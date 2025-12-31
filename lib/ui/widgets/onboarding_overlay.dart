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
    "Time passes either way",
    "In 5 years, you'll be someone better",
    "Best time to start is now"
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
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 800),
                  reverseDuration: const Duration(milliseconds: 400),
                  switchInCurve: Curves.easeOutQuart,
                  switchOutCurve: Curves.easeInQuart,
                  transitionBuilder: (Widget child, Animation<double> animation) {
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
                
                const SizedBox(height: 60),
                
                // Progress Indicator Dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_onboardingSteps.length, (index) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 8,
                      width: _currentIndex == index ? 24 : 8,
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
                  child: Text(
                    _currentIndex == _onboardingSteps.length - 1 
                        ? "Tap to start" 
                        : "Tap to continue",
                    style: textTheme.labelMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}