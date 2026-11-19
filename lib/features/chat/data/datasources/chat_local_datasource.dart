import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:vision_ai/core/constants/storage_keys.dart';
import 'package:vision_ai/core/errors/app_exception.dart';
import 'package:vision_ai/features/chat/domain/entities/chat_message.dart';
import 'package:vision_ai/features/chat/domain/entities/conversation_thread.dart';

/// Persists single-session messages and multi-conversation threads locally
/// via [SharedPreferences].
class ChatLocalDataSource {
  const ChatLocalDataSource(this._prefs);

  final SharedPreferences _prefs;

  /// Reads the stored legacy list of [ChatMessage] items.
  List<ChatMessage> readMessages() {
    final rawJson = _prefs.getString(StorageKeys.chatHistory);
    if (rawJson == null || rawJson.isEmpty) {
      return const <ChatMessage>[];
    }

    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! List<Object?>) {
        return const <ChatMessage>[];
      }
      final messages = <ChatMessage>[];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          messages.add(ChatMessage.fromJson(item));
        }
      }
      return List<ChatMessage>.unmodifiable(messages);
    } on FormatException {
      return const <ChatMessage>[];
    }
  }

  /// Writes the updated [messages] list to local storage.
  Future<void> writeMessages(List<ChatMessage> messages) async {
    final encoded = jsonEncode(
      messages.map((msg) => msg.toJson()).toList(growable: false),
    );
    final success = await _prefs.setString(StorageKeys.chatHistory, encoded);
    if (!success) {
      throw const StorageException(
        message: 'Failed to save conversation transcript locally.',
      );
    }
  }

  /// Clears all persisted conversation messages.
  Future<void> clearMessages() async {
    await _prefs.remove(StorageKeys.chatHistory);
  }

  /// Reads persisted [ConversationThread] items, automatically migrating any
  /// legacy [StorageKeys.chatHistory] transcript on first read.
  List<ConversationThread> readThreads() {
    final rawJson = _prefs.getString(StorageKeys.chatThreads);
    if (rawJson != null && rawJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawJson);
        if (decoded is List<Object?>) {
          final threads = <ConversationThread>[];
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              threads.add(ConversationThread.fromJson(item));
            }
          }
          return List<ConversationThread>.unmodifiable(threads);
        }
      } on FormatException {
        return const <ConversationThread>[];
      }
    }

    // One-time transparent migration from legacy flat message list.
    final legacyMessages = readMessages();
    if (legacyMessages.isNotEmpty) {
      final migrated = ConversationThread(
        id: 'thread_migrated_${legacyMessages.first.createdAt.microsecondsSinceEpoch}',
        title: ConversationThread.deriveTitle(legacyMessages),
        messages: legacyMessages,
        createdAt: legacyMessages.first.createdAt,
        updatedAt: legacyMessages.last.createdAt,
      );
      return <ConversationThread>[migrated];
    }

    return const <ConversationThread>[];
  }

  /// Persists the list of [ConversationThread] items locally.
  Future<void> writeThreads(List<ConversationThread> threads) async {
    final encoded = jsonEncode(
      threads.map((t) => t.toJson()).toList(growable: false),
    );
    final success = await _prefs.setString(StorageKeys.chatThreads, encoded);
    if (!success) {
      throw const StorageException(
        message: 'Failed to save conversation threads locally.',
      );
    }
  }

  String? readActiveThreadId() => _prefs.getString(StorageKeys.activeThreadId);

  Future<void> writeActiveThreadId(String? threadId) async {
    if (threadId == null || threadId.isEmpty) {
      await _prefs.remove(StorageKeys.activeThreadId);
    } else {
      await _prefs.setString(StorageKeys.activeThreadId, threadId);
    }
  }

  Future<void> clearAllThreads() async {
    await _prefs.remove(StorageKeys.chatThreads);
    await _prefs.remove(StorageKeys.activeThreadId);
    await _prefs.remove(StorageKeys.chatHistory);
  }
}
