import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

// Global navigation key
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // 1. Initialize Timezone DB
    tz.initializeTimeZones();

    // 2. Get Local Timezone
    String timeZoneName;
    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      // TimezoneInfo has an 'identifier' property that contains the timezone string
      timeZoneName = timezoneInfo.identifier;
    } catch (e) {
      // Fallback if there's any error
      timeZoneName = 'UTC';
    }

    // 3. Set Location
    try {
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    // 4. Android Init Settings
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('ic_launcher_foreground');

    // 5. iOS Init Settings
    final DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    final InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
        );

    // 6. Initialize Plugin
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload == 'daily_check_in') {
          navigatorKey.currentState?.pushNamed('/daily_check_in');
        }
      },
    );
  }

Future<void> scheduleDailyNotification() async {
  await flutterLocalNotificationsPlugin.zonedSchedule(
    0,
    'Daily Check-in',
    'Time to log your habits for today!',
    _nextInstanceOfTime(23, 59),
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'daily_channel_id',
        'Daily Reminders',
        channelDescription: 'Reminders to check in on your habits',
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    ),
    // 1. Keep this for Android 13+ compatibility
    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    
    // 2. This line was removed in recent plugin versions - DELETE IT
    // uiLocalNotificationDateInterpretation: ... 

    matchDateTimeComponents: DateTimeComponents.time,
    payload: 'daily_check_in',
  );
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

  Future<void> requestPermissions() async {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }
}
