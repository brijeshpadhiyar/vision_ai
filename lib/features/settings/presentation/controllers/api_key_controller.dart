import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vision_ai/core/utils/app_logger.dart';
import 'package:vision_ai/core/utils/secure_storage_provider.dart';
import 'package:vision_ai/features/settings/domain/entities/ai_provider_type.dart';

/// Tracks which [AiProviderType] backends currently have an encrypted API key stored.
final apiKeyStatusControllerProvider =
    AsyncNotifierProvider<ApiKeyStatusController, Map<AiProviderType, bool>>(
      ApiKeyStatusController.new,
    );

/// Manages inspection, saving, and deletion of encrypted AI provider API keys.
class ApiKeyStatusController extends AsyncNotifier<Map<AiProviderType, bool>> {
  @override
  Future<Map<AiProviderType, bool>> build() async {
    return _loadStatuses();
  }

  Future<Map<AiProviderType, bool>> _loadStatuses() async {
    final store = ref.watch(secureCredentialStoreProvider);
    final result = <AiProviderType, bool>{};
    for (final provider in AiProviderType.values) {
      try {
        result[provider] = await store.hasApiKey(provider.id);
      } on Exception catch (error, stackTrace) {
        ref
            .read(appLoggerProvider)
            .warning(
              'Could not verify keystore status for ${provider.displayName}',
              error: error,
              stackTrace: stackTrace,
            );
        result[provider] = false;
      }
    }
    return Map<AiProviderType, bool>.unmodifiable(result);
  }

  /// Encrypts and persists [apiKey] for [provider] in Android Keystore.
  Future<void> saveApiKey({
    required AiProviderType provider,
    required String apiKey,
  }) async {
    final store = ref.read(secureCredentialStoreProvider);
    await store.saveApiKey(providerId: provider.id, apiKey: apiKey);
    ref
        .read(appLoggerProvider)
        .info('Saved encrypted API key for ${provider.displayName}');
    state = AsyncData(await _loadStatuses());
  }

  /// Removes the stored encrypted API key for [provider].
  Future<void> removeApiKey(AiProviderType provider) async {
    final store = ref.read(secureCredentialStoreProvider);
    await store.deleteApiKey(provider.id);
    ref
        .read(appLoggerProvider)
        .info('Removed encrypted API key for ${provider.displayName}');
    state = AsyncData(await _loadStatuses());
  }
}
