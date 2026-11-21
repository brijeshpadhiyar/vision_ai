import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:vision_ai/core/config/cloud_config.dart';
import 'package:vision_ai/features/chat/domain/entities/ai_completion_request.dart';
import 'package:vision_ai/features/chat/domain/entities/ai_models.dart';
import 'package:vision_ai/features/chat/domain/entities/chat_message.dart';
import 'package:vision_ai/features/chat/domain/repositories/ai_provider.dart';
import 'package:vision_ai/features/chat/domain/repositories/ai_provider_client.dart';
import 'package:vision_ai/features/settings/domain/entities/ai_provider_type.dart';

/// Tracks daily free-tier request usage for the VISION Cloud proxy.
@immutable
class VisionCloudQuota {
  const VisionCloudQuota({
    required this.used,
    required this.remaining,
    required this.dailyLimit,
    this.resetAt,
  });

  static const int defaultDailyLimit = 30;

  final int used;
  final int remaining;
  final int dailyLimit;
  final DateTime? resetAt;

  bool get isExhausted => remaining <= 0;

  String get badgeLabel => '$remaining/$dailyLimit free left';

  factory VisionCloudQuota.fromMap(Map<String, dynamic> map) {
    final limit = (map['daily_limit'] as num?)?.toInt() ?? defaultDailyLimit;
    final used = (map['used'] as num?)?.toInt() ?? 0;
    final remaining =
        (map['remaining'] as num?)?.toInt() ?? (limit - used).clamp(0, limit);
    final resetRaw = map['reset_at'] as String?;
    return VisionCloudQuota(
      used: used,
      remaining: remaining,
      dailyLimit: limit,
      resetAt: resetRaw != null ? DateTime.tryParse(resetRaw) : null,
    );
  }
}

/// Notifier holding the latest observed [VisionCloudQuota] for the signed-in user.
class VisionCloudQuotaNotifier extends Notifier<VisionCloudQuota?> {
  @override
  VisionCloudQuota? build() => null;

  void update(VisionCloudQuota quota) {
    state = quota;
  }

  void clear() {
    state = null;
  }
}

final visionCloudQuotaProvider =
    NotifierProvider<VisionCloudQuotaNotifier, VisionCloudQuota?>(
      VisionCloudQuotaNotifier.new,
    );

/// Invoker signature for calling the `vision-ai-proxy` Supabase Edge Function
/// (injectable for deterministic unit testing).
typedef VisionCloudFunctionInvoker =
    Future<({int status, Map<String, dynamic> data})> Function(
      Map<String, dynamic> body,
    );

/// Built-in zero-friction AI provider backed by the `vision-ai-proxy` Supabase
/// Edge Function (Google Gemini 2.5 Flash, 30 free requests/day per signed-in user).
class VisionCloudProvider implements AIProvider, AiProviderClient {
  VisionCloudProvider({
    this.invoker,
    this.onQuotaUpdated,
  });

  static const String functionName = 'vision-ai-proxy';

  final VisionCloudFunctionInvoker? invoker;
  final void Function(VisionCloudQuota quota)? onQuotaUpdated;

  @override
  AiProviderType get providerType => AiProviderType.visionCloud;

  @override
  String get providerName => AiProviderType.visionCloud.displayName;

  List<Map<String, dynamic>> _buildContents(AIRequest request) {
    final contents = <Map<String, dynamic>>[];
    final recent = request.messages.length > 14
        ? request.messages.sublist(request.messages.length - 14)
        : request.messages;
    for (final msg in recent) {
      if (msg.isError) continue;
      final parts = <Map<String, dynamic>>[];
      if (msg.content.trim().isNotEmpty) {
        parts.add(<String, dynamic>{'text': msg.content.trim()});
      }
      final img = msg.imageAttachment;
      if (img != null && img.base64Data.isNotEmpty) {
        parts.add(<String, dynamic>{
          'inlineData': <String, dynamic>{
            'mimeType': img.mimeType,
            'data': img.base64Data,
          },
        });
      }
      if (parts.isEmpty) continue;
      contents.add(<String, dynamic>{
        'role': msg.sender == MessageSender.user ? 'user' : 'model',
        'parts': parts,
      });
    }
    return contents;
  }

  Future<({int status, Map<String, dynamic> data})> _invokeProxy(
    Map<String, dynamic> body,
  ) async {
    final customInvoker = invoker;
    if (customInvoker != null) {
      return customInvoker(body);
    }

    if (!CloudConfig.isSupabaseConfigured) {
      throw AIError(
        kind: AIErrorKind.invalidApiKey,
        provider: providerType,
        modelId: providerType.defaultModel,
        message: 'Supabase cloud configuration missing.',
        userMessage:
            'VISION Cloud Free Tier requires Supabase configuration. Add your own API key in Settings or rebuild with Supabase --dart-define.',
      );
    }

    final client = Supabase.instance.client;
    if (client.auth.currentSession == null) {
      throw AIError(
        kind: AIErrorKind.invalidApiKey,
        provider: providerType,
        modelId: providerType.defaultModel,
        message: 'User not signed in.',
        userMessage:
            'Sign in with Google in Settings → Account & Cloud Sync to unlock 30 free VISION Cloud requests/day (or add your own API key).',
      );
    }

    try {
      final response = await client.functions.invoke(functionName, body: body);
      final parsed = _normalizePayload(response.data);
      return (status: response.status, data: parsed);
    } on FunctionException catch (error) {
      final parsed = _normalizePayload(error.details);
      return (status: error.status, data: parsed);
    }
  }

  static Map<String, dynamic> _normalizePayload(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } on FormatException {
        return <String, dynamic>{'message': raw};
      }
    }
    return const <String, dynamic>{};
  }

  void _recordQuotaFromMap(Map<String, dynamic> data) {
    final rawQuota = data['quota'];
    if (rawQuota is Map) {
      final quota = VisionCloudQuota.fromMap(
        Map<String, dynamic>.from(rawQuota),
      );
      onQuotaUpdated?.call(quota);
    }
  }

  @override
  Future<AIResponse> generate(
    AIRequest request, {
    required String apiKey,
    AICancellationToken? cancellationToken,
  }) async {
    final sw = Stopwatch()..start();
    final modelId = request.modelId.trim().isNotEmpty
        ? request.modelId.trim()
        : providerType.defaultModel;

    final payload = <String, dynamic>{
      'model': modelId,
      'contents': _buildContents(request),
      'systemInstruction': request.systemInstruction,
      'temperature': request.temperature,
      'maxOutputTokens': request.maxOutputTokens,
    };

    final result = await _invokeProxy(payload);
    _recordQuotaFromMap(result.data);

    if (result.status == 401) {
      throw AIError(
        kind: AIErrorKind.invalidApiKey,
        provider: providerType,
        modelId: modelId,
        statusCode: 401,
        message: 'Unauthorized for VISION Cloud.',
        userMessage:
            (result.data['message'] as String?) ??
            'Sign in with Google to use VISION Cloud Free Tier (30 requests/day).',
      );
    }

    if (result.status == 429) {
      throw AIError(
        kind: AIErrorKind.rateLimited,
        provider: providerType,
        modelId: modelId,
        statusCode: 429,
        message: 'Daily VISION Cloud quota exceeded.',
        userMessage:
            (result.data['message'] as String?) ??
            'You have used all 30 free VISION Cloud requests for today. Add your own Gemini/OpenAI/Claude key in Settings or wait for the daily reset.',
      );
    }

    if (result.status == 503) {
      throw AIError(
        kind: AIErrorKind.serverError,
        provider: providerType,
        modelId: modelId,
        statusCode: 503,
        message: 'VISION Cloud server secret not configured.',
        userMessage:
            (result.data['message'] as String?) ??
            'VISION Cloud Free Tier is awaiting server GEMINI_API_KEY activation. You can add your own API key in Settings anytime.',
      );
    }

    if (result.status < 200 || result.status >= 300) {
      throw AIError(
        kind: AIErrorKind.serverError,
        provider: providerType,
        modelId: modelId,
        statusCode: result.status,
        message: 'VISION Cloud error (${result.status}).',
        userMessage:
            (result.data['message'] as String?) ??
            'VISION Cloud could not complete that request (${result.status}). Please try again.',
      );
    }

    final text = (result.data['text'] as String?)?.trim() ?? '';
    if (text.isEmpty) {
      throw AIError(
        kind: AIErrorKind.unrecognizedResponse,
        provider: providerType,
        modelId: modelId,
        message: 'Empty response from VISION Cloud.',
        userMessage: 'VISION Cloud returned an empty response. Please retry.',
      );
    }

    AIUsage? usage;
    final rawUsage = result.data['usage'];
    if (rawUsage is Map) {
      final u = Map<String, dynamic>.from(rawUsage);
      usage = AIUsage(
        inputTokens: (u['input_tokens'] as num?)?.toInt() ?? 0,
        outputTokens: (u['output_tokens'] as num?)?.toInt() ?? 0,
        totalTokens: (u['total_tokens'] as num?)?.toInt() ?? 0,
      );
    }

    sw.stop();
    return AIResponse(
      text: text,
      provider: providerType,
      modelId: (result.data['model'] as String?) ?? modelId,
      latency: sw.elapsed,
      usage: usage,
    );
  }

  @override
  Stream<AIStreamChunk> stream(
    AIRequest request, {
    required String apiKey,
    AICancellationToken? cancellationToken,
  }) async* {
    final response = await generate(
      request,
      apiKey: apiKey,
      cancellationToken: cancellationToken,
    );
    yield AITextDeltaChunk(response.text);
    yield AICompletedChunk(response);
  }

  @override
  Future<List<String>> listAvailableModels({
    required String apiKey,
    AICancellationToken? cancellationToken,
  }) async => const <String>['gemini-2.5-flash'];

  @override
  Future<String> generateReply({
    required AiCompletionRequest request,
    required String apiKey,
  }) async {
    final response = await generate(request.toAiRequest(), apiKey: apiKey);
    return response.text;
  }

  @override
  Future<AIConnectionTestResult> testConnection({
    required String apiKey,
    String? modelId,
    AICancellationToken? cancellationToken,
  }) async {
    final sw = Stopwatch()..start();
    final targetModel = modelId ?? providerType.defaultModel;
    try {
      final result = await _invokeProxy(const <String, dynamic>{
        'action': 'quota',
      });
      _recordQuotaFromMap(result.data);
      sw.stop();
      if (result.status >= 200 && result.status < 300) {
        final rawQuota = result.data['quota'];
        final quotaMsg = rawQuota is Map
            ? ' (${VisionCloudQuota.fromMap(Map<String, dynamic>.from(rawQuota)).badgeLabel})'
            : '';
        return AIConnectionTestResult(
          provider: providerType,
          modelId: targetModel,
          connected: true,
          message: 'VISION Cloud Free Tier ready$quotaMsg.',
          latency: sw.elapsed,
          availableModels: const <String>['gemini-2.5-flash'],
          testedAt: DateTime.now(),
        );
      }
      return AIConnectionTestResult(
        provider: providerType,
        modelId: targetModel,
        connected: false,
        message:
            (result.data['message'] as String?) ??
            'VISION Cloud check failed (${result.status}).',
        latency: sw.elapsed,
        testedAt: DateTime.now(),
      );
    } on AIError catch (error) {
      sw.stop();
      return AIConnectionTestResult(
        provider: providerType,
        modelId: targetModel,
        connected: false,
        message: error.userMessage,
        latency: sw.elapsed,
        testedAt: DateTime.now(),
      );
    } catch (error) {
      sw.stop();
      return AIConnectionTestResult(
        provider: providerType,
        modelId: targetModel,
        connected: false,
        message: 'VISION Cloud unavailable: $error',
        latency: sw.elapsed,
        testedAt: DateTime.now(),
      );
    }
  }
}
