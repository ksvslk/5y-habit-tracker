import 'package:isar/isar.dart';

part 'habit_schema.g.dart';

@collection
class Habit {
  Id id = Isar.autoIncrement; // Auto-incrementing ID

  late String name;
  
  // Store color as int (ARGB) for raw performance
  late int colorValue; 
  
  late String theme;
  String? customImagePath;

  // Isar stores Lists of Strings very efficiently
  late List<String> completedDays; 
}