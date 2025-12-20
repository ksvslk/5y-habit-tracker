import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/habit_schema.dart';
import '../../data/habit_provider.dart';
import '../../data/theme_colors.dart';

class EditHabitScreen extends ConsumerStatefulWidget {
  final Habit habit;

  const EditHabitScreen({super.key, required this.habit});

  @override
  ConsumerState<EditHabitScreen> createState() => _EditHabitScreenState();
}

class _EditHabitScreenState extends ConsumerState<EditHabitScreen> {
  late String name;
  late String selectedTheme;
  late IconData selectedIcon;
  late Color backendColor;

  int _activeStep = 1;
  late FocusNode _nameFocusNode;
  late FocusNode _iconFocusNode;

  final List<IconData> _availableIcons = [
    Icons.emoji_events,
    Icons.star,
    Icons.flag,
    Icons.check_circle,
    Icons.timeline,
    Icons.lightbulb,
    Icons.bolt,
    Icons.local_fire_department,
    Icons.access_alarm,
    Icons.timer,
    Icons.schedule,
    Icons.today,
    Icons.fitness_center,
    Icons.book,
    Icons.water_drop,
    Icons.directions_run,
    Icons.bed,
    Icons.restaurant,
    Icons.work,
    Icons.code,
    Icons.music_note,
    Icons.palette,
    Icons.local_florist,
    Icons.self_improvement,
  ];

  @override
  void initState() {
    super.initState();
    _nameFocusNode = FocusNode();
    _iconFocusNode = FocusNode();

    name = widget.habit.name;
    selectedTheme = widget.habit.theme;
    selectedIcon = IconData(
      widget.habit.iconCodePoint!,
      fontFamily: 'MaterialIcons',
    );

    backendColor = _getColorForTheme(selectedTheme);
    if (backendColor == Colors.black && widget.habit.colorValue != 0) {
      backendColor = Color(widget.habit.colorValue);
    }

    _nameFocusNode.addListener(() {
      if (_nameFocusNode.hasFocus) setState(() => _activeStep = 1);
    });
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

  void _saveHabit() {
    if (name.isEmpty) return;

    final updatedHabit = widget.habit
      ..name = name
      ..colorValue = backendColor.value
      ..theme = selectedTheme
      ..iconCodePoint = selectedIcon.codePoint;

    ref.read(habitRepositoryProvider).updateHabit(updatedHabit);

    Navigator.pop(context, updatedHabit);
  }

  // NEW: Delete Logic
  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Habit"),
        content: const Text(
          "Are you sure you want to delete this habit? This cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx); // Close dialog
              _deleteHabit();
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _deleteHabit() {
    ref.read(habitRepositoryProvider).deleteHabit(widget.habit.id);
    // Return a specific flag indicating deletion
    Navigator.pop(context, 'DELETED');
  }

  Widget _buildStepSection({
    required int stepNumber,
    required String title,
    required Widget child,
    required Color activeColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final isActive = (_activeStep == stepNumber);
    final borderColor = isActive ? activeColor : Colors.transparent;
    final cardColor = isDark
        ? Colors.grey[900]!.withOpacity(0.5)
        : Colors.white;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 2),

          // CHANGED: Removed the isActive check that added a colored shadow.
          // We force an empty list so no background glow appears.
          boxShadow: [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "$stepNumber. $title",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isActive
                    ? activeColor
                    : (isDark ? Colors.grey[500] : Colors.grey[600]),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final surfaceColor = Theme.of(context).colorScheme.surface;
    final activeColor = _getReadableColor(backendColor);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: surfaceColor,
        appBar: AppBar(
          title: Text(
            "Edit Habit",
            style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
          ),
          backgroundColor: surfaceColor,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.close, color: textColor),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            TextButton(
              onPressed: name.isNotEmpty ? _saveHabit : null,
              child: Text(
                "Save",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: activeColor,
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                _buildStepSection(
                  stepNumber: 1,
                  title: "HABIT",
                  activeColor: activeColor,
                  isDark: isDark,
                  onTap: () {
                    setState(() => _activeStep = 1);
                    _nameFocusNode.requestFocus();
                  },
                  child: TextFormField(
                    initialValue: name,
                    focusNode: _nameFocusNode,
                    textInputAction: TextInputAction.next,
                    style: TextStyle(color: textColor, fontSize: 18),
                    cursorColor: activeColor,
                    decoration: InputDecoration(
                      hintText: "e.g. Read 10 pages",
                      hintStyle: TextStyle(
                        color: isDark ? Colors.grey[600] : Colors.grey[400],
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (val) {
                      setState(() => name = val);
                      _updateSelectedColor();
                    },
                    onFieldSubmitted: (_) {
                      setState(() => _activeStep = 2);
                      _nameFocusNode.unfocus();
                    },
                  ),
                ),

                _buildStepSection(
                  stepNumber: 2,
                  title: "ICON",
                  activeColor: activeColor,
                  isDark: isDark,
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
                                  : (isDark
                                        ? Colors.grey[800]
                                        : Colors.grey[100]),
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
                                  : (isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[500]),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                _buildStepSection(
                  stepNumber: 3,
                  title: "THEME",
                  activeColor: activeColor,
                  isDark: isDark,
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

                          final inactiveBg = isDark
                              ? Colors.grey[800]!
                              : const Color(0xFFF4F4F5);
                          final inactiveText = isDark
                              ? Colors.grey[400]
                              : Colors.black87;

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
                                    : inactiveBg,
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
                                        : inactiveText,
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

                // NEW: Delete Button at bottom
                const SizedBox(height: 20),
                Center(
                  child: TextButton.icon(
                    onPressed: _confirmDelete,
                    icon: Icon(Icons.delete_outline, color: Colors.red[400]),
                    label: Text(
                      "Delete Habit",
                      style: TextStyle(
                        color: Colors.red[400],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
