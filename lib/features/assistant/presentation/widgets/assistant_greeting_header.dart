import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/constants/app_constants.dart';

/// Displays the primary VISION greeting and subtitle with a smooth entrance transition.
class AssistantGreetingHeader extends StatelessWidget {
  const AssistantGreetingHeader({
    super.key,
    this.greeting = AppConstants.homeGreeting,
    this.subtitle = AppConstants.homeSubtitle,
  });

  final String greeting;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 12),
            child: child,
          ),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            greeting,
            textAlign: TextAlign.center,
            style: theme.textTheme.displaySmall?.copyWith(
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
