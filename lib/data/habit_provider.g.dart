// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'habit_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$habitRepositoryHash() => r'533104a61386a6b63cfbf61ae31a2dc9e57bf3ba';

/// See also [habitRepository].
@ProviderFor(habitRepository)
final habitRepositoryProvider = Provider<HabitRepository>.internal(
  habitRepository,
  name: r'habitRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$habitRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef HabitRepositoryRef = ProviderRef<HabitRepository>;
String _$habitsHash() => r'93f0ca01ef287e29761c3bcc6ea3a90379c99f95';

/// See also [habits].
@ProviderFor(habits)
final habitsProvider = AutoDisposeStreamProvider<List<Habit>>.internal(
  habits,
  name: r'habitsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$habitsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef HabitsRef = AutoDisposeStreamProviderRef<List<Habit>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
