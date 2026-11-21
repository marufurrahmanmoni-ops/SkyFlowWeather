import 'dart:async';

import '../../core/constants.dart';
import '../../core/geo.dart';
import '../../core/mini_xml.dart';
import '../models/place.dart';
import '../models/warnings.dart';
import '../net/cached_fetcher.dart';
import 'interfaces.dart';

/// Parses one CAP 1.2 alert message into warnings (one per `<info>` block in
/// the preferred language).
List<OfficialWarning> parseCapAlert(
  String xml, {
  required String source,
  required String language,
  String? fallbackLink,
}) {
  final status = MiniXml.text(xml, 'status')?.toLowerCase();
  final msgType = MiniXml.text(xml, 'msgType')?.toLowerCase();
  if (status != null && status != 'actual') return const [];
  if (msgType == 'cancel') return const [];
  final identifier = MiniXml.text(xml, 'identifier') ?? fallbackLink ?? xml.hashCode.toString();
  final sent = MiniXml.parseIso(MiniXml.text(xml, 'sent'));

  final infos = MiniXml.elements(xml, 'info');
  if (infos.isEmpty) return const [];
  String? chosen;
  for (final info in infos) {
    final lang = (MiniXml.text(info, 'language') ?? 'en').toLowerCase();
    if (lang.startsWith(language)) {
      chosen = info;
      break;
    }
  }
  chosen ??= infos.firstWhere(
    (i) => (MiniXml.text(i, 'language') ?? 'en').toLowerCase().startsWith('en'),
    orElse: () => infos.first,
  );

  final info = chosen;
  final event = MiniXml.text(info, 'event');
  final headline = MiniXml.text(info, 'headline') ?? event ?? source;
  final polygons = <List<GeoPoint>>[];
  final areaDescs = <String>[];
  for (final area in MiniXml.elements(info, 'area')) {
    final desc = MiniXml.text(area, 'areaDesc');
    if (desc != null) areaDescs.add(desc);
    for (final poly in MiniXml.texts(area, 'polygon')) {
      final pts = <GeoPoint>[];
      for (final pair in poly.split(RegExp(r'\s+'))) {
        final parts = pair.split(',');
        if (parts.length < 2) continue;
        final lat = double.tryParse(parts[0]);
        final lon = double.tryParse(parts[1]);
        if (lat != null && lon != null) pts.add(GeoPoint(lat, lon));
      }
      if (pts.length >= 3) polygons.add(pts);
    }
  }
  return [
    OfficialWarning(
      id: '$source:$identifier',
      source: source,
      headline: headline,
      event: event,
      kind: kindFromText('${event ?? ''} $headline'),
      severity: severityFromCap(MiniXml.text(info, 'severity')),
      description: MiniXml.text(info, 'description'),
      instruction: MiniXml.text(info, 'instruction'),
      senderName: MiniXml.text(info, 'senderName'),
      areaDesc: areaDescs.isEmpty ? null : areaDescs.join('; '),
      sent: sent,
      effective: MiniXml.parseIso(MiniXml.text(info, 'effective')) ??
          MiniXml.parseIso(MiniXml.text(info, 'onset')),
      expires: MiniXml.parseIso(MiniXml.text(info, 'expires')),
      polygons: polygons,
      link: MiniXml.text(info, 'web') ?? fallbackLink,
    ),
  ];
}

/// Generic CAP-over-RSS feed (used for the Bangladesh Meteorological
/// Department, and usable for any WMO-registered CAP feed).
class CapRssWarningSource implements WarningSource {
  CapRssWarningSource({
    required CachedFetcher fetcher,
    required this.id,
    required this.label,
    required this.feedUrl,
    required this.countryCode,
    required this.region,
    this.maxItems = 8,
  }) : _fetcher = fetcher;

  final CachedFetcher _fetcher;
  @override
  final String id;
  @override
  final String label;
  final String feedUrl;
  final String countryCode;
  final GeoBounds region;
  final int maxItems;

  @override
  bool covers(Place place) =>
      place.countryCode == countryCode || region.contains(place.lat, place.lon);

  @override
  Future<List<OfficialWarning>> activeFor(Place place, {required String language}) async {
    final rss = await _fetcher.getText(feedUrl, maxAge: const Duration(minutes: 10));
    final items = MiniXml.elements(rss.data, 'item').take(maxItems).toList();
    final now = DateTime.now().toUtc();
    final futures = <Future<List<OfficialWarning>>>[];
    for (final item in items) {
      final link = MiniXml.text(item, 'link');
      final pubDate = MiniXml.parseRfc822(MiniXml.text(item, 'pubDate'));
      // Skip items older than 10 days without fetching them.
      if (pubDate != null && now.difference(pubDate).inDays > 10) continue;
      if (link == null || !link.startsWith('http')) continue;
      futures.add(_fetcher
          .getText(link, maxAge: const Duration(hours: 12))
          .then((r) => parseCapAlert(r.data,
              source: id, language: language, fallbackLink: link))
          .catchError((Object _) => <OfficialWarning>[]));
    }
    final all = (await Future.wait(futures)).expand((e) => e);
    final result = <OfficialWarning>[];
    for (final w in all) {
      final active = w.expires != null
          ? w.expires!.isAfter(now)
          : (w.sent != null && now.difference(w.sent!).inHours < 36);
      if (!active) continue;
      if (!w.covers(place.lat, place.lon, radiusKm: 25)) continue;
      result.add(w);
    }
    return result;
  }
}

/// US National Weather Service active alerts.
/// Docs: https://www.weather.gov/documentation/services-web-api
class NwsWarningSource implements WarningSource {
  NwsWarningSource(this._fetcher);

  final CachedFetcher _fetcher;

  @override
  String get id => 'NWS';

  @override
  String get label => 'US National Weather Service';

  static const _region = GeoBounds(south: 17, west: -180, north: 72, east: -64.5);

  @override
  bool covers(Place place) =>
      place.countryCode == 'US' ||
      (place.countryCode == null && _region.contains(place.lat, place.lon));

  @override
  Future<List<OfficialWarning>> activeFor(Place place, {required String language}) async {
    final r = await _fetcher.getJson(
      Endpoints.nwsAlertsActive,
      query: {'point': '${place.lat.toStringAsFixed(4)},${place.lon.toStringAsFixed(4)}'},
      headers: const {
        'Accept': 'application/geo+json',
        'User-Agent': AppInfo.userAgent,
      },
      maxAge: const Duration(minutes: 5),
    );
    final data = r.data;
    if (data is! Map || data['features'] is! List) return const [];
    final out = <OfficialWarning>[];
    for (final f in data['features'] as List) {
      if (f is! Map || f['properties'] is! Map) continue;
      final p = f['properties'] as Map;
      if ((p['status'] as String?)?.toLowerCase() != 'actual') continue;
      final event = p['event'] as String?;
      final headline = (p['headline'] as String?) ?? event ?? 'NWS alert';
      final polygons = <List<GeoPoint>>[];
      final geom = f['geometry'];
      if (geom is Map && geom['type'] == 'Polygon' && geom['coordinates'] is List) {
        for (final ring in geom['coordinates'] as List) {
          if (ring is! List) continue;
          polygons.add([
            for (final c in ring)
              if (c is List && c.length >= 2)
                GeoPoint((c[1] as num).toDouble(), (c[0] as num).toDouble()),
          ]);
        }
      }
      out.add(OfficialWarning(
        id: 'NWS:${p['id'] ?? headline.hashCode}',
        source: 'NWS',
        headline: headline,
        event: event,
        kind: kindFromText('${event ?? ''} $headline'),
        severity: severityFromCap(p['severity'] as String?),
        description: p['description'] as String?,
        instruction: p['instruction'] as String?,
        senderName: p['senderName'] as String?,
        areaDesc: p['areaDesc'] as String?,
        sent: MiniXml.parseIso(p['sent'] as String?),
        effective: MiniXml.parseIso(p['effective'] as String?),
        expires: MiniXml.parseIso((p['ends'] ?? p['expires']) as String?),
        polygons: polygons,
        link: p['@id'] as String?,
      ));
    }
    return out;
  }
}

/// GDACS (Global Disaster Alert and Coordination System, EU JRC & UN OCHA):
/// active tropical cyclones and floods worldwide.
/// API: https://www.gdacs.org/gdacsapi/
class GdacsSource implements StormSource, WarningSource {
  GdacsSource(this._fetcher);

  final CachedFetcher _fetcher;

  @override
  String get id => 'GDACS';

  @override
  String get label => 'GDACS (EU JRC / UN)';

  @override
  bool covers(Place place) => true;

  String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Future<List<DisasterEvent>> activeEvents({Set<String> types = const {'TC'}}) async {
    final now = DateTime.now().toUtc();
    final r = await _fetcher.getJson(
      Endpoints.gdacsEventSearch,
      query: {
        'eventlist': types.join(';'),
        'fromdate': _date(now.subtract(const Duration(days: 21))),
        'todate': _date(now.add(const Duration(days: 1))),
        'alertlevel': 'green;orange;red',
      },
      maxAge: const Duration(minutes: 20),
    );
    final data = r.data;
    if (data is! Map || data['features'] is! List) return const [];
    final out = <DisasterEvent>[];
    for (final f in data['features'] as List) {
      if (f is! Map || f['properties'] is! Map) continue;
      final p = f['properties'] as Map;
      final isCurrent = '${p['iscurrent']}'.toLowerCase() == 'true';
      if (!isCurrent) continue;
      double? lat, lon;
      final geom = f['geometry'];
      if (geom is Map && geom['coordinates'] is List) {
        final c = geom['coordinates'] as List;
        if (c.length >= 2 && c[0] is num && c[1] is num) {
          lon = (c[0] as num).toDouble();
          lat = (c[1] as num).toDouble();
        }
      }
      if (lat == null || lon == null) continue;
      final url = p['url'];
      final severity = p['severitydata'];
      final iso2 = <String>[];
      if (p['affectedcountries'] is List) {
        for (final c in p['affectedcountries'] as List) {
          if (c is Map && c['iso2'] is String) iso2.add((c['iso2'] as String).toUpperCase());
        }
      }
      out.add(DisasterEvent(
        eventType: '${p['eventtype']}',
        eventId: (p['eventid'] as num?)?.toInt() ?? 0,
        episodeId: (p['episodeid'] as num?)?.toInt() ?? 0,
        name: (p['eventname'] as String?)?.isNotEmpty == true
            ? p['eventname'] as String
            : (p['name'] as String? ?? 'Event'),
        alertLevel: p['alertlevel'] as String? ?? 'Green',
        lat: lat,
        lon: lon,
        country: p['country'] as String?,
        fromDate: MiniXml.parseIso(p['fromdate'] as String?),
        toDate: MiniXml.parseIso(p['todate'] as String?),
        severityText: severity is Map ? severity['severitytext'] as String? : null,
        geometryUrl: url is Map ? url['geometry'] as String? : null,
        reportUrl: url is Map ? url['report'] as String? : null,
        isCurrent: true,
        affectedIso2: iso2,
        description: p['description'] as String?,
      ));
    }
    return out;
  }

  @override
  Future<Map<String, dynamic>?> geometry(DisasterEvent event) async {
    final url = event.geometryUrl;
    if (url == null) return null;
    final r = await _fetcher.getJson(url, maxAge: const Duration(minutes: 30));
    final data = r.data;
    if (data is Map<String, dynamic> && data['type'] == 'FeatureCollection') return data;
    return null;
  }

  @override
  Future<List<OfficialWarning>> activeFor(Place place, {required String language}) async {
    final events = await activeEvents(types: const {'TC', 'FL'});
    final out = <OfficialWarning>[];
    for (final e in events) {
      final distance = Geo.distanceKm(place.lat, place.lon, e.lat, e.lon);
      final countryMatch =
          place.countryCode != null && e.affectedIso2.contains(place.countryCode);
      final relevant = e.eventType == 'TC'
          ? (distance <= 900 || (countryMatch && distance <= 2000))
          : (countryMatch || distance <= 250);
      if (!relevant) continue;
      final typeLabel = e.eventType == 'TC' ? 'Tropical cyclone' : 'Flood';
      out.add(OfficialWarning(
        id: 'GDACS:${e.eventType}:${e.eventId}:${e.episodeId}',
        source: 'GDACS',
        headline: '${e.alertLevel} alert – $typeLabel ${e.name}',
        event: typeLabel,
        kind: e.kind,
        severity: e.severity,
        description: [
          if (e.severityText != null) e.severityText!,
          if (e.description != null) e.description!,
          '${distance.round()} km from ${place.name}',
        ].join('\n'),
        senderName: 'GDACS – European Commission JRC',
        areaDesc: e.country,
        sent: e.fromDate,
        expires: e.toDate?.add(const Duration(days: 1)),
        point: GeoPoint(e.lat, e.lon),
        link: e.reportUrl,
      ));
    }
    return out;
  }
}

/// Bangladesh bounding box used to route BMD warnings.
const bangladeshRegion = GeoBounds(south: 20.3, west: 87.9, north: 26.8, east: 92.8);
