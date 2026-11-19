import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/theme/vision_colors.dart';

/// Centralized Material 3 typography scale powered by offline-bundled Manrope
/// via [GoogleFonts] (`allowRuntimeFetching = false`).
abstract final class VisionTypography {
  /// Primary bundled font family registered in `pubspec.yaml` and `assets/fonts/`.
  static const String fontFamily = 'Manrope';

  static TextStyle _manrope({
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
    double? letterSpacing,
    double? height,
  }) {
    return GoogleFonts.manrope(
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: height,
      color: color,
    ).copyWith(fontFamilyFallback: const <String>[fontFamily]);
  }

  /// Builds a complete 15-style Material 3 [TextTheme] tuned for both
  /// Midnight Violet (dark) and Pearl Lavender (light) themes.
  static TextTheme buildTextTheme(Brightness brightness) {
    GoogleFonts.config.allowRuntimeFetching = false;
    final primary = VisionColors.primaryText(brightness);
    final secondary = VisionColors.secondaryText(brightness);

    return TextTheme(
      displayLarge: _manrope(
        fontSize: 44,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.1,
        height: 1.12,
        color: primary,
      ),
      displayMedium: _manrope(
        fontSize: 38,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.9,
        height: 1.15,
        color: primary,
      ),
      displaySmall: _manrope(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.7,
        height: 1.18,
        color: primary,
      ),
      headlineLarge: _manrope(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.55,
        height: 1.22,
        color: primary,
      ),
      headlineMedium: _manrope(
        fontSize: 25,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.45,
        height: 1.24,
        color: primary,
      ),
      headlineSmall: _manrope(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.25,
        height: 1.28,
        color: primary,
      ),
      titleLarge: _manrope(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.0,
        height: 1.32,
        color: primary,
      ),
      titleMedium: _manrope(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.05,
        height: 1.38,
        color: primary,
      ),
      titleSmall: _manrope(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        height: 1.38,
        color: primary,
      ),
      bodyLarge: _manrope(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: primary,
      ),
      bodyMedium: _manrope(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.46,
        color: secondary,
      ),
      bodySmall: _manrope(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.42,
        color: secondary,
      ),
      labelLarge: _manrope(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.35,
        color: primary,
      ),
      labelMedium: _manrope(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.45,
        color: secondary,
      ),
      labelSmall: _manrope(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.35,
        color: secondary,
      ),
    );
  }
}
