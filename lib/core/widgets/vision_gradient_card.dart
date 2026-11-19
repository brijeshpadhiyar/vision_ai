import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/theme/vision_elevation.dart';
import 'package:vision_ai/core/theme/vision_motion.dart';
import 'package:vision_ai/core/theme/vision_radius.dart';
import 'package:vision_ai/core/theme/vision_spacing.dart';
import 'package:vision_ai/core/theme/vision_theme_extension.dart';

/// Soft gradient accent card for hero highlights, active provider banners,
/// and premium feature callouts.
class VisionGradientCard extends StatelessWidget {
  const VisionGradientCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(VisionSpacing.md),
    this.borderRadius = VisionRadius.lgBorder,
    this.gradient,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final Gradient? gradient;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.visionColors;
    final brightness = Theme.of(context).brightness;
    final effectiveGradient =
        gradient ??
        LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            colors.primaryContainer.withValues(
              alpha: brightness == Brightness.dark ? 0.85 : 0.72,
            ),
            colors.elevatedSurface,
          ],
        );

    final content = AnimatedContainer(
      duration: VisionMotion.resolve(context, VisionMotion.standard),
      curve: VisionMotion.standardCurve,
      padding: padding,
      decoration: BoxDecoration(
        gradient: effectiveGradient,
        borderRadius: borderRadius,
        border: Border.all(color: colors.primary.withValues(alpha: 0.34)),
        boxShadow: VisionElevation.subtle(brightness),
      ),
      child: child,
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      borderRadius: borderRadius,
      child: InkWell(onTap: onTap, borderRadius: borderRadius, child: content),
    );
  }
}
