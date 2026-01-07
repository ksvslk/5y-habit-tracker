// habit_repository.dart
import 'dart:async';
import 'package:fiveyear/data/entities.dart';
import 'package:fiveyear/data/objectbox.dart';
import 'package:objectbox/objectbox.dart';

class HabitRepository {
  final ObjectBox _objectbox;
  late final StreamController<List<Habit>> _habitsController;

  HabitRepository(this._objectbox) {
    // Create broadcast stream with initial value
    _habitsController = StreamController<List<Habit>>.broadcast(
      onListen: () {
        // Emit current data whenever someone listens
        _emitHabits();
      },
    );
  }

  Box<Habit> get _box => _objectbox.store.box<Habit>();

  void _emitHabits() {
    final habits = _box.getAll();
    print('🔵 Emitting ${habits.length} habits');
    _habitsController.add(habits);
  }

  Stream<List<Habit>> watchAllHabits() {
    print('🔵 watchAllHabits called');
    return _habitsController.stream;
  }

  Future<void> addHabit(Habit habit) async {
    print('🔵 Adding habit: ${habit.name}');
    _box.put(habit);
    _emitHabits(); // Manually trigger update
    print('🔵 Total habits in box: ${_box.count()}');
  }

  Future<void> updateHabit(Habit habit) async {
    _box.put(habit);
    _emitHabits();
  }

  Future<void> updateHabitDays(int id, List<String> days) async {
    final habit = _box.get(id);
    if (habit != null) {
      habit.completedDays = days;
      _box.put(habit);
      _emitHabits();
    }
  }

  Future<void> deleteHabit(int id) async {
    _box.remove(id);
    _emitHabits();
  }

  void dispose() {
    _habitsController.close();
  }
}
