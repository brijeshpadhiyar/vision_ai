import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/theme/vision_radius.dart';
import 'package:vision_ai/core/theme/vision_spacing.dart';
import 'package:vision_ai/core/theme/vision_theme_extension.dart';
import 'package:vision_ai/core/widgets/vision_primary_button.dart';

/// Semantic empty state card with consistent hierarchy and optional primary CTA.
class VisionEmptyView extends StatelessWidget {
  const VisionEmptyView({
    required this.title,
    required this.message,
    super.key,
    this.icon = Icons.auto_awesome_outlined,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.visionColors;

    return Container(
      padding: const EdgeInsets.all(VisionSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: VisionRadius.lgBorder,
        border: Border.all(color: colors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 26, color: colors.primary),
          ),
          const SizedBox(height: VisionSpacing.sm),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          if (actionLabel != null && onAction != null) ...<Widget>[
            const SizedBox(height: VisionSpacing.md),
            VisionPrimaryButton(label: actionLabel!, onPressed: onAction),
          ],
        ],
      ),
    );
  }
}
