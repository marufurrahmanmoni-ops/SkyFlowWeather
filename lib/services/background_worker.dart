import 'package:flutter/foundation.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:workmanager/workmanager.dart';

import '../core/format.dart';
import '../core/l10n/app_strings.dart';
import '../data/db/app_database.dart';
import '../data/models/settings.dart';
import '../data/models/warnings.dart';
import '../data/net/cached_fetcher.dart';
import '../data/net/http.dart';
import '../data/sources/open_meteo.dart';
import '../data/sources/warnings_sources.dart';
import '../state/providers.dart' show bmdWarningSource, buildWarningSources, loadSettings, resolveLanguage;
import 'alert_engine.dart';
import 'alert_text.dart';
import 'home_widget_service.dart';
import 'rain_alarm.dart';
import 'notification_service.dart';

const String _uniqueName = 'skyflow-alert-check';
const String _taskName = 'skyflow.alertCheck';

/// Entry point for background alert checks (runs in its own isolate).
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await AlertChecker.run();
    } catch (e) {
      debugPrint('Background alert check failed: $e');
    }
    return true;
  });
}

class BackgroundWorker {
  BackgroundWorker._();

  static Future<void> initialize() async {
    try {
      await Workmanager().initialize(callbackDispatcher);
    } catch (e) {
      debugPrint('Workmanager init failed: $e');
    }
  }

  /// Schedules the periodic check to match [settings]: every 30 minutes
  /// while BMD warnings are on (cyclone signals change fast), otherwise
  /// every 3 hours for favourite alerts. The same run refreshes the
  /// home-screen widget, so it also runs when only the widget needs it.
  static Future<void> sync(AppSettings settings) => _schedule(
        settings.rainAlarmEnabled
            // The shortest period Android allows; rain can arrive within the hour.
            ? const Duration(minutes: 15)
            : settings.bmdAllWarnings
                ? const Duration(minutes: 30)
                : const Duration(hours: 3),
      );


  static Future<void> _schedule(Duration? frequency) async {
    try {
      if (frequency != null) {
        await Workmanager().registerPeriodicTask(
          _uniqueName,
          _taskName,
          frequency: frequency,
          constraints: Constraints(networkType: NetworkType.connected),
          existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
        );
      } else {
        await Workmanager().cancelByUniqueName(_uniqueName);
      }
    } catch (e) {
      debugPrint('Workmanager schedule failed: $e');
    }
  }
}

/// Checks every favourite with alerts enabled and posts a notification for
/// each new forecast alert or official warning (de-duplicated).
class AlertChecker {
  AlertChecker._();

  static Future<int> run({AppDatabase? db, CachedFetcher? fetcher}) async {
    // Needed in the background isolate for Bengali/English date formats.
    await initializeDateFormatting();
    final database = db ?? await AppDatabase.open();
    final settings = await loadSettings(database);
    final lang = resolveLanguage(settings.language);
    final strings = AppStrings(lang);
    final units = settings.formatter(lang);
    final fmt = TimeFmt(locale: lang, use24h: settings.use24h);
    final f = fetcher ?? CachedFetcher(HttpClientFactory.create(), database);
    final forecastSource = OpenMeteoForecastSource(f);
    final warnings = WarningService(buildWarningSources(f, GdacsSource(f)));
    const engine = AlertEngine();
    // The rain alarm is the most time-critical, so it goes first.
    if (settings.rainAlarmEnabled) {
      try {
        await RainAlarmService.check(
            fetcher: f, database: database, settings: settings, language: lang);
      } catch (e) {
        debugPrint('Rain alarm check failed: $e');
      }
    }
    // The home-screen widget is refreshed on every run.
    await HomeWidgetService.refresh(fetcher: f, settings: settings, language: lang);

    var sent = 0;
    if (settings.bmdAllWarnings) {
      sent += await _notifyBmd(database, f, strings, lang);
    }
    if (!settings.backgroundAlerts) return sent;
    final favorites = (await database.favorites()).where((x) => x.alertRules.enabled).toList();
    if (favorites.isEmpty) return sent;
    await NotificationService.instance.init();

    for (final fav in favorites) {
      final name = fav.displayName;
      try {
        final fc = await forecastSource.alertForecast(fav.place);
        for (final a in engine.evaluate(fc, fav.alertRules, hoursAhead: 36)) {
          final key = 'fc:${fav.id}:${a.dedupeKey}';
          if (await database.wasNotified(key)) continue;
          await NotificationService.instance.show(
            id: key.hashCode & 0x7fffffff,
            title: '$name · ${warningKindLabel(strings, a.kind)}',
            body: '${forecastAlertText(strings, units, fmt, a)}\n${strings.forecastAlertDisclaimer}',
            strings: strings,
          );
          await database.markNotified(key);
          sent++;
        }
      } catch (e) {
        debugPrint('Forecast alert check failed for $name: $e');
      }
      try {
        final result = await warnings.forPlace(fav.place, language: lang);
        for (final w in engine.filterOfficial(result.warnings, fav.alertRules)) {
          // Already sent by the all-BMD check.
          if (settings.bmdAllWarnings && w.source == 'BMD') continue;
          final key = 'w:${fav.id}:${w.id}';
          if (await database.wasNotified(key)) continue;
          await NotificationService.instance.show(
            id: key.hashCode & 0x7fffffff,
            title: '${w.source}: ${w.headline}',
            body: [name, if (w.areaDesc != null) w.areaDesc!, if (w.description != null) w.description!]
                .join('\n'),
            strings: strings,
            urgent: w.severity == WarningSeverity.extreme || w.severity == WarningSeverity.severe,
          );
          await database.markNotified(key);
          sent++;
        }
      } catch (e) {
        debugPrint('Official warning check failed for $name: $e');
      }
    }
    return sent;
  }

  /// Posts a notification for every BMD warning not notified before.
  static Future<int> _notifyBmd(
      AppDatabase database, CachedFetcher f, AppStrings strings, String lang) async {
    try {
      final bmd = bmdWarningSource(f);
      final list = await bmd.allActive(language: lang);
      if (list.isEmpty) return 0;
      await NotificationService.instance.init();
      var sent = 0;
      for (final w in list) {
        final key = 'bmd:${w.id}';
        if (await database.wasNotified(key)) continue;
        await NotificationService.instance.show(
          id: key.hashCode & 0x7fffffff,
          title: 'BMD: ${w.headline}',
          body: [if (w.areaDesc != null) w.areaDesc!, if (w.description != null) w.description!]
              .join('\n'),
          strings: strings,
          urgent: w.severity == WarningSeverity.extreme || w.severity == WarningSeverity.severe,
        );
        await database.markNotified(key);
        sent++;
      }
      return sent;
    } catch (e) {
      debugPrint('BMD warning check failed: $e');
      return 0;
    }
  }
}
