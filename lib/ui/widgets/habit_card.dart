import 'dart:io';
import 'dart:math';

import 'package:fiveyear/data/habit_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/habit_schema.dart';
import '../../data/theme_colors.dart';
import '../screens/calendar_screen.dart';
import 'mosaic_painter.dart';

class HabitCard extends ConsumerStatefulWidget {
  final Habit habit;
  final int sourceWidth;

  const HabitCard({super.key, required this.habit, this.sourceWidth = 1024});

  @override
  ConsumerState<HabitCard> createState() => _HabitCardState();
}

class _HabitCardState extends ConsumerState<HabitCard> {
  late PageController _yearController;
  final int _historyLength = 100;
  late int _displayYear;
  final int _anchorYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _displayYear = _anchorYear;
    _yearController = PageController(initialPage: _historyLength);
  }

  @override
  void dispose() {
    _yearController.dispose();
    super.dispose();
  }

  Color _getColorForPageIndex(int index) {
    final yearsInPast = _historyLength - index;
    final year = _anchorYear - yearsInPast;
    int yearDiff = year - _anchorYear;
    int assetIndex = ((yearDiff % 5) + 5) % 5 + 1;

    try {
      final themeName = widget.habit.theme;
      if (themeData.containsKey(themeName)) {
        final colors = themeData[themeName]['colors'] as List<Color>;
        return colors[assetIndex - 1];
      }
    } catch (e) {
      // Fallthrough
    }
    return Color(widget.habit.colorValue);
  }

  Color _getSmoothColor() {
    if (!_yearController.hasClients) {
      return _getColorForPageIndex(_historyLength);
    }
    final double page = _yearController.page ?? _historyLength.toDouble();
    final int prevIndex = page.floor();
    final int nextIndex = page.ceil();
    final double percent = page - prevIndex;
    final Color colorA = _getColorForPageIndex(prevIndex);
    final Color colorB = _getColorForPageIndex(nextIndex);
    return Color.lerp(colorA, colorB, percent) ?? colorA;
  }

  /// Helper for Light Mode borders (Vapor/Paper style)
  Color _getCrispBorder(Color fill) {
    final hsl = HSLColor.fromColor(fill);
    if (hsl.lightness > 0.5) {
      return hsl.withLightness(max(0.0, hsl.lightness - 0.2)).toColor();
    } else {
      return hsl.withLightness(max(0.0, hsl.lightness - 0.15)).toColor();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final pixelRatio = MediaQuery.of(context).devicePixelRatio;
    int targetCacheWidth = (screenWidth * pixelRatio).round();
    if (targetCacheWidth > widget.sourceWidth)
      targetCacheWidth = widget.sourceWidth;

    const double borderRadius = 12.0;
    const double borderStroke = 0.5;

    return GestureDetector(
      onTap: () async {
        final List<String>? result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                CalendarScreen(habit: widget.habit, initialYear: _displayYear),
          ),
        );
        if (result != null) {
          ref
              .read(habitRepositoryProvider)
              .updateHabitDays(widget.habit.id, result);
        }
      },
      child: AnimatedBuilder(
        animation: _yearController,
        builder: (context, child) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          var currentColor = _getSmoothColor();

          Color baseTone;
          Color textColor;
          Color uiColor;
          Color gridFill;
          Color gridBorder;

          // CALCULATE ACCENTS
          var hsl = HSLColor.fromColor(currentColor);

          if (isDark) {
            baseTone = Color.alphaBlend(
              currentColor.withOpacity(0.15),
              Colors.black,
            );
            textColor = Colors.white;
            uiColor = hsl.withLightness(max(hsl.lightness, 0.7)).toColor();
            gridFill = const Color(0xFF121212);
            gridBorder = HSLColor.fromColor(baseTone).withLightness(0.2).toColor();
          } else {
            // --- LIGHT MODE CONFIG ---
            baseTone = Color.alphaBlend(
              currentColor.withOpacity(0.15),
              Colors.white,
            );
            textColor = Colors.black;
            uiColor = hsl.withLightness(min(hsl.lightness, 0.3)).toColor();

            gridFill = currentColor;
            gridBorder = _getCrispBorder(currentColor);
          }

          // --- RESOLVE ICON DATA ---
          IconData habitIcon = widget.habit.iconCodePoint != null
              ? IconData(
                  widget.habit.iconCodePoint!,
                  fontFamily: 'MaterialIcons',
                )
              : Icons.emoji_events;

          // --- CONTRAST CALCULATIONS FOR ICON ---
          Color iconBg;
          Color iconFg;

          if (isDark) {
            // Dark Mode: Glassy background, Neon Icon
            iconBg = currentColor.withOpacity(0.2);
            iconFg = uiColor;
          } else {
            // Light Mode: Solid background, Black/White Icon based on luminance
            iconBg = currentColor;
            // Calculate luminance: 0.0 (dark) to 1.0 (light).
            // If background is light (>0.5), use Black icon. Otherwise White.
            iconFg = iconBg.computeLuminance() > 0.5
                ? Colors.black87
                : Colors.white;
          }
          return Container(
            decoration: BoxDecoration(
              color: isDark ? currentColor.withAlpha(15):currentColor.withAlpha(50) ,
              borderRadius: BorderRadius.circular(20),
        
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: iconBg,
                        shape: BoxShape.circle,
                        // In dark mode, add a thin border to define the circle against the dark card
                      ),
                      child: Icon(habitIcon, color: iconFg, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.habit.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                          color: textColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      _displayYear.toString(),
                      style: TextStyle(
                        color: uiColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                AspectRatio(
                  aspectRatio: 20 / 19,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(borderRadius),
                        child: PageView.builder(
                          controller: _yearController,
                          itemCount: _historyLength + 1,
                          onPageChanged: (index) {
                            final yearsInPast = _historyLength - index;
                            final newYear = _anchorYear - yearsInPast;
                            if (_displayYear != newYear) {
                              setState(() => _displayYear = newYear);
                            }
                          },
                          itemBuilder: (context, index) {
                            final yearsInPast = _historyLength - index;
                            final year = _anchorYear - yearsInPast;
                            int yearDiff = year - _anchorYear;
                            int assetIndex = ((yearDiff % 5) + 5) % 5 + 1;

                            return Stack(
                              fit: StackFit.expand,
                              children: [
                                widget.habit.customImagePath != null
                                    ? Image.file(
                                        File(widget.habit.customImagePath!),
                                        fit: BoxFit.cover,
                                        cacheWidth: targetCacheWidth,
                                      )
                                    : Image.asset(
                                        'assets/habits/${widget.habit.theme}/$assetIndex.jpg',
                                        fit: BoxFit.cover,
                                        cacheWidth: targetCacheWidth,
                                        frameBuilder:
                                            (context, child, frame, wasSync) {
                                              if (wasSync) return child;
                                              return AnimatedOpacity(
                                                opacity: frame == null ? 0 : 1,
                                                duration: const Duration(
                                                  milliseconds: 300,
                                                ),
                                                curve: Curves.easeOut,
                                                child: child,
                                              );
                                            },
                                      ),
                                CustomPaint(
                                  painter: MosaicPainter(
                                    completedDays: widget.habit.completedDays,
                                    year: year,
                                    fillColor: gridFill,
                                    borderColor: gridBorder,
                                  ),
                                  size: Size.infinite,
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(borderRadius),
                            border: Border.all(
                              color: uiColor,
                              width: borderStroke,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
