import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/app/theme/app_colors.dart';

/// Vector-accurate geometric VISION V-Iris brand mark rendered synchronously.
class VisionBrandLogo extends StatelessWidget {
  const VisionBrandLogo({
    super.key,
    this.size = 120,
    this.isDarkBackground = true,
    this.showAmbientGlow = true,
  });

  final double size;
  final bool isDarkBackground;
  final bool showAmbientGlow;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'VISION AI brand logo',
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _VisionBrandLogoPainter(
            isDarkBackground: isDarkBackground,
            showAmbientGlow: showAmbientGlow,
          ),
        ),
      ),
    );
  }
}

class _VisionBrandLogoPainter extends CustomPainter {
  const _VisionBrandLogoPainter({
    required this.isDarkBackground,
    required this.showAmbientGlow,
  });

  final bool isDarkBackground;
  final bool showAmbientGlow;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width, size.height) / 512.0;
    canvas.save();
    canvas.scale(scale, scale);

    final primaryCyan = isDarkBackground
        ? AppColors.brandAccentPrimary
        : const Color(0xFF0095D9);
    final midBlue = isDarkBackground
        ? const Color(0xFF1EA8FF)
        : const Color(0xFF1A75FF);
    final secondaryBlue = isDarkBackground
        ? AppColors.brandAccentSecondary
        : const Color(0xFF2958E8);

    if (showAmbientGlow) {
      final haloPaint = Paint()
        ..shader =
            RadialGradient(
              colors: [
                primaryCyan.withValues(alpha: 0.22),
                secondaryBlue.withValues(alpha: 0.06),
                secondaryBlue.withValues(alpha: 0.0),
              ],
              stops: const [0.0, 0.60, 1.0],
            ).createShader(
              Rect.fromCircle(center: const Offset(256, 240), radius: 206),
            );
      canvas.drawCircle(const Offset(256, 240), 206, haloPaint);
    }

    // Outer stylized geometric V frame.
    final vPath = Path()
      ..moveTo(88, 112)
      ..lineTo(154, 112)
      ..lineTo(256, 364)
      ..lineTo(358, 112)
      ..lineTo(424, 112)
      ..lineTo(284, 432)
      ..cubicTo(276, 448, 236, 448, 228, 432)
      ..close();

    final vPaint = Paint()
      ..shader = LinearGradient(
        begin: const Alignment(-0.7, -0.7),
        end: const Alignment(0.7, 0.7),
        colors: [primaryCyan, midBlue, secondaryBlue],
        stops: const [0.0, 0.52, 1.0],
      ).createShader(const Rect.fromLTWH(88, 112, 336, 336));
    canvas.drawPath(vPath, vPaint);

    // Subtle beveled facet along the left wing.
    final facetPath = Path()
      ..moveTo(88, 112)
      ..lineTo(116, 112)
      ..lineTo(244, 416)
      ..lineTo(228, 432)
      ..close();
    final facetPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF8AF0FF).withValues(alpha: 0.72),
          primaryCyan.withValues(alpha: 0.0),
        ],
      ).createShader(const Rect.fromLTWH(88, 112, 156, 320));
    canvas.drawPath(facetPath, facetPaint);

    // Dark optical cradle behind the AI eye for crisp contrast.
    final outerCradle = Path()
      ..moveTo(152, 202)
      ..cubicTo(194, 142, 318, 142, 360, 202)
      ..cubicTo(318, 262, 194, 262, 152, 202)
      ..close();
    canvas.drawPath(
      outerCradle,
      Paint()..color = AppColors.brandBackgroundPrimary,
    );

    // Precision eye aperture fill and rim.
    final eyeAperture = Path()
      ..moveTo(158, 202)
      ..cubicTo(197, 147, 315, 147, 354, 202)
      ..cubicTo(315, 257, 197, 257, 158, 202)
      ..close();
    canvas.drawPath(
      eyeAperture,
      Paint()..color = AppColors.brandBackgroundSecondary,
    );
    canvas.drawPath(
      eyeAperture,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7.5
        ..strokeJoin = StrokeJoin.round
        ..shader = LinearGradient(
          colors: [primaryCyan, const Color(0xFF8AF0FF), secondaryBlue],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(const Rect.fromLTWH(158, 150, 196, 104)),
    );

    // Outer AI telemetry ring nested cleanly inside the optical aperture.
    canvas.drawCircle(
      const Offset(256, 202),
      35,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.75
        ..color = primaryCyan.withValues(alpha: 0.55),
    );

    // Luminous AI iris.
    final irisPaint = Paint()
      ..shader =
          RadialGradient(
            center: const Alignment(0.0, -0.08),
            radius: 0.54,
            colors: [
              const Color(0xFFE6FCFF),
              primaryCyan,
              secondaryBlue,
              const Color(0xFF163E9E),
            ],
            stops: const [0.0, 0.30, 0.74, 1.0],
          ).createShader(
            Rect.fromCircle(center: const Offset(256, 202), radius: 26),
          );
    canvas.drawCircle(const Offset(256, 202), 26, irisPaint);

    // Deep obsidian pupil core.
    canvas.drawCircle(
      const Offset(256, 202),
      11.5,
      Paint()..color = AppColors.brandBackgroundPrimary,
    );

    // Specular awareness highlights.
    canvas.drawCircle(
      const Offset(262.5, 194.5),
      4.6,
      Paint()..color = AppColors.brandTextPrimary,
    );
    canvas.drawCircle(
      const Offset(247.5, 209.5),
      1.9,
      Paint()..color = const Color(0xFF8AF0FF).withValues(alpha: 0.85),
    );

    // Precision apex anchor.
    final apexPath = Path()
      ..moveTo(256, 374)
      ..lineTo(268, 396)
      ..lineTo(256, 418)
      ..lineTo(244, 396)
      ..close();
    canvas.drawPath(
      apexPath,
      Paint()..color = AppColors.brandBackgroundPrimary.withValues(alpha: 0.55),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _VisionBrandLogoPainter oldDelegate) {
    return oldDelegate.isDarkBackground != isDarkBackground ||
        oldDelegate.showAmbientGlow != showAmbientGlow;
  }
}
