import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/theme/vision_colors.dart';
import 'package:vision_ai/core/theme/vision_radii.dart';
import 'package:vision_ai/core/theme/vision_shadows.dart';

/// Preset glass visual intensities for selective BackdropFilter and layered surfaces.
enum VisionGlassVariant {
  /// Subtle card glass (5–8% white tint in dark mode), zero blur by default for list performance.
  subtle,

  /// Standard panel glass (~8–10% white tint, specular top rim).
  standard,

  /// Elevated chrome glass (navigation bar, app bar, dialogs, sheets) with blur enabled.
  elevated,

  /// Accent-tinted glass for primary active cards or prompts.
  accent,
}

/// Tokenized decoration builder for Liquid Glass containers.
abstract final class VisionGlass {
  static const double blurNone = 0.0;
  static const double blurSoft = 12.0;
  static const double blurStandard = 18.0;
  static const double blurStrong = 26.0;

  static BoxDecoration decoration(
    Brightness brightness, {
    VisionGlassVariant variant = VisionGlassVariant.standard,
    double? surfaceOpacity,
    double? borderOpacity,
    BorderRadius? borderRadius,
    Color? borderColor,
    Color? glowColor,
    double glowIntensity = 0.0,
    Gradient? gradientOverlay,
    bool showShadow = false,
  }) {
    final isDark = brightness == Brightness.dark;
    final resolvedRadius = borderRadius ?? VisionRadii.lgBorder;

    final defaultSurfaceOpacity = switch (variant) {
      VisionGlassVariant.subtle => 0.05,
      VisionGlassVariant.standard => 0.08,
      VisionGlassVariant.elevated => 0.11,
      VisionGlassVariant.accent => 0.10,
    };
    final defaultBorderOpacity = switch (variant) {
      VisionGlassVariant.subtle => 0.12,
      VisionGlassVariant.standard => 0.16,
      VisionGlassVariant.elevated => 0.20,
      VisionGlassVariant.accent => 0.28,
    };

    final effectiveSurfaceOpacity = surfaceOpacity ?? defaultSurfaceOpacity;
    final effectiveBorderOpacity = borderOpacity ?? defaultBorderOpacity;

    final resolvedBorderColor =
        borderColor ??
        (variant == VisionGlassVariant.accent
            ? VisionColors.primaryAccent(brightness)
                  .withValues(alpha: isDark ? 0.36 : 0.28)
            : VisionColors.glassBorder(
                brightness,
                opacity: effectiveBorderOpacity,
              ));

    final Gradient effectiveGradient =
        gradientOverlay ??
        LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: variant == VisionGlassVariant.accent
              ? [
                  VisionColors.accentPrimary.withValues(
                    alpha: isDark ? 0.14 : 0.12,
                  ),
                  VisionColors.accentSecondary.withValues(
                    alpha: isDark ? 0.07 : 0.06,
                  ),
                  VisionColors.glassSurface(
                    brightness,
                    opacity: effectiveSurfaceOpacity,
                  ),
                ]
              : [
                  VisionColors.glassSurface(
                    brightness,
                    opacity: (effectiveSurfaceOpacity + 0.03).clamp(0.0, 0.95),
                  ),
                  VisionColors.glassSurface(
                    brightness,
                    opacity: (effectiveSurfaceOpacity - 0.02).clamp(0.02, 0.92),
                  ),
                ],
        );

    return BoxDecoration(
      borderRadius: resolvedRadius,
      gradient: effectiveGradient,
      border: Border.all(color: resolvedBorderColor, width: 1.0),
      boxShadow: showShadow || glowIntensity > 0
          ? VisionShadows.glassElevation(
              brightness,
              glowColor: glowColor,
              glowIntensity: glowIntensity,
            )
          : null,
    );
  }
}
