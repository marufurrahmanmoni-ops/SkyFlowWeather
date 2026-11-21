import '../../core/geo.dart';
import '../../core/units.dart';

enum WarningSeverity { extreme, severe, moderate, minor, unknown }

enum WarningKind { rain, thunderstorm, wind, heat, cold, flood, cyclone, severe, other }

WarningSeverity severityFromCap(String? s) {
  switch ((s ?? '').trim().toLowerCase()) {
    case 'extreme':
      return WarningSeverity.extreme;
    case 'severe':
      return WarningSeverity.severe;
    case 'moderate':
      return WarningSeverity.moderate;
    case 'minor':
      return WarningSeverity.minor;
    default:
      return WarningSeverity.unknown;
  }
}

/// Guesses the hazard type from an event name or headline.
WarningKind kindFromText(String text) {
  final t = text.toLowerCase();
  if (t.contains('cyclon') ||
      t.contains('hurricane') ||
      t.contains('typhoon') ||
      t.contains('tropical storm') ||
      t.contains('depression') ||
      t.contains('ঘূর্ণিঝড়') ||
      t.contains('নিম্নচাপ')) {
    return WarningKind.cyclone;
  }
  if (t.contains('flood') || t.contains('বন্যা') || t.contains('storm surge')) {
    return WarningKind.flood;
  }
  if (t.contains('thunder') ||
      t.contains('lightning') ||
      t.contains('nor\'wester') ||
      t.contains('বজ্র') ||
      t.contains('কালবৈশাখী') ||
      t.contains('tornado')) {
    return WarningKind.thunderstorm;
  }
  if (t.contains('rain') || t.contains('বৃষ্টি')) return WarningKind.rain;
  if (t.contains('heat') || t.contains('তাপপ্রবাহ')) return WarningKind.heat;
  if (t.contains('cold') ||
      t.contains('freeze') ||
      t.contains('frost') ||
      t.contains('winter') ||
      t.contains('শৈত্যপ্রবাহ')) {
    return WarningKind.cold;
  }
  if (t.contains('wind') || t.contains('gale') || t.contains('বাতাস')) {
    return WarningKind.wind;
  }
  if (t.contains('severe') || t.contains('storm')) return WarningKind.severe;
  return WarningKind.other;
}

/// An official warning from a meteorological or disaster agency.
class OfficialWarning {
  const OfficialWarning({
    required this.id,
    required this.source,
    required this.headline,
    required this.kind,
    required this.severity,
    this.event,
    this.description,
    this.instruction,
    this.senderName,
    this.areaDesc,
    this.sent,
    this.effective,
    this.expires,
    this.polygons = const [],
    this.point,
    this.link,
  });

  final String id;

  /// Short source label, e.g. "BMD", "NWS", "GDACS".
  final String source;
  final String headline;
  final WarningKind kind;
  final WarningSeverity severity;
  final String? event;
  final String? description;
  final String? instruction;
  final String? senderName;
  final String? areaDesc;
  final DateTime? sent;
  final DateTime? effective;
  final DateTime? expires;
  final List<List<GeoPoint>> polygons;
  final GeoPoint? point;
  final String? link;

  bool isActive(DateTime now) => expires == null || expires!.isAfter(now);

  /// Whether the warning applies to the given location. Warnings with no
  /// geometry are assumed to cover the issuing country (handled by caller).
  bool covers(double lat, double lon, {double radiusKm = 0}) {
    if (polygons.isNotEmpty) {
      for (final poly in polygons) {
        if (Geo.pointInPolygon(lat, lon, poly)) return true;
      }
      if (radiusKm <= 0) return false;
      for (final poly in polygons) {
        for (final p in poly) {
          if (Geo.distanceKm(lat, lon, p.lat, p.lon) <= radiusKm) return true;
        }
      }
      return false;
    }
    if (point != null && radiusKm > 0) {
      return Geo.distanceKm(lat, lon, point!.lat, point!.lon) <= radiusKm;
    }
    return true;
  }
}

/// A forecast value crossing one of the user's thresholds.
class ForecastAlert {
  const ForecastAlert({
    required this.kind,
    required this.time,
    required this.value,
    required this.threshold,
    required this.quantity,
  });

  final WarningKind kind;

  /// Unix seconds of the first hour (or day) that crosses the threshold.
  final int time;
  final double value;
  final double threshold;
  final Quantity quantity;

  String get dedupeKey => '${kind.name}:${time ~/ 21600}';
}

/// An active tropical cyclone or other disaster event from GDACS.
class DisasterEvent {
  const DisasterEvent({
    required this.eventType,
    required this.eventId,
    required this.episodeId,
    required this.name,
    required this.alertLevel,
    required this.lat,
    required this.lon,
    this.country,
    this.fromDate,
    this.toDate,
    this.severityText,
    this.geometryUrl,
    this.reportUrl,
    this.isCurrent = false,
    this.affectedIso2 = const [],
    this.description,
  });

  final String eventType;
  final int eventId;
  final int episodeId;
  final String name;
  final String alertLevel;
  final double lat;
  final double lon;
  final String? country;
  final DateTime? fromDate;
  final DateTime? toDate;
  final String? severityText;
  final String? geometryUrl;
  final String? reportUrl;
  final bool isCurrent;
  final List<String> affectedIso2;
  final String? description;

  WarningKind get kind =>
      eventType == 'TC' ? WarningKind.cyclone : (eventType == 'FL' ? WarningKind.flood : WarningKind.other);

  WarningSeverity get severity {
    switch (alertLevel.toLowerCase()) {
      case 'red':
        return WarningSeverity.extreme;
      case 'orange':
        return WarningSeverity.severe;
      case 'green':
        return WarningSeverity.minor;
      default:
        return WarningSeverity.unknown;
    }
  }
}
