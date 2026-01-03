import 'dart:math';
import 'package:fiveyear/data/entities.dart';
import 'package:fiveyear/data/habit_provider.dart';
import 'package:fiveyear/data/subscription_service.dart'; //
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart'; // Import for Paywall
import '../../data/theme_colors.dart';

class AddHabitScreen extends ConsumerStatefulWidget {
  const AddHabitScreen({super.key});

  @override
  ConsumerState<AddHabitScreen> createState() => _AddHabitScreenState();
}

class _AddHabitScreenState extends ConsumerState<AddHabitScreen> {
  String name = '';
  String selectedTheme = 'athlete';
  Color backendColor = Colors.green;
  IconData selectedIcon = Icons.emoji_events;

  int _activeStep = 1;
  late FocusNode _nameFocusNode;
  late FocusNode _iconFocusNode;

  final List<IconData> _availableIcons = [
// Achievement & Progress
    Icons.emoji_events, Icons.star, Icons.flag, Icons.check_circle, Icons.timeline,
    Icons.lightbulb, Icons.bolt, Icons.local_fire_department,
    
    // Time & Schedule
    Icons.access_alarm, Icons.timer, Icons.schedule, Icons.today, Icons.alarm_on,
    
    // Fitness & Sports
    Icons.fitness_center, Icons.directions_run, Icons.directions_walk, Icons.hiking,
    Icons.pool, Icons.pedal_bike, Icons.sports_soccer, Icons.sports_basketball,
    
    // Health & Wellness
    Icons.favorite, Icons.healing, Icons.self_improvement, Icons.spa, Icons.water_drop,
    Icons.bed, Icons.bedtime, Icons.psychology,
    
    // Food & Drink
    Icons.restaurant, Icons.lunch_dining, Icons.apple, Icons.coffee, Icons.local_cafe,
    Icons.water, Icons.liquor, Icons.no_food, Icons.fastfood, Icons.local_pizza,
    Icons.cake,
    
    // Learning & Reading
    Icons.school, Icons.book, Icons.menu_book, Icons.language, Icons.science,
    
    // Work & Productivity
    Icons.work, Icons.laptop, Icons.code, Icons.edit,
    
    // Creative & Hobbies
    Icons.music_note, Icons.palette, Icons.brush, Icons.photo_camera, Icons.videogame_asset,
    
    // Finance
    Icons.attach_money, Icons.savings, Icons.shopping_cart, Icons.credit_card,
    Icons.shopping_bag, Icons.store,
    
    // Home & Chores
    Icons.home, Icons.cleaning_services, Icons.local_laundry_service, Icons.kitchen,
    
    // Social
    Icons.people, Icons.chat, Icons.call, Icons.favorite_border,
    
    // Nature & Outdoors
    Icons.local_florist, Icons.park, Icons.pets, Icons.nature,
    
    // Bad Habits & Breaking Habits
    Icons.smoking_rooms, Icons.do_not_disturb, Icons.block, 
    Icons.phone_disabled, Icons.phonelink_erase, Icons.phone_android, Icons.smartphone,
    Icons.cancel, Icons.close, Icons.remove_circle, Icons.warning, Icons.error,
    Icons.no_cell, Icons.mobile_off, Icons.notifications_off, Icons.snooze,
    Icons.local_bar, Icons.wine_bar, Icons.nightlife, Icons.bed_outlined,
    Icons.tv, Icons.tv_off, Icons.laptop_chromebook, Icons.screen_lock_portrait,
    Icons.no_drinks, Icons.smoke_free, Icons.block_flipped,
    
    // Miscellaneous
    Icons.celebration, Icons.card_giftcard, Icons.recycling,
  ];

  @override
  void initState() {
    super.initState();
    _nameFocusNode = FocusNode();
    _iconFocusNode = FocusNode();

    _nameFocusNode.addListener(() {
      if (_nameFocusNode.hasFocus) setState(() => _activeStep = 1);
    });

    backendColor = _getColorForTheme(selectedTheme);
  }

  @override
  void dispose() {
    _nameFocusNode.dispose();
    _iconFocusNode.dispose();
    super.dispose();
  }

  Color _getColorForTheme(String themeKey) {
    if (!themeData.containsKey(themeKey)) return Colors.grey;
    final List<Color> colors = themeData[themeKey]['colors'];
    if (colors.isEmpty) return Colors.black;
    final int currentYear = DateTime.now().year;
    return colors[currentYear % colors.length];
  }

  Color _getReadableColor(Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final HSLColor hsl = HSLColor.fromColor(color);
    if (isDark) {
      return hsl
          .withLightness(max(hsl.lightness, 0.65))
          .withSaturation(max(hsl.saturation, 0.6))
          .toColor();
    } else {
      return hsl.withLightness(min(hsl.lightness, 0.4)).toColor();
    }
  }

  void _updateSelectedColor() {
    setState(() {
      backendColor = _getColorForTheme(selectedTheme);
    });
  }

  void _createHabit() {
    if (name.isEmpty) return;
    final newHabit = Habit()
      ..name = name
      ..colorValue = backendColor.value
      ..theme = selectedTheme
      ..customImagePath = null
      ..iconCodePoint = selectedIcon.codePoint
      ..completedDays = [];

    ref.read(habitRepositoryProvider).addHabit(newHabit);
    Navigator.pop(context, newHabit.id.toString()); // Return ID for scrolling
  }

  Widget _buildStepSection({
    required int stepNumber,
    required String title,
    required Widget child,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isActive = (_activeStep == stepNumber);
    final borderColor = isActive ? activeColor : Colors.transparent;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "$stepNumber. $title",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isActive ? activeColor : colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final activeColor = _getReadableColor(backendColor);

    // NEW: Watch subscription status to lock themes
    final subscriptionAsync = ref.watch(subscriptionStatusProvider);
    final isPro = subscriptionAsync.value ?? false;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              title: const Text(
                "New Habit",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              floating: true,
              pinned: true,
              centerTitle: false,
              backgroundColor: colorScheme.surface,
              foregroundColor: colorScheme.onSurface,
              elevation: 0,
              scrolledUnderElevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                TextButton(
                  onPressed: name.isNotEmpty ? _createHabit : null,
                  child: Text(
                    "Create",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: activeColor,
                    ),
                  ),
                ),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.all(24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // --- STEP 1: HABIT ---
                  _buildStepSection(
                    stepNumber: 1,
                    title: "HABIT",
                    activeColor: activeColor,
                    onTap: () {
                      setState(() => _activeStep = 1);
                      _nameFocusNode.requestFocus();
                    },
                    child: TextField(
                      focusNode: _nameFocusNode,
                      autofocus: true,
                      textInputAction: TextInputAction.next,
                      style: TextStyle(
                        color: colorScheme.onSurface, 
                        fontSize: 18
                      ),
                      cursorColor: activeColor,
                      decoration: InputDecoration(
                        hintText: "e.g. Read 10 pages",
                        hintStyle: TextStyle(
                          color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (val) {
                        setState(() => name = val);
                        _updateSelectedColor();
                      },
                      onSubmitted: (_) {
                        setState(() => _activeStep = 2);
                        _nameFocusNode.unfocus();
                      },
                    ),
                  ),

                  // --- STEP 2: ICON ---
                  _buildStepSection(
                    stepNumber: 2,
                    title: "ICON",
                    activeColor: activeColor,
                    onTap: () {
                      FocusScope.of(context).unfocus();
                      setState(() => _activeStep = 2);
                    },
                    child: SizedBox(
                      height: 60,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _availableIcons.length,
                        itemBuilder: (context, index) {
                          final icon = _availableIcons[index];
                          final isSelected = (icon == selectedIcon);

                          return GestureDetector(
                            onTap: () {
                              FocusScope.of(context).unfocus();
                              setState(() {
                                selectedIcon = icon;
                                _activeStep = 2;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 60,
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? activeColor.withOpacity(0.2)
                                    : colorScheme.surfaceContainerHigh,
                                shape: BoxShape.circle,
                                border: isSelected
                                    ? Border.all(color: activeColor, width: 2)
                                    : Border.all(color: Colors.transparent),
                              ),
                              child: Icon(
                                icon,
                                size: 28,
                                color: isSelected
                                    ? activeColor
                                    : colorScheme.onSurfaceVariant,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // --- STEP 3: THEME ---
                  _buildStepSection(
                    stepNumber: 3,
                    title: "THEME",
                    activeColor: activeColor,
                    onTap: () {
                      FocusScope.of(context).unfocus();
                      setState(() => _activeStep = 3);
                    },
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final buttonWidth = (constraints.maxWidth - 12) / 2;
                        final entries = themeData.entries.toList();

                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: List.generate(entries.length, (index) {
                            final e = entries[index];
                            final key = e.key;
                            final data = e.value;
                            final isSelected = (selectedTheme == key);
                            final rawColor = _getColorForTheme(key);
                            final contrastColor = _getReadableColor(rawColor);

                            // NEW: Lock check (Limit to first 5 themes for free users)
                            final bool isLocked = !isPro && index >= 5;

                            return GestureDetector(
                              onTap: () {
                                if (isLocked) {
                                  // Trigger Paywall
                                  RevenueCatUI.presentPaywallIfNeeded("5Y Pro");
                                  return;
                                }
                                FocusScope.of(context).unfocus();
                                setState(() {
                                  _activeStep = 3;
                                  selectedTheme = key;
                                  _updateSelectedColor();
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: buttonWidth,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: isLocked
                                      ? colorScheme.surfaceContainerHigh.withOpacity(0.5)
                                      : (isSelected
                                          ? contrastColor.withOpacity(0.2)
                                          : colorScheme.surfaceContainerHigh),
                                  border: Border.all(
                                    color: isSelected
                                        ? contrastColor
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Opacity(
                                  opacity: isLocked ? 0.6 : 1.0,
                                  child: Row(
                                    mainAxisAlignment: isLocked
                                        ? MainAxisAlignment.start
                                        : MainAxisAlignment.center,
                                    children: [
                                      if (!isLocked)
                                        Text(
                                          data['name'],
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                            color: isSelected
                                                ? contrastColor
                                                : colorScheme.onSurface,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      if (isLocked) ...[
                                        Icon(
                                          Icons.lock_outline,
                                          size: 20,
                                          color: colorScheme.onSurface,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            data['name'],
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                              color: colorScheme.onSurface,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ]
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 40),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}