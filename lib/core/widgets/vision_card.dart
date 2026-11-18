import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/theme/vision_glass.dart';
import 'package:vision_ai/core/theme/vision_spacing.dart';
import 'package:vision_ai/core/widgets/glass/vision_glass_card.dart';

/// Reusable Liquid Glass card for VISION AI panels, status blocks, and lists.
class VisionCard extends StatelessWidget {
  const VisionCard({
    required this.child,
    super.key,
    this.padding = VisionSpacing.cardPadding,
    this.onTap,
    this.borderColor,
    this.variant = VisionGlassVariant.standard,
    this.blurSigma = VisionGlass.blurNone,
    this.glowColor,
    this.glowIntensity = 0.0,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? borderColor;
  final VisionGlassVariant variant;
  final double blurSigma;
  final Color? glowColor;
  final double glowIntensity;

  @override
  Widget build(BuildContext context) {
    return VisionGlassCard(
      padding: padding,
      onTap: onTap,
      borderColor: borderColor,
      variant: variant,
      blurSigma: blurSigma,
      glowColor: glowColor,
      glowIntensity: glowIntensity,
      child: child,
    );
  }
}
