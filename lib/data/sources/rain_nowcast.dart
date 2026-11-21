import '../../core/constants.dart';
import '../net/cached_fetcher.dart';
import '../net/http.dart';

/// A town used for the "rain across Bangladesh" list.
class BdCity {
  const BdCity(this.nameEn, this.nameBn, this.lat, this.lon);
  final String nameEn;
  final String nameBn;
  final double lat;
  final double lon;

  String name(bool bengali) => bengali ? nameBn : nameEn;
}

/// Divisional headquarters plus the radar stations and other large towns.
const List<BdCity> bdCities = [
  BdCity('Dhaka', 'ঢাকা', 23.8103, 90.4125),
  BdCity('Chattogram', 'চট্টগ্রাম', 22.3569, 91.7832),
  BdCity('Khulna', 'খুলনা', 22.8456, 89.5403),
  BdCity('Rajshahi', 'রাজশাহী', 24.3745, 88.6042),
  BdCity('Sylhet', 'সিলেট', 24.8949, 91.8687),
  BdCity('Barishal', 'বরিশাল', 22.7010, 90.3535),
  BdCity('Rangpur', 'রংপুর', 25.7439, 89.2752),
  BdCity('Mymensingh', 'ময়মনসিংহ', 24.7471, 90.4203),
  BdCity("Cox's Bazar", 'কক্সবাজার', 21.4272, 92.0058),
  BdCity('Cumilla', 'কুমিল্লা', 23.4607, 91.1809),
  BdCity('Bogura', 'বগুড়া', 24.8466, 89.3773),
  BdCity('Jashore', 'যশোর', 23.1664, 89.2081),
  BdCity('Dinajpur', 'দিনাজপুর', 25.6217, 88.6354),
  BdCity('Patuakhali', 'পটুয়াখালী', 22.3596, 90.3299),
  BdCity('Noakhali', 'নোয়াখালী', 22.8696, 91.0995),
  BdCity('Moulvibazar', 'মৌলভীবাজার', 24.4829, 91.7774),
  BdCity('Faridpur', 'ফরিদপুর', 23.6070, 89.8429),
  BdCity('Tangail', 'টাঙ্গাইল', 24.2513, 89.9167),
];

/// Rain now and over the next two hours (15-minute steps) for one point.
class RainNowcast {
  const RainNowcast({
    required this.lat,
    required this.lon,
    required this.currentMm,
    required this.weatherCode,
    required this.stepTimes,
    required this.stepMm,
    required this.probability,
    required this.utcOffsetSeconds,
  });

  final double lat;
  final double lon;

  /// Precipitation of the current 15-minute period, mm.
  final double currentMm;
  final int? weatherCode;

  /// Start of each 15-minute step (unix seconds) and its precipitation (mm).
  final List<int> stepTimes;
  final List<double> stepMm;

  /// Highest hourly rain probability over the next two hours, percent.
  final int? probability;
  final int utcOffsetSeconds;

  /// 0.1 mm per 15 minutes is the smallest amount a gauge reports.
  static const double wetThreshold = 0.1;

  static bool isRainCode(int? code) =>
      code != null && ((code >= 51 && code <= 67) || (code >= 80 && code <= 82) || code >= 95);

  bool get rainingNow => currentMm >= wetThreshold || isRainCode(weatherCode);

  double get next2hMm => stepMm.fold(0.0, (a, b) => a + b);

  /// Minutes from now until the first wet 15-minute step, or null if dry.
  int? minutesUntilRain(int nowSec) {
    for (var i = 0; i < stepTimes.length; i++) {
      if (stepMm[i] >= wetThreshold) {
        final m = ((stepTimes[i] - nowSec) / 60).round();
        return m < 0 ? 0 : m;
      }
    }
    return null;
  }

  /// Minutes from now until rain stops, when it is raining now.
  int? minutesUntilDry(int nowSec) {
    if (!rainingNow) return null;
    for (var i = 0; i < stepTimes.length; i++) {
      if (stepMm[i] < wetThreshold && stepTimes[i] >= nowSec) {
        return ((stepTimes[i] - nowSec) / 60).round();
      }
    }
    return null;
  }

  /// Rough intensity class of the heaviest coming step: 0 none … 3 heavy.
  int get intensity {
    final peak = [currentMm, ...stepMm].fold(0.0, (a, b) => a > b ? a : b);
    if (peak < wetThreshold) return 0;
    if (peak < 0.6) return 1; // < 2.5 mm/h
    if (peak < 2.0) return 2; // < 8 mm/h
    return 3;
  }
}

/// Parses an Open-Meteo response (one object, or a list for many points).
List<RainNowcast?> parseRainNowcast(Object? data, int count) {
  final list = data is List ? data : [data];
  final out = <RainNowcast?>[];
  for (var i = 0; i < count; i++) {
    final item = i < list.length ? list[i] : null;
    out.add(item is Map ? _parseOne(item) : null);
  }
  return out;
}

RainNowcast? _parseOne(Map json) {
  double num0(Object? v) => v is num ? v.toDouble() : 0.0;
  final current = json['current'];
  final m15 = json['minutely_15'];
  if (current is! Map || m15 is! Map || m15['time'] is! List) return null;
  final times = [for (final t in m15['time'] as List) (t as num).toInt()];
  final rawMm = m15['precipitation'];
  final mm = [
    for (var k = 0; k < times.length; k++) rawMm is List && k < rawMm.length ? num0(rawMm[k]) : 0.0,
  ];
  int? prob;
  final hourly = json['hourly'];
  if (hourly is Map && hourly['precipitation_probability'] is List) {
    for (final p in hourly['precipitation_probability'] as List) {
      if (p is num && (prob == null || p > prob)) prob = p.round();
    }
  }
  final code = current['weather_code'];
  return RainNowcast(
    lat: num0(json['latitude']),
    lon: num0(json['longitude']),
    currentMm: num0(current['precipitation']),
    weatherCode: code is num ? code.toInt() : null,
    stepTimes: times,
    stepMm: mm,
    probability: prob,
    utcOffsetSeconds: (json['utc_offset_seconds'] as num?)?.toInt() ?? 0,
  );
}

/// Rain now and in the next two hours from Open-Meteo. In South Asia the
/// 15-minute values come from the weather models, not from radar.
class RainNowcastSource {
  RainNowcastSource(this._fetcher);
  final CachedFetcher _fetcher;

  Future<List<RainNowcast?>> fetch(List<(double, double)> points) async {
    if (points.isEmpty) return const [];
    final r = await _fetcher.getJson(
      Endpoints.openMeteoForecast,
      query: withOpenMeteoKey({
        'latitude': points.map((p) => p.$1.toStringAsFixed(4)).join(','),
        'longitude': points.map((p) => p.$2.toStringAsFixed(4)).join(','),
        'current': 'precipitation,weather_code',
        'minutely_15': 'precipitation',
        'forecast_minutely_15': 8,
        'hourly': 'precipitation_probability',
        'forecast_hours': 2,
        'timezone': 'auto',
        'timeformat': 'unixtime',
      }),
      maxAge: const Duration(minutes: 10),
    );
    return parseRainNowcast(r.data, points.length);
  }
}
