import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vision_ai/core/constants/storage_keys.dart';
import 'package:vision_ai/core/utils/shared_preferences_provider.dart';
import 'package:vision_ai/features/chat/domain/entities/ai_models.dart';
import 'package:vision_ai/features/chat/domain/entities/ai_usage_stats.dart';
import 'package:vision_ai/features/settings/domain/entities/ai_provider_type.dart';

/// Persisted local per-provider and per-model AI usage counter controller.
final usageStatsControllerProvider =
    NotifierProvider<UsageStatsController, UsageStatsState>(
      UsageStatsController.new,
    );

class UsageStatsController extends Notifier<UsageStatsState> {
  @override
  UsageStatsState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final raw = prefs.getString(StorageKeys.aiUsageStats);
    return UsageStatsState(entries: _decode(raw));
  }

  /// Records a completed AI request and its token usage locally.
  Future<void> recordUsage({
    required AiProviderType provider,
    required String modelId,
    AIUsage? usage,
  }) async {
    final normalizedModel = modelId.trim().isEmpty
        ? provider.defaultModel
        : modelId.trim();
    final key = '${provider.id}::$normalizedModel';
    final now = DateTime.now();
    final existing = state.entries[key];
    final inputTokens = usage?.inputTokens ?? 0;
    final outputTokens = usage?.outputTokens ?? 0;

    final updatedEntry = existing != null
        ? existing.add(
            addedInputTokens: inputTokens,
            addedOutputTokens: outputTokens,
            usedAt: now,
          )
        : ModelUsageEntry(
            providerId: provider.id,
            modelId: normalizedModel,
            requestCount: 1,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            lastUsedAt: now,
          );

    final nextMap = Map<String, ModelUsageEntry>.from(state.entries)
      ..[key] = updatedEntry;
    state = UsageStatsState(
      entries: Map<String, ModelUsageEntry>.unmodifiable(nextMap),
    );
    await _persist(nextMap);
  }

  /// Resets all local AI usage counters.
  Future<void> clearUsage() async {
    state = const UsageStatsState();
    await ref.read(sharedPreferencesProvider).remove(StorageKeys.aiUsageStats);
  }

  Future<void> _persist(Map<String, ModelUsageEntry> entries) async {
    final encoded = jsonEncode(
      entries.values.map((entry) => entry.toJson()).toList(growable: false),
    );
    await ref
        .read(sharedPreferencesProvider)
        .setString(StorageKeys.aiUsageStats, encoded);
  }

  static Map<String, ModelUsageEntry> _decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const <String, ModelUsageEntry>{};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List<Object?>) {
        return const <String, ModelUsageEntry>{};
      }
      final result = <String, ModelUsageEntry>{};
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          final entry = ModelUsageEntry.fromJson(item);
          if (entry.providerId.isNotEmpty && entry.modelId.isNotEmpty) {
            result[entry.key] = entry;
          }
        }
      }
      return Map<String, ModelUsageEntry>.unmodifiable(result);
    } on FormatException {
      return const <String, ModelUsageEntry>{};
    }
  }
}
