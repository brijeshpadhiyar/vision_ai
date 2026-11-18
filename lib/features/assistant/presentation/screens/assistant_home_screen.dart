import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/app/router/app_routes.dart';
import 'package:vision_ai/core/constants/app_constants.dart';
import 'package:vision_ai/core/theme/vision_colors.dart';
import 'package:vision_ai/core/theme/vision_glass.dart';
import 'package:vision_ai/core/theme/vision_spacing.dart';
import 'package:vision_ai/core/widgets/glass/vision_glass_widgets.dart';
import 'package:vision_ai/core/widgets/vision_app_bar.dart';
import 'package:vision_ai/core/widgets/vision_brand_logo.dart';
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
import 'package:vision_ai/features/chat/domain/entities/ai_models.dart';
import 'package:vision_ai/features/chat/domain/entities/chat_message.dart';
import 'package:vision_ai/features/chat/presentation/controllers/chat_controller.dart';
import 'package:vision_ai/features/settings/domain/entities/ai_provider_type.dart';
import 'package:vision_ai/features/settings/domain/entities/app_settings.dart';
import 'package:vision_ai/features/settings/presentation/controllers/api_key_controller.dart';
import 'package:vision_ai/features/settings/presentation/controllers/provider_connection_controller.dart';
import 'package:vision_ai/features/settings/presentation/controllers/settings_controller.dart';
import 'package:vision_ai/features/voice/domain/entities/voice_session_state.dart';
import 'package:vision_ai/features/voice/presentation/controllers/voice_controller.dart';

/// Primary Liquid Glass dashboard for VISION AI.
class AssistantHomeScreen extends ConsumerWidget {
  const AssistantHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readiness = ref.watch(assistantControllerProvider);
    final settings = ref.watch(settingsControllerProvider);
    final voiceState = ref.watch(voiceControllerProvider);
    final chatState = ref.watch(chatControllerProvider);
    final automationState = ref.watch(automationControllerProvider);
    final connectionMap = ref.watch(providerConnectionControllerProvider);
    final keyMap =
        ref.watch(apiKeyStatusControllerProvider).asData?.value ??
        const <AiProviderType, bool>{};

    final activeProvider = settings.selectedAiProvider;
    final hasActiveKey = keyMap[activeProvider] ?? false;
    final connectionState =
        connectionMap[activeProvider]?.connectionState ??
        ProviderConnectionState.untested;

    void haptic() {
      if (settings.hapticFeedbackEnabled) {
        unawaited(HapticFeedback.selectionClick());
      }
    }

    Future<void> handleMicTap() async {
      if (settings.hapticFeedbackEnabled) {
        unawaited(HapticFeedback.lightImpact());
      }
      await ref.read(voiceControllerProvider.notifier).toggleVoiceCapture();
      if (context.mounted) {
        unawaited(context.push(AppRoutes.assistantPath));
      }
    }

    void handleOpenAssistant() {
      haptic();
      unawaited(context.push(AppRoutes.assistantPath));
    }

    Future<void> handleWakeWordTap() async {
      haptic();
      final currentVoice = ref.read(voiceControllerProvider);
      if (currentVoice.isWakeServiceRunning) {
        await ref.read(voiceControllerProvider.notifier).stopWakeWordSession();
      } else {
        await ref.read(voiceControllerProvider.notifier).startWakeWordSession();
      }
    }

    void handleOpenChat() {
      haptic();
      context.go(AppRoutes.chatPath);
    }

    void handleOpenAutomation() {
      haptic();
      context.go(AppRoutes.automationPath);
    }

    void handleOpenSettings() {
      haptic();
      context.go(AppRoutes.settingsPath);
    }

    void handleDismissNotice() {
      ref.read(assistantControllerProvider.notifier).dismissNotice();
      ref.read(voiceControllerProvider.notifier).dismissError();
    }

    return VisionScaffold(
      appBar: VisionAppBar(
        centerTitle: false,
        title: AppConstants.appName,
        titleWidget: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const VisionBrandLogo(size: 30, showAmbientGlow: false),
            const SizedBox(width: 10),
            Text(
              AppConstants.appName,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(letterSpacing: 3.2, fontWeight: FontWeight.w700),
            ),
          ],
        ),
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
            onPressed: handleOpenSettings,
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
              chatState: chatState,
              automationState: automationState,
              connectionState: connectionState,
              hasActiveKey: hasActiveKey,
              onOrbTap: handleOpenAssistant,
              onMicTap: handleMicTap,
              onWakeWordTap: handleWakeWordTap,
              onOpenChat: handleOpenChat,
              onOpenAutomation: handleOpenAutomation,
              onOpenSettings: handleOpenSettings,
              onOpenRoadmap: () {
                haptic();
                unawaited(context.push(AppRoutes.onboardingPath));
              },
              onDismissNotice: handleDismissNotice,
            );
          }

          return _CompactHomeLayout(
            readiness: readiness,
            settings: settings,
            voiceState: voiceState,
            chatState: chatState,
            automationState: automationState,
            connectionState: connectionState,
            hasActiveKey: hasActiveKey,
            onOrbTap: handleOpenAssistant,
            onMicTap: handleMicTap,
            onWakeWordTap: handleWakeWordTap,
            onOpenChat: handleOpenChat,
            onOpenAutomation: handleOpenAutomation,
            onOpenSettings: handleOpenSettings,
            onOpenRoadmap: () {
              haptic();
              unawaited(context.push(AppRoutes.onboardingPath));
            },
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
    required this.chatState,
    required this.automationState,
    required this.connectionState,
    required this.hasActiveKey,
    required this.onOrbTap,
    required this.onMicTap,
    required this.onWakeWordTap,
    required this.onOpenChat,
    required this.onOpenAutomation,
    required this.onOpenSettings,
    required this.onOpenRoadmap,
    required this.onDismissNotice,
  });

  final AssistantReadiness readiness;
  final AppSettings settings;
  final VoiceSessionState voiceState;
  final ChatState chatState;
  final AutomationState automationState;
  final ProviderConnectionState connectionState;
  final bool hasActiveKey;
  final VoidCallback onOrbTap;
  final VoidCallback onMicTap;
  final VoidCallback onWakeWordTap;
  final VoidCallback onOpenChat;
  final VoidCallback onOpenAutomation;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenRoadmap;
  final VoidCallback onDismissNotice;

  @override
  Widget build(BuildContext context) {
    final isThinking =
        voiceState.phase == VoiceListeningPhase.processingAi ||
        chatState.isLoading;

    return ListView(
      padding: const EdgeInsets.only(
        top: 6,
        bottom: VisionSpacing.navBarClearance,
      ),
      children: [
        Center(
          child: VisionStatusBadge(
            label: voiceState.isListening
                ? 'Listening...'
                : isThinking
                ? 'Thinking...'
                : voiceState.isSpeaking
                ? 'Speaking...'
                : 'AI Standby • ${settings.selectedAiProvider.displayName}',
            indicatorColor: voiceState.isListening
                ? VisionColors.success
                : voiceState.errorMessage != null
                ? VisionColors.error
                : VisionColors.accentPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: AssistantOrb(
            size: 176,
            isHighlighted:
                readiness.mode == AssistantStandbyMode.micPlaceholderNotice,
            isListening: voiceState.isMicActuallyActive,
            isThinking: isThinking,
            isSpeaking: voiceState.isSpeaking,
            hasError: voiceState.errorMessage != null,
            audioLevel: voiceState.normalizedAmplitude,
            onTap: onOrbTap,
          ),
        ),
        const SizedBox(height: 10),
        const AssistantGreetingHeader(),
        const SizedBox(height: 14),
        Center(
          child: AssistantMicButton(
            onPressed: onMicTap,
            onWakeWordTap: onWakeWordTap,
            isListening: voiceState.isListening,
            isSpeaking: voiceState.isSpeaking,
            isWakeActive: voiceState.isWakeServiceRunning,
          ),
        ),
        const SizedBox(height: 18),
        _QuickActionsRow(
          onAssistant: onOrbTap,
          onChat: onOpenChat,
          onAutomation: onOpenAutomation,
          onSettings: onOpenSettings,
          onRoadmap: onOpenRoadmap,
        ),
        const SizedBox(height: 16),
        AssistantStatusPanel(
          readiness: readiness,
          settings: settings,
          voiceState: voiceState,
          connectionState: connectionState,
          hasApiKey: hasActiveKey,
          onDismissNotice: onDismissNotice,
          onTapProviderStatus: onOpenSettings,
        ),
        if (automationState.pendingConfirmation != null ||
            automationState.contactChoices.isNotEmpty ||
            automationState.contactSearchResults.isNotEmpty ||
            (automationState.lastResult?.requiresPermission == true)) ...[
          const SizedBox(height: 12),
          _HomeAutomationPromptWrapper(automationState: automationState),
        ],
        const SizedBox(height: 12),
        _RecentConversationsCard(
          messages: chatState.messages,
          onOpenChat: onOpenChat,
        ),
        const SizedBox(height: 12),
        _RecentAutomationCard(
          entries: automationState.recentActions,
          onOpenAutomation: onOpenAutomation,
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
    required this.chatState,
    required this.automationState,
    required this.connectionState,
    required this.hasActiveKey,
    required this.onOrbTap,
    required this.onMicTap,
    required this.onWakeWordTap,
    required this.onOpenChat,
    required this.onOpenAutomation,
    required this.onOpenSettings,
    required this.onOpenRoadmap,
    required this.onDismissNotice,
  });

  final AssistantReadiness readiness;
  final AppSettings settings;
  final VoiceSessionState voiceState;
  final ChatState chatState;
  final AutomationState automationState;
  final ProviderConnectionState connectionState;
  final bool hasActiveKey;
  final VoidCallback onOrbTap;
  final VoidCallback onMicTap;
  final VoidCallback onWakeWordTap;
  final VoidCallback onOpenChat;
  final VoidCallback onOpenAutomation;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenRoadmap;
  final VoidCallback onDismissNotice;

  @override
  Widget build(BuildContext context) {
    final isThinking =
        voiceState.phase == VoiceListeningPhase.processingAi ||
        chatState.isLoading;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(
        top: 6,
        bottom: VisionSpacing.navBarClearance,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                VisionStatusBadge(
                  label:
                      'AI Standby • ${settings.selectedAiProvider.displayName}',
                ),
                const SizedBox(height: 14),
                AssistantOrb(
                  size: 168,
                  isListening: voiceState.isMicActuallyActive,
                  isThinking: isThinking,
                  isSpeaking: voiceState.isSpeaking,
                  hasError: voiceState.errorMessage != null,
                  audioLevel: voiceState.normalizedAmplitude,
                  onTap: onOrbTap,
                ),
                const SizedBox(height: 14),
                const AssistantGreetingHeader(),
                const SizedBox(height: 14),
                AssistantMicButton(
                  onPressed: onMicTap,
                  onWakeWordTap: onWakeWordTap,
                  isListening: voiceState.isListening,
                  isSpeaking: voiceState.isSpeaking,
                  isWakeActive: voiceState.isWakeServiceRunning,
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _QuickActionsRow(
                  onAssistant: onOrbTap,
                  onChat: onOpenChat,
                  onAutomation: onOpenAutomation,
                  onSettings: onOpenSettings,
                  onRoadmap: onOpenRoadmap,
                ),
                const SizedBox(height: 12),
                AssistantStatusPanel(
                  readiness: readiness,
                  settings: settings,
                  voiceState: voiceState,
                  connectionState: connectionState,
                  hasApiKey: hasActiveKey,
                  onDismissNotice: onDismissNotice,
                  onTapProviderStatus: onOpenSettings,
                ),
                if (automationState.pendingConfirmation != null ||
                    automationState.contactChoices.isNotEmpty ||
                    automationState.contactSearchResults.isNotEmpty ||
                    (automationState.lastResult?.requiresPermission ==
                        true)) ...[
                  const SizedBox(height: 12),
                  _HomeAutomationPromptWrapper(
                    automationState: automationState,
                  ),
                ],
                const SizedBox(height: 12),
                _RecentConversationsCard(
                  messages: chatState.messages,
                  onOpenChat: onOpenChat,
                ),
                const SizedBox(height: 12),
                _RecentAutomationCard(
                  entries: automationState.recentActions,
                  onOpenAutomation: onOpenAutomation,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow({
    required this.onAssistant,
    required this.onChat,
    required this.onAutomation,
    required this.onSettings,
    required this.onRoadmap,
  });

  final VoidCallback onAssistant;
  final VoidCallback onChat;
  final VoidCallback onAutomation;
  final VoidCallback onSettings;
  final VoidCallback onRoadmap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          VisionGlassChip(
            icon: Icons.auto_awesome_rounded,
            label: 'Voice Assistant',
            selected: true,
            onTap: onAssistant,
          ),
          const SizedBox(width: 8),
          VisionGlassChip(
            icon: Icons.forum_outlined,
            label: 'AI Chat',
            onTap: onChat,
          ),
          const SizedBox(width: 8),
          VisionGlassChip(
            icon: Icons.bolt_rounded,
            label: 'Device Control',
            onTap: onAutomation,
          ),
          const SizedBox(width: 8),
          VisionGlassChip(
            icon: Icons.timeline_rounded,
            label: 'Roadmap',
            onTap: onRoadmap,
          ),
          const SizedBox(width: 8),
          VisionGlassChip(
            icon: Icons.tune_rounded,
            label: 'Providers',
            onTap: onSettings,
          ),
        ],
      ),
    );
  }
}

class _RecentConversationsCard extends StatelessWidget {
  const _RecentConversationsCard({
    required this.messages,
    required this.onOpenChat,
  });

  final List<ChatMessage> messages;
  final VoidCallback onOpenChat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final accent = VisionColors.primaryAccent(brightness);
    final preview = messages.reversed.take(2).toList(growable: false);

    return VisionGlassCard(
      onTap: onOpenChat,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.forum_outlined, size: 17, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Recent Conversations',
                  style: theme.textTheme.titleSmall,
                ),
              ),
              Text(
                messages.isEmpty ? 'Start' : 'Open (${messages.length})',
                style: theme.textTheme.labelMedium?.copyWith(color: accent),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, size: 18, color: accent),
            ],
          ),
          const SizedBox(height: 10),
          if (preview.isEmpty)
            Text(
              'No messages yet. Ask VISION anything via voice or chat.',
              style: theme.textTheme.bodySmall,
            )
          else
            for (final msg in preview)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 5),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: msg.sender == MessageSender.user
                            ? VisionColors.accentSecondary
                            : accent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${msg.sender == MessageSender.user ? 'You' : 'VISION'}: ${msg.content}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: VisionColors.primaryText(brightness),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _RecentAutomationCard extends StatelessWidget {
  const _RecentAutomationCard({
    required this.entries,
    required this.onOpenAutomation,
  });

  final List<AutomationExecutionEntry> entries;
  final VoidCallback onOpenAutomation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final accent = VisionColors.primaryAccent(brightness);

    return VisionGlassCard(
      variant: VisionGlassVariant.subtle,
      onTap: onOpenAutomation,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt_rounded, size: 17, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Recent Automation Activity',
                  style: theme.textTheme.titleSmall,
                ),
              ),
              Text(
                'Control Hub',
                style: theme.textTheme.labelMedium?.copyWith(color: accent),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, size: 18, color: accent),
            ],
          ),
          const SizedBox(height: 10),
          if (entries.isEmpty)
            Text(
              'No device actions triggered this session. Try alarms, timers, apps, or system settings.',
              style: theme.textTheme.bodySmall,
            )
          else
            for (final entry in entries.take(2))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(
                      entry.result.success
                          ? Icons.check_circle_outline_rounded
                          : Icons.error_outline_rounded,
                      size: 15,
                      color: entry.result.success
                          ? VisionColors.success
                          : VisionColors.warning,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        entry.result.summary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: VisionColors.primaryText(brightness),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
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
