import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:vision_ai/features/chat/domain/entities/chat_message.dart';

/// Immutable multi-turn conversation thread with local/cloud serialization
/// and Markdown export.
@immutable
class ConversationThread {
  const ConversationThread({
    required this.id,
    required this.title,
    required this.messages,
    required this.createdAt,
    required this.updatedAt,
    this.isPinned = false,
  });

  final String id;
  final String title;
  final List<ChatMessage> messages;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPinned;

  static const String defaultTitle = 'New Conversation';

  /// Creates an empty thread with a unique timestamp-based ID.
  factory ConversationThread.create({
    String? id,
    String title = defaultTitle,
    List<ChatMessage> messages = const <ChatMessage>[],
    DateTime? now,
    bool isPinned = false,
  }) {
    final ts = now ?? DateTime.now();
    final generatedId = id ?? 'thread_${ts.microsecondsSinceEpoch}';
    return ConversationThread(
      id: generatedId,
      title: title,
      messages: List<ChatMessage>.unmodifiable(messages),
      createdAt: ts,
      updatedAt: ts,
      isPinned: isPinned,
    );
  }

  /// Derives a concise, readable title from the first non-empty user message.
  static String deriveTitle(List<ChatMessage> messages) {
    for (final msg in messages) {
      if (msg.sender == MessageSender.user && msg.content.trim().isNotEmpty) {
        final normalized = msg.content.replaceAll(RegExp(r'\s+'), ' ').trim();
        if (normalized.length <= 42) return normalized;
        return '${normalized.substring(0, 39).trimRight()}...';
      }
    }
    return defaultTitle;
  }

  /// Preview snippet of the latest message in the thread.
  String get previewText {
    if (messages.isEmpty) return 'No messages yet';
    final latest = messages.last.content.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (latest.isEmpty) return 'No messages yet';
    if (latest.length <= 84) return latest;
    return '${latest.substring(0, 81).trimRight()}...';
  }

  /// Returns `true` if [query] matches the thread title or any message content.
  bool matchesQuery(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    if (title.toLowerCase().contains(normalized)) return true;
    return messages.any(
      (msg) => msg.content.toLowerCase().contains(normalized),
    );
  }

  /// Exports the conversation thread as clean GitHub-flavored Markdown.
  String toMarkdown() {
    final buffer = StringBuffer()
      ..writeln('# $title')
      ..writeln()
      ..writeln(
        '_Updated: ${updatedAt.toLocal().toIso8601String().split('.').first.replaceFirst('T', ' ')}_',
      )
      ..writeln();

    for (final msg in messages) {
      final speaker = msg.sender == MessageSender.user
          ? '**You**'
          : '**VISION** (${msg.provider?.displayName ?? 'AI'})';
      buffer
        ..writeln('### $speaker')
        ..writeln()
        ..writeln(msg.content.trim())
        ..writeln();
    }
    return buffer.toString().trimRight();
  }

  ConversationThread copyWith({
    String? title,
    List<ChatMessage>? messages,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPinned,
  }) {
    return ConversationThread(
      id: id,
      title: title ?? this.title,
      messages: messages != null
          ? List<ChatMessage>.unmodifiable(messages)
          : this.messages,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPinned: isPinned ?? this.isPinned,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'messages': messages.map((m) => m.toJson()).toList(growable: false),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isPinned': isPinned,
    };
  }

  factory ConversationThread.fromJson(Map<String, dynamic> json) {
    final rawMessages = json['messages'];
    final parsedMessages = <ChatMessage>[];
    if (rawMessages is List<Object?>) {
      for (final item in rawMessages) {
        if (item is Map<String, dynamic>) {
          parsedMessages.add(ChatMessage.fromJson(item));
        }
      }
    }

    final createdAt =
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now();
    final updatedAt =
        DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? createdAt;

    return ConversationThread(
      id: json['id'] as String? ?? 'thread_${createdAt.microsecondsSinceEpoch}',
      title: (json['title'] as String?)?.trim().isNotEmpty == true
          ? (json['title'] as String).trim()
          : deriveTitle(parsedMessages),
      messages: List<ChatMessage>.unmodifiable(parsedMessages),
      createdAt: createdAt,
      updatedAt: updatedAt,
      isPinned: json['isPinned'] as bool? ?? false,
    );
  }

  /// Converts to a Supabase `conversation_threads` row map.
  Map<String, dynamic> toSupabaseRow(String userId) {
    return <String, dynamic>{
      'id': id,
      'user_id': userId,
      'title': title,
      'is_pinned': isPinned,
      'messages_json': jsonEncode(
        messages.map((m) => m.toJson()).toList(growable: false),
      ),
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  /// Parses a Supabase `conversation_threads` row map.
  factory ConversationThread.fromSupabaseRow(Map<String, dynamic> row) {
    final rawMessagesJson = row['messages_json'];
    final parsedMessages = <ChatMessage>[];

    dynamic decoded = rawMessagesJson;
    if (rawMessagesJson is String && rawMessagesJson.isNotEmpty) {
      try {
        decoded = jsonDecode(rawMessagesJson);
      } on FormatException {
        decoded = const <Object?>[];
      }
    }
    if (decoded is List<Object?>) {
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          parsedMessages.add(ChatMessage.fromJson(item));
        }
      }
    }

    final createdAt =
        DateTime.tryParse(row['created_at'] as String? ?? '') ?? DateTime.now();
    final updatedAt =
        DateTime.tryParse(row['updated_at'] as String? ?? '') ?? createdAt;

    return ConversationThread(
      id: row['id'] as String? ?? 'thread_${createdAt.microsecondsSinceEpoch}',
      title: (row['title'] as String?)?.trim().isNotEmpty == true
          ? (row['title'] as String).trim()
          : deriveTitle(parsedMessages),
      messages: List<ChatMessage>.unmodifiable(parsedMessages),
      createdAt: createdAt,
      updatedAt: updatedAt,
      isPinned: row['is_pinned'] as bool? ?? false,
    );
  }
}
