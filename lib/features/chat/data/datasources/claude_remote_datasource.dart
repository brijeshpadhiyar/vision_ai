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

/// Backward-compatible alias for [ClaudeProvider].
typedef ClaudeRemoteDataSource = ClaudeProvider;

/// Anthropic Claude Messages API REST & SSE Streaming provider (`/v1/messages`).
class ClaudeProvider implements AIProvider, AiProviderClient {
  const ClaudeProvider(this._httpClient);

  static const String _anthropicVersion = '2023-06-01';

  final http.Client _httpClient;

  @override
  AiProviderType get providerType => AiProviderType.claude;

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
    final uri = Uri.parse(AIModelRegistry.claudeMessagesEndpoint);

    final payload = _buildPayload(request, modelId: modelId, stream: false);
    final response = await AiHttpHelper.sendWithRetry(
      client: _httpClient,
      provider: providerType,
      method: 'POST',
      uri: uri,
      modelId: modelId,
      headers: _headers(apiKey),
      body: jsonEncode(payload),
      cancellationToken: cancellationToken,
    );

    stopwatch.stop();
    return _parseMessagesPayload(
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
    final uri = Uri.parse(AIModelRegistry.claudeMessagesEndpoint);

    final payload = _buildPayload(request, modelId: modelId, stream: true);
    final textBuffer = StringBuffer();
    final toolCalls = <AIToolCall>[];
    final activeToolBlocks =
        <int, ({String id, String name, StringBuffer json})>{};
    int? inputTokens;
    int? outputTokens;
    String? responseId;
    String? stopReason;

    await for (final sse in AiHttpHelper.streamSse(
      client: _httpClient,
      provider: providerType,
      uri: uri,
      modelId: modelId,
      headers: _headers(apiKey),
      body: jsonEncode(payload),
      cancellationToken: cancellationToken,
    )) {
      final dynamic decoded;
      try {
        decoded = jsonDecode(sse.data);
      } on FormatException {
        continue;
      }
      if (decoded is! Map<String, dynamic>) continue;

      final eventType = decoded['type'] as String? ?? sse.event;
      switch (eventType) {
        case 'message_start':
          final msg = decoded['message'];
          if (msg is Map<String, dynamic>) {
            responseId = msg['id'] as String?;
            final usage = msg['usage'];
            if (usage is Map<String, dynamic>) {
              inputTokens = (usage['input_tokens'] as num?)?.toInt();
            }
          }

        case 'content_block_start':
          final index = (decoded['index'] as num?)?.toInt();
          final block = decoded['content_block'];
          if (index != null &&
              block is Map<String, dynamic> &&
              block['type'] == 'tool_use') {
            activeToolBlocks[index] = (
              id: (block['id'] as String?) ?? '',
              name: (block['name'] as String?) ?? '',
              json: StringBuffer(),
            );
          }

        case 'content_block_delta':
          final index = (decoded['index'] as num?)?.toInt();
          final delta = decoded['delta'];
          if (delta is Map<String, dynamic>) {
            final deltaType = delta['type'];
            if (deltaType == 'text_delta') {
              final text = delta['text'];
              if (text is String && text.isNotEmpty) {
                textBuffer.write(text);
                yield AITextDeltaChunk(text);
              }
            } else if (deltaType == 'input_json_delta' && index != null) {
              final partial = delta['partial_json'];
              if (partial is String) {
                activeToolBlocks[index]?.json.write(partial);
              }
            }
          }

        case 'content_block_stop':
          final index = (decoded['index'] as num?)?.toInt();
          if (index != null && activeToolBlocks.containsKey(index)) {
            final completed = activeToolBlocks.remove(index)!;
            var args = const <String, dynamic>{};
            final rawJson = completed.json.toString().trim();
            if (rawJson.isNotEmpty) {
              try {
                final parsed = jsonDecode(rawJson);
                if (parsed is Map<String, dynamic>) args = parsed;
              } on FormatException {
                // Keep empty map on malformed tool JSON.
              }
            }
            if (completed.name.isNotEmpty) {
              final call = AIToolCall(
                id: completed.id,
                name: completed.name,
                arguments: args,
              );
              toolCalls.add(call);
              yield AIToolCallChunk(call);
            }
          }

        case 'message_delta':
          final delta = decoded['delta'];
          if (delta is Map<String, dynamic>) {
            stopReason = delta['stop_reason'] as String?;
          }
          final usage = decoded['usage'];
          if (usage is Map<String, dynamic>) {
            outputTokens = (usage['output_tokens'] as num?)?.toInt();
          }

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
        message: 'Anthropic Claude stream completed with no content.',
        userMessage:
            'Anthropic Claude returned an empty response. Please retry.',
      );
    }

    yield AICompletedChunk(
      AIResponse(
        text: combinedText,
        provider: providerType,
        modelId: modelId,
        usage: (inputTokens != null || outputTokens != null)
            ? AIUsage(inputTokens: inputTokens, outputTokens: outputTokens)
            : null,
        toolCalls: List<AIToolCall>.unmodifiable(toolCalls),
        latency: stopwatch.elapsed,
        finishReason: stopReason,
        responseId: responseId,
      ),
    );
  }

  @override
  Future<List<String>> listAvailableModels({
    required String apiKey,
    AICancellationToken? cancellationToken,
  }) async {
    final uri = Uri.parse(AIModelRegistry.claudeModelsEndpoint);
    final response = await AiHttpHelper.sendWithRetry(
      client: _httpClient,
      provider: providerType,
      method: 'GET',
      uri: uri,
      headers: <String, String>{
        'x-api-key': apiKey,
        'anthropic-version': _anthropicVersion,
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
        if (id is String && id.isNotEmpty) {
          models.add(id);
        }
      }
    }
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
        message: 'Connected to Anthropic Claude ($targetModel).',
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

  Map<String, String> _headers(String apiKey) => <String, String>{
    HttpHeaders.contentTypeHeader: 'application/json; charset=UTF-8',
    'x-api-key': apiKey,
    'anthropic-version': _anthropicVersion,
  };

  Map<String, Object?> _buildPayload(
    AIRequest request, {
    required String modelId,
    required bool stream,
  }) {
    // Anthropic requires alternating roles starting with `user`.
    final messages = <Map<String, String>>[];
    for (final msg in request.messages) {
      if (msg.isError || msg.sender == MessageSender.system) continue;
      final role = msg.sender == MessageSender.assistant ? 'assistant' : 'user';
      if (messages.isEmpty && role == 'assistant') {
        continue;
      }
      if (messages.isNotEmpty && messages.last['role'] == role) {
        messages[messages.length - 1] = <String, String>{
          'role': role,
          'content': '${messages.last['content']}\n\n${msg.content}',
        };
      } else {
        messages.add(<String, String>{'role': role, 'content': msg.content});
      }
    }

    if (messages.isEmpty) {
      messages.add(const <String, String>{'role': 'user', 'content': 'Hello'});
    }

    return <String, Object?>{
      'model': modelId,
      'max_tokens': request.maxOutputTokens,
      'temperature': request.temperature,
      'system': request.systemInstruction,
      'messages': messages,
      if (stream) 'stream': true,
      if (request.tools.isNotEmpty)
        'tools': <Map<String, Object?>>[
          for (final tool in request.tools)
            <String, Object?>{
              'name': tool.name,
              'description': tool.description,
              'input_schema': tool.parametersSchema,
            },
        ],
    };
  }

  AIResponse _parseMessagesPayload(
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
        message: 'Unrecognized JSON payload from Anthropic Claude.',
        userMessage: 'Anthropic Claude returned an unexpected response format.',
      );
    }

    final buffer = StringBuffer();
    final toolCalls = <AIToolCall>[];
    final blocks = decoded['content'];
    if (blocks is List<Object?>) {
      for (final block in blocks) {
        if (block is! Map<String, dynamic>) continue;
        final type = block['type'];
        if (type == 'text') {
          final text = block['text'];
          if (text is String) buffer.write(text);
        } else if (type == 'tool_use') {
          final name = block['name'];
          final input = block['input'];
          if (name is String && name.isNotEmpty) {
            toolCalls.add(
              AIToolCall(
                id: (block['id'] as String?) ?? '',
                name: name,
                arguments: input is Map<String, dynamic>
                    ? input
                    : const <String, dynamic>{},
              ),
            );
          }
        }
      }
    }

    final text = buffer.toString().trim();
    if (text.isEmpty && toolCalls.isEmpty) {
      throw AIError(
        kind: AIErrorKind.unrecognizedResponse,
        provider: providerType,
        modelId: modelId,
        message: 'Empty content blocks returned by Anthropic Claude.',
        userMessage: 'Anthropic Claude returned an empty response.',
      );
    }

    AIUsage? usage;
    final usageRaw = decoded['usage'];
    if (usageRaw is Map<String, dynamic>) {
      usage = AIUsage(
        inputTokens: (usageRaw['input_tokens'] as num?)?.toInt(),
        outputTokens: (usageRaw['output_tokens'] as num?)?.toInt(),
      );
    }

    return AIResponse(
      text: text,
      provider: providerType,
      modelId: modelId,
      usage: usage,
      toolCalls: toolCalls,
      latency: latency,
      finishReason: decoded['stop_reason'] as String?,
      responseId: decoded['id'] as String?,
    );
  }
}
