import 'dart:math';
import 'dart:ui';
import 'package:fiveyear/data/entities.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/habit_provider.dart';
import '../../data/theme_colors.dart';

class DailyCheckInScreen extends ConsumerStatefulWidget {
  const DailyCheckInScreen({super.key});

  @override
  ConsumerState<DailyCheckInScreen> createState() => _DailyCheckInScreenState();
}

class _DailyCheckInScreenState extends ConsumerState<DailyCheckInScreen> {
  late PageController _pageController;
  int _currentIndex = 0;
  bool _isCompletedView = false;

  final List<Habit> _completedSessionHabits = [];
  final List<Habit> _skippedSessionHabits = [];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Color _getHabitColor(Habit habit) {
    try {
      if (themeData.containsKey(habit.theme)) {
        final colors = themeData[habit.theme]['colors'] as List<Color>;
        if (colors.isNotEmpty) return colors[0];
      }
    } catch (_) {}
    return Color(habit.colorValue);
  }

  String _getTodayString() {
    final now = DateTime.now();
    final start = DateTime(now.year, 1, 1);
    final dayNum = now.difference(start).inDays;
    return "${now.year}-$dayNum";
  }

  void _onHabitCompleted(Habit habit) async {
    final currentData = habit.completedDays;
    final today = _getTodayString();

    if (!currentData.contains(today)) {
      final newData = List<String>.from(currentData)..add(today);
      ref.read(habitRepositoryProvider).updateHabitDays(habit.id, newData);
      _completedSessionHabits.add(habit);
    }

    await Future.delayed(const Duration(milliseconds: 400));
    _next();
  }

  void _onHabitSkipped(Habit habit) {
    HapticFeedback.selectionClick();
    final currentData = habit.completedDays;
    final today = _getTodayString();

    if (currentData.contains(today)) {
      final newData = List<String>.from(currentData)..remove(today);
      ref.read(habitRepositoryProvider).updateHabitDays(habit.id, newData);
    }

    _skippedSessionHabits.add(habit);
    _next();
  }

  void _next() {
    final habits = ref.read(habitsProvider).value ?? [];
    if (_currentIndex < habits.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutQuart,
      );
    } else {
      setState(() => _isCompletedView = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final habitsAsync = ref.watch(habitsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: habitsAsync.when(
        data: (habits) {
          if (habits.isEmpty)
            return Center(
              child: Text(
                "No habits found",
                style: TextStyle(color: colorScheme.onSurface),
              ),
            );

          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: _isCompletedView
                ? _buildSummaryView()
                : _buildQuestionFlow(habits),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text("Error: $e")),
      ),
    );
  }

  Widget _buildQuestionFlow(List<Habit> habits) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      key: const ValueKey('questions'),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(Icons.close, color: colorScheme.onSurface),
                  onPressed: () => Navigator.pop(context),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      "${_currentIndex + 1} / ${habits.length}",
                      key: ValueKey(_currentIndex),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: PageView.builder(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (index) => setState(() => _currentIndex = index),
              itemCount: habits.length,
              itemBuilder: (context, index) {
                return HabitCheckCard(
                  habit: habits[index],
                  onYes: () => _onHabitCompleted(habits[index]),
                  onNo: () => _onHabitSkipped(habits[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryView() {
    final colorScheme = Theme.of(context).colorScheme;
    final total = _completedSessionHabits.length + _skippedSessionHabits.length;
    final percent = total == 0
        ? 0
        : (_completedSessionHabits.length / total * 100).toInt();

    return SafeArea(
      key: const ValueKey('summary'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            Text(
              "All Done!",
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "You completed $percent% of your habits.",
              style: TextStyle(
                fontSize: 16,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            if (_completedSessionHabits.isNotEmpty) ...[
              Text(
                "COMPLETED",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.green[400],
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.1,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: _completedSessionHabits.length,
                  itemBuilder: (context, index) =>
                      _buildCompletedCard(_completedSessionHabits[index]),
                ),
              ),
            ] else
              const Spacer(),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "Finish",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedCard(Habit habit) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = _getHabitColor(habit);

    // FIX: Make the background SOLID by blending the tint with the surface color.
    final tintOpacity = isDark ? 0.15 : 0.25;
    final bgColor = Color.alphaBlend(
      color.withOpacity(tintOpacity),
      colorScheme.surface,
    );

    final borderColor = isDark
        ? color.withOpacity(0.4)
        : color.withOpacity(0.6);

    // Determine text color based on background luminance for readability
    final textColor = bgColor.computeLuminance() > 0.5
        ? Colors.black87
        : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 2),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: const Icon(Icons.check, color: Colors.black87, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            habit.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// HABIT CHECK CARD
// -----------------------------------------------------------------------------
class HabitCheckCard extends StatelessWidget {
  final Habit habit;
  final VoidCallback onYes;
  final VoidCallback onNo;

  const HabitCheckCard({
    super.key,
    required this.habit,
    required this.onYes,
    required this.onNo,
  });

  Color _getHabitColor() {
    try {
      if (themeData.containsKey(habit.theme)) {
        final colors = themeData[habit.theme]['colors'] as List<Color>;
        if (colors.isNotEmpty) return colors[0];
      }
    } catch (_) {}
    return Color(habit.colorValue);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 2),
          Text(
            "Did you complete",
            style: TextStyle(
              fontSize: 20,
              color: colorScheme.onSurfaceVariant,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Text(
              habit.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 36,
                height: 1.1,
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface,
                letterSpacing: -1.0,
              ),
            ),
          ),
          const Spacer(flex: 3),

          AnimatedCheckButton(color: _getHabitColor(), onTap: onYes),

          const Spacer(flex: 1),
          TextButton(
            onPressed: onNo,
            style: TextButton.styleFrom(
              foregroundColor: colorScheme.onSurfaceVariant,
            ),
            child: const Text("Skip for now", style: TextStyle(fontSize: 16)),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}

class AnimatedCheckButton extends StatefulWidget {
  final Color color;
  final VoidCallback onTap;

  const AnimatedCheckButton({
    super.key,
    required this.color,
    required this.onTap,
  });

  @override
  State<AnimatedCheckButton> createState() => _AnimatedCheckButtonState();
}

class _AnimatedCheckButtonState extends State<AnimatedCheckButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _checkAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.ease),
      ),
    );

    _checkAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (_isPressed) return;
    setState(() => _isPressed = true);
    HapticFeedback.heavyImpact();
    _controller.forward();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // --- COLORS ---
    final idleOpacity = isDark ? 0.05 : 0.2;
    final activeOpacity = isDark ? 0.25 : 0.4;

    // FIX: Make button background solid
    final bgColor = Color.alphaBlend(
      widget.color.withOpacity(_isPressed ? activeOpacity : idleOpacity),
      colorScheme.surface,
    );

    final borderOpacity = isDark ? 0.3 : 0.5;
    final borderColor = _isPressed
        ? widget.color
        : widget.color.withOpacity(borderOpacity);

    // Contrast check for "YES" text
    final textStyleColor = bgColor.computeLuminance() > 0.5
        ? Colors.black87
        : Colors.white;

    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        height: 260,
        width: 260,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: borderColor, width: 2),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedOpacity(
              opacity: _isPressed ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Padding(
                padding: const EdgeInsets.only(top: 140),
                child: Text(
                  "YES",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                    color: textStyleColor,
                  ),
                ),
              ),
            ),
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    // Use solid surface colors
                    color: colorScheme.surfaceContainerHigh,
                    border: Border.all(
                      color: colorScheme.outlineVariant,
                      width: 4,
                    ),
                  ),
                ),
                AnimatedBuilder(
                  animation: _scaleAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.color,
                          boxShadow: [
                            BoxShadow(
                              color: widget.color.withOpacity(0.4),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                CustomPaint(
                  size: const Size(100, 100),
                  painter: CheckmarkPainter(
                    progress: _checkAnimation,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class CheckmarkPainter extends CustomPainter {
  final Animation<double> progress;
  final Color color;

  CheckmarkPainter({required this.progress, required this.color})
    : super(repaint: progress);

  @override
  void paint(Canvas canvas, Size size) {
    if (progress.value == 0) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    path.moveTo(size.width * 0.28, size.height * 0.53);
    path.lineTo(size.width * 0.45, size.height * 0.70);
    path.lineTo(size.width * 0.75, size.height * 0.35);

    final pathMetrics = path.computeMetrics();
    final extractPath = Path();

    for (var metric in pathMetrics) {
      extractPath.addPath(
        metric.extractPath(0, metric.length * progress.value),
        Offset.zero,
      );
    }

    canvas.drawPath(extractPath, paint);
  }

  @override
  bool shouldRepaint(covariant CheckmarkPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
