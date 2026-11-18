import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/theme/vision_colors.dart';
import 'package:vision_ai/core/theme/vision_radii.dart';
import 'package:vision_ai/core/theme/vision_typography.dart';

/// Complete dark & light Material 3 [ThemeData] built on VISION Liquid Glass tokens.
abstract final class VisionTheme {
  static ThemeData get darkTheme => _buildTheme(Brightness.dark);

  static ThemeData get lightTheme => _buildTheme(Brightness.light);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final bgPrimary = VisionColors.primaryBackground(brightness);
    final bgSecondary = VisionColors.secondaryBackground(brightness);
    final elevated = VisionColors.elevatedSurface(brightness);
    final primaryAccent = VisionColors.primaryAccent(brightness);
    final primaryText = VisionColors.primaryText(brightness);
    final secondaryText = VisionColors.secondaryText(brightness);
    final outlineColor = VisionColors.glassBorder(brightness, opacity: 0.16);

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: primaryAccent,
      onPrimary: isDark ? VisionColors.backgroundPrimary : Colors.white,
      primaryContainer: isDark ? bgSecondary : const Color(0xFFDCEBFF),
      onPrimaryContainer: primaryAccent,
      secondary: VisionColors.accentSecondary,
      onSecondary: Colors.white,
      secondaryContainer: isDark ? elevated : const Color(0xFFE7EFFA),
      onSecondaryContainer: primaryText,
      surface: bgSecondary,
      onSurface: primaryText,
      onSurfaceVariant: secondaryText,
      surfaceContainerHighest: isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.white.withValues(alpha: 0.85),
      outline: outlineColor,
      outlineVariant: VisionColors.glassBorder(brightness, opacity: 0.10),
      error: VisionColors.error,
      onError: Colors.white,
    );

    final textTheme = VisionTypography.buildTextTheme(brightness);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: bgPrimary,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: primaryText,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        color: VisionColors.glassSurface(brightness, opacity: 0.07),
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: VisionRadii.lgBorder,
          side: BorderSide(color: outlineColor),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: VisionColors.glassBorder(brightness, opacity: 0.12),
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? elevated : VisionColors.textPrimaryLight,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: VisionRadii.mdBorder,
          side: BorderSide(
            color: VisionColors.glassBorder(Brightness.dark, opacity: 0.16),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? bgSecondary : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: VisionRadii.xlBorder,
          side: BorderSide(color: outlineColor),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(VisionRadii.xl),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: VisionColors.glassSurface(brightness, opacity: 0.06),
        hintStyle: textTheme.bodyMedium,
        labelStyle: textTheme.bodyMedium,
        border: OutlineInputBorder(
          borderRadius: VisionRadii.mdBorder,
          borderSide: BorderSide(color: outlineColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: VisionRadii.mdBorder,
          borderSide: BorderSide(color: outlineColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: VisionRadii.mdBorder,
          borderSide: BorderSide(color: primaryAccent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: VisionRadii.mdBorder,
          borderSide: const BorderSide(color: VisionColors.error),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryAccent,
          foregroundColor: isDark
              ? VisionColors.backgroundPrimary
              : Colors.white,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: VisionRadii.mdBorder),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryAccent,
          side: BorderSide(color: outlineColor),
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: VisionRadii.mdBorder),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryAccent,
          minimumSize: const Size(44, 44),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return isDark ? VisionColors.backgroundPrimary : Colors.white;
          }
          return secondaryText;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryAccent;
          }
          return VisionColors.glassSurface(brightness, opacity: 0.12);
        }),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: primaryAccent,
        inactiveTrackColor: VisionColors.glassBorder(brightness, opacity: 0.16),
        thumbColor: primaryAccent,
        overlayColor: primaryAccent.withValues(alpha: 0.16),
      ),
    );
  }
}
