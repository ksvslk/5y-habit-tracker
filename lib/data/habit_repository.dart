import 'package:fiveyear/data/entities.dart';
import 'package:fiveyear/data/objectbox.dart';
import 'package:fiveyear/data/objectbox.g.dart';

class HabitRepository {
  final ObjectBox _objectbox;

  HabitRepository(this._objectbox);

  Box<Habit> get _box => _objectbox.store.box<Habit>();

  Stream<List<Habit>> watchAllHabits() {
    // The query builder is created once and the stream is returned.
    // The stream is automatically updated when the data changes.
    return _box
        .query()
        .watch(triggerImmediately: true)
        .map((query) => query.find());
  }

  Future<void> addHabit(Habit habit) async {
    _box.put(habit);
  }

  Future<void> updateHabit(Habit habit) async {
    _box.put(habit);
  }

  Future<void> updateHabitDays(int id, List<String> days) async {
    final habit = _box.get(id);
    if (habit != null) {
      habit.completedDays = days;
      _box.put(habit);
    }
  }

  Future<void> deleteHabit(int id) async {
    _box.remove(id);
  }
}
