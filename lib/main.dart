import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'data/db/app_database.dart';
import 'services/background_worker.dart';
import 'services/notification_service.dart';
import 'state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();
  final db = await AppDatabase.open();
  final settings = await loadSettings(db);

  // Drop cached responses older than a week to keep storage small.
  unawaited(db.pruneCache(const Duration(days: 7)).catchError((Object _) {}));
  unawaited(NotificationService.instance.init());
  await BackgroundWorker.initialize();
  if (settings.backgroundAlerts) unawaited(BackgroundWorker.setEnabled(true));

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
}
