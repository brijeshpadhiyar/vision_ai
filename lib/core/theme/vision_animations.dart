import 'package:material_ui/material_ui.dart';

/// Centralized motion timings, curves, and reduced-motion helpers for VISION AI.
abstract final class VisionAnimations {
  /// Micro-interactions: button press, chip toggle, icon pulse (120–220 ms).
  static const Duration micro = Duration(milliseconds: 160);
  static const Duration microFast = Duration(milliseconds: 120);

  /// Standard UI transitions: cards, panels, tabs, chat messages (220–350 ms).
  static const Duration standard = Duration(milliseconds: 280);
  static const Duration standardFast = Duration(milliseconds: 220);

  /// Large structural transitions: routes, sheets, dialogs (350–500 ms).
  static const Duration large = Duration(milliseconds: 400);
  static const Duration entrance = Duration(milliseconds: 460);

  /// Ambient orb cycles.
  static const Duration orbBreath = Duration(milliseconds: 3400);
  static const Duration orbOrbit = Duration(milliseconds: 2600);
  static const Duration shimmerCycle = Duration(milliseconds: 1400);

  static const Curve standardCurve = Curves.easeOutCubic;
  static const Curve emphasizedCurve = Curves.easeOutQuart;
  static const Curve springCurve = Curves.easeOutBack;
  static const Curve breathCurve = Curves.easeInOutSine;

  /// Returns `true` when the user enabled reduced motion / disabled animations.
  static bool isReducedMotion(BuildContext context) {
    return MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }

  /// Resolves [normal] or [Duration.zero] when reduced motion is active.
  static Duration resolveDuration(
    BuildContext context,
    Duration normal, {
    Duration? reduced,
  }) {
    if (isReducedMotion(context)) {
      return reduced ?? Duration.zero;
    }
    return normal;
  }
}
