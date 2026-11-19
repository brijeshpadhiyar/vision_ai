import 'package:flutter_animate/flutter_animate.dart';
import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/theme/vision_colors.dart';

/// Centralized motion timings, curves, reduced-motion helpers, and
/// `flutter_animate` presets for VISION AI.
abstract final class VisionAnimations {
  /// Micro-interactions: button press, chip toggle, icon pulse (120–220 ms).
  static const Duration micro = Duration(milliseconds: 160);
  static const Duration microFast = Duration(milliseconds: 120);

  /// Standard UI transitions: cards, panels, tabs, chat messages (220–350 ms).
  static const Duration standard = Duration(milliseconds: 280);
  static const Duration standardFast = Duration(milliseconds: 220);

  /// Large structural transitions: routes, sheets, dialogs (350–500 ms).
  static const Duration large = Duration(milliseconds: 400);
  static const Duration entrance = Duration(milliseconds: 460);

  /// Ambient orb and skeleton cycles.
  static const Duration orbBreath = Duration(milliseconds: 3400);
  static const Duration orbOrbit = Duration(milliseconds: 2600);
  static const Duration shimmerCycle = Duration(milliseconds: 1400);

  static const Curve standardCurve = Curves.easeOutCubic;
  static const Curve emphasizedCurve = Curves.easeOutQuart;
  static const Curve springCurve = Curves.easeOutBack;
  static const Curve breathCurve = Curves.easeInOutSine;

  /// Returns `true` when the user enabled reduced motion / disabled animations.
  static bool isReducedMotion(BuildContext context) {
    final media = MediaQuery.maybeOf(context);
    return (media?.disableAnimations ?? false) ||
        (media?.accessibleNavigation ?? false);
  }

  /// Returns `true` when tickers are active and reduced motion is disabled.
  static bool shouldAnimate(BuildContext context) {
    return !isReducedMotion(context) && TickerMode.valuesOf(context).enabled;
  }

  /// Resolves [normal] or [Duration.zero] when reduced motion is active.
  static Duration resolveDuration(
    BuildContext context,
    Duration normal, {
    Duration? reduced,
  }) {
    if (isReducedMotion(context)) {
      return reduced ?? Duration.zero;
    }
    return normal;
  }
}

/// Centralized reusable `flutter_animate` presets tuned for 60 FPS Android
/// rendering, reduced-motion accessibility, and off-screen lifecycle safety.
abstract final class VisionAnimatePresets {
  static Widget fadeIn(
    BuildContext context,
    Widget child, {
    Duration delay = Duration.zero,
    Duration duration = VisionAnimations.standardFast,
  }) {
    if (!VisionAnimations.shouldAnimate(context)) return child;
    return child
        .animate(autoPlay: false, onInit: (controller) => controller.forward())
        .fadeIn(
          delay: delay,
          duration: duration,
          curve: VisionAnimations.standardCurve,
        );
  }

  static Widget slideUp(
    BuildContext context,
    Widget child, {
    Duration delay = Duration.zero,
    Duration duration = VisionAnimations.standard,
    double beginY = 0.06,
  }) {
    if (!VisionAnimations.shouldAnimate(context)) return child;
    return child
        .animate(autoPlay: false, onInit: (controller) => controller.forward())
        .slideY(
          delay: delay,
          begin: beginY,
          end: 0,
          duration: duration,
          curve: VisionAnimations.standardCurve,
        );
  }

  static Widget scaleIn(
    BuildContext context,
    Widget child, {
    Duration delay = Duration.zero,
    Duration duration = VisionAnimations.standardFast,
    double beginScale = 0.96,
  }) {
    if (!VisionAnimations.shouldAnimate(context)) return child;
    return child
        .animate(autoPlay: false, onInit: (controller) => controller.forward())
        .fadeIn(
          delay: delay,
          duration: duration,
          curve: VisionAnimations.standardCurve,
        )
        .scale(
          delay: delay,
          begin: Offset(beginScale, beginScale),
          end: const Offset(1, 1),
          duration: duration,
          curve: VisionAnimations.emphasizedCurve,
        );
  }

  static Widget fadeAndSlide(
    BuildContext context,
    Widget child, {
    Duration delay = Duration.zero,
    Duration duration = VisionAnimations.standard,
    double beginY = 0.05,
  }) {
    if (!VisionAnimations.shouldAnimate(context)) return child;
    return child
        .animate(autoPlay: false, onInit: (controller) => controller.forward())
        .fadeIn(
          delay: delay,
          duration: duration,
          curve: VisionAnimations.standardCurve,
        )
        .slideY(
          delay: delay,
          begin: beginY,
          end: 0,
          duration: duration,
          curve: VisionAnimations.standardCurve,
        );
  }

  static Widget cardEntrance(
    BuildContext context,
    Widget child, {
    int index = 0,
  }) {
    if (!VisionAnimations.shouldAnimate(context)) return child;
    final clampedIndex = index.clamp(0, 5);
    return fadeAndSlide(
      context,
      child,
      delay: Duration(milliseconds: clampedIndex * 45),
      duration: VisionAnimations.standard,
      beginY: 0.04,
    );
  }

  static Widget buttonPress(
    BuildContext context,
    Widget child, {
    required bool isPressed,
    double pressedScale = 0.97,
  }) {
    final duration = VisionAnimations.resolveDuration(
      context,
      VisionAnimations.microFast,
    );
    return AnimatedScale(
      scale: isPressed && !VisionAnimations.isReducedMotion(context)
          ? pressedScale
          : 1.0,
      duration: duration,
      curve: VisionAnimations.standardCurve,
      child: child,
    );
  }

  static Widget iconTransition(
    BuildContext context,
    Widget child, {
    Duration duration = VisionAnimations.micro,
  }) {
    if (!VisionAnimations.shouldAnimate(context)) return child;
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: VisionAnimations.standardCurve,
      switchOutCurve: VisionAnimations.standardCurve,
      transitionBuilder: (widget, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.86, end: 1.0).animate(animation),
            child: widget,
          ),
        );
      },
      child: child,
    );
  }

  static Widget shimmer(BuildContext context, Widget child, {Color? color}) {
    if (!VisionAnimations.shouldAnimate(context)) return child;
    final brightness = Theme.of(context).brightness;
    final shimmerColor =
        color ??
        VisionColors.primaryAccent(brightness)
            .withValues(alpha: brightness == Brightness.dark ? 0.16 : 0.12);
    return child
        .animate(autoPlay: false, onInit: (controller) => controller.repeat())
        .shimmer(duration: VisionAnimations.shimmerCycle, color: shimmerColor);
  }

  static Widget subtleBreathing(
    BuildContext context,
    Widget child, {
    double minScale = 0.985,
    double maxScale = 1.015,
  }) {
    if (!VisionAnimations.shouldAnimate(context)) return child;
    return child
        .animate(
          autoPlay: false,
          onInit: (controller) => controller.repeat(reverse: true),
        )
        .scale(
          begin: Offset(minScale, minScale),
          end: Offset(maxScale, maxScale),
          duration: VisionAnimations.orbBreath,
          curve: VisionAnimations.breathCurve,
        );
  }
}

/// Ergonomic widget extensions delegating to [VisionAnimatePresets].
extension VisionWidgetAnimations on Widget {
  Widget visionFadeIn(
    BuildContext context, {
    Duration delay = Duration.zero,
    Duration duration = VisionAnimations.standardFast,
  }) => VisionAnimatePresets.fadeIn(
    context,
    this,
    delay: delay,
    duration: duration,
  );

  Widget visionSlideUp(
    BuildContext context, {
    Duration delay = Duration.zero,
    Duration duration = VisionAnimations.standard,
    double beginY = 0.06,
  }) => VisionAnimatePresets.slideUp(
    context,
    this,
    delay: delay,
    duration: duration,
    beginY: beginY,
  );

  Widget visionScaleIn(
    BuildContext context, {
    Duration delay = Duration.zero,
    Duration duration = VisionAnimations.standardFast,
    double beginScale = 0.96,
  }) => VisionAnimatePresets.scaleIn(
    context,
    this,
    delay: delay,
    duration: duration,
    beginScale: beginScale,
  );

  Widget visionFadeAndSlide(
    BuildContext context, {
    Duration delay = Duration.zero,
    Duration duration = VisionAnimations.standard,
    double beginY = 0.05,
  }) => VisionAnimatePresets.fadeAndSlide(
    context,
    this,
    delay: delay,
    duration: duration,
    beginY: beginY,
  );

  Widget visionCardEntrance(BuildContext context, {int index = 0}) =>
      VisionAnimatePresets.cardEntrance(context, this, index: index);

  Widget visionShimmer(BuildContext context, {Color? color}) =>
      VisionAnimatePresets.shimmer(context, this, color: color);

  Widget visionSubtleBreathing(
    BuildContext context, {
    double minScale = 0.985,
    double maxScale = 1.015,
  }) => VisionAnimatePresets.subtleBreathing(
    context,
    this,
    minScale: minScale,
    maxScale: maxScale,
  );
}

/// Lightweight press-scale wrapper providing tactile micro-feedback for buttons
/// and interactive cards while respecting reduced-motion preferences.
class VisionPressable extends StatefulWidget {
  const VisionPressable({
    required this.child,
    super.key,
    this.enabled = true,
    this.pressedScale = 0.97,
  });

  final Widget child;
  final bool enabled;
  final double pressedScale;

  @override
  State<VisionPressable> createState() => _VisionPressableState();
}

class _VisionPressableState extends State<VisionPressable> {
  bool _isPressed = false;

  void _setPressed(bool value) {
    if (!widget.enabled || _isPressed == value) return;
    setState(() => _isPressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: VisionAnimatePresets.buttonPress(
        context,
        widget.child,
        isPressed: _isPressed,
        pressedScale: widget.pressedScale,
      ),
    );
  }
}
