import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/theme/vision_colors.dart';

/// Centralized elevation and subtle shadow tokens for Midnight Violet & Pearl Lavender.
abstract final class VisionElevation {
  static const double none = 0;
  static const double low = 2;
  static const double medium = 6;
  static const double high = 12;

  static List<BoxShadow> subtle(Brightness brightness) => <BoxShadow>[
    BoxShadow(
      color: brightness == Brightness.dark
          ? VisionColorTokens.dark.shadow
          : VisionColorTokens.light.shadow,
      blurRadius: brightness == Brightness.dark ? 18 : 14,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> elevated(Brightness brightness) => <BoxShadow>[
    BoxShadow(
      color: brightness == Brightness.dark
          ? VisionColorTokens.dark.shadow.withValues(alpha: 0.55)
          : VisionColorTokens.light.shadow.withValues(alpha: 0.14),
      blurRadius: 24,
      offset: const Offset(0, 10),
    ),
  ];

  static List<BoxShadow> primaryGlow(
    Brightness brightness, {
    double intensity = 0.22,
  }) => <BoxShadow>[
    BoxShadow(
      color: VisionColors.primaryAccent(brightness)
          .withValues(alpha: intensity.clamp(0.05, 0.5)),
      blurRadius: 26,
      spreadRadius: 1,
    ),
  ];
}
