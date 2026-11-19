import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/theme/vision_radius.dart';
import 'package:vision_ai/core/theme/vision_spacing.dart';
import 'package:vision_ai/core/theme/vision_theme_extension.dart';

/// Selective translucent glass panel (avoid applying to every card; use for
/// floating bars, assistant overlays, and featured banners).
class VisionGlassPanel extends StatelessWidget {
  const VisionGlassPanel({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(VisionSpacing.md),
    this.borderRadius = VisionRadius.lgBorder,
    this.highlighted = false,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final bool highlighted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.visionColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final panel = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.elevatedSurface.withValues(alpha: isDark ? 0.84 : 0.90),
        borderRadius: borderRadius,
        border: Border.all(
          color: highlighted
              ? colors.primary.withValues(alpha: 0.52)
              : colors.border,
          width: highlighted ? 1.4 : 1.0,
        ),
      ),
      child: Padding(padding: padding, child: child),
    );

    if (onTap == null) return panel;

    return Material(
      color: Colors.transparent,
      borderRadius: borderRadius,
      child: InkWell(onTap: onTap, borderRadius: borderRadius, child: panel),
    );
  }
}
