import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import '../../core/constants.dart';
import '../../core/geo.dart';
import '../models/forecast.dart';
import '../models/place.dart';
import '../net/cached_fetcher.dart';
import '../net/http.dart';
import 'interfaces.dart';

String _c(double v) => v.toStringAsFixed(4);

/// Open-Meteo forecast, air quality and marine APIs.
/// Docs: https://open-meteo.com/en/docs
class OpenMeteoForecastSource implements ForecastSource {
  OpenMeteoForecastSource(this._fetcher);

  final CachedFetcher _fetcher;

  @override
  String get name => 'Open-Meteo';

  @override
  String get attribution => 'Weather data by Open-Meteo.com (CC BY 4.0)';

  @override
  String get attributionUrl => 'https://open-meteo.com/';

  static const currentVars = [
    'temperature_2m',
    'relative_humidity_2m',
    'apparent_temperature',
    'is_day',
    'precipitation',
    'weather_code',
    'cloud_cover',
    'pressure_msl',
    'wind_speed_10m',
    'wind_direction_10m',
    'wind_gusts_10m',
    'dew_point_2m',
    'visibility',
    'uv_index',
  ];

  static const hourlyVars = [
    'temperature_2m',
    'apparent_temperature',
    'relative_humidity_2m',
    'dew_point_2m',
    'precipitation_probability',
    'precipitation',
    'snowfall',
    'weather_code',
    'pressure_msl',
    'cloud_cover',
    'cloud_cover_low',
    'cloud_cover_mid',
    'cloud_cover_high',
    'visibility',
    'wind_speed_10m',
    'wind_direction_10m',
    'wind_gusts_10m',
    'uv_index',
    'cape',
    'is_day',
  ];

  static const dailyVars = [
    'weather_code',
    'temperature_2m_max',
    'temperature_2m_min',
    'apparent_temperature_max',
    'apparent_temperature_min',
    'sunrise',
    'sunset',
    'daylight_duration',
    'uv_index_max',
    'precipitation_sum',
    'precipitation_probability_max',
    'wind_speed_10m_max',
    'wind_gusts_10m_max',
    'wind_direction_10m_dominant',
  ];

  Map<String, dynamic> _base(Place place) => withOpenMeteoKey({
        'latitude': _c(place.lat),
        'longitude': _c(place.lon),
        'timezone': 'auto',
        'timeformat': 'unixtime',
      });

  @override
  Future<ForecastBundle> forecast(Place place,
      {bool forceRefresh = false, void Function()? onRevalidated}) async {
    // A saved forecast up to a day old is shown at once and refreshed behind.
    final maxStale = onRevalidated == null ? null : const Duration(hours: 24);
    final forecastFuture = _fetcher.getJson(
      Endpoints.openMeteoForecast,
      query: {
        ..._base(place),
        'current': currentVars.join(','),
        'hourly': hourlyVars.join(','),
        'daily': dailyVars.join(','),
        'forecast_days': 16,
      },
      maxAge: const Duration(minutes: 15),
      forceRefresh: forceRefresh,
      maxStale: maxStale,
      onRevalidated: onRevalidated,
    );
    // Secondary datasets must never break the main forecast.
    final aqFuture = _optional(_fetcher.getJson(
      Endpoints.openMeteoAirQuality,
      query: {
        ..._base(place),
        'current':
            'us_aqi,european_aqi,pm2_5,pm10,ozone,nitrogen_dioxide,sulphur_dioxide,carbon_monoxide',
        'hourly': 'us_aqi,pm2_5',
        'forecast_days': 3,
      },
      maxAge: const Duration(minutes: 30),
      forceRefresh: forceRefresh,
      maxStale: maxStale,
      onRevalidated: onRevalidated,
    ));
    final marineFuture = _optional(_fetcher.getJson(
      Endpoints.openMeteoMarine,
      query: {
        ..._base(place),
        'current':
            'wave_height,wave_direction,wave_period,swell_wave_height,swell_wave_direction,sea_surface_temperature',
        'hourly': 'wave_height,swell_wave_height,sea_surface_temperature',
        'forecast_days': 3,
      },
      maxAge: const Duration(minutes: 60),
      forceRefresh: forceRefresh,
      maxStale: maxStale,
      onRevalidated: onRevalidated,
    ));
    final astroFuture = _optional(_fetcher.getJson(
      Endpoints.openMeteoForecast,
      query: {
        ..._base(place),
        'daily': 'moonrise,moonset',
        'forecast_days': 7,
      },
      maxAge: const Duration(hours: 6),
      forceRefresh: forceRefresh,
      maxStale: maxStale,
      onRevalidated: onRevalidated,
    ));

    final f = await forecastFuture;
    final aq = await aqFuture;
    final marine = await marineFuture;
    final astro = await astroFuture;
    return ForecastBundle(
      forecast: _parse(f),
      airQuality: aq == null ? null : _parse(aq),
      marine: marine == null ? null : _parse(marine),
      astronomy: astro == null ? null : _parse(astro),
    );
  }

  Future<FetchResult<Object?>?> _optional(Future<FetchResult<Object?>> f) async {
    try {
      return await f;
    } catch (_) {
      return null;
    }
  }

  OmResponse _parse(FetchResult<Object?> r) {
    final data = r.data;
    if (data is! Map<String, dynamic>) {
      throw const ApiException(ApiErrorKind.unknown, message: 'Unexpected response');
    }
    if (data['error'] == true) {
      throw ApiException(ApiErrorKind.badRequest, message: data['reason'] as String?);
    }
    return OmResponse.fromJson(data, fetchedAt: r.fetchedAt, stale: r.stale);
  }

  @override
  Future<OmResponse> modelComparison(Place place, List<String> models,
      {int days = 10}) async {
    final r = await _fetcher.getJson(
      Endpoints.openMeteoForecast,
      query: {
        ..._base(place),
        'hourly':
            'temperature_2m,wind_speed_10m,wind_direction_10m,precipitation,cloud_cover,pressure_msl',
        'models': models.join(','),
        'forecast_days': days,
      },
      maxAge: const Duration(minutes: 30),
    );
    return _parse(r);
  }

  @override
  Future<OmResponse> pressureLevels(Place place, List<int> levels) async {
    final vars = <String>[
      for (final l in levels) ...[
        'cloud_cover_${l}hPa',
        'temperature_${l}hPa',
        'relative_humidity_${l}hPa',
        'geopotential_height_${l}hPa',
        'wind_speed_${l}hPa',
        'wind_direction_${l}hPa',
      ],
    ];
    final r = await _fetcher.getJson(
      Endpoints.openMeteoForecast,
      query: {
        ..._base(place),
        'hourly': vars.join(','),
        'forecast_days': 3,
      },
      maxAge: const Duration(minutes: 45),
    );
    return _parse(r);
  }

  @override
  Future<OmResponse> alertForecast(Place place) async {
    final r = await _fetcher.getJson(
      Endpoints.openMeteoForecast,
      query: {
        ..._base(place),
        'hourly':
            'temperature_2m,precipitation,wind_gusts_10m,cape,weather_code',
        'daily': 'precipitation_sum',
        'forecast_days': 3,
      },
      maxAge: const Duration(minutes: 30),
    );
    return _parse(r);
  }

  @override
  Future<List<OmResponse?>> currentForMany(List<Place> places) async {
    if (places.isEmpty) return const [];
    final r = await _fetcher.getJson(
      Endpoints.openMeteoForecast,
      query: withOpenMeteoKey({
        'latitude': places.map((p) => _c(p.lat)).join(','),
        'longitude': places.map((p) => _c(p.lon)).join(','),
        'current': 'temperature_2m,weather_code,is_day,wind_speed_10m,precipitation',
        'daily': 'temperature_2m_max,temperature_2m_min',
        'forecast_days': 1,
        'timezone': 'auto',
        'timeformat': 'unixtime',
      }),
      maxAge: const Duration(minutes: 15),
    );
    final data = r.data;
    final list = data is List ? data : [data];
    return [
      for (var i = 0; i < places.length; i++)
        (i < list.length && list[i] is Map<String, dynamic>)
            ? OmResponse.fromJson(list[i] as Map<String, dynamic>,
                fetchedAt: r.fetchedAt, stale: r.stale)
            : null,
    ];
  }
}

/// Fetches hourly series for many points at once using Open-Meteo's
/// multi-coordinate support (one JSON object per point).
class OpenMeteoGridSource implements GridSource {
  OpenMeteoGridSource(this._fetcher);

  final CachedFetcher _fetcher;

  @override
  Future<List<PointSeries?>> fetch(GridRequest request, List<GeoPoint> points) async {
    if (points.isEmpty) return const [];
    final query = withOpenMeteoKey(<String, dynamic>{
      'latitude': points.map((p) => p.lat.toStringAsFixed(3)).join(','),
      'longitude': points.map((p) => p.lon.toStringAsFixed(3)).join(','),
      'hourly': request.variables.join(','),
      'forecast_days': 4,
      'timezone': 'GMT',
      'timeformat': 'unixtime',
      ...request.extra,
    });
    // Cached on the phone so reopening the app shows the map at once; the
    // models update hourly, so 45 minutes keeps the data current.
    final body = await _fetcher.getText(
      request.url,
      query: query,
      maxAge: const Duration(minutes: 45),
      keyPrefix: gridCachePrefix,
    );
    // Decoding a few hundred kB of JSON on the UI thread makes the app stutter.
    final variables = request.variables;
    final count = points.length;
    final parsed = await parseGridInBackground(body.data, variables, count);
    if (parsed.error != null) {
      throw ApiException(ApiErrorKind.badRequest, message: parsed.error);
    }
    return parsed.series;
  }
}

/// Top-level so the isolate closure does not capture `this` (Dio, database).
Future<ParsedGrid> parseGridInBackground(String body, List<String> variables, int count) =>
    Isolate.run(() => parseGridResponse(body, variables, count));

/// Cache-key prefix of map grid responses (pruned more often than others).
const String gridCachePrefix = 'grid:';

class ParsedGrid {
  const ParsedGrid(this.series, [this.error]);
  final List<PointSeries?> series;
  final String? error;
}

/// Parses an Open-Meteo multi-location response. Runs in a background isolate.
ParsedGrid parseGridResponse(String body, List<String> variables, int count) {
  Object? data;
  try {
    data = jsonDecode(body);
  } on FormatException catch (e) {
    return ParsedGrid(const [], 'Invalid JSON: ${e.message}');
  }
  if (data is Map && data['error'] == true) {
    return ParsedGrid(const [], data['reason'] as String? ?? 'error');
  }
  final list = data is List ? data : [data];
  final result = <PointSeries?>[];
  for (var i = 0; i < count; i++) {
    if (i >= list.length || list[i] is! Map) {
      result.add(null);
      continue;
    }
    final hourly = (list[i] as Map)['hourly'];
    if (hourly is! Map || hourly['time'] is! List) {
      result.add(null);
      continue;
    }
    final times = hourly['time'] as List;
    if (times.isEmpty) {
      result.add(null);
      continue;
    }
    final start = (times.first as num).toInt();
    final series = <String, Float32List>{};
    for (final v in variables) {
      final raw = hourly[v];
      final arr = Float32List(times.length);
      for (var t = 0; t < times.length; t++) {
        final val = (raw is List && t < raw.length) ? raw[t] : null;
        arr[t] = val is num ? val.toDouble() : double.nan;
      }
      series[v] = arr;
    }
    result.add(PointSeries(start, series));
  }
  return ParsedGrid(result);
}
