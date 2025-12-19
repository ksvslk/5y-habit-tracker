import 'package:fiveyear/data/habit_schema.dart';
import 'package:isar/isar.dart';

class HabitRepository {
  // Pass the database future in via constructor
  final Future<Isar> db;

  HabitRepository(this.db);

  Stream<Habit?> watchHabit(int id) async* {
    final isar = await db;
    yield* isar.habits.watchObject(id, fireImmediately: true);
  }

  Stream<List<Habit>> watchAllHabits() async* {
    final isar = await db;
    yield* isar.habits.where().watch(fireImmediately: true);
  }

  Future<void> addHabit(Habit habit) async {
    final isar = await db;
    await isar.writeTxn(() async {
      await isar.habits.put(habit);
    });
  }

  Future<void> updateHabit(Habit habit) async {
    final isar = await db;
    await isar.writeTxn(() async {
      await isar.habits.put(habit);
    });
  }

  Future<void> updateHabitDays(int id, List<String> days) async {
    final isar = await db;
    await isar.writeTxn(() async {
      final habit = await isar.habits.get(id);
      if (habit != null) {
        habit.completedDays = days;
        await isar.habits.put(habit);
      }
    });
  }

  // NEW: Delete method
  Future<void> deleteHabit(int id) async {
    final isar = await db;
    await isar.writeTxn(() async {
      await isar.habits.delete(id);
    });
  }
}