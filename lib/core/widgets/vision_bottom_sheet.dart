import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/theme/vision_animations.dart';
import 'package:vision_ai/core/theme/vision_radius.dart';
import 'package:vision_ai/core/theme/vision_theme_extension.dart';

/// Semantic modal bottom sheet wrapper with drag handle, centralized typography,
/// and subtle reduced-motion-safe entrance.
class VisionBottomSheet extends StatelessWidget {
  const VisionBottomSheet({required this.child, super.key, this.title});

  final String? title;
  final Widget child;

  static Future<T?> show<T>(
    BuildContext context, {
    required Widget child,
    String? title,
    bool isScrollControlled = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: VisionBottomSheet(title: title, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.visionColors;
    return VisionAnimatePresets.slideUp(
      context,
      Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(VisionRadius.xl),
          ),
          border: Border(top: BorderSide(color: colors.border)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: VisionRadius.pillBorder,
                  ),
                ),
              ),
              if (title != null) ...<Widget>[
                Text(title!, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
              ],
              child,
            ],
          ),
        ),
      ),
      duration: VisionAnimations.standardFast,
      beginY: 0.04,
    );
  }
}
