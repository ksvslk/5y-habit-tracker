import 'package:isar/isar.dart';

part 'app_settings_schema.g.dart';

@collection
class AppSettings {
  Id id = Isar.autoIncrement;
  DateTime? dailyReminderTime;
  bool isReminderEnabled = false;
  bool isFirstLaunch = true;
}