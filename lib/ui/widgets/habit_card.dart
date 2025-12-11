import 'dart:io';
import 'package:fiveyear/data/habit_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/habit_schema.dart';
import '../screens/calendar_screen.dart'; 
import 'mosaic_painter.dart';

class HabitCard extends ConsumerWidget {
  final Habit habit;

  const HabitCard({super.key, required this.habit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final year = DateTime.now().year;
    final color = Color(habit.colorValue);
    
    final baseTone = Color.alphaBlend(color.withOpacity(0.15), Colors.white);
    
    // Count days for current year
    final count = habit.completedDays.where((d) => d.startsWith("$year-")).length;
    final percent = ((count / 365) * 100).round();

    return GestureDetector(
      onTap: () async {
        final List<String>? result = await Navigator.push(
          context,
          PageRouteBuilder(
            opaque: true, 
            pageBuilder: (_, __, ___) => CalendarScreen(habit: habit),
            transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
          ),
        );
        
        if (result != null) {
          ref.read(habitRepositoryProvider).updateHabitDays(habit.id, result);
        }
      },
      child: Container(
        // FIX 1: Removed fixed "height: 380". 
        // Now the card expands to fit the mosaic perfectly on any screen size.
        decoration: BoxDecoration(
          color: baseTone,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 8))],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Wrap content tightly
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(backgroundColor: color, radius: 20, child: const Icon(Icons.emoji_events, color: Colors.white, size: 20)),
                const SizedBox(width: 12),
                // Expanded ensures long names don't break layout
                Expanded(
                  child: Text(
                    habit.name, 
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            
            // FIX 2: Fixed spacing instead of Spacer().
            // This guarantees the header is never "too close" to the grid.
            const SizedBox(height: 20),
            
            // The Mosaic
            AspectRatio(
              aspectRatio: 20 / 19,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (habit.customImagePath != null)
                      Image.file(
                        File(habit.customImagePath!), 
                        fit: BoxFit.cover,
                        cacheWidth: 600, 
                      )
                    else
                      Image.asset('assets/habits/${habit.theme}/1.jpg', fit: BoxFit.cover),
                      
                    CustomPaint(
                      painter: MosaicPainter(
                        completedDays: habit.completedDays,
                        year: year,
                        tileColor: baseTone,
                        itemRadius: 2.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // FIX 3: Fixed spacing for footer
            const SizedBox(height: 20),
            
            // Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("$count days", style: TextStyle(color: Colors.black.withOpacity(0.5), fontWeight: FontWeight.bold)),
                Text("$percent%", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: percent / 100, color: color, backgroundColor: Colors.white60, minHeight: 8, borderRadius: BorderRadius.circular(4)),
          ],
        ),
      ),
    );
  }
}