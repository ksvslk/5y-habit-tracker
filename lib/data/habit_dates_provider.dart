import 'package:flutter_riverpod/flutter_riverpod.dart';

final habitDatesProvider =
    StateNotifierProvider.family<HabitDatesNotifier, Set<DateTime>, int>(
  (ref, habitId) => HabitDatesNotifier(),
);

class HabitDatesNotifier extends StateNotifier<Set<DateTime>> {
  HabitDatesNotifier() : super({});

  static DateTime _norm(DateTime d) => DateTime(d.year, d.month, d.day);

  void toggleDate(DateTime day) {
    final normalized = _norm(day);

    // Use a temporary copy to avoid mutating the existing state
    final updated = Set<DateTime>.from(state);

    if (updated.contains(normalized)) {
      updated.remove(normalized);
    } else {
      updated.add(normalized);
    }

    state = updated;
  }
}
