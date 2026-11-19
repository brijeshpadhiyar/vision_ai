import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/errors/app_exception.dart';
import 'package:vision_ai/core/errors/error_handler.dart';
import 'package:vision_ai/core/intelligence/conversation_context.dart';
import 'package:vision_ai/core/telemetry/performance_telemetry.dart';
import 'package:vision_ai/core/utils/app_logger.dart';
import 'package:vision_ai/core/utils/secret_redactor.dart';
import 'package:vision_ai/features/automation/domain/entities/device_action.dart';
import 'package:vision_ai/features/automation/domain/utils/device_intent_parser.dart';
import 'package:vision_ai/features/automation/presentation/controllers/automation_controller.dart';
import 'package:vision_ai/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:vision_ai/features/chat/domain/entities/ai_models.dart';
import 'package:vision_ai/features/chat/domain/entities/chat_message.dart';
import 'package:vision_ai/features/chat/domain/entities/image_attachment.dart';
import 'package:vision_ai/features/chat/domain/repositories/chat_repository.dart';
import 'package:vision_ai/features/settings/domain/entities/ai_provider_type.dart';
import 'package:vision_ai/features/settings/presentation/controllers/settings_controller.dart';
import 'package:vision_ai/features/vision/domain/services/visual_intelligence_service.dart';

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
    this.pendingImage,
    this.webResearchEnabled = false,
  });

  final List<ChatMessage> messages;
  final bool isLoading;
  final bool isOfflineError;
  final String? errorMessage;
  final String? routingNotice;
  final AiProviderType? missingKeyProvider;
  final String? unsentDraft;
  final ImageAttachment? pendingImage;
  final bool webResearchEnabled;

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? isOfflineError,
    String? errorMessage,
    String? routingNotice,
    AiProviderType? missingKeyProvider,
    String? unsentDraft,
    ImageAttachment? pendingImage,
    bool? webResearchEnabled,
    bool clearError = false,
    bool clearRoutingNotice = false,
    bool clearDraft = false,
    bool clearPendingImage = false,
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
      pendingImage: clearPendingImage
          ? null
          : (pendingImage ?? this.pendingImage),
      webResearchEnabled: webResearchEnabled ?? this.webResearchEnabled,
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
  ConversationIntelligenceContext _intelContext =
      const ConversationIntelligenceContext();
  String? _lastSubmittedPrompt;
  DateTime? _lastSubmittedAt;

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
  /// [alternativeTranscripts] carries additional speech recognition hypotheses
  /// so intent classification and phonetic contact matching can recover from
  /// ASR misspellings without mutating displayed user text.
  ///
  /// Returns `true` if the prompt completed or executed locally, or `false` if
  /// blocked before dispatch (missing key / offline) so callers can preserve the draft.
  void setPendingImage(ImageAttachment attachment) {
    state = state.copyWith(pendingImage: attachment, clearError: true);
  }

  void clearPendingImage() {
    state = state.copyWith(clearPendingImage: true);
  }

  void toggleWebResearch() {
    state = state.copyWith(webResearchEnabled: !state.webResearchEnabled);
  }

  /// Runs offline ML Kit OCR on the currently staged photo and appends the
  /// extracted text into the conversation with zero cloud upload.
  Future<void> extractTextFromPendingImage() async {
    final image = state.pendingImage;
    if (image == null || image.filePath.isEmpty || state.isLoading) return;

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final text = await ref
          .read(visualIntelligenceServiceProvider)
          .extractTextOffline(image.filePath);
      final settings = ref.read(settingsControllerProvider);
      final updated = await ref
          .read(chatRepositoryProvider)
          .recordLocalActionExchange(
            userPrompt: 'Read text from photo (${image.label})',
            assistantReply: text.isNotEmpty
                ? 'Extracted text (Offline ML Kit OCR):\n\n$text'
                : 'No readable text detected in this photo.',
            provider: settings.selectedAiProvider,
            modelId: 'mlkit-offline-ocr',
          );
      state = state.copyWith(
        messages: updated,
        isLoading: false,
        clearPendingImage: true,
        routingNotice: 'Offline ML Kit OCR completed locally.',
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Offline OCR failed: $error',
      );
    }
  }

  Future<bool> sendMessage(
    String prompt, {
    List<String> alternativeTranscripts = const <String>[],
    String? originalTranscript,
    bool allowDuplicate = false,
  }) async {
    final trimmed = prompt.trim();
    final stagedImage = state.pendingImage;
    if ((trimmed.isEmpty && stagedImage == null) || state.isLoading) {
      return false;
    }

    final now = DateTime.now();
    if (!allowDuplicate &&
        _lastSubmittedPrompt == trimmed.toLowerCase() &&
        _lastSubmittedAt != null &&
        now.difference(_lastSubmittedAt!).inMilliseconds < 1200) {
      return false;
    }
    _lastSubmittedPrompt = trimmed.toLowerCase();
    _lastSubmittedAt = now;

    final settings = ref.read(settingsControllerProvider);
    final repository = ref.read(chatRepositoryProvider);
    final logger = ref.read(appLoggerProvider);
    if (originalTranscript != null &&
        originalTranscript.trim().isNotEmpty &&
        originalTranscript.trim() != trimmed) {
      logger.info(
        'Voice transcript preserved raw="$originalTranscript" cleaned="$trimmed"',
      );
    }

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
      final telemetry = ref.read(telemetryProvider.notifier);
      final resolution = DeviceIntentParser.analyzeIntent(
        trimmed,
        context: _intelContext,
        alternativeTranscripts: alternativeTranscripts,
      );
      telemetry.recordIntentParse(
        resolution.parseTimeMicros,
        localHandled:
            resolution.shouldHandleLocally || resolution.needsClarification,
      );

      if (resolution.needsClarification &&
          resolution.clarificationPrompt != null) {
        final clarification = resolution.clarificationPrompt!;
        _intelContext = _intelContext.copyWith(
          pendingClarificationIntentId: resolution.intentId,
          pendingClarificationPrompt: clarification,
          lastSpokenReply: clarification,
        );
        final updatedMessages = await repository.recordLocalActionExchange(
          userPrompt: trimmed,
          assistantReply: clarification,
          provider: settings.selectedAiProvider,
          modelId: 'offline-local-clarification',
        );
        state = ChatState(messages: updatedMessages);
        return true;
      }

      if (settings.deviceActionsEnabled &&
          resolution.shouldHandleLocally &&
          resolution.request != null) {
        final localAction = resolution.request!;
        if (localAction.type == DeviceActionType.repeatLast) {
          final repeatText =
              _intelContext.lastSpokenReply ??
              repository
                  .getMessages()
                  .lastWhere(
                    (m) => m.sender == MessageSender.assistant,
                    orElse: () => ChatMessage(
                      id: 'none',
                      sender: MessageSender.assistant,
                      content: 'There is no previous response to repeat yet.',
                      createdAt: DateTime.now(),
                    ),
                  )
                  .content;
          final updatedMessages = await repository.recordLocalActionExchange(
            userPrompt: trimmed,
            assistantReply: repeatText,
            provider: settings.selectedAiProvider,
            modelId: 'offline-local-intent',
          );
          state = ChatState(messages: updatedMessages);
          return true;
        }

        final automationNotifier = ref.read(
          automationControllerProvider.notifier,
        );
        final actionResult = resolution.intentId == 'confirm_pending'
            ? (await automationNotifier.confirmPendingAction(
                    saveAsAlias: true,
                  ) ??
                  await automationNotifier.executeRequest(
                    localAction,
                    confirmed: true,
                    alternativeQueries: alternativeTranscripts,
                  ))
            : await automationNotifier.executeRequest(
                localAction,
                alternativeQueries: alternativeTranscripts,
              );

        final latestAutomationState = ref.read(automationControllerProvider);
        final isPendingConfirm =
            actionResult.status == DeviceActionStatus.confirmationRequired;
        _intelContext = _intelContext.copyWith(
          lastIntentId: resolution.intentId,
          lastContactName:
              (localAction.type == DeviceActionType.callPhone ||
                      localAction.type == DeviceActionType.lookupContacts ||
                      localAction.type == DeviceActionType.sendSms ||
                      localAction.type == DeviceActionType.sendWhatsapp) &&
                  localAction.target.isNotEmpty
              ? (actionResult.suggestedContact?.name ?? localAction.target)
              : _intelContext.lastContactName,
          lastAppName: localAction.type == DeviceActionType.launchApp
              ? localAction.target
              : _intelContext.lastAppName,
          lastSpokenReply: actionResult.summary,
          pendingAction: isPendingConfirm
              ? (latestAutomationState.pendingConfirmation ?? localAction)
              : null,
          clearPendingAction: !isPendingConfirm,
          clearClarification: true,
        );

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

      String? latestRoutingNotice;
      final useWebResearch = state.webResearchEnabled;
      await for (final update in repository.streamUserMessage(
        prompt: trimmed,
        settings: settings,
        cancellationToken: cancellationToken,
        imageAttachment: stagedImage,
        webResearchEnabled: useWebResearch,
      )) {
        if (!ref.mounted) return false;
        if (update is ChatMessagesUpdated) {
          latestRoutingNotice = update.routingNotice ?? latestRoutingNotice;
          state = state.copyWith(
            messages: update.messages,
            routingNotice: latestRoutingNotice,
            clearPendingImage: true,
          );
        }
      }

      if (!ref.mounted) return false;
      final aiAction = repository.consumePendingAiAction();
      if (aiAction != null && settings.deviceActionsEnabled) {
        final actionResult = await ref
            .read(automationControllerProvider.notifier)
            .executeRequest(aiAction);
        _intelContext = _intelContext.copyWith(
          pendingAction:
              actionResult.status == DeviceActionStatus.confirmationRequired
              ? aiAction
              : null,
          clearPendingAction:
              actionResult.status != DeviceActionStatus.confirmationRequired,
        );
        logger.info(
          'AI-triggered device action [${aiAction.type.wireId}]: '
          '${actionResult.summary}',
        );
      }

      final allMessages = repository.getMessages();
      if (allMessages.isNotEmpty &&
          allMessages.last.sender == MessageSender.assistant) {
        _intelContext = _intelContext.copyWith(
          lastSpokenReply: allMessages.last.content,
          clearClarification: true,
        );
      }

      state = ChatState(
        messages: allMessages,
        routingNotice: latestRoutingNotice,
        webResearchEnabled: useWebResearch,
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
      if (!ref.mounted) return false;
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
      if (!ref.mounted) return false;
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
      if (!ref.mounted) return false;
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
    return sendMessage(userMessages.last.content, allowDuplicate: true);
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
