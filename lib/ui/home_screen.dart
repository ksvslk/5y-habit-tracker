import 'dart:io';
import 'package:fiveyear/data/habit_provider.dart';
import 'package:fiveyear/main.dart';
import 'package:fiveyear/ui/screens/add_habit_screen.dart';
import 'package:fiveyear/ui/widgets/habit_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/habit_schema.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitsAsync = ref.watch(habitsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = Theme.of(context).colorScheme.surface;

    return Scaffold(
      // No hardcoded background color
      body: CustomScrollView(
        cacheExtent: 2000,
        slivers: [
          SliverAppBar(
            floating: true,
            title: Text(
              'Habits',
              style: TextStyle(
                // Adapt text color
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            // Adapt Appbar background
            backgroundColor: surfaceColor,
            elevation: 0,
            iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
          ),

          habitsAsync.when(
            loading: () => const SliverToBoxAdapter(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, stack) =>
                SliverToBoxAdapter(child: Text('Error: $err')),
            data: (habits) {
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final habit = habits[index];
                    return RepaintBoundary(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: HabitCard(habit: habit),
                      ),
                    );
                  }, childCount: habits.length),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.large(
        onPressed: () {
          Navigator.of(context).push(
            PageRouteBuilder(
              opaque: true, 
              pageBuilder: (context, animation, secondaryAnimation) => FadeTransition(
                opacity: animation, 
                child: const AddHabitScreen(),
              ),
            ),
          );
        },
        // DARK MODE FAB LOGIC:
        // Light Mode: Black BG / White Icon
        // Dark Mode: White BG / Black Icon (High Visibility)
        backgroundColor: isDark ? Colors.white : Colors.black,
        foregroundColor: isDark ? Colors.black : Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}