import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class HabitCardShimmer extends StatelessWidget {
  const HabitCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Use surface container for the "card" color
    // Use surface for the base color
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Shimmer.fromColors(
        baseColor: colorScheme.surfaceContainerHighest,
        highlightColor: colorScheme.surface,
        child: Container(
          height: 160,
          decoration: BoxDecoration(
            color: Colors.black, // Color doesn't matter, masked by Shimmer
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 150, height: 20, color: Colors.white),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  height: 14,
                  color: Colors.white,
                ),
                const SizedBox(height: 8),
                Container(width: 200, height: 14, color: Colors.white),
                const Spacer(),
                Row(
                  children: [
                    Container(width: 40, height: 40, color: Colors.white),
                    const SizedBox(width: 16),
                    Expanded(child: Container(height: 10, color: Colors.white)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
