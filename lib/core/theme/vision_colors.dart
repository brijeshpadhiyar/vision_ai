import 'package:material_ui/material_ui.dart';

/// Centralized Liquid Glass color palette for VISION AI (dark & light modes).
abstract final class VisionColors {
  // ── Core Brand & Dark Atmospheric Backgrounds ──────────────────────────
  static const Color backgroundPrimary = Color(0xFF050812);
  static const Color backgroundSecondary = Color(0xFF0A1220);
  static const Color backgroundElevated = Color(0xFF0F192D);

  // ── Light Theme Atmospheric Backgrounds ────────────────────────────────
  static const Color lightBackgroundPrimary = Color(0xFFF3F7FC);
  static const Color lightBackgroundSecondary = Color(0xFFE6EEF9);
  static const Color lightBackgroundElevated = Color(0xFFFFFFFF);

  // ── Glass Surface & Border Base Colors ─────────────────────────────────
  static const Color glassTintDark = Color(0xFFFFFFFF);
  static const Color glassTintLight = Color(0xFFFFFFFF);
  static const Color glassBorderDark = Color(0xFFFFFFFF);
  static const Color glassBorderLight = Color(0xFF0A1220);

  // ── Accents ────────────────────────────────────────────────────────────
  static const Color accentPrimary = Color(0xFF00D4FF);
  static const Color accentPrimaryLightMode = Color(0xFF0088C2);
  static const Color accentSecondary = Color(0xFF3985FF);
  static const Color accentDeep = Color(0xFF1A4DFF);
  static const Color accentIce = Color(0xFF8AF0FF);

  // ── Semantic Status ────────────────────────────────────────────────────
  static const Color success = Color(0xFF12C991);
  static const Color warning = Color(0xFFFFB547);
  static const Color error = Color(0xFFFF5A6A);

  // ── Typography Colors ──────────────────────────────────────────────────
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFFA7B2C5);
  static const Color textMutedDark = Color(0xFF6B7890);

  static const Color textPrimaryLight = Color(0xFF081020);
  static const Color textSecondaryLight = Color(0xFF43536B);
  static const Color textMutedLight = Color(0xFF6D7D94);

  // ── Adaptive Helpers ───────────────────────────────────────────────────
  static Color primaryBackground(Brightness brightness) =>
      brightness == Brightness.dark
      ? backgroundPrimary
      : lightBackgroundPrimary;

  static Color secondaryBackground(Brightness brightness) =>
      brightness == Brightness.dark
      ? backgroundSecondary
      : lightBackgroundSecondary;

  static Color elevatedSurface(Brightness brightness) =>
      brightness == Brightness.dark
      ? backgroundElevated
      : lightBackgroundElevated;

  static Color primaryText(Brightness brightness) =>
      brightness == Brightness.dark ? textPrimaryDark : textPrimaryLight;

  static Color secondaryText(Brightness brightness) =>
      brightness == Brightness.dark ? textSecondaryDark : textSecondaryLight;

  static Color mutedText(Brightness brightness) =>
      brightness == Brightness.dark ? textMutedDark : textMutedLight;

  static Color primaryAccent(Brightness brightness) =>
      brightness == Brightness.dark ? accentPrimary : accentPrimaryLightMode;

  static Color glassSurface(Brightness brightness, {double opacity = 0.08}) {
    final clamped = opacity.clamp(0.03, 0.92);
    if (brightness == Brightness.dark) {
      return glassTintDark.withValues(alpha: clamped);
    }
    // In light mode, increase frosted white fill slightly for crisp readability.
    return glassTintLight.withValues(
      alpha: (0.55 + clamped * 2.5).clamp(0.55, 0.92),
    );
  }

  static Color glassBorder(Brightness brightness, {double opacity = 0.16}) {
    final clamped = opacity.clamp(0.06, 0.6);
    if (brightness == Brightness.dark) {
      return glassBorderDark.withValues(alpha: clamped);
    }
    return glassBorderLight.withValues(
      alpha: (clamped * 0.65).clamp(0.08, 0.25),
    );
  }

  // ── Gradients ──────────────────────────────────────────────────────────
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentPrimary, accentSecondary],
  );

  static const LinearGradient darkBackdropGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [backgroundPrimary, backgroundSecondary, backgroundPrimary],
    stops: [0.0, 0.55, 1.0],
  );

  static const LinearGradient lightBackdropGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      lightBackgroundPrimary,
      lightBackgroundSecondary,
      lightBackgroundPrimary,
    ],
    stops: [0.0, 0.55, 1.0],
  );
}
