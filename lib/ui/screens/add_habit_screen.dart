import 'dart:math';
import 'package:fiveyear/data/habit_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/habit_schema.dart';
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
    Icons.emoji_events, Icons.star, Icons.flag, Icons.check_circle, Icons.timeline,
    Icons.lightbulb, Icons.bolt, Icons.local_fire_department, Icons.access_alarm,
    Icons.timer, Icons.schedule, Icons.today, Icons.fitness_center, Icons.book,
    Icons.water_drop, Icons.directions_run, Icons.bed, Icons.restaurant, Icons.work,
    Icons.code, Icons.music_note, Icons.palette, Icons.local_florist, Icons.self_improvement,
    Icons.hiking, Icons.pool, Icons.pedal_bike, Icons.sports_soccer, Icons.spa,
    Icons.school, Icons.language, Icons.edit, Icons.monitor, Icons.attach_money,
    Icons.savings, Icons.shopping_cart, Icons.cleaning_services, Icons.local_laundry_service,
    Icons.pets, Icons.kitchen, Icons.coffee, Icons.celebration, Icons.photo_camera,
    Icons.videogame_asset, Icons.smoke_free, Icons.do_not_disturb,
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
    Navigator.pop(context);
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
          // MATERIAL 3 FIX: Use 'surfaceContainer' for cards.
          // This creates a solid, distinct layer above the 'surface' background.
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
                // Use standard onSurface (or primary if active)
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

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        // Default scaffold background (surface)
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
                                    : colorScheme.surfaceContainerHigh, // Slightly lighter than card
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
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: themeData.entries.map((e) {
                            final key = e.key;
                            final data = e.value;
                            final isSelected = (selectedTheme == key);
                            final rawColor = _getColorForTheme(key);
                            final contrastColor = _getReadableColor(rawColor);

                            return GestureDetector(
                              onTap: () {
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
                                  color: isSelected
                                      ? contrastColor.withOpacity(0.2)
                                      : colorScheme.surfaceContainerHigh,
                                  border: Border.all(
                                    color: isSelected
                                        ? contrastColor
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    data['name'],
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: isSelected
                                          ? contrastColor
                                          : colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
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