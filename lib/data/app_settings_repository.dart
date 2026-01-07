import 'dart:async';
import 'package:fiveyear/data/entities.dart';
import 'package:fiveyear/data/objectbox.dart';
import 'package:fiveyear/services/notification_service.dart';
import 'package:objectbox/objectbox.dart';

class AppSettingsRepository {
  final ObjectBox _objectbox;
  final NotificationService notificationService;
  late final StreamController<AppSetting> _settingsController;

  AppSettingsRepository(this._objectbox, this.notificationService) {
    _settingsController = StreamController<AppSetting>.broadcast(
      onListen: () {
        _emitSettings();
      },
    );
  }

  Box<AppSetting> get _box => _objectbox.store.box<AppSetting>();

  void _emitSettings() {
    final settings = _box.getAll().firstOrNull;
    if (settings == null) {
      final now = DateTime.now();
      final defaultSettings = AppSetting()
        ..dailyReminderTime = DateTime(now.year, now.month, now.day, 20, 0)
        ..isReminderEnabled = false
        ..isFirstLaunch = true
        ..isModelLicenseAccepted = false
        ..dailyTokenUsage = 0;
      _box.put(defaultSettings);
      _settingsController.add(defaultSettings);
    } else {
      _settingsController.add(settings);
    }
  }

  Stream<AppSetting> watchSettings() {
    return _settingsController.stream;
  }

  Future<AppSetting> getSettings() async {
    var settings = _box.getAll().firstOrNull;

    if (settings == null) {
      final now = DateTime.now();
      settings = AppSetting()
        ..dailyReminderTime = DateTime(now.year, now.month, now.day, 20, 0)
        ..isReminderEnabled = false
        ..isFirstLaunch = true
        ..isModelLicenseAccepted = false
        ..dailyTokenUsage = 0;
      _box.put(settings);
    }

    final lastChat = settings.lastChatDate;
    if (lastChat != null) {
      final now = DateTime.now();
      final isSameDay =
          now.year == lastChat.year &&
          now.month == lastChat.month &&
          now.day == lastChat.day;

      if (!isSameDay) {
        settings.dailyTokenUsage = 0;
        settings.lastChatDate = now;
        _box.put(settings);
      }
    }

    return settings;
  }

  Future<void> updateDailyReminder(bool isEnabled, DateTime? time) async {
    final settings = await getSettings();
    settings.isReminderEnabled = isEnabled;
    settings.dailyReminderTime = time;
    _box.put(settings);
    _emitSettings(); // Add this

    if (isEnabled && time != null) {
      await notificationService.scheduleDailyNotification(
        time.hour,
        time.minute,
      );
    } else {
      await notificationService.cancelDailyNotifications();
    }
  }

  Future<void> finalizeOnboarding(
    bool enableNotifications,
    DateTime? time,
  ) async {
    final settings = await getSettings();
    settings.isReminderEnabled = enableNotifications;
    settings.dailyReminderTime = time;
    settings.isFirstLaunch = false;
    _box.put(settings);
    _emitSettings(); // Add this

    if (enableNotifications && time != null) {
      await notificationService.scheduleDailyNotification(
        time.hour,
        time.minute,
      );
    } else {
      await notificationService.cancelDailyNotifications();
    }
  }

  Future<void> setModelLicenseAccepted(bool accepted) async {
    final settings = await getSettings();
    settings.isModelLicenseAccepted = accepted;
    _box.put(settings);
    _emitSettings(); // Add this
  }

  Future<void> incrementTokenUsage(int tokens) async {
    final settings = await getSettings();
    settings.dailyTokenUsage += tokens;
    settings.lastChatDate = DateTime.now();
    _box.put(settings);
    _emitSettings(); // Add this
  }

  void dispose() {
    _settingsController.close();
  }
}
