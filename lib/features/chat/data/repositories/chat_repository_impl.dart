import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vision_ai/core/constants/app_constants.dart';
import 'package:vision_ai/core/utils/http_client_provider.dart';
import 'package:vision_ai/core/utils/network_status_service.dart';
import 'package:vision_ai/core/utils/secure_storage_provider.dart';
import 'package:vision_ai/core/utils/shared_preferences_provider.dart';
import 'package:vision_ai/features/automation/domain/entities/device_action.dart';
import 'package:vision_ai/features/automation/domain/utils/device_intent_parser.dart';
import 'package:vision_ai/features/chat/data/datasources/chat_local_datasource.dart';
import 'package:vision_ai/features/chat/data/datasources/claude_remote_datasource.dart';
import 'package:vision_ai/features/chat/data/datasources/gemini_remote_datasource.dart';
import 'package:vision_ai/features/chat/data/datasources/openai_remote_datasource.dart';
import 'package:vision_ai/features/chat/domain/entities/ai_completion_request.dart';
import 'package:vision_ai/features/chat/domain/entities/ai_models.dart';
import 'package:vision_ai/features/chat/domain/entities/chat_message.dart';
import 'package:vision_ai/features/chat/domain/repositories/ai_provider.dart';
import 'package:vision_ai/features/chat/domain/repositories/ai_provider_client.dart';
import 'package:vision_ai/features/chat/domain/repositories/chat_repository.dart';
import 'package:vision_ai/features/chat/domain/services/ai_conversation_manager.dart';
import 'package:vision_ai/features/chat/domain/services/ai_router.dart';
import 'package:vision_ai/features/settings/domain/entities/ai_provider_type.dart';
import 'package:vision_ai/features/settings/domain/entities/app_settings.dart';
import 'package:vision_ai/features/settings/domain/entities/voice_language.dart';

/// Provides the [ChatLocalDataSource] backed by [sharedPreferencesProvider].
final chatLocalDataSourceProvider = Provider<ChatLocalDataSource>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ChatLocalDataSource(prefs);
});

/// Provides the map of [AiProviderClient] adapters keyed by [AiProviderType].
final aiProviderClientsProvider =
    Provider<Map<AiProviderType, AiProviderClient>>((ref) {
      final httpClient = ref.watch(httpClientProvider);
      return <AiProviderType, AiProviderClient>{
        AiProviderType.gemini: GeminiProvider(httpClient),
        AiProviderType.openAi: OpenAIProvider(httpClient),
        AiProviderType.claude: ClaudeProvider(httpClient),
      };
    });

/// Provides the [AIProviderRegistry] built from registered [AIProvider] instances.
final aiProviderRegistryProvider = Provider<AIProviderRegistry>((ref) {
  final clients = ref.watch(aiProviderClientsProvider);
  final mapped = <AiProviderType, AIProvider>{};
  for (final entry in clients.entries) {
    final client = entry.value;
    if (client is AIProvider) {
      mapped[entry.key] = client as AIProvider;
    } else {
      mapped[entry.key] = _LegacyClientAdapter(client);
    }
  }
  return AIProviderRegistry(mapped);
});

/// Provides the [AIRouter] orchestrating multi-provider selection and fallback.
final aiRouterProvider = Provider<AIRouter>((ref) {
  final registry = ref.watch(aiProviderRegistryProvider);
  final credentialStore = ref.watch(secureCredentialStoreProvider);
  return AIRouter(registry: registry, credentialStore: credentialStore);
});

/// Provides the concrete [ChatRepository] implementation.
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final localDataSource = ref.watch(chatLocalDataSourceProvider);
  final router = ref.watch(aiRouterProvider);
  final networkStatus = ref.watch(networkStatusServiceProvider);
  return ChatRepositoryImpl(localDataSource, router, networkStatus);
});

/// Adapts legacy [AiProviderClient] test stubs into [AIProvider].
class _LegacyClientAdapter implements AIProvider {
  const _LegacyClientAdapter(this._client);

  final AiProviderClient _client;

  @override
  AiProviderType get providerType => _client.providerType;

  @override
  String get providerName => _client.providerType.displayName;

  @override
  Future<AIResponse> generate(
    AIRequest request, {
    required String apiKey,
    AICancellationToken? cancellationToken,
  }) async {
    final sw = Stopwatch()..start();
    final text = await _client.generateReply(
      request: AiCompletionRequest(
        provider: request.provider,
        modelId: request.modelId,
        messages: request.messages,
        responseLanguage: request.responseLanguage,
        temperature: request.temperature,
        maxOutputTokens: request.maxOutputTokens,
        enableDeviceActions: request.enableDeviceActions,
      ),
      apiKey: apiKey,
    );
    sw.stop();
    return AIResponse(
      text: text,
      provider: request.provider,
      modelId: request.modelId,
      latency: sw.elapsed,
    );
  }

  @override
  Stream<AIStreamChunk> stream(
    AIRequest request, {
    required String apiKey,
    AICancellationToken? cancellationToken,
  }) async* {
    final response = await generate(
      request,
      apiKey: apiKey,
      cancellationToken: cancellationToken,
    );
    yield AITextDeltaChunk(response.text);
    yield AICompletedChunk(response);
  }

  @override
  Future<List<String>> listAvailableModels({
    required String apiKey,
    AICancellationToken? cancellationToken,
  }) async => <String>[providerType.defaultModel];

  @override
  Future<AIConnectionTestResult> testConnection({
    required String apiKey,
    String? modelId,
    AICancellationToken? cancellationToken,
  }) async {
    return AIConnectionTestResult(
      provider: providerType,
      modelId: modelId ?? providerType.defaultModel,
      connected: true,
      message: 'Connected via test adapter.',
      testedAt: DateTime.now(),
    );
  }
}

/// Concrete implementation of [ChatRepository] routing requests across Gemini,
/// OpenAI, and Claude via [AIRouter] and [AIConversationManager].
class ChatRepositoryImpl implements ChatRepository {
  ChatRepositoryImpl(
    this._localDataSource,
    this._router,
    this._networkStatusService,
  ) : _conversationManager = AIConversationManager(
        initialMessages: _localDataSource.readMessages(),
      );

  final ChatLocalDataSource _localDataSource;
  final AIRouter _router;
  final NetworkStatusService _networkStatusService;
  final AIConversationManager _conversationManager;
  DeviceActionRequest? _pendingAiAction;

  @override
  List<ChatMessage> getMessages() => _conversationManager.messages;

  @override
  DeviceActionRequest? consumePendingAiAction() {
    final action = _pendingAiAction;
    _pendingAiAction = null;
    return action;
  }

  @override
  Future<List<ChatMessage>> sendUserMessage({
    required String prompt,
    required AiProviderType provider,
    required VoiceLanguage language,
    bool enableDeviceActions = true,
    AppSettings? settings,
    AICancellationToken? cancellationToken,
  }) async {
    final effectiveSettings =
        settings ??
        AppSettings(
          selectedAiProvider: provider,
          selectedVoiceLanguage: language,
          deviceActionsEnabled: enableDeviceActions,
          streamingEnabled: false,
        );

    List<ChatMessage> latest = getMessages();
    await for (final update in streamUserMessage(
      prompt: prompt,
      settings: effectiveSettings.copyWith(streamingEnabled: false),
      cancellationToken: cancellationToken,
    )) {
      if (update is ChatMessagesUpdated) {
        latest = update.messages;
      }
    }
    return latest;
  }

  @override
  Stream<ChatStreamUpdate> streamUserMessage({
    required String prompt,
    required AppSettings settings,
    AICancellationToken? cancellationToken,
  }) async* {
    final trimmedPrompt = prompt.trim();
    if (trimmedPrompt.isEmpty) {
      yield ChatMessagesUpdated(getMessages());
      return;
    }
    _pendingAiAction = null;

    final isOnline = await _networkStatusService.isOnline();
    if (!isOnline) {
      throw AIError(
        kind: AIErrorKind.networkUnavailable,
        provider: settings.selectedAiProvider,
        modelId: settings.selectedModelId,
        message: 'Device is offline.',
        userMessage:
            'No internet connection detected. Online AI is unavailable right now, '
            'but offline device commands (alarms, timers, app launching, settings, flashlight, device status) still work.',
      );
    }

    final provider = settings.selectedAiProvider;
    final modelId = settings.modelForProvider(provider);

    // Validate candidate availability before adding user prompt to history so
    // missing-key errors don't leave orphaned messages.
    await _router.resolveCandidates(
      settings: settings,
      promptText: trimmedPrompt,
    );

    final userMessage = _conversationManager.createUserMessage(
      trimmedPrompt,
      provider: provider,
      modelId: modelId,
    );
    _conversationManager.addMessage(userMessage);
    await _localDataSource.writeMessages(_conversationManager.messages);
    yield ChatMessagesUpdated(_conversationManager.messages);

    final contextWindow = _conversationManager.buildContextWindow(
      maxMessages: AppConstants.maxContextMessages,
    );

    final completionRequest = AiCompletionRequest(
      provider: provider,
      modelId: modelId,
      messages: contextWindow,
      responseLanguage: settings.selectedVoiceLanguage,
      enableDeviceActions: settings.deviceActionsEnabled,
    );

    if (!settings.streamingEnabled) {
      final response = await _router.routeAndGenerate(
        completionRequest: completionRequest,
        settings: settings,
        promptText: trimmedPrompt,
        cancellationToken: cancellationToken,
      );
      final assistantMessage = _finalizeResponse(
        response,
        enableDeviceActions: settings.deviceActionsEnabled,
      );
      _conversationManager.addMessage(assistantMessage);
      await _localDataSource.writeMessages(_conversationManager.messages);
      yield ChatMessagesUpdated(
        _conversationManager.messages,
        routingNotice: response.routingNotice,
      );
      return;
    }

    final streamMessageId = 'ast_${DateTime.now().microsecondsSinceEpoch}';
    final partialBuffer = StringBuffer();
    var streamedAnyDelta = false;
    AIResponse? completedResponse;

    try {
      await for (final chunk in _router.routeAndStream(
        completionRequest: completionRequest,
        settings: settings,
        promptText: trimmedPrompt,
        cancellationToken: cancellationToken,
      )) {
        switch (chunk) {
          case AITextDeltaChunk(:final delta):
            streamedAnyDelta = true;
            partialBuffer.write(delta);
            final displayPreview = _stripActionTagForPreview(
              partialBuffer.toString(),
            );
            _conversationManager.upsertStreamingAssistantMessage(
              ChatMessage(
                id: streamMessageId,
                sender: MessageSender.assistant,
                content: displayPreview,
                createdAt: DateTime.now(),
                provider: provider,
                modelId: modelId,
              ),
            );
            yield ChatMessagesUpdated(_conversationManager.messages);

          case AIToolCallChunk():
            break;

          case AICompletedChunk(:final response):
            completedResponse = response;
        }
      }
    } catch (error) {
      if (streamedAnyDelta && partialBuffer.isNotEmpty) {
        _conversationManager.upsertStreamingAssistantMessage(
          ChatMessage(
            id: streamMessageId,
            sender: MessageSender.assistant,
            content: partialBuffer.toString().trim(),
            createdAt: DateTime.now(),
            provider: provider,
            modelId: modelId,
          ),
        );
        await _localDataSource.writeMessages(_conversationManager.messages);
      } else {
        _conversationManager.removeMessageById(streamMessageId);
      }
      rethrow;
    }

    if (completedResponse != null) {
      final finalMessage = _finalizeResponse(
        completedResponse,
        messageId: streamMessageId,
        enableDeviceActions: settings.deviceActionsEnabled,
      );
      _conversationManager.upsertStreamingAssistantMessage(finalMessage);
      await _localDataSource.writeMessages(_conversationManager.messages);
      yield ChatMessagesUpdated(
        _conversationManager.messages,
        routingNotice: completedResponse.routingNotice,
      );
    }
  }

  ChatMessage _finalizeResponse(
    AIResponse response, {
    String? messageId,
    required bool enableDeviceActions,
  }) {
    final rawText = response.text;
    if (enableDeviceActions && response.toolCalls.isNotEmpty) {
      final firstTool = response.toolCalls.first;
      if (firstTool.name == 'execute_device_action') {
        final directive =
            '[[VISION_ACTION:${jsonEncode(firstTool.arguments)}]]';
        final extracted = DeviceIntentParser.extractAiAction(directive);
        if (extracted.action != null) {
          _pendingAiAction = extracted.action;
        }
      }
    }

    final extraction = DeviceIntentParser.extractAiAction(rawText);
    if (enableDeviceActions &&
        _pendingAiAction == null &&
        extraction.action != null) {
      _pendingAiAction = extraction.action;
    }

    final cleanContent = extraction.cleanText.isNotEmpty
        ? extraction.cleanText
        : (_pendingAiAction?.displaySummary ?? rawText);

    return ChatMessage(
      id: messageId ?? 'ast_${DateTime.now().microsecondsSinceEpoch}',
      sender: MessageSender.assistant,
      content: cleanContent,
      createdAt: DateTime.now(),
      provider: response.provider,
      modelId: response.modelId,
      inputTokens: response.usage?.inputTokens,
      outputTokens: response.usage?.outputTokens,
      routingNotice: response.routingNotice,
    );
  }

  String _stripActionTagForPreview(String raw) {
    final idx = raw.indexOf('[[VISION_ACTION:');
    if (idx == -1) return raw;
    return raw.substring(0, idx).trimRight();
  }

  @override
  Future<List<ChatMessage>> recordLocalActionExchange({
    required String userPrompt,
    required String assistantReply,
    required AiProviderType provider,
    String? modelId,
  }) async {
    final now = DateTime.now();
    _conversationManager.addMessage(
      ChatMessage(
        id: 'usr_${now.microsecondsSinceEpoch}',
        sender: MessageSender.user,
        content: userPrompt.trim(),
        createdAt: now,
        provider: provider,
        modelId: modelId,
      ),
    );
    _conversationManager.addMessage(
      ChatMessage(
        id: 'act_${now.microsecondsSinceEpoch + 1}',
        sender: MessageSender.assistant,
        content: assistantReply.trim(),
        createdAt: DateTime.now(),
        provider: provider,
        modelId: modelId ?? 'offline-local-intent',
      ),
    );
    await _localDataSource.writeMessages(_conversationManager.messages);
    return getMessages();
  }

  @override
  Future<void> clearHistory() async {
    _pendingAiAction = null;
    _conversationManager.clear();
    await _localDataSource.clearMessages();
  }
}
