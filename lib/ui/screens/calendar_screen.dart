import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart'; 
import 'package:table_calendar/table_calendar.dart';

import '../../data/habit_schema.dart';
import '../../data/habit_provider.dart';
import '../../data/theme_colors.dart'; 

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
  
  const HabitStats(this.current, this.longest, this.year, this.percent, this.total);
}

HashSet<int> _parseDataInIsolate(IsolateInput input) {
  final set = HashSet<int>();
  for (final raw in input.currentData) {
    final parts = raw.split('-');
    if (parts.length == 2) {
      final y = int.tryParse(parts[0]);
      final d = int.tryParse(parts[1]);
      if (y != null && d != null) {
        // We use UTC here to ensure consistency when hydrating from string
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
  
  final yearCompletions = sortedDates.where((d) => d >= yearPrefix && d < yearPrefix + 1232).length;
  
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
      final d2 = _intToDate(sortedDates[i+1]);
      
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
  return DateTime.utc(y, m, d); // Use UTC to prevent DST shift errors
}

// -----------------------------------------------------------------------------
// 2. STATE CONTROLLER
// -----------------------------------------------------------------------------

class CalendarController {
  final ValueNotifier<HashSet<int>> dates = ValueNotifier(HashSet());
  final ValueNotifier<HabitStats> stats = ValueNotifier(const HabitStats(0,0,0,0,0));
  
  Function(HashSet<int>)? onSave;
  bool _isLoaded = false;
  
  Future<void> load(List<String> rawData) async {
    if (_isLoaded) return;
    final set = await compute(_parseDataInIsolate, IsolateInput(currentData: rawData));
    dates.value = set;
    _recalc(set);
    _isLoaded = true;
  }

  void toggle(DateTime date) {
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

  // UPDATED: Use UTC loop to ensure we don't skip days during DST changeover
  void fillYear(DateTime focusedMonth) {
    HapticFeedback.mediumImpact();
    
    final now = DateTime.now();
    final targetYear = focusedMonth.year;
    final newSet = HashSet<int>.from(dates.value);
    
    final startOfYear = DateTime.utc(targetYear, 1, 1);
    final endDate = targetYear == now.year 
        ? DateTime.utc(now.year, now.month, now.day)
        : DateTime.utc(targetYear, 12, 31);
    
    DateTime current = startOfYear;
    while (current.isBefore(endDate) || current.isAtSameMomentAs(endDate)) {
      final dateInt = current.year * 10000 + current.month * 100 + current.day;
      newSet.add(dateInt);
      current = current.add(const Duration(days: 1));
    }
    
    dates.value = newSet;
    _recalc(newSet);
    if (onSave != null) onSave!(newSet);
  }

  // UPDATED: Use UTC loop
  void addRandomDates(DateTime focusedMonth) {
    HapticFeedback.mediumImpact();
    final now = DateTime.now();
    final random = Random();
    final targetYear = focusedMonth.year;
    final newSet = HashSet<int>.from(dates.value);
    
    final startOfYear = DateTime.utc(targetYear, 1, 1);
    final endDate = targetYear == now.year 
        ? DateTime.utc(now.year, now.month, now.day)
        : DateTime.utc(targetYear, 12, 31);
    
    final daysInPeriod = endDate.difference(startOfYear).inDays + 1;
    final minDays = (daysInPeriod * 0.3).round();
    final maxDays = (daysInPeriod * 0.8).round();
    final targetCount = minDays + random.nextInt(maxDays - minDays + 1);
    
    final availableDays = <DateTime>[];
    DateTime current = startOfYear;
    while (current.isBefore(endDate) || current.isAtSameMomentAs(endDate)) {
      availableDays.add(current);
      current = current.add(const Duration(days: 1));
    }
    availableDays.shuffle(random);
    
    for (int i = 0; i < targetCount && i < availableDays.length; i++) {
      final date = availableDays[i];
      final dateInt = date.year * 10000 + date.month * 100 + date.day;
      newSet.add(dateInt);
    }
    dates.value = newSet;
    _recalc(newSet);
    if (onSave != null) onSave!(newSet);
  }

  void clearAllDates() {
    HapticFeedback.mediumImpact();
    final newSet = HashSet<int>();
    dates.value = newSet;
    _recalc(newSet);
    if (onSave != null) onSave!(newSet);
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

  const CalendarScreen({
    super.key, 
    required this.habit,
    this.initialYear,
  });

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late final CalendarController _controller;
  bool _showDebugButtons = false;
  late DateTime _focusedMonth;

  // Dynamic colors
  late Color _currentColor;       // Base pastel color (charts/bg)
  late Color _activeColor;        // High contrast version for Buttons
  late Color _readableColor;      // Text/Borders
  final int _anchorYear = DateTime.now().year;

  // Standardization Constant
  static const double _sidePadding = 20.0;

@override
  void initState() {
    super.initState();
    
    final now = DateTime.now();
    
    // Determine which year to show (default to current year if null)
    int targetYear = widget.initialYear ?? now.year;
    
    // LOGIC FIX: 
    // If the target year is the CURRENT year, show the CURRENT month.
    // Otherwise (for past/future years), default to January.
    int targetMonth = (targetYear == now.year) ? now.month : 1;

    // Initialize _focusedMonth using UTC to align with your controller logic
    _focusedMonth = DateTime.utc(targetYear, targetMonth, 1);

    _controller = CalendarController();
    _controller.load(widget.habit.completedDays);
    _controller.onSave = _handleSave;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateColor(_focusedMonth.year);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateColor(_focusedMonth.year);
  }

  void _updateColor(int year) {
    int yearDiff = year - _anchorYear;
    int assetIndex = ((yearDiff % 5) + 5) % 5 + 1; 

    Color newColor;
    try {
      final themeName = widget.habit.theme;
      if (themeData.containsKey(themeName)) {
        final colors = themeData[themeName]['colors'] as List<Color>;
        newColor = colors[assetIndex - 1];
      } else {
        newColor = Color(widget.habit.colorValue);
      }
    } catch (e) {
      newColor = Color(widget.habit.colorValue);
    }

    // High Contrast Logic
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    
    final hsl = HSLColor.fromColor(newColor);
    Color readable;
    Color active;

    if (isDark) {
      readable = hsl.withLightness(max(hsl.lightness, 0.75)).toColor();
      active = hsl.withLightness(max(hsl.lightness, 0.30)).toColor();
    } else {
      readable = hsl.withLightness(min(hsl.lightness, 0.4)).toColor();
      active = hsl.withLightness(min(hsl.lightness, 0.85)).toColor();
    }

    setState(() {
      _currentColor = newColor;
      _readableColor = readable;
      _activeColor = active;
    });
  }

  void _onMonthChanged(DateTime month) {
    if (month.year != _focusedMonth.year) {
      _updateColor(month.year);
    }
    setState(() => _focusedMonth = month);
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
        ref.read(habitRepositoryProvider).updateHabitDays(widget.habit.id, strings);
      }
    });
  }
  
  // FIX: Ensure Year Picker uses UTC
  void _showYearPicker() {
    final int currentYear = DateTime.now().year;
    final int startYear = currentYear - 100; 
    final int range = 110; 
    
    final int selectedYear = _focusedMonth.year;
    int initialIndex = selectedYear - startYear;
    if (initialIndex < 0) initialIndex = 0;
    if (initialIndex >= range) initialIndex = range - 1;

    const double itemHeight = 50.0;
    final double scrollOffset = (initialIndex * itemHeight) - 100.0;
    final scrollController = ScrollController(
      initialScrollOffset: scrollOffset.clamp(0.0, double.infinity)
    );

    final surfaceColor = Theme.of(context).colorScheme.surface;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: surfaceColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
                    color: isDark ? Colors.white : Colors.black
                  )
                )
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
                      title: Center(child: Text("$year", style: TextStyle(
                        fontSize: 18, 
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, 
                        color: isSelected ? _readableColor : (isDark ? Colors.white70 : Colors.black)
                      ))),
                      onTap: () {
                        Navigator.pop(context);
                        setState(() {
                          // USE UTC HERE
                          _focusedMonth = DateTime.utc(year, _focusedMonth.month, 1);
                        });
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.white70 : Colors.black87;
    final dateColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              // UPDATED: Standardized padding
              padding: const EdgeInsets.symmetric(horizontal: _sidePadding, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(Icons.close, color: iconColor),
                    onPressed: () => Navigator.pop(context)
                  ),
                  Text(
                    widget.habit.name, 
                    style: TextStyle(
                      fontSize: 18, 
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black
                    )
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.bug_report, color: Colors.grey[400]),
                        onPressed: () => setState(() => _showDebugButtons = !_showDebugButtons),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text("Done", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _readableColor)),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (_showDebugButtons)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                // UPDATED: Standardized margin
                margin: const EdgeInsets.symmetric(horizontal: _sidePadding),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("DEBUG TOOLS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[600], letterSpacing: 1.0)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: ElevatedButton(onPressed: () => _controller.fillYear(_focusedMonth), child: const Text("Fill"))),
                        const SizedBox(width: 8),
                        Expanded(child: ElevatedButton(onPressed: () => _controller.addRandomDates(_focusedMonth), child: const Text("Rnd"))),
                        const SizedBox(width: 8),
                        Expanded(child: ElevatedButton(onPressed: _controller.clearAllDates, child: const Text("Clr"))),
                      ],
                    ),
                  ],
                ),
              ),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    _StatsView(
                      stats: _controller.stats, 
                      dates: _controller.dates, 
                      color: _currentColor, 
                      readableColor: _readableColor 
                    ),
                    const SizedBox(height: 20),
                    
                    // -----------------------------------------------------------------
                    // TABLE CALENDAR INTEGRATION
                    // -----------------------------------------------------------------
                    
                    Padding(
                      // UPDATED: Standardized padding
                      padding: const EdgeInsets.symmetric(horizontal: _sidePadding, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: Icon(Icons.chevron_left, color: iconColor), 
                            onPressed: () {
                              setState(() {
                                // Manual UTC control
                                _focusedMonth = DateTime.utc(_focusedMonth.year, _focusedMonth.month - 1, 1);
                              });
                            }
                          ),
                          GestureDetector(
                            onTap: _showYearPicker,
                            child: Row(
                              children: [
                                Text(
                                  DateFormat.yMMMM().format(_focusedMonth), 
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: dateColor)
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.chevron_right, color: iconColor), 
                            onPressed: () {
                              setState(() {
                                // Manual UTC control
                                _focusedMonth = DateTime.utc(_focusedMonth.year, _focusedMonth.month + 1, 1);
                              });
                            }
                          ),
                        ],
                      ),
                    ),

                    Padding(
                      // UPDATED: Standardized padding
                      padding: const EdgeInsets.symmetric(horizontal: _sidePadding),
                      child: ValueListenableBuilder<HashSet<int>>(
                        valueListenable: _controller.dates,
                        builder: (context, dateSet, _) {
                          return TableCalendar(
                            // FIX: Boundaries in UTC to prevent day-skipping
                            firstDay: DateTime.utc(2000, 1, 1),
                            lastDay: DateTime.utc(2100, 12, 31),
                            focusedDay: _focusedMonth,
                            currentDay: DateTime.now(), // This can remain local for the "Today" marker
                            headerVisible: false, 
                            startingDayOfWeek: StartingDayOfWeek.monday,
                            daysOfWeekStyle: const DaysOfWeekStyle(
                              weekdayStyle: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600),
                              weekendStyle: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            
                            onPageChanged: (focusedDay) {
                              _onMonthChanged(focusedDay);
                            },
                            
                            calendarBuilders: CalendarBuilders(
                              defaultBuilder: (context, date, focusedDay) {
                                return _buildCalendarCell(date, dateSet, isToday: false);
                              },
                              todayBuilder: (context, date, focusedDay) {
                                return _buildCalendarCell(date, dateSet, isToday: true);
                              },
                              outsideBuilder: (context, date, focusedDay) {
                                return const SizedBox.shrink(); 
                              },
                            ),
                            
                            onDaySelected: (selectedDay, focusedDay) {
                              // 1. We removed the "isAfter(now)" check so you can test 2025/Future dates
                              // 2. We normalize the clicked day to UTC noon to be safe
                              final safeDate = DateTime.utc(selectedDay.year, selectedDay.month, selectedDay.day);
                              _controller.toggle(safeDate);
                            },
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
  }

  Widget _buildCalendarCell(DateTime date, HashSet<int> dateSet, {required bool isToday}) {
    final dateInt = date.year * 10000 + date.month * 100 + date.day;
    final isCompleted = dateSet.contains(dateInt);
    
    // Logic to visually lock future dates
    // If you want to enable clicking them but still SHOW them as locked, keep this.
    // Otherwise, comment out the return statement.
    final isFuture = date.isAfter(DateTime.now());
    if (isFuture) {
      // return Center(child: Icon(Icons.lock, size: 14, color: Colors.grey[800])); 
      // I have commented this out so you can see the dates and click them for testing.
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color textColor;
    if (isCompleted) {
       textColor = (_activeColor.computeLuminance() > 0.5 ? Colors.black : Colors.white);
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
          border: (isToday && !isCompleted) ? Border.all(color: _readableColor, width: 2) : null,
        ),
        child: Text("${date.day}", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 4. STATS VIEW (Unchanged)
// -----------------------------------------------------------------------------

class _StatsView extends StatefulWidget {
  final ValueNotifier<HabitStats> stats;
  final ValueNotifier<HashSet<int>> dates;
  final Color color;
  final Color readableColor;

  const _StatsView({required this.stats, required this.dates, required this.color, required this.readableColor});

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
    if (_lastDateSet != null && _lastDateSet == dateSet && _cachedMonthCounts != null) {
      return _cachedMonthCounts!;
    }

    final now = DateTime.now();
    final counts = <String, int>{};
    for (int i = 0; i < 4; i++) {
      final monthDate = DateTime(now.year, now.month - i, 1);
      final key = "${monthDate.year}-${monthDate.month}";
      final daysInMonth = DateUtils.getDaysInMonth(monthDate.year, monthDate.month);
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dotInactiveColor = isDark ? Colors.grey[800] : Colors.grey[300];

    return Column(
      children: [
        SizedBox(
          height: 160,
          child: PageView(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            children: [
              ValueListenableBuilder<HashSet<int>>(valueListenable: widget.dates, builder: (context, dateSet, _) => _buildMonthlyTrendCard(dateSet)),
              ValueListenableBuilder<HabitStats>(valueListenable: widget.stats, builder: (context, s, _) => _buildDoubleStatCard(title: "Streaks", label1: "Current", val1: "${s.current}", icon1: Icons.local_fire_department, label2: "Longest", val2: "${s.longest}", icon2: Icons.emoji_events)),
              ValueListenableBuilder<HashSet<int>>(valueListenable: widget.dates, builder: (context, dateSet, _) => _buildFrequencyCard(dateSet)),
              ValueListenableBuilder<HabitStats>(valueListenable: widget.stats, builder: (context, s, _) => _buildDoubleStatCard(title: "Volume", label1: "This Year", val1: "${s.year}", icon1: Icons.calendar_today, label2: "Total", val2: "${s.total}", icon2: Icons.functions)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (index) {
            final isActive = _currentIndex == index;
            return AnimatedContainer(duration: const Duration(milliseconds: 300), margin: const EdgeInsets.symmetric(horizontal: 4), height: 8, width: isActive ? 24 : 8, decoration: BoxDecoration(color: isActive ? widget.color : dotInactiveColor, borderRadius: BorderRadius.circular(4)));
          }),
        ),
      ],
    );
  }

  Widget _buildMonthlyTrendCard(HashSet<int> dateSet) {
    final now = DateTime.now();
    final counts = _getMonthCounts(dateSet);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final bgOpacity = isDark ? 0.15 : 0.08;
    final trackColor = isDark ? Colors.grey[800] : Colors.grey[100];

    return Container(
      // UPDATED: Using uniform 20.0 padding (already present)
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: widget.color.withOpacity(bgOpacity), 
        borderRadius: BorderRadius.circular(20)
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("PERFORMANCE TREND", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[600], letterSpacing: 1.0)),
              Text("Last 4 Months", style: TextStyle(fontSize: 10, color: Colors.grey[500])),
            ],
          ),
          const Spacer(),
          ...List.generate(4, (i) {
            final monthDate = DateTime(now.year, now.month - i, 1);
            final name = DateFormat.MMM().format(monthDate).toUpperCase();
            final daysInMonth = DateUtils.getDaysInMonth(monthDate.year, monthDate.month);
            final key = "${monthDate.year}-${monthDate.month}";
            final completed = counts[key] ?? 0;
            final double pct = daysInMonth == 0 ? 0 : completed / daysInMonth;
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  SizedBox(width: 32, child: Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey[600]))),
                  const SizedBox(width: 8),
                  Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(
                    value: pct, 
                    minHeight: 8, 
                    backgroundColor: trackColor, 
                    color: widget.readableColor 
                  ))),
                  const SizedBox(width: 12),
                  SizedBox(width: 36, child: Text("${(pct * 100).toInt()}%", textAlign: TextAlign.end, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? Colors.white70 : Colors.black87))),
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
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgOpacity = isDark ? 0.15 : 0.08;

    return Container(
      // UPDATED: Using uniform 20.0 padding (already present)
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: widget.color.withOpacity(bgOpacity), borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("CONSISTENCY", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[600], letterSpacing: 1.0)),
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
                      return Container(width: 12, height: 60 * value + 4, decoration: BoxDecoration(color: widget.readableColor.withOpacity(0.5 + (0.5 * value)), borderRadius: BorderRadius.circular(4)));
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(days[index], style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[600])),
                ],
              );
            }),
          )
        ],
      ),
    );
  }

  Widget _buildDoubleStatCard({required String title, required String label1, required String val1, required IconData icon1, required String label2, required String val2, required IconData icon2}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgOpacity = isDark ? 0.15 : 0.08;
    
    return Container(
      // UPDATED: Using uniform 20.0 padding (already present)
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: widget.color.withOpacity(bgOpacity), borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[600], letterSpacing: 1.0)),
          const Spacer(),
          Row(
            children: [
              _buildSingleStat(label1, val1, icon1, isDark),
              Container(width: 1, height: 40, color: Colors.grey[isDark ? 700 : 300]),
              _buildSingleStat(label2, val2, icon2, isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSingleStat(String label, String value, IconData icon, bool isDark) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24, color: widget.readableColor),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}