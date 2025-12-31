import 'package:fiveyear/data/app_settings_schema.dart';
import 'package:fiveyear/services/notification_service.dart';
import 'package:isar/isar.dart';

class AppSettingsRepository {
  final Future<Isar> db;
  final NotificationService notificationService;

  AppSettingsRepository(this.db, this.notificationService);

  Future<AppSettings> getSettings() async {
    final isar = await db;
    final settings = await isar.appSettings.where().findFirst();

    if (settings == null) {
      final now = DateTime.now();
      final newSettings = AppSettings()
        ..dailyReminderTime = DateTime(now.year, now.month, now.day, 20, 0)
        ..isReminderEnabled = false
        ..dailyTokenUsage = 0; // Init

      await isar.writeTxn(() async {
        await isar.appSettings.put(newSettings);
      });
      return newSettings;
    }
    
    // NEW: Check if we need to reset daily limits (if day changed)
    if (settings.lastChatDate != null) {
      final now = DateTime.now();
      final last = settings.lastChatDate!;
      
      // Simple day check
      final isSameDay = now.year == last.year && now.month == last.month && now.day == last.day;
      
      if (!isSameDay) {
         // It's a new day, reset usage
         await isar.writeTxn(() async {
           settings.dailyTokenUsage = 0;
           settings.lastChatDate = now;
           await isar.appSettings.put(settings);
         });
      }
    }

    return settings;
  }

  // ... (updateDailyReminder and finalizeOnboarding remain the same) ...
  Future<void> updateDailyReminder(bool isEnabled, DateTime? time) async {
    final isar = await db;
    final settings = await getSettings();

    settings.isReminderEnabled = isEnabled;
    settings.dailyReminderTime = time;

    await isar.writeTxn(() async {
      await isar.appSettings.put(settings);
    });

    if (isEnabled && time != null) {
      await notificationService.scheduleDailyNotification(
        time.hour,
        time.minute,
      );
    } else {
      await notificationService.cancelDailyNotifications();
    }
  }

  Future<void> finalizeOnboarding(bool enableNotifications, DateTime? time) async {
    final isar = await db;
    final settings = await getSettings();

    settings.isReminderEnabled = enableNotifications;
    settings.dailyReminderTime = time;
    settings.isFirstLaunch = false;

    await isar.writeTxn(() async {
      await isar.appSettings.put(settings);
    });

    if (enableNotifications && time != null) {
      await notificationService.scheduleDailyNotification(time.hour, time.minute);
    } else {
      await notificationService.cancelDailyNotifications();
    }
  }

  Future<void> setModelLicenseAccepted(bool accepted) async {
    final database = await db;
    await database.writeTxn(() async {
      final settings = await database.appSettings.where().findFirst();
      if (settings != null) {
        settings.isModelLicenseAccepted = accepted;
        await database.appSettings.put(settings);
      }
    });
  }

  // NEW: Increment Usage
  Future<void> incrementTokenUsage(int tokens) async {
    final isar = await db;
    // Ensure we have fresh settings (handles day reset if needed via getSettings)
    final settings = await getSettings(); 
    
    await isar.writeTxn(() async {
      settings.dailyTokenUsage += tokens;
      settings.lastChatDate = DateTime.now();
      await isar.appSettings.put(settings);
    });
  }
}