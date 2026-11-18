import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:vision_ai/features/chat/data/datasources/ai_http_helper.dart';
import 'package:vision_ai/features/chat/domain/entities/ai_completion_request.dart';
import 'package:vision_ai/features/chat/domain/entities/ai_model_config.dart';
import 'package:vision_ai/features/chat/domain/entities/ai_models.dart';
import 'package:vision_ai/features/chat/domain/entities/chat_message.dart';
import 'package:vision_ai/features/chat/domain/repositories/ai_provider.dart';
import 'package:vision_ai/features/chat/domain/repositories/ai_provider_client.dart';
import 'package:vision_ai/features/settings/domain/entities/ai_provider_type.dart';
import 'package:vision_ai/features/settings/domain/entities/voice_language.dart';

/// Backward-compatible alias for [OpenAIProvider].
typedef OpenAiRemoteDataSource = OpenAIProvider;

/// OpenAI Responses API REST & SSE Streaming provider (`/v1/responses`).
class OpenAIProvider implements AIProvider, AiProviderClient {
  const OpenAIProvider(this._httpClient);

  final http.Client _httpClient;

  @override
  AiProviderType get providerType => AiProviderType.openAi;

  @override
  String get providerName => providerType.displayName;

  @override
  Future<String> generateReply({
    required AiCompletionRequest request,
    required String apiKey,
  }) async {
    final response = await generate(request.toAiRequest(), apiKey: apiKey);
    if (response.text.isNotEmpty) {
      return response.text;
    }
    if (response.toolCalls.isNotEmpty) {
      return '[[VISION_ACTION:${jsonEncode(response.toolCalls.first.arguments)}]]';
    }
    return '';
  }

  @override
  Future<AIResponse> generate(
    AIRequest request, {
    required String apiKey,
    AICancellationToken? cancellationToken,
  }) async {
    final stopwatch = Stopwatch()..start();
    final modelId = AIModelRegistry.normalizeModelId(
      providerType,
      request.modelId,
    );
    final uri = Uri.parse(AIModelRegistry.openAiResponsesEndpoint);

    final payload = _buildPayload(request, modelId: modelId, stream: false);
    final response = await AiHttpHelper.sendWithRetry(
      client: _httpClient,
      provider: providerType,
      method: 'POST',
      uri: uri,
      modelId: modelId,
      headers: <String, String>{
        HttpHeaders.contentTypeHeader: 'application/json; charset=UTF-8',
        HttpHeaders.authorizationHeader: 'Bearer $apiKey',
      },
      body: jsonEncode(payload),
      cancellationToken: cancellationToken,
    );

    stopwatch.stop();
    return _parseResponsesPayload(
      response.body,
      modelId: modelId,
      latency: stopwatch.elapsed,
    );
  }

  @override
  Stream<AIStreamChunk> stream(
    AIRequest request, {
    required String apiKey,
    AICancellationToken? cancellationToken,
  }) async* {
    final stopwatch = Stopwatch()..start();
    final modelId = AIModelRegistry.normalizeModelId(
      providerType,
      request.modelId,
    );
    final uri = Uri.parse(AIModelRegistry.openAiResponsesEndpoint);

    final payload = _buildPayload(request, modelId: modelId, stream: true);
    final textBuffer = StringBuffer();
    final toolCalls = <AIToolCall>[];
    AIUsage? finalUsage;
    String? responseId;
    String? finishReason;

    await for (final sse in AiHttpHelper.streamSse(
      client: _httpClient,
      provider: providerType,
      uri: uri,
      modelId: modelId,
      headers: <String, String>{
        HttpHeaders.contentTypeHeader: 'application/json; charset=UTF-8',
        HttpHeaders.authorizationHeader: 'Bearer $apiKey',
      },
      body: jsonEncode(payload),
      cancellationToken: cancellationToken,
    )) {
      if (sse.data == '[DONE]') {
        break;
      }

      final dynamic decoded;
      try {
        decoded = jsonDecode(sse.data);
      } on FormatException {
        continue;
      }
      if (decoded is! Map<String, dynamic>) continue;

      final eventType = decoded['type'] as String? ?? sse.event;
      switch (eventType) {
        case 'response.output_text.delta':
          final delta = decoded['delta'];
          if (delta is String && delta.isNotEmpty) {
            textBuffer.write(delta);
            yield AITextDeltaChunk(delta);
          }

        case 'response.output_item.done':
          final item = decoded['item'];
          if (item is Map<String, dynamic> && item['type'] == 'function_call') {
            final call = _parseFunctionCallItem(item);
            if (call != null) {
              toolCalls.add(call);
              yield AIToolCallChunk(call);
            }
          }

        case 'response.completed':
          final responseObj = decoded['response'];
          if (responseObj is Map<String, dynamic>) {
            responseId = responseObj['id'] as String?;
            finishReason = responseObj['status'] as String?;
            finalUsage = _parseUsage(responseObj['usage']);
            if (textBuffer.isEmpty && toolCalls.isEmpty) {
              final extracted = _extractOutputFromResponseMap(responseObj);
              if (extracted.text.isNotEmpty) {
                textBuffer.write(extracted.text);
                yield AITextDeltaChunk(extracted.text);
              }
              for (final tc in extracted.toolCalls) {
                toolCalls.add(tc);
                yield AIToolCallChunk(tc);
              }
            }
          }

        case 'response.failed':
        case 'error':
          throw AiHttpHelper.classifyHttpError(
            provider: providerType,
            modelId: modelId,
            statusCode: 400,
            responseBody: sse.data,
          );
      }
    }

    stopwatch.stop();
    final combinedText = textBuffer.toString().trim();
    if (combinedText.isEmpty && toolCalls.isEmpty) {
      throw AIError(
        kind: AIErrorKind.unrecognizedResponse,
        provider: providerType,
        modelId: modelId,
        message: 'OpenAI stream ended without output text or tool calls.',
        userMessage: 'OpenAI returned an empty response. Please retry.',
      );
    }

    yield AICompletedChunk(
      AIResponse(
        text: combinedText,
        provider: providerType,
        modelId: modelId,
        usage: finalUsage,
        toolCalls: List<AIToolCall>.unmodifiable(toolCalls),
        latency: stopwatch.elapsed,
        finishReason: finishReason,
        responseId: responseId,
      ),
    );
  }

  @override
  Future<List<String>> listAvailableModels({
    required String apiKey,
    AICancellationToken? cancellationToken,
  }) async {
    final uri = Uri.parse(AIModelRegistry.openAiModelsEndpoint);
    final response = await AiHttpHelper.sendWithRetry(
      client: _httpClient,
      provider: providerType,
      method: 'GET',
      uri: uri,
      headers: <String, String>{
        HttpHeaders.authorizationHeader: 'Bearer $apiKey',
      },
      timeout: const Duration(seconds: 20),
      maxRetries: 1,
      cancellationToken: cancellationToken,
    );

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return const <String>[];
    final data = decoded['data'];
    if (data is! List<Object?>) return const <String>[];

    final models = <String>[];
    for (final item in data) {
      if (item is Map<String, dynamic>) {
        final id = item['id'];
        if (id is String &&
            (id.startsWith('gpt-') ||
                id.startsWith('o3') ||
                id.startsWith('o4'))) {
          models.add(id);
        }
      }
    }
    models.sort();
    return models;
  }

  @override
  Future<AIConnectionTestResult> testConnection({
    required String apiKey,
    String? modelId,
    AICancellationToken? cancellationToken,
  }) async {
    final targetModel = AIModelRegistry.normalizeModelId(providerType, modelId);
    final stopwatch = Stopwatch()..start();
    var availableModels = const <String>[];

    try {
      availableModels = await listAvailableModels(
        apiKey: apiKey,
        cancellationToken: cancellationToken,
      );

      final probeRequest = AIRequest(
        provider: providerType,
        modelId: targetModel,
        messages: <ChatMessage>[
          ChatMessage(
            id: 'probe_user',
            sender: MessageSender.user,
            content: 'Reply with OK.',
            createdAt: DateTime.now(),
          ),
        ],
        systemInstruction: 'You are a connectivity probe. Reply briefly.',
        responseLanguage: VoiceLanguage.english,
        maxOutputTokens: 16,
        enableDeviceActions: false,
      );

      await generate(
        probeRequest,
        apiKey: apiKey,
        cancellationToken: cancellationToken,
      );
      stopwatch.stop();

      return AIConnectionTestResult(
        provider: providerType,
        modelId: targetModel,
        connected: true,
        message: 'Connected to OpenAI ($targetModel).',
        testedAt: DateTime.now(),
        latency: stopwatch.elapsed,
        availableModels: availableModels,
      );
    } on AIError catch (error) {
      stopwatch.stop();
      return AIConnectionTestResult(
        provider: providerType,
        modelId: targetModel,
        connected: false,
        message: error.userMessage,
        testedAt: DateTime.now(),
        latency: stopwatch.elapsed,
        availableModels: availableModels,
        errorKind: error.kind,
      );
    }
  }

  Map<String, Object?> _buildPayload(
    AIRequest request, {
    required String modelId,
    required bool stream,
  }) {
    final input = <Map<String, String>>[
      for (final msg in request.messages)
        if (!msg.isError && msg.sender != MessageSender.system)
          <String, String>{
            'role': msg.sender == MessageSender.assistant
                ? 'assistant'
                : 'user',
            'content': msg.content,
          },
    ];

    if (input.isEmpty) {
      input.add(const <String, String>{'role': 'user', 'content': 'Hello'});
    }

    final modelConfig = AIModelRegistry.resolveModel(providerType, modelId);

    return <String, Object?>{
      'model': modelId,
      'instructions': request.systemInstruction,
      'input': input,
      'max_output_tokens': request.maxOutputTokens < 16
          ? 16
          : request.maxOutputTokens,
      if (modelConfig.supportsTemperature) 'temperature': request.temperature,
      if (stream) 'stream': true,
      if (request.tools.isNotEmpty)
        'tools': <Map<String, Object?>>[
          for (final tool in request.tools)
            <String, Object?>{
              'type': 'function',
              'name': tool.name,
              'description': tool.description,
              'parameters': tool.parametersSchema,
            },
        ],
    };
  }

  AIResponse _parseResponsesPayload(
    String responseBody, {
    required String modelId,
    required Duration latency,
  }) {
    final decoded = jsonDecode(responseBody);
    if (decoded is! Map<String, dynamic>) {
      throw AIError(
        kind: AIErrorKind.unrecognizedResponse,
        provider: providerType,
        modelId: modelId,
        message: 'Unrecognized JSON payload from OpenAI.',
        userMessage: 'OpenAI returned an unexpected response format.',
      );
    }

    final extracted = _extractOutputFromResponseMap(decoded);
    final text = extracted.text.trim();
    if (text.isEmpty && extracted.toolCalls.isEmpty) {
      throw AIError(
        kind: AIErrorKind.unrecognizedResponse,
        provider: providerType,
        modelId: modelId,
        message: 'OpenAI response contained no output text or tool calls.',
        userMessage: 'OpenAI returned an empty response.',
      );
    }

    return AIResponse(
      text: text,
      provider: providerType,
      modelId: modelId,
      usage: _parseUsage(decoded['usage']),
      toolCalls: extracted.toolCalls,
      latency: latency,
      finishReason: decoded['status'] as String?,
      responseId: decoded['id'] as String?,
    );
  }

  ({String text, List<AIToolCall> toolCalls}) _extractOutputFromResponseMap(
    Map<String, dynamic> decoded,
  ) {
    final buffer = StringBuffer();
    final toolCalls = <AIToolCall>[];

    final output = decoded['output'];
    if (output is List<Object?>) {
      for (final item in output) {
        if (item is! Map<String, dynamic>) continue;
        final type = item['type'];
        if (type == 'message') {
          final content = item['content'];
          if (content is List<Object?>) {
            for (final part in content) {
              if (part is! Map<String, dynamic>) continue;
              if (part['type'] == 'output_text' || part['type'] == 'text') {
                final text = part['text'];
                if (text is String) buffer.write(text);
              }
            }
          }
        } else if (type == 'function_call') {
          final call = _parseFunctionCallItem(item);
          if (call != null) toolCalls.add(call);
        }
      }
    }

    if (buffer.isEmpty && decoded['output_text'] is String) {
      buffer.write(decoded['output_text'] as String);
    }

    return (text: buffer.toString(), toolCalls: toolCalls);
  }

  AIToolCall? _parseFunctionCallItem(Map<String, dynamic> item) {
    final name = item['name'];
    if (name is! String || name.isEmpty) return null;
    final callId =
        (item['call_id'] as String?) ?? (item['id'] as String?) ?? '';
    final rawArgs = item['arguments'];
    var args = const <String, dynamic>{};
    if (rawArgs is Map<String, dynamic>) {
      args = rawArgs;
    } else if (rawArgs is String && rawArgs.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawArgs);
        if (decoded is Map<String, dynamic>) {
          args = decoded;
        }
      } on FormatException {
        // Leave empty map if malformed.
      }
    }
    return AIToolCall(id: callId, name: name, arguments: args);
  }

  AIUsage? _parseUsage(Object? usageRaw) {
    if (usageRaw is! Map<String, dynamic>) return null;
    final details = usageRaw['output_tokens_details'];
    final reasoningTokens = details is Map<String, dynamic>
        ? (details['reasoning_tokens'] as num?)?.toInt()
        : null;
    return AIUsage(
      inputTokens: (usageRaw['input_tokens'] as num?)?.toInt(),
      outputTokens: (usageRaw['output_tokens'] as num?)?.toInt(),
      totalTokens: (usageRaw['total_tokens'] as num?)?.toInt(),
      reasoningTokens: reasoningTokens,
    );
  }
}
