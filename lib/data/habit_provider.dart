import 'package:fiveyear/data/habit_repository.dart';
import 'package:fiveyear/data/entities.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'database_provider.dart';

part 'habit_provider.g.dart';

// 1. Singleton for the Repository
@Riverpod(keepAlive: true)
HabitRepository habitRepository(HabitRepositoryRef ref) {
  final objectbox = ref.watch(objectboxProvider).value;

  if (objectbox == null) {
    throw Exception("ObjectBox store not available");
  }
  return HabitRepository(objectbox);
}

// 2. The Stream of Habits
@riverpod
Stream<List<Habit>> habits(HabitsRef ref) {
  final repository = ref.watch(habitRepositoryProvider);
  return repository.watchAllHabits();
}