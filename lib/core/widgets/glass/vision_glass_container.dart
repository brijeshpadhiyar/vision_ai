import 'dart:ui';

import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/theme/vision_glass.dart';
import 'package:vision_ai/core/theme/vision_radii.dart';

/// Base Liquid Glass surface supporting selective [BackdropFilter] blur,
/// surface/border opacity, gradient overlays, glow, and light/dark adaptation.
class VisionGlassContainer extends StatelessWidget {
  const VisionGlassContainer({
    required this.child,
    super.key,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.blurSigma = VisionGlass.blurNone,
    this.variant = VisionGlassVariant.standard,
    this.surfaceOpacity,
    this.borderOpacity,
    this.borderRadius,
    this.borderColor,
    this.gradientOverlay,
    this.glowColor,
    this.glowIntensity = 0.0,
    this.showShadow = false,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;

  /// Gaussian blur sigma. Defaults to `0.0` so scrolling cards avoid unnecessary
  /// GPU passes; set `VisionGlass.blurSoft` / `blurStandard` for chrome & modals.
  final double blurSigma;
  final VisionGlassVariant variant;
  final double? surfaceOpacity;
  final double? borderOpacity;
  final BorderRadius? borderRadius;
  final Color? borderColor;
  final Gradient? gradientOverlay;
  final Color? glowColor;
  final double glowIntensity;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final resolvedRadius = borderRadius ?? VisionRadii.lgBorder;
    final decoration = VisionGlass.decoration(
      brightness,
      variant: variant,
      surfaceOpacity: surfaceOpacity,
      borderOpacity: borderOpacity,
      borderRadius: resolvedRadius,
      borderColor: borderColor,
      gradientOverlay: gradientOverlay,
      glowColor: glowColor,
      glowIntensity: glowIntensity,
      showShadow: showShadow,
    );

    Widget content = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: decoration,
      child: child,
    );

    if (blurSigma > 0.1) {
      content = ClipRRect(
        borderRadius: resolvedRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: content,
        ),
      );
    } else {
      content = ClipRRect(borderRadius: resolvedRadius, child: content);
    }

    if (margin != null) {
      content = Padding(padding: margin!, child: content);
    }

    return content;
  }
}
