import 'package:flutter/foundation.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart' as toolkit;

import 'package:vision_ai/features/chat/domain/entities/ai_completion_request.dart';
import 'package:vision_ai/features/chat/domain/entities/ai_models.dart';
import 'package:vision_ai/features/chat/domain/entities/chat_message.dart'
    as vision;
import 'package:vision_ai/features/chat/domain/entities/image_attachment.dart';
import 'package:vision_ai/features/chat/domain/services/ai_router.dart';
import 'package:vision_ai/features/settings/domain/entities/app_settings.dart';

/// Bridges VISION AI's multi-provider [AIRouter] (Gemini, OpenAI, Claude, and
/// On-Device Edge AI) into `flutter_ai_toolkit`'s [toolkit.LlmProvider] contract
/// so users can toggle into `LlmChatView` inside ChatScreen.
class VisionLlmProvider extends ChangeNotifier implements toolkit.LlmProvider {
  VisionLlmProvider({
    required this.router,
    required this.settingsReader,
    Iterable<toolkit.ChatMessage>? initialHistory,
  }) : _history = initialHistory?.toList() ?? <toolkit.ChatMessage>[];

  final AIRouter router;
  final AppSettings Function() settingsReader;
  List<toolkit.ChatMessage> _history;

  @override
  Iterable<toolkit.ChatMessage> get history => _history;

  @override
  set history(Iterable<toolkit.ChatMessage> history) {
    _history = history.toList();
    notifyListeners();
  }

  @override
  Stream<String> generateStream(
    String prompt, {
    Iterable<toolkit.Attachment> attachments = const <toolkit.Attachment>[],
  }) async* {
    final settings = settingsReader();
    final image = _extractFirstImage(attachments);
    final userMsg = vision.ChatMessage(
      id: 'tk_usr_${DateTime.now().microsecondsSinceEpoch}',
      sender: vision.MessageSender.user,
      content: prompt,
      createdAt: DateTime.now(),
      provider: settings.selectedAiProvider,
      modelId: settings.selectedModelId,
      imageAttachment: image,
    );

    final req = AiCompletionRequest(
      provider: settings.selectedAiProvider,
      modelId: settings.selectedModelId,
      messages: <vision.ChatMessage>[userMsg],
      responseLanguage: settings.selectedVoiceLanguage,
      assistantIdentity: settings.assistantIdentity,
    );

    await for (final chunk in router.routeAndStream(
      completionRequest: req,
      settings: settings,
      promptText: prompt,
    )) {
      if (chunk is AITextDeltaChunk) {
        yield chunk.delta;
      }
    }
  }

  @override
  Stream<String> sendMessageStream(
    String prompt, {
    Iterable<toolkit.Attachment> attachments = const <toolkit.Attachment>[],
  }) async* {
    final userMessage = toolkit.ChatMessage.user(prompt, attachments);
    final llmMessage = toolkit.ChatMessage.llm();
    _history.addAll(<toolkit.ChatMessage>[userMessage, llmMessage]);
    notifyListeners();

    final buffer = StringBuffer();
    try {
      await for (final delta in generateStream(
        prompt,
        attachments: attachments,
      )) {
        buffer.write(delta);
        llmMessage.append(delta);
        yield delta;
      }
    } catch (error) {
      final errText = 'Unable to complete request: $error';
      if (buffer.isEmpty) {
        llmMessage.append(errText);
        yield errText;
      }
    } finally {
      notifyListeners();
    }
  }

  ImageAttachment? _extractFirstImage(
    Iterable<toolkit.Attachment> attachments,
  ) {
    for (final att in attachments) {
      if (att is toolkit.ImageFileAttachment) {
        return ImageAttachment.fromBytes(
          att.bytes,
          mimeType: att.mimeType,
          label: att.name,
        );
      }
    }
    return null;
  }
}
