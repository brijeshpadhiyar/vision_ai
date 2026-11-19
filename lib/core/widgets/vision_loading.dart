import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/theme/vision_motion.dart';
import 'package:vision_ai/core/theme/vision_radius.dart';
import 'package:vision_ai/core/theme/vision_theme_extension.dart';

/// Lightweight, reduced-motion-aware shimmer skeleton placeholder for
/// provider cards, model lists, and chat loading indicators.
class VisionLoadingSkeleton extends StatefulWidget {
  const VisionLoadingSkeleton({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = VisionRadius.smBorder,
  });

  final double width;
  final double height;
  final BorderRadius borderRadius;

  /// Pre-composed skeleton card matching AI provider & settings cards.
  static Widget cardPlaceholder() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          VisionLoadingSkeleton(width: 160, height: 16),
          SizedBox(height: 10),
          VisionLoadingSkeleton(height: 12),
          SizedBox(height: 6),
          VisionLoadingSkeleton(width: 220, height: 12),
        ],
      ),
    );
  }

  @override
  State<VisionLoadingSkeleton> createState() => _VisionLoadingSkeletonState();
}

class _VisionLoadingSkeletonState extends State<VisionLoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: VisionMotion.decorative,
    )..repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (VisionMotion.reduceMotion(context)) {
      _controller.stop();
      _controller.value = 0.5;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.visionColors;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final alpha = 0.35 + (_controller.value * 0.35);
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: colors.border.withValues(alpha: alpha),
            borderRadius: widget.borderRadius,
          ),
        );
      },
    );
  }
}
