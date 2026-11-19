import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/theme/vision_motion.dart';
import 'package:vision_ai/core/theme/vision_radius.dart';
import 'package:vision_ai/core/theme/vision_theme_extension.dart';

/// Primary semantic action button with Midnight Violet / Pearl Lavender styling.
class VisionPrimaryButton extends StatelessWidget {
  const VisionPrimaryButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
    this.isLoading = false,
    this.expanded = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final colors = context.visionColors;
    final child = AnimatedSwitcher(
      duration: VisionMotion.resolve(context, VisionMotion.micro),
      child: isLoading
          ? SizedBox(
              key: const ValueKey<String>('loading'),
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            )
          : Row(
              key: const ValueKey<String>('content'),
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  Icon(icon, size: 18),
                  const SizedBox(width: 8),
                ],
                Text(label),
              ],
            ),
    );

    final button = FilledButton(
      onPressed: isLoading ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: colors.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        minimumSize: Size(expanded ? double.infinity : 0, 48),
        shape: const RoundedRectangleBorder(
          borderRadius: VisionRadius.mdBorder,
        ),
      ),
      child: child,
    );

    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}
