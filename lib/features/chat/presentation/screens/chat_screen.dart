import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/app/router/app_routes.dart';
import 'package:vision_ai/app/theme/app_colors.dart';
import 'package:vision_ai/core/widgets/vision_app_bar.dart';
import 'package:vision_ai/core/widgets/vision_card.dart';
import 'package:vision_ai/core/widgets/vision_scaffold.dart';
import 'package:vision_ai/core/widgets/vision_status_badge.dart';
import 'package:vision_ai/features/automation/domain/entities/device_action.dart';
import 'package:vision_ai/features/automation/presentation/controllers/automation_controller.dart';
import 'package:vision_ai/features/automation/presentation/widgets/automation_action_prompt_card.dart';
import 'package:vision_ai/features/chat/domain/entities/ai_models.dart';
import 'package:vision_ai/features/chat/presentation/controllers/chat_controller.dart';
import 'package:vision_ai/features/chat/presentation/widgets/chat_input_bar.dart';
import 'package:vision_ai/features/chat/presentation/widgets/chat_message_bubble.dart';
import 'package:vision_ai/features/settings/domain/entities/ai_provider_type.dart';
import 'package:vision_ai/features/settings/presentation/controllers/api_key_controller.dart';
import 'package:vision_ai/features/settings/presentation/controllers/provider_connection_controller.dart';
import 'package:vision_ai/features/settings/presentation/controllers/settings_controller.dart';
import 'package:vision_ai/features/settings/presentation/widgets/api_key_config_dialog.dart';
import 'package:vision_ai/features/voice/presentation/controllers/voice_controller.dart';

/// Live multi-provider AI conversation screen for VISION AI.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

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
    await showDialog<bool>(
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

    return VisionScaffold(
      appBar: VisionAppBar(
        title: 'VISION CHAT',
        subtitle:
            '${activeProvider.displayName} • ${settings.selectedVoiceLanguage.displayName}',
        actions: [
          IconButton(
            onPressed: () => context.push(AppRoutes.automationPath),
            icon: const Icon(Icons.phonelink_setup_rounded),
            tooltip: 'Device Control',
          ),
          if (chatState.messages.isNotEmpty)
            IconButton(
              onPressed: () =>
                  ref.read(chatControllerProvider.notifier).clearConversation(),
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear conversation',
            ),
          IconButton(
            onPressed: () => context.push(AppRoutes.settingsPath),
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Provider Settings',
          ),
        ],
      ),
      body: Column(
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
            onConfigureKey: () => _openKeyDialog(activeProvider, hasActiveKey),
          ),
          if (chatState.routingNotice != null) ...[
            const SizedBox(height: 8),
            VisionCard(
              borderColor: AppColors.warning.withValues(alpha: 0.6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.alt_route_rounded,
                    size: 16,
                    color: AppColors.warning,
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
            const SizedBox(height: 10),
            _ChatErrorBanner(
              message: chatState.errorMessage!,
              missingKeyProvider: chatState.missingKeyProvider,
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
          const SizedBox(height: 8),
          Expanded(
            child: chatState.messages.isEmpty
                ? _EmptyChatView(
                    provider: activeProvider,
                    modelId: activeModelId,
                    hasApiKey: hasActiveKey,
                    onSelectPrompt: (prompt) {
                      _inputController.text = prompt;
                      _inputController.selection = TextSelection.fromPosition(
                        TextPosition(offset: prompt.length),
                      );
                    },
                    onConfigureKey: () =>
                        _openKeyDialog(activeProvider, hasActiveKey),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: chatState.messages.length,
                    itemBuilder: (context, index) {
                      final msg = chatState.messages[index];
                      return ChatMessageBubble(
                        message: msg,
                        isSpeaking: voiceState.isSpeaking,
                        onSpeak: () => ref
                            .read(voiceControllerProvider.notifier)
                            .speakReply(msg.content),
                      );
                    },
                  ),
          ),
          ChatInputBar(
            controller: _inputController,
            isLoading: chatState.isLoading,
            isListening: voiceState.isListening,
            providerName: '${activeProvider.displayName} ($activeModelId)',
            onSend: _handleSend,
            onCancel: () =>
                ref.read(chatControllerProvider.notifier).cancelActiveRequest(),
            onVoiceTap: () =>
                ref.read(voiceControllerProvider.notifier).toggleVoiceCapture(),
          ),
          if (automationState.pendingConfirmation != null ||
              automationState.contactChoices.isNotEmpty ||
              automationState.contactSearchResults.isNotEmpty ||
              (automationState.lastResult?.requiresPermission == true)) ...[
            const SizedBox(height: 10),
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
        ],
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
    final statusLabel = switch (connectionState) {
      ProviderConnectionState.connected => 'Connected',
      ProviderConnectionState.testing => 'Testing...',
      ProviderConnectionState.failed => 'Check Failed',
      ProviderConnectionState.missingKey => 'Add API Key',
      ProviderConnectionState.disabled => 'Disabled',
      ProviderConnectionState.untested =>
        hasApiKey ? 'Key Saved' : 'Add API Key',
    };
    final statusColor = switch (connectionState) {
      ProviderConnectionState.connected => AppColors.success,
      ProviderConnectionState.failed => AppColors.error,
      ProviderConnectionState.testing => AppColors.cyanAccent,
      _ => hasApiKey ? AppColors.cyanAccent : AppColors.warning,
    };

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: PopupMenuButton<AiProviderType>(
            tooltip: 'Switch AI Provider (preserves chat history)',
            onSelected: onSwitchProvider,
            itemBuilder: (context) => [
              for (final p in AiProviderType.values)
                PopupMenuItem<AiProviderType>(
                  value: p,
                  child: Text(p.displayName),
                ),
            ],
            child: VisionStatusBadge(
              label: '${provider.displayName} ($modelId)',
              icon: Icons.hub_outlined,
            ),
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: onConfigureKey,
          borderRadius: BorderRadius.circular(999),
          child: VisionStatusBadge(
            label: statusLabel,
            indicatorColor: statusColor,
          ),
        ),
      ],
    );
  }
}

class _ChatErrorBanner extends StatelessWidget {
  const _ChatErrorBanner({
    required this.message,
    required this.onDismiss,
    this.missingKeyProvider,
    this.onConfigureKey,
  });

  final String message;
  final AiProviderType? missingKeyProvider;
  final VoidCallback? onConfigureKey;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return VisionCard(
      borderColor: AppColors.error.withValues(alpha: 0.7),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.error,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          if (onConfigureKey != null)
            TextButton(onPressed: onConfigureKey, child: const Text('Add Key')),
          IconButton(
            onPressed: onDismiss,
            icon: const Icon(Icons.close_rounded, size: 18),
            visualDensity: VisualDensity.compact,
            tooltip: 'Dismiss error',
          ),
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
    final colorScheme = theme.colorScheme;

    return Center(
      child: SingleChildScrollView(
        child: VisionCard(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                size: 36,
                color: colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                'Ready to Chat with ${provider.displayName}',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                'Model: $modelId',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
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
                FilledButton.icon(
                  onPressed: onConfigureKey,
                  icon: const Icon(Icons.key_rounded, size: 18),
                  label: Text('Configure ${provider.displayName} Key'),
                ),
              ],
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'STARTER PROMPTS',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.primary,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              for (final prompt in _starterPrompts) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => onSelectPrompt(prompt),
                    style: OutlinedButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                    child: Text(
                      prompt,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    ),
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
