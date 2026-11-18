import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/app/router/app_routes.dart';
import 'package:vision_ai/core/constants/app_constants.dart';
import 'package:vision_ai/core/widgets/vision_app_bar.dart';
import 'package:vision_ai/core/widgets/vision_card.dart';
import 'package:vision_ai/core/widgets/vision_scaffold.dart';
import 'package:vision_ai/core/widgets/vision_status_badge.dart';
import 'package:vision_ai/features/assistant/domain/entities/assistant_readiness.dart';
import 'package:vision_ai/features/assistant/presentation/controllers/assistant_controller.dart';
import 'package:vision_ai/features/assistant/presentation/widgets/assistant_greeting_header.dart';
import 'package:vision_ai/features/assistant/presentation/widgets/assistant_mic_button.dart';
import 'package:vision_ai/features/assistant/presentation/widgets/assistant_orb.dart';
import 'package:vision_ai/features/assistant/presentation/widgets/assistant_status_panel.dart';
import 'package:vision_ai/features/automation/domain/entities/device_action.dart';
import 'package:vision_ai/features/automation/presentation/controllers/automation_controller.dart';
import 'package:vision_ai/features/automation/presentation/widgets/automation_action_prompt_card.dart';
import 'package:vision_ai/features/settings/domain/entities/app_settings.dart';
import 'package:vision_ai/features/settings/presentation/controllers/settings_controller.dart';
import 'package:vision_ai/features/voice/domain/entities/voice_session_state.dart';
import 'package:vision_ai/features/voice/presentation/controllers/voice_controller.dart';

/// Primary home screen for VISION AI.
class AssistantHomeScreen extends ConsumerWidget {
  const AssistantHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readiness = ref.watch(assistantControllerProvider);
    final settings = ref.watch(settingsControllerProvider);
    final voiceState = ref.watch(voiceControllerProvider);
    final automationState = ref.watch(automationControllerProvider);

    Future<void> handleMicTap() async {
      if (settings.hapticFeedbackEnabled) {
        unawaited(HapticFeedback.lightImpact());
      }
      await ref.read(voiceControllerProvider.notifier).toggleVoiceCapture();
    }

    Future<void> handleWakeWordTap() async {
      if (settings.hapticFeedbackEnabled) {
        unawaited(HapticFeedback.selectionClick());
      }
      final voiceState = ref.read(voiceControllerProvider);
      if (voiceState.isWakeServiceRunning) {
        await ref.read(voiceControllerProvider.notifier).stopWakeWordSession();
      } else {
        await ref.read(voiceControllerProvider.notifier).startWakeWordSession();
      }
    }

    void handleOpenChat() {
      if (settings.hapticFeedbackEnabled) {
        unawaited(HapticFeedback.selectionClick());
      }
      context.push(AppRoutes.chatPath);
    }

    void handleOpenAutomation() {
      if (settings.hapticFeedbackEnabled) {
        unawaited(HapticFeedback.selectionClick());
      }
      context.push(AppRoutes.automationPath);
    }

    void handleDismissNotice() {
      ref.read(assistantControllerProvider.notifier).dismissNotice();
      ref.read(voiceControllerProvider.notifier).dismissError();
    }

    return VisionScaffold(
      appBar: VisionAppBar(
        title: AppConstants.appName,
        actions: [
          IconButton(
            onPressed: handleOpenAutomation,
            icon: const Icon(Icons.phonelink_setup_rounded),
            tooltip: 'Device Control',
          ),
          IconButton(
            onPressed: handleOpenChat,
            icon: const Icon(Icons.forum_outlined),
            tooltip: 'Conversation Module',
          ),
          IconButton(
            onPressed: () => context.push(AppRoutes.settingsPath),
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide =
              constraints.maxWidth >= AppConstants.compactBreakpoint ||
              constraints.maxHeight < 520;

          if (isWide) {
            return _WideHomeLayout(
              readiness: readiness,
              settings: settings,
              voiceState: voiceState,
              automationState: automationState,
              onMicTap: handleMicTap,
              onWakeWordTap: handleWakeWordTap,
              onOpenChat: handleOpenChat,
              onOpenAutomation: handleOpenAutomation,
              onDismissNotice: handleDismissNotice,
            );
          }

          return _CompactHomeLayout(
            readiness: readiness,
            settings: settings,
            voiceState: voiceState,
            automationState: automationState,
            onMicTap: handleMicTap,
            onWakeWordTap: handleWakeWordTap,
            onOpenChat: handleOpenChat,
            onOpenAutomation: handleOpenAutomation,
            onDismissNotice: handleDismissNotice,
          );
        },
      ),
    );
  }
}

class _CompactHomeLayout extends StatelessWidget {
  const _CompactHomeLayout({
    required this.readiness,
    required this.settings,
    required this.voiceState,
    required this.automationState,
    required this.onMicTap,
    required this.onWakeWordTap,
    required this.onOpenChat,
    required this.onOpenAutomation,
    required this.onDismissNotice,
  });

  final AssistantReadiness readiness;
  final AppSettings settings;
  final VoiceSessionState voiceState;
  final AutomationState automationState;
  final VoidCallback onMicTap;
  final VoidCallback onWakeWordTap;
  final VoidCallback onOpenChat;
  final VoidCallback onOpenAutomation;
  final VoidCallback onDismissNotice;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: VisionStatusBadge(label: AppConstants.currentPhaseLabel),
              ),
              const SizedBox(height: 16),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AssistantOrb(
                    isHighlighted:
                        readiness.mode ==
                        AssistantStandbyMode.micPlaceholderNotice,
                    isListening: voiceState.isMicActuallyActive,
                    isSpeaking: voiceState.isSpeaking,
                    audioLevel: voiceState.normalizedAmplitude,
                  ),
                  const SizedBox(height: 24),
                  const AssistantGreetingHeader(),
                ],
              ),
              const SizedBox(height: 20),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AssistantStatusPanel(
                    readiness: readiness,
                    settings: settings,
                    voiceState: voiceState,
                    onDismissNotice: onDismissNotice,
                  ),
                  if (automationState.pendingConfirmation != null ||
                      automationState.contactChoices.isNotEmpty ||
                      automationState.contactSearchResults.isNotEmpty ||
                      (automationState.lastResult?.requiresPermission ==
                          true)) ...[
                    const SizedBox(height: 10),
                    _HomeAutomationPromptWrapper(
                      automationState: automationState,
                    ),
                  ] else if (automationState.lastResult != null) ...[
                    const SizedBox(height: 10),
                    _HomeAutomationBanner(
                      summary: automationState.lastResult!.summary,
                      onOpenControlHub: onOpenAutomation,
                    ),
                  ],
                  const SizedBox(height: 14),
                  _HomeActionButtons(
                    providerName: settings.selectedAiProvider.displayName,
                    onOpenChat: onOpenChat,
                    onOpenAutomation: onOpenAutomation,
                  ),
                  const SizedBox(height: 18),
                  AssistantMicButton(
                    onPressed: onMicTap,
                    onWakeWordTap: onWakeWordTap,
                    isListening: voiceState.isListening,
                    isSpeaking: voiceState.isSpeaking,
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WideHomeLayout extends StatelessWidget {
  const _WideHomeLayout({
    required this.readiness,
    required this.settings,
    required this.voiceState,
    required this.automationState,
    required this.onMicTap,
    required this.onWakeWordTap,
    required this.onOpenChat,
    required this.onOpenAutomation,
    required this.onDismissNotice,
  });

  final AssistantReadiness readiness;
  final AppSettings settings;
  final VoiceSessionState voiceState;
  final AutomationState automationState;
  final VoidCallback onMicTap;
  final VoidCallback onWakeWordTap;
  final VoidCallback onOpenChat;
  final VoidCallback onOpenAutomation;
  final VoidCallback onDismissNotice;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const VisionStatusBadge(
                    label: AppConstants.currentPhaseLabel,
                  ),
                  const SizedBox(height: 16),
                  AssistantOrb(
                    size: 168,
                    isHighlighted:
                        readiness.mode ==
                        AssistantStandbyMode.micPlaceholderNotice,
                    isListening: voiceState.isMicActuallyActive,
                    isSpeaking: voiceState.isSpeaking,
                    audioLevel: voiceState.normalizedAmplitude,
                  ),
                  const SizedBox(height: 16),
                  const AssistantGreetingHeader(),
                ],
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AssistantStatusPanel(
                    readiness: readiness,
                    settings: settings,
                    voiceState: voiceState,
                    onDismissNotice: onDismissNotice,
                  ),
                  if (automationState.pendingConfirmation != null ||
                      automationState.contactChoices.isNotEmpty ||
                      automationState.contactSearchResults.isNotEmpty ||
                      (automationState.lastResult?.requiresPermission ==
                          true)) ...[
                    const SizedBox(height: 10),
                    _HomeAutomationPromptWrapper(
                      automationState: automationState,
                    ),
                  ] else if (automationState.lastResult != null) ...[
                    const SizedBox(height: 10),
                    _HomeAutomationBanner(
                      summary: automationState.lastResult!.summary,
                      onOpenControlHub: onOpenAutomation,
                    ),
                  ],
                  const SizedBox(height: 14),
                  _HomeActionButtons(
                    providerName: settings.selectedAiProvider.displayName,
                    onOpenChat: onOpenChat,
                    onOpenAutomation: onOpenAutomation,
                  ),
                  const SizedBox(height: 18),
                  AssistantMicButton(
                    onPressed: onMicTap,
                    onWakeWordTap: onWakeWordTap,
                    isListening: voiceState.isListening,
                    isSpeaking: voiceState.isSpeaking,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeActionButtons extends StatelessWidget {
  const _HomeActionButtons({
    required this.providerName,
    required this.onOpenChat,
    required this.onOpenAutomation,
  });

  final String providerName;
  final VoidCallback onOpenChat;
  final VoidCallback onOpenAutomation;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onOpenChat,
            icon: const Icon(Icons.forum_outlined, size: 18),
            label: Text(
              'Chat with $providerName',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onOpenAutomation,
            icon: const Icon(Icons.phonelink_setup_rounded, size: 18),
            label: const Text(
              'Device Control & Actions',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
}

class _HomeAutomationPromptWrapper extends ConsumerWidget {
  const _HomeAutomationPromptWrapper({required this.automationState});

  final AutomationState automationState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(automationControllerProvider.notifier);
    return AutomationActionPromptCard(
      automationState: automationState,
      compact: true,
      onConfirm: () => unawaited(controller.confirmPendingAction()),
      onCancel: controller.cancelPendingAction,
      onSelectContact: (contact) =>
          unawaited(controller.selectContactForPendingAction(contact)),
      onGrantPermission: (permission) =>
          unawaited(controller.requestPermission(permission)),
      onCallContact: (contact) => unawaited(
        controller.executeRequest(
          DeviceActionRequest(
            type: DeviceActionType.callPhone,
            target: contact.phoneNumber,
            displaySummary: 'Call ${contact.name}',
          ),
        ),
      ),
      onMessageContact: (contact) => unawaited(
        controller.executeRequest(
          DeviceActionRequest(
            type: DeviceActionType.sendSms,
            target: contact.phoneNumber,
            displaySummary: 'Compose SMS to ${contact.name}',
          ),
        ),
      ),
      onClearSearchResults: controller.clearContactSearchResults,
    );
  }
}

class _HomeAutomationBanner extends StatelessWidget {
  const _HomeAutomationBanner({
    required this.summary,
    required this.onOpenControlHub,
  });

  final String summary;
  final VoidCallback onOpenControlHub;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return VisionCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.bolt_rounded, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              summary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
          TextButton(onPressed: onOpenControlHub, child: const Text('Details')),
        ],
      ),
    );
  }
}
