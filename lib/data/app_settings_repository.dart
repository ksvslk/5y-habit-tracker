import 'package:fiveyear/data/app_settings_schema.dart';
import 'package:fiveyear/services/notification_service.dart';
import 'package:isar/isar.dart';

class AppSettingsRepository {
  final Future<Isar> db;

  final NotificationService notificationService;

  AppSettingsRepository(this.db, this.notificationService);

  /// Get the single settings object.
  /// Creates a default one if it doesn't exist yet.
  Future<AppSettings> getSettings() async {
    final isar = await db;
    final settings = await isar.appSettings.where().findFirst();

    if (settings == null) {
      // Initialize defaults
      final now = DateTime.now();
      final newSettings = AppSettings()
        ..dailyReminderTime = DateTime(now.year, now.month, now.day, 20, 0)
        ..isReminderEnabled = false;

      await isar.writeTxn(() async {
        await isar.appSettings.put(newSettings);
      });
      return newSettings;
    }
    return settings;
  }

  Future<void> updateDailyReminder(bool isEnabled, DateTime? time) async {
    final isar = await db;
    final settings = await getSettings();

    settings.isReminderEnabled = isEnabled;
    settings.dailyReminderTime = time;

    await isar.writeTxn(() async {
      await isar.appSettings.put(settings);
    });

    // 3. Use the injected instance (No more "NotificationService()...")
    if (isEnabled && time != null) {
      await notificationService.scheduleDailyNotification(
        time.hour,
        time.minute,
      );
    } else {
      await notificationService.cancelDailyNotifications();
    }
  }

// ADD THIS NEW METHOD
  Future<void> finalizeOnboarding(bool enableNotifications, DateTime? time) async {
    final isar = await db;
    final settings = await getSettings();

    // 1. Set the Time & Notification preference
    settings.isReminderEnabled = enableNotifications;
    settings.dailyReminderTime = time;

    // 2. Mark as NOT first launch anymore
    settings.isFirstLaunch = false;

    // 3. Save everything in ONE transaction
    await isar.writeTxn(() async {
      await isar.appSettings.put(settings);
    });

    // 4. Handle the notification scheduling
    if (enableNotifications && time != null) {
      await notificationService.scheduleDailyNotification(time.hour, time.minute);
    } else {
      await notificationService.cancelDailyNotifications();
    }
  }
}
