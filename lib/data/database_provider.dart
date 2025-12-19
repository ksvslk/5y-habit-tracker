import 'package:fiveyear/data/app_settings_schema.dart';
import 'package:fiveyear/data/chat_entity_schema.dart';
import 'package:fiveyear/data/habit_schema.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final isarDatabaseProvider = FutureProvider<Isar>((ref) async {
  final dir = await getApplicationDocumentsDirectory();
  
  if (Isar.instanceNames.isEmpty) {
    return await Isar.open(
      [HabitSchema, ChatEntitySchema, AppSettingsSchema],
      directory: dir.path,
      inspector: true,
    );
  }
  
  return Isar.getInstance()!;
});