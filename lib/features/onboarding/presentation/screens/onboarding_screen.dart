import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/app/router/app_routes.dart';
import 'package:vision_ai/app/theme/app_colors.dart';
import 'package:vision_ai/core/constants/app_constants.dart';
import 'package:vision_ai/core/widgets/vision_app_bar.dart';
import 'package:vision_ai/core/widgets/vision_card.dart';
import 'package:vision_ai/core/widgets/vision_scaffold.dart';
import 'package:vision_ai/core/widgets/vision_status_badge.dart';
import 'package:vision_ai/features/settings/presentation/controllers/settings_controller.dart';

/// Architectural overview and honest roadmap verification screen for VISION AI.
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return VisionScaffold(
      appBar: const VisionAppBar(
        title: 'VISION ROADMAP',
        subtitle: 'Verified Implementation Status',
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          const Center(
            child: VisionStatusBadge(
              label: AppConstants.currentPhaseLabel,
              indicatorColor: AppColors.warning,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Built for Modularity & Honest Verification',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'VISION AI uses a feature-first Clean Architecture with Riverpod '
            'and native Kotlin bridges calibrated for ${AppConstants.targetDeviceName}. '
            'Live API and physical device tests remain gated on user credentials and device attachment.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          const _PhaseStepCard(
            phaseNumber: 'Phase 1',
            title: 'Production Project Foundation',
            description:
                'Feature-first modular structure, Riverpod state management, '
                'GoRouter navigation, dark/light themes, secret-redacted error boundaries, '
                'and settings persistence.',
            statusLabel: 'Completed',
            statusColor: AppColors.success,
          ),
          const SizedBox(height: 12),
          const _PhaseStepCard(
            phaseNumber: 'Phase 2',
            title: 'Multi-Provider AI Orchestration',
            description:
                'Unified AIProvider, AIModelRegistry, AIRouter & AIConversationManager '
                'with Gemini, OpenAI Responses API & Claude Messages API SSE streaming, '
                'tool calling, retry/cancellation, and real connection testing. '
                'Requires user API keys for live verification.',
            statusLabel: 'Implemented • Needs Live Key Test',
            statusColor: AppColors.warning,
          ),
          const SizedBox(height: 12),
          const _PhaseStepCard(
            phaseNumber: 'Phase 3',
            title: 'Multilingual Voice, Wake-Word & Assistant Role',
            description:
                'English, Hindi, and Gujarati STT/TTS, foreground AudioRecord '
                'wake-word service ("Hey VISION"), VoiceInteractionService, and '
                'translucent Assistant Overlay. Pending physical OPPO Reno 16 testing.',
            statusLabel: 'Implemented • Pending Device Test',
            statusColor: AppColors.warning,
          ),
          const SizedBox(height: 12),
          const _PhaseStepCard(
            phaseNumber: 'Phase 4',
            title: 'Android Device Automation & Actions',
            description:
                'Kotlin MethodChannel bridges for calls, contacts, alarms/timers, '
                'app launching, settings, WhatsApp composer, consent-gated notifications, '
                'and OPPO Reno 16 telemetry. Pending physical device verification.',
            statusLabel: 'In Progress • Pending Device Test',
            statusColor: AppColors.warning,
            isCurrent: true,
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
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
            icon: const Icon(Icons.check_rounded, size: 20),
            label: const Text('Return to VISION Home'),
          ),
        ],
      ),
    );
  }
}

class _PhaseStepCard extends StatelessWidget {
  const _PhaseStepCard({
    required this.phaseNumber,
    required this.title,
    required this.description,
    required this.statusLabel,
    required this.statusColor,
    this.isCurrent = false,
  });

  final String phaseNumber;
  final String title;
  final String description;
  final String statusLabel;
  final Color statusColor;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return VisionCard(
      borderColor: isCurrent ? colorScheme.primary : colorScheme.outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                phaseNumber.toUpperCase(),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
              Flexible(
                child: VisionStatusBadge(
                  label: statusLabel,
                  indicatorColor: statusColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(description, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
