import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'notification_service.g.dart';

// 1. Create the provider
@Riverpod(keepAlive: true)
NotificationService notificationService(Ref ref) {
  return NotificationService();
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// Returns the payload (route) if the app was launched by a notification
  Future<String?> init() async {
    tz.initializeTimeZones();

    String timeZoneName;
    try {
      final timezoneResult = await FlutterTimezone.getLocalTimezone();
      timeZoneName = timezoneResult.identifier;
    } catch (e) {
      timeZoneName = 'UTC';
    }

    try {
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // This handles taps when app is in Foreground or Background (not killed)
        if (response.payload == 'daily_check_in') {
          navigatorKey.currentState?.pushNamed('/daily_check_in');
        }
      },
    );

    await _createNotificationChannel();

    // CHECK APP LAUNCH DETAILS (For when app is killed)
    final NotificationAppLaunchDetails? notificationAppLaunchDetails =
        await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();

    if (notificationAppLaunchDetails?.didNotificationLaunchApp ?? false) {
      return notificationAppLaunchDetails?.notificationResponse?.payload;
    }

    return null;
  }

  Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'daily_channel_id',
      'Daily Reminders',
      description: 'Reminders to check in on your habits',
      importance: Importance.high,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> showTestNotification() async {
    await flutterLocalNotificationsPlugin.show(
      888,
      'Test Notification',
      'If you see this, notifications are working!',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_channel_id',
          'Daily Reminders',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  Future<void> scheduleDailyNotification(int hour, int minute) async {
    // 1. Cancel old notifications so we don't pile them up
    await flutterLocalNotificationsPlugin.cancel(0);

    // 2. Check for permission and schedule accordingly
    final useExact = await hasExactAlarmPermission();
    final scheduledTime = _nextInstanceOfTime(hour, minute);
    print('Scheduling notification for: $scheduledTime (exact: $useExact)');

    // 3. Schedule the new one
    await flutterLocalNotificationsPlugin.zonedSchedule(
      0,
      'Daily Check-in',
      'Time to log your habits for today!',
      scheduledTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_channel_id',
          'Daily Reminders',
          channelDescription: 'Reminders to check in on your habits',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: useExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'daily_check_in',
    );
  }

  Future<void> cancelDailyNotifications() async {
    await flutterLocalNotificationsPlugin.cancel(0);
    print('Canceled daily notifications');
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  // --- NEW PERMISSION LOGIC USING permission_handler ---

  /// Silently checks if standard notification permission is granted.
  Future<bool> hasNotificationPermission() async {
    final status = await Permission.notification.status;
    return status.isGranted;
  }

  /// Requests standard notification permission. Returns true if granted.
  Future<bool> requestNotificationPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// Silently checks if the exact alarm permission is granted.
  Future<bool> hasExactAlarmPermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.scheduleExactAlarm.status;
      return status.isGranted;
    }
    return true; // Not applicable on other platforms
  }

  /// Requests the exact alarm permission.
  /// This will open the special settings screen on Android 14+.
  Future<void> requestExactAlarmPermission() async {
    if (Platform.isAndroid) {
      await Permission.scheduleExactAlarm.request();
    }
  }

  /// Opens the app's settings screen so the user can manually change permissions.
  Future<void> openAppSettings() async {
    await openAppSettings();
  }
}
