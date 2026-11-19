import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/theme/vision_colors.dart';
import 'package:vision_ai/core/theme/vision_glass.dart';
import 'package:vision_ai/core/widgets/glass/vision_glass_widgets.dart';
import 'package:vision_ai/features/automation/domain/entities/device_action.dart';
import 'package:vision_ai/features/automation/presentation/controllers/automation_controller.dart';
import 'package:vision_ai/features/planner/presentation/controllers/daily_planner_controller.dart';
import 'package:vision_ai/features/proactive/domain/entities/proactive_suggestion.dart';
import 'package:vision_ai/features/proactive/presentation/controllers/proactive_intelligence_controller.dart';
import 'package:vision_ai/features/voice/presentation/controllers/voice_controller.dart';

/// Compact proactive intelligence cards shown on the Home screen (Module 24).
class ProactiveSuggestionsStrip extends ConsumerWidget {
  const ProactiveSuggestionsStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestions = ref.watch(proactiveSuggestionsProvider);
    if (suggestions.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final accent = VisionColors.primaryAccent(theme.brightness);
    final top = suggestions.take(2).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 15, color: accent),
              const SizedBox(width: 6),
              Text(
                'PROACTIVE SUGGESTIONS',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: accent,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        for (final item in top)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: VisionGlassCard(
              variant: VisionGlassVariant.subtle,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(item.icon, size: 20, color: accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title, style: theme.textTheme.titleSmall),
                        const SizedBox(height: 2),
                        Text(
                          item.subtitle,
                          style: theme.textTheme.bodySmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: () => _handleAction(context, ref, item),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(item.actionLabel),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 16),
                    tooltip: 'Dismiss',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => ref
                        .read(proactiveDismissedProvider.notifier)
                        .dismiss(item.id),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    ProactiveSuggestion item,
  ) async {
    switch (item.actionType) {
      case ProactiveActionType.speakBriefing:
        final briefing = ref
            .read(dailyPlannerControllerProvider.notifier)
            .buildDailyBriefing();
        await ref.read(voiceControllerProvider.notifier).speakReply(briefing);
      case ProactiveActionType.openRoute:
        final route = item.routePath;
        if (route != null && context.mounted) {
          await context.push(route);
        }
      case ProactiveActionType.openBatterySettings:
        await ref
            .read(automationControllerProvider.notifier)
            .executeRequest(
              const DeviceActionRequest(
                type: DeviceActionType.openSettings,
                target: 'battery',
                displaySummary: 'Open Battery settings',
              ),
            );
    }
  }
}
