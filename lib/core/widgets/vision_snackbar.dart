import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/theme/vision_radius.dart';
import 'package:vision_ai/core/theme/vision_theme_extension.dart';

enum VisionSnackBarTone { info, success, warning, error }

/// Semantic floating snackbar helper for VISION AI.
abstract final class VisionSnackBar {
  static void show(
    BuildContext context, {
    required String message,
    VisionSnackBarTone tone = VisionSnackBarTone.info,
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    final colors = context.visionColors;
    final (Color accent, IconData icon) = switch (tone) {
      VisionSnackBarTone.info => (colors.primary, Icons.info_outline_rounded),
      VisionSnackBarTone.success => (
        colors.success,
        Icons.check_circle_outline_rounded,
      ),
      VisionSnackBarTone.warning => (
        colors.warning,
        Icons.warning_amber_rounded,
      ),
      VisionSnackBarTone.error => (colors.error, Icons.error_outline_rounded),
    };

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: duration,
          behavior: SnackBarBehavior.floating,
          backgroundColor: colors.elevatedSurface,
          shape: RoundedRectangleBorder(
            borderRadius: VisionRadius.mdBorder,
            side: BorderSide(color: accent.withValues(alpha: 0.45)),
          ),
          action: action,
          content: Row(
            children: <Widget>[
              Icon(icon, size: 18, color: accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: colors.textPrimary),
                ),
              ),
            ],
          ),
        ),
      );
  }
}
