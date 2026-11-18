import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/errors/app_exception.dart';
import 'package:vision_ai/core/utils/secure_storage_provider.dart';
import 'package:vision_ai/features/chat/domain/entities/ai_completion_request.dart';
import 'package:vision_ai/features/chat/domain/entities/ai_model_config.dart';
import 'package:vision_ai/features/chat/domain/entities/ai_models.dart';
import 'package:vision_ai/features/chat/domain/repositories/ai_provider.dart';
import 'package:vision_ai/features/settings/domain/entities/ai_provider_type.dart';
import 'package:vision_ai/features/settings/domain/entities/app_settings.dart';

/// Candidate `(provider, modelId)` pair evaluated by [AIRouter].
@immutable
class AIRouteTarget {
  const AIRouteTarget({
    required this.provider,
    required this.modelId,
    required this.reason,
  });

  final AiProviderType provider;
  final String modelId;
  final String reason;
}

/// Multi-provider AI router supporting manual selection, automatic task-based
/// routing, and transparent fallback across enabled providers.
class AIRouter {
  const AIRouter({required this._registry, required this._credentialStore});

  final AIProviderRegistry _registry;
  final SecureCredentialStore _credentialStore;

  /// Resolves ordered `(provider, modelId)` candidates based on [settings]
  /// and prompt characteristics.
  Future<List<({AIRouteTarget target, String apiKey, AIProvider client})>>
  resolveCandidates({
    required AppSettings settings,
    required String promptText,
    AiProviderType? explicitProvider,
    String? explicitModelId,
  }) async {
    final orderedTargets = <AIRouteTarget>[];
    final primaryProvider = explicitProvider ?? settings.selectedAiProvider;

    if (explicitProvider == null && settings.autoRoutingEnabled) {
      orderedTargets.addAll(_computeAutoRouteOrder(settings, promptText));
    } else if (settings.isProviderEnabled(primaryProvider)) {
      orderedTargets.add(
        AIRouteTarget(
          provider: primaryProvider,
          modelId:
              explicitModelId ?? settings.modelForProvider(primaryProvider),
          reason: 'Primary selection',
        ),
      );
    }

    if (settings.fallbackEnabled) {
      for (final candidate in AiProviderType.values) {
        if (!settings.isProviderEnabled(candidate)) continue;
        if (orderedTargets.any((t) => t.provider == candidate)) continue;
        orderedTargets.add(
          AIRouteTarget(
            provider: candidate,
            modelId: settings.modelForProvider(candidate),
            reason: 'Fallback provider',
          ),
        );
      }
    }

    if (orderedTargets.isEmpty) {
      throw const ConfigurationException(
        message: 'No AI providers are currently enabled. Enable at least one provider in Settings.',
      );
    }

    final resolved =
        <({AIRouteTarget target, String apiKey, AIProvider client})>[];
    for (final target in orderedTargets) {
      final client = _registry.getProvider(target.provider);
      if (client == null) continue;
      final apiKey = await _credentialStore.readApiKey(target.provider.id);
      if (apiKey == null) continue;
      resolved.add((target: target, apiKey: apiKey, client: client));
    }

    if (resolved.isEmpty) {
      throw MissingApiKeyException(
        providerId: primaryProvider.id,
        providerName: primaryProvider.displayName,
      );
    }

    return resolved;
  }

  /// Executes a non-streaming completion with explicit fallback reporting.
  Future<AIResponse> routeAndGenerate({
    required AiCompletionRequest completionRequest,
    required AppSettings settings,
    required String promptText,
    AICancellationToken? cancellationToken,
  }) async {
    final candidates = await resolveCandidates(
      settings: settings,
      promptText: promptText,
      explicitProvider: settings.autoRoutingEnabled
          ? null
          : completionRequest.provider,
      explicitModelId: settings.autoRoutingEnabled
          ? null
          : completionRequest.modelId,
    );

    AIError? lastError;
    final primary = candidates.first.target;

    for (var i = 0; i < candidates.length; i++) {
      final candidate = candidates[i];
      final isFallback = i > 0;
      final req = completionRequest.copyWithModel(
        provider: candidate.target.provider,
        modelId: candidate.target.modelId,
      );

      try {
        final response = await candidate.client.generate(
          req.toAiRequest(),
          apiKey: candidate.apiKey,
          cancellationToken: cancellationToken,
        );
        final notice = _buildRoutingNotice(
          settings: settings,
          primary: primary,
          actual: candidate.target,
          isFallback: isFallback,
          previousError: lastError,
        );
        return AIResponse(
          text: response.text,
          provider: response.provider,
          modelId: response.modelId,
          usage: response.usage,
          toolCalls: response.toolCalls,
          latency: response.latency,
          finishReason: response.finishReason,
          responseId: response.responseId,
          routingNotice: notice,
        );
      } on AIError catch (error) {
        lastError = error;
        if (!error.allowsProviderFallback || i == candidates.length - 1) {
          rethrow;
        }
      }
    }

    throw lastError!;
  }

  /// Streams incremental chunks with transparent fallback if the primary
  /// provider fails before emitting any content chunks.
  Stream<AIStreamChunk> routeAndStream({
    required AiCompletionRequest completionRequest,
    required AppSettings settings,
    required String promptText,
    AICancellationToken? cancellationToken,
  }) async* {
    final candidates = await resolveCandidates(
      settings: settings,
      promptText: promptText,
      explicitProvider: settings.autoRoutingEnabled
          ? null
          : completionRequest.provider,
      explicitModelId: settings.autoRoutingEnabled
          ? null
          : completionRequest.modelId,
    );

    final primary = candidates.first.target;
    AIError? lastError;

    for (var i = 0; i < candidates.length; i++) {
      final candidate = candidates[i];
      final isFallback = i > 0;
      final req = completionRequest.copyWithModel(
        provider: candidate.target.provider,
        modelId: candidate.target.modelId,
      );

      var emittedAnyToken = false;
      try {
        await for (final chunk in candidate.client.stream(
          req.toAiRequest(),
          apiKey: candidate.apiKey,
          cancellationToken: cancellationToken,
        )) {
          if (chunk is AITextDeltaChunk || chunk is AIToolCallChunk) {
            emittedAnyToken = true;
            yield chunk;
          } else if (chunk is AICompletedChunk) {
            final r = chunk.response;
            final notice = _buildRoutingNotice(
              settings: settings,
              primary: primary,
              actual: candidate.target,
              isFallback: isFallback,
              previousError: lastError,
            );
            yield AICompletedChunk(
              AIResponse(
                text: r.text,
                provider: r.provider,
                modelId: r.modelId,
                usage: r.usage,
                toolCalls: r.toolCalls,
                latency: r.latency,
                finishReason: r.finishReason,
                responseId: r.responseId,
                routingNotice: notice,
              ),
            );
          }
        }
        return;
      } on AIError catch (error) {
        lastError = error;
        if (emittedAnyToken ||
            !error.allowsProviderFallback ||
            i == candidates.length - 1) {
          rethrow;
        }
      }
    }

    if (lastError != null) {
      throw lastError;
    }
  }

  List<AIRouteTarget> _computeAutoRouteOrder(
    AppSettings settings,
    String promptText,
  ) {
    final lower = promptText.toLowerCase();
    final isHeavyCodingOrReasoning =
        promptText.length > 220 ||
        lower.contains('code') ||
        lower.contains('debug') ||
        lower.contains('architecture') ||
        lower.contains('compare') ||
        lower.contains('analyze') ||
        lower.contains('explain in detail');

    final preferredOrder = isHeavyCodingOrReasoning
        ? <AiProviderType>[
            AiProviderType.claude,
            AiProviderType.openAi,
            AiProviderType.gemini,
          ]
        : <AiProviderType>[
            settings.selectedAiProvider,
            AiProviderType.gemini,
            AiProviderType.openAi,
            AiProviderType.claude,
          ];

    final targets = <AIRouteTarget>[];
    final seen = <AiProviderType>{};
    for (final provider in preferredOrder) {
      if (!seen.add(provider) || !settings.isProviderEnabled(provider)) {
        continue;
      }
      final configuredModel = settings.modelForProvider(provider);
      final chosenModel = isHeavyCodingOrReasoning
          ? _selectCapableModel(provider, configuredModel)
          : configuredModel;
      targets.add(
        AIRouteTarget(
          provider: provider,
          modelId: chosenModel,
          reason: isHeavyCodingOrReasoning
              ? 'Auto-routed for complex reasoning/coding'
              : 'Auto-routed for fast response',
        ),
      );
    }
    return targets;
  }

  String _selectCapableModel(AiProviderType provider, String configuredModel) {
    final models = AIModelRegistry.modelsForProvider(provider);
    final configured = AIModelRegistry.resolveModel(provider, configuredModel);
    if (configured.tier != AiModelTier.fast) {
      return configured.modelId;
    }
    for (final model in models) {
      if (model.tier == AiModelTier.balanced ||
          model.tier == AiModelTier.flagship) {
        return model.modelId;
      }
    }
    return configuredModel;
  }

  String? _buildRoutingNotice({
    required AppSettings settings,
    required AIRouteTarget primary,
    required AIRouteTarget actual,
    required bool isFallback,
    required AIError? previousError,
  }) {
    if (isFallback) {
      return 'Fallback active: ${primary.provider.displayName} unavailable '
          '(${previousError?.kind.name ?? 'error'}). Answered using '
          '${actual.provider.displayName} (${actual.modelId}).';
    }
    if (settings.autoRoutingEnabled &&
        (actual.provider != settings.selectedAiProvider ||
            actual.modelId != settings.modelForProvider(actual.provider))) {
      return 'Auto-routed to ${actual.provider.displayName} (${actual.modelId}).';
    }
    return null;
  }
}

extension on AiCompletionRequest {
  AiCompletionRequest copyWithModel({
    required AiProviderType provider,
    required String modelId,
  }) {
    return AiCompletionRequest(
      provider: provider,
      modelId: modelId,
      messages: messages,
      responseLanguage: responseLanguage,
      temperature: temperature,
      maxOutputTokens: maxOutputTokens,
      enableDeviceActions: enableDeviceActions,
    );
  }
}
