import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'habit_schema.dart';

class HabitRepository {
  late Future<Isar> db;

  HabitRepository() {
    db = _initDb();
  }

  Future<Isar> _initDb() async {
    final dir = await getApplicationDocumentsDirectory();
    if (Isar.instanceNames.isEmpty) {
      return await Isar.open(
        [HabitSchema],
        directory: dir.path,
        inspector: true, // Allows debugging DB in real-time
      );
    }
    return Isar.getInstance()!;
  }

  // OPTIMIZATION: Returns a Stream. Riverpod listens to this.
  // When you add/edit a habit, the UI rebuilds automatically.
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
}