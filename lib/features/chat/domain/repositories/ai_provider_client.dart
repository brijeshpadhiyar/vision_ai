import 'package:vision_ai/features/chat/domain/entities/ai_completion_request.dart';
import 'package:vision_ai/features/settings/domain/entities/ai_provider_type.dart';

/// Unified adapter interface implemented by each AI provider remote data source.
abstract interface class AiProviderClient {
  /// The provider backend handled by this client.
  AiProviderType get providerType;

  /// Executes a live completion call using the provided [apiKey] and returns the reply text.
  Future<String> generateReply({
    required AiCompletionRequest request,
    required String apiKey,
  });
}
