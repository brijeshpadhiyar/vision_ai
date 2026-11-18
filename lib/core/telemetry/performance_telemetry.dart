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

/// Immutable snapshot of runtime latency and execution telemetry.
@immutable
class PerformanceSnapshot {
  const PerformanceSnapshot({
    this.intentParseCount = 0,
    this.avgIntentParseMicros = 0,
    this.localCommandCount = 0,
    this.localCommandSuccessCount = 0,
    this.automationCount = 0,
    this.automationSuccessCount = 0,
    this.avgAutomationMs = 0,
    this.aiRequestCount = 0,
    this.aiSuccessCount = 0,
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

  final int intentParseCount;
  final double avgIntentParseMicros;
  final int localCommandCount;
  final int localCommandSuccessCount;
  final int automationCount;
  final int automationSuccessCount;
  final double avgAutomationMs;
  final int aiRequestCount;
  final int aiSuccessCount;
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

  Map<String, Object?> toSanitizedReport() => <String, Object?>{
    'intentParseCount': intentParseCount,
    'avgIntentParseMicros': avgIntentParseMicros.round(),
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

  int _totalIntentMicros = 0;
  int _totalAutomationMs = 0;
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

  void recordIntentParse(int micros, {required bool localHandled}) {
    final nextCount = state.intentParseCount + 1;
    _totalIntentMicros += micros;
    final nextLocalCount = state.localCommandCount + (localHandled ? 1 : 0);
    state = PerformanceSnapshot(
      intentParseCount: nextCount,
      avgIntentParseMicros: _totalIntentMicros / nextCount,
      localCommandCount: nextLocalCount,
      localCommandSuccessCount: state.localCommandSuccessCount,
      automationCount: state.automationCount,
      automationSuccessCount: state.automationSuccessCount,
      avgAutomationMs: state.avgAutomationMs,
      aiRequestCount: state.aiRequestCount,
      aiSuccessCount: state.aiSuccessCount,
      avgAiFirstTokenMs: state.avgAiFirstTokenMs,
      avgAiTotalMs: state.avgAiTotalMs,
      lastAiProvider: state.lastAiProvider,
      lastAiModelId: state.lastAiModelId,
      voiceSttCount: state.voiceSttCount,
      avgVoiceSttMs: state.avgVoiceSttMs,
      avgTtsStartupMs: state.avgTtsStartupMs,
      avgEndToEndMs: state.avgEndToEndMs,
      recentErrors: state.recentErrors,
    );
  }

  void recordAutomationExecution(
    DeviceActionType actionType,
    int durationMs, {
    required bool success,
    bool wasLocal = true,
  }) {
    final nextAutoCount = state.automationCount + 1;
    final nextSuccess = state.automationSuccessCount + (success ? 1 : 0);
    _totalAutomationMs += durationMs;
    final nextLocalSuccess =
        state.localCommandSuccessCount + (wasLocal && success ? 1 : 0);

    state = PerformanceSnapshot(
      intentParseCount: state.intentParseCount,
      avgIntentParseMicros: state.avgIntentParseMicros,
      localCommandCount: state.localCommandCount,
      localCommandSuccessCount: nextLocalSuccess,
      automationCount: nextAutoCount,
      automationSuccessCount: nextSuccess,
      avgAutomationMs: _totalAutomationMs / nextAutoCount,
      aiRequestCount: state.aiRequestCount,
      aiSuccessCount: state.aiSuccessCount,
      avgAiFirstTokenMs: state.avgAiFirstTokenMs,
      avgAiTotalMs: state.avgAiTotalMs,
      lastAiProvider: state.lastAiProvider,
      lastAiModelId: state.lastAiModelId,
      voiceSttCount: state.voiceSttCount,
      avgVoiceSttMs: state.avgVoiceSttMs,
      avgTtsStartupMs: state.avgTtsStartupMs,
      avgEndToEndMs: state.avgEndToEndMs,
      recentErrors: state.recentErrors,
    );
  }

  void recordAiLatency(
    AiProviderType provider,
    String modelId, {
    required int totalMs,
    int? firstTokenMs,
    required bool success,
  }) {
    final nextCount = state.aiRequestCount + 1;
    final nextSuccess = state.aiSuccessCount + (success ? 1 : 0);
    _totalAiMs += totalMs;
    if (firstTokenMs != null && firstTokenMs >= 0) {
      _totalFirstTokenMs += firstTokenMs;
      _firstTokenSamples++;
    }

    state = PerformanceSnapshot(
      intentParseCount: state.intentParseCount,
      avgIntentParseMicros: state.avgIntentParseMicros,
      localCommandCount: state.localCommandCount,
      localCommandSuccessCount: state.localCommandSuccessCount,
      automationCount: state.automationCount,
      automationSuccessCount: state.automationSuccessCount,
      avgAutomationMs: state.avgAutomationMs,
      aiRequestCount: nextCount,
      aiSuccessCount: nextSuccess,
      avgAiFirstTokenMs: _firstTokenSamples == 0
          ? 0
          : _totalFirstTokenMs / _firstTokenSamples,
      avgAiTotalMs: _totalAiMs / nextCount,
      lastAiProvider: provider,
      lastAiModelId: modelId,
      voiceSttCount: state.voiceSttCount,
      avgVoiceSttMs: state.avgVoiceSttMs,
      avgTtsStartupMs: state.avgTtsStartupMs,
      avgEndToEndMs: state.avgEndToEndMs,
      recentErrors: state.recentErrors,
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

    state = PerformanceSnapshot(
      intentParseCount: state.intentParseCount,
      avgIntentParseMicros: state.avgIntentParseMicros,
      localCommandCount: state.localCommandCount,
      localCommandSuccessCount: state.localCommandSuccessCount,
      automationCount: state.automationCount,
      automationSuccessCount: state.automationSuccessCount,
      avgAutomationMs: state.avgAutomationMs,
      aiRequestCount: state.aiRequestCount,
      aiSuccessCount: state.aiSuccessCount,
      avgAiFirstTokenMs: state.avgAiFirstTokenMs,
      avgAiTotalMs: state.avgAiTotalMs,
      lastAiProvider: state.lastAiProvider,
      lastAiModelId: state.lastAiModelId,
      voiceSttCount: nextVoiceCount,
      avgVoiceSttMs: nextAvgStt,
      avgTtsStartupMs: nextAvgTts,
      avgEndToEndMs: nextAvgE2e,
      recentErrors: state.recentErrors,
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

    state = PerformanceSnapshot(
      intentParseCount: state.intentParseCount,
      avgIntentParseMicros: state.avgIntentParseMicros,
      localCommandCount: state.localCommandCount,
      localCommandSuccessCount: state.localCommandSuccessCount,
      automationCount: state.automationCount,
      automationSuccessCount: state.automationSuccessCount,
      avgAutomationMs: state.avgAutomationMs,
      aiRequestCount: state.aiRequestCount,
      aiSuccessCount: state.aiSuccessCount,
      avgAiFirstTokenMs: state.avgAiFirstTokenMs,
      avgAiTotalMs: state.avgAiTotalMs,
      lastAiProvider: state.lastAiProvider,
      lastAiModelId: state.lastAiModelId,
      voiceSttCount: state.voiceSttCount,
      avgVoiceSttMs: state.avgVoiceSttMs,
      avgTtsStartupMs: state.avgTtsStartupMs,
      avgEndToEndMs: state.avgEndToEndMs,
      recentErrors: updated,
    );
  }

  void clearErrors() {
    state = PerformanceSnapshot(
      intentParseCount: state.intentParseCount,
      avgIntentParseMicros: state.avgIntentParseMicros,
      localCommandCount: state.localCommandCount,
      localCommandSuccessCount: state.localCommandSuccessCount,
      automationCount: state.automationCount,
      automationSuccessCount: state.automationSuccessCount,
      avgAutomationMs: state.avgAutomationMs,
      aiRequestCount: state.aiRequestCount,
      aiSuccessCount: state.aiSuccessCount,
      avgAiFirstTokenMs: state.avgAiFirstTokenMs,
      avgAiTotalMs: state.avgAiTotalMs,
      lastAiProvider: state.lastAiProvider,
      lastAiModelId: state.lastAiModelId,
      voiceSttCount: state.voiceSttCount,
      avgVoiceSttMs: state.avgVoiceSttMs,
      avgTtsStartupMs: state.avgTtsStartupMs,
      avgEndToEndMs: state.avgEndToEndMs,
    );
  }
}
