import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/features/chat/domain/entities/ai_model_config.dart';
import 'package:vision_ai/features/chat/domain/entities/ai_models.dart';
import 'package:vision_ai/features/chat/domain/entities/chat_message.dart';
import 'package:vision_ai/features/settings/domain/entities/ai_provider_type.dart';
import 'package:vision_ai/features/settings/domain/entities/voice_language.dart';

/// Encapsulates a multi-turn completion request routed to an AI provider.
@immutable
class AiCompletionRequest {
  const AiCompletionRequest({
    required this.provider,
    required this.messages,
    required this.responseLanguage,
    this.modelId,
    this.temperature = 0.7,
    this.maxOutputTokens = 1024,
    this.enableDeviceActions = true,
  });

  final AiProviderType provider;
  final String? modelId;
  final List<ChatMessage> messages;
  final VoiceLanguage responseLanguage;
  final double temperature;
  final int maxOutputTokens;
  final bool enableDeviceActions;

  String get resolvedModelId =>
      AIModelRegistry.normalizeModelId(provider, modelId);

  /// Structured tool definition exposed to function-calling AI providers.
  static const List<AIToolDefinition> deviceActionTools = <AIToolDefinition>[
    AIToolDefinition(
      name: 'execute_device_action',
      description:
          'Trigger an Android device action when the user explicitly asks to '
          'control their phone (call, contacts, alarm, timer, launch app, '
          'settings, SMS, WhatsApp share/compose, flashlight, ringer, volume, '
          'web search, maps navigation, or device status).',
      parametersSchema: <String, Object?>{
        'type': 'object',
        'properties': <String, Object?>{
          'action': <String, Object?>{
            'type': 'string',
            'description':
                'Action name: call_phone, lookup_contacts, set_alarm, '
                'set_timer, launch_app, open_settings, send_sms, '
                'send_whatsapp, open_url, toggle_flashlight, set_ringer_mode, '
                'adjust_volume, web_search, navigate_to, device_status.',
          },
          'target': <String, Object?>{
            'type': 'string',
            'description':
                'Contact name, phone number, app name, URL, ringer mode, '
                'volume direction, or settings section.',
          },
          'query': <String, Object?>{
            'type': 'string',
            'description': 'Search query or contact lookup query.',
          },
          'hour': <String, Object?>{
            'type': 'integer',
            'description': 'Alarm hour (0-23).',
          },
          'minute': <String, Object?>{
            'type': 'integer',
            'description': 'Alarm minute (0-59).',
          },
          'seconds': <String, Object?>{
            'type': 'integer',
            'description': 'Timer duration in seconds.',
          },
          'label': <String, Object?>{
            'type': 'string',
            'description': 'Optional alarm or timer label.',
          },
          'message': <String, Object?>{
            'type': 'string',
            'description': 'Optional SMS or WhatsApp message body.',
          },
          'enabled': <String, Object?>{
            'type': 'boolean',
            'description': 'Boolean toggle for flashlight.',
          },
          'destination': <String, Object?>{
            'type': 'string',
            'description': 'Navigation destination for Maps.',
          },
        },
        'required': <String>['action'],
      },
    ),
  ];

  /// Builds the system instruction guiding VISION's persona, language preference,
  /// and optional Android device automation directive output.
  String get systemInstruction {
    final base =
        'You are VISION, a concise, helpful, and intelligent personal Android AI '
        'assistant created for the user. Respond clearly and accurately. '
        'When appropriate or requested, prefer responding in '
        '${responseLanguage.displayName} (${responseLanguage.nativeName}, '
        'locale ${responseLanguage.localeCode}), while adapting naturally to the '
        "language of the user's prompt.";

    if (!enableDeviceActions) {
      return base;
    }

    return '$base\n\n'
        'You can also trigger Android device actions when the user explicitly '
        'asks to control their phone. Prefer calling the `execute_device_action` '
        'tool when tool calling is available, or append exactly one JSON '
        'directive at the very end of your reply in this format:\n'
        '[[VISION_ACTION:{"action":"<name>",...}]]\n'
        'Supported actions:\n'
        '- call_phone: {"action":"call_phone","target":"<name or number>"}\n'
        '- lookup_contacts: {"action":"lookup_contacts","query":"<name>"}\n'
        '- set_alarm: {"action":"set_alarm","hour":0-23,"minute":0-59,"label":"<optional>"}\n'
        '- set_timer: {"action":"set_timer","seconds":<int>,"label":"<optional>"}\n'
        '- launch_app: {"action":"launch_app","app":"<app name>"}\n'
        '- open_settings: {"action":"open_settings","section":"wifi|bluetooth|sound|display|battery|location|apps|notifications|storage|security|privacy|accessibility|network|notification_listener|main"}\n'
        '- send_sms: {"action":"send_sms","target":"<name or number>","message":"<optional>"}\n'
        '- send_whatsapp: {"action":"send_whatsapp","target":"<optional name or number>","message":"<text>"}\n'
        '- open_url: {"action":"open_url","url":"https://..."}\n'
        '- toggle_flashlight: {"action":"toggle_flashlight","enabled":true|false}\n'
        '- set_ringer_mode: {"action":"set_ringer_mode","mode":"normal|vibrate|silent"}\n'
        '- adjust_volume: {"action":"adjust_volume","direction":"up|down|mute|unmute"}\n'
        '- web_search: {"action":"web_search","query":"<search terms>"}\n'
        '- navigate_to: {"action":"navigate_to","destination":"<place or address>"}\n'
        '- device_status: {"action":"device_status"}\n'
        'Do not emit [[VISION_ACTION:...]] for normal conversational questions.';
  }

  /// Converts this completion request into a provider-independent [AIRequest].
  AIRequest toAiRequest({String? requestId}) {
    return AIRequest(
      provider: provider,
      modelId: resolvedModelId,
      messages: messages,
      systemInstruction: systemInstruction,
      responseLanguage: responseLanguage,
      temperature: temperature,
      maxOutputTokens: maxOutputTokens,
      tools: enableDeviceActions
          ? deviceActionTools
          : const <AIToolDefinition>[],
      enableDeviceActions: enableDeviceActions,
      requestId: requestId,
    );
  }
}
