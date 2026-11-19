import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/theme/vision_radius.dart';
import 'package:vision_ai/core/theme/vision_theme_extension.dart';

/// Secondary outlined button using semantic border and primary accent tokens.
class VisionSecondaryButton extends StatelessWidget {
  const VisionSecondaryButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
    this.expanded = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final colors = context.visionColors;
    final button = OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.primary,
        side: BorderSide(color: colors.border),
        backgroundColor: colors.surface,
        minimumSize: Size(expanded ? double.infinity : 0, 46),
        shape: const RoundedRectangleBorder(
          borderRadius: VisionRadius.mdBorder,
        ),
      ),
      child: Row(
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

    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}
