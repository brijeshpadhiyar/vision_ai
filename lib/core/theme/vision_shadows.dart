import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/theme/vision_colors.dart';

/// Soft elevation shadows and ambient accent glows for Liquid Glass layers.
abstract final class VisionShadows {
  static List<BoxShadow> glassElevation(
    Brightness brightness, {
    Color? glowColor,
    double glowIntensity = 0.0,
  }) {
    final isDark = brightness == Brightness.dark;
    return <BoxShadow>[
      BoxShadow(
        color: isDark
            ? Colors.black.withValues(alpha: 0.42)
            : const Color(0xFF0A1220).withValues(alpha: 0.08),
        blurRadius: isDark ? 26 : 18,
        offset: const Offset(0, 10),
        spreadRadius: isDark ? -4 : -2,
      ),
      if (glowColor != null && glowIntensity > 0)
        BoxShadow(
          color: glowColor.withValues(
            alpha: (isDark ? 0.24 : 0.16) * glowIntensity,
          ),
          blurRadius: 24 * glowIntensity,
          spreadRadius: 1,
        ),
    ];
  }

  static List<BoxShadow> orbGlow(Color accent, {double intensity = 0.55}) {
    return <BoxShadow>[
      BoxShadow(
        color: accent.withValues(alpha: 0.38 * intensity),
        blurRadius: 36,
        spreadRadius: 4,
      ),
      BoxShadow(
        color: VisionColors.accentSecondary.withValues(alpha: 0.22 * intensity),
        blurRadius: 58,
        spreadRadius: 8,
      ),
    ];
  }
}
