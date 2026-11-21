import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/l10n/app_strings.dart';

/// Local notifications for weather alerts.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const String channelId = 'weather_alerts';

  Future<void> init() async {
    if (_initialized) return;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@drawable/ic_stat_skyflow'),
        ),
      );
      _initialized = true;
    } catch (e) {
      debugPrint('Notification init failed: $e');
    }
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  /// Asks for the Android 13+ notification permission. Returns true if
  /// notifications may be shown.
  Future<bool> requestPermission() async {
    await init();
    try {
      final granted = await _android?.requestNotificationsPermission();
      return granted ?? true;
    } catch (_) {
      return false;
    }
  }

  Future<void> show({
    required int id,
    required String title,
    required String body,
    required AppStrings strings,
    bool urgent = false,
  }) async {
    await init();
    if (!_initialized) return;
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        strings.notificationChannelName,
        channelDescription: strings.notificationChannelDesc,
        importance: urgent ? Importance.max : Importance.high,
        priority: urgent ? Priority.max : Priority.high,
        styleInformation: BigTextStyleInformation(body),
      ),
    );
    await _plugin.show(id: id, title: title, body: body, notificationDetails: details);
  }
}
