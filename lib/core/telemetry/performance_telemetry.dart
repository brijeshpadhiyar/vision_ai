import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vision_ai/core/utils/secret_redactor.dart';
import 'package:vision_ai/features/automation/domain/entities/device_action.dart';
import 'package:vision_ai/features/settings/domain/entities/ai_provider_type.dart';

/// Sanitized error entry stored in a bounded in-memory ring buffer.
@immutable
class SanitizedDiagnosticError {
  const SanitizedDiagnosticError({
    required this.timestamp,
    required this.source,
    required this.message,
  });

  final DateTime timestamp;
  final String source;
  final String message;

  Map<String, Object?> toJson() => <String, Object?>{
    'timestamp': timestamp.toIso8601String(),
    'source': source,
    'message': message,
  };
}

/// Immutable snapshot of per-stage runtime latency and execution telemetry.
@immutable
class PerformanceSnapshot {
  const PerformanceSnapshot({
    this.wakeDetectionCount = 0,
    this.avgWakeDetectionMs = 0,
    this.intentParseCount = 0,
    this.avgIntentParseMicros = 0,
    this.contactResolutionCount = 0,
    this.avgContactResolutionMs = 0,
    this.localCommandCount = 0,
    this.localCommandSuccessCount = 0,
    this.automationCount = 0,
    this.automationSuccessCount = 0,
    this.avgAutomationMs = 0,
    this.aiRequestCount = 0,
    this.aiSuccessCount = 0,
    this.avgAiStartupMs = 0,
    this.avgAiFirstTokenMs = 0,
    this.avgAiTotalMs = 0,
    this.lastAiProvider,
    this.lastAiModelId,
    this.voiceSttCount = 0,
    this.avgVoiceSttMs = 0,
    this.avgTtsStartupMs = 0,
    this.avgEndToEndMs = 0,
    this.recentErrors = const <SanitizedDiagnosticError>[],
  });

  final int wakeDetectionCount;
  final double avgWakeDetectionMs;
  final int intentParseCount;
  final double avgIntentParseMicros;
  final int contactResolutionCount;
  final double avgContactResolutionMs;
  final int localCommandCount;
  final int localCommandSuccessCount;
  final int automationCount;
  final int automationSuccessCount;
  final double avgAutomationMs;
  final int aiRequestCount;
  final int aiSuccessCount;
  final double avgAiStartupMs;
  final double avgAiFirstTokenMs;
  final double avgAiTotalMs;
  final AiProviderType? lastAiProvider;
  final String? lastAiModelId;
  final int voiceSttCount;
  final double avgVoiceSttMs;
  final double avgTtsStartupMs;
  final double avgEndToEndMs;
  final List<SanitizedDiagnosticError> recentErrors;

  double get automationSuccessRate =>
      automationCount == 0 ? 1.0 : automationSuccessCount / automationCount;

  double get aiSuccessRate =>
      aiRequestCount == 0 ? 1.0 : aiSuccessCount / aiRequestCount;

  PerformanceSnapshot copyWith({
    int? wakeDetectionCount,
    double? avgWakeDetectionMs,
    int? intentParseCount,
    double? avgIntentParseMicros,
    int? contactResolutionCount,
    double? avgContactResolutionMs,
    int? localCommandCount,
    int? localCommandSuccessCount,
    int? automationCount,
    int? automationSuccessCount,
    double? avgAutomationMs,
    int? aiRequestCount,
    int? aiSuccessCount,
    double? avgAiStartupMs,
    double? avgAiFirstTokenMs,
    double? avgAiTotalMs,
    AiProviderType? lastAiProvider,
    String? lastAiModelId,
    int? voiceSttCount,
    double? avgVoiceSttMs,
    double? avgTtsStartupMs,
    double? avgEndToEndMs,
    List<SanitizedDiagnosticError>? recentErrors,
  }) {
    return PerformanceSnapshot(
      wakeDetectionCount: wakeDetectionCount ?? this.wakeDetectionCount,
      avgWakeDetectionMs: avgWakeDetectionMs ?? this.avgWakeDetectionMs,
      intentParseCount: intentParseCount ?? this.intentParseCount,
      avgIntentParseMicros: avgIntentParseMicros ?? this.avgIntentParseMicros,
      contactResolutionCount:
          contactResolutionCount ?? this.contactResolutionCount,
      avgContactResolutionMs:
          avgContactResolutionMs ?? this.avgContactResolutionMs,
      localCommandCount: localCommandCount ?? this.localCommandCount,
      localCommandSuccessCount:
          localCommandSuccessCount ?? this.localCommandSuccessCount,
      automationCount: automationCount ?? this.automationCount,
      automationSuccessCount:
          automationSuccessCount ?? this.automationSuccessCount,
      avgAutomationMs: avgAutomationMs ?? this.avgAutomationMs,
      aiRequestCount: aiRequestCount ?? this.aiRequestCount,
      aiSuccessCount: aiSuccessCount ?? this.aiSuccessCount,
      avgAiStartupMs: avgAiStartupMs ?? this.avgAiStartupMs,
      avgAiFirstTokenMs: avgAiFirstTokenMs ?? this.avgAiFirstTokenMs,
      avgAiTotalMs: avgAiTotalMs ?? this.avgAiTotalMs,
      lastAiProvider: lastAiProvider ?? this.lastAiProvider,
      lastAiModelId: lastAiModelId ?? this.lastAiModelId,
      voiceSttCount: voiceSttCount ?? this.voiceSttCount,
      avgVoiceSttMs: avgVoiceSttMs ?? this.avgVoiceSttMs,
      avgTtsStartupMs: avgTtsStartupMs ?? this.avgTtsStartupMs,
      avgEndToEndMs: avgEndToEndMs ?? this.avgEndToEndMs,
      recentErrors: recentErrors ?? this.recentErrors,
    );
  }

  Map<String, Object?> toSanitizedReport() => <String, Object?>{
    'wakeDetectionCount': wakeDetectionCount,
    'avgWakeDetectionMs': avgWakeDetectionMs.round(),
    'intentParseCount': intentParseCount,
    'avgIntentParseMicros': avgIntentParseMicros.round(),
    'contactResolutionCount': contactResolutionCount,
    'avgContactResolutionMs': avgContactResolutionMs.round(),
    'localCommandCount': localCommandCount,
    'localCommandSuccessCount': localCommandSuccessCount,
    'automationCount': automationCount,
    'automationSuccessCount': automationSuccessCount,
    'automationSuccessRate': double.parse(
      automationSuccessRate.toStringAsFixed(3),
    ),
    'avgAutomationMs': avgAutomationMs.round(),
    'aiRequestCount': aiRequestCount,
    'aiSuccessCount': aiSuccessCount,
    'aiSuccessRate': double.parse(aiSuccessRate.toStringAsFixed(3)),
    'avgAiStartupMs': avgAiStartupMs.round(),
    'avgAiFirstTokenMs': avgAiFirstTokenMs.round(),
    'avgAiTotalMs': avgAiTotalMs.round(),
    'lastAiProvider': lastAiProvider?.id,
    'lastAiModelId': lastAiModelId,
    'voiceSttCount': voiceSttCount,
    'avgVoiceSttMs': avgVoiceSttMs.round(),
    'avgTtsStartupMs': avgTtsStartupMs.round(),
    'avgEndToEndMs': avgEndToEndMs.round(),
    'recentErrors': recentErrors.map((e) => e.toJson()).toList(),
  };
}

/// Provides application-wide privacy-safe telemetry tracking.
final telemetryProvider =
    NotifierProvider<TelemetryNotifier, PerformanceSnapshot>(
      TelemetryNotifier.new,
    );

/// Tracks per-stage latency averages, execution rates, and sanitized errors
/// without storing PII, contact names, API keys, or prompt contents.
class TelemetryNotifier extends Notifier<PerformanceSnapshot> {
  static const int _maxErrors = 25;

  int _totalWakeMs = 0;
  int _totalIntentMicros = 0;
  int _totalContactMs = 0;
  int _totalAutomationMs = 0;
  int _totalAiStartupMs = 0;
  int _aiStartupSamples = 0;
  int _totalFirstTokenMs = 0;
  int _firstTokenSamples = 0;
  int _totalAiMs = 0;
  int _totalVoiceSttMs = 0;
  int _totalTtsStartupMs = 0;
  int _ttsSamples = 0;
  int _totalEndToEndMs = 0;
  int _e2eSamples = 0;

  @override
  PerformanceSnapshot build() => const PerformanceSnapshot();

  void recordWakeDetection(int durationMs) {
    final next = state.wakeDetectionCount + 1;
    _totalWakeMs += durationMs;
    state = state.copyWith(
      wakeDetectionCount: next,
      avgWakeDetectionMs: _totalWakeMs / next,
    );
  }

  void recordIntentParse(int micros, {required bool localHandled}) {
    final nextCount = state.intentParseCount + 1;
    _totalIntentMicros += micros;
    state = state.copyWith(
      intentParseCount: nextCount,
      avgIntentParseMicros: _totalIntentMicros / nextCount,
      localCommandCount: state.localCommandCount + (localHandled ? 1 : 0),
    );
  }

  void recordContactResolution(int durationMs) {
    final next = state.contactResolutionCount + 1;
    _totalContactMs += durationMs;
    state = state.copyWith(
      contactResolutionCount: next,
      avgContactResolutionMs: _totalContactMs / next,
    );
  }

  void recordAutomationExecution(
    DeviceActionType actionType,
    int durationMs, {
    required bool success,
    bool wasLocal = true,
  }) {
    final nextAutoCount = state.automationCount + 1;
    _totalAutomationMs += durationMs;
    state = state.copyWith(
      automationCount: nextAutoCount,
      automationSuccessCount: state.automationSuccessCount + (success ? 1 : 0),
      localCommandSuccessCount:
          state.localCommandSuccessCount + (wasLocal && success ? 1 : 0),
      avgAutomationMs: _totalAutomationMs / nextAutoCount,
    );
  }

  void recordAiLatency(
    AiProviderType provider,
    String modelId, {
    required int totalMs,
    int? startupMs,
    int? firstTokenMs,
    required bool success,
  }) {
    final nextCount = state.aiRequestCount + 1;
    _totalAiMs += totalMs;
    if (startupMs != null && startupMs >= 0) {
      _totalAiStartupMs += startupMs;
      _aiStartupSamples++;
    }
    if (firstTokenMs != null && firstTokenMs >= 0) {
      _totalFirstTokenMs += firstTokenMs;
      _firstTokenSamples++;
    }

    state = state.copyWith(
      aiRequestCount: nextCount,
      aiSuccessCount: state.aiSuccessCount + (success ? 1 : 0),
      avgAiStartupMs: _aiStartupSamples == 0
          ? state.avgAiStartupMs
          : _totalAiStartupMs / _aiStartupSamples,
      avgAiFirstTokenMs: _firstTokenSamples == 0
          ? state.avgAiFirstTokenMs
          : _totalFirstTokenMs / _firstTokenSamples,
      avgAiTotalMs: _totalAiMs / nextCount,
      lastAiProvider: provider,
      lastAiModelId: modelId,
    );
  }

  void recordVoiceLatency({
    int? sttFinalMs,
    int? ttsStartupMs,
    int? endToEndMs,
  }) {
    var nextVoiceCount = state.voiceSttCount;
    var nextAvgStt = state.avgVoiceSttMs;
    if (sttFinalMs != null && sttFinalMs >= 0) {
      nextVoiceCount++;
      _totalVoiceSttMs += sttFinalMs;
      nextAvgStt = _totalVoiceSttMs / nextVoiceCount;
    }

    var nextAvgTts = state.avgTtsStartupMs;
    if (ttsStartupMs != null && ttsStartupMs >= 0) {
      _ttsSamples++;
      _totalTtsStartupMs += ttsStartupMs;
      nextAvgTts = _totalTtsStartupMs / _ttsSamples;
    }

    var nextAvgE2e = state.avgEndToEndMs;
    if (endToEndMs != null && endToEndMs >= 0) {
      _e2eSamples++;
      _totalEndToEndMs += endToEndMs;
      nextAvgE2e = _totalEndToEndMs / _e2eSamples;
    }

    state = state.copyWith(
      voiceSttCount: nextVoiceCount,
      avgVoiceSttMs: nextAvgStt,
      avgTtsStartupMs: nextAvgTts,
      avgEndToEndMs: nextAvgE2e,
    );
  }

  void recordSanitizedError(String source, Object error) {
    final redacted = SecretRedactor.redact(error.toString());
    final truncated = redacted.length > 220
        ? '${redacted.substring(0, 217)}...'
        : redacted;
    final entry = SanitizedDiagnosticError(
      timestamp: DateTime.now(),
      source: source,
      message: truncated,
    );
    final updated = <SanitizedDiagnosticError>[
      entry,
      ...state.recentErrors,
    ].take(_maxErrors).toList(growable: false);

    state = state.copyWith(recentErrors: updated);
  }

  void clearErrors() {
    state = state.copyWith(recentErrors: const <SanitizedDiagnosticError>[]);
  }
}
