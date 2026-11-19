import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/theme/vision_colors.dart';

/// Material 3 [ThemeExtension] carrying all semantic Midnight Violet & Pearl
/// Lavender design tokens across the entire widget tree.
@immutable
class VisionThemeExtension extends ThemeExtension<VisionThemeExtension> {
  const VisionThemeExtension({
    required this.background,
    required this.secondaryBackground,
    required this.surface,
    required this.elevatedSurface,
    required this.primary,
    required this.primaryContainer,
    required this.secondary,
    required this.tertiary,
    required this.textPrimary,
    required this.textSecondary,
    required this.outline,
    required this.border,
    required this.divider,
    required this.success,
    required this.warning,
    required this.error,
    required this.disabled,
    required this.overlay,
    required this.shadow,
    required this.brandGradient,
    required this.surfaceGradient,
  });

  factory VisionThemeExtension.fromTokens(VisionColorTokens tokens) {
    return VisionThemeExtension(
      background: tokens.background,
      secondaryBackground: tokens.secondaryBackground,
      surface: tokens.surface,
      elevatedSurface: tokens.elevatedSurface,
      primary: tokens.primary,
      primaryContainer: tokens.primaryContainer,
      secondary: tokens.secondary,
      tertiary: tokens.tertiary,
      textPrimary: tokens.textPrimary,
      textSecondary: tokens.textSecondary,
      outline: tokens.outline,
      border: tokens.border,
      divider: tokens.divider,
      success: tokens.success,
      warning: tokens.warning,
      error: tokens.error,
      disabled: tokens.disabled,
      overlay: tokens.overlay,
      shadow: tokens.shadow,
      brandGradient: tokens.brandGradient,
      surfaceGradient: tokens.surfaceGradient,
    );
  }

  static final VisionThemeExtension dark = VisionThemeExtension.fromTokens(
    VisionColorTokens.dark,
  );

  static final VisionThemeExtension light = VisionThemeExtension.fromTokens(
    VisionColorTokens.light,
  );

  final Color background;
  final Color secondaryBackground;
  final Color surface;
  final Color elevatedSurface;
  final Color primary;
  final Color primaryContainer;
  final Color secondary;
  final Color tertiary;
  final Color textPrimary;
  final Color textSecondary;
  final Color outline;
  final Color border;
  final Color divider;
  final Color success;
  final Color warning;
  final Color error;
  final Color disabled;
  final Color overlay;
  final Color shadow;
  final LinearGradient brandGradient;
  final LinearGradient surfaceGradient;

  @override
  VisionThemeExtension copyWith({
    Color? background,
    Color? secondaryBackground,
    Color? surface,
    Color? elevatedSurface,
    Color? primary,
    Color? primaryContainer,
    Color? secondary,
    Color? tertiary,
    Color? textPrimary,
    Color? textSecondary,
    Color? outline,
    Color? border,
    Color? divider,
    Color? success,
    Color? warning,
    Color? error,
    Color? disabled,
    Color? overlay,
    Color? shadow,
    LinearGradient? brandGradient,
    LinearGradient? surfaceGradient,
  }) {
    return VisionThemeExtension(
      background: background ?? this.background,
      secondaryBackground: secondaryBackground ?? this.secondaryBackground,
      surface: surface ?? this.surface,
      elevatedSurface: elevatedSurface ?? this.elevatedSurface,
      primary: primary ?? this.primary,
      primaryContainer: primaryContainer ?? this.primaryContainer,
      secondary: secondary ?? this.secondary,
      tertiary: tertiary ?? this.tertiary,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      outline: outline ?? this.outline,
      border: border ?? this.border,
      divider: divider ?? this.divider,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      disabled: disabled ?? this.disabled,
      overlay: overlay ?? this.overlay,
      shadow: shadow ?? this.shadow,
      brandGradient: brandGradient ?? this.brandGradient,
      surfaceGradient: surfaceGradient ?? this.surfaceGradient,
    );
  }

  @override
  VisionThemeExtension lerp(
    covariant ThemeExtension<VisionThemeExtension>? other,
    double t,
  ) {
    if (other is! VisionThemeExtension) return this;
    return VisionThemeExtension(
      background: Color.lerp(background, other.background, t)!,
      secondaryBackground: Color.lerp(
        secondaryBackground,
        other.secondaryBackground,
        t,
      )!,
      surface: Color.lerp(surface, other.surface, t)!,
      elevatedSurface: Color.lerp(elevatedSurface, other.elevatedSurface, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryContainer: Color.lerp(
        primaryContainer,
        other.primaryContainer,
        t,
      )!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      tertiary: Color.lerp(tertiary, other.tertiary, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      border: Color.lerp(border, other.border, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      disabled: Color.lerp(disabled, other.disabled, t)!,
      overlay: Color.lerp(overlay, other.overlay, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      brandGradient: LinearGradient.lerp(
        brandGradient,
        other.brandGradient,
        t,
      )!,
      surfaceGradient: LinearGradient.lerp(
        surfaceGradient,
        other.surfaceGradient,
        t,
      )!,
    );
  }
}

/// Ergonomic theme token accessor for feature and core widgets.
extension VisionThemeContext on BuildContext {
  VisionThemeExtension get visionColors {
    final ext = Theme.of(this).extension<VisionThemeExtension>();
    if (ext != null) return ext;
    return Theme.of(this).brightness == Brightness.dark
        ? VisionThemeExtension.dark
        : VisionThemeExtension.light;
  }
}
