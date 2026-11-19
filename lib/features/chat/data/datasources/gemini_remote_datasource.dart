import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:google_generative_ai/google_generative_ai.dart' as genai;
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

/// Backward-compatible alias for [GeminiProvider].
typedef GeminiRemoteDataSource = GeminiProvider;

/// Google Gemini REST & SSE Streaming provider (`/v1beta/models/{model}:generateContent`).
class GeminiProvider implements AIProvider, AiProviderClient {
  const GeminiProvider(this._httpClient);

  final http.Client _httpClient;

  @override
  AiProviderType get providerType => AiProviderType.gemini;

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
      return _toolCallFallbackDirective(response.toolCalls.first);
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
    final uri = Uri.parse(
      '${AIModelRegistry.geminiBaseEndpoint}/models/$modelId:generateContent',
    );

    final payload = _buildPayload(request);
    final response = await AiHttpHelper.sendWithRetry(
      client: _httpClient,
      provider: providerType,
      method: 'POST',
      uri: uri,
      modelId: modelId,
      headers: <String, String>{
        HttpHeaders.contentTypeHeader: 'application/json; charset=UTF-8',
        'x-goog-api-key': apiKey,
      },
      body: jsonEncode(payload),
      cancellationToken: cancellationToken,
    );

    stopwatch.stop();
    return _parseGenerateContentResponse(
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
    final uri = Uri.parse(
      '${AIModelRegistry.geminiBaseEndpoint}/models/$modelId:streamGenerateContent?alt=sse',
    );

    final payload = _buildPayload(request);
    final textBuffer = StringBuffer();
    final toolCalls = <AIToolCall>[];
    AIUsage? finalUsage;
    String? finishReason;

    await for (final sse in AiHttpHelper.streamSse(
      client: _httpClient,
      provider: providerType,
      uri: uri,
      modelId: modelId,
      headers: <String, String>{
        HttpHeaders.contentTypeHeader: 'application/json; charset=UTF-8',
        'x-goog-api-key': apiKey,
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

      if (decoded.containsKey('error')) {
        throw AiHttpHelper.classifyHttpError(
          provider: providerType,
          modelId: modelId,
          statusCode: 400,
          responseBody: sse.data,
        );
      }

      final parsed = _extractPartsFromMap(decoded);
      if (parsed.text.isNotEmpty) {
        textBuffer.write(parsed.text);
        yield AITextDeltaChunk(parsed.text);
      }
      for (final tc in parsed.toolCalls) {
        toolCalls.add(tc);
        yield AIToolCallChunk(tc);
      }
      if (parsed.usage != null) {
        finalUsage = parsed.usage;
      }
      if (parsed.finishReason != null) {
        finishReason = parsed.finishReason;
      }
    }

    stopwatch.stop();
    final combinedText = textBuffer.toString().trim();
    if (combinedText.isEmpty && toolCalls.isEmpty) {
      throw AIError(
        kind: AIErrorKind.unrecognizedResponse,
        provider: providerType,
        modelId: modelId,
        message: 'Gemini stream completed with no text or tool call output.',
        userMessage: 'Google Gemini returned an empty response. Please retry.',
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
      ),
    );
  }

  @override
  Future<List<String>> listAvailableModels({
    required String apiKey,
    AICancellationToken? cancellationToken,
  }) async {
    final uri = Uri.parse('${AIModelRegistry.geminiBaseEndpoint}/models');
    final response = await AiHttpHelper.sendWithRetry(
      client: _httpClient,
      provider: providerType,
      method: 'GET',
      uri: uri,
      headers: <String, String>{'x-goog-api-key': apiKey},
      timeout: const Duration(seconds: 20),
      maxRetries: 1,
      cancellationToken: cancellationToken,
    );

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return const <String>[];
    final modelsRaw = decoded['models'];
    if (modelsRaw is! List<Object?>) return const <String>[];

    final models = <String>[];
    for (final item in modelsRaw) {
      if (item is! Map<String, dynamic>) continue;
      final name = item['name'];
      final methods = item['supportedGenerationMethods'];
      if (name is! String) continue;
      final supportsGen =
          methods is List<Object?> && methods.contains('generateContent');
      if (!supportsGen) continue;
      models.add(
        name.startsWith('models/') ? name.substring('models/'.length) : name,
      );
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
        responseLanguage: _defaultLanguage,
        temperature: 0.0,
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
        message: 'Connected to Google Gemini ($targetModel).',
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

  static const VoiceLanguage _defaultLanguage = VoiceLanguage.english;

  /// Creates an official `google_generative_ai` [genai.GenerativeModel] bound
  /// to the user's Keystore API key for direct SDK multimodal & streaming calls.
  genai.GenerativeModel createSdkModel({
    required String apiKey,
    String? modelId,
    String? systemInstruction,
  }) {
    final normalized = AIModelRegistry.normalizeModelId(providerType, modelId);
    return genai.GenerativeModel(
      model: normalized,
      apiKey: apiKey,
      systemInstruction:
          systemInstruction != null && systemInstruction.isNotEmpty
          ? genai.Content.system(systemInstruction)
          : null,
    );
  }

  Map<String, Object?> _buildPayload(AIRequest request) {
    final contents = <Map<String, Object?>>[
      for (final msg in request.messages)
        if (!msg.isError && msg.sender != MessageSender.system)
          <String, Object?>{
            'role': msg.sender == MessageSender.assistant ? 'model' : 'user',
            'parts': <Map<String, Object?>>[
              <String, Object?>{'text': msg.content},
              if (msg.imageAttachment != null)
                <String, Object?>{
                  'inlineData': <String, String>{
                    'mimeType': msg.imageAttachment!.mimeType,
                    'data': msg.imageAttachment!.base64Data,
                  },
                },
            ],
          },
    ];

    if (contents.isEmpty) {
      contents.add(<String, Object?>{
        'role': 'user',
        'parts': <Map<String, String>>[
          const <String, String>{'text': 'Hello'},
        ],
      });
    }

    return <String, Object?>{
      'systemInstruction': <String, Object?>{
        'parts': <Map<String, String>>[
          <String, String>{'text': request.systemInstruction},
        ],
      },
      'contents': contents,
      'generationConfig': <String, Object?>{
        'temperature': request.temperature,
        'maxOutputTokens': request.maxOutputTokens,
      },
      if (request.tools.isNotEmpty)
        'tools': <Map<String, Object?>>[
          <String, Object?>{
            'functionDeclarations': <Map<String, Object?>>[
              for (final tool in request.tools)
                <String, Object?>{
                  'name': tool.name,
                  'description': tool.description,
                  'parameters': tool.parametersSchema,
                },
            ],
          },
        ],
    };
  }

  AIResponse _parseGenerateContentResponse(
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
        message: 'Unrecognized JSON payload from Google Gemini.',
        userMessage: 'Google Gemini returned an unexpected response format.',
      );
    }

    final parsed = _extractPartsFromMap(decoded);
    final text = parsed.text.trim();
    if (text.isEmpty && parsed.toolCalls.isEmpty) {
      throw AIError(
        kind: AIErrorKind.unrecognizedResponse,
        provider: providerType,
        modelId: modelId,
        message: 'Empty candidate content returned by Google Gemini.',
        userMessage: 'Google Gemini returned an empty response.',
      );
    }

    return AIResponse(
      text: text,
      provider: providerType,
      modelId: modelId,
      usage: parsed.usage,
      toolCalls: parsed.toolCalls,
      latency: latency,
      finishReason: parsed.finishReason,
    );
  }

  ({
    String text,
    List<AIToolCall> toolCalls,
    AIUsage? usage,
    String? finishReason,
  })
  _extractPartsFromMap(Map<String, dynamic> decoded) {
    final buffer = StringBuffer();
    final toolCalls = <AIToolCall>[];
    String? finishReason;

    final candidates = decoded['candidates'];
    if (candidates is List<Object?> && candidates.isNotEmpty) {
      final first = candidates.first;
      if (first is Map<String, dynamic>) {
        if (first['finishReason'] is String) {
          finishReason = first['finishReason'] as String;
        }
        final content = first['content'];
        if (content is Map<String, dynamic>) {
          final parts = content['parts'];
          if (parts is List<Object?>) {
            for (final part in parts) {
              if (part is! Map<String, dynamic>) continue;
              final text = part['text'];
              if (text is String) {
                buffer.write(text);
              }
              final fnCall = part['functionCall'];
              if (fnCall is Map<String, dynamic>) {
                final name = fnCall['name'];
                final args = fnCall['args'];
                if (name is String && name.isNotEmpty) {
                  toolCalls.add(
                    AIToolCall(
                      name: name,
                      arguments: args is Map<String, dynamic>
                          ? args
                          : const <String, dynamic>{},
                    ),
                  );
                }
              }
            }
          }
        }
      }
    }

    AIUsage? usage;
    final usageRaw = decoded['usageMetadata'];
    if (usageRaw is Map<String, dynamic>) {
      usage = AIUsage(
        inputTokens: (usageRaw['promptTokenCount'] as num?)?.toInt(),
        outputTokens: (usageRaw['candidatesTokenCount'] as num?)?.toInt(),
        totalTokens: (usageRaw['totalTokenCount'] as num?)?.toInt(),
        reasoningTokens: (usageRaw['thoughtsTokenCount'] as num?)?.toInt(),
      );
    }

    return (
      text: buffer.toString(),
      toolCalls: toolCalls,
      usage: usage,
      finishReason: finishReason,
    );
  }

  String _toolCallFallbackDirective(AIToolCall call) {
    return '[[VISION_ACTION:${jsonEncode(call.arguments)}]]';
  }
}
