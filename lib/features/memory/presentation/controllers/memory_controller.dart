import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vision_ai/core/constants/storage_keys.dart';
import 'package:vision_ai/core/utils/secret_redactor.dart';
import 'package:vision_ai/core/utils/shared_preferences_provider.dart';
import 'package:vision_ai/features/memory/domain/entities/memory_entry.dart';

@immutable
class MemoryState {
  const MemoryState({
    this.memoryEnabled = false,
    this.entries = const <MemoryEntry>[],
  });

  final bool memoryEnabled;
  final List<MemoryEntry> entries;

  MemoryState copyWith({bool? memoryEnabled, List<MemoryEntry>? entries}) {
    return MemoryState(
      memoryEnabled: memoryEnabled ?? this.memoryEnabled,
      entries: entries ?? this.entries,
    );
  }

  /// Formats active personalization memories into a compact AI context block.
  /// Returns an empty string when memory is disabled or empty.
  String buildPromptContext({int maxEntries = 8}) {
    if (!memoryEnabled) return '';
    final active = entries
        .where((entry) => entry.enabled && entry.content.trim().isNotEmpty)
        .take(maxEntries)
        .toList(growable: false);
    if (active.isEmpty) return '';

    final buffer = StringBuffer(
      'USER PERSONALIZATION PREFERENCES (apply naturally when relevant):\n',
    );
    for (final entry in active) {
      buffer.writeln(
        '- [${entry.category.displayName}] ${entry.title}: ${entry.content}',
      );
    }
    return buffer.toString().trim();
  }
}

/// Manages explicit user-consented local personalization memory entries.
final memoryControllerProvider =
    NotifierProvider<MemoryController, MemoryState>(MemoryController.new);

class MemoryController extends Notifier<MemoryState> {
  static final RegExp _sensitiveKeywordPattern = RegExp(
    r'\b(password|passcode|pin\s+code|secret\s+key|api\s*key|bearer\s+token)\b',
    caseSensitive: false,
  );

  @override
  MemoryState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final enabled = prefs.getBool(StorageKeys.personalMemoryEnabled) ?? false;
    final rawList = prefs.getString(StorageKeys.personalMemoryEntries);
    final entries = _decodeEntries(rawList);
    return MemoryState(memoryEnabled: enabled, entries: entries);
  }

  Future<void> setMemoryEnabled(bool enabled) async {
    state = state.copyWith(memoryEnabled: enabled);
    await ref
        .read(sharedPreferencesProvider)
        .setBool(StorageKeys.personalMemoryEnabled, enabled);
  }

  /// Adds a new entry after redacting secret patterns. Rejects obvious password payloads.
  Future<bool> addEntry({
    required MemoryCategory category,
    required String title,
    required String content,
  }) async {
    final cleanTitle = SecretRedactor.redact(title.trim());
    final cleanContent = SecretRedactor.redact(content.trim());
    if (cleanTitle.isEmpty || cleanContent.isEmpty) {
      return false;
    }
    if (_sensitiveKeywordPattern.hasMatch('$cleanTitle $cleanContent')) {
      return false;
    }

    final entry = MemoryEntry(
      id: 'mem_${DateTime.now().microsecondsSinceEpoch}',
      category: category,
      title: cleanTitle,
      content: cleanContent,
      updatedAt: DateTime.now(),
    );
    final updated = <MemoryEntry>[entry, ...state.entries];
    state = state.copyWith(entries: updated);
    await _persist(updated);
    return true;
  }

  Future<bool> updateEntry(
    String id, {
    required String title,
    required String content,
    MemoryCategory? category,
    bool? enabled,
  }) async {
    final cleanTitle = SecretRedactor.redact(title.trim());
    final cleanContent = SecretRedactor.redact(content.trim());
    if (cleanTitle.isEmpty ||
        cleanContent.isEmpty ||
        _sensitiveKeywordPattern.hasMatch('$cleanTitle $cleanContent')) {
      return false;
    }

    final updated = state.entries
        .map(
          (entry) => entry.id == id
              ? entry.copyWith(
                  title: cleanTitle,
                  content: cleanContent,
                  category: category,
                  enabled: enabled,
                  updatedAt: DateTime.now(),
                )
              : entry,
        )
        .toList(growable: false);
    state = state.copyWith(entries: updated);
    await _persist(updated);
    return true;
  }

  Future<void> toggleEntry(String id, bool enabled) async {
    final updated = state.entries
        .map(
          (entry) => entry.id == id
              ? entry.copyWith(enabled: enabled, updatedAt: DateTime.now())
              : entry,
        )
        .toList(growable: false);
    state = state.copyWith(entries: updated);
    await _persist(updated);
  }

  Future<void> deleteEntry(String id) async {
    final updated = state.entries
        .where((entry) => entry.id != id)
        .toList(growable: false);
    state = state.copyWith(entries: updated);
    await _persist(updated);
  }

  Future<void> clearAllEntries() async {
    state = state.copyWith(entries: const <MemoryEntry>[]);
    await ref
        .read(sharedPreferencesProvider)
        .remove(StorageKeys.personalMemoryEntries);
  }

  Future<void> _persist(List<MemoryEntry> entries) async {
    final payload = jsonEncode(entries.map((e) => e.toJson()).toList());
    await ref
        .read(sharedPreferencesProvider)
        .setString(StorageKeys.personalMemoryEntries, payload);
  }

  List<MemoryEntry> _decodeEntries(String? raw) {
    if (raw == null || raw.isEmpty) return const <MemoryEntry>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <MemoryEntry>[];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(MemoryEntry.fromJson)
          .toList(growable: false);
    } on FormatException {
      return const <MemoryEntry>[];
    }
  }
}
