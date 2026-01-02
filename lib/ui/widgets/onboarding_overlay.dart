import 'package:flutter/material.dart';

class OnboardingOverlay extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingOverlay({super.key, required this.onComplete});

  @override
  State<OnboardingOverlay> createState() => _OnboardingOverlayState();
}

class _OnboardingOverlayState extends State<OnboardingOverlay> {
  int _currentIndex = 0;

final List<String> _onboardingSteps = [
  "Greatness is just doing the basics",
  "Over and over again",
  "Chop wood, carry water"
];

  void _handleTap() {
    if (_currentIndex < _onboardingSteps.length - 1) {
      setState(() {
        _currentIndex++;
      });
    } else {
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: colorScheme.surface,
      child: InkWell(
        onTap: _handleTap,
        // 1. Make splash subtle by using low opacity onSurface color
        splashColor: colorScheme.onSurface.withOpacity(0.01),
        // 2. Make the background highlight (hold state) barely visible
        highlightColor: colorScheme.onSurface.withOpacity(0.02),
        // 3. Use InkRipple for a smoother, less "jarring" expansion animation
        splashFactory: InkRipple.splashFactory, 
        child: SizedBox.expand(
          // SizedBox.expand ensures the InkWell covers the entire screen,
          // not just the area the text occupies.
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 800),
                      reverseDuration: const Duration(milliseconds: 400),
                      switchInCurve: Curves.easeOutQuart,
                      switchOutCurve: Curves.easeInQuart,
                      transitionBuilder:
                          (Widget child, Animation<double> animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.0, 0.05),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: Text(
                        _onboardingSteps[_currentIndex],
                        key: ValueKey<int>(_currentIndex),
                        textAlign: TextAlign.center,
                        style: textTheme.headlineSmall?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                          height: 1.5,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
                // This Column contains the pills and the "Tap to continue" text,
                // which should remain at a fixed position near the bottom.
                Column(
                  children: [
                    // Progress Indicator Dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_onboardingSteps.length, (index) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 8,
                          width: 8,
                          decoration: BoxDecoration(
                            color: _currentIndex == index
                                ? colorScheme.primary
                                : colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 32),
                    AnimatedOpacity(
                      opacity: 0.4,
                      duration: const Duration(milliseconds: 1000),
                      child: SizedBox(
                        width: 150, // Fixed width to prevent layout shifts
                        child: Text(
                          _currentIndex == _onboardingSteps.length - 1
                              ? "Tap to start"
                              : "Tap to continue",
                          textAlign: TextAlign.center,
                          style: textTheme.labelMedium,
                        ),
                      ),
                    ),
                    const SizedBox(height: 60), // Bottom padding
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}