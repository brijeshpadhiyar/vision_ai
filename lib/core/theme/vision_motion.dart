import 'package:material_ui/material_ui.dart';

/// Centralized motion design tokens (durations, curves & reduced-motion support).
abstract final class VisionMotion {
  /// Micro-interactions (button press, chip toggle, icon feedback): 120–180 ms.
  static const Duration micro = Duration(milliseconds: 150);

  /// Standard UI transitions (card state, theme change, expand/collapse): 200–300 ms.
  static const Duration standard = Duration(milliseconds: 240);

  /// Screen & modal transitions: 250–350 ms.
  static const Duration screen = Duration(milliseconds: 300);

  /// Decorative ambient animations (orb breathing, shimmer): 1–3 s.
  static const Duration decorative = Duration(milliseconds: 2200);

  static const Curve standardCurve = Curves.easeOutCubic;
  static const Curve emphasizedCurve = Curves.easeInOutCubic;
  static const Curve springCurve = Curves.easeOutBack;

  /// Returns `true` when the user enabled Android Reduce Motion / Disable Animations.
  static bool reduceMotion(BuildContext context) {
    final media = MediaQuery.maybeOf(context);
    return (media?.disableAnimations ?? false) ||
        (media?.accessibleNavigation ?? false);
  }

  /// Resolves [duration] to [Duration.zero] when reduced motion is enabled.
  static Duration resolve(BuildContext context, Duration duration) =>
      reduceMotion(context) ? Duration.zero : duration;
}
