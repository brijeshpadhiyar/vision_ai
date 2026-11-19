import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/theme/vision_elevation.dart';

/// Backward-compatible shadow facade backed by [VisionElevation].
abstract final class VisionShadows {
  static List<BoxShadow> glassElevation(
    Brightness brightness, {
    Color? glowColor,
    double glowIntensity = 0.22,
  }) {
    final base = VisionElevation.subtle(brightness);
    if (glowColor == null) return base;
    return <BoxShadow>[
      ...base,
      BoxShadow(
        color: glowColor.withValues(
          alpha:
              (brightness == Brightness.dark
                      ? glowIntensity * 0.32
                      : glowIntensity * 0.20)
                  .clamp(0.05, 0.45),
        ),
        blurRadius: 22,
        spreadRadius: 1,
      ),
    ];
  }

  static List<BoxShadow> ambientGlow(
    Brightness brightness, {
    double intensity = 0.22,
  }) => VisionElevation.primaryGlow(brightness, intensity: intensity);
}
