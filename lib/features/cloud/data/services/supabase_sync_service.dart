import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:vision_ai/core/config/cloud_config.dart';
import 'package:vision_ai/features/chat/domain/entities/conversation_thread.dart';
import 'package:vision_ai/features/cloud/domain/services/zero_knowledge_key_vault.dart';

/// Provides [ZeroKnowledgeKeyVault] for client-side AES-256-GCM encryption.
final zeroKnowledgeKeyVaultProvider = Provider<ZeroKnowledgeKeyVault>((ref) {
  return ZeroKnowledgeKeyVault();
});

/// Provides [SupabaseSyncService] for authenticated thread & encrypted key sync.
final supabaseSyncServiceProvider = Provider<SupabaseSyncService>((ref) {
  return SupabaseSyncService();
});

/// Handles authenticated PostgreSQL sync against Supabase tables
/// `conversation_threads` and `user_api_keys` (protected by RLS).
class SupabaseSyncService {
  static const String threadsTable = 'conversation_threads';
  static const String apiKeysTable = 'user_api_keys';

  SupabaseClient? get _clientOrNull {
    if (!CloudConfig.isSupabaseConfigured) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Fetches all conversation threads owned by the authenticated user.
  Future<List<ConversationThread>> fetchRemoteThreads(String userId) async {
    final client = _clientOrNull;
    if (client == null) return const <ConversationThread>[];

    final rows = await client
        .from(threadsTable)
        .select()
        .eq('user_id', userId)
        .order('updated_at', ascending: false);

    final threads = <ConversationThread>[];
    for (final row in rows) {
      threads.add(ConversationThread.fromSupabaseRow(row));
    }
    return List<ConversationThread>.unmodifiable(threads);
  }

  /// Upserts non-empty local threads to Supabase PostgreSQL.
  Future<void> upsertThreads({
    required String userId,
    required List<ConversationThread> threads,
  }) async {
    final client = _clientOrNull;
    if (client == null) return;

    final nonEmpty = threads.where((t) => t.messages.isNotEmpty).toList();
    if (nonEmpty.isEmpty) return;

    final payload = nonEmpty
        .map((t) => t.toSupabaseRow(userId))
        .toList(growable: false);
    await client.from(threadsTable).upsert(payload, onConflict: 'id');
  }

  /// Deletes a single thread from Supabase.
  Future<void> deleteRemoteThread({
    required String userId,
    required String threadId,
  }) async {
    final client = _clientOrNull;
    if (client == null) return;
    await client
        .from(threadsTable)
        .delete()
        .eq('id', threadId)
        .eq('user_id', userId);
  }

  /// Uploads a zero-knowledge encrypted API key vault blob for [userId].
  Future<void> upsertEncryptedApiKeys({
    required String userId,
    required EncryptedVaultBlob blob,
  }) async {
    final client = _clientOrNull;
    if (client == null) {
      throw StateError('Supabase is not configured.');
    }
    await client
        .from(apiKeysTable)
        .upsert(blob.toSupabaseRow(userId), onConflict: 'user_id');
  }

  /// Downloads the encrypted API key vault blob for [userId], or `null` if none exists.
  Future<EncryptedVaultBlob?> fetchEncryptedApiKeys(String userId) async {
    final client = _clientOrNull;
    if (client == null) return null;

    final row = await client
        .from(apiKeysTable)
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) return null;
    return EncryptedVaultBlob.fromSupabaseRow(row);
  }
}
