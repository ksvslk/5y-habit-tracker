import 'package:flutter/material.dart';

class TypingIndicator extends StatefulWidget {
  final bool isDark;
  const TypingIndicator({super.key, required this.isDark});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dotColor = widget.isDark ? Colors.white70 : Colors.black54;

    return Container(
      width: 48,
      height: 24,
      alignment: Alignment.center, // CHANGED: Center vertically
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center, // CHANGED: Center items
        children: List.generate(3, (index) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              // 1. Staggered time (0.0 to 1.0)
              double t = (_controller.value + (index * 0.2)) % 1.0;

              double offsetY = 0;

              // 2. Animate only first 50% of cycle
              if (t < 0.5) {
                // Split into UP (0.0-0.25) and DOWN (0.25-0.5)
                if (t < 0.25) {
                  // GOING UP: Fast -> Slow
                  double progress = t * 4.0;
                  offsetY = Curves.easeOutCubic.transform(progress) * -8;
                } else {
                  // GOING DOWN: Slow -> Fast
                  double progress = (t - 0.25) * 4.0;
                  offsetY = (1.0 - Curves.easeInCubic.transform(progress)) * -8;
                }
              }

              return Transform.translate(
                offset: Offset(0, offsetY),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}
