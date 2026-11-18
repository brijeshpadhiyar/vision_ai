import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/errors/app_exception.dart';
import 'package:vision_ai/core/errors/error_handler.dart';
import 'package:vision_ai/core/utils/app_logger.dart';
import 'package:vision_ai/core/utils/secret_redactor.dart';
import 'package:vision_ai/features/automation/domain/utils/device_intent_parser.dart';
import 'package:vision_ai/features/automation/presentation/controllers/automation_controller.dart';
import 'package:vision_ai/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:vision_ai/features/chat/domain/entities/ai_models.dart';
import 'package:vision_ai/features/chat/domain/entities/chat_message.dart';
import 'package:vision_ai/features/chat/domain/repositories/chat_repository.dart';
import 'package:vision_ai/features/settings/domain/entities/ai_provider_type.dart';
import 'package:vision_ai/features/settings/presentation/controllers/settings_controller.dart';

/// Immutable presentation state for the VISION conversation screen.
@immutable
class ChatState {
  const ChatState({
    this.messages = const <ChatMessage>[],
    this.isLoading = false,
    this.isOfflineError = false,
    this.errorMessage,
    this.routingNotice,
    this.missingKeyProvider,
    this.unsentDraft,
  });

  final List<ChatMessage> messages;
  final bool isLoading;
  final bool isOfflineError;
  final String? errorMessage;
  final String? routingNotice;
  final AiProviderType? missingKeyProvider;
  final String? unsentDraft;

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? isOfflineError,
    String? errorMessage,
    String? routingNotice,
    AiProviderType? missingKeyProvider,
    String? unsentDraft,
    bool clearError = false,
    bool clearRoutingNotice = false,
    bool clearDraft = false,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isOfflineError: clearError
          ? false
          : (isOfflineError ?? this.isOfflineError),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      routingNotice: clearRoutingNotice
          ? null
          : (routingNotice ?? this.routingNotice),
      missingKeyProvider: clearError
          ? null
          : (missingKeyProvider ?? this.missingKeyProvider),
      unsentDraft: clearDraft ? null : (unsentDraft ?? this.unsentDraft),
    );
  }
}

/// Global provider for the [ChatController].
final chatControllerProvider = NotifierProvider<ChatController, ChatState>(
  ChatController.new,
);

/// Manages multi-turn AI conversation state, streaming, cancellation, routing,
/// offline local fallback, and error feedback.
class ChatController extends Notifier<ChatState> {
  AICancellationToken? _activeCancellation;

  @override
  ChatState build() {
    final repository = ref.watch(chatRepositoryProvider);
    ref.onDispose(() {
      _activeCancellation?.cancel();
    });
    return ChatState(messages: repository.getMessages());
  }

  /// Sends [prompt] using the active AI configuration (streaming, routing,
  /// fallback, and hybrid offline local command execution).
  ///
  /// Returns `true` if the prompt completed or executed locally, or `false` if
  /// blocked before dispatch (missing key / offline) so callers can preserve the draft.
  Future<bool> sendMessage(String prompt) async {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty || state.isLoading) {
      return false;
    }

    final settings = ref.read(settingsControllerProvider);
    final repository = ref.read(chatRepositoryProvider);
    final logger = ref.read(appLoggerProvider);

    final optimisticMessage = ChatMessage(
      id: 'pending_${DateTime.now().microsecondsSinceEpoch}',
      sender: MessageSender.user,
      content: trimmed,
      createdAt: DateTime.now(),
      provider: settings.selectedAiProvider,
      modelId: settings.selectedModelId,
    );

    final cancellationToken = AICancellationToken();
    _activeCancellation = cancellationToken;

    state = state.copyWith(
      messages: <ChatMessage>[...state.messages, optimisticMessage],
      isLoading: true,
      clearError: true,
      clearRoutingNotice: true,
      clearDraft: true,
    );

    try {
      if (settings.deviceActionsEnabled) {
        final localAction = DeviceIntentParser.parseLocalCommand(trimmed);
        if (localAction != null) {
          final actionResult = await ref
              .read(automationControllerProvider.notifier)
              .executeRequest(localAction);
          final updatedMessages = await repository.recordLocalActionExchange(
            userPrompt: trimmed,
            assistantReply: actionResult.summary,
            provider: settings.selectedAiProvider,
            modelId: 'offline-local-intent',
          );
          state = ChatState(messages: updatedMessages);
          logger.info('Executed local device command: ${actionResult.summary}');
          return true;
        }
      }

      String? latestRoutingNotice;
      await for (final update in repository.streamUserMessage(
        prompt: trimmed,
        settings: settings,
        cancellationToken: cancellationToken,
      )) {
        if (update is ChatMessagesUpdated) {
          latestRoutingNotice = update.routingNotice ?? latestRoutingNotice;
          state = state.copyWith(
            messages: update.messages,
            routingNotice: latestRoutingNotice,
          );
        }
      }

      final aiAction = repository.consumePendingAiAction();
      if (aiAction != null && settings.deviceActionsEnabled) {
        final actionResult = await ref
            .read(automationControllerProvider.notifier)
            .executeRequest(aiAction);
        logger.info(
          'AI-triggered device action [${aiAction.type.wireId}]: '
          '${actionResult.summary}',
        );
      }

      state = ChatState(
        messages: repository.getMessages(),
        routingNotice: latestRoutingNotice,
      );
      logger.info(
        'Completed reply using ${settings.selectedAiProvider.displayName}',
      );
      return true;
    } on MissingApiKeyException catch (error) {
      logger.warning(error.message);
      state = ChatState(
        messages: repository.getMessages(),
        errorMessage: error.message,
        missingKeyProvider: settings.selectedAiProvider,
        unsentDraft: trimmed,
      );
      return false;
    } on AIError catch (error, stackTrace) {
      if (error.kind == AIErrorKind.cancelled) {
        logger.info('AI request cancelled by user.');
        state = ChatState(
          messages: repository.getMessages(),
          errorMessage: 'Response generation cancelled.',
        );
        return true;
      }

      logger.error(
        'AI provider error (${error.provider.displayName})',
        error: error,
        stackTrace: stackTrace,
      );
      final isOffline = error.kind == AIErrorKind.networkUnavailable;
      state = ChatState(
        messages: repository.getMessages(),
        isOfflineError: isOffline,
        errorMessage: SecretRedactor.redact(error.userMessage),
        unsentDraft: isOffline ? trimmed : null,
      );
      return !isOffline;
    } on AppException catch (error, stackTrace) {
      logger.error(
        'AI provider error (${settings.selectedAiProvider.displayName})',
        error: error,
        stackTrace: stackTrace,
      );
      state = ChatState(
        messages: repository.getMessages(),
        errorMessage: SecretRedactor.redact(error.message),
      );
      return true;
    } on Exception catch (error, stackTrace) {
      logger.error(
        'Unexpected chat failure',
        error: error,
        stackTrace: stackTrace,
      );
      state = ChatState(
        messages: repository.getMessages(),
        errorMessage: AppErrorHandler.toUserMessage(error),
      );
      return true;
    } finally {
      if (identical(_activeCancellation, cancellationToken)) {
        _activeCancellation = null;
      }
    }
  }

  /// Cancels any in-flight AI completion or stream request.
  void cancelActiveRequest() {
    _activeCancellation?.cancel();
  }

  /// Regenerates a reply for the most recent user prompt in the conversation.
  Future<bool> regenerateLastResponse() async {
    if (state.isLoading) return false;
    final userMessages = state.messages
        .where((m) => m.sender == MessageSender.user)
        .toList(growable: false);
    if (userMessages.isEmpty) return false;
    return sendMessage(userMessages.last.content);
  }

  /// Retries an unsent failed prompt or falls back to the latest user prompt.
  Future<bool> retryLastPrompt() async {
    final draft = state.unsentDraft?.trim();
    if (draft != null && draft.isNotEmpty) {
      return sendMessage(draft);
    }
    return regenerateLastResponse();
  }

  /// Clears all messages from the current conversation and local storage.
  Future<void> clearConversation() async {
    _activeCancellation?.cancel();
    await ref.read(chatRepositoryProvider).clearHistory();
    state = const ChatState();
    ref.read(appLoggerProvider).info('Conversation history cleared');
  }

  /// Dismisses any visible error banner.
  void dismissError() {
    state = state.copyWith(clearError: true);
  }
}
