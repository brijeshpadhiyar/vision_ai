import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/theme/vision_colors.dart';

/// Backward-compatible color token aliases backed by [VisionColors].
abstract final class AppColors {
  static const Color brandBackgroundPrimary = VisionColors.backgroundPrimary;
  static const Color brandBackgroundSecondary =
      VisionColors.backgroundSecondary;
  static const Color brandAccentPrimary = VisionColors.accentPrimary;
  static const Color brandAccentSecondary = VisionColors.accentSecondary;
  static const Color brandTextPrimary = VisionColors.textPrimaryDark;
  static const Color brandTextSecondary = VisionColors.textSecondaryDark;

  static const Color darkBackground = VisionColors.backgroundPrimary;
  static const Color darkSurface = VisionColors.backgroundSecondary;
  static const Color darkSurfaceElevated = VisionColors.backgroundElevated;
  static const Color darkBorder = VisionColors.darkBorder;

  static const Color lightBackground = VisionColors.lightBackgroundPrimary;
  static const Color lightSurface = VisionColors.lightBackgroundElevated;
  static const Color lightSurfaceElevated =
      VisionColors.lightBackgroundSecondary;
  static const Color lightBorder = VisionColors.lightBorder;

  static const Color cyanAccent = VisionColors.accentPrimary;
  static const Color cyanPrimaryDark = VisionColors.accentPrimary;
  static const Color cyanPrimaryLight = VisionColors.accentPrimaryLightMode;
  static const Color electricBlue = VisionColors.accentSecondary;
  static const Color deepIndigo = VisionColors.accentDeep;

  static const Color darkTextPrimary = VisionColors.textPrimaryDark;
  static const Color darkTextSecondary = VisionColors.textSecondaryDark;
  static const Color darkTextMuted = VisionColors.textMutedDark;

  static const Color lightTextPrimary = VisionColors.textPrimaryLight;
  static const Color lightTextSecondary = VisionColors.textSecondaryLight;
  static const Color lightTextMuted = VisionColors.textMutedLight;

  static const Color success = VisionColors.success;
  static const Color warning = VisionColors.warning;
  static const Color error = VisionColors.error;
}
