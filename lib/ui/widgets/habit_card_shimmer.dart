// lib/ui/widgets/habit_card_shimmer.dart
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class HabitCardShimmer extends StatelessWidget {
  const HabitCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Define base/highlight colors based on theme for a subtle effect
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Shimmer.fromColors(
        baseColor: baseColor,
        highlightColor: highlightColor,
        child: Container(
          height: 160, // Approximate height of your real HabitCard
          decoration: BoxDecoration(
            color: Colors.black, // Color doesn't matter, masked by Shimmer
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Mock Title
                Container(
                  width: 150,
                  height: 20,
                  color: Colors.white,
                ),
                const SizedBox(height: 12),
                // Mock Subtitle / Description
                Container(
                  width: double.infinity,
                  height: 14,
                  color: Colors.white,
                ),
                const SizedBox(height: 8),
                Container(
                  width: 200,
                  height: 14,
                  color: Colors.white,
                ),
                const Spacer(),
                // Mock Action Row (e.g., buttons or progress)
                Row(
                  children: [
                    Container(width: 40, height: 40, color: Colors.white),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(height: 10, color: Colors.white),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}