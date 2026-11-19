import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/theme/vision_colors.dart';

/// Vector-accurate Futuristic Prism V + Glowing AI Spark / Neural Iris brand
/// mark rendered synchronously in both Midnight Violet (dark) and Pearl
/// Lavender (light) themes.
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

  /// Paints the canonical VISION Prism V + AI Spark mark onto [canvas] inside
  /// [size], shared by both the in-app widget and high-res icon exports.
  static void paintMark(
    Canvas canvas,
    Size size, {
    bool isDarkBackground = true,
    bool showAmbientGlow = true,
    double contentScale = 1.0,
  }) {
    final dim = math.min(size.width, size.height);
    final baseScale = (dim / 512.0) * contentScale;
    final offsetX = (size.width - 512.0 * baseScale) / 2.0;
    final offsetY = (size.height - 512.0 * baseScale) / 2.0;

    canvas.save();
    canvas.translate(offsetX, offsetY);
    canvas.scale(baseScale, baseScale);

    final primaryViolet = isDarkBackground
        ? VisionColors.darkPrimary
        : VisionColors.lightPrimary;
    final midRose = isDarkBackground
        ? VisionColors.darkTertiary
        : VisionColors.lightTertiary;
    final secondaryMint = isDarkBackground
        ? VisionColors.darkSecondary
        : VisionColors.lightSecondary;
    final deepAccent = isDarkBackground
        ? const Color(0xFF4C3582)
        : const Color(0xFF4B2FA0);
    final coreDark = isDarkBackground
        ? VisionColors.darkBackground
        : VisionColors.lightTextPrimary;
    final highlightWhite = isDarkBackground
        ? VisionColors.darkTextPrimary
        : Colors.white;

    // 1. Subtle atmospheric aura (hardware-accelerated radial gradient, no blur)
    if (showAmbientGlow) {
      final auraPaint = Paint()
        ..shader =
            RadialGradient(
              colors: <Color>[
                primaryViolet.withValues(alpha: isDarkBackground ? 0.28 : 0.18),
                midRose.withValues(alpha: isDarkBackground ? 0.12 : 0.08),
                secondaryMint.withValues(alpha: 0.0),
              ],
              stops: const <double>[0.0, 0.52, 1.0],
            ).createShader(
              Rect.fromCircle(center: const Offset(256, 236), radius: 220),
            );
      canvas.drawCircle(const Offset(256, 236), 220, auraPaint);
    }

    // 2. Left Prism Wing of the V (Primary Violet -> Deep Indigo facet)
    final leftOuterWing = Path()
      ..moveTo(86, 114)
      ..lineTo(156, 114)
      ..lineTo(256, 358)
      ..lineTo(256, 434)
      ..cubicTo(240, 434, 226, 424, 218, 406)
      ..close();

    final leftWingPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[primaryViolet, deepAccent],
        stops: const <double>[0.0, 1.0],
      ).createShader(const Rect.fromLTWH(86, 114, 170, 320));
    canvas.drawPath(leftOuterWing, leftWingPaint);

    // Crisp specular edge highlight along left outer bevel
    final leftSpecularBevel = Path()
      ..moveTo(86, 114)
      ..lineTo(114, 114)
      ..lineTo(244, 418)
      ..lineTo(226, 422)
      ..close();
    canvas.drawPath(
      leftSpecularBevel,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            highlightWhite.withValues(alpha: isDarkBackground ? 0.55 : 0.45),
            primaryViolet.withValues(alpha: 0.0),
          ],
        ).createShader(const Rect.fromLTWH(86, 114, 158, 308)),
    );

    // 3. Right Prism Wing of the V (Rose -> Luminous Mint gradient, overlapping apex)
    final rightOuterWing = Path()
      ..moveTo(356, 114)
      ..lineTo(426, 114)
      ..lineTo(294, 406)
      ..cubicTo(286, 424, 272, 434, 256, 434)
      ..lineTo(256, 358)
      ..close();

    final rightWingPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: <Color>[secondaryMint, midRose, primaryViolet],
        stops: const <double>[0.0, 0.54, 1.0],
      ).createShader(const Rect.fromLTWH(256, 114, 170, 320));
    canvas.drawPath(rightOuterWing, rightWingPaint);

    // Inner prism ridge accent along right wing
    final rightInnerFacet = Path()
      ..moveTo(356, 114)
      ..lineTo(382, 114)
      ..lineTo(266, 382)
      ..lineTo(256, 358)
      ..close();
    canvas.drawPath(
      rightInnerFacet,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: <Color>[
            highlightWhite.withValues(alpha: isDarkBackground ? 0.48 : 0.38),
            secondaryMint.withValues(alpha: 0.0),
          ],
        ).createShader(const Rect.fromLTWH(256, 114, 126, 268)),
    );

    // 4. Precision Prism Apex Diamond Cut
    final apexFacet = Path()
      ..moveTo(256, 358)
      ..lineTo(276, 396)
      ..lineTo(256, 434)
      ..lineTo(236, 396)
      ..close();
    canvas.drawPath(
      apexFacet,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            highlightWhite.withValues(alpha: 0.34),
            primaryViolet.withValues(alpha: 0.72),
          ],
        ).createShader(const Rect.fromLTWH(236, 358, 40, 76)),
    );

    // 5. Suspended Neural Iris / Orbital Ring in the upper V aperture
    const sparkCenter = Offset(256, 184);

    // Outer subtle telemetry orbit ring
    canvas.drawCircle(
      sparkCenter,
      54,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            primaryViolet.withValues(alpha: 0.75),
            midRose.withValues(alpha: 0.45),
            secondaryMint.withValues(alpha: 0.85),
          ],
        ).createShader(Rect.fromCircle(center: sparkCenter, radius: 54)),
    );

    // Soft glowing backdrop halo behind the 4-point AI spark
    canvas.drawCircle(
      sparkCenter,
      46,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            secondaryMint.withValues(alpha: isDarkBackground ? 0.38 : 0.25),
            primaryViolet.withValues(alpha: isDarkBackground ? 0.22 : 0.14),
            Colors.transparent,
          ],
          stops: const <double>[0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: sparkCenter, radius: 46)),
    );

    // 6. Luminous 4-Point AI Spark Star (curved astroid geometry)
    final sparkPath = Path()
      ..moveTo(sparkCenter.dx, sparkCenter.dy - 40)
      ..quadraticBezierTo(
        sparkCenter.dx + 6,
        sparkCenter.dy - 6,
        sparkCenter.dx + 40,
        sparkCenter.dy,
      )
      ..quadraticBezierTo(
        sparkCenter.dx + 6,
        sparkCenter.dy + 6,
        sparkCenter.dx,
        sparkCenter.dy + 40,
      )
      ..quadraticBezierTo(
        sparkCenter.dx - 6,
        sparkCenter.dy + 6,
        sparkCenter.dx - 40,
        sparkCenter.dy,
      )
      ..quadraticBezierTo(
        sparkCenter.dx - 6,
        sparkCenter.dy - 6,
        sparkCenter.dx,
        sparkCenter.dy - 40,
      )
      ..close();

    canvas.drawPath(
      sparkPath,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[highlightWhite, secondaryMint, primaryViolet],
          stops: const <double>[0.0, 0.42, 1.0],
        ).createShader(Rect.fromCircle(center: sparkCenter, radius: 40)),
    );

    // Inner neural iris core dot
    canvas.drawCircle(
      sparkCenter,
      8.5,
      Paint()..color = coreDark.withValues(alpha: 0.88),
    );
    canvas.drawCircle(
      Offset(sparkCenter.dx + 2.5, sparkCenter.dy - 2.5),
      2.6,
      Paint()..color = highlightWhite,
    );

    canvas.restore();
  }

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
    VisionBrandLogo.paintMark(
      canvas,
      size,
      isDarkBackground: isDarkBackground,
      showAmbientGlow: showAmbientGlow,
    );
  }

  @override
  bool shouldRepaint(covariant _VisionBrandLogoPainter oldDelegate) {
    return oldDelegate.isDarkBackground != isDarkBackground ||
        oldDelegate.showAmbientGlow != showAmbientGlow;
  }
}
