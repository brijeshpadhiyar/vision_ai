import 'dart:convert';

import 'package:vision_ai/core/intelligence/confidence_manager.dart';
import 'package:vision_ai/core/intelligence/conversation_context.dart';
import 'package:vision_ai/core/intelligence/intent_engine.dart';
import 'package:vision_ai/features/automation/domain/entities/device_action.dart';

/// Result of extracting an optional `[[VISION_ACTION:...]]` directive from an AI reply.
class AiActionExtraction {
  const AiActionExtraction({required this.cleanText, this.action});

  final String cleanText;
  final DeviceActionRequest? action;
}

/// Facade connecting the modular multilingual [IntentEngine] with local device
/// command parsing and validated AI-suggested action extraction.
abstract final class DeviceIntentParser {
  static final RegExp _aiActionTagRegex = RegExp(
    r'\[\[VISION_ACTION:(\{.*?\})\]\]',
    dotAll: true,
  );

  /// Evaluates [input] (and optional [alternativeTranscripts]) with full intent
  /// classification, confidence scoring, clarification detection, and sequential planning.
  static IntentResolution analyzeIntent(
    String input, {
    List<String> alternativeTranscripts = const <String>[],
    ConversationIntelligenceContext context =
        const ConversationIntelligenceContext(),
  }) {
    if (alternativeTranscripts.isEmpty) {
      return IntentEngine.analyze(input, context: context);
    }
    return IntentEngine.analyzeWithHypotheses(<String>[
      input,
      ...alternativeTranscripts,
    ], context: context);
  }

  /// Attempts to parse a direct local device command without calling a remote LLM.
  ///
  /// Returns `null` when [input] is conversational or requires clarification.
  static DeviceActionRequest? parseLocalCommand(
    String input, {
    ConversationIntelligenceContext context =
        const ConversationIntelligenceContext(),
  }) {
    final resolution = IntentEngine.analyze(input, context: context);
    if (!resolution.shouldHandleLocally) return null;
    return resolution.request;
  }

  /// Strips `[[VISION_ACTION:{...}]]` from [aiReply] and parses the validated action.
  static AiActionExtraction extractAiAction(String aiReply) {
    final match = _aiActionTagRegex.firstMatch(aiReply);
    if (match == null) {
      return AiActionExtraction(cleanText: aiReply.trim());
    }

    final cleanText = aiReply.replaceAll(_aiActionTagRegex, '').trim();
    final jsonRaw = match.group(1);
    if (jsonRaw == null || jsonRaw.isEmpty) {
      return AiActionExtraction(cleanText: cleanText);
    }

    try {
      final decoded = jsonDecode(jsonRaw);
      if (decoded is! Map<String, dynamic>) {
        return AiActionExtraction(cleanText: cleanText);
      }
      final action = _fromAiJson(decoded);
      if (action != null &&
          ConfidenceManager.validateRequiredParameters(action) != null) {
        return AiActionExtraction(cleanText: cleanText);
      }
      return AiActionExtraction(cleanText: cleanText, action: action);
    } on FormatException {
      return AiActionExtraction(cleanText: cleanText);
    }
  }

  static DeviceActionRequest? _fromAiJson(Map<String, dynamic> map) {
    final actionName = (map['action'] as String?)?.trim().toLowerCase();
    switch (actionName) {
      case 'call_phone':
        final target =
            ((map['target'] ?? map['number'] ?? map['contact']) as String?)
                ?.trim();
        if (target == null || target.isEmpty) return null;
        return DeviceActionRequest(
          type: DeviceActionType.callPhone,
          target: target,
          displaySummary: 'Call $target',
          requiresConfirmation: true,
        );
      case 'lookup_contacts':
        final query = (map['query'] as String?)?.trim() ?? '';
        if (query.isEmpty) return null;
        return DeviceActionRequest(
          type: DeviceActionType.lookupContacts,
          target: query,
          displaySummary: 'Search contacts for "$query"',
        );
      case 'set_alarm':
        final hour = (map['hour'] as num?)?.toInt();
        final minute = (map['minute'] as num?)?.toInt() ?? 0;
        if (hour == null ||
            hour < 0 ||
            hour > 23 ||
            minute < 0 ||
            minute > 59) {
          return null;
        }
        final label = (map['label'] as String?)?.trim();
        return DeviceActionRequest(
          type: DeviceActionType.setAlarm,
          hour: hour,
          minute: minute,
          label: label,
          displaySummary: 'Set alarm for ${_formatTime(hour, minute)}',
        );
      case 'set_timer':
        final seconds = (map['seconds'] as num?)?.toInt();
        if (seconds == null || seconds <= 0 || seconds > 86400) return null;
        final label = (map['label'] as String?)?.trim();
        return DeviceActionRequest(
          type: DeviceActionType.setTimer,
          durationSeconds: seconds,
          label: label,
          displaySummary: 'Start timer for ${_formatDuration(seconds)}',
        );
      case 'dismiss_alarm':
        return const DeviceActionRequest(
          type: DeviceActionType.dismissAlarm,
          displaySummary: 'Dismiss or manage alarm',
        );
      case 'dismiss_timer':
        return const DeviceActionRequest(
          type: DeviceActionType.dismissTimer,
          displaySummary: 'Dismiss or manage timer',
        );
      case 'launch_app':
        final app = ((map['app'] ?? map['target']) as String?)?.trim();
        if (app == null || app.isEmpty) return null;
        return DeviceActionRequest(
          type: DeviceActionType.launchApp,
          target: app,
          displaySummary: 'Open $app',
        );
      case 'open_settings':
        final section = (map['section'] as String?)?.trim() ?? 'main';
        return DeviceActionRequest(
          type: DeviceActionType.openSettings,
          target: section,
          displaySummary: 'Open ${section.toUpperCase()} settings',
        );
      case 'send_sms':
        final target = ((map['target'] ?? map['number']) as String?)?.trim();
        if (target == null || target.isEmpty) return null;
        final message = (map['message'] as String?)?.trim();
        return DeviceActionRequest(
          type: DeviceActionType.sendSms,
          target: target,
          message: message,
          displaySummary: 'Compose SMS to $target',
        );
      case 'send_whatsapp':
        final target =
            ((map['target'] ?? map['number'] ?? map['contact']) as String?)
                ?.trim() ??
            '';
        final message = (map['message'] as String?)?.trim();
        if (target.isEmpty && (message == null || message.isEmpty)) return null;
        return DeviceActionRequest(
          type: DeviceActionType.sendWhatsapp,
          target: target,
          message: message,
          displaySummary: target.isNotEmpty
              ? 'Compose WhatsApp to $target'
              : 'Share via WhatsApp',
        );
      case 'read_notifications':
        return const DeviceActionRequest(
          type: DeviceActionType.readNotifications,
          displaySummary: 'Read recent notifications',
        );
      case 'open_url':
        final url = (map['url'] as String?)?.trim();
        if (url == null || url.isEmpty) return null;
        return DeviceActionRequest(
          type: DeviceActionType.openUrl,
          target: url,
          displaySummary: 'Open $url',
        );
      case 'toggle_flashlight':
        final enabled = map['enabled'] as bool?;
        if (enabled == null) return null;
        return DeviceActionRequest(
          type: DeviceActionType.toggleFlashlight,
          enabled: enabled,
          displaySummary: enabled
              ? 'Turn on flashlight'
              : 'Turn off flashlight',
        );
      case 'set_ringer_mode':
        final mode = (map['mode'] as String?)?.trim().toLowerCase();
        if (mode == null ||
            (mode != 'normal' && mode != 'vibrate' && mode != 'silent')) {
          return null;
        }
        return DeviceActionRequest(
          type: DeviceActionType.setRingerMode,
          target: mode,
          displaySummary: 'Set ringer mode to $mode',
        );
      case 'adjust_volume':
        final direction = (map['direction'] as String?)?.trim().toLowerCase();
        if (direction == null ||
            (direction != 'up' &&
                direction != 'down' &&
                direction != 'mute' &&
                direction != 'unmute')) {
          return null;
        }
        return DeviceActionRequest(
          type: DeviceActionType.adjustVolume,
          target: direction,
          displaySummary: 'Adjust volume ($direction)',
        );
      case 'web_search':
        final query = (map['query'] as String?)?.trim();
        if (query == null || query.isEmpty) return null;
        return DeviceActionRequest(
          type: DeviceActionType.webSearch,
          target: query,
          displaySummary: 'Search web for "$query"',
        );
      case 'navigate_to':
        final destination = ((map['destination'] ?? map['target']) as String?)
            ?.trim();
        if (destination == null || destination.isEmpty) return null;
        return DeviceActionRequest(
          type: DeviceActionType.navigateTo,
          target: destination,
          displaySummary: 'Navigate to $destination',
        );
      case 'device_status':
        return const DeviceActionRequest(
          type: DeviceActionType.deviceStatus,
          displaySummary: 'Check device status',
        );
      default:
        return null;
    }
  }

  static String _formatTime(int hour, int minute) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final paddedMin = minute.toString().padLeft(2, '0');
    return '$displayHour:$paddedMin $period';
  }

  static String _formatDuration(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    final parts = <String>[];
    if (hours > 0) parts.add('${hours}h');
    if (minutes > 0) parts.add('${minutes}m');
    if (seconds > 0 || parts.isEmpty) parts.add('${seconds}s');
    return parts.join(' ');
  }
}
