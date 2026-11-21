import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'data/db/app_database.dart';
import 'data/sources/open_meteo.dart' show gridCachePrefix;
import 'services/background_worker.dart';
import 'services/notification_service.dart';
import 'state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Only what the first frame needs is awaited; the rest runs after runApp.
  final (_, db) = await (
    // The app only ships English and Bengali.
    Future.wait([initializeDateFormatting('en'), initializeDateFormatting('bn')]),
    AppDatabase.open(),
  ).wait;
  final settings = await loadSettings(db);

  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        initialSettingsProvider.overrideWithValue(settings),
      ],
      // The HTTP layer already retries transient failures.
      retry: (retryCount, error) => null,
      child: const SkyFlowApp(),
    ),
  );

  // Drop old cached responses to keep storage small (map grids go stale fast).
  unawaited(db.pruneCache(const Duration(days: 7)).catchError((Object _) {}));
  unawaited(db.pruneCachePrefix(gridCachePrefix, const Duration(hours: 12)).catchError((Object _) {}));
  unawaited(NotificationService.instance.init().then((_) {
    // BMD warnings are on by default, so ask once for notification access.
    if (settings.bmdAllWarnings) return NotificationService.instance.requestPermission();
  }));
  unawaited(BackgroundWorker.initialize().then((_) => BackgroundWorker.sync(settings)));
}
