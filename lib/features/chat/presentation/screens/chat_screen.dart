import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart' as toolkit;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/app/router/app_routes.dart';
import 'package:vision_ai/core/theme/vision_colors.dart';
import 'package:vision_ai/core/theme/vision_glass.dart';
import 'package:vision_ai/core/theme/vision_radii.dart';
import 'package:vision_ai/core/theme/vision_spacing.dart';
import 'package:vision_ai/core/widgets/glass/vision_glass_widgets.dart';
import 'package:vision_ai/core/widgets/vision_app_bar.dart';
import 'package:vision_ai/core/widgets/vision_loading.dart';
import 'package:vision_ai/core/widgets/vision_scaffold.dart';
import 'package:vision_ai/core/widgets/vision_status_badge.dart';
import 'package:vision_ai/features/automation/domain/entities/device_action.dart';
import 'package:vision_ai/features/automation/presentation/controllers/automation_controller.dart';
import 'package:vision_ai/features/automation/presentation/widgets/automation_action_prompt_card.dart';
import 'package:vision_ai/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:vision_ai/features/chat/domain/entities/ai_models.dart';
import 'package:vision_ai/features/chat/domain/entities/chat_message.dart';
import 'package:vision_ai/features/chat/domain/services/vision_llm_provider.dart';
import 'package:vision_ai/features/chat/presentation/controllers/chat_controller.dart';
import 'package:vision_ai/features/chat/presentation/widgets/chat_input_bar.dart';
import 'package:vision_ai/features/chat/presentation/widgets/chat_message_bubble.dart';
import 'package:vision_ai/features/settings/domain/entities/ai_provider_type.dart';
import 'package:vision_ai/features/settings/presentation/controllers/api_key_controller.dart';
import 'package:vision_ai/features/settings/presentation/controllers/provider_connection_controller.dart';
import 'package:vision_ai/features/settings/presentation/controllers/settings_controller.dart';
import 'package:vision_ai/features/settings/presentation/widgets/api_key_config_dialog.dart';
import 'package:vision_ai/features/vision/domain/services/visual_intelligence_service.dart';
import 'package:vision_ai/features/voice/presentation/controllers/voice_controller.dart';

/// Live multi-provider AI conversation screen with Liquid Glass UI.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _useToolkitView = false;
  VisionLlmProvider? _toolkitProvider;

  VisionLlmProvider _getOrCreateToolkitProvider() {
    return _toolkitProvider ??= VisionLlmProvider(
      router: ref.read(aiRouterProvider),
      settingsReader: () => ref.read(settingsControllerProvider),
    );
  }

  Future<void> _handleCapturePhoto() async {
    final attachment = await ref
        .read(visualIntelligenceServiceProvider)
        .capturePhoto();
    if (attachment != null && mounted) {
      ref.read(chatControllerProvider.notifier).setPendingImage(attachment);
    }
  }

  Future<void> _handlePickGallery() async {
    final attachment = await ref
        .read(visualIntelligenceServiceProvider)
        .pickFromGallery();
    if (attachment != null && mounted) {
      ref.read(chatControllerProvider.notifier).setPendingImage(attachment);
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleSend([String? presetPrompt]) async {
    final text = presetPrompt ?? _inputController.text;
    if (text.trim().isEmpty) return;

    final settings = ref.read(settingsControllerProvider);
    if (settings.hapticFeedbackEnabled) {
      await HapticFeedback.lightImpact();
    }

    final accepted = await ref
        .read(chatControllerProvider.notifier)
        .sendMessage(text);
    if (accepted && presetPrompt == null) {
      _inputController.clear();
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _openKeyDialog(AiProviderType provider, bool hasKey) async {
    await showVisionGlassDialog<bool>(
      context: context,
      builder: (dialogContext) => ApiKeyConfigDialog(
        provider: provider,
        hasExistingKey: hasKey,
        onSave: (apiKey) async {
          await ref
              .read(apiKeyStatusControllerProvider.notifier)
              .saveApiKey(provider: provider, apiKey: apiKey);
          ref
              .read(providerConnectionControllerProvider.notifier)
              .invalidateProvider(provider);
          ref.read(chatControllerProvider.notifier).dismissError();
        },
        onRemove: () async {
          await ref
              .read(apiKeyStatusControllerProvider.notifier)
              .removeApiKey(provider);
          ref
              .read(providerConnectionControllerProvider.notifier)
              .invalidateProvider(provider);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatControllerProvider);
    final settings = ref.watch(settingsControllerProvider);
    final voiceState = ref.watch(voiceControllerProvider);
    final automationState = ref.watch(automationControllerProvider);
    final connectionMap = ref.watch(providerConnectionControllerProvider);
    final keyStatusAsync = ref.watch(apiKeyStatusControllerProvider);
    final keyMap =
        keyStatusAsync.asData?.value ?? const <AiProviderType, bool>{};
    final activeProvider = settings.selectedAiProvider;
    final activeModelId = settings.modelForProvider(activeProvider);
    final hasActiveKey = keyMap[activeProvider] ?? false;
    final runtimeStatus = connectionMap[activeProvider];
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 80;

    final waitingForFirstToken =
        chatState.isLoading &&
        (chatState.messages.isEmpty ||
            chatState.messages.last.sender == MessageSender.user);

    final lastAssistantIndex = chatState.messages.lastIndexWhere(
      (m) => m.sender == MessageSender.assistant,
    );

    return VisionScaffold(
      useSafeAreaBottom: false,
      appBar: VisionAppBar(
        title: 'VISION CHAT',
        subtitle:
            '${activeProvider.displayName} • ${settings.selectedVoiceLanguage.displayName}',
        actions: [
          IconButton(
            onPressed: () => context.push(AppRoutes.helpPath),
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: 'Help & User Guide',
          ),
          IconButton(
            onPressed: () => setState(() => _useToolkitView = !_useToolkitView),
            icon: Icon(
              _useToolkitView
                  ? Icons.chat_bubble_outline_rounded
                  : Icons.widgets_outlined,
            ),
            tooltip: _useToolkitView
                ? 'Switch to VISION Liquid Glass Chat'
                : 'Switch to Flutter AI Toolkit View',
          ),
          IconButton(
            onPressed: () => context.push(AppRoutes.assistantPath),
            icon: const Icon(Icons.auto_awesome_outlined),
            tooltip: 'Voice Assistant Mode',
          ),
          if (chatState.messages.isNotEmpty)
            IconButton(
              onPressed: () =>
                  ref.read(chatControllerProvider.notifier).clearConversation(),
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear conversation',
            ),
          IconButton(
            onPressed: () => context.go(AppRoutes.settingsPath),
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Provider Settings',
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: true,
        child: Column(
          children: [
            _ProviderStatusBar(
              provider: activeProvider,
              modelId: activeModelId,
              hasApiKey: hasActiveKey,
              connectionState:
                  runtimeStatus?.connectionState ??
                  ProviderConnectionState.untested,
              onSwitchProvider: (selected) {
                unawaited(
                  ref
                      .read(settingsControllerProvider.notifier)
                      .setAiProvider(selected),
                );
              },
              onConfigureKey: () =>
                  _openKeyDialog(activeProvider, hasActiveKey),
            ),
            if (chatState.routingNotice != null) ...[
              const SizedBox(height: 8),
              VisionGlassCard(
                variant: VisionGlassVariant.subtle,
                borderColor: VisionColors.warning.withValues(alpha: 0.55),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.alt_route_rounded,
                      size: 16,
                      color: VisionColors.warning,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        chatState.routingNotice!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (chatState.errorMessage != null) ...[
              const SizedBox(height: 8),
              _ChatErrorBanner(
                message: chatState.errorMessage!,
                missingKeyProvider: chatState.missingKeyProvider,
                canRetry:
                    chatState.unsentDraft != null ||
                    chatState.messages.any(
                      (m) => m.sender == MessageSender.user,
                    ),
                onRetry: () {
                  unawaited(
                    ref.read(chatControllerProvider.notifier).retryLastPrompt(),
                  );
                },
                onConfigureKey: chatState.missingKeyProvider != null
                    ? () => _openKeyDialog(
                        chatState.missingKeyProvider!,
                        keyMap[chatState.missingKeyProvider!] ?? false,
                      )
                    : null,
                onDismiss: () =>
                    ref.read(chatControllerProvider.notifier).dismissError(),
              ),
            ],
            const SizedBox(height: 6),
            if (_useToolkitView)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(
                    bottom: VisionSpacing.navBarClearance,
                  ),
                  child: toolkit.LlmChatView(
                    provider: _getOrCreateToolkitProvider(),
                    welcomeMessage:
                        'VISION AI Toolkit Mode (${activeProvider.displayName}). '
                        'Send text or attach photos to stream replies.',
                  ),
                ),
              )
            else ...[
              Expanded(
                child: chatState.messages.isEmpty
                    ? _EmptyChatView(
                        provider: activeProvider,
                        modelId: activeModelId,
                        hasApiKey: hasActiveKey,
                        onSelectPrompt: (prompt) {
                          _inputController.text = prompt;
                          _inputController.selection =
                              TextSelection.fromPosition(
                                TextPosition(offset: prompt.length),
                              );
                        },
                        onConfigureKey: () =>
                            _openKeyDialog(activeProvider, hasActiveKey),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount:
                            chatState.messages.length +
                            (waitingForFirstToken ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (waitingForFirstToken &&
                              index == chatState.messages.length) {
                            return _ThinkingShimmerBubble(
                              providerName: activeProvider.displayName,
                            );
                          }
                          final msg = chatState.messages[index];
                          final isLastAssistant = index == lastAssistantIndex;
                          return ChatMessageBubble(
                            message: msg,
                            isSpeaking: voiceState.isSpeaking,
                            isStreaming:
                                chatState.isLoading &&
                                isLastAssistant &&
                                !waitingForFirstToken,
                            onSpeak: () => ref
                                .read(voiceControllerProvider.notifier)
                                .speakReply(msg.content),
                            onCitationTap: (url) => unawaited(
                              ref
                                  .read(automationControllerProvider.notifier)
                                  .executeRequest(
                                    DeviceActionRequest(
                                      type: DeviceActionType.openUrl,
                                      target: url,
                                      displaySummary: 'Open research source',
                                    ),
                                  ),
                            ),
                            onRegenerate:
                                (isLastAssistant && !chatState.isLoading)
                                ? () => unawaited(
                                    ref
                                        .read(chatControllerProvider.notifier)
                                        .regenerateLastResponse(),
                                  )
                                : null,
                          );
                        },
                      ),
              ),
              if (automationState.pendingConfirmation != null ||
                  automationState.contactChoices.isNotEmpty ||
                  automationState.contactSearchResults.isNotEmpty ||
                  (automationState.lastResult?.requiresPermission == true)) ...[
                const SizedBox(height: 8),
                AutomationActionPromptCard(
                  automationState: automationState,
                  compact: true,
                  onConfirm: () => unawaited(
                    ref
                        .read(automationControllerProvider.notifier)
                        .confirmPendingAction(),
                  ),
                  onConfirmAndSaveAlias: () => unawaited(
                    ref
                        .read(automationControllerProvider.notifier)
                        .confirmPendingAction(saveAsAlias: true),
                  ),
                  onCancel: () => ref
                      .read(automationControllerProvider.notifier)
                      .cancelPendingAction(),
                  onSelectContact: (contact) => unawaited(
                    ref
                        .read(automationControllerProvider.notifier)
                        .selectContactForPendingAction(contact),
                  ),
                  onGrantPermission: (permission) => unawaited(
                    ref
                        .read(automationControllerProvider.notifier)
                        .requestPermission(permission),
                  ),
                  onCallContact: (contact) => unawaited(
                    ref
                        .read(automationControllerProvider.notifier)
                        .executeRequest(
                          DeviceActionRequest(
                            type: DeviceActionType.callPhone,
                            target: contact.phoneNumber,
                            displaySummary: 'Call ${contact.name}',
                          ),
                        ),
                  ),
                  onMessageContact: (contact) => unawaited(
                    ref
                        .read(automationControllerProvider.notifier)
                        .executeRequest(
                          DeviceActionRequest(
                            type: DeviceActionType.sendSms,
                            target: contact.phoneNumber,
                            displaySummary: 'Compose SMS to ${contact.name}',
                          ),
                        ),
                  ),
                  onClearSearchResults: () => ref
                      .read(automationControllerProvider.notifier)
                      .clearContactSearchResults(),
                ),
              ],
              const SizedBox(height: 6),
              Padding(
                padding: EdgeInsets.only(
                  bottom: keyboardOpen ? 6 : VisionSpacing.navBarClearance - 14,
                ),
                child: ChatInputBar(
                  controller: _inputController,
                  isLoading: chatState.isLoading,
                  isListening: voiceState.isListening,
                  webResearchEnabled: chatState.webResearchEnabled,
                  pendingImage: chatState.pendingImage,
                  providerName: activeProvider.displayName,
                  onSend: _handleSend,
                  onCancel: () => ref
                      .read(chatControllerProvider.notifier)
                      .cancelActiveRequest(),
                  onVoiceTap: () => ref
                      .read(voiceControllerProvider.notifier)
                      .toggleVoiceCapture(),
                  onCameraTap: _handleCapturePhoto,
                  onGalleryTap: _handlePickGallery,
                  onClearImage: () => ref
                      .read(chatControllerProvider.notifier)
                      .clearPendingImage(),
                  onExtractOcr: () => ref
                      .read(chatControllerProvider.notifier)
                      .extractTextFromPendingImage(),
                  onToggleWebResearch: () => ref
                      .read(chatControllerProvider.notifier)
                      .toggleWebResearch(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProviderStatusBar extends StatelessWidget {
  const _ProviderStatusBar({
    required this.provider,
    required this.modelId,
    required this.hasApiKey,
    required this.connectionState,
    required this.onSwitchProvider,
    required this.onConfigureKey,
  });

  final AiProviderType provider;
  final String modelId;
  final bool hasApiKey;
  final ProviderConnectionState connectionState;
  final ValueChanged<AiProviderType> onSwitchProvider;
  final VoidCallback onConfigureKey;

  @override
  Widget build(BuildContext context) {
    final statusLabel = !provider.requiresApiKey
        ? 'On-Device'
        : switch (connectionState) {
            ProviderConnectionState.connected => 'Connected',
            ProviderConnectionState.testing => 'Testing...',
            ProviderConnectionState.failed => 'Check Failed',
            ProviderConnectionState.missingKey => 'Add API Key',
            ProviderConnectionState.disabled => 'Disabled',
            ProviderConnectionState.untested =>
              hasApiKey ? 'Key Saved' : 'Add API Key',
          };
    final statusColor = switch (connectionState) {
      ProviderConnectionState.connected => VisionColors.success,
      ProviderConnectionState.failed => VisionColors.error,
      ProviderConnectionState.testing => VisionColors.accentPrimary,
      _ => hasApiKey ? VisionColors.accentPrimary : VisionColors.warning,
    };

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: VisionGlassPopup<AiProviderType>(
            tooltip: 'Switch AI Provider (preserves chat history)',
            onSelected: onSwitchProvider,
            items: [
              for (final p in AiProviderType.values)
                PopupMenuItem<AiProviderType>(
                  value: p,
                  child: Row(
                    children: [
                      Icon(
                        p == provider
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_off_rounded,
                        size: 16,
                        color: p == provider
                            ? VisionColors.accentPrimary
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Text(p.displayName),
                    ],
                  ),
                ),
            ],
            child: VisionStatusBadge(
              label: '${provider.displayName} • $modelId',
              icon: Icons.hub_outlined,
            ),
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: onConfigureKey,
          borderRadius: VisionRadii.pillBorder,
          child: VisionStatusBadge(
            label: statusLabel,
            indicatorColor: statusColor,
          ),
        ),
      ],
    );
  }
}

class _ThinkingShimmerBubble extends StatelessWidget {
  const _ThinkingShimmerBubble({required this.providerName});

  final String providerName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(16),
          decoration: VisionGlass.decoration(
            brightness,
            variant: VisionGlassVariant.standard,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(VisionRadii.lg),
              topRight: Radius.circular(VisionRadii.lg),
              bottomRight: Radius.circular(VisionRadii.lg),
              bottomLeft: Radius.circular(VisionRadii.xs),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 14,
                    color: VisionColors.primaryAccent(brightness),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '$providerName is thinking...',
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: VisionColors.primaryAccent(brightness),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              VisionLoading(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Generating assistant response details',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Preparing structured reply',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatErrorBanner extends StatelessWidget {
  const _ChatErrorBanner({
    required this.message,
    required this.onDismiss,
    required this.canRetry,
    required this.onRetry,
    this.missingKeyProvider,
    this.onConfigureKey,
  });

  final String message;
  final AiProviderType? missingKeyProvider;
  final VoidCallback? onConfigureKey;
  final bool canRetry;
  final VoidCallback onRetry;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;

    return VisionGlassContainer(
      variant: VisionGlassVariant.standard,
      borderColor: VisionColors.error.withValues(alpha: 0.7),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: VisionColors.error,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: VisionColors.primaryText(brightness),
                  ),
                ),
              ),
              IconButton(
                onPressed: onDismiss,
                icon: const Icon(Icons.close_rounded, size: 18),
                visualDensity: VisualDensity.compact,
                tooltip: 'Dismiss error',
              ),
            ],
          ),
          if (onConfigureKey != null || canRetry) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (onConfigureKey != null)
                  VisionGlassButton(
                    label: 'Add Key',
                    icon: Icons.key_rounded,
                    compact: true,
                    style: VisionGlassButtonStyle.tonal,
                    onPressed: onConfigureKey,
                  ),
                if (canRetry)
                  VisionGlassButton(
                    label: 'Retry',
                    icon: Icons.refresh_rounded,
                    compact: true,
                    style: VisionGlassButtonStyle.glass,
                    onPressed: onRetry,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyChatView extends StatelessWidget {
  const _EmptyChatView({
    required this.provider,
    required this.modelId,
    required this.hasApiKey,
    required this.onSelectPrompt,
    required this.onConfigureKey,
  });

  final AiProviderType provider;
  final String modelId;
  final bool hasApiKey;
  final ValueChanged<String> onSelectPrompt;
  final VoidCallback onConfigureKey;

  static const List<String> _starterPrompts = <String>[
    'Plan a focused morning routine for high productivity.',
    'Explain how Android Keystore hardware encryption works.',
    'Translate "Hello, how can I help you today?" into Hindi and Gujarati.',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final accent = VisionColors.primaryAccent(brightness);

    return Center(
      child: SingleChildScrollView(
        child: VisionGlassCard(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: VisionColors.brandGradient,
                  boxShadow: [
                    BoxShadow(
                      color: VisionColors.accentPrimary.withValues(alpha: 0.35),
                      blurRadius: 18,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  size: 26,
                  color: VisionColors.backgroundPrimary,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Ready to Chat with ${provider.displayName}',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              VisionStatusBadge(
                label: 'Model: $modelId',
                indicatorColor: accent,
                compact: true,
              ),
              const SizedBox(height: 10),
              Text(
                hasApiKey
                    ? 'Your encrypted ${provider.displayName} API key is loaded. '
                          'Send a message below or tap a starter prompt.'
                    : 'Configure your personal ${provider.displayName} API key in '
                          'Android Keystore to begin live AI conversations.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              if (!hasApiKey) ...[
                const SizedBox(height: 16),
                VisionGlassButton(
                  onPressed: onConfigureKey,
                  icon: Icons.key_rounded,
                  label: 'Configure ${provider.displayName} Key',
                ),
              ],
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'STARTER PROMPTS',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: accent,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              for (final prompt in _starterPrompts) ...[
                VisionGlassCard(
                  variant: VisionGlassVariant.subtle,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  onTap: () => onSelectPrompt(prompt),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          prompt,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: VisionColors.primaryText(brightness),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.north_west_rounded, size: 15, color: accent),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
