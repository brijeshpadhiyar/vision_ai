import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vision_ai/features/chat/domain/entities/ai_models.dart';
import 'package:vision_ai/features/settings/domain/entities/ai_provider_type.dart';

enum ProviderCircuitState { healthy, degraded, cooldown }

/// Live operational health metrics for an individual AI provider.
class ProviderHealthRecord {
  const ProviderHealthRecord({
    this.circuitState = ProviderCircuitState.healthy,
    this.consecutiveFailures = 0,
    this.avgLatencyMs = 0,
    this.lastSuccessAt,
    this.lastFailureAt,
    this.cooldownUntil,
    this.lastErrorKind,
  });

  final ProviderCircuitState circuitState;
  final int consecutiveFailures;
  final double avgLatencyMs;
  final DateTime? lastSuccessAt;
  final DateTime? lastFailureAt;
  final DateTime? cooldownUntil;
  final AIErrorKind? lastErrorKind;

  bool isAvailableAt(DateTime now) {
    if (circuitState != ProviderCircuitState.cooldown) return true;
    return cooldownUntil == null || !now.isBefore(cooldownUntil!);
  }
}

/// Shared Riverpod provider for provider circuit-breaker & latency health state.
final providerHealthManagerProvider = Provider<ProviderHealthManager>((ref) {
  return ProviderHealthManager();
});

/// Tracks per-provider health, failure cooldowns, and rolling latency averages
/// so failing providers do not repeatedly stall user requests.
class ProviderHealthManager {
  final Map<AiProviderType, ProviderHealthRecord> _records =
      <AiProviderType, ProviderHealthRecord>{
        for (final provider in AiProviderType.values)
          provider: const ProviderHealthRecord(),
      };

  final Map<AiProviderType, int> _successSamples = <AiProviderType, int>{};
  final Map<AiProviderType, int> _cumulativeLatencyMs = <AiProviderType, int>{};

  ProviderHealthRecord recordFor(AiProviderType provider) =>
      _records[provider] ?? const ProviderHealthRecord();

  Map<AiProviderType, ProviderHealthRecord> snapshotAll() =>
      Map<AiProviderType, ProviderHealthRecord>.unmodifiable(_records);

  bool isProviderAvailable(AiProviderType provider, {DateTime? now}) {
    final record = _records[provider];
    if (record == null) return true;
    return record.isAvailableAt(now ?? DateTime.now());
  }

  void recordSuccess(AiProviderType provider, {required int latencyMs}) {
    final samples = (_successSamples[provider] ?? 0) + 1;
    final total = (_cumulativeLatencyMs[provider] ?? 0) + latencyMs;
    _successSamples[provider] = samples;
    _cumulativeLatencyMs[provider] = total;

    _records[provider] = ProviderHealthRecord(
      circuitState: ProviderCircuitState.healthy,
      consecutiveFailures: 0,
      avgLatencyMs: total / samples,
      lastSuccessAt: DateTime.now(),
      lastFailureAt: _records[provider]?.lastFailureAt,
    );
  }

  void recordFailure(AiProviderType provider, AIError error) {
    final prev = _records[provider] ?? const ProviderHealthRecord();
    final failures = prev.consecutiveFailures + 1;
    final now = DateTime.now();

    Duration? cooldown;
    if (error.kind == AIErrorKind.invalidApiKey) {
      cooldown = const Duration(minutes: 5);
    } else if (error.kind == AIErrorKind.quotaExceeded ||
        error.kind == AIErrorKind.rateLimited) {
      cooldown = const Duration(seconds: 60);
    } else if (failures >= 2 && error.isRetryable) {
      cooldown = Duration(seconds: (failures * 20).clamp(20, 120));
    }

    _records[provider] = ProviderHealthRecord(
      circuitState: cooldown != null
          ? ProviderCircuitState.cooldown
          : ProviderCircuitState.degraded,
      consecutiveFailures: failures,
      avgLatencyMs: prev.avgLatencyMs,
      lastSuccessAt: prev.lastSuccessAt,
      lastFailureAt: now,
      cooldownUntil: cooldown != null ? now.add(cooldown) : null,
      lastErrorKind: error.kind,
    );
  }

  void resetProvider(AiProviderType provider) {
    _records[provider] = const ProviderHealthRecord();
  }
}
