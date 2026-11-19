import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/theme/vision_animations.dart';
import 'package:vision_ai/core/theme/vision_radius.dart';
import 'package:vision_ai/core/theme/vision_spacing.dart';
import 'package:vision_ai/core/theme/vision_theme_extension.dart';
import 'package:vision_ai/core/widgets/vision_primary_button.dart';

/// Semantic error & offline recovery state view with optional retry action and
/// subtle fade-and-slide entrance.
class VisionErrorView extends StatelessWidget {
  const VisionErrorView({
    required this.title,
    required this.message,
    super.key,
    this.icon = Icons.error_outline_rounded,
    this.retryLabel = 'Retry',
    this.onRetry,
  });

  final String title;
  final String message;
  final IconData icon;
  final String retryLabel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.visionColors;

    return VisionAnimatePresets.fadeAndSlide(
      context,
      Container(
        padding: const EdgeInsets.all(VisionSpacing.lg),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: VisionRadius.lgBorder,
          border: Border.all(color: colors.error.withValues(alpha: 0.4)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 36, color: colors.error),
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
            if (onRetry != null) ...<Widget>[
              const SizedBox(height: VisionSpacing.md),
              VisionPrimaryButton(
                label: retryLabel,
                icon: Icons.refresh_rounded,
                onPressed: onRetry,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
