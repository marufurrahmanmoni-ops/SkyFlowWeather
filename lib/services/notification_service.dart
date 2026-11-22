import 'dart:typed_data';

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

  static const String alarmChannelId = 'rain_alarm';

  /// Alarm-style notification: alarm sound repeating (up to a minute),
  /// vibration, shown over the lock screen, with a Stop button.
  Future<void> showAlarm({
    required int id,
    required String title,
    required String body,
    required bool bengali,
  }) async {
    await init();
    if (!_initialized) return;
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        alarmChannelId,
        bengali ? 'বৃষ্টি ও ঝড় অ্যালার্ম' : 'Rain & storm alarm',
        channelDescription:
            bengali ? 'বাছাই করা এলাকায় বৃষ্টি বা ঝড় আসার আগে অ্যালার্ম' : 'Alarm before rain or storms reach your area',
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
        playSound: true,
        sound: const UriAndroidNotificationSound('content://settings/system/alarm_alert'),
        audioAttributesUsage: AudioAttributesUsage.alarm,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 900, 500, 900, 500, 900]),
        // FLAG_INSISTENT: keep ringing until the user reacts (or the timeout).
        additionalFlags: Int32List.fromList([4]),
        timeoutAfter: 60000,
        visibility: NotificationVisibility.public,
        styleInformation: BigTextStyleInformation(body),
        actions: [
          AndroidNotificationAction('stop', bengali ? 'বন্ধ করুন' : 'Stop', cancelNotification: true),
        ],
      ),
    );
    await _plugin.show(id: id, title: title, body: body, notificationDetails: details);
  }
}
