import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/app/theme/app_colors.dart';
import 'package:vision_ai/core/widgets/vision_card.dart';
import 'package:vision_ai/features/assistant/domain/entities/assistant_readiness.dart';
import 'package:vision_ai/features/settings/domain/entities/app_settings.dart';
import 'package:vision_ai/features/voice/domain/entities/voice_session_state.dart';

/// Displays current readiness, live voice transcript, configured AI provider, and voice locale.
class AssistantStatusPanel extends StatelessWidget {
  const AssistantStatusPanel({
    required this.readiness,
    required this.settings,
    super.key,
    this.voiceState,
    this.onDismissNotice,
  });

  final AssistantReadiness readiness;
  final AppSettings settings;
  final VoiceSessionState? voiceState;
  final VoidCallback? onDismissNotice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isNotice =
        readiness.mode == AssistantStandbyMode.micPlaceholderNotice;
    final hasVoiceError = voiceState?.errorMessage != null;
    final isMicActive = voiceState?.isMicActuallyActive ?? false;
    final isVoiceActive =
        isMicActive || (voiceState?.phase == VoiceListeningPhase.processingAi);

    final headline = hasVoiceError
        ? 'Voice Engine Notice'
        : isVoiceActive
        ? (voiceState?.phase == VoiceListeningPhase.processingAi
              ? 'Processing Voice Command...'
              : (voiceState?.isWakeServiceRunning ?? false) &&
                    !(voiceState?.isListening ?? false)
              ? 'Hands-Free Standby Active ("Hey VISION")'
              : voiceState?.phase == VoiceListeningPhase.listeningWakeWord
              ? 'Wake-Word Standby ("Hey VISION")'
              : 'Listening (${settings.selectedVoiceLanguage.displayName})...')
        : readiness.statusHeadline;

    final detail = hasVoiceError
        ? voiceState!.errorMessage!
        : (voiceState != null && voiceState!.liveTranscript.isNotEmpty)
        ? '"${voiceState!.liveTranscript}"'
        : readiness.statusDetail;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: VisionCard(
        key: ValueKey<String>('$headline-$detail'),
        borderColor: hasVoiceError
            ? AppColors.error.withValues(alpha: 0.7)
            : isVoiceActive
            ? AppColors.success.withValues(alpha: 0.7)
            : isNotice
            ? colorScheme.primary.withValues(alpha: 0.65)
            : colorScheme.outline,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  hasVoiceError
                      ? Icons.warning_amber_rounded
                      : isVoiceActive
                      ? Icons.graphic_eq_rounded
                      : isNotice
                      ? Icons.info_outline_rounded
                      : Icons.verified_user_outlined,
                  size: 18,
                  color: hasVoiceError
                      ? AppColors.error
                      : isVoiceActive
                      ? AppColors.success
                      : colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    headline,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: 14,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                if ((isNotice || hasVoiceError) && onDismissNotice != null)
                  IconButton(
                    onPressed: onDismissNotice,
                    icon: const Icon(Icons.close_rounded, size: 18),
                    tooltip: 'Dismiss notice',
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(detail, style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _ConfigChip(
                  icon: Icons.hub_outlined,
                  label: 'AI: ${settings.selectedAiProvider.displayName}',
                ),
                _ConfigChip(
                  icon: Icons.translate_rounded,
                  label:
                      'Voice: ${settings.selectedVoiceLanguage.displayName} (${settings.selectedVoiceLanguage.localeCode})',
                ),
                if (settings.wakeWordEnabled)
                  const _ConfigChip(
                    icon: Icons.hearing_rounded,
                    label: 'Wake-Word: "Hey VISION"',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfigChip extends StatelessWidget {
  const _ConfigChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: colorScheme.primary),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
