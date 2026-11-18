import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'package:vision_ai/core/constants/app_constants.dart';
import 'package:vision_ai/core/utils/secret_redactor.dart';
import 'package:vision_ai/features/chat/domain/entities/ai_model_config.dart';
import 'package:vision_ai/features/chat/domain/entities/ai_models.dart';
import 'package:vision_ai/features/settings/domain/entities/ai_provider_type.dart';

/// Parsed Server-Sent Event item emitted by streaming AI APIs.
class AiSseEvent {
  const AiSseEvent({required this.data, this.event});

  final String? event;
  final String data;
}

/// Shared HTTP transport, SSE streaming, cancellation, retry, and error
/// classification utilities for all [AIProvider] implementations.
abstract final class AiHttpHelper {
  static final Random _jitterRandom = Random();

  /// Executes a JSON HTTP request with safe retry on transient errors
  /// (`429`, `500`, `502`, `503`, `504`, `TimeoutException`, `SocketException`).
  static Future<http.Response> sendWithRetry({
    required http.Client client,
    required AiProviderType provider,
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    String? body,
    String? modelId,
    Duration timeout = AppConstants.aiRequestTimeout,
    int maxRetries = 2,
    AICancellationToken? cancellationToken,
  }) async {
    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      _throwIfCancelled(provider, modelId, cancellationToken);

      try {
        final request = http.Request(method, uri)..headers.addAll(headers);
        if (body != null) {
          request.body = body;
        }

        final streamed = await _raceCancellation(
          client.send(request).timeout(timeout),
          provider: provider,
          modelId: modelId,
          cancellationToken: cancellationToken,
        );
        final response = await _raceCancellation(
          http.Response.fromStream(streamed).timeout(timeout),
          provider: provider,
          modelId: modelId,
          cancellationToken: cancellationToken,
        );

        if (response.statusCode >= 200 && response.statusCode < 300) {
          return response;
        }

        final aiError = classifyHttpError(
          provider: provider,
          modelId: modelId,
          statusCode: response.statusCode,
          responseBody: response.body,
          headers: response.headers,
        );

        if (attempt < maxRetries && aiError.isRetryable) {
          final delay = _computeBackoff(attempt, aiError.retryAfter);
          await _sleepWithCancellation(
            delay,
            provider: provider,
            modelId: modelId,
            cancellationToken: cancellationToken,
          );
          continue;
        }

        throw aiError;
      } on AIError catch (error) {
        if (attempt < maxRetries && error.isRetryable) {
          final delay = _computeBackoff(attempt, error.retryAfter);
          await _sleepWithCancellation(
            delay,
            provider: provider,
            modelId: modelId,
            cancellationToken: cancellationToken,
          );
          continue;
        }
        rethrow;
      } on TimeoutException catch (error, stackTrace) {
        if (attempt < maxRetries) {
          await _sleepWithCancellation(
            _computeBackoff(attempt, null),
            provider: provider,
            modelId: modelId,
            cancellationToken: cancellationToken,
          );
          continue;
        }
        throw AIError(
          kind: AIErrorKind.timeout,
          provider: provider,
          modelId: modelId,
          message: 'Request to ${provider.displayName} timed out.',
          userMessage:
              'Request to ${provider.displayName} timed out. Check your internet connection and try again.',
          cause: error,
          stackTrace: stackTrace,
        );
      } on SocketException catch (error, stackTrace) {
        if (attempt < maxRetries) {
          await _sleepWithCancellation(
            _computeBackoff(attempt, null),
            provider: provider,
            modelId: modelId,
            cancellationToken: cancellationToken,
          );
          continue;
        }
        throw AIError(
          kind: AIErrorKind.networkUnavailable,
          provider: provider,
          modelId: modelId,
          message:
              'Network connection unavailable for ${provider.displayName}.',
          userMessage:
              'Unable to reach ${provider.displayName}. Check your Wi-Fi or mobile data connection.',
          cause: error,
          stackTrace: stackTrace,
        );
      } on http.ClientException catch (error, stackTrace) {
        throw AIError(
          kind: AIErrorKind.networkUnavailable,
          provider: provider,
          modelId: modelId,
          message: SecretRedactor.redact(
            'HTTP client error for ${provider.displayName}: ${error.message}',
          ),
          userMessage:
              'Network error communicating with ${provider.displayName}.',
          cause: error,
          stackTrace: stackTrace,
        );
      }
    }

    throw AIError(
      kind: AIErrorKind.serverError,
      provider: provider,
      modelId: modelId,
      message: '${provider.displayName} request failed after retries.',
      userMessage:
          '${provider.displayName} is temporarily unavailable. Please try again.',
    );
  }

  /// Opens an SSE streaming POST request with initial connection retry before
  /// the first chunk arrives and cooperative cancellation support.
  static Stream<AiSseEvent> streamSse({
    required http.Client client,
    required AiProviderType provider,
    required Uri uri,
    required Map<String, String> headers,
    required String body,
    String? modelId,
    Duration timeout = AppConstants.aiRequestTimeout,
    int maxRetries = 1,
    AICancellationToken? cancellationToken,
  }) async* {
    http.StreamedResponse? streamedResponse;

    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      _throwIfCancelled(provider, modelId, cancellationToken);
      try {
        final request = http.Request('POST', uri)
          ..headers.addAll(headers)
          ..body = body;
        final response = await _raceCancellation(
          client.send(request).timeout(timeout),
          provider: provider,
          modelId: modelId,
          cancellationToken: cancellationToken,
        );

        if (response.statusCode >= 200 && response.statusCode < 300) {
          streamedResponse = response;
          break;
        }

        final errorBody = await response.stream.bytesToString().timeout(
          const Duration(seconds: 10),
          onTimeout: () => '',
        );
        final aiError = classifyHttpError(
          provider: provider,
          modelId: modelId,
          statusCode: response.statusCode,
          responseBody: errorBody,
          headers: response.headers,
        );
        if (attempt < maxRetries && aiError.isRetryable) {
          await _sleepWithCancellation(
            _computeBackoff(attempt, aiError.retryAfter),
            provider: provider,
            modelId: modelId,
            cancellationToken: cancellationToken,
          );
          continue;
        }
        throw aiError;
      } on TimeoutException catch (error, stackTrace) {
        if (attempt < maxRetries) {
          await _sleepWithCancellation(
            _computeBackoff(attempt, null),
            provider: provider,
            modelId: modelId,
            cancellationToken: cancellationToken,
          );
          continue;
        }
        throw AIError(
          kind: AIErrorKind.timeout,
          provider: provider,
          modelId: modelId,
          message: 'Streaming connection to ${provider.displayName} timed out.',
          userMessage:
              'Connection to ${provider.displayName} timed out. Check your network and try again.',
          cause: error,
          stackTrace: stackTrace,
        );
      } on SocketException catch (error, stackTrace) {
        throw AIError(
          kind: AIErrorKind.networkUnavailable,
          provider: provider,
          modelId: modelId,
          message:
              'Network unavailable while streaming ${provider.displayName}.',
          userMessage:
              'Unable to reach ${provider.displayName}. Check your internet connection.',
          cause: error,
          stackTrace: stackTrace,
        );
      }
    }

    if (streamedResponse == null) {
      throw AIError(
        kind: AIErrorKind.serverError,
        provider: provider,
        modelId: modelId,
        message: 'Failed to open stream to ${provider.displayName}.',
        userMessage: 'Unable to open stream with ${provider.displayName}.',
      );
    }

    final controller = StreamController<String>();
    final subscription = streamedResponse.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          controller.add,
          onError: controller.addError,
          onDone: controller.close,
          cancelOnError: true,
        );

    void onCancel() {
      unawaited(subscription.cancel());
      if (!controller.isClosed) {
        controller.addError(
          AIError(
            kind: AIErrorKind.cancelled,
            provider: provider,
            modelId: modelId,
            message: 'Request cancelled by user.',
            userMessage: 'Request cancelled.',
          ),
        );
        unawaited(controller.close());
      }
    }

    cancellationToken?.addListener(onCancel);

    String? currentEvent;
    final dataLines = <String>[];

    try {
      await for (final line in controller.stream) {
        _throwIfCancelled(provider, modelId, cancellationToken);
        if (line.isEmpty) {
          if (dataLines.isNotEmpty) {
            final payload = dataLines.join('\n').trim();
            dataLines.clear();
            final eventName = currentEvent;
            currentEvent = null;
            if (payload.isNotEmpty) {
              yield AiSseEvent(event: eventName, data: payload);
            }
          } else {
            currentEvent = null;
          }
          continue;
        }
        if (line.startsWith(':')) {
          continue; // SSE comment / heartbeat
        }
        if (line.startsWith('event:')) {
          currentEvent = line.substring(6).trim();
          continue;
        }
        if (line.startsWith('data:')) {
          dataLines.add(line.substring(5).trimLeft());
        }
      }

      if (dataLines.isNotEmpty) {
        final payload = dataLines.join('\n').trim();
        if (payload.isNotEmpty) {
          yield AiSseEvent(event: currentEvent, data: payload);
        }
      }
    } finally {
      cancellationToken?.removeListener(onCancel);
      await subscription.cancel();
    }
  }

  /// Classifies provider HTTP errors into structured [AIError] values with safe
  /// user-facing explanations.
  static AIError classifyHttpError({
    required AiProviderType provider,
    required int statusCode,
    required String responseBody,
    String? modelId,
    Map<String, String> headers = const <String, String>{},
  }) {
    final rawMessage = SecretRedactor.redact(
      _extractProviderErrorMessage(responseBody, statusCode, provider),
    );
    final lower = rawMessage.toLowerCase();
    final retryAfter = _parseRetryAfter(headers);

    if (statusCode == 401 ||
        statusCode == 403 ||
        lower.contains('api key not valid') ||
        lower.contains('api_key_invalid') ||
        lower.contains('invalid x-api-key') ||
        lower.contains('incorrect api key') ||
        lower.contains('authentication')) {
      return AIError(
        kind: AIErrorKind.invalidApiKey,
        provider: provider,
        modelId: modelId,
        statusCode: statusCode,
        message: rawMessage,
        userMessage:
            'Invalid or unauthorized ${provider.displayName} API key (HTTP $statusCode). '
            'Update your key in Settings and test the connection.',
      );
    }

    if (statusCode == 429 ||
        lower.contains('rate limit') ||
        lower.contains('quota') ||
        lower.contains('insufficient_quota') ||
        lower.contains('billing')) {
      final isQuota =
          lower.contains('quota') ||
          lower.contains('billing') ||
          lower.contains('credit') ||
          lower.contains('balance');
      return AIError(
        kind: isQuota ? AIErrorKind.quotaExceeded : AIErrorKind.rateLimited,
        provider: provider,
        modelId: modelId,
        statusCode: statusCode,
        retryAfter: retryAfter,
        message: rawMessage,
        userMessage: isQuota
            ? '${provider.displayName} quota or billing limit exceeded: $rawMessage'
            : '${provider.displayName} rate limit reached. Please wait briefly and try again.',
      );
    }

    if (statusCode == 404 ||
        lower.contains('no longer available') ||
        lower.contains('deprecated') ||
        lower.contains('not found') ||
        lower.contains('does not exist') ||
        lower.contains('not supported for generatecontent')) {
      final suggested = modelId != null
          ? AIModelRegistry.deprecationReplacement(modelId) ??
                AIModelRegistry.defaultModelFor(provider).modelId
          : AIModelRegistry.defaultModelFor(provider).modelId;
      return AIError(
        kind: AIErrorKind.modelUnavailable,
        provider: provider,
        modelId: modelId,
        statusCode: statusCode,
        suggestedModelId: suggested,
        message: rawMessage,
        userMessage:
            'Model "${modelId ?? provider.defaultModel}" is unavailable on '
            '${provider.displayName}: $rawMessage. Recommended model: $suggested.',
      );
    }

    if (statusCode == 408) {
      return AIError(
        kind: AIErrorKind.timeout,
        provider: provider,
        modelId: modelId,
        statusCode: statusCode,
        message: rawMessage,
        userMessage: '${provider.displayName} request timed out (HTTP 408).',
      );
    }

    if (statusCode >= 500) {
      return AIError(
        kind: AIErrorKind.serverError,
        provider: provider,
        modelId: modelId,
        statusCode: statusCode,
        retryAfter: retryAfter,
        message: rawMessage,
        userMessage:
            '${provider.displayName} service error (HTTP $statusCode). Please retry shortly.',
      );
    }

    return AIError(
      kind: AIErrorKind.badRequest,
      provider: provider,
      modelId: modelId,
      statusCode: statusCode,
      message: rawMessage,
      userMessage: '${provider.displayName} rejected the request: $rawMessage',
    );
  }

  static String _extractProviderErrorMessage(
    String responseBody,
    int statusCode,
    AiProviderType provider,
  ) {
    try {
      final decoded = jsonDecode(responseBody);
      if (decoded is Map<String, dynamic>) {
        if (decoded case {'error': {'message': final String msg}}) {
          return msg;
        }
        if (decoded case {'message': final String msg}) {
          return msg;
        }
      }
    } on FormatException {
      // Fall through to status code message.
    }
    return '${provider.displayName} returned HTTP $statusCode.';
  }

  static Duration? _parseRetryAfter(Map<String, String> headers) {
    final raw = headers['retry-after'] ?? headers['Retry-After'];
    if (raw == null) return null;
    final seconds = int.tryParse(raw.trim());
    if (seconds != null && seconds > 0) {
      return Duration(seconds: seconds.clamp(1, 15));
    }
    return null;
  }

  static Duration _computeBackoff(int attempt, Duration? retryAfter) {
    if (retryAfter != null) {
      return retryAfter;
    }
    final baseMs = 500 * (1 << attempt);
    final jitterMs = _jitterRandom.nextInt(250);
    return Duration(milliseconds: baseMs + jitterMs);
  }

  static void _throwIfCancelled(
    AiProviderType provider,
    String? modelId,
    AICancellationToken? token,
  ) {
    if (token?.isCancelled ?? false) {
      throw AIError(
        kind: AIErrorKind.cancelled,
        provider: provider,
        modelId: modelId,
        message: 'Request cancelled by user.',
        userMessage: 'Request cancelled.',
      );
    }
  }

  static Future<T> _raceCancellation<T>(
    Future<T> future, {
    required AiProviderType provider,
    required String? modelId,
    AICancellationToken? cancellationToken,
  }) {
    if (cancellationToken == null) return future;
    if (cancellationToken.isCancelled) {
      return Future<T>.error(
        AIError(
          kind: AIErrorKind.cancelled,
          provider: provider,
          modelId: modelId,
          message: 'Request cancelled by user.',
          userMessage: 'Request cancelled.',
        ),
      );
    }

    final completer = Completer<T>();
    void onCancel() {
      if (!completer.isCompleted) {
        completer.completeError(
          AIError(
            kind: AIErrorKind.cancelled,
            provider: provider,
            modelId: modelId,
            message: 'Request cancelled by user.',
            userMessage: 'Request cancelled.',
          ),
        );
      }
    }

    cancellationToken.addListener(onCancel);
    future.then(
      (value) {
        cancellationToken.removeListener(onCancel);
        if (!completer.isCompleted) completer.complete(value);
      },
      onError: (Object error, StackTrace stackTrace) {
        cancellationToken.removeListener(onCancel);
        if (!completer.isCompleted) completer.completeError(error, stackTrace);
      },
    );
    return completer.future;
  }

  static Future<void> _sleepWithCancellation(
    Duration duration, {
    required AiProviderType provider,
    required String? modelId,
    AICancellationToken? cancellationToken,
  }) {
    if (cancellationToken == null) return Future<void>.delayed(duration);
    final completer = Completer<void>();
    Timer? timer;
    void onCancel() {
      timer?.cancel();
      if (!completer.isCompleted) {
        completer.completeError(
          AIError(
            kind: AIErrorKind.cancelled,
            provider: provider,
            modelId: modelId,
            message: 'Request cancelled by user.',
            userMessage: 'Request cancelled.',
          ),
        );
      }
    }

    cancellationToken.addListener(onCancel);
    timer = Timer(duration, () {
      cancellationToken.removeListener(onCancel);
      if (!completer.isCompleted) completer.complete();
    });
    return completer.future;
  }
}
