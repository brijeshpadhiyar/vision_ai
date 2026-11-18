import 'package:vision_ai/features/automation/domain/entities/device_action.dart';
import 'package:vision_ai/features/chat/domain/entities/ai_models.dart';
import 'package:vision_ai/features/chat/domain/entities/chat_message.dart';
import 'package:vision_ai/features/settings/domain/entities/ai_provider_type.dart';
import 'package:vision_ai/features/settings/domain/entities/app_settings.dart';
import 'package:vision_ai/features/settings/domain/entities/voice_language.dart';

/// Event emitted during a streamed or completed chat exchange.
sealed class ChatStreamUpdate {
  const ChatStreamUpdate();
}

final class ChatMessagesUpdated extends ChatStreamUpdate {
  const ChatMessagesUpdated(this.messages, {this.routingNotice});

  final List<ChatMessage> messages;
  final String? routingNotice;
}

/// Domain contract for conversation transcript persistence and multi-provider AI orchestration.
abstract interface class ChatRepository {
  /// Returns the current session's persisted messages.
  List<ChatMessage> getMessages();

  /// Appends a user message, dispatches the conversation to [provider], and stores the reply.
  Future<List<ChatMessage>> sendUserMessage({
    required String prompt,
    required AiProviderType provider,
    required VoiceLanguage language,
    bool enableDeviceActions = true,
    AppSettings? settings,
    AICancellationToken? cancellationToken,
  });

  /// Streams incremental conversation updates when SSE streaming is enabled.
  Stream<ChatStreamUpdate> streamUserMessage({
    required String prompt,
    required AppSettings settings,
    AICancellationToken? cancellationToken,
  });

  /// Records a local device-automation command and result into conversation history.
  Future<List<ChatMessage>> recordLocalActionExchange({
    required String userPrompt,
    required String assistantReply,
    required AiProviderType provider,
    String? modelId,
  });

  /// Consumes and clears any [DeviceActionRequest] extracted from the latest AI reply.
  DeviceActionRequest? consumePendingAiAction();

  /// Clears the persisted conversation history.
  Future<void> clearHistory();
}
