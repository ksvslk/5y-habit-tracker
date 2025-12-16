import 'package:isar/isar.dart';

part 'habit_schema.g.dart';

@collection
class Habit {
  Id id = Isar.autoIncrement; 

  late String name;
  late int colorValue; 
  late String theme;
  String? customImagePath;
  
  // NEW: Store the icon's integer ID
  int? iconCodePoint;

  late List<String> completedDays; 
}