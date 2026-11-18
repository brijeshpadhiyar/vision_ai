import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/errors/app_exception.dart';
import 'package:vision_ai/features/chat/domain/entities/ai_model_config.dart';
import 'package:vision_ai/features/chat/domain/entities/chat_message.dart';
import 'package:vision_ai/features/settings/domain/entities/ai_provider_type.dart';
import 'package:vision_ai/features/settings/domain/entities/voice_language.dart';

/// Token accounting reported by an AI provider response.
@immutable
class AIUsage {
  const AIUsage({
    this.inputTokens,
    this.outputTokens,
    this.totalTokens,
    this.reasoningTokens,
  });

  final int? inputTokens;
  final int? outputTokens;
  final int? totalTokens;
  final int? reasoningTokens;

  int? get resolvedTotal =>
      totalTokens ??
      (inputTokens != null && outputTokens != null
          ? inputTokens! + outputTokens!
          : null);

  Map<String, dynamic> toJson() => <String, dynamic>{
    if (inputTokens != null) 'inputTokens': inputTokens,
    if (outputTokens != null) 'outputTokens': outputTokens,
    if (totalTokens != null) 'totalTokens': totalTokens,
    if (reasoningTokens != null) 'reasoningTokens': reasoningTokens,
  };

  factory AIUsage.fromJson(Map<String, dynamic> json) {
    return AIUsage(
      inputTokens: (json['inputTokens'] as num?)?.toInt(),
      outputTokens: (json['outputTokens'] as num?)?.toInt(),
      totalTokens: (json['totalTokens'] as num?)?.toInt(),
      reasoningTokens: (json['reasoningTokens'] as num?)?.toInt(),
    );
  }
}

/// Provider-independent tool / function schema exposed to AI models.
@immutable
class AIToolDefinition {
  const AIToolDefinition({
    required this.name,
    required this.description,
    required this.parametersSchema,
  });

  final String name;
  final String description;
  final Map<String, Object?> parametersSchema;
}

/// Structured tool invocation returned by an AI model.
@immutable
class AIToolCall {
  const AIToolCall({required this.name, required this.arguments, this.id = ''});

  final String id;
  final String name;
  final Map<String, dynamic> arguments;
}

/// Cooperative cancellation token for aborting in-flight AI requests/streams.
class AICancellationToken {
  bool _cancelled = false;
  final List<void Function()> _listeners = <void Function()>[];

  bool get isCancelled => _cancelled;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    for (final listener in List<void Function()>.of(_listeners)) {
      listener();
    }
    _listeners.clear();
  }

  void addListener(void Function() listener) {
    if (_cancelled) {
      listener();
      return;
    }
    _listeners.add(listener);
  }

  void removeListener(void Function() listener) {
    _listeners.remove(listener);
  }
}

/// Provider-independent completion request sent to any [AIProvider].
@immutable
class AIRequest {
  const AIRequest({
    required this.provider,
    required this.modelId,
    required this.messages,
    required this.systemInstruction,
    required this.responseLanguage,
    this.temperature = 0.7,
    this.maxOutputTokens = 1024,
    this.tools = const <AIToolDefinition>[],
    this.enableDeviceActions = true,
    this.requestId,
  });

  final AiProviderType provider;
  final String modelId;
  final List<ChatMessage> messages;
  final String systemInstruction;
  final VoiceLanguage responseLanguage;
  final double temperature;
  final int maxOutputTokens;
  final List<AIToolDefinition> tools;
  final bool enableDeviceActions;
  final String? requestId;

  AiModelConfig get modelConfig =>
      AIModelRegistry.resolveModel(provider, modelId);

  AIRequest copyWith({
    AiProviderType? provider,
    String? modelId,
    List<ChatMessage>? messages,
    String? systemInstruction,
    VoiceLanguage? responseLanguage,
    double? temperature,
    int? maxOutputTokens,
    List<AIToolDefinition>? tools,
    bool? enableDeviceActions,
    String? requestId,
  }) {
    return AIRequest(
      provider: provider ?? this.provider,
      modelId: modelId ?? this.modelId,
      messages: messages ?? this.messages,
      systemInstruction: systemInstruction ?? this.systemInstruction,
      responseLanguage: responseLanguage ?? this.responseLanguage,
      temperature: temperature ?? this.temperature,
      maxOutputTokens: maxOutputTokens ?? this.maxOutputTokens,
      tools: tools ?? this.tools,
      enableDeviceActions: enableDeviceActions ?? this.enableDeviceActions,
      requestId: requestId ?? this.requestId,
    );
  }
}

/// Normalized completion response returned by an [AIProvider].
@immutable
class AIResponse {
  const AIResponse({
    required this.text,
    required this.provider,
    required this.modelId,
    this.usage,
    this.toolCalls = const <AIToolCall>[],
    this.latency = Duration.zero,
    this.finishReason,
    this.responseId,
    this.routingNotice,
  });

  final String text;
  final AiProviderType provider;
  final String modelId;
  final AIUsage? usage;
  final List<AIToolCall> toolCalls;
  final Duration latency;
  final String? finishReason;
  final String? responseId;
  final String? routingNotice;
}

/// Categorized AI error taxonomy for accurate retry, fallback, and UI guidance.
enum AIErrorKind {
  invalidApiKey,
  quotaExceeded,
  rateLimited,
  modelUnavailable,
  networkUnavailable,
  timeout,
  cancelled,
  badRequest,
  serverError,
  unrecognizedResponse,
}

/// Structured AI error extending [AiProviderException] for clean interoperability.
final class AIError extends AiProviderException {
  const AIError({
    required this.kind,
    required this.provider,
    required super.message,
    required this.userMessage,
    this.modelId,
    super.statusCode,
    this.retryAfter,
    this.suggestedModelId,
    super.cause,
    super.stackTrace,
  }) : super(providerName: '', code: 'AI_ERROR');

  final AIErrorKind kind;
  final AiProviderType provider;
  final String? modelId;
  final String userMessage;
  final Duration? retryAfter;
  final String? suggestedModelId;

  @override
  String get providerName => provider.displayName;

  bool get isRetryable =>
      kind == AIErrorKind.rateLimited ||
      kind == AIErrorKind.timeout ||
      kind == AIErrorKind.serverError;

  bool get allowsProviderFallback =>
      kind != AIErrorKind.cancelled && kind != AIErrorKind.networkUnavailable;
}

/// Incremental streaming event emitted by [AIProvider.stream].
sealed class AIStreamChunk {
  const AIStreamChunk();
}

final class AITextDeltaChunk extends AIStreamChunk {
  const AITextDeltaChunk(this.delta);

  final String delta;
}

final class AIToolCallChunk extends AIStreamChunk {
  const AIToolCallChunk(this.toolCall);

  final AIToolCall toolCall;
}

final class AICompletedChunk extends AIStreamChunk {
  const AICompletedChunk(this.response);

  final AIResponse response;
}

/// Connection state tracked per provider in Settings.
enum ProviderConnectionState {
  untested,
  testing,
  connected,
  failed,
  missingKey,
  disabled,
}

/// Result of a real authenticated connection check against an AI provider.
@immutable
class AIConnectionTestResult {
  const AIConnectionTestResult({
    required this.provider,
    required this.modelId,
    required this.connected,
    required this.message,
    required this.testedAt,
    this.latency,
    this.availableModels = const <String>[],
    this.errorKind,
  });

  final AiProviderType provider;
  final String modelId;
  final bool connected;
  final String message;
  final DateTime testedAt;
  final Duration? latency;
  final List<String> availableModels;
  final AIErrorKind? errorKind;
}
