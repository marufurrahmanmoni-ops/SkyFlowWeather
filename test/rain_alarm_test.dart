import 'package:flutter_test/flutter_test.dart';
import 'package:skyflow_weather/data/models/settings.dart';
import 'package:skyflow_weather/features/air/air_quality_screen.dart';
import 'package:skyflow_weather/services/rain_alarm.dart';

void main() {
  const now = 1000000;
  const settings = AppSettings(rainAlarmEnabled: true, rainAlarmLeadMinutes: 60, rainAlarmMinProbability: 60);

  Map<String, dynamic> json({
    double currentMm = 0,
    int currentCode = 3,
    List<double> mm = const [0, 0, 0, 0.6, 1, 0, 0, 0, 0, 0, 0, 0],
    List<int> codes = const [3, 3, 3, 61, 63, 3, 3, 3, 3, 3, 3, 3],
    List<double> gust = const [20, 20, 20, 25, 30, 20, 20, 20, 20, 20, 20, 20],
    List<int> prob = const [70, 75, 75, 20],
  }) =>
      {
        'current': {'time': now, 'precipitation': currentMm, 'weather_code': currentCode},
        'minutely_15': {
          'time': [for (var i = 0; i < mm.length; i++) now + i * 900],
          'precipitation': mm,
          'weather_code': codes,
          'wind_gusts_10m': gust,
        },
        'hourly': {
          'time': [for (var i = 0; i < prob.length; i++) now + i * 3600],
          'precipitation_probability': prob,
        },
      };

  test('rain 45 minutes ahead rings with the right lead time', () {
    final data = RainAlarmData.parse(json())!;
    final e = evaluateRainAlarm(data, settings, now)!;
    expect(e.kind, RainAlarmKind.rain);
    expect(e.minutesUntil, 45);
    expect(formatLead(e.minutesUntil, true), '৪৫ মিনিট পর');
    expect(formatLead(e.minutesUntil, false), 'in 45 minutes');
    final (title, body) = rainAlarmText(e, 'ঢাকা', true);
    expect(title, contains('ঢাকা'));
    expect(body, contains('৪৫ মিনিট পর'));
  });

  test('outside the lead time or below the probability: no alarm', () {
    final data = RainAlarmData.parse(json())!;
    expect(evaluateRainAlarm(data, settings.copyWith(rainAlarmLeadMinutes: 30), now), isNull);
    // Hour 0 probability is 30% (< 60%).
    final early = RainAlarmData.parse(
        json(mm: const [0, 0.5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], prob: const [30, 75, 75, 20]))!;
    expect(evaluateRainAlarm(early, settings, now), isNull);
    expect(evaluateRainAlarm(early, settings.copyWith(rainAlarmMinProbability: 20), now)?.minutesUntil, 15);
  });

  test('already raining: no alarm', () {
    final data = RainAlarmData.parse(json(currentMm: 0.4, currentCode: 61))!;
    expect(evaluateRainAlarm(data, settings, now), isNull);
  });

  test('thunderstorm and strong gusts ring when storms are on', () {
    final thunder = RainAlarmData.parse(json(
      mm: const [0, 0, 0.1, 0, 0, 0, 0, 0, 0, 0, 0, 0],
      codes: const [3, 3, 95, 3, 3, 3, 3, 3, 3, 3, 3, 3],
    ))!;
    expect(evaluateRainAlarm(thunder, settings, now)?.kind, RainAlarmKind.thunderstorm);
    expect(evaluateRainAlarm(thunder, settings.copyWith(rainAlarmStorms: false), now), isNull);

    final windy = RainAlarmData.parse(json(
      mm: List.filled(12, 0.0),
      gust: const [20, 70, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20],
    ))!;
    final e = evaluateRainAlarm(windy, settings, now)!;
    expect(e.kind, RainAlarmKind.wind);
    expect(rainAlarmText(e, 'Dhaka', false).$2, contains('70 km/h'));
  });

  test('long lead times read as hours and minutes', () {
    expect(formatLead(75, true), '১ ঘণ্টা ১৫ মিনিট পর');
    expect(formatLead(120, false), 'in 2 hours');
    expect(formatLead(2, true), 'কয়েক মিনিটের মধ্যে');
  });

  test('settings round-trip keeps the alarm', () {
    final s = AppSettings.fromJson(
        settings.copyWith(rainAlarmVoice: false, rainAlarmLeadMinutes: 120).toJson());
    expect(s.rainAlarmEnabled, isTrue);
    expect(s.rainAlarmVoice, isFalse);
    expect(s.rainAlarmLeadMinutes, 120);
    expect(s.bmdAllWarnings, isTrue);
  });

  test('AQI: main pollutant and EU bands', () {
    expect(dominantPollutant({'us_aqi_pm2_5': 160, 'us_aqi_ozone': 40})!.symbol, 'PM2.5');
    expect(dominantPollutant({}), isNull);
    expect(euCategoryIndex(15), 0);
    expect(euCategoryIndex(55), 2);
    expect(euCategoryIndex(130), 5);
  });
}
