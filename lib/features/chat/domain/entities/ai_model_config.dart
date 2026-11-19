import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/features/chat/domain/services/task_complexity_classifier.dart';
import 'package:vision_ai/features/settings/domain/entities/ai_provider_type.dart';

/// Capabilities supported by a configured AI model.
enum AiCapability { text, streaming, toolCalling, multimodalVision, reasoning }

/// Relative API token cost tier for intelligent routing trade-offs.
enum AiCostTier { economy, standard, premium }

/// Centralized model metadata and endpoint specification for an AI model.
@immutable
class AiModelConfig {
  const AiModelConfig({
    required this.provider,
    required this.modelId,
    required this.displayName,
    required this.endpointUrl,
    required this.capabilities,
    this.contextWindowTokens = 128000,
    this.maxOutputTokens = 4096,
    this.supportsTemperature = true,
    this.isDefault = false,
    this.isCustom = false,
    this.tier = AiModelTier.balanced,
    this.reasoningScore = 7,
    this.multilingualScore = 8,
    this.costTier = AiCostTier.standard,
  });

  final AiProviderType provider;
  final String modelId;
  final String displayName;
  final String endpointUrl;
  final Set<AiCapability> capabilities;
  final int contextWindowTokens;
  final int maxOutputTokens;
  final bool supportsTemperature;
  final bool isDefault;
  final bool isCustom;
  final AiModelTier tier;
  final int reasoningScore;
  final int multilingualScore;
  final AiCostTier costTier;

  bool get supportsStreaming => capabilities.contains(AiCapability.streaming);
  bool get supportsTools => capabilities.contains(AiCapability.toolCalling);
  bool get supportsVision =>
      capabilities.contains(AiCapability.multimodalVision);
  bool get supportsReasoning => capabilities.contains(AiCapability.reasoning);
}

/// Latency/capability tier used by [AIRouter] during automatic model routing.
enum AiModelTier { fast, balanced, flagship }

/// Centralized catalog of supported AI models and deprecated model migrations.
///
/// No retired model IDs (such as `gemini-2.5-flash` or `claude-3-5-haiku-latest`)
/// are registered as defaults.
abstract final class AIModelRegistry {
  static const String geminiBaseEndpoint =
      'https://generativelanguage.googleapis.com/v1beta';
  static const String openAiResponsesEndpoint =
      'https://api.openai.com/v1/responses';
  static const String openAiModelsEndpoint = 'https://api.openai.com/v1/models';
  static const String claudeMessagesEndpoint =
      'https://api.anthropic.com/v1/messages';
  static const String claudeModelsEndpoint =
      'https://api.anthropic.com/v1/models';

  /// Known deprecated/retired model IDs mapped to their recommended replacement.
  static const Map<String, String> deprecatedModelReplacements =
      <String, String>{
        'gemini-2.5-flash': 'gemini-3.5-flash-lite',
        'models/gemini-2.5-flash': 'gemini-3.5-flash-lite',
        'gemini-2.0-flash': 'gemini-3.5-flash-lite',
        'gemini-1.5-flash': 'gemini-3.5-flash-lite',
        'gemini-1.5-pro': 'gemini-3.8-flash',
        'gpt-4o-mini': 'gpt-5.4-mini',
        'gpt-4o': 'gpt-5.4',
        'gpt-4.1-mini': 'gpt-5.4-mini',
        'claude-3-5-haiku-latest': 'claude-haiku-5-5',
        'claude-3-5-sonnet-latest': 'claude-sonnet-5-5',
        'claude-3-7-sonnet-20250219': 'claude-sonnet-5-5',
      };

  static const List<AiModelConfig> _catalog = <AiModelConfig>[
    // On-Device Edge AI (flutter_edge_ai / Gemini Nano via Android AICore)
    AiModelConfig(
      provider: AiProviderType.edgeAi,
      modelId: 'gemini-nano',
      displayName: 'Gemini Nano (On-Device)',
      endpointUrl: 'on-device://android-aicore/gemini-nano',
      capabilities: <AiCapability>{
        AiCapability.text,
        AiCapability.streaming,
      },
      contextWindowTokens: 4096,
      maxOutputTokens: 1024,
      isDefault: true,
      tier: AiModelTier.fast,
      reasoningScore: 6,
      multilingualScore: 7,
      costTier: AiCostTier.economy,
    ),
    // Google Gemini
    AiModelConfig(
      provider: AiProviderType.gemini,
      modelId: 'gemini-3.5-flash-lite',
      displayName: 'Gemini 3.5 Flash-Lite',
      endpointUrl: '$geminiBaseEndpoint/models/gemini-3.5-flash-lite',
      capabilities: <AiCapability>{
        AiCapability.text,
        AiCapability.streaming,
        AiCapability.toolCalling,
        AiCapability.multimodalVision,
      },
      contextWindowTokens: 1000000,
      maxOutputTokens: 8192,
      isDefault: true,
      tier: AiModelTier.fast,
    ),
    AiModelConfig(
      provider: AiProviderType.gemini,
      modelId: 'gemini-3.8-flash',
      displayName: 'Gemini 3.8 Flash',
      endpointUrl: '$geminiBaseEndpoint/models/gemini-3.8-flash',
      capabilities: <AiCapability>{
        AiCapability.text,
        AiCapability.streaming,
        AiCapability.toolCalling,
        AiCapability.multimodalVision,
        AiCapability.reasoning,
      },
      contextWindowTokens: 1000000,
      maxOutputTokens: 8192,
      tier: AiModelTier.balanced,
    ),
    AiModelConfig(
      provider: AiProviderType.gemini,
      modelId: 'gemini-4-argon',
      displayName: 'Gemini 4 Argon',
      endpointUrl: '$geminiBaseEndpoint/models/gemini-4-argon',
      capabilities: <AiCapability>{
        AiCapability.text,
        AiCapability.streaming,
        AiCapability.toolCalling,
        AiCapability.multimodalVision,
        AiCapability.reasoning,
      },
      contextWindowTokens: 1000000,
      maxOutputTokens: 8192,
      tier: AiModelTier.flagship,
    ),
    AiModelConfig(
      provider: AiProviderType.gemini,
      modelId: 'gemini-4-carbon',
      displayName: 'Gemini 4 Carbon',
      endpointUrl: '$geminiBaseEndpoint/models/gemini-4-carbon',
      capabilities: <AiCapability>{
        AiCapability.text,
        AiCapability.streaming,
        AiCapability.toolCalling,
        AiCapability.multimodalVision,
        AiCapability.reasoning,
      },
      contextWindowTokens: 1000000,
      maxOutputTokens: 8192,
      tier: AiModelTier.flagship,
    ),

    // OpenAI (Responses API)
    AiModelConfig(
      provider: AiProviderType.openAi,
      modelId: 'gpt-5.4-mini',
      displayName: 'GPT-5.4 Mini',
      endpointUrl: openAiResponsesEndpoint,
      capabilities: <AiCapability>{
        AiCapability.text,
        AiCapability.streaming,
        AiCapability.toolCalling,
        AiCapability.multimodalVision,
      },
      contextWindowTokens: 400000,
      maxOutputTokens: 8192,
      supportsTemperature: false,
      isDefault: true,
      tier: AiModelTier.fast,
    ),
    AiModelConfig(
      provider: AiProviderType.openAi,
      modelId: 'gpt-5.4',
      displayName: 'GPT-5.4',
      endpointUrl: openAiResponsesEndpoint,
      capabilities: <AiCapability>{
        AiCapability.text,
        AiCapability.streaming,
        AiCapability.toolCalling,
        AiCapability.multimodalVision,
        AiCapability.reasoning,
      },
      contextWindowTokens: 400000,
      maxOutputTokens: 8192,
      supportsTemperature: false,
      tier: AiModelTier.flagship,
    ),
    AiModelConfig(
      provider: AiProviderType.openAi,
      modelId: 'gpt-5.4-nano',
      displayName: 'GPT-5.4 Nano',
      endpointUrl: openAiResponsesEndpoint,
      capabilities: <AiCapability>{
        AiCapability.text,
        AiCapability.streaming,
        AiCapability.toolCalling,
      },
      contextWindowTokens: 200000,
      maxOutputTokens: 4096,
      supportsTemperature: false,
      tier: AiModelTier.fast,
    ),

    // Anthropic Claude (Messages API)
    AiModelConfig(
      provider: AiProviderType.claude,
      modelId: 'claude-haiku-5-5',
      displayName: 'Claude Haiku 5.5',
      endpointUrl: claudeMessagesEndpoint,
      capabilities: <AiCapability>{
        AiCapability.text,
        AiCapability.streaming,
        AiCapability.toolCalling,
        AiCapability.multimodalVision,
      },
      contextWindowTokens: 1000000,
      maxOutputTokens: 8192,
      isDefault: true,
      tier: AiModelTier.fast,
    ),
    AiModelConfig(
      provider: AiProviderType.claude,
      modelId: 'claude-sonnet-5-5',
      displayName: 'Claude Sonnet 5.5',
      endpointUrl: claudeMessagesEndpoint,
      capabilities: <AiCapability>{
        AiCapability.text,
        AiCapability.streaming,
        AiCapability.toolCalling,
        AiCapability.multimodalVision,
        AiCapability.reasoning,
      },
      contextWindowTokens: 1000000,
      maxOutputTokens: 8192,
      tier: AiModelTier.balanced,
    ),
    AiModelConfig(
      provider: AiProviderType.claude,
      modelId: 'claude-opus-5-5',
      displayName: 'Claude Opus 5.5',
      endpointUrl: claudeMessagesEndpoint,
      capabilities: <AiCapability>{
        AiCapability.text,
        AiCapability.streaming,
        AiCapability.toolCalling,
        AiCapability.multimodalVision,
        AiCapability.reasoning,
      },
      contextWindowTokens: 1000000,
      maxOutputTokens: 8192,
      tier: AiModelTier.flagship,
    ),
  ];

  /// Returns all built-in models for [provider].
  static List<AiModelConfig> modelsForProvider(AiProviderType provider) {
    return _catalog
        .where((m) => m.provider == provider)
        .toList(growable: false);
  }

  /// Returns the recommended default [AiModelConfig] for [provider].
  static AiModelConfig defaultModelFor(AiProviderType provider) {
    return _catalog.firstWhere(
      (m) => m.provider == provider && m.isDefault,
      orElse: () => modelsForProvider(provider).first,
    );
  }

  /// Normalizes a user-supplied or persisted model ID for [provider].
  ///
  /// Strips a leading `models/` prefix on Gemini IDs and automatically upgrades
  /// known retired defaults if [upgradeDeprecated] is `true`.
  static String normalizeModelId(
    AiProviderType provider,
    String? rawModelId, {
    bool upgradeDeprecated = false,
  }) {
    var trimmed = rawModelId?.trim() ?? '';
    if (trimmed.isEmpty) {
      return defaultModelFor(provider).modelId;
    }
    if (provider == AiProviderType.gemini && trimmed.startsWith('models/')) {
      trimmed = trimmed.substring('models/'.length);
    }
    if (upgradeDeprecated) {
      final replacement = deprecatedModelReplacements[trimmed];
      if (replacement != null) {
        return replacement;
      }
    }
    return trimmed;
  }

  /// Resolves an [AiModelConfig] for [provider] and [modelId], synthesizing a
  /// custom config if the user specified a custom/newly-released model ID.
  static AiModelConfig resolveModel(AiProviderType provider, String? modelId) {
    final normalized = normalizeModelId(provider, modelId);
    for (final model in _catalog) {
      if (model.provider == provider && model.modelId == normalized) {
        return model;
      }
    }

    final defaultEndpoint = switch (provider) {
      AiProviderType.gemini => '$geminiBaseEndpoint/models/$normalized',
      AiProviderType.openAi => openAiResponsesEndpoint,
      AiProviderType.claude => claudeMessagesEndpoint,
      AiProviderType.edgeAi => 'on-device://android-aicore/gemini-nano',
    };

    return AiModelConfig(
      provider: provider,
      modelId: normalized,
      displayName: normalized,
      endpointUrl: defaultEndpoint,
      capabilities: <AiCapability>{
        AiCapability.text,
        AiCapability.streaming,
        AiCapability.toolCalling,
      },
      supportsTemperature: provider != AiProviderType.openAi,
      isCustom: true,
    );
  }

  /// Recommends a capable model for [provider] matching [complexity], falling back
  /// cleanly to the user's configured model or provider default.
  static AiModelConfig recommendModelFor(
    AiProviderType provider, {
    required TaskComplexityTier complexity,
    String? userSelectedModelId,
  }) {
    final normalizedSelected = normalizeModelId(
      provider,
      userSelectedModelId,
      upgradeDeprecated: true,
    );
    final selected = resolveModel(provider, normalizedSelected);
    // Honor custom user-entered models directly.
    if (selected.isCustom) return selected;

    final providerModels = modelsForProvider(provider);
    switch (complexity) {
      case TaskComplexityTier.simpleFast:
        // If user explicitly chose flagship, honor unless balanced/fast exists;
        // prefer fast models on default settings.
        if (userSelectedModelId == null || userSelectedModelId.isEmpty) {
          return providerModels.firstWhere(
            (m) => m.tier == AiModelTier.fast,
            orElse: () => selected,
          );
        }
        return selected;
      case TaskComplexityTier.balancedMultilingual:
        if (userSelectedModelId == null || userSelectedModelId.isEmpty) {
          return providerModels.firstWhere(
            (m) => m.tier == AiModelTier.balanced,
            orElse: () => selected,
          );
        }
        return selected;
      case TaskComplexityTier.deepReasoningCoding:
        // Upgrade from a lightweight default when complex reasoning/coding is detected,
        // while keeping the user's chosen provider.
        if (selected.tier == AiModelTier.fast) {
          return providerModels.firstWhere(
            (m) => m.supportsReasoning && m.tier == AiModelTier.balanced,
            orElse: () => providerModels.firstWhere(
              (m) => m.supportsReasoning,
              orElse: () => selected,
            ),
          );
        }
        return selected;
    }
  }

  /// Returns a recommended replacement if [modelId] is known deprecated/retired.
  static String? deprecationReplacement(String modelId) {
    final trimmed = modelId.trim();
    return deprecatedModelReplacements[trimmed] ??
        deprecatedModelReplacements['models/$trimmed'];
  }
}
