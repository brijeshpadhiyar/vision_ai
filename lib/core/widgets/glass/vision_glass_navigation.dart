import 'dart:ui';

import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/theme/vision_animations.dart';
import 'package:vision_ai/core/theme/vision_colors.dart';
import 'package:vision_ai/core/theme/vision_glass.dart';
import 'package:vision_ai/core/theme/vision_radii.dart';

/// Translucent Liquid Glass top application bar.
class VisionGlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  const VisionGlassAppBar({
    required this.title,
    super.key,
    this.subtitle,
    this.leading,
    this.actions,
    this.centerTitle = true,
    this.enableBlur = true,
    this.titleWidget,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget>? actions;
  final bool centerTitle;
  final bool enableBlur;
  final Widget? titleWidget;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 8);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final isDark = brightness == Brightness.dark;

    final bar = AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: leading,
      centerTitle: centerTitle,
      actions: actions,
      title:
          titleWidget ??
          (subtitle == null
              ? Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w700,
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        letterSpacing: 1.3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle!,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: VisionColors.secondaryText(brightness),
                      ),
                    ),
                  ],
                )),
    );

    if (!enableBlur) {
      return bar;
    }

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: VisionGlass.blurSoft,
          sigmaY: VisionGlass.blurSoft,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? VisionColors.backgroundPrimary.withValues(alpha: 0.55)
                : Colors.white.withValues(alpha: 0.68),
            border: Border(
              bottom: BorderSide(
                color: VisionColors.glassBorder(brightness, opacity: 0.12),
              ),
            ),
          ),
          child: bar,
        ),
      ),
    );
  }
}

/// Destination descriptor for [VisionGlassNavigationBar].
class VisionNavItem {
  const VisionNavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    this.isPrimaryAssistant = false,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final bool isPrimaryAssistant;
}

/// Floating Liquid Glass bottom navigation bar with a prominent Assistant trigger.
class VisionGlassNavigationBar extends StatelessWidget {
  const VisionGlassNavigationBar({
    required this.items,
    required this.currentIndex,
    required this.onSelect,
    super.key,
  });

  final List<VisionNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final accent = VisionColors.primaryAccent(brightness);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: Center(
          heightFactor: 1.0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: RepaintBoundary(
              child: ClipRRect(
                borderRadius: VisionRadii.xlBorder,
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: VisionGlass.blurStandard,
                    sigmaY: VisionGlass.blurStandard,
                  ),
                  child: Container(
                    height: 70,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: VisionGlass.decoration(
                      brightness,
                      variant: VisionGlassVariant.elevated,
                      surfaceOpacity: isDark ? 0.10 : 0.78,
                      borderOpacity: 0.20,
                      borderRadius: VisionRadii.xlBorder,
                      showShadow: true,
                    ),
                    child: Row(
                      children: [
                        for (int i = 0; i < items.length; i++)
                          Expanded(
                            child: _NavBarDestination(
                              item: items[i],
                              selected: i == currentIndex,
                              accent: accent,
                              onTap: () => onSelect(i),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavBarDestination extends StatelessWidget {
  const _NavBarDestination({
    required this.item,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final VisionNavItem item;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final isDark = brightness == Brightness.dark;
    final duration = VisionAnimations.resolveDuration(
      context,
      VisionAnimations.micro,
    );

    if (item.isPrimaryAssistant) {
      return Semantics(
        button: true,
        selected: selected,
        label: '${item.label} voice assistant',
        child: Tooltip(
          message: 'Open VISION Voice Assistant',
          child: InkWell(
            onTap: onTap,
            borderRadius: VisionRadii.pillBorder,
            child: Center(
              child: AnimatedContainer(
                duration: duration,
                curve: VisionAnimations.standardCurve,
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: VisionColors.brandGradient,
                  border: Border.all(
                    color: Colors.white.withValues(
                      alpha: selected ? 0.75 : 0.4,
                    ),
                    width: selected ? 1.8 : 1.1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: VisionColors.accentPrimary.withValues(
                        alpha: selected ? 0.55 : 0.35,
                      ),
                      blurRadius: selected ? 20 : 14,
                      spreadRadius: selected ? 2 : 0,
                    ),
                  ],
                ),
                child: Icon(
                  selected ? item.activeIcon : item.icon,
                  color: VisionColors.backgroundPrimary,
                  size: 25,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: VisionRadii.lgBorder,
        child: SizedBox(
          height: 60,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: duration,
                curve: VisionAnimations.standardCurve,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  borderRadius: VisionRadii.pillBorder,
                  color: selected
                      ? accent.withValues(alpha: isDark ? 0.20 : 0.15)
                      : Colors.transparent,
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.24),
                            blurRadius: 12,
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  selected ? item.activeIcon : item.icon,
                  size: 21,
                  color: selected
                      ? accent
                      : VisionColors.secondaryText(brightness),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 10.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? VisionColors.primaryText(brightness)
                      : VisionColors.secondaryText(brightness),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
