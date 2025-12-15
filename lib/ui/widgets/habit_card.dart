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
    
    // 1. Base Tone (Card Background)
    final baseTone = Color.alphaBlend(color.withOpacity(0.15), Colors.white);
    
    // 2. Derive Tones using HSL
    final HSLColor hslBase = HSLColor.fromColor(baseTone);

    // Grid Fill
    final Color gridFill = hslBase.withLightness(
      (hslBase.lightness - 0.05).clamp(0.0, 1.0)
    ).toColor();

    // Grid Border
    final Color gridBorder = hslBase.withLightness(
      (hslBase.lightness - 0.20).clamp(0.0, 1.0)
    ).toColor();

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
        decoration: BoxDecoration(
          color: baseTone,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 8))],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                CircleAvatar(backgroundColor: color, radius: 20, child: const Icon(Icons.emoji_events, color: Colors.white, size: 20)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    habit.name, 
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            AspectRatio(
              aspectRatio: 20 / 19,
              child: ClipRRect(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // --- ANIMATION START ---
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.0, end: 1.0), // Fade 0 to 1
                      duration: const Duration(milliseconds: 1000), // Duration 0.8s
                      curve: Curves.linear,
                      
                      // PASS IMAGE AS CHILD (Optimized so image loads once, not every frame)
                      child: habit.customImagePath != null
                          ? Image.file(File(habit.customImagePath!), fit: BoxFit.cover, cacheWidth: 600)
                          : Image.asset('assets/habits/${habit.theme}/1.jpg', fit: BoxFit.cover),
                      
                      // BUILDER APPLIES OPACITY
                      builder: (context, opacity, child) {
                        return Opacity(
                          opacity: opacity,
                          child: child,
                        );
                      },
                    ),
                    // --- ANIMATION END ---
                      
                    CustomPaint(
                      painter: MosaicPainter(
                        completedDays: habit.completedDays,
                        year: year,
                        fillColor: gridFill,
                        borderColor: gridBorder,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("$count days", style: TextStyle(color: Colors.black.withOpacity(0.5), fontWeight: FontWeight.bold)),
                Text("$percent%", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}