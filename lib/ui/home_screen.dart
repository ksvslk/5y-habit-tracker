import 'dart:ui'; // Needed for ImageFilter if we want blur, or just for generic UI

import 'package:fiveyear/data/app_settings_provider.dart';
import 'package:fiveyear/data/habit_provider.dart';
import 'package:fiveyear/data/subscription_service.dart'; //
import 'package:fiveyear/ui/screens/add_habit_screen.dart';
import 'package:fiveyear/ui/screens/chat_screen.dart';
import 'package:fiveyear/ui/screens/settings_screen.dart';
import 'package:fiveyear/ui/widgets/onboarding_overlay.dart';
import 'package:fiveyear/ui/widgets/first_launch_dialog.dart';
import 'package:fiveyear/ui/widgets/habit_card.dart';
import 'package:fiveyear/ui/widgets/habit_card_shimmer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  final ScrollController _landscapeHabitController = ScrollController();
  String? _pendingScrollToId;
  bool _hasScrolled = false;

  @override
  void dispose() {
    _scrollController.dispose();
    _landscapeHabitController.dispose();
    super.dispose();
  }

  // LOGIC TO FINISH ONBOARDING
  Future<void> _completeOnboarding() async {
    if (!mounted) return;

    // 1. Show the dialog
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const FirstLaunchDialog(),
    );

    // 2. Wait for the dialog dismissal animation to finish
    // A small delay (300ms is standard for Material transitions) or post-frame callback
    await Future.delayed(const Duration(milliseconds: 300));

    if (mounted) {
      await RevenueCatUI.presentPaywallIfNeeded("5Y Pro");
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch providers
    final settingsAsync = ref.watch(appSettingsProvider);
    final habitsAsync = ref.watch(habitsProvider);

    // NEW: Watch subscription status
    final subscriptionAsync = ref.watch(subscriptionStatusProvider);
    final isPro = subscriptionAsync.value ?? false;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = Theme.of(context).colorScheme.surface;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    // Safely determine if we should show the overlay.
    final bool showOnboarding = settingsAsync.maybeWhen(
      data: (settings) => settings.isFirstLaunch,
      orElse: () => false,
    );

    return Stack(
      children: [
        Scaffold(
          appBar: isLandscape
              ? AppBar(
                  title: Text(
                    '5 Year Plan',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  backgroundColor: surfaceColor,
                  elevation: 0,
                  iconTheme: IconThemeData(
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.settings),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SettingsScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                )
              : null,
          body: CustomScrollView(
            controller: _scrollController,
            scrollDirection: Axis.vertical, // Always vertical
            cacheExtent: 2000,
            slivers: [
              if (!isLandscape)
                SliverAppBar(
                  floating: true,
                  title: Text(
                    '5 Year Plan',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.settings),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SettingsScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                  backgroundColor: surfaceColor,
                  elevation: 0,
                  iconTheme: IconThemeData(
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),

              // -------------------------------------------------------------
              // LOGIC FIX: Gate the Habit List behind Settings
              // -------------------------------------------------------------
              settingsAsync.when(
                loading: () =>
                    const SliverToBoxAdapter(child: SizedBox.shrink()),
                error: (err, stack) =>
                    SliverToBoxAdapter(child: Text('Error: $err')),
                data: (settings) {
                  if (settings.isFirstLaunch) {
                    return const SliverToBoxAdapter(child: SizedBox.shrink());
                  }

                  return habitsAsync.when(
                    loading: () {
                      return SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            return isLandscape
                                ? const SizedBox(
                                    width: 320,
                                    child: HabitCardShimmer(),
                                  )
                                : const HabitCardShimmer();
                          }, childCount: 4),
                        ),
                      );
                    },
                    error: (err, stack) =>
                        SliverToBoxAdapter(child: Text('Error: $err')),
                    data: (habits) {
                      // Handle auto-scroll logic
                      if (_pendingScrollToId != null &&
                          !_hasScrolled &&
                          habits.isNotEmpty) {
                        final targetId = _pendingScrollToId!;
                        final index = habits.indexWhere(
                          (h) => h.id == targetId,
                        );

                        if (index != -1) {
                          _hasScrolled = true;
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              final itemSize = isLandscape ? 340.0 : 200.0;
                              final targetPosition = (index * itemSize).clamp(
                                0.0,
                                _scrollController.position.maxScrollExtent,
                              );
                              if (isLandscape) {
                                _landscapeHabitController.animateTo(
                                  targetPosition,
                                  duration: const Duration(milliseconds: 700),
                                  curve: Curves.easeOutCubic,
                                );
                              } else if (_scrollController.hasClients) {
                                _scrollController.animateTo(
                                  targetPosition,
                                  duration: const Duration(milliseconds: 700),
                                  curve: Curves.easeOutCubic,
                                );
                              }
                            }
                          });
                          Future.delayed(const Duration(milliseconds: 800), () {
                            if (mounted) {
                              setState(() {
                                _pendingScrollToId = null;
                              });
                            }
                          });
                        }
                      }

                      // Empty State
                      if (habits.isEmpty) {
                        return SliverFillRemaining(
                          hasScrollBody: false,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 120),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Opacity(
                                    opacity: 0.8,
                                    child: SizedBox(
                                      width: 200,
                                      height: 200,
                                      child: Image.asset(
                                        isDark
                                            ? 'assets/icons/greyscale_night.png'
                                            : 'assets/icons/greyscale.png',
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    'No habits yet',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Tap the + button to start your journey.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: isDark
                                          ? Colors.white38
                                          : Colors.black45,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }

                      // Normal List State
                      if (isLandscape) {
                        return SliverToBoxAdapter(
                          child: SizedBox(
                            height: 400,
                            child: ListView.builder(
                              controller: _landscapeHabitController,
                              padding: const EdgeInsets.fromLTRB(20, 20, 0, 20),
                              scrollDirection: Axis.horizontal,
                              itemCount: habits.length,
                              itemBuilder: (context, index) {
                                final habit = habits[index];
                                final bool isLocked = !isPro && index >= 2;

                                Widget card = SizedBox(
                                  width: 320,
                                  child: HabitCard(habit: habit),
                                );

                                if (isLocked) {
                                  card = _LockOverlay(child: card);
                                }

                                return RepaintBoundary(
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 24),
                                    child: card,
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      } else {
                        return SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final habit = habits[index];
                              final bool isLocked = !isPro && index >= 2;

                              Widget card = HabitCard(habit: habit);

                              if (isLocked) {
                                card = _LockOverlay(child: card);
                              }

                              return RepaintBoundary(
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 24),
                                  child: card,
                                ),
                              );
                            }, childCount: habits.length),
                          ),
                        );
                      }
                    },
                  );
                },
              ),
            ],
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
          floatingActionButton: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton(
                  heroTag: 'chat_btn',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ChatScreen()),
                    );
                  },
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.secondaryContainer,
                  foregroundColor: Theme.of(
                    context,
                  ).colorScheme.onSecondaryContainer,
                  child: const Icon(Icons.try_sms_star),
                ),
                FloatingActionButton.large(
                  heroTag: 'add_btn',
                  onPressed: () async {
                    // NEW: Check limits before adding
                    final currentHabits = habitsAsync.valueOrNull ?? [];

                    // If not Pro and trying to add 3rd habit (index 2+), show paywall
                    if (!isPro && currentHabits.length >= 2) {
                      await RevenueCatUI.presentPaywallIfNeeded("5Y Pro");
                      return;
                    }

                    final newHabitId = await Navigator.of(context).push<String>(
                      MaterialPageRoute(builder: (_) => const AddHabitScreen()),
                    );
                    if (newHabitId != null && mounted) {
                      setState(() {
                        _pendingScrollToId = newHabitId;
                        _hasScrolled = false;
                      });
                    }
                  },
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  foregroundColor: Theme.of(
                    context,
                  ).colorScheme.onPrimaryContainer,
                  child: const Icon(Icons.add),
                ),
              ],
            ),
          ),
        ),

        // ---------------------------------------------
        // ONBOARDING OVERLAY
        // ---------------------------------------------
        if (showOnboarding)
          Positioned.fill(
            child: OnboardingOverlay(onComplete: _completeOnboarding),
          ),
      ],
    );
  }
}

// NEW: Helper widget to lock the habit card
class _LockOverlay extends StatelessWidget {
  final Widget child;

  const _LockOverlay({required this.child});

  @override
  Widget build(BuildContext context) {
    final surfaceContainer = Theme.of(context).colorScheme.surfaceContainer;
    final secondaryContainer = Theme.of(context).colorScheme.secondaryContainer;
    final onSecondaryContainer = Theme.of(
      context,
    ).colorScheme.onSecondaryContainer;
    return Stack(
      children: [
        // 1. The original card, non-interactive
        IgnorePointer(child: child),

        // 2. The Lock Overlay
        Positioned.fill(
          child: ClipRRect(
            // Approximating standard card radius. Adjust if HabitCard is different.
            borderRadius: BorderRadius.circular(24),
            child: GestureDetector(
              onTap: () {
                // Trigger paywall on tap
                RevenueCatUI.presentPaywallIfNeeded("5Y Pro");
              },
              child: Container(
                color: surfaceContainer.withOpacity(
                  0.95,
                ), // Semi-transparent dark overlay
                alignment: Alignment.center,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: secondaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.lock_outline_rounded,
                    color: onSecondaryContainer,
                    size: 32,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
