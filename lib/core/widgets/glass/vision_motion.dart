import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/theme/vision_animations.dart';
import 'package:vision_ai/core/theme/vision_colors.dart';
import 'package:vision_ai/core/theme/vision_radii.dart';

/// Lightweight shimmer placeholder bar for loading and AI thinking states.
class VisionShimmer extends StatefulWidget {
  const VisionShimmer({
    super.key,
    this.width = double.infinity,
    this.height = 14,
    this.borderRadius,
  });

  final double width;
  final double height;
  final BorderRadius? borderRadius;

  @override
  State<VisionShimmer> createState() => _VisionShimmerState();
}

class _VisionShimmerState extends State<VisionShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: VisionAnimations.shimmerCycle,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final reducedMotion = VisionAnimations.isReducedMotion(context);
    final baseColor = VisionColors.glassSurface(brightness, opacity: 0.07);
    final highlightColor = VisionColors.accentPrimary.withValues(
      alpha: brightness == Brightness.dark ? 0.20 : 0.14,
    );
    final radius = widget.borderRadius ?? VisionRadii.smBorder;

    if (reducedMotion) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(color: baseColor, borderRadius: radius),
      );
    }

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final shift = (_controller.value * 2.4) - 1.2;
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: LinearGradient(
                begin: Alignment(shift - 0.8, 0),
                end: Alignment(shift + 0.8, 0),
                colors: [baseColor, highlightColor, baseColor],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Subtle staggered entrance reveal respecting system reduced-motion settings.
class VisionStaggeredReveal extends StatefulWidget {
  const VisionStaggeredReveal({
    required this.child,
    super.key,
    this.delay = Duration.zero,
    this.offsetY = 14,
  });

  final Widget child;
  final Duration delay;
  final double offsetY;

  @override
  State<VisionStaggeredReveal> createState() => _VisionStaggeredRevealState();
}

class _VisionStaggeredRevealState extends State<VisionStaggeredReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: VisionAnimations.standard,
    );
    final curved = CurvedAnimation(
      parent: _controller,
      curve: VisionAnimations.standardCurve,
    );
    _opacity = curved;
    _slide = Tween<Offset>(
      begin: Offset(0, widget.offsetY / 100),
      end: Offset.zero,
    ).animate(curved);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (VisionAnimations.isReducedMotion(context)) {
      _controller.value = 1.0;
    } else if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (VisionAnimations.isReducedMotion(context)) {
      return widget.child;
    }
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
