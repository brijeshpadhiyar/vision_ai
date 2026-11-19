import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/theme/vision_animations.dart';
import 'package:vision_ai/core/theme/vision_radius.dart';
import 'package:vision_ai/core/theme/vision_theme_extension.dart';

/// Semantic themed dialog helper using Midnight Violet / Pearl Lavender tokens
/// with a subtle reduced-motion-safe scale-and-fade entrance.
class VisionDialog extends StatelessWidget {
  const VisionDialog({
    required this.title,
    required this.content,
    super.key,
    this.icon,
    this.actions = const <Widget>[],
  });

  final String title;
  final Widget content;
  final IconData? icon;
  final List<Widget> actions;

  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    required Widget content,
    IconData? icon,
    List<Widget> actions = const <Widget>[],
  }) {
    return showDialog<T>(
      context: context,
      builder: (_) => VisionDialog(
        title: title,
        content: content,
        icon: icon,
        actions: actions,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.visionColors;
    return VisionAnimatePresets.scaleIn(
      context,
      AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: VisionRadius.xlBorder,
          side: BorderSide(color: colors.border),
        ),
        title: Row(
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 22, color: colors.primary),
              const SizedBox(width: 10),
            ],
            Expanded(child: Text(title)),
          ],
        ),
        content: content,
        actions: actions,
      ),
    );
  }
}
