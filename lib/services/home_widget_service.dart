import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../core/format.dart';
import '../core/l10n/app_strings.dart';
import '../core/units.dart';
import '../data/models/place.dart';
import '../data/models/settings.dart';
import '../data/models/weather_code.dart';
import '../data/net/cached_fetcher.dart';
import '../data/sources/open_meteo.dart';
import '../data/sources/rain_nowcast.dart';

/// Keeps the Android home-screen widget (SkyFlowWidgetProvider) up to date.
/// Works from the app and from the background worker.
class HomeWidgetService {
  HomeWidgetService._();

  static const String androidName = 'SkyFlowWidgetProvider';

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

  /// Downloads current weather for [place] and redraws the widget.
  static Future<void> refresh({
    required CachedFetcher fetcher,
    required AppSettings settings,
    required String language,
    Place? place,
  }) async {
    final p = place ?? settings.lastPlace ?? fallbackPlace;
    try {
      final strings = AppStrings(language);
      final units = settings.formatter(language);
      final fmt = TimeFmt(locale: language, use24h: settings.use24h);
      final (currents, nowcasts) = await (
        OpenMeteoForecastSource(fetcher).currentForMany([p]),
        RainNowcastSource(fetcher)
            .fetch([(p.lat, p.lon)])
            .catchError((Object _) => <RainNowcast?>[null]),
      ).wait;
      final current = currents.firstOrNull;
      if (current == null) return;
      final nowcast = nowcasts.firstOrNull;
      final c = current.current;
      final code = c['weather_code']?.round();
      final isDay = (c['is_day'] ?? 1) >= 1;
      final hi = current.daily.at('temperature_2m_max', 0);
      final lo = current.daily.at('temperature_2m_min', 0);
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await _save({
        'place': p.name,
        'temp': units.format(Quantity.temperature, c['temperature_2m']),
        'condition': code == null ? '' : strings.weatherCode(code),
        'emoji': emojiFor(code, isDay),
        'hilo': '↑${units.format(Quantity.temperature, hi)}  ↓${units.format(Quantity.temperature, lo)}',
        'rain': [
          if (nowcast?.probability != null) '💧 ${nowcast!.probability}%',
          rainLine(strings, nowcast, nowSec),
        ].where((x) => x.isNotEmpty).join('  ·  '),
        'updated': strings.widgetUpdated(fmt.hm(DateTime.now())),
        'isDay': isDay ? '1' : '0',
      });
    } catch (e) {
      debugPrint('Widget refresh failed: $e');
    }
  }

  static Future<void> _save(Map<String, String> data) async {
    for (final e in data.entries) {
      await HomeWidget.saveWidgetData<String>(e.key, e.value);
    }
    await HomeWidget.updateWidget(androidName: androidName);
  }
}
