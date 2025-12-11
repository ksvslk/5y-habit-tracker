import 'dart:io';
import 'package:fiveyear/data/habit_provider.dart';
import 'package:fiveyear/main.dart';
import 'package:fiveyear/ui/screens/add_habit_dialog.dart';
import 'package:fiveyear/ui/widgets/habit_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/habit_schema.dart';


class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitsAsync = ref.watch(habitsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        // Optimization: Render unseen items to prevent jank on rapid scroll
        cacheExtent: 2000, 
        slivers: [
          const SliverAppBar(
            floating: true,
            title: Text('Habits', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            backgroundColor: Color(0xFFF8FAFC),
            elevation: 0,
          ),
          
          habitsAsync.when(
            loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
            error: (err, stack) => SliverToBoxAdapter(child: Text('Error: $err')),
            data: (habits) {
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final habit = habits[index];
                      // PERFORMANCE: RepaintBoundary isolates this card.
                      // If another card updates, this one does not repaint.
                      return RepaintBoundary(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: HabitCard(habit: habit),
                        ),
                      );
                    },
                    childCount: habits.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.large(
        onPressed: () => showDialog(context: context, builder: (_) => const AddHabitDialog()),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}