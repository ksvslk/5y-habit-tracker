import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart'; // For 'compute'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart'; 
import '../../data/habit_schema.dart';
import '../../data/habit_provider.dart';

// -----------------------------------------------------------------------------
// 1. ISOLATED LOGIC (Runs on separate CPU Thread)
// -----------------------------------------------------------------------------

/// Raw data packet to send to background isolate
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

/// BACKGROUND TASK: Parses Strings -> Ints (YYYYMMDD)
HashSet<int> _parseDataInIsolate(IsolateInput input) {
  final set = HashSet<int>();
  for (final raw in input.currentData) {
    final parts = raw.split('-');
    if (parts.length == 2) {
      final y = int.tryParse(parts[0]);
      final d = int.tryParse(parts[1]);
      if (y != null && d != null) {
        final date = DateTime(y, 1, 1).add(Duration(days: d));
        set.add(date.year * 10000 + date.month * 100 + date.day);
      }
    }
  }
  return set;
}

/// BACKGROUND TASK: Calculates Stats
HabitStats _calcStatsInIsolate(List<int> sortedDates) {
  final now = DateTime.now();
  final yearPrefix = now.year * 10000;
  
  // Year Stats
  final yearCompletions = sortedDates.where((d) => d >= yearPrefix && d < yearPrefix + 1232).length;
  
  // Streak Calc
  int currentStreak = 0;
  final dateSet = HashSet<int>.from(sortedDates);
  
  DateTime check = DateTime(now.year, now.month, now.day);
  int checkInt = check.year * 10000 + check.month * 100 + check.day;
  
  // Check Today
  if (dateSet.contains(checkInt)) {
    while (dateSet.contains(checkInt)) {
      currentStreak++;
      check = check.subtract(const Duration(days: 1));
      checkInt = check.year * 10000 + check.month * 100 + check.day;
    }
  } else {
    // Grace Period (Check Yesterday)
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

/// BACKGROUND TASK: Serializes Ints -> Strings for DB
List<String> _serializeInIsolate(List<int> dates) {
  return dates.map((intDate) {
    final d = _intToDate(intDate);
    final start = DateTime(d.year, 1, 1);
    final dayNum = d.difference(start).inDays;
    return "${d.year}-$dayNum";
  }).toList();
}

DateTime _intToDate(int ymd) {
  final y = ymd ~/ 10000;
  final m = (ymd % 10000) ~/ 100;
  final d = ymd % 100;
  return DateTime(y, m, d);
}

// -----------------------------------------------------------------------------
// 2. STATE CONTROLLER (The Brain)
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
    final dateInt = date.year * 10000 + date.month * 100 + date.day;
    final newSet = HashSet<int>.from(dates.value);
    
    if (newSet.contains(dateInt)) {
      newSet.remove(dateInt);
    } else {
      newSet.add(dateInt);
    }

    // 1. Instant UI Update
    dates.value = newSet;

    // 2. Background Math
    _recalc(newSet);
    
    // 3. Trigger Save
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
  const CalendarScreen({super.key, required this.habit});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late final CalendarController _controller;

  @override
  void initState() {
    super.initState();
    _controller = CalendarController();
    _controller.load(widget.habit.completedDays);
    _controller.onSave = _handleSave;
  }

  @override
  void dispose() {
    _controller.dates.dispose();
    _controller.stats.dispose();
    super.dispose();
  }

  void _handleSave(HashSet<int> set) {
    final list = set.toList();
    // Serialize in background to keep UI smooth
    compute(_serializeInIsolate, list).then((strings) {
      if (mounted) {
        ref.read(habitRepositoryProvider).updateHabitDays(widget.habit.id, strings);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final rawColor = Color(widget.habit.colorValue);
    final readableColor = rawColor.computeLuminance() > 0.65 
        ? HSLColor.fromColor(rawColor).withLightness(0.4).toColor() 
        : rawColor;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  Text(widget.habit.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text("Done", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: readableColor)),
                  )
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    // Swipeable Stats View
                    _StatsView(
                      stats: _controller.stats,
                      dates: _controller.dates, 
                      color: rawColor, 
                      readableColor: readableColor
                    ),
                    const SizedBox(height: 20),
                    _BareMetalCalendar(
                      dates: _controller.dates,
                      color: rawColor,
                      onTap: _controller.toggle,
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
}

// -----------------------------------------------------------------------------
// 4. BARE METAL CALENDAR
// -----------------------------------------------------------------------------

class _BareMetalCalendar extends StatefulWidget {
  final ValueNotifier<HashSet<int>> dates;
  final Color color;
  final Function(DateTime) onTap;

  const _BareMetalCalendar({required this.dates, required this.color, required this.onTap});

  @override
  State<_BareMetalCalendar> createState() => _BareMetalCalendarState();
}

class _BareMetalCalendarState extends State<_BareMetalCalendar> {
  final PageController _pageCtrl = PageController(initialPage: 1000);
  DateTime _focusedMonth = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 380,
      child: Column(
        children: [
          // Nav
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _pageCtrl.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut)),
                Text(DateFormat.yMMMM().format(_focusedMonth), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _pageCtrl.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut)),
              ],
            ),
          ),
          // Weekdays
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].map((d) => 
              SizedBox(width: 44, child: Center(child: Text(d, style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600))))
            ).toList(),
          ),
          const SizedBox(height: 8),
          // Grid
          Expanded(
            child: PageView.builder(
              controller: _pageCtrl,
              onPageChanged: (i) {
                final now = DateTime.now();
                setState(() => _focusedMonth = DateTime(now.year, now.month + (i - 1000), 1));
              },
              itemBuilder: (_, i) {
                final now = DateTime.now();
                return _MonthGrid(
                  month: DateTime(now.year, now.month + (i - 1000), 1),
                  dates: widget.dates,
                  color: widget.color,
                  onTap: widget.onTap,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  final DateTime month;
  final ValueNotifier<HashSet<int>> dates;
  final Color color;
  final Function(DateTime) onTap;

  const _MonthGrid({required this.month, required this.dates, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final firstWeekday = DateTime(month.year, month.month, 1).weekday;
    final offset = firstWeekday - 1;

    // Lightweight listener
    return ValueListenableBuilder<HashSet<int>>(
      valueListenable: dates,
      builder: (context, selectedInts, _) {
        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7, mainAxisSpacing: 8, crossAxisSpacing: 0,
          ),
          itemCount: 42,
          itemBuilder: (context, index) {
            final dayNum = index - offset + 1;
            if (dayNum < 1 || dayNum > daysInMonth) return const SizedBox();
            
            final date = DateTime(month.year, month.month, dayNum);
            final dateInt = date.year * 10000 + date.month * 100 + date.day;
            final isSelected = selectedInts.contains(dateInt);
            
            return _DayCell(
              date: date,
              isSelected: isSelected,
              color: color,
              onTap: () => onTap(date),
            );
          },
        );
      },
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime date;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _DayCell({required this.date, required this.isSelected, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isFuture = date.isAfter(DateTime.now());
    if (isFuture) return Center(child: Icon(Icons.lock, size: 14, color: Colors.grey[200]));

    final textColor = isSelected 
      ? (color.computeLuminance() > 0.5 ? Colors.black : Colors.white)
      : Colors.grey[700];

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Center(
        child: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: (date.day == DateTime.now().day && date.month == DateTime.now().month && date.year == DateTime.now().year && !isSelected)
                ? Border.all(color: color, width: 2) : null,
          ),
          child: Center(child: Text("${date.day}", style: TextStyle(color: textColor, fontWeight: FontWeight.bold))),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 5. STATS VIEW (Swipeable Cards)
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

  // Cache expensive calculations
  Map<String, int>? _cachedMonthCounts;
  HashSet<int>? _lastDateSet;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Map<String, int> _getMonthCounts(HashSet<int> dateSet) {
    // Return cached if dateSet unchanged
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
    // Split listeners: stats-only cards vs date-dependent cards
    return Column(
      children: [
        SizedBox(
          height: 160,
          child: PageView(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            children: [
              // Card 1: Monthly Trend (needs dates)
              ValueListenableBuilder<HashSet<int>>(
                valueListenable: widget.dates,
                builder: (context, dateSet, _) => _buildMonthlyTrendCard(dateSet),
              ),

              // Card 2: Streaks (needs stats only)
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

              // Card 3: Frequency (needs dates)
              ValueListenableBuilder<HashSet<int>>(
                valueListenable: widget.dates,
                builder: (context, dateSet, _) => _buildFrequencyCard(dateSet),
              ),
              
              // Card 4: Volume (needs stats only)
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
        // Dot Indicators
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
                color: isActive ? widget.color : Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
      ],
    );
  }

  // --- CARD 1: MONTHLY TREND (Last 4 Months) ---
  Widget _buildMonthlyTrendCard(HashSet<int> dateSet) {
    final now = DateTime.now();
    final counts = _getMonthCounts(dateSet);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: widget.color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
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
                  SizedBox(
                    width: 32, 
                    child: Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey[600]))
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 8,
                        backgroundColor: Colors.white,
                        color: widget.color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 36,
                    child: Text("${(pct * 100).toInt()}%", textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // --- CARD 3: FREQUENCY BAR CHART ---
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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: widget.color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
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
                       return Container(
                         width: 12,
                         height: 60 * value + 4, 
                         decoration: BoxDecoration(
                           color: widget.color.withOpacity(0.5 + (0.5 * value)), 
                           borderRadius: BorderRadius.circular(4),
                         ),
                       );
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

  // --- STANDARD CARD (Streaks / Volume) ---
  Widget _buildDoubleStatCard({
    required String title,
    required String label1,
    required String val1,
    required IconData icon1,
    required String label2,
    required String val2,
    required IconData icon2,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: widget.color.withOpacity(0.08),
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
              color: Colors.grey[600], 
              letterSpacing: 1.0
            ),
          ),
          const Spacer(),
          Row(
            children: [
              _buildSingleStat(label1, val1, icon1),
              Container(width: 1, height: 40, color: Colors.grey[300]), // Divider
              _buildSingleStat(label2, val2, icon2),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSingleStat(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24, color: widget.color),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}