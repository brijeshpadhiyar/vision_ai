import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/features/chat/domain/entities/image_attachment.dart';
import 'package:vision_ai/features/research/domain/entities/research_source.dart';
import 'package:vision_ai/features/settings/domain/entities/ai_provider_type.dart';

/// Identifies the author of a [ChatMessage] in a conversation thread.
enum MessageSender {
  user,
  assistant,
  system;

  static MessageSender fromName(String? raw) {
    for (final value in MessageSender.values) {
      if (value.name == raw) return value;
    }
    return MessageSender.user;
  }
}

/// Immutable domain entity representing a single conversation message.
@immutable
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.sender,
    required this.content,
    required this.createdAt,
    this.provider,
    this.modelId,
    this.inputTokens,
    this.outputTokens,
    this.routingNotice,
    this.isError = false,
    this.imageAttachment,
    this.citations = const <ResearchSource>[],
  });

  /// Deserializes a [ChatMessage] from a persisted JSON map using Dart 3 pattern matching.
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return switch (json) {
      {
        'id': final String id,
        'sender': final String senderRaw,
        'content': final String content,
        'createdAt': final String createdAtRaw,
      } =>
        ChatMessage(
          id: id,
          sender: MessageSender.fromName(senderRaw),
          content: content,
          createdAt:
              DateTime.tryParse(createdAtRaw) ??
              DateTime.fromMillisecondsSinceEpoch(0),
          provider: json['provider'] is String
              ? AiProviderType.fromId(json['provider'] as String)
              : null,
          modelId: json['modelId'] is String ? json['modelId'] as String : null,
          inputTokens: (json['inputTokens'] as num?)?.toInt(),
          outputTokens: (json['outputTokens'] as num?)?.toInt(),
          routingNotice: json['routingNotice'] is String
              ? json['routingNotice'] as String
              : null,
          isError: json['isError'] is bool && (json['isError'] as bool),
          citations: (json['citations'] is List<Object?>)
              ? (json['citations'] as List<Object?>)
                    .whereType<Map<String, dynamic>>()
                    .map(ResearchSource.fromJson)
                    .toList(growable: false)
              : const <ResearchSource>[],
        ),
      _ => throw const FormatException('Malformed ChatMessage JSON payload.'),
    };
  }

  final String id;
  final MessageSender sender;
  final String content;
  final DateTime createdAt;
  final AiProviderType? provider;
  final String? modelId;
  final int? inputTokens;
  final int? outputTokens;
  final String? routingNotice;
  final bool isError;
  final ImageAttachment? imageAttachment;
  final List<ResearchSource> citations;

  ChatMessage copyWith({
    String? id,
    MessageSender? sender,
    String? content,
    DateTime? createdAt,
    AiProviderType? provider,
    String? modelId,
    int? inputTokens,
    int? outputTokens,
    String? routingNotice,
    bool? isError,
    ImageAttachment? imageAttachment,
    List<ResearchSource>? citations,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      sender: sender ?? this.sender,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      provider: provider ?? this.provider,
      modelId: modelId ?? this.modelId,
      inputTokens: inputTokens ?? this.inputTokens,
      outputTokens: outputTokens ?? this.outputTokens,
      routingNotice: routingNotice ?? this.routingNotice,
      isError: isError ?? this.isError,
      imageAttachment: imageAttachment ?? this.imageAttachment,
      citations: citations ?? this.citations,
    );
  }

  /// Serializes this [ChatMessage] to a JSON map for local persistence.
  ///
  /// Raw [imageAttachment] bytes are intentionally excluded to protect user
  /// photo privacy and avoid bloating SharedPreferences.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'sender': sender.name,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      if (provider != null) 'provider': provider!.id,
      if (modelId != null) 'modelId': modelId,
      if (inputTokens != null) 'inputTokens': inputTokens,
      if (outputTokens != null) 'outputTokens': outputTokens,
      if (routingNotice != null) 'routingNotice': routingNotice,
      'isError': isError,
      if (citations.isNotEmpty)
        'citations': citations.map((c) => c.toJson()).toList(growable: false),
    };
  }
}
