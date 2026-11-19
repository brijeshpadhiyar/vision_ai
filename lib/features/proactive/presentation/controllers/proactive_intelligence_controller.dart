import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/app/router/app_routes.dart';
import 'package:vision_ai/features/planner/domain/entities/planner_task.dart';
import 'package:vision_ai/features/planner/presentation/controllers/daily_planner_controller.dart';
import 'package:vision_ai/features/proactive/domain/entities/proactive_suggestion.dart';
import 'package:vision_ai/features/settings/domain/entities/ai_provider_type.dart';
import 'package:vision_ai/features/settings/presentation/controllers/api_key_controller.dart';
import 'package:vision_ai/features/settings/presentation/controllers/settings_controller.dart';

/// Pure, 100% on-device contextual rule engine for Module 24 (Proactive Intelligence).
abstract final class ProactiveIntelligenceEngine {
  static List<ProactiveSuggestion> evaluate({
    required DateTime now,
    required List<PlannerTask> tasks,
    required bool hasConfiguredProvider,
    int? batteryPercent,
    bool isCharging = false,
    Set<String> dismissedIds = const <String>{},
  }) {
    final suggestions = <ProactiveSuggestion>[];
    final pendingTasks = tasks
        .where((t) => !t.completed)
        .toList(growable: false);
    final highPriorityCount = pendingTasks
        .where((t) => t.priority == PlannerPriority.high)
        .length;

    // 1. Low battery proactive awareness
    if (batteryPercent != null && batteryPercent <= 20 && !isCharging) {
      suggestions.add(
        ProactiveSuggestion(
          id: 'low_battery',
          title: 'Battery at $batteryPercent%',
          subtitle: 'Power is getting low. Review battery settings or keep VISION standby lightweight.',
          icon: Icons.battery_alert_rounded,
          actionLabel: 'Battery',
          actionType: ProactiveActionType.openBatterySettings,
          priority: 100,
        ),
      );
    }

    // 2. Setup readiness nudge when no API key & not on Edge AI
    if (!hasConfiguredProvider) {
      suggestions.add(
        const ProactiveSuggestion(
          id: 'setup_provider',
          title: 'Finish AI Provider Setup',
          subtitle: 'Add an API key (Gemini, OpenAI, Claude) or switch to On-Device Edge AI to unlock full chat.',
          icon: Icons.vpn_key_rounded,
          actionLabel: 'Setup',
          actionType: ProactiveActionType.openRoute,
          routePath: AppRoutes.settingsPath,
          priority: 95,
        ),
      );
    }

    // 3. Time-of-day + Daily Planner spoken briefing nudge
    final hour = now.hour;
    if (pendingTasks.isNotEmpty) {
      final isMorning = hour >= 5 && hour < 12;
      final isEvening = hour >= 19 || hour < 5;
      final greeting = isMorning
          ? 'Morning Briefing Ready'
          : isEvening
          ? 'Evening Wrap-Up'
          : 'Today\'s Focus';
      final detail = highPriorityCount > 0
          ? '${pendingTasks.length} pending ($highPriorityCount high priority). Tap to hear your spoken briefing.'
          : '${pendingTasks.length} task${pendingTasks.length == 1 ? '' : 's'} remaining today. Tap to hear your briefing.';
      suggestions.add(
        ProactiveSuggestion(
          id: 'planner_briefing',
          title: greeting,
          subtitle: detail,
          icon: isMorning
              ? Icons.wb_sunny_outlined
              : isEvening
              ? Icons.nights_stay_outlined
              : Icons.checklist_rounded,
          actionLabel: 'Speak',
          actionType: ProactiveActionType.speakBriefing,
          routePath: AppRoutes.plannerPath,
          priority: 85,
        ),
      );
    } else if (hour >= 6 && hour < 11) {
      suggestions.add(
        const ProactiveSuggestion(
          id: 'plan_your_day',
          title: 'Plan Your Day',
          subtitle: 'Your Daily Planner is clear. Add today\'s top priorities or say "Add task ...".',
          icon: Icons.edit_calendar_rounded,
          actionLabel: 'Planner',
          actionType: ProactiveActionType.openRoute,
          routePath: AppRoutes.plannerPath,
          priority: 70,
        ),
      );
    }

    // 4. Discoverability nudge for Help & Guide when list is otherwise light
    if (suggestions.length < 2) {
      suggestions.add(
        const ProactiveSuggestion(
          id: 'explore_help',
          title: 'Explore Voice Commands & Guides',
          subtitle: 'Try Maps navigation, YouTube search, Smart Home scenes, or Offline OCR.',
          icon: Icons.tips_and_updates_outlined,
          actionLabel: 'Guide',
          actionType: ProactiveActionType.openRoute,
          routePath: AppRoutes.helpPath,
          priority: 40,
        ),
      );
    }

    final filtered =
        suggestions
            .where((s) => !dismissedIds.contains(s.id))
            .toList(growable: false)
          ..sort((a, b) => b.priority.compareTo(a.priority));
    return filtered;
  }
}

class ProactiveDismissedNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const <String>{};

  void dismiss(String id) {
    state = <String>{...state, id};
  }

  void resetAll() {
    state = const <String>{};
  }
}

final proactiveDismissedProvider =
    NotifierProvider<ProactiveDismissedNotifier, Set<String>>(
      ProactiveDismissedNotifier.new,
    );

/// Live reactive list of proactive suggestions for the Home screen.
final proactiveSuggestionsProvider = Provider<List<ProactiveSuggestion>>((ref) {
  final tasks = ref.watch(dailyPlannerControllerProvider);
  final settings = ref.watch(settingsControllerProvider);
  final keyStatus = ref.watch(apiKeyStatusControllerProvider);
  final dismissed = ref.watch(proactiveDismissedProvider);

  final keyMap = keyStatus.asData?.value ?? const <AiProviderType, bool>{};
  final hasConfiguredProvider =
      settings.selectedAiProvider == AiProviderType.edgeAi ||
      (keyMap[settings.selectedAiProvider] ?? false);

  return ProactiveIntelligenceEngine.evaluate(
    now: DateTime.now(),
    tasks: tasks,
    hasConfiguredProvider: hasConfiguredProvider,
    dismissedIds: dismissed,
  );
});
