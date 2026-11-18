import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/app/router/app_routes.dart';
import 'package:vision_ai/core/constants/app_constants.dart';
import 'package:vision_ai/core/theme/vision_colors.dart';
import 'package:vision_ai/core/theme/vision_glass.dart';
import 'package:vision_ai/core/theme/vision_radii.dart';
import 'package:vision_ai/core/widgets/glass/vision_glass_widgets.dart';
import 'package:vision_ai/core/widgets/vision_app_bar.dart';
import 'package:vision_ai/core/widgets/vision_brand_logo.dart';
import 'package:vision_ai/core/widgets/vision_scaffold.dart';
import 'package:vision_ai/core/widgets/vision_status_badge.dart';
import 'package:vision_ai/features/settings/presentation/controllers/settings_controller.dart';

enum _PhaseState { completed, active, pendingVerification }

class _RoadmapPhaseItem {
  const _RoadmapPhaseItem({
    required this.phaseNumber,
    required this.title,
    required this.description,
    required this.statusLabel,
    required this.state,
    required this.progress,
  });

  final String phaseNumber;
  final String title;
  final String description;
  final String statusLabel;
  final _PhaseState state;
  final double progress;
}

/// Liquid Glass timeline roadmap screen showing honest verified project status.
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  static const List<_RoadmapPhaseItem> _phases = <_RoadmapPhaseItem>[
    _RoadmapPhaseItem(
      phaseNumber: 'Phase 1',
      title: 'Production Project Foundation',
      description:
          'Feature-first modular architecture, Riverpod state management, '
          'GoRouter navigation, dark/light themes, secret-redacted error boundaries, '
          'and persistent preferences.',
      statusLabel: 'Completed',
      state: _PhaseState.completed,
      progress: 1.0,
    ),
    _RoadmapPhaseItem(
      phaseNumber: 'Phase 2',
      title: 'Multi-Provider AI Orchestration',
      description:
          'Unified AIProvider, AIModelRegistry, AIRouter & AIConversationManager '
          'with Gemini, OpenAI Responses API & Claude Messages API SSE streaming, '
          'tool calling, retry/cancellation, and real connection testing. '
          'Requires user API keys for live account verification.',
      statusLabel: 'Implemented • Needs Live Key Test',
      state: _PhaseState.pendingVerification,
      progress: 0.85,
    ),
    _RoadmapPhaseItem(
      phaseNumber: 'Phase 3',
      title: 'Multilingual Voice, Wake-Word & Assistant Role',
      description:
          'English, Hindi, and Gujarati STT/TTS, foreground AudioRecord '
          'wake-word service ("Hey VISION"), VoiceInteractionService, and '
          'dedicated Assistant experience. Pending physical OPPO Reno 16 testing.',
      statusLabel: 'Implemented • Pending Device Test',
      state: _PhaseState.pendingVerification,
      progress: 0.85,
    ),
    _RoadmapPhaseItem(
      phaseNumber: 'Phase 4',
      title: 'Android Device Automation & Actions',
      description:
          'Kotlin MethodChannel bridges for calls, contacts, alarms/timers, '
          'app launching, settings, WhatsApp composer, consent-gated notifications, '
          'and OPPO Reno 16 telemetry. Pending physical device verification.',
      statusLabel: 'In Progress • Pending Device Test',
      state: _PhaseState.active,
      progress: 0.80,
    ),
    _RoadmapPhaseItem(
      phaseNumber: 'Phase 5',
      title: 'Liquid Glass UI/UX & Assistant Experience',
      description:
          'Centralized Liquid Glass design tokens, floating glass navigation, '
          '5-state animated VisionAiOrb, dedicated Voice Assistant mode, '
          'Markdown + code rendering, and responsive OPPO Reno 16 polish.',
      statusLabel: 'Active • UI/UX Redesign',
      state: _PhaseState.active,
      progress: 0.90,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final accent = VisionColors.primaryAccent(brightness);
    final completedCount = _phases
        .where((p) => p.state == _PhaseState.completed)
        .length;
    final overallProgress =
        _phases.fold<double>(0, (sum, item) => sum + item.progress) /
        _phases.length;

    return VisionScaffold(
      appBar: const VisionAppBar(
        title: 'VISION ROADMAP',
        subtitle: 'Honest Implementation Timeline',
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          VisionGlassCard(
            variant: VisionGlassVariant.accent,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const VisionBrandLogo(size: 38, showAmbientGlow: false),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Built for Honest Verification',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Target: ${AppConstants.targetDeviceName} • '
                            '$completedCount/${_phases.length} fully verified',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Implementation Progress',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: VisionColors.primaryText(brightness),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(overallProgress * 100).round()}% code complete',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: VisionRadii.pillBorder,
                  child: LinearProgressIndicator(
                    value: overallProgress,
                    minHeight: 7,
                    backgroundColor: VisionColors.glassSurface(
                      brightness,
                      opacity: 0.12,
                    ),
                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Live AI tests and physical Android device execution remain gated on '
                  'user API credentials and an attached ${AppConstants.targetDeviceName}.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          for (int i = 0; i < _phases.length; i++)
            _TimelinePhaseNode(
              item: _phases[i],
              isLast: i == _phases.length - 1,
            ),
          const SizedBox(height: 16),
          VisionGlassButton(
            expand: true,
            icon: Icons.check_rounded,
            label: 'Return to VISION Home',
            onPressed: () async {
              await ref
                  .read(settingsControllerProvider.notifier)
                  .completeOnboarding();
              if (context.mounted) {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(AppRoutes.homePath);
                }
              }
            },
          ),
        ],
      ),
    );
  }
}

class _TimelinePhaseNode extends StatelessWidget {
  const _TimelinePhaseNode({required this.item, required this.isLast});

  final _RoadmapPhaseItem item;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final statusColor = switch (item.state) {
      _PhaseState.completed => VisionColors.success,
      _PhaseState.active => VisionColors.accentPrimary,
      _PhaseState.pendingVerification => VisionColors.warning,
    };
    final isCurrent = item.state == _PhaseState.active;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                const SizedBox(height: 18),
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: statusColor.withValues(alpha: 0.22),
                    border: Border.all(color: statusColor, width: 2.2),
                    boxShadow: isCurrent
                        ? [
                            BoxShadow(
                              color: statusColor.withValues(alpha: 0.55),
                              blurRadius: 10,
                            ),
                          ]
                        : null,
                  ),
                  child: item.state == _PhaseState.completed
                      ? Icon(Icons.check, size: 10, color: statusColor)
                      : null,
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            statusColor.withValues(alpha: 0.55),
                            VisionColors.glassBorder(brightness, opacity: 0.14),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: VisionGlassCard(
                variant: isCurrent
                    ? VisionGlassVariant.accent
                    : VisionGlassVariant.standard,
                borderColor: isCurrent
                    ? statusColor.withValues(alpha: 0.55)
                    : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        Text(
                          item.phaseNumber.toUpperCase(),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                        ),
                        VisionStatusBadge(
                          label: item.statusLabel,
                          indicatorColor: statusColor,
                          compact: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(item.title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text(item.description, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
