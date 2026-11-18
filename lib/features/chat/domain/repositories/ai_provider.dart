import 'package:vision_ai/features/chat/domain/entities/ai_models.dart';
import 'package:vision_ai/features/settings/domain/entities/ai_provider_type.dart';

/// Provider-independent contract for all AI backends (Gemini, OpenAI, Claude).
abstract interface class AIProvider {
  AiProviderType get providerType;

  String get providerName;

  /// Executes a single-shot completion request and returns a normalized [AIResponse].
  Future<AIResponse> generate(
    AIRequest request, {
    required String apiKey,
    AICancellationToken? cancellationToken,
  });

  /// Streams incremental text deltas, tool calls, and the final [AIResponse].
  Stream<AIStreamChunk> stream(
    AIRequest request, {
    required String apiKey,
    AICancellationToken? cancellationToken,
  });

  /// Executes a real authenticated probe against the provider API.
  ///
  /// Must never return `connected: true` without a verified 2xx API response.
  Future<AIConnectionTestResult> testConnection({
    required String apiKey,
    String? modelId,
    AICancellationToken? cancellationToken,
  });

  /// Fetches live model identifiers visible to [apiKey], when supported.
  Future<List<String>> listAvailableModels({
    required String apiKey,
    AICancellationToken? cancellationToken,
  });
}

/// Registry holding configured [AIProvider] implementations keyed by [AiProviderType].
class AIProviderRegistry {
  AIProviderRegistry(Map<AiProviderType, AIProvider> providers)
    : _providers = Map<AiProviderType, AIProvider>.unmodifiable(providers);

  final Map<AiProviderType, AIProvider> _providers;

  AIProvider? getProvider(AiProviderType type) => _providers[type];

  List<AIProvider> get allProviders =>
      List<AIProvider>.unmodifiable(_providers.values);

  bool contains(AiProviderType type) => _providers.containsKey(type);
}
