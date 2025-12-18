import 'dart:io';
import 'package:fiveyear/data/habit_provider.dart';
import 'package:fiveyear/main.dart';
import 'package:fiveyear/ui/screens/add_habit_screen.dart';
import 'package:fiveyear/ui/screens/chat_screen.dart';
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
      body: CustomScrollView(
        cacheExtent: 2000,
        slivers: [
          SliverAppBar(
            floating: true,
            title: Text(
              'Habits',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
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
              // --- CHANGE STARTS HERE ---
             if (habits.isEmpty) {
  bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

  return SliverFillRemaining(
    hasScrollBody: false,
    child: Padding(
      // Adding bottom padding (e.g., 100-150) pushes the content up 
      // away from the FABs and into the visual center.
      padding: const EdgeInsets.only(bottom: 120), 
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Opacity(
              opacity: 0.8,
              child: Image.asset(
                isDarkMode 
                  ? 'assets/icons/greyscale_night.png' 
                  : 'assets/icons/greyscale.png',
                width: 200,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No habits yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the + button to start your journey.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: isDarkMode ? Colors.white38 : Colors.black45,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
              // --- CHANGE ENDS HERE ---

              return SliverPadding(
                // Added extra bottom padding so the FABs don't cover the last item
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
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
      
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Future Chat Button
            FloatingActionButton.large(
              heroTag: 'chat_btn',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ChatScreen()),
                );
              },
              backgroundColor: isDark ? Colors.white : Colors.black,
              foregroundColor: isDark ? Colors.black : Colors.white,
              child: const Icon(Icons.blur_on),
            ),

            // Add Habit Button
            FloatingActionButton.large(
              heroTag: 'add_btn',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AddHabitScreen()),
                );
              },
              backgroundColor: isDark ? Colors.white : Colors.black,
              foregroundColor: isDark ? Colors.black : Colors.white,
              child: const Icon(Icons.add),
            ),
          ],
        ),
      ),
    );
  }
}