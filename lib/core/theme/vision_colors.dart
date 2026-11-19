import 'package:material_ui/material_ui.dart';

/// Semantic color token set for VISION AI (Midnight Violet Dark & Pearl Lavender Light).
@immutable
class VisionColorTokens {
  const VisionColorTokens({
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

  /// MIDNIGHT VIOLET — Dark Theme Tokens.
  static const VisionColorTokens dark = VisionColorTokens(
    background: VisionColors.darkBackground,
    secondaryBackground: VisionColors.darkSecondaryBackground,
    surface: VisionColors.darkSurface,
    elevatedSurface: VisionColors.darkElevatedSurface,
    primary: VisionColors.darkPrimary,
    primaryContainer: VisionColors.darkPrimaryContainer,
    secondary: VisionColors.darkSecondary,
    tertiary: VisionColors.darkTertiary,
    textPrimary: VisionColors.darkTextPrimary,
    textSecondary: VisionColors.darkTextSecondary,
    outline: VisionColors.darkBorder,
    border: VisionColors.darkBorder,
    divider: Color(0xFF282534),
    success: VisionColors.darkSuccess,
    warning: VisionColors.darkWarning,
    error: VisionColors.darkError,
    disabled: Color(0xFF5D586B),
    overlay: Color(0xB8101016),
    shadow: Color(0x6606050A),
    brandGradient: VisionColors.darkBrandGradient,
    surfaceGradient: VisionColors.darkSurfaceGradient,
  );

  /// PEARL LAVENDER — Light Theme Tokens.
  static const VisionColorTokens light = VisionColorTokens(
    background: VisionColors.lightBackground,
    secondaryBackground: VisionColors.lightSecondaryBackground,
    surface: VisionColors.lightSurface,
    elevatedSurface: VisionColors.lightElevatedSurface,
    primary: VisionColors.lightPrimary,
    primaryContainer: VisionColors.lightPrimaryContainer,
    secondary: VisionColors.lightSecondary,
    tertiary: VisionColors.lightTertiary,
    textPrimary: VisionColors.lightTextPrimary,
    textSecondary: VisionColors.lightTextSecondary,
    outline: VisionColors.lightBorder,
    border: VisionColors.lightBorder,
    divider: Color(0xFFEBE6F1),
    success: VisionColors.lightSuccess,
    warning: VisionColors.lightWarning,
    error: VisionColors.lightError,
    disabled: Color(0xFFA9A2B5),
    overlay: Color(0x73211B2B),
    shadow: Color(0x16211B2B),
    brandGradient: VisionColors.lightBrandGradient,
    surfaceGradient: VisionColors.lightSurfaceGradient,
  );

  static VisionColorTokens ofBrightness(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;
}

/// Centralized Midnight Violet + Pearl Lavender color palette for VISION AI.
abstract final class VisionColors {
  // ── DARK THEME — MIDNIGHT VIOLET ───────────────────────────────────────
  static const Color darkBackground = Color(0xFF101016);
  static const Color darkSecondaryBackground = Color(0xFF15151E);
  static const Color darkSurface = Color(0xFF191823);
  static const Color darkElevatedSurface = Color(0xFF22212E);
  static const Color darkPrimary = Color(0xFFA78BFA);
  static const Color darkPrimaryContainer = Color(0xFF35284E);
  static const Color darkSecondary = Color(0xFF65E6C1);
  static const Color darkTertiary = Color(0xFFF0A6C8);
  static const Color darkTextPrimary = Color(0xFFF5F1FA);
  static const Color darkTextSecondary = Color(0xFFB6B0C2);
  static const Color darkBorder = Color(0xFF302D3C);
  static const Color darkSuccess = Color(0xFF65D6A5);
  static const Color darkWarning = Color(0xFFF4BD70);
  static const Color darkError = Color(0xFFFF858D);

  // ── LIGHT THEME — PEARL LAVENDER ───────────────────────────────────────
  static const Color lightBackground = Color(0xFFF7F5FA);
  static const Color lightSecondaryBackground = Color(0xFFF0EDF5);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightElevatedSurface = Color(0xFFFFFFFF);
  static const Color lightPrimary = Color(0xFF7554C7);
  static const Color lightPrimaryContainer = Color(0xFFE9DFFF);
  static const Color lightSecondary = Color(0xFF168D73);
  static const Color lightTertiary = Color(0xFFB65F89);
  static const Color lightTextPrimary = Color(0xFF211B2B);
  static const Color lightTextSecondary = Color(0xFF696273);
  static const Color lightBorder = Color(0xFFE5DFEB);
  static const Color lightSuccess = Color(0xFF187B59);
  static const Color lightWarning = Color(0xFFA5681D);
  static const Color lightError = Color(0xFFC23E51);

  // ── Semantic Aliases (Preserve Existing Call Sites Without Old Blue) ───
  static const Color backgroundPrimary = darkBackground;
  static const Color backgroundSecondary = darkSecondaryBackground;
  static const Color backgroundElevated = darkElevatedSurface;

  static const Color lightBackgroundPrimary = lightBackground;
  static const Color lightBackgroundSecondary = lightSecondaryBackground;
  static const Color lightBackgroundElevated = lightElevatedSurface;

  static const Color glassTintDark = Color(0xFFFFFFFF);
  static const Color glassTintLight = Color(0xFFFFFFFF);
  static const Color glassBorderDark = darkPrimary;
  static const Color glassBorderLight = lightPrimary;

  static const Color accentPrimary = darkPrimary;
  static const Color accentPrimaryLightMode = lightPrimary;
  static const Color accentSecondary = darkSecondary;
  static const Color accentTertiary = darkTertiary;
  static const Color accentDeep = lightPrimary;
  static const Color accentIce = Color(0xFFD8CBFF);

  static const Color success = darkSuccess;
  static const Color warning = darkWarning;
  static const Color error = darkError;

  static const Color textPrimaryDark = darkTextPrimary;
  static const Color textSecondaryDark = darkTextSecondary;
  static const Color textMutedDark = Color(0xFF8A8399);

  static const Color textPrimaryLight = lightTextPrimary;
  static const Color textSecondaryLight = lightTextSecondary;
  static const Color textMutedLight = Color(0xFF8C8499);

  // ── Adaptive Helpers ───────────────────────────────────────────────────
  static Color primaryBackground(Brightness brightness) =>
      brightness == Brightness.dark ? darkBackground : lightBackground;

  static Color secondaryBackground(Brightness brightness) =>
      brightness == Brightness.dark
      ? darkSecondaryBackground
      : lightSecondaryBackground;

  static Color surfaceColor(Brightness brightness) =>
      brightness == Brightness.dark ? darkSurface : lightSurface;

  static Color elevatedSurface(Brightness brightness) =>
      brightness == Brightness.dark
      ? darkElevatedSurface
      : lightElevatedSurface;

  static Color primaryText(Brightness brightness) =>
      brightness == Brightness.dark ? darkTextPrimary : lightTextPrimary;

  static Color secondaryText(Brightness brightness) =>
      brightness == Brightness.dark ? darkTextSecondary : lightTextSecondary;

  static Color mutedText(Brightness brightness) =>
      brightness == Brightness.dark ? textMutedDark : textMutedLight;

  static Color primaryAccent(Brightness brightness) =>
      brightness == Brightness.dark ? darkPrimary : lightPrimary;

  static Color secondaryAccent(Brightness brightness) =>
      brightness == Brightness.dark ? darkSecondary : lightSecondary;

  static Color tertiaryAccent(Brightness brightness) =>
      brightness == Brightness.dark ? darkTertiary : lightTertiary;

  static Color borderColor(Brightness brightness) =>
      brightness == Brightness.dark ? darkBorder : lightBorder;

  static Color semanticSuccess(Brightness brightness) =>
      brightness == Brightness.dark ? darkSuccess : lightSuccess;

  static Color semanticWarning(Brightness brightness) =>
      brightness == Brightness.dark ? darkWarning : lightWarning;

  static Color semanticError(Brightness brightness) =>
      brightness == Brightness.dark ? darkError : lightError;

  static Color glassSurface(Brightness brightness, {double opacity = 0.08}) {
    final clamped = opacity.clamp(0.03, 0.92);
    if (brightness == Brightness.dark) {
      return darkElevatedSurface.withValues(
        alpha: (0.58 + clamped * 2.4).clamp(0.58, 0.90),
      );
    }
    return lightSurface.withValues(
      alpha: (0.76 + clamped * 1.8).clamp(0.76, 0.96),
    );
  }

  static Color glassBorder(Brightness brightness, {double opacity = 0.16}) {
    final clamped = opacity.clamp(0.06, 0.7);
    if (brightness == Brightness.dark) {
      return darkBorder.withValues(alpha: (0.65 + clamped).clamp(0.65, 1.0));
    }
    return lightBorder.withValues(alpha: (0.80 + clamped).clamp(0.80, 1.0));
  }

  // ── Gradients ──────────────────────────────────────────────────────────
  static const LinearGradient darkBrandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[darkPrimary, darkTertiary, darkSecondary],
  );

  static const LinearGradient lightBrandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[lightPrimary, lightTertiary, lightSecondary],
  );

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[darkPrimary, darkSecondary],
  );

  static const LinearGradient darkSurfaceGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[darkElevatedSurface, darkSurface],
  );

  static const LinearGradient lightSurfaceGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[lightSurface, lightSecondaryBackground],
  );

  static const LinearGradient darkBackdropGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[darkBackground, darkSecondaryBackground, darkBackground],
    stops: <double>[0.0, 0.52, 1.0],
  );

  static const LinearGradient lightBackdropGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[lightBackground, lightSecondaryBackground, lightBackground],
    stops: <double>[0.0, 0.55, 1.0],
  );
}
