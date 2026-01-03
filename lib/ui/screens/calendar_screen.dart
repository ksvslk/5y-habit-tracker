import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'package:fiveyear/data/entities.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../data/habit_provider.dart';
import '../../data/theme_colors.dart';
import 'edit_habit_screen.dart';

// -----------------------------------------------------------------------------
// 1. ISOLATED LOGIC
// -----------------------------------------------------------------------------

class IsolateInput {
  final List<String> currentData;
  IsolateInput({this.currentData = const []});
}

class HabitStats {
  final int current;
  final int longest;
  final int year;
  final int percent;
  final int total;

  const HabitStats(
    this.current,
    this.longest,
    this.year,
    this.percent,
    this.total,
  );
}

HashSet<int> _parseDataInIsolate(IsolateInput input) {
  final set = HashSet<int>();
  for (final raw in input.currentData) {
    final parts = raw.split('-');
    if (parts.length == 2) {
      final y = int.tryParse(parts[0]);
      final d = int.tryParse(parts[1]);
      if (y != null && d != null) {
        final date = DateTime.utc(y, 1, 1).add(Duration(days: d));
        set.add(date.year * 10000 + date.month * 100 + date.day);
      }
    }
  }
  return set;
}

HabitStats _calcStatsInIsolate(List<int> sortedDates) {
  final now = DateTime.now();
  final yearPrefix = now.year * 10000;

  final yearCompletions = sortedDates
      .where((d) => d >= yearPrefix && d < yearPrefix + 1232)
      .length;

  int currentStreak = 0;
  final dateSet = HashSet<int>.from(sortedDates);

  DateTime check = DateTime(now.year, now.month, now.day);
  int checkInt = check.year * 10000 + check.month * 100 + check.day;

  if (dateSet.contains(checkInt)) {
    while (dateSet.contains(checkInt)) {
      currentStreak++;
      check = check.subtract(const Duration(days: 1));
      checkInt = check.year * 10000 + check.month * 100 + check.day;
    }
  } else {
    check = check.subtract(const Duration(days: 1));
    checkInt = check.year * 10000 + check.month * 100 + check.day;
    if (dateSet.contains(checkInt)) {
      while (dateSet.contains(checkInt)) {
        currentStreak++;
        check = check.subtract(const Duration(days: 1));
        checkInt = check.year * 10000 + check.month * 100 + check.day;
      }
    }
  }

  int longestStreak = 0;
  if (sortedDates.isNotEmpty) {
    int temp = 1;
    for (int i = 0; i < sortedDates.length - 1; i++) {
      final d1 = _intToDate(sortedDates[i]);
      final d2 = _intToDate(sortedDates[i + 1]);

      if (d2.difference(d1).inDays == 1) {
        temp++;
      } else {
        if (temp > longestStreak) longestStreak = temp;
        temp = 1;
      }
    }
    if (temp > longestStreak) longestStreak = temp;
  }

  return HabitStats(
    currentStreak,
    longestStreak,
    yearCompletions,
    ((yearCompletions / 365) * 100).round(),
    sortedDates.length,
  );
}

List<String> _serializeInIsolate(List<int> dates) {
  return dates.map((intDate) {
    final d = _intToDate(intDate);
    final start = DateTime.utc(d.year, 1, 1);
    final dayNum = d.difference(start).inDays;
    return "${d.year}-$dayNum";
  }).toList();
}

DateTime _intToDate(int ymd) {
  final y = ymd ~/ 10000;
  final m = (ymd % 10000) ~/ 100;
  final d = ymd % 100;
  return DateTime.utc(y, m, d);
}

// -----------------------------------------------------------------------------
// 2. STATE CONTROLLER
// -----------------------------------------------------------------------------

class CalendarController {
  final ValueNotifier<HashSet<int>> dates = ValueNotifier(HashSet());
  final ValueNotifier<HabitStats> stats = ValueNotifier(
    const HabitStats(0, 0, 0, 0, 0),
  );

  Function(HashSet<int>)? onSave;
  bool _isLoaded = false;

  CalendarController();

  Future<void> load(List<String> rawData) async {
    if (_isLoaded) return;
    final set = await compute(
      _parseDataInIsolate,
      IsolateInput(currentData: rawData),
    );
    dates.value = set;
    _recalc(set);
    _isLoaded = true;
  }

  void toggle(DateTime date) {
    final now = DateTime.now();
    final today = DateTime.utc(now.year, now.month, now.day);
    if (date.isAfter(today)) {
      HapticFeedback.heavyImpact();
      return;
    }

    HapticFeedback.lightImpact();

    final dateInt = date.year * 10000 + date.month * 100 + date.day;
    final newSet = HashSet<int>.from(dates.value);

    if (newSet.contains(dateInt)) {
      newSet.remove(dateInt);
    } else {
      newSet.add(dateInt);
    }

    dates.value = newSet;
    _recalc(newSet);

    if (onSave != null) {
      onSave!(newSet);
    }
  }

  void _recalc(HashSet<int> set) {
    final list = set.toList()..sort();
    compute(_calcStatsInIsolate, list).then((s) {
      stats.value = s;
    });
  }
}

// -----------------------------------------------------------------------------
// 3. MAIN SCREEN
// -----------------------------------------------------------------------------

class CalendarScreen extends ConsumerStatefulWidget {
  final Habit habit;
  final int? initialYear;

  const CalendarScreen({super.key, required this.habit, this.initialYear});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late final CalendarController _controller;
  late DateTime _focusedMonth;

  // Colors are calculated based on the active habit's theme
  Color? _currentColor;
  Color? _activeColor;
  Color? _readableColor;
  final int _anchorYear = DateTime.now().year;

  static const double _sidePadding = 20.0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    int targetYear = widget.initialYear ?? now.year;
    int targetMonth = (targetYear == now.year) ? now.month : 1;
    _focusedMonth = DateTime.utc(targetYear, targetMonth, 1);
    
    _controller = CalendarController();
    _controller.load(widget.habit.completedDays);
    _controller.onSave = _handleSave;
  }

  void _calculateColors(Habit habit) {
    int yearDiff = _focusedMonth.year - _anchorYear;
    int assetIndex = ((yearDiff % 5) + 5) % 5 + 1;

    Color newColor;
    try {
      final themeName = habit.theme;
      if (themeData.containsKey(themeName)) {
        final colors = themeData[themeName]['colors'] as List<Color>;
        newColor = colors[assetIndex - 1];
      } else {
        newColor = Color(habit.colorValue);
      }
    } catch (e) {
      newColor = Color(habit.colorValue);
    }

    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final hsl = HSLColor.fromColor(newColor);

    if (isDark) {
      _readableColor = hsl.withLightness(max(hsl.lightness, 0.75)).toColor();
      _activeColor = hsl.withLightness(max(hsl.lightness, 0.30)).toColor();
    } else {
      _readableColor = hsl.withLightness(min(hsl.lightness, 0.4)).toColor();
      _activeColor = hsl.withLightness(min(hsl.lightness, 0.85)).toColor();
    }
    _currentColor = newColor;
  }

  @override
  void dispose() {
    _controller.dates.dispose();
    _controller.stats.dispose();
    super.dispose();
  }

  void _handleSave(HashSet<int> set) {
    final list = set.toList();
    compute(_serializeInIsolate, list).then((strings) {
      if (mounted) {
        ref
            .read(habitRepositoryProvider)
            .updateHabitDays(widget.habit.id, strings);
      }
    });
  }

  void _showYearPicker(Habit habit) {
    final int currentYear = DateTime.now().year;
    final int startYear = currentYear - 100;
    const int range = 110;

    final int selectedYear = _focusedMonth.year;
    int initialIndex = selectedYear - startYear;
    if (initialIndex < 0) initialIndex = 0;
    if (initialIndex >= range) initialIndex = range - 1;

    const double itemHeight = 50.0;
    final double scrollOffset = (initialIndex * itemHeight) - 100.0;
    final scrollController = ScrollController(
      initialScrollOffset: scrollOffset.clamp(0.0, double.infinity),
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SizedBox(
          height: 300,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  "Select Year",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemExtent: itemHeight,
                  itemCount: range,
                  itemBuilder: (context, index) {
                    final year = startYear + index;
                    final isSelected = year == _focusedMonth.year;
                    return ListTile(
                      title: Center(
                        child: Text(
                          "$year",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected 
                                ? _readableColor 
                                : (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black),
                          ),
                        ),
                      ),
                      onTap: () {
                        setState(() {
                          _focusedMonth = DateTime.utc(year, _focusedMonth.month, 1);
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch the habits stream to react to database changes
    final habitsAsync = ref.watch(habitsProvider);

    return habitsAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text("Error: $err"))),
      data: (allHabits) {
        // Extract the latest data for this specific habit
        final currentHabit = allHabits.firstWhere(
          (h) => h.id == widget.habit.id,
          orElse: () => widget.habit,
        );

        // Calculate colors based on current habit settings
        _calculateColors(currentHabit);

        final isDark = Theme.of(context).brightness == Brightness.dark;
        final iconColor = isDark ? Colors.white70 : Colors.black87;
        final dateColor = isDark ? Colors.white : Colors.black87;

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                AppBar(
                  automaticallyImplyLeading: false, // Disable default back button
                  leading: IconButton(
                    icon: Icon(Icons.edit, color: iconColor), // Existing edit button
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EditHabitScreen(habit: currentHabit),
                        ),
                      );
                      if (result == 'DELETED' && mounted) {
                        Navigator.pop(context);
                      }
                    },
                  ),
                  title: Text(
                    currentHabit.name, // Habit name as title
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  centerTitle: true,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                  actions: [
                    TextButton(
                        style: TextButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          "Back",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: _readableColor,
                          ),
                        ),
                      ),
                  ],
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        _StatsView(
                          stats: _controller.stats,
                          dates: _controller.dates,
                          color: _currentColor ?? Colors.blue,
                          readableColor: _readableColor ?? Colors.blue,
                        ),
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: _sidePadding, vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                icon: Icon(Icons.chevron_left, color: iconColor),
                                onPressed: () => setState(() => _focusedMonth = DateTime.utc(_focusedMonth.year, _focusedMonth.month - 1, 1)),
                              ),
                              GestureDetector(
                                onTap: () => _showYearPicker(currentHabit),
                                child: Row(
                                  children: [
                                    Text(DateFormat.yMMMM().format(_focusedMonth), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: dateColor)),
                                    const SizedBox(width: 4),
                                    Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
                                  ],
                                ),
                              ),
                              Builder(
                                builder: (context) {
                                  final isFuture = _focusedMonth.year == DateTime.now().year && _focusedMonth.month == DateTime.now().month;
                                  return IconButton(
                                    icon: Icon(Icons.chevron_right, color: isFuture ? Colors.transparent : iconColor),
                                    onPressed: isFuture ? null : () => setState(() => _focusedMonth = DateTime.utc(_focusedMonth.year, _focusedMonth.month + 1, 1)),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: _sidePadding),
                          child: ValueListenableBuilder<HashSet<int>>(
                            valueListenable: _controller.dates,
                            builder: (context, dateSet, _) {
                              return TableCalendar(
                                firstDay: DateTime.utc(2000, 1, 1),
                                lastDay: DateTime.now(),
                                focusedDay: _focusedMonth,
                                currentDay: DateTime.now(),
                                headerVisible: false,
                                startingDayOfWeek: StartingDayOfWeek.monday,
                                daysOfWeekStyle: const DaysOfWeekStyle(
                                  weekdayStyle: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600),
                                  weekendStyle: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                                onPageChanged: (focusedDay) => setState(() => _focusedMonth = focusedDay),
                                calendarBuilders: CalendarBuilders(
                                  defaultBuilder: (context, date, _) => _buildCalendarCell(date, dateSet, isToday: false),
                                  todayBuilder: (context, date, _) => _buildCalendarCell(date, dateSet, isToday: true),
                                  outsideBuilder: (context, date, _) => const SizedBox.shrink(),
                                ),
                                onDaySelected: (selectedDay, _) => _controller.toggle(DateTime.utc(selectedDay.year, selectedDay.month, selectedDay.day)),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCalendarCell(DateTime date, HashSet<int> dateSet, {required bool isToday}) {
    final dateInt = date.year * 10000 + date.month * 100 + date.day;
    final isCompleted = dateSet.contains(dateInt);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color textColor;
    if (isCompleted) {
      textColor = ((_activeColor ?? Colors.blue).computeLuminance() > 0.5 ? Colors.black : Colors.white);
    } else {
      textColor = isDark ? Colors.grey[400]! : Colors.grey[700]!;
    }

    return Center(
      child: Container(
        margin: const EdgeInsets.all(4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isCompleted ? _activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: (isToday && !isCompleted) ? Border.all(color: _readableColor ?? Colors.blue, width: 2) : null,
        ),
        child: Text("${date.day}", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 4. STATS VIEW
// -----------------------------------------------------------------------------

class _StatsView extends StatefulWidget {
  final ValueNotifier<HabitStats> stats;
  final ValueNotifier<HashSet<int>> dates;
  final Color color;
  final Color readableColor;

  const _StatsView({
    required this.stats,
    required this.dates,
    required this.color,
    required this.readableColor,
  });

  @override
  State<_StatsView> createState() => _StatsViewState();
}

class _StatsViewState extends State<_StatsView> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  Map<String, int>? _cachedMonthCounts;
  HashSet<int>? _lastDateSet;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Map<String, int> _getMonthCounts(HashSet<int> dateSet) {
    if (_lastDateSet != null &&
        _lastDateSet == dateSet &&
        _cachedMonthCounts != null) {
      return _cachedMonthCounts!;
    }

    final now = DateTime.now();
    final counts = <String, int>{};
    for (int i = 0; i < 4; i++) {
      final monthDate = DateTime(now.year, now.month - i, 1);
      final key = "${monthDate.year}-${monthDate.month}";
      final daysInMonth = DateUtils.getDaysInMonth(
        monthDate.year,
        monthDate.month,
      );
      int completed = 0;
      for (int d = 1; d <= daysInMonth; d++) {
        final dateInt = monthDate.year * 10000 + monthDate.month * 100 + d;
        if (dateSet.contains(dateInt)) completed++;
      }
      counts[key] = completed;
    }
    _cachedMonthCounts = counts;
    _lastDateSet = HashSet.from(dateSet);
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dotInactiveColor = colorScheme.surfaceContainerHighest;

    return Column(
      children: [
        SizedBox(
          height: 160,
          child: PageView(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            children: [
              ValueListenableBuilder<HashSet<int>>(
                valueListenable: widget.dates,
                builder: (context, dateSet, _) =>
                    _buildMonthlyTrendCard(dateSet),
              ),
              ValueListenableBuilder<HabitStats>(
                valueListenable: widget.stats,
                builder: (context, s, _) => _buildDoubleStatCard(
                  title: "Streaks",
                  label1: "Current",
                  val1: "${s.current}",
                  icon1: Icons.local_fire_department,
                  label2: "Longest",
                  val2: "${s.longest}",
                  icon2: Icons.emoji_events,
                ),
              ),
              ValueListenableBuilder<HashSet<int>>(
                valueListenable: widget.dates,
                builder: (context, dateSet, _) => _buildFrequencyCard(dateSet),
              ),
              ValueListenableBuilder<HabitStats>(
                valueListenable: widget.stats,
                builder: (context, s, _) => _buildDoubleStatCard(
                  title: "Volume",
                  label1: "This Year",
                  val1: "${s.year}",
                  icon1: Icons.calendar_today,
                  label2: "Total",
                  val2: "${s.total}",
                  icon2: Icons.functions,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (index) {
            final isActive = _currentIndex == index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 8,
              width: isActive ? 24 : 8,
              decoration: BoxDecoration(
                color: isActive ? widget.color : dotInactiveColor,
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildMonthlyTrendCard(HashSet<int> dateSet) {
    final now = DateTime.now();
    final counts = _getMonthCounts(dateSet);
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgOpacity = isDark ? 0.15 : 0.08;
    final bgColor = Color.alphaBlend(
      widget.color.withOpacity(bgOpacity),
      colorScheme.surface,
    );
    final trackColor = isDark ? Colors.grey[800] : Colors.grey[200];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "PERFORMANCE TREND",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurfaceVariant,
                  letterSpacing: 1.0,
                ),
              ),
              Text(
                "Last 4 Months",
                style: TextStyle(
                  fontSize: 10,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const Spacer(),
          ...List.generate(4, (i) {
            final monthDate = DateTime(now.year, now.month - i, 1);
            final name = DateFormat.MMM().format(monthDate).toUpperCase();
            final daysInMonth = DateUtils.getDaysInMonth(
              monthDate.year,
              monthDate.month,
            );
            final key = "${monthDate.year}-${monthDate.month}";
            final completed = counts[key] ?? 0;
            final double pct = daysInMonth == 0 ? 0 : completed / daysInMonth;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  SizedBox(
                    width: 32,
                    child: Text(
                      name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 8,
                        backgroundColor: trackColor,
                        color: widget.readableColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 36,
                    child: Text(
                      "${(pct * 100).toInt()}%",
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFrequencyCard(HashSet<int> dateSet) {
    final counts = [0, 0, 0, 0, 0, 0, 0];
    int maxCount = 0;
    for (final dateInt in dateSet) {
      final y = dateInt ~/ 10000;
      final m = (dateInt % 10000) ~/ 100;
      final d = dateInt % 100;
      final dt = DateTime(y, m, d);
      final weekdayIndex = dt.weekday - 1;
      counts[weekdayIndex]++;
      if (counts[weekdayIndex] > maxCount) maxCount = counts[weekdayIndex];
    }
    final days = ["M", "T", "W", "T", "F", "S", "S"];

    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgOpacity = isDark ? 0.15 : 0.08;
    final bgColor = Color.alphaBlend(
      widget.color.withOpacity(bgOpacity),
      colorScheme.surface,
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "CONSISTENCY",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurfaceVariant,
              letterSpacing: 1.0,
            ),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(7, (index) {
              final double pct = maxCount == 0 ? 0 : counts[index] / maxCount;
              return Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 800),
                    tween: Tween(begin: 0, end: pct),
                    builder: (context, value, _) {
                      return Container(
                        width: 12,
                        height: 60 * value + 4,
                        decoration: BoxDecoration(
                          color: widget.readableColor.withOpacity(
                            0.5 + (0.5 * value),
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    days[index],
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildDoubleStatCard({
    required String title,
    required String label1,
    required String val1,
    required IconData icon1,
    required String label2,
    required String val2,
    required IconData icon2,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgOpacity = isDark ? 0.15 : 0.08;
    final bgColor = Color.alphaBlend(
      widget.color.withOpacity(bgOpacity),
      colorScheme.surface,
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurfaceVariant,
              letterSpacing: 1.0,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              _buildSingleStat(label1, val1, icon1),
              Container(
                width: 1,
                height: 40,
                color: colorScheme.outlineVariant,
              ),
              _buildSingleStat(label2, val2, icon2),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSingleStat(String label, String value, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24, color: widget.readableColor),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}