import 'package:material_ui/material_ui.dart';

/// Semantic color tokens for VISION AI's dark and light themes.
abstract final class AppColors {
  // ── Official VISION Brand Palette ─────────────────────────────────────
  static const Color brandBackgroundPrimary = Color(0xFF080D18);
  static const Color brandBackgroundSecondary = Color(0xFF101A2B);
  static const Color brandAccentPrimary = Color(0xFF00D4FF);
  static const Color brandAccentSecondary = Color(0xFF397BFF);
  static const Color brandTextPrimary = Color(0xFFFFFFFF);
  static const Color brandTextSecondary = Color(0xFFAAB8CC);

  // ── Dark Theme Surfaces (Primary Experience) ──────────────────────────
  static const Color darkBackground = Color(0xFF05080F);
  static const Color darkSurface = Color(0xFF0B111E);
  static const Color darkSurfaceElevated = Color(0xFF111A2E);
  static const Color darkBorder = Color(0xFF1E2D45);

  // ── Light Theme Surfaces ──────────────────────────────────────────────
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceElevated = Color(0xFFF1F5F9);
  static const Color lightBorder = Color(0xFFE2E8F0);

  // ── Signature Cyan & Electric Blue Accents ────────────────────────────
  static const Color cyanAccent = Color(0xFF00E5FF);
  static const Color cyanPrimaryDark = Color(0xFF06B6D4);
  static const Color cyanPrimaryLight = Color(0xFF0284C7);
  static const Color electricBlue = Color(0xFF3B82F6);
  static const Color deepIndigo = Color(0xFF1D4ED8);

  // ── Typography Colors ─────────────────────────────────────────────────
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextMuted = Color(0xFF64748B);

  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightTextMuted = Color(0xFF64748B);

  // ── Semantic Status Colors ────────────────────────────────────────────
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
}
