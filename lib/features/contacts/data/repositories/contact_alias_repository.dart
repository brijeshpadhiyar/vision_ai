import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vision_ai/core/constants/storage_keys.dart';
import 'package:vision_ai/core/utils/shared_preferences_provider.dart';
import 'package:vision_ai/features/automation/domain/entities/device_action.dart';
import 'package:vision_ai/features/contacts/domain/services/contact_normalization_service.dart';

/// User-confirmed voice alias mapping a misrecognized spoken name
/// (e.g., `"shohil jht"`) to an Android Contacts Provider `contactId`.
@immutable
class ContactVoiceAlias {
  const ContactVoiceAlias({
    required this.aliasId,
    required this.spokenPhrase,
    required this.normalizedPhrase,
    required this.contactId,
    required this.contactDisplayName,
    required this.updatedAt,
  });

  factory ContactVoiceAlias.fromJson(Map<String, dynamic> json) {
    return ContactVoiceAlias(
      aliasId: json['aliasId'] as String? ?? '',
      spokenPhrase: json['spokenPhrase'] as String? ?? '',
      normalizedPhrase: json['normalizedPhrase'] as String? ?? '',
      contactId: json['contactId'] as String? ?? '',
      contactDisplayName: json['contactDisplayName'] as String? ?? '',
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  final String aliasId;
  final String spokenPhrase;
  final String normalizedPhrase;
  final String contactId;
  final String contactDisplayName;
  final DateTime updatedAt;

  ContactVoiceAlias copyWith({
    String? spokenPhrase,
    String? normalizedPhrase,
    String? contactId,
    String? contactDisplayName,
    DateTime? updatedAt,
  }) {
    return ContactVoiceAlias(
      aliasId: aliasId,
      spokenPhrase: spokenPhrase ?? this.spokenPhrase,
      normalizedPhrase: normalizedPhrase ?? this.normalizedPhrase,
      contactId: contactId ?? this.contactId,
      contactDisplayName: contactDisplayName ?? this.contactDisplayName,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'aliasId': aliasId,
    'spokenPhrase': spokenPhrase,
    'normalizedPhrase': normalizedPhrase,
    'contactId': contactId,
    'contactDisplayName': contactDisplayName,
    'updatedAt': updatedAt.toIso8601String(),
  };
}

final contactAliasRepositoryProvider = Provider<ContactAliasRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ContactAliasRepository(prefs);
});

/// Persistent, editable, deletable local repository of user-confirmed
/// spoken-name aliases keyed by Android `contactId`.
///
/// Never automatically stores unconfirmed fuzzy guesses.
class ContactAliasRepository {
  ContactAliasRepository(this._prefs);

  final SharedPreferences _prefs;

  List<ContactVoiceAlias> getAliases() {
    final raw = _prefs.getString(StorageKeys.contactVoiceAliases);
    if (raw == null || raw.isEmpty) return const <ContactVoiceAlias>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <ContactVoiceAlias>[];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(ContactVoiceAlias.fromJson)
          .where((a) => a.normalizedPhrase.isNotEmpty && a.contactId.isNotEmpty)
          .toList(growable: false);
    } on FormatException {
      return const <ContactVoiceAlias>[];
    }
  }

  /// Resolves live [ContactMatch] records linked to a user-confirmed alias for [spokenQuery].
  ///
  /// Uses Android `contactId` so display name edits or phone number updates stay
  /// synced cleanly, falling back only when unique and matching original name.
  List<ContactMatch> resolveAliasForQuery(
    String spokenQuery,
    List<ContactMatch> liveContacts,
  ) {
    final normalized = ContactNormalizationService.normalize(
      spokenQuery,
      stripHonorifics: true,
    ).romanizedFull;
    if (normalized.isEmpty) return const <ContactMatch>[];

    final aliases = getAliases()
        .where((a) => a.normalizedPhrase == normalized)
        .toList(growable: false);
    if (aliases.isEmpty) return const <ContactMatch>[];

    final matched = <ContactMatch>[];
    for (final alias in aliases) {
      final byId = liveContacts
          .where(
            (c) => c.contactId.isNotEmpty && c.contactId == alias.contactId,
          )
          .toList(growable: false);
      if (byId.isNotEmpty) {
        matched.addAll(byId);
      }
    }
    return matched;
  }

  /// Saves a user-confirmed voice alias keyed by [contact.contactId].
  Future<bool> saveConfirmedAlias({
    required String spokenPhrase,
    required ContactMatch contact,
  }) async {
    final cleanSpoken = spokenPhrase.trim();
    final normalized = ContactNormalizationService.normalize(
      cleanSpoken,
      stripHonorifics: true,
    ).romanizedFull;
    final contactKey = contact.contactId.trim().isNotEmpty
        ? contact.contactId.trim()
        : contact.name.trim();
    if (normalized.isEmpty || contactKey.isEmpty) return false;

    final existing = getAliases().toList(growable: true);
    existing.removeWhere(
      (a) => a.normalizedPhrase == normalized && a.contactId == contactKey,
    );

    final entry = ContactVoiceAlias(
      aliasId: 'alias_${DateTime.now().microsecondsSinceEpoch}',
      spokenPhrase: cleanSpoken,
      normalizedPhrase: normalized,
      contactId: contactKey,
      contactDisplayName: contact.name,
      updatedAt: DateTime.now(),
    );
    existing.insert(0, entry);
    await _persist(existing);
    return true;
  }

  Future<void> updateAliasSpokenPhrase(String aliasId, String newPhrase) async {
    final normalized = ContactNormalizationService.normalize(
      newPhrase,
      stripHonorifics: true,
    ).romanizedFull;
    if (normalized.isEmpty) return;

    final updated = getAliases()
        .map(
          (a) => a.aliasId == aliasId
              ? a.copyWith(
                  spokenPhrase: newPhrase.trim(),
                  normalizedPhrase: normalized,
                  updatedAt: DateTime.now(),
                )
              : a,
        )
        .toList(growable: false);
    await _persist(updated);
  }

  Future<void> deleteAlias(String aliasId) async {
    final updated = getAliases()
        .where((a) => a.aliasId != aliasId)
        .toList(growable: false);
    await _persist(updated);
  }

  Future<void> clearAllAliases() async {
    await _prefs.remove(StorageKeys.contactVoiceAliases);
  }

  Future<void> _persist(List<ContactVoiceAlias> aliases) async {
    final json = jsonEncode(aliases.map((e) => e.toJson()).toList());
    await _prefs.setString(StorageKeys.contactVoiceAliases, json);
  }
}
