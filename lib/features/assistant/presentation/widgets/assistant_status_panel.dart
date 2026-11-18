import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/theme/vision_animations.dart';
import 'package:vision_ai/core/theme/vision_colors.dart';
import 'package:vision_ai/core/theme/vision_glass.dart';
import 'package:vision_ai/core/widgets/glass/vision_glass_card.dart';
import 'package:vision_ai/core/widgets/vision_status_badge.dart';
import 'package:vision_ai/features/assistant/domain/entities/assistant_readiness.dart';
import 'package:vision_ai/features/chat/domain/entities/ai_models.dart';
import 'package:vision_ai/features/settings/domain/entities/app_settings.dart';
import 'package:vision_ai/features/voice/domain/entities/voice_session_state.dart';

/// Liquid Glass status card displaying real assistant readiness, voice state,
/// active AI provider, connection verification status, and locale.
class AssistantStatusPanel extends StatelessWidget {
  const AssistantStatusPanel({
    required this.readiness,
    required this.settings,
    super.key,
    this.voiceState,
    this.connectionState = ProviderConnectionState.untested,
    this.hasApiKey = false,
    this.onDismissNotice,
    this.onTapProviderStatus,
  });

  final AssistantReadiness readiness;
  final AppSettings settings;
  final VoiceSessionState? voiceState;
  final ProviderConnectionState connectionState;
  final bool hasApiKey;
  final VoidCallback? onDismissNotice;
  final VoidCallback? onTapProviderStatus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
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

    final (providerStatusText, providerColor) = switch (connectionState) {
      ProviderConnectionState.connected => ('Connected', VisionColors.success),
      ProviderConnectionState.testing => (
        'Testing...',
        VisionColors.accentPrimary,
      ),
      ProviderConnectionState.failed => ('Check Failed', VisionColors.error),
      ProviderConnectionState.missingKey => (
        'Key Needed',
        VisionColors.warning,
      ),
      ProviderConnectionState.disabled => (
        'Disabled',
        VisionColors.mutedText(brightness),
      ),
      ProviderConnectionState.untested =>
        hasApiKey
            ? ('Key Saved', VisionColors.accentPrimary)
            : ('Key Needed', VisionColors.warning),
    };

    return AnimatedSwitcher(
      duration: VisionAnimations.resolveDuration(
        context,
        VisionAnimations.standardFast,
      ),
      child: VisionGlassCard(
        key: ValueKey<String>('$headline-$providerStatusText-$hasApiKey'),
        variant: isVoiceActive
            ? VisionGlassVariant.accent
            : VisionGlassVariant.standard,
        borderColor: hasVoiceError
            ? VisionColors.error.withValues(alpha: 0.65)
            : isVoiceActive
            ? VisionColors.success.withValues(alpha: 0.65)
            : null,
        padding: const EdgeInsets.all(16),
        onTap: onTapProviderStatus,
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
                      : Icons.auto_awesome_rounded,
                  size: 18,
                  color: hasVoiceError
                      ? VisionColors.error
                      : isVoiceActive
                      ? VisionColors.success
                      : VisionColors.primaryAccent(brightness),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(headline, style: theme.textTheme.titleSmall),
                ),
                VisionStatusBadge(
                  label: providerStatusText,
                  indicatorColor: providerColor,
                  compact: true,
                ),
                if (hasVoiceError && onDismissNotice != null) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: onDismissNotice,
                    icon: const Icon(Icons.close_rounded, size: 18),
                    tooltip: 'Dismiss notice',
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(detail, style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                VisionGlassMetaPill(
                  icon: Icons.hub_outlined,
                  label:
                      '${settings.selectedAiProvider.displayName} • ${settings.selectedModelId}',
                ),
                VisionGlassMetaPill(
                  icon: Icons.translate_rounded,
                  label:
                      '${settings.selectedVoiceLanguage.displayName} (${settings.selectedVoiceLanguage.localeCode})',
                ),
                if (settings.wakeWordEnabled)
                  const VisionGlassMetaPill(
                    icon: Icons.hearing_rounded,
                    label: '"Hey VISION" Armed',
                    color: VisionColors.success,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
