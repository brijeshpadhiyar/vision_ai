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
    this.temperature = 0.6,
    this.maxOutputTokens = 1024,
    this.enableDeviceActions = true,
    this.personalMemoryContext = '',
    this.deviceContextSummary = '',
  });

  final AiProviderType provider;
  final String? modelId;
  final List<ChatMessage> messages;
  final VoiceLanguage responseLanguage;
  final double temperature;
  final int maxOutputTokens;
  final bool enableDeviceActions;
  final String personalMemoryContext;
  final String deviceContextSummary;

  String get resolvedModelId =>
      AIModelRegistry.normalizeModelId(provider, modelId);

  /// Structured tool definition exposed to function-calling AI providers.
  static const List<AIToolDefinition> deviceActionTools = <AIToolDefinition>[
    AIToolDefinition(
      name: 'execute_device_action',
      description:
          'Trigger an Android device action ONLY when the user explicitly asks '
          'to control their device (call, contacts, alarm, dismiss alarm, timer, '
          'dismiss timer, launch app, settings, SMS, WhatsApp compose, flashlight, '
          'ringer, volume, web search, maps navigation, or device status).',
      parametersSchema: <String, Object?>{
        'type': 'object',
        'properties': <String, Object?>{
          'action': <String, Object?>{
            'type': 'string',
            'description':
                'Action name: call_phone, lookup_contacts, set_alarm, '
                'dismiss_alarm, set_timer, dismiss_timer, launch_app, '
                'open_settings, send_sms, send_whatsapp, open_url, '
                'toggle_flashlight, set_ringer_mode, adjust_volume, '
                'web_search, navigate_to, device_status.',
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
            'description': 'Timer duration in seconds (1-86400).',
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

  /// Builds grounded system instructions enforcing accuracy, honesty about
  /// execution outcomes, clarity checks, and concise vs detailed depth.
  String get systemInstruction {
    final buffer = StringBuffer()
      ..writeln(
        'You are VISION, an accurate, fast, and reliable Android AI assistant.',
      )
      ..writeln(
        'CORE ACCURACY & COMMUNICATION RULES:\n'
        '1. Understand the actual user intent before answering; follow active conversation context.\n'
        '2. Keep simple factual answers concise and direct (1-3 sentences); provide well-structured, thorough explanations for complex, coding, or analytical questions.\n'
        '3. If a request is ambiguous or missing essential parameters (time, recipient, target app), ask one clear clarifying question instead of guessing.\n'
        '4. Admit uncertainty honestly when facts cannot be verified.\n'
        '5. NEVER claim a call, alarm, message, or Android action was completed unless the structured tool/action directive was genuinely requested and returned confirmation.\n'
        '6. Match the user\'s language and script naturally (English, Hindi, Gujarati, Hinglish, or Gujlish), defaulting to '
        '${responseLanguage.displayName} (${responseLanguage.nativeName}, '
        'locale ${responseLanguage.localeCode}) when unclear.',
      );

    if (deviceContextSummary.trim().isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('DEVICE & SESSION CONTEXT: ${deviceContextSummary.trim()}');
    }

    if (personalMemoryContext.trim().isNotEmpty) {
      buffer
        ..writeln()
        ..writeln(personalMemoryContext.trim());
    }

    if (enableDeviceActions) {
      buffer
        ..writeln()
        ..writeln(
          'ANDROID DEVICE AUTOMATION:\n'
          'When the user clearly wants an Android device action performed, call '
          '`execute_device_action` or append one directive at the end:\n'
          '[[VISION_ACTION:{"action":"<name>",...}]]\n'
          'Supported actions: call_phone, lookup_contacts, set_alarm, '
          'dismiss_alarm, set_timer, dismiss_timer, launch_app, open_settings, '
          'send_sms, send_whatsapp, open_url, toggle_flashlight, set_ringer_mode, '
          'adjust_volume, web_search, navigate_to, device_status.\n'
          'Do NOT emit [[VISION_ACTION:...]] for informational questions.',
        );
    }

    return buffer.toString().trim();
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
