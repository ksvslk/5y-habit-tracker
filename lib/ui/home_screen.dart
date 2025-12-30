import 'package:fiveyear/data/app_settings_provider.dart';
import 'package:fiveyear/data/habit_provider.dart';
import 'package:fiveyear/ui/screens/add_habit_screen.dart';
import 'package:fiveyear/ui/screens/chat_screen.dart';
import 'package:fiveyear/ui/screens/settings_screen.dart';
import 'package:fiveyear/ui/widgets/first_launch_dialog.dart';
import 'package:fiveyear/ui/widgets/habit_card.dart';
import 'package:fiveyear/ui/widgets/habit_card_shimmer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  String? _pendingScrollToId;
  bool _hasScrolled = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(appSettingsProvider);
    final habitsAsync = ref.watch(habitsProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = Theme.of(context).colorScheme.surface;

    bool showOnboarding = false;
    settingsAsync.whenData((settings) {
      if (settings.isFirstLaunch) {
        showOnboarding = true;
      }
    });


    return Stack(
      children: [
        Scaffold(
          body: CustomScrollView(
            controller: _scrollController,
            cacheExtent: 2000,
            slivers: [
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
                    // The color is already handled by the SliverAppBar.iconTheme below,
                    // so it will automatically switch between black/white based on 'isDark'.
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
              habitsAsync.when(
                loading: () => SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      return const HabitCardShimmer();
                    }, childCount: 4),
                  ),
                ),
                error: (err, stack) =>
                    SliverToBoxAdapter(child: Text('Error: $err')),
                data: (habits) {
                  // Perform scroll if we have a pending scroll
                  if (_pendingScrollToId != null &&
                      !_hasScrolled &&
                      habits.isNotEmpty) {
                    final targetId = _pendingScrollToId!;
                    final index = habits.indexWhere((h) => h.id == targetId);

                    if (index != -1) {
                      // Mark as scrolled immediately to prevent multiple attempts
                      _hasScrolled = true;

                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (_scrollController.hasClients && mounted) {
                          // Calculate position
                          // AppBar (~56) + each card height + padding
                          // Adjust this value based on your actual HabitCard height
                          final cardHeight =
                              200.0; // Estimate, adjust as needed
                          final targetPosition = (index * cardHeight).clamp(
                            0.0,
                            _scrollController.position.maxScrollExtent,
                          );

                          _scrollController.animateTo(
                            targetPosition,
                            duration: const Duration(milliseconds: 700),
                            curve: Curves.easeOutCubic,
                          );
                        }
                      });

                      // Clear the pending ID after a delay
                      Future.delayed(const Duration(milliseconds: 800), () {
                        if (mounted) {
                          setState(() {
                            _pendingScrollToId = null;
                          });
                        }
                      });
                    }
                  }

                  if (habits.isEmpty) {
                    bool isDarkMode =
                        Theme.of(context).brightness == Brightness.dark;

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
                                // WRAPPER: This SizedBox reserves the pixels immediately
                                child: SizedBox(
                                  width: 200,
                                  height:
                                      200, // <--- CRITICAL: Defines the height before the image exists
                                  child: Image.asset(
                                    isDarkMode
                                        ? 'assets/icons/greyscale_night.png'
                                        : 'assets/icons/greyscale.png',
                                    fit: BoxFit
                                        .contain, // Ensures the image doesn't stretch if it's not perfectly square
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'No habits yet',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: isDarkMode
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
                                  color: isDarkMode
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

                  return SliverPadding(
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
       backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                  foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
                  child: const Icon(Icons.try_sms_star),
                ),
                FloatingActionButton.large(
                  heroTag: 'add_btn',
                  onPressed: () async {
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
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                  child: const Icon(Icons.add),
                ),
              ],
            ),
          ),
        ),

        if (showOnboarding)
          Container(
            color: Colors.black54,
            child: const Center(child: FirstLaunchDialog()),
          ),
      ],
    );
  }
}
