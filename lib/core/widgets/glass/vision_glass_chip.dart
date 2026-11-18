import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/theme/vision_animations.dart';
import 'package:vision_ai/core/theme/vision_colors.dart';
import 'package:vision_ai/core/theme/vision_glass.dart';
import 'package:vision_ai/core/theme/vision_radii.dart';

/// Selectable or actionable Liquid Glass pill chip.
class VisionGlassChip extends StatelessWidget {
  const VisionGlassChip({
    required this.label,
    super.key,
    this.icon,
    this.onTap,
    this.selected = false,
    this.accentColor,
    this.compact = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool selected;
  final Color? accentColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final effectiveAccent =
        accentColor ?? VisionColors.primaryAccent(brightness);

    return Semantics(
      button: onTap != null,
      selected: selected,
      label: label,
      child: AnimatedContainer(
        duration: VisionAnimations.resolveDuration(
          context,
          VisionAnimations.micro,
        ),
        curve: VisionAnimations.standardCurve,
        decoration: VisionGlass.decoration(
          brightness,
          variant: selected
              ? VisionGlassVariant.accent
              : VisionGlassVariant.subtle,
          borderRadius: VisionRadii.pillBorder,
          borderColor: selected
              ? effectiveAccent.withValues(alpha: 0.65)
              : null,
          glowColor: selected ? effectiveAccent : null,
          glowIntensity: selected ? 0.45 : 0.0,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: VisionRadii.pillBorder,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 11 : 14,
                vertical: compact ? 7 : 9,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      size: compact ? 15 : 16,
                      color: selected
                          ? effectiveAccent
                          : VisionColors.secondaryText(brightness),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontSize: compact ? 11.5 : 12.5,
                        color: selected
                            ? VisionColors.primaryText(brightness)
                            : VisionColors.secondaryText(brightness),
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Segmented Liquid Glass tab switcher with smooth indicator transition.
class VisionGlassTabBar<T> extends StatelessWidget {
  const VisionGlassTabBar({
    required this.items,
    required this.selectedValue,
    required this.onSelected,
    super.key,
  });

  final List<({T value, String label, IconData? icon})> items;
  final T selectedValue;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final accent = VisionColors.primaryAccent(brightness);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: VisionGlass.decoration(
        brightness,
        variant: VisionGlassVariant.subtle,
        borderRadius: VisionRadii.mdBorder,
      ),
      child: Row(
        children: [
          for (final item in items)
            Expanded(
              child: _TabSegment(
                label: item.label,
                icon: item.icon,
                selected: item.value == selectedValue,
                accent: accent,
                onTap: () => onSelected(item.value),
              ),
            ),
        ],
      ),
    );
  }
}

class _TabSegment extends StatelessWidget {
  const _TabSegment({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
    this.icon,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: AnimatedContainer(
        duration: VisionAnimations.resolveDuration(
          context,
          VisionAnimations.micro,
        ),
        curve: VisionAnimations.standardCurve,
        decoration: selected
            ? BoxDecoration(
                borderRadius: VisionRadii.smBorder,
                color: accent.withValues(
                  alpha: brightness == Brightness.dark ? 0.20 : 0.14,
                ),
                border: Border.all(color: accent.withValues(alpha: 0.45)),
              )
            : null,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: VisionRadii.smBorder,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      size: 16,
                      color: selected
                          ? accent
                          : VisionColors.secondaryText(brightness),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: selected
                            ? VisionColors.primaryText(brightness)
                            : VisionColors.secondaryText(brightness),
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
