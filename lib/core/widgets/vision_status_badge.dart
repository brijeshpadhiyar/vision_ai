import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/theme/vision_colors.dart';
import 'package:vision_ai/core/theme/vision_glass.dart';
import 'package:vision_ai/core/theme/vision_radii.dart';

/// Compact Liquid Glass status pill displaying an indicator dot/icon and label.
class VisionStatusBadge extends StatelessWidget {
  const VisionStatusBadge({
    required this.label,
    super.key,
    this.indicatorColor,
    this.icon,
    this.compact = false,
  });

  final String label;
  final Color? indicatorColor;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final dotColor = indicatorColor ?? VisionColors.primaryAccent(brightness);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: dotColor.withValues(
          alpha: brightness == Brightness.dark ? 0.12 : 0.10,
        ),
        borderRadius: VisionRadii.pillBorder,
        border: Border.all(
          color: dotColor.withValues(
            alpha: brightness == Brightness.dark ? 0.38 : 0.28,
          ),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            VisionColors.glassSurface(brightness, opacity: 0.08),
            dotColor.withValues(
              alpha: brightness == Brightness.dark ? 0.10 : 0.07,
            ),
          ],
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, size: compact ? 13 : 14, color: dotColor)
          else
            Container(
              width: compact ? 7 : 8,
              height: compact ? 7 : 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: dotColor.withValues(alpha: 0.65),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          SizedBox(width: compact ? 6 : 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                fontSize: compact ? 11 : 12,
                color: VisionColors.primaryText(brightness),
                letterSpacing: 0.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small non-interactive tag chip used inside cards for metadata.
class VisionGlassMetaPill extends StatelessWidget {
  const VisionGlassMetaPill({
    required this.icon,
    required this.label,
    super.key,
    this.color,
  });

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final effectiveColor = color ?? VisionColors.primaryAccent(brightness);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: VisionGlass.decoration(
        brightness,
        variant: VisionGlassVariant.subtle,
        borderRadius: VisionRadii.pillBorder,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: effectiveColor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: VisionColors.primaryText(brightness),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
