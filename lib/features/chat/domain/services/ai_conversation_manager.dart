import 'package:vision_ai/core/constants/app_constants.dart';
import 'package:vision_ai/features/chat/domain/entities/chat_message.dart';
import 'package:vision_ai/features/settings/domain/entities/ai_provider_type.dart';

/// Manages provider-agnostic conversation history so multi-turn context is
/// preserved seamlessly when switching between Gemini, OpenAI, and Claude.
class AIConversationManager {
  AIConversationManager({List<ChatMessage>? initialMessages})
    : _messages = List<ChatMessage>.from(
        initialMessages ?? const <ChatMessage>[],
      );

  final List<ChatMessage> _messages;

  List<ChatMessage> get messages => List<ChatMessage>.unmodifiable(_messages);

  void addMessage(ChatMessage message) {
    _messages.add(message);
  }

  void upsertStreamingAssistantMessage(ChatMessage message) {
    final index = _messages.indexWhere((m) => m.id == message.id);
    if (index == -1) {
      _messages.add(message);
    } else {
      _messages[index] = message;
    }
  }

  void removeMessageById(String id) {
    _messages.removeWhere((m) => m.id == id);
  }

  void clear() {
    _messages.clear();
  }

  /// Returns the normalized recent context window preserving turn order across
  /// provider switches (excluding error banners).
  List<ChatMessage> buildContextWindow({
    int maxMessages = AppConstants.maxContextMessages,
  }) {
    final clean = _messages
        .where((m) => !m.isError && m.sender != MessageSender.system)
        .toList(growable: false);
    if (clean.length <= maxMessages) {
      return clean;
    }
    return clean.sublist(clean.length - maxMessages);
  }

  /// Records a provider switch marker when helpful for diagnostics without
  /// disrupting provider role alternation.
  ChatMessage createUserMessage(
    String content, {
    required AiProviderType provider,
    String? modelId,
  }) {
    final now = DateTime.now();
    return ChatMessage(
      id: 'usr_${now.microsecondsSinceEpoch}',
      sender: MessageSender.user,
      content: content,
      createdAt: now,
      provider: provider,
      modelId: modelId,
    );
  }
}
