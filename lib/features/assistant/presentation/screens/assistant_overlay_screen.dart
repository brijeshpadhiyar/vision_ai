import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/app/router/app_routes.dart';
import 'package:vision_ai/app/theme/app_colors.dart';
import 'package:vision_ai/core/widgets/vision_card.dart';
import 'package:vision_ai/core/widgets/vision_status_badge.dart';
import 'package:vision_ai/features/assistant/presentation/widgets/assistant_orb.dart';
import 'package:vision_ai/features/automation/presentation/controllers/automation_controller.dart';
import 'package:vision_ai/features/automation/presentation/widgets/automation_action_prompt_card.dart';
import 'package:vision_ai/features/settings/presentation/controllers/settings_controller.dart';
import 'package:vision_ai/features/voice/domain/entities/voice_session_state.dart';
import 'package:vision_ai/features/voice/presentation/controllers/voice_controller.dart';

/// Gemini-like translucent floating assistant sheet used by `AssistantOverlayActivity`
/// when triggered via "Hey VISION" wake word or Android's Assist gesture.
class AssistantOverlayScreen extends ConsumerStatefulWidget {
  const AssistantOverlayScreen({super.key});

  @override
  ConsumerState<AssistantOverlayScreen> createState() =>
      _AssistantOverlayScreenState();
}

class _AssistantOverlayScreenState
    extends ConsumerState<AssistantOverlayScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_bootstrapOverlaySession());
    });
  }

  Future<void> _bootstrapOverlaySession() async {
    final notifier = ref.read(voiceControllerProvider.notifier);
    await notifier.checkQueuedOverlayPrompt();
    if (!mounted) return;
    final state = ref.read(voiceControllerProvider);
    if (state.phase == VoiceListeningPhase.idle) {
      await notifier.startCommandListening();
    }
  }

  @override
  Widget build(BuildContext context) {
    final voiceState = ref.watch(voiceControllerProvider);
    final settings = ref.watch(settingsControllerProvider);
    final automationState = ref.watch(automationControllerProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final phaseLabel = switch (voiceState.phase) {
      VoiceListeningPhase.listeningCommand =>
        'Listening (${settings.selectedVoiceLanguage.displayName})...',
      VoiceListeningPhase.processingAi => 'Thinking...',
      VoiceListeningPhase.speaking => 'Speaking...',
      VoiceListeningPhase.error => 'Voice Notice',
      VoiceListeningPhase.requestingPermission => 'Checking Microphone...',
      _ => 'VISION Assistant Ready',
    };

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.45),
      body: SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: VisionCard(
              borderColor: voiceState.isListening
                  ? AppColors.success
                  : colorScheme.primary.withValues(alpha: 0.7),
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        VisionStatusBadge(
                          label: phaseLabel,
                          indicatorColor: voiceState.isListening
                              ? AppColors.success
                              : voiceState.isSpeaking
                              ? AppColors.warning
                              : colorScheme.primary,
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => SystemNavigator.pop(),
                          icon: const Icon(Icons.close_rounded),
                          tooltip: 'Dismiss Assistant',
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Center(
                      child: AssistantOrb(
                        size: 112,
                        isListening: voiceState.isListening,
                        isSpeaking: voiceState.isSpeaking,
                        audioLevel: voiceState.normalizedAmplitude,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (voiceState.liveTranscript.isNotEmpty)
                      Text(
                        '"${voiceState.liveTranscript}"',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium,
                      ),
                    if (voiceState.lastReplyText.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.35,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          voiceState.lastReplyText,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                    if (voiceState.errorMessage != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        voiceState.errorMessage!,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ],
                    if (automationState.pendingConfirmation != null ||
                        automationState.contactChoices.isNotEmpty ||
                        automationState.lastResult?.requiresPermission ==
                            true) ...[
                      const SizedBox(height: 12),
                      AutomationActionPromptCard(
                        automationState: automationState,
                        compact: true,
                        onConfirm: () => unawaited(
                          ref
                              .read(automationControllerProvider.notifier)
                              .confirmPendingAction(),
                        ),
                        onCancel: () => ref
                            .read(automationControllerProvider.notifier)
                            .cancelPendingAction(),
                        onSelectContact: (c) => unawaited(
                          ref
                              .read(automationControllerProvider.notifier)
                              .selectContactForPendingAction(c),
                        ),
                        onGrantPermission: (p) => unawaited(
                          ref
                              .read(automationControllerProvider.notifier)
                              .requestPermission(p),
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        FilledButton.icon(
                          onPressed: () {
                            unawaited(
                              ref
                                  .read(voiceControllerProvider.notifier)
                                  .interruptAndListen(),
                            );
                          },
                          icon: Icon(
                            voiceState.isListening
                                ? Icons.graphic_eq_rounded
                                : Icons.mic_rounded,
                            size: 18,
                          ),
                          label: Text(
                            voiceState.isListening
                                ? 'Listening...'
                                : voiceState.isSpeaking
                                ? 'Interrupt & Speak'
                                : 'Listen Again',
                          ),
                        ),
                        if (voiceState.isSpeaking)
                          OutlinedButton.icon(
                            onPressed: () => unawaited(
                              ref
                                  .read(voiceControllerProvider.notifier)
                                  .stopSpeaking(),
                            ),
                            icon: const Icon(
                              Icons.volume_off_rounded,
                              size: 18,
                            ),
                            label: const Text('Stop Speaking'),
                          ),
                        OutlinedButton.icon(
                          onPressed: () => context.go(AppRoutes.chatPath),
                          icon: const Icon(Icons.open_in_new_rounded, size: 18),
                          label: const Text('Open Full VISION'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
