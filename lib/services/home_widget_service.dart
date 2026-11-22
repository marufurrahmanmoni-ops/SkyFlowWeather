import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../core/constants.dart';
import '../core/format.dart';
import '../core/l10n/app_strings.dart';
import '../core/units.dart';
import '../data/models/forecast.dart';
import '../data/models/place.dart';
import '../data/models/settings.dart';
import '../data/models/weather_code.dart';
import '../data/net/cached_fetcher.dart';
import '../data/sources/open_meteo.dart';
import '../data/sources/rain_nowcast.dart';
import '../data/sources/warnings_sources.dart';

/// Keeps the Android home-screen widget (SkyFlowWidgetProvider) up to date.
/// Works from the app and from the background worker.
class HomeWidgetService {
  HomeWidgetService._();

  static const String androidName = 'SkyFlowWidgetProvider';
  static const String largeAndroidName = 'SkyFlowLargeWidgetProvider';
  static const String packageName = 'com.skyflow.weather';

  static Future<bool> canPin() async {
    try {
      return await HomeWidget.isRequestPinWidgetSupported() ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Asks the launcher to add a widget (large or small). Not every launcher supports it.
  static Future<void> pin({required bool large}) => HomeWidget.requestPinWidget(
        qualifiedAndroidName: '$packageName.${large ? largeAndroidName : androidName}',
      );

  /// Dhaka, used before the user has picked a place.
  static const Place fallbackPlace = Place(
    id: 'bd:dhaka',
    name: 'Dhaka',
    lat: 23.8103,
    lon: 90.4125,
    country: 'Bangladesh',
    countryCode: 'BD',
  );

  static String emojiFor(int? code, bool isDay) {
    if (code == null) return '☁️';
    switch (WeatherCodes.icon(code)) {
      case WxIcon.clear:
        return isDay ? '☀️' : '🌙';
      case WxIcon.mainlyClear:
        return isDay ? '🌤️' : '🌙';
      case WxIcon.partlyCloudy:
        return isDay ? '⛅' : '☁️';
      case WxIcon.overcast:
        return '☁️';
      case WxIcon.fog:
        return '🌫️';
      case WxIcon.drizzle:
      case WxIcon.showers:
        return '🌦️';
      case WxIcon.rain:
      case WxIcon.heavyRain:
      case WxIcon.freezingRain:
        return '🌧️';
      case WxIcon.snow:
      case WxIcon.snowShowers:
        return '🌨️';
      case WxIcon.thunder:
      case WxIcon.thunderHail:
        return '⛈️';
    }
  }

  /// Short "rain in 30 min" / "rain stops in 45 min" / "no rain for 2 h" line.
  static String rainLine(AppStrings s, RainNowcast? n, int nowSec) {
    if (n == null) return '';
    final stop = n.minutesUntilDry(nowSec);
    if (n.rainingNow) return stop == null ? s.rainContinuing : s.rainStopsIn(stop);
    final start = n.minutesUntilRain(nowSec);
    if (start != null) return s.rainStartsIn(start);
    return s.noRainNext2h;
  }

  /// Downloads the weather for [place] and redraws both widgets.
  static Future<void> refresh({
    required CachedFetcher fetcher,
    required AppSettings settings,
    required String language,
    Place? place,
  }) async {
    final p = place ?? settings.lastPlace ?? fallbackPlace;
    try {
      final strings = AppStrings(language);
      final bn = language == 'bn';
      final units = settings.formatter(language);
      final fmt = TimeFmt(locale: language, use24h: settings.use24h);
      final (bundle, nowcasts, warnings) = await (
        OpenMeteoForecastSource(fetcher).forecast(p),
        RainNowcastSource(fetcher)
            .fetch([(p.lat, p.lon)])
            .catchError((Object _) => <RainNowcast?>[null]),
        _warnings(fetcher, p, language),
      ).wait;
      final f = bundle.forecast;
      final nowcast = nowcasts.firstOrNull;
      final c = f.current;
      final code = c['weather_code']?.round();
      final isDay = (c['is_day'] ?? 1) >= 1;
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      String temp(double? v) => units.format(Quantity.temperature, v);
      DateTime local(int sec) => DateTime.fromMillisecondsSinceEpoch(sec * 1000);

      final data = <String, String>{
        'place': p.name,
        'temp': temp(c['temperature_2m']),
        'condition': code == null ? '' : strings.weatherCode(code),
        'emoji': emojiFor(code, isDay),
        'hilo': '↑${temp(f.daily.at('temperature_2m_max', 0))}  ↓${temp(f.daily.at('temperature_2m_min', 0))}',
        'rain': [
          if (nowcast?.probability != null) '💧 ${nowcast!.probability}%',
          rainLine(strings, nowcast, nowSec),
        ].where((x) => x.isNotEmpty).join('  ·  '),
        'updated': strings.widgetUpdated(fmt.hm(DateTime.now())),
        'isDay': isDay ? '1' : '0',
        // Large widget.
        'feels': '${bn ? 'অনুভূত' : 'Feels'} ${temp(c['apparent_temperature'])}',
        'humidity': '💧 ${units.format(Quantity.percent, c['relative_humidity_2m'])}',
        'wind': '💨 ${units.format(Quantity.speed, c['wind_speed_10m'])}'
            '${c['wind_direction_10m'] == null ? '' : ' ${compassLabel(c['wind_direction_10m']!)}'}',
        'uv': '☀️ UV ${c['uv_index'] == null ? '–' : units.number(c['uv_index']!)}',
        'aqi': _aqiText(bundle.airQuality?.current['us_aqi'], strings, units),
        'sun': _sunText(f.daily, fmt, local),
        'warning': warnings,
      };
      // Next five hours.
      final h = f.hourly;
      final h0 = h.isEmpty ? 0 : h.indexFor(nowSec);
      for (var i = 0; i < 5; i++) {
        final k = h0 + 1 + i;
        final ok = k < h.length;
        data['h${i}_time'] = ok ? fmt.hour(local(h.time[k])) : '';
        data['h${i}_emoji'] = ok
            ? emojiFor(h.at('weather_code', k)?.round(), (h.at('is_day', k) ?? 1) >= 1)
            : '';
        data['h${i}_temp'] = ok ? temp(h.at('temperature_2m', k)) : '';
      }
      // Next three days (from tomorrow; today is in the header).
      final d = f.daily;
      for (var i = 0; i < 3; i++) {
        final k = i + 1;
        final ok = k < d.length;
        data['d${i}_name'] = ok ? fmt.weekday(local(d.time[k])) : '';
        data['d${i}_emoji'] = ok ? emojiFor(d.at('weather_code', k)?.round(), true) : '';
        final prob = ok ? d.at('precipitation_probability_max', k) : null;
        data['d${i}_rain'] = prob == null ? '' : '💧${prob.round()}%';
        data['d${i}_hilo'] = ok
            ? '${temp(d.at('temperature_2m_max', k))} / ${temp(d.at('temperature_2m_min', k))}'
            : '';
      }
      await _save(data);
    } catch (e) {
      debugPrint('Widget refresh failed: $e');
    }
  }

  static String _aqiText(double? us, AppStrings s, UnitFormatter units) {
    if (us == null) return '🫁 AQI –';
    final cat = us <= 50 ? 0 : us <= 100 ? 1 : us <= 150 ? 2 : us <= 200 ? 3 : us <= 300 ? 4 : 5;
    const dots = ['🟢', '🟡', '🟠', '🔴', '🟣', '🟤'];
    return '${dots[cat]} AQI ${units.number(us)}';
  }

  static String _sunText(TimeSeries daily, TimeFmt fmt, DateTime Function(int) local) {
    final rise = daily.at('sunrise', 0);
    final set = daily.at('sunset', 0);
    if (rise == null || set == null) return '';
    return '🌅 ${fmt.hm(local(rise.round()))}   🌇 ${fmt.hm(local(set.round()))}';
  }

  /// First active BMD warning that covers [place] (Bangladesh only).
  static Future<String> _warnings(CachedFetcher fetcher, Place place, String language) async {
    if (place.countryCode != null && place.countryCode != 'BD') return '';
    try {
      final list = await bmdWarningSourceFor(fetcher).activeFor(place, language: language);
      return list.isEmpty ? '' : '⚠️ ${list.first.headline}';
    } catch (_) {
      return '';
    }
  }

  static Future<void> _save(Map<String, String> data) async {
    for (final e in data.entries) {
      await HomeWidget.saveWidgetData<String>(e.key, e.value);
    }
    await HomeWidget.updateWidget(androidName: androidName);
    await HomeWidget.updateWidget(androidName: largeAndroidName);
  }
}

/// The BMD CAP feed (same settings as the app's warning list).
CapRssWarningSource bmdWarningSourceFor(CachedFetcher fetcher) => CapRssWarningSource(
      fetcher: fetcher,
      id: 'BMD',
      label: 'Bangladesh Meteorological Department',
      feedUrl: Endpoints.bmdCapRss,
      countryCode: 'BD',
      region: bangladeshRegion,
      maxItems: 15,
    );
