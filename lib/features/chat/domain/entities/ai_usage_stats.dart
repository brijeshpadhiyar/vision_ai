import 'package:flutter/foundation.dart';

/// Persisted request & token usage metrics for a single `(providerId, modelId)` pair.
@immutable
class ModelUsageEntry {
  const ModelUsageEntry({
    required this.providerId,
    required this.modelId,
    required this.requestCount,
    required this.inputTokens,
    required this.outputTokens,
    required this.lastUsedAt,
  });

  factory ModelUsageEntry.fromJson(Map<String, dynamic> json) {
    return ModelUsageEntry(
      providerId: (json['providerId'] as String?) ?? '',
      modelId: (json['modelId'] as String?) ?? '',
      requestCount: (json['requestCount'] as num?)?.toInt() ?? 0,
      inputTokens: (json['inputTokens'] as num?)?.toInt() ?? 0,
      outputTokens: (json['outputTokens'] as num?)?.toInt() ?? 0,
      lastUsedAt:
          DateTime.tryParse((json['lastUsedAt'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  final String providerId;
  final String modelId;
  final int requestCount;
  final int inputTokens;
  final int outputTokens;
  final DateTime lastUsedAt;

  String get key => '$providerId::$modelId';
  int get totalTokens => inputTokens + outputTokens;

  ModelUsageEntry add({
    required int addedInputTokens,
    required int addedOutputTokens,
    required DateTime usedAt,
  }) {
    return ModelUsageEntry(
      providerId: providerId,
      modelId: modelId,
      requestCount: requestCount + 1,
      inputTokens: inputTokens + addedInputTokens,
      outputTokens: outputTokens + addedOutputTokens,
      lastUsedAt: usedAt,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'providerId': providerId,
    'modelId': modelId,
    'requestCount': requestCount,
    'inputTokens': inputTokens,
    'outputTokens': outputTokens,
    'lastUsedAt': lastUsedAt.toIso8601String(),
  };
}

/// Aggregated local AI usage state across providers and models.
@immutable
class UsageStatsState {
  const UsageStatsState({
    this.entries = const <String, ModelUsageEntry>{},
  });

  final Map<String, ModelUsageEntry> entries;

  int get totalRequests =>
      entries.values.fold(0, (sum, entry) => sum + entry.requestCount);

  int get totalInputTokens =>
      entries.values.fold(0, (sum, entry) => sum + entry.inputTokens);

  int get totalOutputTokens =>
      entries.values.fold(0, (sum, entry) => sum + entry.outputTokens);

  int get totalTokens => totalInputTokens + totalOutputTokens;

  List<ModelUsageEntry> entriesForProvider(String providerId) {
    final matching = entries.values
        .where((entry) => entry.providerId == providerId)
        .toList(growable: false)
      ..sort((a, b) => b.lastUsedAt.compareTo(a.lastUsedAt));
    return matching;
  }

  int requestsForProvider(String providerId) => entries.values
      .where((entry) => entry.providerId == providerId)
      .fold(0, (sum, entry) => sum + entry.requestCount);

  int tokensForProvider(String providerId) => entries.values
      .where((entry) => entry.providerId == providerId)
      .fold(0, (sum, entry) => sum + entry.totalTokens);

  Map<String, Object?> toSanitizedReport() => <String, Object?>{
    'totalRequests': totalRequests,
    'totalInputTokens': totalInputTokens,
    'totalOutputTokens': totalOutputTokens,
    'byModel': <String, Object?>{
      for (final entry in entries.values) entry.key: entry.toJson(),
    },
  };
}
