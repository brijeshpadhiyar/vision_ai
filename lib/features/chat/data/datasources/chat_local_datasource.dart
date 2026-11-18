import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:vision_ai/core/constants/storage_keys.dart';
import 'package:vision_ai/core/errors/app_exception.dart';
import 'package:vision_ai/features/chat/domain/entities/chat_message.dart';

/// Persists conversation history locally via [SharedPreferences].
class ChatLocalDataSource {
  const ChatLocalDataSource(this._prefs);

  final SharedPreferences _prefs;

  /// Reads the stored list of [ChatMessage] items.
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
}
