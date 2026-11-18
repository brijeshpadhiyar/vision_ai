import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/theme/vision_animations.dart';
import 'package:vision_ai/core/theme/vision_glass.dart';
import 'package:vision_ai/core/theme/vision_radii.dart';
import 'package:vision_ai/core/theme/vision_spacing.dart';
import 'package:vision_ai/core/widgets/glass/vision_glass_container.dart';

/// Interactive Liquid Glass card with tactile press micro-animation.
class VisionGlassCard extends StatefulWidget {
  const VisionGlassCard({
    required this.child,
    super.key,
    this.padding = VisionSpacing.cardPadding,
    this.margin,
    this.onTap,
    this.onLongPress,
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
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
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
  State<VisionGlassCard> createState() => _VisionGlassCardState();
}

class _VisionGlassCardState extends State<VisionGlassCard> {
  bool _isPressed = false;

  void _setPressed(bool pressed) {
    if (_isPressed == pressed) return;
    setState(() => _isPressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    final isInteractive = widget.onTap != null || widget.onLongPress != null;
    final resolvedRadius = widget.borderRadius ?? VisionRadii.lgBorder;
    final reducedMotion = VisionAnimations.isReducedMotion(context);

    final inner = VisionGlassContainer(
      margin: widget.margin,
      blurSigma: widget.blurSigma,
      variant: widget.variant,
      surfaceOpacity: widget.surfaceOpacity,
      borderOpacity: widget.borderOpacity,
      borderRadius: resolvedRadius,
      borderColor: widget.borderColor,
      gradientOverlay: widget.gradientOverlay,
      glowColor: widget.glowColor,
      glowIntensity: widget.glowIntensity,
      showShadow: widget.showShadow,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          onHighlightChanged: isInteractive ? _setPressed : null,
          borderRadius: resolvedRadius,
          splashColor: Theme.of(context).colorScheme.primary
              .withValues(alpha: 0.10),
          highlightColor: Colors.white.withValues(alpha: 0.05),
          child: Padding(padding: widget.padding, child: widget.child),
        ),
      ),
    );

    if (!isInteractive || reducedMotion) {
      return inner;
    }

    return AnimatedScale(
      scale: _isPressed ? 0.982 : 1.0,
      duration: VisionAnimations.microFast,
      curve: VisionAnimations.standardCurve,
      child: inner,
    );
  }
}
