import 'dart:convert';
import 'package:objectbox/objectbox.dart';

// This will be the main data model for a Habit, used by both ObjectBox and the UI.
@Entity()
class Habit {
  @Id()
  int id = 0;

  late String name;
  late int colorValue;
  late String theme;
  String? customImagePath;
  int? iconCodePoint;

  // Stored as a JSON string in the database
  late String _completedDays;

  // Public getter for the UI
  List<String> get completedDays {
    if (_completedDays.isEmpty) return [];
    try {
      return (jsonDecode(_completedDays) as List).cast<String>();
    } catch (e) {
      return [];
    }
  }

  // Public setter for the UI
  set completedDays(List<String> days) {
    _completedDays = jsonEncode(days);
  }
}

// This will be the main data model for AppSettings.
@Entity()
class AppSetting {
  @Id()
  int id = 0;

  @Property(type: PropertyType.date)
  DateTime? dailyReminderTime;

  bool isReminderEnabled = false;
  bool isFirstLaunch = true;
  bool isModelLicenseAccepted = false;

  @Property(type: PropertyType.date)
  DateTime? lastChatDate;

  int dailyTokenUsage = 0;
}

// This will be the main data model for a ChatEntity.
@Entity()
class ChatEntity {
  @Id()
  int id = 0;

  late String content; // Renamed to avoid conflicts
  late bool isUser;

  @Property(type: PropertyType.date)
  late DateTime timestamp;
}
