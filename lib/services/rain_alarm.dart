import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../core/constants.dart';
import '../data/db/app_database.dart';
import '../data/models/place.dart';
import '../data/models/settings.dart';
import '../data/net/cached_fetcher.dart';
import '../data/net/http.dart';
import 'notification_service.dart';

enum RainAlarmKind { rain, heavyRain, thunderstorm, wind }

/// What the coming weather looks like for the alarm place.
class RainAlarmEvent {
  const RainAlarmEvent({
    required this.kind,
    required this.startSec,
    required this.minutesUntil,
    this.probability,
    this.mmPer15,
    this.gustKmh,
  });

  final RainAlarmKind kind;
  final int startSec;
  final int minutesUntil;
  final int? probability;
  final double? mmPer15;
  final double? gustKmh;
}

/// Forecast steps the alarm looks at (15-minute and hourly).
class RainAlarmData {
  const RainAlarmData({
    required this.currentMm,
    required this.currentCode,
    required this.stepTimes,
    required this.stepMm,
    required this.stepCode,
    required this.stepGust,
    required this.hourTimes,
    required this.hourProb,
  });

  final double currentMm;
  final int? currentCode;
  final List<int> stepTimes;
  final List<double> stepMm;
  final List<int?> stepCode;
  final List<double?> stepGust;
  final List<int> hourTimes;
  final List<int?> hourProb;

  static RainAlarmData? parse(Object? json) {
    if (json is! Map) return null;
    final cur = json['current'];
    final m = json['minutely_15'];
    final h = json['hourly'];
    if (cur is! Map || m is! Map || m['time'] is! List) return null;
    double d(Object? v) => v is num ? v.toDouble() : 0.0;
    double? dn(Object? v) => v is num ? v.toDouble() : null;
    int? i(Object? v) => v is num ? v.round() : null;
    List<Object?> list(Map src, String k) => src[k] is List ? src[k] as List : const [];
    final times = [for (final t in m['time'] as List) (t as num).toInt()];
    Object? at(List<Object?> l, int k) => k < l.length ? l[k] : null;
    final mm = list(m, 'precipitation');
    final code = list(m, 'weather_code');
    final gust = list(m, 'wind_gusts_10m');
    final hTimes = h is Map && h['time'] is List ? [for (final t in h['time'] as List) (t as num).toInt()] : <int>[];
    final hProb = h is Map ? list(h, 'precipitation_probability') : const <Object?>[];
    return RainAlarmData(
      currentMm: d(cur['precipitation']),
      currentCode: i(cur['weather_code']),
      stepTimes: times,
      stepMm: [for (var k = 0; k < times.length; k++) d(at(mm, k))],
      stepCode: [for (var k = 0; k < times.length; k++) i(at(code, k))],
      stepGust: [for (var k = 0; k < times.length; k++) dn(at(gust, k))],
      hourTimes: hTimes,
      hourProb: [for (var k = 0; k < hTimes.length; k++) i(at(hProb, k))],
    );
  }

  int? probabilityAt(int sec) {
    for (var k = hourTimes.length - 1; k >= 0; k--) {
      if (hourTimes[k] <= sec) return hourProb[k];
    }
    return hourProb.isEmpty ? null : hourProb.first;
  }
}

bool _isRainCode(int? c) => c != null && ((c >= 51 && c <= 67) || (c >= 80 && c <= 82) || c >= 95);
bool _isThunder(int? c) => c != null && c >= 95;

/// Strong-gust threshold for a "storm" alarm (km/h).
const double stormGustKmh = 55;

/// Finds the first rain/storm expected within [settings]' lead time, or null.
/// No alarm while it is already raining (the rain has arrived).
RainAlarmEvent? evaluateRainAlarm(RainAlarmData data, AppSettings settings, int nowSec) {
  if (data.currentMm >= 0.1 || _isRainCode(data.currentCode)) return null;
  final lead = settings.rainAlarmLeadMinutes * 60;
  for (var k = 0; k < data.stepTimes.length; k++) {
    final t = data.stepTimes[k];
    // A step that has started still counts (its rain is still ahead).
    if (t + 900 <= nowSec) continue;
    if (t - nowSec > lead) break;
    final minutes = ((t - nowSec) / 60).round().clamp(0, 100000);
    final prob = data.probabilityAt(t);
    final mm = data.stepMm[k];
    final code = data.stepCode[k];
    final gust = data.stepGust[k];
    if (settings.rainAlarmStorms && _isThunder(code)) {
      return RainAlarmEvent(
          kind: RainAlarmKind.thunderstorm, startSec: t, minutesUntil: minutes, probability: prob, mmPer15: mm, gustKmh: gust);
    }
    if (settings.rainAlarmStorms && gust != null && gust >= stormGustKmh) {
      return RainAlarmEvent(
          kind: RainAlarmKind.wind, startSec: t, minutesUntil: minutes, probability: prob, gustKmh: gust);
    }
    // Rain: a real amount, and likely enough (unknown probability needs more rain).
    final likely = prob == null ? mm >= 0.5 : prob >= settings.rainAlarmMinProbability;
    if (mm >= 0.2 && likely) {
      return RainAlarmEvent(
        kind: mm >= 2.0 ? RainAlarmKind.heavyRain : RainAlarmKind.rain,
        startSec: t,
        minutesUntil: minutes,
        probability: prob,
        mmPer15: mm,
        gustKmh: gust,
      );
    }
  }
  return null;
}

String _digits(int v, bool bn) {
  if (!bn) return '$v';
  const d = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
  return '$v'.split('').map((c) => d[int.parse(c)]).join();
}

/// "45 minutes" / "1 hour 15 minutes" / "within minutes".
String formatLead(int minutes, bool bn) {
  if (minutes < 5) return bn ? 'কয়েক মিনিটের মধ্যে' : 'within minutes';
  final rounded = (minutes / 5).round() * 5;
  final h = rounded ~/ 60;
  final m = rounded % 60;
  if (bn) {
    final parts = [if (h > 0) '${_digits(h, true)} ঘণ্টা', if (m > 0) '${_digits(m, true)} মিনিট'];
    return '${parts.join(' ')} পর';
  }
  final parts = [if (h > 0) '$h hour${h > 1 ? 's' : ''}', if (m > 0) '$m minutes'];
  return 'in ${parts.join(' ')}';
}

/// Title and spoken/body text of the alarm.
(String, String) rainAlarmText(RainAlarmEvent e, String placeName, bool bn) {
  final when = formatLead(e.minutesUntil, bn);
  final what = switch (e.kind) {
    RainAlarmKind.thunderstorm => bn ? 'বজ্রসহ ঝড়-বৃষ্টি' : 'Thunderstorm',
    RainAlarmKind.wind => bn ? 'ঝোড়ো হাওয়া' : 'Strong wind',
    RainAlarmKind.heavyRain => bn ? 'ভারী বৃষ্টি' : 'Heavy rain',
    RainAlarmKind.rain => bn ? 'বৃষ্টি' : 'Rain',
  };
  final title = bn ? '⚠️ $placeName: $what আসছে' : '⚠️ $placeName: $what coming';
  final extras = <String>[
    if (e.probability != null) bn ? 'সম্ভাবনা ${_digits(e.probability!, true)}%' : 'chance ${e.probability}%',
    if (e.gustKmh != null && e.gustKmh! >= stormGustKmh)
      bn
          ? 'দমকা হাওয়া ঘণ্টায় ${_digits(e.gustKmh!.round(), true)} কিমি'
          : 'gusts ${e.gustKmh!.round()} km/h',
  ];
  final body = bn
      ? '$placeName-এ প্রায় $when $what হতে পারে।${extras.isEmpty ? '' : ' (${extras.join(', ')})'}'
      : '$what expected in $placeName $when.${extras.isEmpty ? '' : ' (${extras.join(', ')})'}';
  return (title, body);
}

/// Downloads the next 3 hours for the alarm place and sounds the alarm.
class RainAlarmService {
  RainAlarmService._();

  static Future<RainAlarmData?> fetch(CachedFetcher fetcher, Place place) async {
    final r = await fetcher.getJson(
      Endpoints.openMeteoForecast,
      query: withOpenMeteoKey({
        'latitude': place.lat.toStringAsFixed(4),
        'longitude': place.lon.toStringAsFixed(4),
        'current': 'precipitation,weather_code',
        'minutely_15': 'precipitation,weather_code,wind_gusts_10m',
        'forecast_minutely_15': 12,
        'hourly': 'precipitation_probability',
        'forecast_hours': 4,
        'wind_speed_unit': 'kmh',
        'timezone': 'auto',
        'timeformat': 'unixtime',
      }),
      // Checked every 15 minutes; always ask for the newest run.
      maxAge: const Duration(minutes: 5),
    );
    return RainAlarmData.parse(r.data);
  }

  /// Background check. Returns true if the alarm went off.
  static Future<bool> check({
    required CachedFetcher fetcher,
    required AppDatabase database,
    required AppSettings settings,
    required String language,
  }) async {
    final place = settings.rainAlarmPlace;
    if (!settings.rainAlarmEnabled || place == null) return false;
    final data = await fetch(fetcher, place);
    if (data == null) return false;
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final event = evaluateRainAlarm(data, settings, nowSec);
    if (event == null) return false;
    // One alarm per rain spell: forecasts shift, so nearby hours count as the same.
    final bucket = event.startSec ~/ 3600;
    for (final b in [bucket - 1, bucket, bucket + 1]) {
      if (await database.wasNotified('rainalarm:${place.id}:$b')) return false;
    }
    await database.markNotified('rainalarm:${place.id}:$bucket');
    await ring(event, place.name, language, voice: settings.rainAlarmVoice);
    return true;
  }

  /// Sounds the alarm notification and, if wanted, speaks the warning.
  static Future<void> ring(RainAlarmEvent event, String placeName, String language,
      {bool voice = true}) async {
    final bn = language == 'bn';
    final (title, body) = rainAlarmText(event, placeName, bn);
    await NotificationService.instance.showAlarm(
      id: 'rainalarm'.hashCode & 0x7fffffff,
      title: title,
      body: body,
      bengali: bn,
    );
    if (voice) await speak(body, bn ? rainAlarmText(event, placeName, false).$2 : null);
  }

  /// Speaks [text]; when it is Bengali and the phone has no Bengali voice,
  /// speaks [englishFallback] instead.
  static Future<void> speak(String text, String? englishFallback) async {
    try {
      final tts = FlutterTts();
      await tts.awaitSpeakCompletion(true);
      var lang = englishFallback == null ? 'en-US' : 'bn-BD';
      if (englishFallback != null && (await tts.isLanguageAvailable('bn-BD')) != true) {
        if ((await tts.isLanguageAvailable('bn-IN')) == true) {
          lang = 'bn-IN';
        } else {
          lang = 'en-US';
          text = englishFallback;
        }
      }
      await tts.setLanguage(lang);
      await tts.setSpeechRate(0.45);
      // Say it twice, like an announcement.
      await tts.speak(text);
      await Future<void>.delayed(const Duration(milliseconds: 700));
      await tts.speak(text);
    } catch (e) {
      debugPrint('Speech failed: $e');
    }
  }
}
