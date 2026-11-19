import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vision_ai/core/constants/storage_keys.dart';
import 'package:vision_ai/core/utils/shared_preferences_provider.dart';
import 'package:vision_ai/features/developer/domain/entities/developer_snippet.dart';

/// Local-first controller for the Developer Assistant Snippet Vault (Module 26).
class DeveloperSnippetsController extends Notifier<List<DeveloperSnippet>> {
  @override
  List<DeveloperSnippet> build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final raw = prefs.getString(StorageKeys.developerSnippets);
    if (raw == null || raw.isEmpty) return const <DeveloperSnippet>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <DeveloperSnippet>[];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(DeveloperSnippet.fromJson)
          .toList(growable: false);
    } on FormatException {
      return const <DeveloperSnippet>[];
    }
  }

  Future<void> addSnippet({
    required String title,
    required String language,
    required String code,
  }) async {
    if (title.trim().isEmpty || code.trim().isEmpty) return;
    final snippet = DeveloperSnippet(
      id: 'snip_${DateTime.now().microsecondsSinceEpoch}',
      title: title.trim(),
      language: language.trim().isEmpty ? 'text' : language.trim(),
      code: code,
      createdAtMillis: DateTime.now().millisecondsSinceEpoch,
    );
    final updated = <DeveloperSnippet>[snippet, ...state];
    await _persist(updated);
    state = updated;
  }

  Future<void> deleteSnippet(String id) async {
    final updated = state.where((s) => s.id != id).toList(growable: false);
    await _persist(updated);
    state = updated;
  }

  Future<void> _persist(List<DeveloperSnippet> list) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(
      StorageKeys.developerSnippets,
      jsonEncode(list.map((s) => s.toJson()).toList()),
    );
  }
}

final developerSnippetsControllerProvider =
    NotifierProvider<DeveloperSnippetsController, List<DeveloperSnippet>>(
      DeveloperSnippetsController.new,
    );
