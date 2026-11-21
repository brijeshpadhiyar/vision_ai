import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vision_ai/core/constants/app_constants.dart';
import 'package:vision_ai/core/intelligence/language_detector.dart';
import 'package:vision_ai/core/telemetry/performance_telemetry.dart';
import 'package:vision_ai/core/utils/http_client_provider.dart';
import 'package:vision_ai/core/utils/network_status_service.dart';
import 'package:vision_ai/core/utils/secure_storage_provider.dart';
import 'package:vision_ai/core/utils/shared_preferences_provider.dart';
import 'package:vision_ai/features/automation/domain/entities/device_action.dart';
import 'package:vision_ai/features/automation/domain/utils/device_intent_parser.dart';
import 'package:vision_ai/features/chat/data/datasources/chat_local_datasource.dart';
import 'package:vision_ai/features/chat/data/datasources/claude_remote_datasource.dart';
import 'package:vision_ai/features/chat/data/datasources/edge_ai_datasource.dart';
import 'package:vision_ai/features/chat/data/datasources/gemini_remote_datasource.dart';
import 'package:vision_ai/features/chat/data/datasources/openai_remote_datasource.dart';
import 'package:vision_ai/features/chat/data/datasources/vision_cloud_datasource.dart';
import 'package:vision_ai/features/chat/domain/entities/ai_completion_request.dart';
import 'package:vision_ai/features/chat/domain/entities/ai_models.dart';
import 'package:vision_ai/features/chat/domain/entities/chat_message.dart';
import 'package:vision_ai/features/chat/domain/entities/image_attachment.dart';
import 'package:vision_ai/features/chat/domain/repositories/ai_provider.dart';
import 'package:vision_ai/features/chat/domain/repositories/ai_provider_client.dart';
import 'package:vision_ai/features/chat/domain/repositories/chat_repository.dart';
import 'package:vision_ai/features/chat/domain/services/ai_conversation_manager.dart';
import 'package:vision_ai/features/chat/domain/services/ai_router.dart';
import 'package:vision_ai/features/chat/domain/services/provider_health_manager.dart';
import 'package:vision_ai/features/chat/domain/services/task_complexity_classifier.dart';
import 'package:vision_ai/features/chat/presentation/controllers/usage_stats_controller.dart';
import 'package:vision_ai/features/memory/presentation/controllers/memory_controller.dart';
import 'package:vision_ai/features/research/domain/entities/research_source.dart';
import 'package:vision_ai/features/research/domain/services/internet_research_service.dart';
import 'package:vision_ai/features/settings/domain/entities/ai_provider_type.dart';
import 'package:vision_ai/features/settings/domain/entities/app_settings.dart';
import 'package:vision_ai/features/settings/domain/entities/voice_language.dart';
import 'package:vision_ai/features/settings/presentation/controllers/settings_controller.dart';
import 'package:vision_ai/features/vision/domain/services/visual_intelligence_service.dart';

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
        AiProviderType.visionCloud: VisionCloudProvider(
          onQuotaUpdated: (quota) {
            ref.read(visionCloudQuotaProvider.notifier).update(quota);
          },
        ),
        AiProviderType.gemini: GeminiProvider(httpClient),
        AiProviderType.openAi: OpenAIProvider(httpClient),
        AiProviderType.claude: ClaudeProvider(httpClient),
        AiProviderType.edgeAi: EdgeAiProvider(),
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

/// Provides the [AIRouter] orchestrating manual provider selection and opt-in fallback.
final aiRouterProvider = Provider<AIRouter>((ref) {
  final registry = ref.watch(aiProviderRegistryProvider);
  final credentialStore = ref.watch(secureCredentialStoreProvider);
  final healthManager = ref.watch(providerHealthManagerProvider);
  final telemetry = ref.read(telemetryProvider.notifier);
  return AIRouter(
    registry: registry,
    credentialStore: credentialStore,
    healthManager: healthManager,
    telemetry: telemetry,
    onUsageRecorded: (provider, modelId, usage) {
      unawaited(
        ref
            .read(usageStatsControllerProvider.notifier)
            .recordUsage(provider: provider, modelId: modelId, usage: usage),
      );
    },
  );
});

/// Provides the concrete [ChatRepository] implementation.
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final localDataSource = ref.watch(chatLocalDataSourceProvider);
  final router = ref.watch(aiRouterProvider);
  final networkStatus = ref.watch(networkStatusServiceProvider);
  final researchService = ref.watch(internetResearchServiceProvider);
  final visualService = ref.watch(visualIntelligenceServiceProvider);
  return ChatRepositoryImpl(
    localDataSource,
    router,
    networkStatus,
    researchService: researchService,
    visualService: visualService,
    memoryContextReader: () =>
        ref.read(memoryControllerProvider).buildPromptContext(),
    isHistoryPersistenceEnabled: () =>
        ref.read(settingsControllerProvider).saveConversationHistory,
  );
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
    this._networkStatusService, {
    this._memoryContextReader,
    this._isHistoryPersistenceEnabled,
    this._researchService,
    this._visualService,
  }) : _conversationManager = AIConversationManager(
         initialMessages: (_isHistoryPersistenceEnabled?.call() ?? false)
             ? _localDataSource.readMessages()
             : const <ChatMessage>[],
       );

  final ChatLocalDataSource _localDataSource;
  final AIRouter _router;
  final NetworkStatusService _networkStatusService;
  final String Function()? _memoryContextReader;
  final bool Function()? _isHistoryPersistenceEnabled;
  final InternetResearchService? _researchService;
  final VisualIntelligenceService? _visualService;
  final AIConversationManager _conversationManager;
  DeviceActionRequest? _pendingAiAction;

  Future<void> _persistIfEnabled() async {
    if (_isHistoryPersistenceEnabled?.call() ?? false) {
      await _localDataSource.writeMessages(_conversationManager.messages);
    }
  }

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
    ImageAttachment? imageAttachment,
    bool webResearchEnabled = false,
  }) async* {
    final trimmedPrompt = prompt.trim();
    if (trimmedPrompt.isEmpty && imageAttachment == null) {
      yield ChatMessagesUpdated(getMessages());
      return;
    }
    final effectivePrompt = trimmedPrompt.isNotEmpty
        ? trimmedPrompt
        : 'Analyze this image and describe what you see.';
    _pendingAiAction = null;

    final isOnline = await _networkStatusService.isOnline();
    final activeSettings = settings;
    String? preRoutingNotice;

    if (!isOnline) {
      // Smart-hybrid Module 20: offline photo -> automatic ML Kit OCR
      if (imageAttachment != null &&
          imageAttachment.filePath.isNotEmpty &&
          _visualService != null) {
        final extracted = await _visualService.extractTextOffline(
          imageAttachment.filePath,
        );
        final userMessage = ChatMessage(
          id: 'usr_${DateTime.now().microsecondsSinceEpoch}',
          sender: MessageSender.user,
          content: effectivePrompt,
          createdAt: DateTime.now(),
          provider: AiProviderType.edgeAi,
          modelId: 'mlkit-offline-ocr',
          imageAttachment: imageAttachment,
        );
        final replyMessage = ChatMessage(
          id: 'ast_${DateTime.now().microsecondsSinceEpoch + 1}',
          sender: MessageSender.assistant,
          content: extracted.isNotEmpty
              ? 'Extracted text (Offline ML Kit OCR):\n\n$extracted'
              : 'Device is offline and no readable text was detected in this photo via ML Kit OCR.',
          createdAt: DateTime.now(),
          provider: AiProviderType.edgeAi,
          modelId: 'mlkit-offline-ocr',
          routingNotice: 'Offline ML Kit OCR active (zero cloud upload).',
        );
        _conversationManager
          ..addMessage(userMessage)
          ..addMessage(replyMessage);
        await _persistIfEnabled();
        yield ChatMessagesUpdated(
          _conversationManager.messages,
          routingNotice: replyMessage.routingNotice,
        );
        return;
      }

      // If On-Device Edge AI is selected, allow it to run offline directly;
      // otherwise throw clean offline AIError preserving unsentDraft.
      if (settings.selectedAiProvider != AiProviderType.edgeAi) {
        throw AIError(
          kind: AIErrorKind.networkUnavailable,
          provider: settings.selectedAiProvider,
          modelId: settings.selectedModelId,
          message: 'Device is offline.',
          userMessage:
              'No internet connection detected. Online AI is unavailable right now, '
              'but offline device commands (alarms, timers, app launching, settings, flashlight, device status) '
              'and On-Device Edge AI / ML Kit OCR still work.',
        );
      }
      preRoutingNotice = 'Offline On-Device Edge AI (Gemini Nano) active.';
    }

    final provider = activeSettings.selectedAiProvider;
    final modelId = activeSettings.modelForProvider(provider);

    // Module 21: Zero-config Internet Research grounding
    var researchCitations = const <ResearchSource>[];
    var webResearchContext = '';
    final shouldResearch =
        isOnline &&
        _researchService != null &&
        (webResearchEnabled ||
            InternetResearchService.shouldAutoTriggerResearch(effectivePrompt));
    if (shouldResearch) {
      final bundle = await _researchService.search(effectivePrompt);
      if (bundle.hasSources) {
        researchCitations = bundle.sources;
        webResearchContext = bundle.buildPromptContext();
        preRoutingNotice =
            'Web Research active: grounded with ${bundle.sources.length} live sources.';
      }
    }

    // Resolve candidates once upfront so missing-key errors abort before writing
    // user messages and SecureStorage isn't queried twice per turn.
    final candidates = await _router.resolveCandidates(
      settings: activeSettings,
      promptText: effectivePrompt,
    );

    final userMessage = ChatMessage(
      id: 'usr_${DateTime.now().microsecondsSinceEpoch}',
      sender: MessageSender.user,
      content: effectivePrompt,
      createdAt: DateTime.now(),
      provider: provider,
      modelId: modelId,
      imageAttachment: imageAttachment,
    );
    _conversationManager.addMessage(userMessage);
    await _persistIfEnabled();
    yield ChatMessagesUpdated(
      _conversationManager.messages,
      routingNotice: preRoutingNotice,
    );

    final contextWindow = _conversationManager.buildContextWindow(
      maxMessages: AppConstants.maxContextMessages,
    );

    final complexity = TaskComplexityClassifier.classify(effectivePrompt);
    final attachTools =
        activeSettings.deviceActionsEnabled &&
        imageAttachment == null &&
        _mightNeedDeviceToolSchema(effectivePrompt);
    final tokenBudget = switch (complexity) {
      TaskComplexityTier.simpleFast => 512,
      TaskComplexityTier.balancedMultilingual => 1024,
      TaskComplexityTier.deepReasoningCoding => 2048,
    };

    final resolvedResponseLanguage =
        activeSettings.selectedVoiceLanguage == VoiceLanguage.auto
        ? LanguageDetector.detect(
            effectivePrompt,
            fallback: VoiceLanguage.english,
          )
        : activeSettings.selectedVoiceLanguage;

    final completionRequest = AiCompletionRequest(
      provider: provider,
      modelId: modelId,
      messages: contextWindow,
      responseLanguage: resolvedResponseLanguage,
      maxOutputTokens: tokenBudget,
      enableDeviceActions: attachTools,
      personalMemoryContext: _memoryContextReader?.call() ?? '',
      webResearchContext: webResearchContext,
      assistantIdentity: activeSettings.assistantIdentity,
    );

    if (!activeSettings.streamingEnabled) {
      final response = await _router.routeAndGenerate(
        completionRequest: completionRequest,
        settings: activeSettings,
        promptText: effectivePrompt,
        cancellationToken: cancellationToken,
        preResolvedCandidates: candidates,
      );
      final assistantMessage = _finalizeResponse(
        response,
        enableDeviceActions: activeSettings.deviceActionsEnabled,
        citations: researchCitations,
      );
      _conversationManager.addMessage(assistantMessage);
      await _persistIfEnabled();
      yield ChatMessagesUpdated(
        _conversationManager.messages,
        routingNotice: response.routingNotice ?? preRoutingNotice,
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
        settings: activeSettings,
        promptText: effectivePrompt,
        cancellationToken: cancellationToken,
        preResolvedCandidates: candidates,
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
                citations: researchCitations,
              ),
            );
            yield ChatMessagesUpdated(
              _conversationManager.messages,
              routingNotice: preRoutingNotice,
            );

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
            citations: researchCitations,
          ),
        );
        await _persistIfEnabled();
      } else {
        _conversationManager.removeMessageById(streamMessageId);
      }
      rethrow;
    }

    if (completedResponse != null) {
      final finalMessage = _finalizeResponse(
        completedResponse,
        messageId: streamMessageId,
        enableDeviceActions: activeSettings.deviceActionsEnabled,
        citations: researchCitations,
      );
      _conversationManager.upsertStreamingAssistantMessage(finalMessage);
      await _persistIfEnabled();
      yield ChatMessagesUpdated(
        _conversationManager.messages,
        routingNotice: completedResponse.routingNotice ?? preRoutingNotice,
      );
    }
  }

  ChatMessage _finalizeResponse(
    AIResponse response, {
    String? messageId,
    required bool enableDeviceActions,
    List<ResearchSource> citations = const <ResearchSource>[],
  }) {
    final rawText = response.text;
    if (enableDeviceActions && response.toolCalls.isNotEmpty) {
      final parsedTools = <DeviceActionRequest>[];
      for (final tool in response.toolCalls) {
        if (tool.name == 'execute_device_action') {
          final directive = '[[VISION_ACTION:${jsonEncode(tool.arguments)}]]';
          final extracted = DeviceIntentParser.extractAiAction(directive);
          if (extracted.action != null) {
            parsedTools.add(extracted.action!);
          }
        }
      }
      if (parsedTools.length == 1) {
        _pendingAiAction = parsedTools.first;
      } else if (parsedTools.length > 1) {
        final primary = parsedTools.first;
        _pendingAiAction = DeviceActionRequest(
          type: primary.type,
          displaySummary: parsedTools.map((a) => a.displaySummary).join(' -> '),
          target: primary.target,
          hour: primary.hour,
          minute: primary.minute,
          durationSeconds: primary.durationSeconds,
          label: primary.label,
          message: primary.message,
          enabled: primary.enabled,
          requiresConfirmation: parsedTools.any((a) => a.requiresConfirmation),
          contactOrdinalIndex: primary.contactOrdinalIndex,
          isTomorrow: primary.isTomorrow,
          followUpActions: parsedTools.skip(1).toList(growable: false),
        );
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
      citations: citations,
    );
  }

  String _stripActionTagForPreview(String raw) {
    final idx = raw.indexOf('[[VISION_ACTION:');
    if (idx == -1) return raw;
    return raw.substring(0, idx).trimRight();
  }

  /// Avoids sending heavy JSON tool schemas on pure Q&A / coding prompts,
  /// lowering TTFT and token usage when local parsing already handles direct actions.
  static bool _mightNeedDeviceToolSchema(String prompt) {
    return RegExp(
      r'\b(call|dial|phone|contact|alarm|timer|open|launch|start|settings|wifi|bluetooth|flashlight|torch|silent|vibrate|volume|mute|battery|status|sms|message|whatsapp|navigate|directions|search|notification)\b',
      caseSensitive: false,
    ).hasMatch(prompt);
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
    await _persistIfEnabled();
    return getMessages();
  }

  /// Replaces the active in-memory session messages (used when switching threads).
  Future<void> replaceSessionMessages(List<ChatMessage> messages) async {
    _pendingAiAction = null;
    _conversationManager.clear();
    for (final msg in messages) {
      _conversationManager.addMessage(msg);
    }
    await _persistIfEnabled();
  }

  @override
  Future<void> clearHistory() async {
    _pendingAiAction = null;
    _conversationManager.clear();
    await _localDataSource.clearMessages();
  }
}
