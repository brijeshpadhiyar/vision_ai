import 'package:vision_ai/core/constants/app_constants.dart';
import 'package:vision_ai/features/chat/domain/entities/chat_message.dart';
import 'package:vision_ai/features/settings/domain/entities/ai_provider_type.dart';

/// Manages provider-agnostic conversation history so multi-turn context stays
/// accurate, noise-free, and within approximate token/turn budgets across
/// Gemini, OpenAI, and Claude switches.
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

  /// Builds a clean, token-bounded conversation context window preserving valid
  /// turns while filtering empty/error artifacts.
  List<ChatMessage> buildContextWindow({
    int maxMessages = AppConstants.maxContextMessages,
    int maxApproxChars = 16000,
  }) {
    final clean = _messages
        .where(
          (m) =>
              !m.isError &&
              m.sender != MessageSender.system &&
              m.content.trim().isNotEmpty,
        )
        .toList(growable: false);

    if (clean.isEmpty) return const <ChatMessage>[];

    final selectedReversed = <ChatMessage>[];
    var totalChars = 0;
    for (var i = clean.length - 1; i >= 0; i--) {
      if (selectedReversed.length >= maxMessages) break;
      final candidate = clean[i];
      final charLen = candidate.content.length;
      if (selectedReversed.isNotEmpty &&
          totalChars + charLen > maxApproxChars) {
        break;
      }
      selectedReversed.add(candidate);
      totalChars += charLen;
    }

    return selectedReversed.reversed.toList(growable: false);
  }

  /// Creates a structured user message tagged with provider/model metadata.
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
