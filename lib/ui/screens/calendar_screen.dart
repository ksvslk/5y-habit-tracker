import 'dart:collection'; // Import this for HashSet
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../data/habit_schema.dart';

class CalendarScreen extends StatefulWidget {
  final Habit habit;

  const CalendarScreen({super.key, required this.habit});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  // OPTIMIZATION: Use a HashSet of DateTimes for O(1) lookups.
  // Comparing DateTimes is much faster than parsing/generating Strings in a loop.
  late final HashSet<DateTime> _selectedDates; 
  DateTime _focusedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    _selectedDates = HashSet<DateTime>(
      equals: isSameDay, // Use TableCalendar's fast comparison
      hashCode: (key) => key.day * 1000000 + key.month * 10000 + key.year,
    );

    // 1. Pre-convert Strings ("2023-156") to DateTimes ONCE.
    // This removes all math from the drawing loop.
    final initialData = _convertStringsToDates(widget.habit.completedDays);
    _selectedDates.addAll(initialData);
  }

  // Helper to convert your DB format back to DateTimes
  List<DateTime> _convertStringsToDates(List<String> rawDays) {
    final list = <DateTime>[];
    for (var raw in rawDays) {
      final parts = raw.split('-'); // "2023-156"
      if (parts.length < 2) continue;
      
      final year = int.tryParse(parts[0]);
      final dayOfYear = int.tryParse(parts[1]);
      
      if (year != null && dayOfYear != null) {
        // Calculate the Date from DayOfYear
        final date = DateTime(year, 1, 1).add(Duration(days: dayOfYear));
        list.add(date);
      }
    }
    return list;
  }

  // Helper to save back to DB format when closing
  List<String> _exportData() {
    return _selectedDates.map((date) {
      final startOfYear = DateTime(date.year, 1, 1);
      final dayOfYear = date.difference(startOfYear).inDays;
      return "${date.year}-$dayOfYear";
    }).toList();
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (selectedDay.isAfter(DateTime.now())) return;

    setState(() {
      _focusedDay = focusedDay;
      // Fast Set operation
      if (_selectedDates.contains(selectedDay)) {
        _selectedDates.remove(selectedDay);
      } else {
        _selectedDates.add(selectedDay);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = Color(widget.habit.colorValue);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.habit.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          // Save and Close
          onPressed: () => Navigator.pop(context, _exportData()),
        ),
        actions: [
           TextButton(
             onPressed: () => Navigator.pop(context, _exportData()), 
             child: Text("Done", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color))
           )
        ],
      ),
      body: TableCalendar(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        
        // OPTIMIZATION: Disable format switching animations
        availableCalendarFormats: const {CalendarFormat.month: 'Month'},
        headerStyle: const HeaderStyle(titleCentered: true),
        
        // OPTIMIZATION: Fast Lookup using HashSet
        selectedDayPredicate: (day) => _selectedDates.contains(day),
        
        onDaySelected: _onDaySelected,
        onPageChanged: (focusedDay) {
          _focusedDay = focusedDay;
        },

        // Simple Builders
        calendarBuilders: CalendarBuilders(
          defaultBuilder: (context, day, focusedDay) => _buildCell(day, false, color),
          todayBuilder: (context, day, focusedDay) => _buildCell(day, false, color, isToday: true),
          selectedBuilder: (context, day, focusedDay) => _buildCell(day, true, color),
        ),
      ),
    );
  }

  Widget _buildCell(DateTime day, bool isSelected, Color activeColor, {bool isToday = false}) {
    // Basic check, avoiding complex math
    bool isFuture = day.isAfter(DateTime.now());

    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200), // Smooth transition
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: isFuture ? Colors.grey[50] 
               : isSelected ? activeColor 
               : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          // Removing border in non-today cells helps GPU slightly
          border: isToday ? Border.all(color: Colors.blueAccent, width: 2) : null,
        ),
        child: Center(
          child: isFuture 
            ? Icon(Icons.lock, size: 12, color: Colors.grey[300]) 
            : Text(
                "${day.day}", 
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[700], 
                  fontWeight: FontWeight.bold
                )
              )
        ),
      ),
    );
  }
}