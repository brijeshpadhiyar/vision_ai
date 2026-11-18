import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/constants/app_constants.dart';
import 'package:vision_ai/core/theme/vision_animations.dart';
import 'package:vision_ai/core/theme/vision_colors.dart';

/// Displays a time-aware personalized greeting and VISION subtitle.
class AssistantGreetingHeader extends StatelessWidget {
  const AssistantGreetingHeader({
    super.key,
    this.greeting = AppConstants.homeGreeting,
    this.subtitle = AppConstants.homeSubtitle,
  });

  final String greeting;
  final String subtitle;

  String _timeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'GOOD MORNING';
    if (hour < 17) return 'GOOD AFTERNOON';
    return 'GOOD EVENING';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final reducedMotion = VisionAnimations.isReducedMotion(context);

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _timeGreeting(),
          textAlign: TextAlign.center,
          style: theme.textTheme.labelMedium?.copyWith(
            color: VisionColors.primaryAccent(brightness),
            letterSpacing: 2.0,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          greeting,
          textAlign: TextAlign.center,
          style: theme.textTheme.displaySmall?.copyWith(
            fontSize: 28,
            color: VisionColors.primaryText(brightness),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );

    if (reducedMotion) return content;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: VisionAnimations.entrance,
      curve: VisionAnimations.standardCurve,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 10),
            child: child,
          ),
        );
      },
      child: content,
    );
  }
}
