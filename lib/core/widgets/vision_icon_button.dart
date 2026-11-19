import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/theme/vision_animations.dart';
import 'package:vision_ai/core/theme/vision_radius.dart';
import 'package:vision_ai/core/theme/vision_theme_extension.dart';

/// Accessible 44x44 semantic icon button with tactile press feedback and
/// smooth icon transitions.
class VisionIconButton extends StatelessWidget {
  const VisionIconButton({
    required this.icon,
    required this.onPressed,
    super.key,
    this.tooltip,
    this.selected = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.visionColors;
    return VisionPressable(
      enabled: onPressed != null,
      pressedScale: 0.94,
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        style: IconButton.styleFrom(
          minimumSize: const Size(44, 44),
          backgroundColor: selected ? colors.primaryContainer : colors.surface,
          foregroundColor: selected ? colors.primary : colors.textPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: VisionRadius.smBorder,
            side: BorderSide(color: selected ? colors.primary : colors.border),
          ),
        ),
        icon: VisionAnimatePresets.iconTransition(
          context,
          Icon(
            icon,
            key: ValueKey<String>('${icon.codePoint}_$selected'),
            size: 20,
          ),
        ),
      ),
    );
  }
}
