import 'dart:ui';

import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/theme/vision_colors.dart';
import 'package:vision_ai/core/theme/vision_glass.dart';
import 'package:vision_ai/core/theme/vision_radii.dart';

/// Displays a Liquid Glass bottom sheet with frosted backdrop and drag handle.
Future<T?> showVisionGlassBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool useSafeArea = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (sheetContext) =>
        VisionGlassBottomSheet(child: builder(sheetContext)),
  );
}

/// Container frame for Liquid Glass modal bottom sheets.
class VisionGlassBottomSheet extends StatelessWidget {
  const VisionGlassBottomSheet({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 24),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    const radius = BorderRadius.vertical(top: Radius.circular(VisionRadii.xl));

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: VisionGlass.blurStrong,
          sigmaY: VisionGlass.blurStrong,
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: radius,
            color: isDark
                ? VisionColors.backgroundSecondary.withValues(alpha: 0.86)
                : Colors.white.withValues(alpha: 0.90),
            border: Border(
              top: BorderSide(
                color: VisionColors.glassBorder(brightness, opacity: 0.22),
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: padding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      borderRadius: VisionRadii.pillBorder,
                      color: VisionColors.secondaryText(brightness)
                          .withValues(alpha: 0.4),
                    ),
                  ),
                  Flexible(child: child),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows a Liquid Glass modal dialog with smooth scale + fade transition.
Future<T?> showVisionGlassDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.62),
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return SafeArea(child: builder(dialogContext));
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Reusable Liquid Glass modal dialog frame.
class VisionGlassDialog extends StatelessWidget {
  const VisionGlassDialog({
    required this.title,
    required this.content,
    required this.actions,
    super.key,
    this.icon,
    this.iconColor,
    this.maxWidth = 440,
  });

  final String title;
  final Widget content;
  final List<Widget> actions;
  final IconData? icon;
  final Color? iconColor;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final isDark = brightness == Brightness.dark;
    final accent = iconColor ?? VisionColors.primaryAccent(brightness);

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: VisionRadii.xlBorder,
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: VisionGlass.blurStrong,
                  sigmaY: VisionGlass.blurStrong,
                ),
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    borderRadius: VisionRadii.xlBorder,
                    color: isDark
                        ? VisionColors.backgroundSecondary.withValues(
                            alpha: 0.88,
                          )
                        : Colors.white.withValues(alpha: 0.94),
                    border: Border.all(
                      color: VisionColors.glassBorder(
                        brightness,
                        opacity: 0.20,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 32,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (icon != null) ...[
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                borderRadius: VisionRadii.smBorder,
                                color: accent.withValues(alpha: 0.14),
                                border: Border.all(
                                  color: accent.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Icon(icon, color: accent, size: 19),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: Text(
                              title,
                              style: theme.textTheme.titleLarge,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      content,
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          for (int i = 0; i < actions.length; i++) ...[
                            if (i > 0) const SizedBox(width: 8),
                            actions[i],
                          ],
                        ],
                      ),
                    ],
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

/// Liquid Glass styled popup menu wrapper.
class VisionGlassPopup<T> extends StatelessWidget {
  const VisionGlassPopup({
    required this.items,
    required this.onSelected,
    required this.child,
    super.key,
    this.tooltip,
  });

  final List<PopupMenuEntry<T>> items;
  final ValueChanged<T> onSelected;
  final Widget child;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return PopupMenuButton<T>(
      tooltip: tooltip,
      onSelected: onSelected,
      color: isDark
          ? VisionColors.backgroundElevated.withValues(alpha: 0.96)
          : Colors.white.withValues(alpha: 0.97),
      elevation: 10,
      shape: RoundedRectangleBorder(
        borderRadius: VisionRadii.mdBorder,
        side: BorderSide(
          color: VisionColors.glassBorder(brightness, opacity: 0.20),
        ),
      ),
      itemBuilder: (_) => items,
      child: child,
    );
  }
}
