import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vision_ai/core/constants/storage_keys.dart';
import 'package:vision_ai/core/utils/network_status_service.dart';
import 'package:vision_ai/core/utils/secure_storage_provider.dart';
import 'package:vision_ai/core/utils/shared_preferences_provider.dart';
import 'package:vision_ai/features/chat/data/datasources/chat_local_datasource.dart';
import 'package:vision_ai/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:vision_ai/features/chat/domain/entities/ai_completion_request.dart';
import 'package:vision_ai/features/chat/domain/entities/ai_models.dart';
import 'package:vision_ai/features/chat/domain/repositories/ai_provider.dart';
import 'package:vision_ai/features/chat/domain/services/ai_router.dart';
import 'package:vision_ai/features/chat/presentation/controllers/usage_stats_controller.dart';
import 'package:vision_ai/features/settings/domain/entities/ai_provider_type.dart';
import 'package:vision_ai/features/settings/domain/entities/app_settings.dart';
import 'package:vision_ai/features/settings/domain/entities/voice_language.dart';
import 'package:vision_ai/features/settings/presentation/controllers/settings_controller.dart';

class _InMemoryCredentialStore implements SecureCredentialStore {
  _InMemoryCredentialStore(this._keys);

  final Map<String, String> _keys;

  @override
  Future<String?> readApiKey(String providerId) async => _keys[providerId];

  @override
  Future<void> saveApiKey({
    required String providerId,
    required String apiKey,
  }) async {
    _keys[providerId] = apiKey;
  }

  @override
  Future<void> deleteApiKey(String providerId) async {
    _keys.remove(providerId);
  }

  @override
  Future<bool> hasApiKey(String providerId) async =>
      (_keys[providerId]?.trim().isNotEmpty ?? false);
}

class _FakeProvider implements AIProvider {
  _FakeProvider({
    required this.providerType,
    this.errorToThrow,
    this.responseText = 'Hello from VISION',
  });

  @override
  final AiProviderType providerType;
  final AIError? errorToThrow;
  final String responseText;
  final AIUsage usage = const AIUsage(inputTokens: 12, outputTokens: 28);

  @override
  String get providerName => providerType.displayName;

  @override
  Future<AIResponse> generate(
    AIRequest request, {
    required String apiKey,
    AICancellationToken? cancellationToken,
  }) async {
    if (errorToThrow != null) throw errorToThrow!;
    return AIResponse(
      text: responseText,
      provider: providerType,
      modelId: request.modelId,
      usage: usage,
      latency: const Duration(milliseconds: 50),
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
  }) async => AIConnectionTestResult(
    provider: providerType,
    modelId: modelId ?? providerType.defaultModel,
    connected: true,
    message: 'OK',
    testedAt: DateTime.now(),
  );
}

class _AlwaysOnlineService extends NetworkStatusService {
  @override
  Future<bool> isOnline() async => true;
}

void main() {
  test('Wave 1 defaults: fallbackEnabled=false & saveConversationHistory=false', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    final settings = container.read(settingsControllerProvider);
    expect(settings.fallbackEnabled, isFalse);
    expect(settings.saveConversationHistory, isFalse);
  });

  test('Wave 1 AIRouter stays strictly manual when fallbackEnabled=false and records usage', () async {
    final recorded = <(AiProviderType, String, AIUsage?)>[];
    final router = AIRouter(
      registry: AIProviderRegistry(<AiProviderType, AIProvider>{
        AiProviderType.gemini: _FakeProvider(
          providerType: AiProviderType.gemini,
          errorToThrow: const AIError(
            kind: AIErrorKind.serverError,
            provider: AiProviderType.gemini,
            message: '503',
            userMessage: 'Gemini unavailable',
          ),
        ),
        AiProviderType.openAi: _FakeProvider(
          providerType: AiProviderType.openAi,
          responseText: 'Fallback answer',
        ),
      }),
      credentialStore: _InMemoryCredentialStore(<String, String>{
        'gemini': 'AIza-test',
        'openai': 'sk-test',
      }),
      onUsageRecorded: (provider, modelId, usage) {
        recorded.add((provider, modelId, usage));
      },
    );

    const manualSettings = AppSettings(
      selectedAiProvider: AiProviderType.gemini,
      fallbackEnabled: false,
    );
    final candidates = await router.resolveCandidates(
      settings: manualSettings,
      promptText: 'Write a complex distributed consensus algorithm in Dart',
    );
    expect(candidates.length, 1);
    expect(candidates.first.target.provider, AiProviderType.gemini);

    // With fallbackEnabled=true, it falls back and records usage on OpenAI
    final fallbackCandidates = await router.resolveCandidates(
      settings: manualSettings.copyWith(fallbackEnabled: true),
      promptText: 'Hello',
    );
    expect(fallbackCandidates.length, 2);
    expect(fallbackCandidates.first.target.provider, AiProviderType.gemini);
    expect(fallbackCandidates[1].target.provider, AiProviderType.openAi);

    final response = await router.routeAndGenerate(
      completionRequest: AiCompletionRequest(
        provider: AiProviderType.gemini,
        modelId: AiProviderType.gemini.defaultModel,
        messages: const [],
        responseLanguage: VoiceLanguage.english,
      ),
      settings: manualSettings.copyWith(fallbackEnabled: true),
      promptText: 'Hello',
    );
    expect(response.provider, AiProviderType.openAi);
    expect(response.routingNotice, contains('Fallback active'));
    expect(recorded.length, 1);
    expect(recorded.first.$1, AiProviderType.openAi);
    expect(recorded.first.$3?.inputTokens, 12);
    expect(recorded.first.$3?.outputTokens, 28);
  });

  test('Wave 1 UsageStatsController persists per-provider/model counters and clears cleanly', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(usageStatsControllerProvider.notifier);
    await notifier.recordUsage(
      provider: AiProviderType.gemini,
      modelId: 'gemini-3.5-flash-lite',
      usage: const AIUsage(inputTokens: 100, outputTokens: 250),
    );
    await notifier.recordUsage(
      provider: AiProviderType.gemini,
      modelId: 'gemini-3.5-flash-lite',
      usage: const AIUsage(inputTokens: 50, outputTokens: 75),
    );

    final stats = container.read(usageStatsControllerProvider);
    expect(stats.totalRequests, 2);
    expect(stats.totalInputTokens, 150);
    expect(stats.totalOutputTokens, 325);
    expect(stats.requestsForProvider('gemini'), 2);

    // Reload into fresh container to verify persistence
    final reloadedContainer = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(reloadedContainer.dispose);
    final reloaded = reloadedContainer.read(usageStatsControllerProvider);
    expect(reloaded.totalRequests, 2);
    expect(reloaded.totalTokens, 475);

    await reloadedContainer
        .read(usageStatsControllerProvider.notifier)
        .clearUsage();
    expect(
      reloadedContainer.read(usageStatsControllerProvider).totalRequests,
      0,
    );
  });

  test('Wave 1 ChatRepositoryImpl is session-only by default and persists only when opted in', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final localDataSource = ChatLocalDataSource(prefs);
    final router = AIRouter(
      registry: AIProviderRegistry(<AiProviderType, AIProvider>{
        AiProviderType.gemini: _FakeProvider(
          providerType: AiProviderType.gemini,
        ),
      }),
      credentialStore: _InMemoryCredentialStore(<String, String>{
        'gemini': 'AIza-test',
      }),
    );

    var saveHistory = false;
    final repo = ChatRepositoryImpl(
      localDataSource,
      router,
      _AlwaysOnlineService(),
      isHistoryPersistenceEnabled: () => saveHistory,
    );

    await repo.recordLocalActionExchange(
      userPrompt: 'Open Settings',
      assistantReply: 'Opened Settings.',
      provider: AiProviderType.gemini,
    );
    expect(repo.getMessages().length, 2);
    expect(prefs.getString(StorageKeys.chatHistory), isNull);

    // Opt in -> subsequent exchange persists
    saveHistory = true;
    await repo.recordLocalActionExchange(
      userPrompt: 'Set alarm 7 AM',
      assistantReply: 'Alarm set.',
      provider: AiProviderType.gemini,
    );
    expect(prefs.getString(StorageKeys.chatHistory), isNotNull);
  });
}
