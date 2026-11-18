import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/utils/app_logger.dart';
import 'package:vision_ai/core/utils/secure_storage_provider.dart';
import 'package:vision_ai/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:vision_ai/features/chat/domain/entities/ai_models.dart';
import 'package:vision_ai/features/settings/domain/entities/ai_provider_type.dart';
import 'package:vision_ai/features/settings/presentation/controllers/api_key_controller.dart';
import 'package:vision_ai/features/settings/presentation/controllers/settings_controller.dart';

/// Live connection state and discovered models for a single AI provider.
@immutable
class ProviderRuntimeStatus {
  const ProviderRuntimeStatus({
    required this.provider,
    this.connectionState = ProviderConnectionState.untested,
    this.statusMessage = 'Not tested yet',
    this.testedModelId,
    this.latency,
    this.availableModels = const <String>[],
    this.testedAt,
  });

  final AiProviderType provider;
  final ProviderConnectionState connectionState;
  final String statusMessage;
  final String? testedModelId;
  final Duration? latency;
  final List<String> availableModels;
  final DateTime? testedAt;

  ProviderRuntimeStatus copyWith({
    ProviderConnectionState? connectionState,
    String? statusMessage,
    String? testedModelId,
    Duration? latency,
    List<String>? availableModels,
    DateTime? testedAt,
  }) {
    return ProviderRuntimeStatus(
      provider: provider,
      connectionState: connectionState ?? this.connectionState,
      statusMessage: statusMessage ?? this.statusMessage,
      testedModelId: testedModelId ?? this.testedModelId,
      latency: latency ?? this.latency,
      availableModels: availableModels ?? this.availableModels,
      testedAt: testedAt ?? this.testedAt,
    );
  }
}

final providerConnectionControllerProvider =
    NotifierProvider<
      ProviderConnectionController,
      Map<AiProviderType, ProviderRuntimeStatus>
    >(ProviderConnectionController.new);

/// Executes real authenticated provider probes so "Connected" is only shown
/// after a verified API request succeeds.
class ProviderConnectionController
    extends Notifier<Map<AiProviderType, ProviderRuntimeStatus>> {
  final Map<AiProviderType, ProviderRuntimeStatus> _cachedStatuses =
      <AiProviderType, ProviderRuntimeStatus>{};

  @override
  Map<AiProviderType, ProviderRuntimeStatus> build() {
    final settings = ref.watch(settingsControllerProvider);
    final keyMap =
        ref.watch(apiKeyStatusControllerProvider).asData?.value ??
        const <AiProviderType, bool>{};

    final initial = <AiProviderType, ProviderRuntimeStatus>{};
    for (final provider in AiProviderType.values) {
      final hasKey = keyMap[provider] ?? false;
      final enabled = settings.isProviderEnabled(provider);
      final current = _cachedStatuses[provider];
      if (!enabled) {
        initial[provider] = ProviderRuntimeStatus(
          provider: provider,
          connectionState: ProviderConnectionState.disabled,
          statusMessage: 'Disabled in settings',
          availableModels: current?.availableModels ?? const <String>[],
        );
      } else if (!hasKey) {
        initial[provider] = ProviderRuntimeStatus(
          provider: provider,
          connectionState: ProviderConnectionState.missingKey,
          statusMessage: 'API key missing',
        );
      } else if (current != null &&
          current.connectionState == ProviderConnectionState.connected &&
          current.testedModelId == settings.modelForProvider(provider)) {
        initial[provider] = current;
      } else {
        initial[provider] = ProviderRuntimeStatus(
          provider: provider,
          connectionState: ProviderConnectionState.untested,
          statusMessage: 'Key saved • Tap Test Connection to verify',
          availableModels: current?.availableModels ?? const <String>[],
        );
      }
      _cachedStatuses[provider] = initial[provider]!;
    }
    return Map<AiProviderType, ProviderRuntimeStatus>.unmodifiable(initial);
  }

  /// Runs a real authenticated API test against [provider] using its stored
  /// encrypted key and currently selected model.
  Future<AIConnectionTestResult> testProviderConnection(
    AiProviderType provider,
  ) async {
    final settings = ref.read(settingsControllerProvider);
    final modelId = settings.modelForProvider(provider);
    final logger = ref.read(appLoggerProvider);

    final apiKey = await ref
        .read(secureCredentialStoreProvider)
        .readApiKey(provider.id);
    if (apiKey == null) {
      final result = AIConnectionTestResult(
        provider: provider,
        modelId: modelId,
        connected: false,
        message: 'No API key configured for ${provider.displayName}.',
        testedAt: DateTime.now(),
        errorKind: AIErrorKind.invalidApiKey,
      );
      _updateStatus(
        provider,
        ProviderRuntimeStatus(
          provider: provider,
          connectionState: ProviderConnectionState.missingKey,
          statusMessage: result.message,
          testedAt: result.testedAt,
        ),
      );
      return result;
    }

    final client = ref.read(aiProviderRegistryProvider).getProvider(provider);
    if (client == null) {
      final result = AIConnectionTestResult(
        provider: provider,
        modelId: modelId,
        connected: false,
        message: 'Provider client not registered for ${provider.displayName}.',
        testedAt: DateTime.now(),
      );
      _updateStatus(
        provider,
        ProviderRuntimeStatus(
          provider: provider,
          connectionState: ProviderConnectionState.failed,
          statusMessage: result.message,
          testedAt: result.testedAt,
        ),
      );
      return result;
    }

    _updateStatus(
      provider,
      ProviderRuntimeStatus(
        provider: provider,
        connectionState: ProviderConnectionState.testing,
        statusMessage: 'Testing $modelId...',
        testedModelId: modelId,
      ),
    );

    final result = await client.testConnection(
      apiKey: apiKey,
      modelId: modelId,
    );

    _updateStatus(
      provider,
      ProviderRuntimeStatus(
        provider: provider,
        connectionState: result.connected
            ? ProviderConnectionState.connected
            : ProviderConnectionState.failed,
        statusMessage: result.message,
        testedModelId: result.modelId,
        latency: result.latency,
        availableModels: result.availableModels,
        testedAt: result.testedAt,
      ),
    );

    logger.info(
      'Connection test for ${provider.displayName} (${result.modelId}): '
      '${result.connected ? 'CONNECTED' : 'FAILED'} — ${result.message}',
    );
    return result;
  }

  /// Marks a provider status as untested after its API key changes.
  void invalidateProvider(AiProviderType provider) {
    _updateStatus(
      provider,
      ProviderRuntimeStatus(
        provider: provider,
        connectionState: ProviderConnectionState.untested,
        statusMessage: 'Key updated • Tap Test Connection to verify',
      ),
    );
  }

  void _updateStatus(AiProviderType provider, ProviderRuntimeStatus status) {
    _cachedStatuses[provider] = status;
    final next = <AiProviderType, ProviderRuntimeStatus>{
      ...state,
      provider: status,
    };
    state = Map<AiProviderType, ProviderRuntimeStatus>.unmodifiable(next);
  }
}
