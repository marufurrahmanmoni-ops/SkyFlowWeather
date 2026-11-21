import 'dart:async';

import '../../core/constants.dart';
import '../models/place.dart';
import '../net/cached_fetcher.dart';
import '../net/http.dart';
import 'interfaces.dart';

/// Open-Meteo geocoding (GeoNames based).
/// Docs: https://open-meteo.com/en/docs/geocoding-api
class OpenMeteoGeocodingSource implements GeocodingSource {
  OpenMeteoGeocodingSource(this._fetcher);

  final CachedFetcher _fetcher;

  @override
  Future<List<Place>> search(String query, {required String language}) async {
    final q = query.trim();
    if (q.length < 2) return const [];
    var results = await _search(q, language);
    if (results.isEmpty && language != 'en') {
      results = await _search(q, 'en');
    }
    return results;
  }

  Future<List<Place>> _search(String q, String language) async {
    final r = await _fetcher.getJson(
      Endpoints.openMeteoGeocoding,
      query: withOpenMeteoKey({
        'name': q,
        'count': 15,
        'language': language,
        'format': 'json',
      }),
      maxAge: const Duration(days: 7),
    );
    final data = r.data;
    if (data is! Map || data['results'] is! List) return const [];
    final out = <Place>[];
    for (final item in data['results'] as List) {
      if (item is! Map) continue;
      final lat = (item['latitude'] as num?)?.toDouble();
      final lon = (item['longitude'] as num?)?.toDouble();
      final name = item['name'] as String?;
      if (lat == null || lon == null || name == null) continue;
      out.add(Place(
        id: 'om:${item['id'] ?? '$lat,$lon'}',
        name: name,
        lat: lat,
        lon: lon,
        admin1: item['admin1'] as String?,
        country: item['country'] as String?,
        countryCode: (item['country_code'] as String?)?.toUpperCase(),
        timezone: item['timezone'] as String?,
        elevation: (item['elevation'] as num?)?.toDouble(),
      ));
    }
    return out;
  }
}

/// Reverse geocoding with OpenStreetMap Nominatim. Follows the usage policy:
/// identifying User-Agent, at most one request per second, and results are
/// cached for 30 days.
/// Policy: https://operations.osmfoundation.org/policies/nominatim/
class NominatimReverseSource implements ReverseGeocodingSource {
  NominatimReverseSource(this._fetcher);

  final CachedFetcher _fetcher;
  static DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  Future<Place?> reverse(double lat, double lon, {required String language}) async {
    // Round so nearby taps reuse the cache.
    final qLat = double.parse(lat.toStringAsFixed(3));
    final qLon = double.parse(lon.toStringAsFixed(3));
    final wait = const Duration(milliseconds: 1100) - DateTime.now().difference(_last);
    if (!wait.isNegative) await Future<void>.delayed(wait);
    _last = DateTime.now();
    final r = await _fetcher.getJson(
      Endpoints.nominatimReverse,
      query: {
        'format': 'jsonv2',
        'lat': qLat,
        'lon': qLon,
        'zoom': 12,
        'addressdetails': 1,
        'accept-language': language == 'bn' ? 'bn,en' : 'en',
      },
      headers: const {'User-Agent': AppInfo.userAgent},
      maxAge: const Duration(days: 30),
    );
    final data = r.data;
    if (data is! Map || data['error'] != null) return null;
    final address = data['address'];
    String? pick(List<String> keys) {
      if (address is! Map) return null;
      for (final k in keys) {
        final v = address[k];
        if (v is String && v.isNotEmpty) return v;
      }
      return null;
    }

    final name = pick(['city', 'town', 'village', 'municipality', 'suburb', 'county', 'state_district']) ??
        (data['name'] is String && (data['name'] as String).isNotEmpty ? data['name'] as String : null);
    if (name == null) return null;
    return Place(
      id: 'coord:${lat.toStringAsFixed(4)},${lon.toStringAsFixed(4)}',
      name: name,
      lat: lat,
      lon: lon,
      admin1: pick(['state', 'region', 'state_district']),
      country: pick(['country']),
      countryCode: pick(['country_code'])?.toUpperCase(),
    );
  }
}
