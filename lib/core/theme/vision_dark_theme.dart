import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/theme/vision_colors.dart';
import 'package:vision_ai/core/theme/vision_radius.dart';
import 'package:vision_ai/core/theme/vision_theme_extension.dart';
import 'package:vision_ai/core/theme/vision_typography.dart';

/// Material 3 Dark Theme — MIDNIGHT VIOLET.
abstract final class VisionDarkTheme {
  static ThemeData build() {
    const tokens = VisionColorTokens.dark;
    final textTheme = VisionTypography.buildTextTheme(Brightness.dark);

    final colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: tokens.primary,
      onPrimary: tokens.background,
      primaryContainer: tokens.primaryContainer,
      onPrimaryContainer: tokens.textPrimary,
      secondary: tokens.secondary,
      onSecondary: tokens.background,
      secondaryContainer: tokens.secondary.withValues(alpha: 0.16),
      onSecondaryContainer: tokens.textPrimary,
      tertiary: tokens.tertiary,
      onTertiary: tokens.background,
      tertiaryContainer: tokens.tertiary.withValues(alpha: 0.18),
      onTertiaryContainer: tokens.textPrimary,
      surface: tokens.surface,
      onSurface: tokens.textPrimary,
      onSurfaceVariant: tokens.textSecondary,
      surfaceContainerHighest: tokens.elevatedSurface,
      outline: tokens.outline,
      outlineVariant: tokens.divider,
      error: tokens.error,
      onError: tokens.background,
      shadow: tokens.shadow,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: tokens.background,
      textTheme: textTheme,
      extensions: <ThemeExtension<dynamic>>[VisionThemeExtension.dark],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: tokens.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      cardTheme: CardThemeData(
        color: tokens.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: VisionRadius.lgBorder,
          side: BorderSide(color: tokens.border),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: tokens.divider,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: tokens.elevatedSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: tokens.textPrimary,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: VisionRadius.mdBorder,
          side: BorderSide(color: tokens.border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: tokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: VisionRadius.xlBorder,
          side: BorderSide(color: tokens.border),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: tokens.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(VisionRadius.xl),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.elevatedSurface,
        hintStyle: textTheme.bodyMedium,
        labelStyle: textTheme.bodyMedium,
        border: OutlineInputBorder(
          borderRadius: VisionRadius.mdBorder,
          borderSide: BorderSide(color: tokens.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: VisionRadius.mdBorder,
          borderSide: BorderSide(color: tokens.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: VisionRadius.mdBorder,
          borderSide: BorderSide(color: tokens.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: VisionRadius.mdBorder,
          borderSide: BorderSide(color: tokens.error),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: tokens.primary,
          foregroundColor: tokens.background,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
          shape: const RoundedRectangleBorder(
            borderRadius: VisionRadius.mdBorder,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: tokens.primary,
          side: BorderSide(color: tokens.border),
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: const RoundedRectangleBorder(
            borderRadius: VisionRadius.mdBorder,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: tokens.primary,
          minimumSize: const Size(44, 44),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return tokens.background;
          return tokens.textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return tokens.primary;
          }
          return tokens.elevatedSurface;
        }),
      ),
    );
  }
}
