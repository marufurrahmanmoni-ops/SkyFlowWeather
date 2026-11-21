/// Parsed Open-Meteo style responses (forecast, air quality, marine).
///
/// All requests use `timeformat=unixtime`, so every time value is UTC seconds.
library;

double? _toDouble(Object? v) {
  if (v is num) return v.toDouble();
  return null;
}

/// A set of aligned time series (hourly or daily).
class TimeSeries {
  TimeSeries(this.time, this.values);

  TimeSeries.empty()
      : time = const [],
        values = const {};

  factory TimeSeries.fromJson(Object? json) {
    if (json is! Map) return TimeSeries.empty();
    final rawTime = json['time'];
    if (rawTime is! List) return TimeSeries.empty();
    final time = <int>[for (final t in rawTime) (t as num).toInt()];
    final values = <String, List<double?>>{};
    json.forEach((key, value) {
      if (key == 'time' || key is! String || value is! List) return;
      values[key] = [for (final v in value) _toDouble(v)];
    });
    return TimeSeries(time, values);
  }

  final List<int> time;
  final Map<String, List<double?>> values;

  int get length => time.length;
  bool get isEmpty => time.isEmpty;

  bool has(String key) => values.containsKey(key);

  List<double?> series(String key) => values[key] ?? List<double?>.filled(length, null);

  double? at(String key, int index) {
    final s = values[key];
    if (s == null || index < 0 || index >= s.length) return null;
    return s[index];
  }

  /// Index of the first entry at or after [unixSeconds], or -1.
  int indexAtOrAfter(int unixSeconds) {
    for (var i = 0; i < time.length; i++) {
      if (time[i] >= unixSeconds) return i;
    }
    return -1;
  }

  /// Index of the entry whose interval contains [unixSeconds].
  int indexFor(int unixSeconds) {
    if (time.isEmpty) return -1;
    var best = 0;
    for (var i = 0; i < time.length; i++) {
      if (time[i] <= unixSeconds) best = i;
    }
    return best;
  }

  bool hasAnyValue(String key) => values[key]?.any((v) => v != null) ?? false;
}

class OmResponse {
  OmResponse({
    required this.latitude,
    required this.longitude,
    required this.elevation,
    required this.timezone,
    required this.timezoneAbbreviation,
    required this.utcOffsetSeconds,
    required this.current,
    required this.currentTime,
    required this.hourly,
    required this.daily,
    required this.fetchedAt,
    required this.stale,
  });

  factory OmResponse.fromJson(Map<String, dynamic> json,
      {required DateTime fetchedAt, bool stale = false}) {
    final current = <String, double?>{};
    int? currentTime;
    final rawCurrent = json['current'];
    if (rawCurrent is Map) {
      rawCurrent.forEach((k, v) {
        if (k == 'time') {
          currentTime = (v as num?)?.toInt();
        } else if (k is String && k != 'interval') {
          current[k] = _toDouble(v);
        }
      });
    }
    return OmResponse(
      latitude: _toDouble(json['latitude']) ?? 0,
      longitude: _toDouble(json['longitude']) ?? 0,
      elevation: _toDouble(json['elevation']),
      timezone: json['timezone'] as String? ?? 'GMT',
      timezoneAbbreviation: json['timezone_abbreviation'] as String?,
      utcOffsetSeconds: (json['utc_offset_seconds'] as num?)?.toInt() ?? 0,
      current: current,
      currentTime: currentTime,
      hourly: TimeSeries.fromJson(json['hourly']),
      daily: TimeSeries.fromJson(json['daily']),
      fetchedAt: fetchedAt,
      stale: stale,
    );
  }

  final double latitude;
  final double longitude;
  final double? elevation;
  final String timezone;
  final String? timezoneAbbreviation;
  final int utcOffsetSeconds;
  final Map<String, double?> current;
  final int? currentTime;
  final TimeSeries hourly;
  final TimeSeries daily;
  final DateTime fetchedAt;

  /// True when the data came from the offline cache after a failed refresh.
  final bool stale;
}

/// Everything shown on the forecast screen for one place.
class ForecastBundle {
  ForecastBundle({
    required this.forecast,
    this.airQuality,
    this.marine,
    this.astronomy,
  });

  final OmResponse forecast;
  final OmResponse? airQuality;
  final OmResponse? marine;

  /// Daily moonrise/moonset (separate request so a failure never breaks the
  /// main forecast).
  final OmResponse? astronomy;

  bool get hasMarine =>
      marine != null &&
      (marine!.current['wave_height'] != null ||
          marine!.hourly.hasAnyValue('wave_height'));
}
