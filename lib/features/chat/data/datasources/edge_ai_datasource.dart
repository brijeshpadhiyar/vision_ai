import 'dart:async';

import 'package:flutter_edge_ai/engine.dart'
    show Message, RuntimeConfig;
import 'package:flutter_edge_ai/flutter_edge_ai.dart' show FlutterEdgeAi;
import 'package:flutter_edge_ai_builtin_ai/flutter_edge_ai_builtin_ai.dart'
    show BuiltInAi, BuiltInAiAvailability, BuiltInAiEngine, BuiltInAiModels;

import 'package:vision_ai/features/chat/domain/entities/ai_completion_request.dart';
import 'package:vision_ai/features/chat/domain/entities/ai_models.dart';
import 'package:vision_ai/features/chat/domain/entities/chat_message.dart';
import 'package:vision_ai/features/chat/domain/repositories/ai_provider.dart';
import 'package:vision_ai/features/chat/domain/repositories/ai_provider_client.dart';
import 'package:vision_ai/features/settings/domain/entities/ai_provider_type.dart';

/// On-device Android Edge AI provider powered by `flutter_edge_ai` +
/// `flutter_edge_ai_builtin_ai` (Gemini Nano via Android AICore / ML Kit GenAI).
///
/// Requires zero API keys and zero bundled model weights; gracefully detects
/// availability on every Android device and reports actionable status if the
/// host device does not support Android AICore.
class EdgeAiProvider implements AIProvider, AiProviderClient {
  EdgeAiProvider();

  static bool _initialized = false;

  @override
  AiProviderType get providerType => AiProviderType.edgeAi;

  @override
  String get providerName => AiProviderType.edgeAi.displayName;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    try {
      await FlutterEdgeAi.initialize(
        inferenceEngines: const [BuiltInAiEngine()],
      );
      _initialized = true;
    } catch (_) {
      // Safe fallback in unit tests or unsupported platforms.
    }
  }

  /// Probes whether OS built-in AI (Gemini Nano / AICore) is currently ready.
  Future<BuiltInAiAvailability> checkAvailability() async {
    await _ensureInitialized();
    try {
      return await BuiltInAi.availability();
    } catch (_) {
      return BuiltInAiAvailability.unavailableOther;
    }
  }

  String _formatPrompt(AIRequest request) {
    final buffer = StringBuffer();
    if (request.systemInstruction.trim().isNotEmpty) {
      buffer.writeln(request.systemInstruction.trim());
      buffer.writeln();
    }
    final recent = request.messages.length > 6
        ? request.messages.sublist(request.messages.length - 6)
        : request.messages;
    for (final msg in recent) {
      if (msg.isError || msg.content.trim().isEmpty) continue;
      final role = msg.sender == MessageSender.user ? 'User' : 'VISION';
      buffer.writeln('$role: ${msg.content.trim()}');
    }
    buffer.write('VISION:');
    return buffer.toString();
  }

  @override
  Future<AIResponse> generate(
    AIRequest request, {
    required String apiKey,
    AICancellationToken? cancellationToken,
  }) async {
    final sw = Stopwatch()..start();
    final availability = await checkAvailability();
    if (availability != BuiltInAiAvailability.available) {
      throw AIError(
        kind: AIErrorKind.serverError,
        provider: providerType,
        modelId: request.modelId,
        message: 'On-Device Edge AI unavailable ($availability).',
        userMessage:
            'On-Device Gemini Nano (Android AICore) is not available on this device ($availability). '
            'Switch to Gemini, OpenAI, or Claude in Settings for cloud AI.',
      );
    }

    final spec = BuiltInAiModels.forCurrentPlatform ?? BuiltInAiModels.geminiNano;
    final model = await const BuiltInAiEngine().createModel(
      spec,
      const RuntimeConfig(modelPath: 'gemini-nano', maxTokens: 1024),
    );
    try {
      final session = await model.openSession();
      try {
        await session.addQueryChunk(
          Message.text(text: _formatPrompt(request), isUser: true),
        );
        final reply = (await session.getResponse()).trim();
        sw.stop();
        return AIResponse(
          text: reply.isEmpty ? 'No response generated on-device.' : reply,
          provider: providerType,
          modelId: request.modelId,
          latency: sw.elapsed,
          finishReason: 'stop',
        );
      } finally {
        await session.close();
      }
    } catch (error) {
      if (error is AIError) rethrow;
      throw AIError(
        kind: AIErrorKind.serverError,
        provider: providerType,
        modelId: request.modelId,
        message: 'On-Device Edge AI inference error: $error',
        userMessage: 'On-Device Edge AI encountered an error on this device.',
      );
    } finally {
      await model.close();
    }
  }

  @override
  Stream<AIStreamChunk> stream(
    AIRequest request, {
    required String apiKey,
    AICancellationToken? cancellationToken,
  }) async* {
    final sw = Stopwatch()..start();
    final availability = await checkAvailability();
    if (availability != BuiltInAiAvailability.available) {
      throw AIError(
        kind: AIErrorKind.serverError,
        provider: providerType,
        modelId: request.modelId,
        message: 'On-Device Edge AI unavailable ($availability).',
        userMessage:
            'On-Device Gemini Nano (Android AICore) is not available on this device ($availability).',
      );
    }

    final spec = BuiltInAiModels.forCurrentPlatform ?? BuiltInAiModels.geminiNano;
    final model = await const BuiltInAiEngine().createModel(
      spec,
      const RuntimeConfig(modelPath: 'gemini-nano', maxTokens: 1024),
    );
    final buffer = StringBuffer();
    try {
      final session = await model.openSession();
      try {
        await session.addQueryChunk(
          Message.text(text: _formatPrompt(request), isUser: true),
        );
        await for (final token in session.getResponseAsync()) {
          if (cancellationToken?.isCancelled == true) {
            throw AIError(
              kind: AIErrorKind.cancelled,
              provider: providerType,
              modelId: request.modelId,
              message: 'Cancelled',
              userMessage: 'Generation stopped.',
            );
          }
          buffer.write(token);
          yield AITextDeltaChunk(token);
        }
        sw.stop();
        yield AICompletedChunk(
          AIResponse(
            text: buffer.toString().trim(),
            provider: providerType,
            modelId: request.modelId,
            latency: sw.elapsed,
            finishReason: 'stop',
          ),
        );
      } finally {
        await session.close();
      }
    } finally {
      await model.close();
    }
  }

  @override
  Future<List<String>> listAvailableModels({
    required String apiKey,
    AICancellationToken? cancellationToken,
  }) async => const <String>['gemini-nano'];

  @override
  Future<AIConnectionTestResult> testConnection({
    required String apiKey,
    String? modelId,
    AICancellationToken? cancellationToken,
  }) async {
    final sw = Stopwatch()..start();
    final status = await checkAvailability();
    sw.stop();
    final ready = status == BuiltInAiAvailability.available;
    return AIConnectionTestResult(
      provider: providerType,
      modelId: modelId ?? providerType.defaultModel,
      connected: ready,
      message: ready
          ? 'On-Device Gemini Nano (Android AICore) is ready for offline inference.'
          : 'On-Device AICore status: ${status.name}. Hardware/OS support required for Gemini Nano.',
      latency: sw.elapsed,
      availableModels: ready ? const <String>['gemini-nano'] : const <String>[],
      testedAt: DateTime.now(),
    );
  }

  @override
  Future<String> generateReply({
    required AiCompletionRequest request,
    required String apiKey,
  }) async {
    final res = await generate(request.toAiRequest(), apiKey: apiKey);
    return res.text;
  }
}
