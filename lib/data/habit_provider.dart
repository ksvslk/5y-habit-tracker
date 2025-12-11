import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../data/habit_repository.dart';
import '../data/habit_schema.dart';

part 'habit_provider.g.dart';

// 1. Singleton for the Repository
@Riverpod(keepAlive: true)
HabitRepository habitRepository(HabitRepositoryRef ref) {
  return HabitRepository();
}

// 2. The Stream of Habits (This drives the UI)
@riverpod
Stream<List<Habit>> habits(HabitsRef ref) {
  final repository = ref.watch(habitRepositoryProvider);
  return repository.watchAllHabits();
}