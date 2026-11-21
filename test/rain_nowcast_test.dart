import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:skyflow_weather/core/l10n/app_strings.dart';
import 'package:skyflow_weather/data/sources/rain_nowcast.dart';
import 'package:skyflow_weather/services/home_widget_service.dart';

void main() {
  const now = 1000000;

  Map<String, dynamic> point({
    double current = 0,
    int code = 3,
    List<double> steps = const [0, 0, 0.3, 0.8, 0.2, 0, 0, 0],
    List<int> prob = const [40, 70],
  }) =>
      {
        'latitude': 23.81,
        'longitude': 90.41,
        'utc_offset_seconds': 21600,
        'current': {'time': now, 'precipitation': current, 'weather_code': code},
        'minutely_15': {
          'time': [for (var i = 0; i < steps.length; i++) now + i * 900],
          'precipitation': steps,
        },
        'hourly': {
          'time': [now, now + 3600],
          'precipitation_probability': prob,
        },
      };

  test('parses a single point and finds when rain starts', () {
    final r = parseRainNowcast(jsonDecode(jsonEncode(point())), 1).single!;
    expect(r.rainingNow, isFalse);
    expect(r.minutesUntilRain(now), 30);
    expect(r.next2hMm, closeTo(1.3, 1e-9));
    expect(r.probability, 70);
    expect(r.intensity, 2);
    expect(r.minutesUntilDry(now), isNull);
  });

  test('raining now: reports when it stops', () {
    final r = parseRainNowcast(
      point(current: 0.5, code: 61, steps: const [0.5, 0.4, 0, 0, 0, 0, 0, 0]),
      1,
    ).single!;
    expect(r.rainingNow, isTrue);
    expect(r.minutesUntilRain(now), 0);
    expect(r.minutesUntilDry(now), 30);
  });

  test('dry forecast and many points with a missing one', () {
    final dry = point(steps: List.filled(8, 0.0), prob: const [5, 10]);
    final list = parseRainNowcast([dry, 'bad'], 3);
    expect(list, hasLength(3));
    expect(list[0]!.minutesUntilRain(now), isNull);
    expect(list[0]!.intensity, 0);
    expect(list[1], isNull);
    expect(list[2], isNull);
  });

  test('rain weather codes', () {
    expect(RainNowcast.isRainCode(61), isTrue);
    expect(RainNowcast.isRainCode(95), isTrue);
    expect(RainNowcast.isRainCode(3), isFalse);
    expect(RainNowcast.isRainCode(71), isFalse); // snow
  });

  test('city list covers all eight divisions', () {
    final names = bdCities.map((c) => c.nameEn).toSet();
    for (final d in ['Dhaka', 'Chattogram', 'Khulna', 'Rajshahi', 'Sylhet', 'Barishal', 'Rangpur', 'Mymensingh']) {
      expect(names, contains(d));
    }
  });

  test('widget rain line and emoji, in English and Bengali', () {
    final soon = parseRainNowcast(point(), 1).single!;
    expect(HomeWidgetService.rainLine(AppStrings('en'), soon, now), 'Rain in ~30 min');
    expect(HomeWidgetService.rainLine(AppStrings('bn'), soon, now), 'প্রায় ৩০ মিনিটে বৃষ্টি');
    final dry = parseRainNowcast(point(steps: List.filled(8, 0.0)), 1).single!;
    expect(HomeWidgetService.rainLine(AppStrings('en'), dry, now), 'No rain in the next 2 h');
    expect(HomeWidgetService.emojiFor(0, true), '☀️');
    expect(HomeWidgetService.emojiFor(0, false), '🌙');
    expect(HomeWidgetService.emojiFor(95, true), '⛈️');
  });
}
