import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/errors/app_exception.dart';
import 'package:vision_ai/core/telemetry/performance_telemetry.dart';
import 'package:vision_ai/core/utils/secure_storage_provider.dart';
import 'package:vision_ai/features/chat/domain/entities/ai_completion_request.dart';
import 'package:vision_ai/features/chat/domain/entities/ai_model_config.dart';
import 'package:vision_ai/features/chat/domain/entities/ai_models.dart';
import 'package:vision_ai/features/chat/domain/repositories/ai_provider.dart';
import 'package:vision_ai/features/chat/domain/services/provider_fallback_manager.dart';
import 'package:vision_ai/features/chat/domain/services/provider_health_manager.dart';
import 'package:vision_ai/features/chat/domain/services/task_complexity_classifier.dart';
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

typedef ResolvedRouteCandidate = ({
  AIRouteTarget target,
  String apiKey,
  AIProvider client,
});

/// Multi-provider AI router supporting manual selection, capability-aware
/// task routing, circuit-breaker health tracking, and explicit fallback.
class AIRouter {
  const AIRouter({
    required this._registry,
    required this._credentialStore,
    this._healthManager,
    this._telemetry,
  });

  final AIProviderRegistry _registry;
  final SecureCredentialStore _credentialStore;
  final ProviderHealthManager? _healthManager;
  final TelemetryNotifier? _telemetry;

  /// Resolves ordered `(provider, modelId)` candidates based on [settings],
  /// task complexity, provider health, and stored API keys.
  Future<List<ResolvedRouteCandidate>> resolveCandidates({
    required AppSettings settings,
    required String promptText,
    AiProviderType? explicitProvider,
    String? explicitModelId,
  }) async {
    final complexity = TaskComplexityClassifier.classify(promptText);
    final orderedTargets = <AIRouteTarget>[];
    final primaryProvider = explicitProvider ?? settings.selectedAiProvider;

    if (explicitProvider == null && settings.autoRoutingEnabled) {
      orderedTargets.addAll(_computeAutoRouteOrder(settings, complexity));
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
      final fallbackCandidates = ProviderFallbackManager.orderCandidates(
        preferredProvider: primaryProvider,
        configuredEnabledProviders: AiProviderType.values
            .where(settings.isProviderEnabled)
            .toSet(),
        autoRoutingEnabled: settings.autoRoutingEnabled,
        fallbackEnabled: settings.fallbackEnabled,
        complexity: complexity,
        healthManager: _healthManager,
      );
      for (final candidate in fallbackCandidates) {
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

    // Resolve keys concurrently to minimize pre-request Keystore overhead.
    final keyFutures = <Future<String?>>[
      for (final target in orderedTargets)
        _credentialStore.readApiKey(target.provider.id),
    ];
    final keys = await Future.wait(keyFutures);

    final resolved = <ResolvedRouteCandidate>[];
    for (var i = 0; i < orderedTargets.length; i++) {
      final target = orderedTargets[i];
      final client = _registry.getProvider(target.provider);
      final apiKey = keys[i];
      if (client == null || apiKey == null) continue;
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

  /// Executes a non-streaming completion with health tracking & fallback reporting.
  Future<AIResponse> routeAndGenerate({
    required AiCompletionRequest completionRequest,
    required AppSettings settings,
    required String promptText,
    AICancellationToken? cancellationToken,
    List<ResolvedRouteCandidate>? preResolvedCandidates,
  }) async {
    final startupSw = Stopwatch()..start();
    final candidates =
        preResolvedCandidates ??
        await resolveCandidates(
          settings: settings,
          promptText: promptText,
          explicitProvider: settings.autoRoutingEnabled
              ? null
              : completionRequest.provider,
          explicitModelId: settings.autoRoutingEnabled
              ? null
              : completionRequest.modelId,
        );
    startupSw.stop();
    final startupMs = startupSw.elapsedMilliseconds;

    AIError? lastError;
    final primary = candidates.first.target;

    for (var i = 0; i < candidates.length; i++) {
      final candidate = candidates[i];
      final isFallback = i > 0;
      final req = completionRequest.copyWithModel(
        provider: candidate.target.provider,
        modelId: candidate.target.modelId,
      );

      final sw = Stopwatch()..start();
      try {
        final response = await candidate.client.generate(
          req.toAiRequest(),
          apiKey: candidate.apiKey,
          cancellationToken: cancellationToken,
        );
        sw.stop();
        _healthManager?.recordSuccess(
          candidate.target.provider,
          latencyMs: sw.elapsedMilliseconds,
        );
        _telemetry?.recordAiLatency(
          candidate.target.provider,
          candidate.target.modelId,
          startupMs: startupMs,
          totalMs: sw.elapsedMilliseconds,
          firstTokenMs: sw.elapsedMilliseconds,
          success: true,
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
        sw.stop();
        lastError = error;
        _healthManager?.recordFailure(candidate.target.provider, error);
        _telemetry?.recordAiLatency(
          candidate.target.provider,
          candidate.target.modelId,
          totalMs: sw.elapsedMilliseconds,
          success: false,
        );
        _telemetry?.recordSanitizedError(
          candidate.target.provider.displayName,
          error,
        );
        if (!error.allowsProviderFallback ||
            !ProviderFallbackManager.shouldFallbackForError(error) ||
            i == candidates.length - 1) {
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
    List<ResolvedRouteCandidate>? preResolvedCandidates,
  }) async* {
    final startupSw = Stopwatch()..start();
    final candidates =
        preResolvedCandidates ??
        await resolveCandidates(
          settings: settings,
          promptText: promptText,
          explicitProvider: settings.autoRoutingEnabled
              ? null
              : completionRequest.provider,
          explicitModelId: settings.autoRoutingEnabled
              ? null
              : completionRequest.modelId,
        );
    startupSw.stop();
    final startupMs = startupSw.elapsedMilliseconds;

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
      int? firstTokenMs;
      final sw = Stopwatch()..start();
      try {
        await for (final chunk in candidate.client.stream(
          req.toAiRequest(),
          apiKey: candidate.apiKey,
          cancellationToken: cancellationToken,
        )) {
          if (chunk is AITextDeltaChunk || chunk is AIToolCallChunk) {
            firstTokenMs ??= sw.elapsedMilliseconds;
            emittedAnyToken = true;
            yield chunk;
          } else if (chunk is AICompletedChunk) {
            sw.stop();
            _healthManager?.recordSuccess(
              candidate.target.provider,
              latencyMs: sw.elapsedMilliseconds,
            );
            _telemetry?.recordAiLatency(
              candidate.target.provider,
              candidate.target.modelId,
              startupMs: startupMs,
              totalMs: sw.elapsedMilliseconds,
              firstTokenMs: firstTokenMs ?? sw.elapsedMilliseconds,
              success: true,
            );
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
        sw.stop();
        lastError = error;
        _healthManager?.recordFailure(candidate.target.provider, error);
        _telemetry?.recordAiLatency(
          candidate.target.provider,
          candidate.target.modelId,
          totalMs: sw.elapsedMilliseconds,
          firstTokenMs: firstTokenMs,
          success: false,
        );
        _telemetry?.recordSanitizedError(
          candidate.target.provider.displayName,
          error,
        );
        if (emittedAnyToken ||
            !error.allowsProviderFallback ||
            !ProviderFallbackManager.shouldFallbackForError(error) ||
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
    TaskComplexityTier complexity,
  ) {
    final enabledProviders = AiProviderType.values
        .where(settings.isProviderEnabled)
        .toSet();
    final ordered = ProviderFallbackManager.orderCandidates(
      preferredProvider: settings.selectedAiProvider,
      configuredEnabledProviders: enabledProviders,
      autoRoutingEnabled: true,
      fallbackEnabled: settings.fallbackEnabled,
      complexity: complexity,
      healthManager: _healthManager,
    );

    return ordered
        .map((provider) {
          final configuredModel = settings.modelForProvider(provider);
          final recommended = AIModelRegistry.recommendModelFor(
            provider,
            complexity: complexity,
            userSelectedModelId: configuredModel,
          );
          final reason = switch (complexity) {
            TaskComplexityTier.deepReasoningCoding =>
              'Routed for deep reasoning/coding',
            TaskComplexityTier.balancedMultilingual =>
              'Routed for multilingual conversation',
            TaskComplexityTier.simpleFast => 'Routed for low-latency response',
          };
          return AIRouteTarget(
            provider: provider,
            modelId: recommended.modelId,
            reason: reason,
          );
        })
        .toList(growable: false);
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
      return '${actual.reason}: ${actual.provider.displayName} (${actual.modelId}).';
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
      personalMemoryContext: personalMemoryContext,
      deviceContextSummary: deviceContextSummary,
    );
  }
}
