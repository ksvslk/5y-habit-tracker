import 'package:fiveyear/data/habit_repository.dart';
import 'package:fiveyear/data/habit_schema.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'database_provider.dart'; // Import the shared DB provider

part 'habit_provider.g.dart';

// 1. Singleton for the Repository
@Riverpod(keepAlive: true)
HabitRepository habitRepository(HabitRepositoryRef ref) {
  // We grab the Future<Isar> from the database provider
  final dbFuture = ref.watch(isarDatabaseProvider.future);
  return HabitRepository(dbFuture);
}

// 2. The Stream of Habits
@riverpod
Stream<List<Habit>> habits(HabitsRef ref) {
  final repository = ref.watch(habitRepositoryProvider);
  return repository.watchAllHabits();
}