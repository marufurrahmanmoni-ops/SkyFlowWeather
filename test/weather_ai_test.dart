import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:skyflow_weather/data/models/forecast.dart';
import 'package:skyflow_weather/data/models/settings.dart';
import 'package:skyflow_weather/data/models/warnings.dart';
import 'package:skyflow_weather/data/sources/rain_nowcast.dart';
import 'package:skyflow_weather/services/radar_analyzer.dart';
import 'package:skyflow_weather/services/weather_ai.dart';

void main() {
  // 2026-11-22 00:00 UTC (06:00 in Dhaka).
  const now = 1795305600;
  const offset = 21600;

  OmResponse forecast({List<double>? precip, List<int>? prob, List<int>? codes, double max = 30}) {
    final hours = 48;
    return OmResponse.fromJson({
      'latitude': 23.8,
      'longitude': 90.4,
      'utc_offset_seconds': offset,
      'current': {
        'time': now,
        'temperature_2m': 24.0,
        'apparent_temperature': 25.0,
        'relative_humidity_2m': 70,
        'wind_speed_10m': 8.0,
        'wind_direction_10m': 180,
        'weather_code': 2,
      },
      'hourly': {
        'time': [for (var i = 0; i < hours; i++) now + i * 3600],
        'precipitation': precip ?? List.filled(hours, 0.0),
        'precipitation_probability': prob ?? List.filled(hours, 5),
        'weather_code': codes ?? List.filled(hours, 2),
      },
      'daily': {
        'time': [for (var d = 0; d < 4; d++) now - offset + d * 86400],
        'temperature_2m_max': [max, 29, 28, 27],
        'temperature_2m_min': [18, 18, 17, 17],
        'precipitation_sum': [0, 0, 50, 0],
        'precipitation_probability_max': [5, 10, 90, 5],
        'weather_code': [2, 2, 63, 1],
      },
    }, fetchedAt: DateTime.now());
  }

  WeatherAi ai(WeatherAiInput input, {bool bn = true}) =>
      WeatherAi(input, bengali: bn, units: const AppSettings().formatter(bn ? 'bn' : 'en'));

  test('dry day: Bengali bulletin with Bengali digits and the three days', () {
    final b = ai(WeatherAiInput(placeName: 'ঢাকা', forecast: forecast(), nowSec: now)).build();
    expect(b.headline, contains('শুকনো'));
    expect(b.headline, isNot(matches(RegExp('[0-9]'))));
    final titles = b.sections.map((s) => s.title).toList();
    expect(titles, containsAll(['এখন', 'আজ ও আজ রাত', 'আগামী ৩ দিন']));
    final days = b.sections.firstWhere((s) => s.title == 'আগামী ৩ দিন').lines;
    expect(days, hasLength(3));
    expect(days[1], contains('ভারী বৃষ্টি')); // 50 mm on day 2 = BMD "heavy"
  });

  test('afternoon thunderstorm becomes the headline with its time window', () {
    final precip = List<double>.filled(48, 0);
    final prob = List<int>.filled(48, 5);
    final codes = List<int>.filled(48, 2);
    for (final i in [9, 10]) {
      // 15:00–17:00 local
      precip[i] = 3;
      prob[i] = 80;
      codes[i] = 95;
    }
    final b = ai(WeatherAiInput(
      placeName: 'ঢাকা',
      forecast: forecast(precip: precip, prob: prob, codes: codes),
      nowSec: now,
    )).build();
    expect(b.headline, contains('বজ্রসহ বৃষ্টি'));
    expect(b.headline, contains('বিকেল'));
    final risks = b.sections.firstWhere((s) => s.title == 'ঝুঁকি ও পরামর্শ').lines;
    expect(risks.first, contains('বজ্রপাত'));
  });

  test('nowcast rain soon wins the headline; heat wave is named in English too', () {
    final n = parseRainNowcast({
      'latitude': 23.8,
      'longitude': 90.4,
      'current': {'precipitation': 0, 'weather_code': 3},
      'minutely_15': {
        'time': [for (var i = 0; i < 8; i++) now + i * 900],
        'precipitation': [0, 0, 0.6, 1, 0, 0, 0, 0],
      },
      'hourly': {'precipitation_probability': [60, 80]},
    }, 1).single;
    final b = ai(WeatherAiInput(placeName: 'Dhaka', forecast: forecast(max: 41), nowSec: now, nowcast: n),
            bn: false)
        .build();
    expect(b.headline, 'Rain likely in Dhaka in about 30 minutes.');
    final risks = b.sections.firstWhere((s) => s.title == 'Risks & advice').lines;
    expect(risks.any((l) => l.contains('severe heat wave')), isTrue);
  });

  test('cyclone in the Bay of Bengal leads, and model agreement gives confidence', () {
    const storm = DisasterEvent(
      eventType: 'TC',
      eventId: 1,
      episodeId: 1,
      name: 'MOCHA',
      alertLevel: 'Red',
      lat: 17,
      lon: 90,
    );
    final models = OmResponse.fromJson({
      'utc_offset_seconds': offset,
      'hourly': {
        'time': [for (var i = 0; i < 24; i++) now + i * 3600],
        for (final m in ['a', 'b', 'c', 'd']) 'precipitation_$m': List.filled(24, m == 'd' ? 0.0 : 0.5),
      },
    }, fetchedAt: DateTime.now());
    final b = ai(WeatherAiInput(
      placeName: 'ঢাকা',
      forecast: forecast(),
      nowSec: now,
      storms: const [storm],
      models: models,
      modelIds: const ['a', 'b', 'c', 'd'],
    )).build();
    expect(b.headline, contains('MOCHA'));
    expect(b.confidence, 1); // 3 of 4
    expect(b.sections.last.lines.single, contains('৪টি আবহাওয়া মডেলের ৩টি'));
  });

  test('radar image: coverage per division and movement direction', () {
    const w = 120, h = 120;
    Uint8List frame(double lat0, double lon0) {
      final data = Uint8List(w * h * 4);
      // Paint a rain blob around (lat0, lon0) in the image's Mercator grid.
      final box = radarImageBox;
      for (var py = 0; py < h; py++) {
        for (var px = 0; px < w; px++) {
          final lon = box.west + (box.east - box.west) * (px + 0.5) / w;
          // Latitude roughly (fine for a test).
          final lat = box.north - (box.north - box.south) * (py + 0.5) / h;
          if ((lat - lat0).abs() < 1 && (lon - lon0).abs() < 1) data[(py * w + px) * 4 + 3] = 255;
        }
      }
      return data;
    }

    final t0 = DateTime.utc(2026, 11, 22, 0);
    final a = analyzeRgba(frame(24.4, 91.6), w, h, radarImageBox, t0);
    final b = analyzeRgba(frame(24.4, 92.6), w, h, radarImageBox, t0.add(const Duration(hours: 1)));
    expect(a.regionCoverage['Sylhet']!, greaterThan(0.3));
    expect(a.regionCoverage['Rajshahi'], 0);
    expect(a.bdCoverage, greaterThan(0));
    final r = summarizeFrames([a, b]);
    expect(directionName(r.bearingDeg!, true), 'পূর্ব');
    expect(r.speedKmh!, greaterThan(50));
  });

  test('Bengali digits', () {
    expect(toBnDigits('AQI 152, 30%'), 'AQI ১৫২, ৩০%');
  });
}
