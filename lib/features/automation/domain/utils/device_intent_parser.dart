import 'dart:convert';

import 'package:vision_ai/features/automation/domain/entities/device_action.dart';

/// Result of extracting an optional `[[VISION_ACTION:...]]` directive from an AI reply.
class AiActionExtraction {
  const AiActionExtraction({required this.cleanText, this.action});

  final String cleanText;
  final DeviceActionRequest? action;
}

/// Parses direct natural-language device commands (English, Hindi, Gujarati)
/// and structured AI action directives.
abstract final class DeviceIntentParser {
  static final RegExp _aiActionTagRegex = RegExp(
    r'\[\[VISION_ACTION:(\{.*?\})\]\]',
    dotAll: true,
  );

  /// Attempts to parse a direct local device command without calling a remote LLM.
  ///
  /// Returns `null` when [input] is a general conversational question.
  static DeviceActionRequest? parseLocalCommand(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;
    final lower = trimmed.toLowerCase();

    // 1. Flashlight / Torch
    final torchMatch = _parseFlashlight(trimmed, lower);
    if (torchMatch != null) return torchMatch;

    // 2. Ringer mode & Volume control
    final ringerMatch = _parseRingerMode(trimmed, lower);
    if (ringerMatch != null) return ringerMatch;

    final volumeMatch = _parseVolume(trimmed, lower);
    if (volumeMatch != null) return volumeMatch;

    // 3. Device status / battery / network
    if (_isDeviceStatusQuery(trimmed, lower)) {
      return const DeviceActionRequest(
        type: DeviceActionType.deviceStatus,
        displaySummary: 'Check device battery, network & system status',
      );
    }

    // 4. Alarm
    final alarmMatch = _parseAlarm(trimmed, lower);
    if (alarmMatch != null) return alarmMatch;

    // 5. Timer
    final timerMatch = _parseTimer(trimmed, lower);
    if (timerMatch != null) return timerMatch;

    // 6. System settings
    final settingsMatch = _parseSettings(trimmed, lower);
    if (settingsMatch != null) return settingsMatch;

    // 6b. Notifications
    final notificationMatch = _parseNotifications(trimmed, lower);
    if (notificationMatch != null) return notificationMatch;

    // 6c. WhatsApp
    final whatsappMatch = _parseWhatsApp(trimmed);
    if (whatsappMatch != null) return whatsappMatch;

    // 7. SMS
    final smsMatch = _parseSms(trimmed);
    if (smsMatch != null) return smsMatch;

    // 8. Contact lookup
    final lookupMatch = _parseContactLookup(trimmed);
    if (lookupMatch != null) return lookupMatch;

    // 9. Phone call / Dial
    final callMatch = _parsePhoneCall(trimmed);
    if (callMatch != null) return callMatch;

    // 10. Maps / Navigation
    final navMatch = _parseNavigation(trimmed);
    if (navMatch != null) return navMatch;

    // 11. Web Search
    final searchMatch = _parseWebSearch(trimmed);
    if (searchMatch != null) return searchMatch;

    // 12. Open URL
    final urlMatch = _parseOpenUrl(trimmed);
    if (urlMatch != null) return urlMatch;

    // 13. Launch installed app
    final appMatch = _parseLaunchApp(trimmed);
    if (appMatch != null) return appMatch;

    return null;
  }

  /// Strips `[[VISION_ACTION:{...}]]` from [aiReply] and parses the structured action.
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
        if (seconds == null || seconds <= 0) return null;
        final label = (map['label'] as String?)?.trim();
        return DeviceActionRequest(
          type: DeviceActionType.setTimer,
          durationSeconds: seconds,
          label: label,
          displaySummary: 'Start timer for ${_formatDuration(seconds)}',
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

  static DeviceActionRequest? _parseFlashlight(String original, String lower) {
    final mentionsTorch =
        lower.contains('flashlight') ||
        lower.contains('torch') ||
        original.contains('टॉर्च') ||
        original.contains('फ्लैशलाइट') ||
        original.contains('ફ્લેશલાઇટ') ||
        original.contains('ટૉર્ચ') ||
        original.contains('ટોર્ચ');
    if (!mentionsTorch) return null;

    if (RegExp(r'\b(on|enable|start|turn on|switch on)\b').hasMatch(lower) ||
        original.contains('चालू') ||
        original.contains('ऑन') ||
        original.contains('जलाओ') ||
        original.contains('ચાલુ') ||
        original.contains('ઓન')) {
      return const DeviceActionRequest(
        type: DeviceActionType.toggleFlashlight,
        enabled: true,
        displaySummary: 'Turn on flashlight',
      );
    }
    if (RegExp(r'\b(off|disable|stop|turn off|switch off)\b').hasMatch(lower) ||
        original.contains('बंद') ||
        original.contains('ऑफ') ||
        original.contains('બંધ') ||
        original.contains('ઓફ')) {
      return const DeviceActionRequest(
        type: DeviceActionType.toggleFlashlight,
        enabled: false,
        displaySummary: 'Turn off flashlight',
      );
    }
    return null;
  }

  static DeviceActionRequest? _parseRingerMode(String original, String lower) {
    final mentionsRingerContext =
        lower.contains('mode') ||
        lower.contains('ringer') ||
        lower.contains('phone') ||
        original.contains('फोन') ||
        original.contains('मोड') ||
        original.contains('ફોન') ||
        original.contains('મોડ');

    if ((mentionsRingerContext && lower.contains('silent')) ||
        lower == 'silence phone' ||
        lower == 'mute phone' ||
        original.contains('साइलेंट') ||
        original.contains('સાયલન્ટ')) {
      return const DeviceActionRequest(
        type: DeviceActionType.setRingerMode,
        target: 'silent',
        displaySummary: 'Set ringer mode to silent',
      );
    }
    if ((mentionsRingerContext && lower.contains('vibrate')) ||
        original.contains('वाइब्रेट') ||
        original.contains('વાઇબ્રેટ')) {
      return const DeviceActionRequest(
        type: DeviceActionType.setRingerMode,
        target: 'vibrate',
        displaySummary: 'Set ringer mode to vibrate',
      );
    }
    if ((mentionsRingerContext &&
            (lower.contains('normal') || lower.contains('ring'))) ||
        lower == 'unmute phone' ||
        original.contains('नॉर्मल मोड') ||
        original.contains('નોર્મલ મોડ')) {
      return const DeviceActionRequest(
        type: DeviceActionType.setRingerMode,
        target: 'normal',
        displaySummary: 'Set ringer mode to normal',
      );
    }
    return null;
  }

  static DeviceActionRequest? _parseVolume(String original, String lower) {
    final mentionsVolume =
        lower.contains('volume') ||
        original.contains('आवाज़') ||
        original.contains('आवाज') ||
        original.contains('वॉल्यूम') ||
        original.contains('અવાજ') ||
        original.contains('વોલ્યુમ');
    if (!mentionsVolume) return null;

    if (RegExp(r'\b(up|increase|raise|higher|louder)\b').hasMatch(lower) ||
        original.contains('बढ़ा') ||
        original.contains('तेज़') ||
        original.contains('વધાર')) {
      return const DeviceActionRequest(
        type: DeviceActionType.adjustVolume,
        target: 'up',
        displaySummary: 'Increase media volume',
      );
    }
    if (RegExp(r'\b(down|decrease|lower|quieter|reduce)\b').hasMatch(lower) ||
        original.contains('कम') ||
        original.contains('धीमा') ||
        original.contains('ઓછ')) {
      return const DeviceActionRequest(
        type: DeviceActionType.adjustVolume,
        target: 'down',
        displaySummary: 'Decrease media volume',
      );
    }
    if (lower.contains('unmute') ||
        original.contains('अनम्यूट') ||
        original.contains('અનમ્યૂટ')) {
      return const DeviceActionRequest(
        type: DeviceActionType.adjustVolume,
        target: 'unmute',
        displaySummary: 'Unmute media volume',
      );
    }
    if (lower.contains('mute') ||
        original.contains('म्यूट') ||
        original.contains('મ્યૂટ')) {
      return const DeviceActionRequest(
        type: DeviceActionType.adjustVolume,
        target: 'mute',
        displaySummary: 'Mute media volume',
      );
    }
    return null;
  }

  static bool _isDeviceStatusQuery(String original, String lower) {
    if (RegExp(
      r'^(?:check |show |get |what is (?:my )?)?(?:device status|phone status|battery(?: level| status| percentage)?|system status)\??$',
    ).hasMatch(lower)) {
      return true;
    }
    return original.contains('बैटरी') ||
        original.contains('डिवाइस स्टेटस') ||
        original.contains('फोन स्टेटस') ||
        original.contains('બેટરી') ||
        original.contains('ડિવાઇસ સ્ટેટસ') ||
        original.contains('ફોન સ્ટેટસ');
  }

  static DeviceActionRequest? _parseAlarm(String original, String lower) {
    final isAlarm =
        lower.contains('alarm') ||
        lower.startsWith('wake me') ||
        original.contains('अलार्म') ||
        original.contains('એલાર્મ');
    if (!isAlarm) {
      return null;
    }

    // Relative alarm: e.g. "set an alarm in 30 minutes"
    final relMatch = RegExp(
      r'\bin\s+(\d+)\s*(hour|hours|hr|hrs|minute|minutes|min|mins)\b',
      caseSensitive: false,
    ).firstMatch(original);
    if (relMatch != null) {
      final qty = int.tryParse(relMatch.group(1) ?? '') ?? 0;
      final unit = (relMatch.group(2) ?? '').toLowerCase();
      if (qty > 0) {
        final delta = unit.startsWith('h')
            ? Duration(hours: qty)
            : Duration(minutes: qty);
        final targetTime = DateTime.now().add(delta);
        return DeviceActionRequest(
          type: DeviceActionType.setAlarm,
          hour: targetTime.hour,
          minute: targetTime.minute,
          displaySummary:
              'Set alarm for ${_formatTime(targetTime.hour, targetTime.minute)}',
        );
      }
    }

    final timeRegex = RegExp(
      r'\b(\d{1,2})(?::(\d{2}))?\s*(a\.?m\.?|p\.?m\.?)?\b',
      caseSensitive: false,
    );
    final match = timeRegex.firstMatch(original);
    if (match == null) return null;

    var hour = int.tryParse(match.group(1) ?? '');
    final minute = int.tryParse(match.group(2) ?? '0') ?? 0;
    final meridiem = match.group(3)?.toLowerCase().replaceAll('.', '');

    if (hour == null || minute < 0 || minute > 59) return null;
    if (meridiem == 'pm' && hour >= 1 && hour <= 11) {
      hour += 12;
    } else if (meridiem == 'am' && hour == 12) {
      hour = 0;
    } else if (meridiem == null &&
        hour >= 1 &&
        hour <= 11 &&
        (original.contains('शाम') ||
            original.contains('रात') ||
            original.contains('સાંજ') ||
            original.contains('રાત'))) {
      hour += 12;
    }
    if (hour < 0 || hour > 23) return null;

    String? label;
    final labelMatch = RegExp(
      r'(?:called|labeled|named|for)\s+([a-zA-Z0-9\s]+)$',
      caseSensitive: false,
    ).firstMatch(original);
    if (labelMatch != null) {
      final candidate = labelMatch.group(1)?.trim() ?? '';
      if (candidate.isNotEmpty &&
          !RegExp(r'^\d').hasMatch(candidate) &&
          !candidate.toLowerCase().contains('am') &&
          !candidate.toLowerCase().contains('pm')) {
        label = candidate;
      }
    }

    return DeviceActionRequest(
      type: DeviceActionType.setAlarm,
      hour: hour,
      minute: minute,
      label: label,
      displaySummary: 'Set alarm for ${_formatTime(hour, minute)}',
    );
  }

  static DeviceActionRequest? _parseTimer(String original, String lower) {
    final isTimer =
        lower.contains('timer') ||
        original.contains('टाइमर') ||
        original.contains('ટાઇમર') ||
        original.contains('ટાઈમર');
    if (!isTimer) return null;

    final durationRegex = RegExp(
      r'(\d+)\s*(hour|hours|hr|hrs|minute|minutes|min|mins|second|seconds|sec|secs|घंटा|घंटे|मिनट|सेकंड|કલાક|મિનિટ|સેકન્ડ)(?=\s|$|[.,!?])',
      caseSensitive: false,
    );
    final matches = durationRegex.allMatches(original);
    if (matches.isEmpty) return null;

    var totalSeconds = 0;
    for (final m in matches) {
      final value = int.tryParse(m.group(1) ?? '') ?? 0;
      final unit = (m.group(2) ?? '').toLowerCase();
      if (unit.startsWith('h') ||
          unit.contains('घंट') ||
          unit.contains('કલાક')) {
        totalSeconds += value * 3600;
      } else if (unit.startsWith('m') ||
          unit.contains('मिनट') ||
          unit.contains('મિનિટ')) {
        totalSeconds += value * 60;
      } else {
        totalSeconds += value;
      }
    }

    if (totalSeconds <= 0) return null;

    String? label;
    final labelMatch = RegExp(
      r'(?:called|labeled|named|for)\s+([a-zA-Z][a-zA-Z0-9\s]*)$',
      caseSensitive: false,
    ).firstMatch(original);
    if (labelMatch != null) {
      final candidate = labelMatch.group(1)?.trim() ?? '';
      if (candidate.isNotEmpty) {
        label = candidate;
      }
    }

    return DeviceActionRequest(
      type: DeviceActionType.setTimer,
      durationSeconds: totalSeconds,
      label: label,
      displaySummary: 'Start timer for ${_formatDuration(totalSeconds)}',
    );
  }

  static DeviceActionRequest? _parseSettings(String original, String lower) {
    const sections = <String, String>{
      'wifi': 'wifi',
      'wi-fi': 'wifi',
      'bluetooth': 'bluetooth',
      'sound': 'sound',
      'volume': 'sound',
      'display': 'display',
      'brightness': 'display',
      'battery': 'battery',
      'location': 'location',
      'gps': 'location',
      'apps': 'apps',
      'notifications': 'notifications',
      'notification': 'notifications',
      'storage': 'storage',
      'security': 'security',
      'privacy': 'privacy',
      'accessibility': 'accessibility',
      'network': 'network',
      'date': 'date',
    };

    final settingsTrigger = RegExp(
      r'^(?:open|show|go to|launch)\s+(.+?)\s+settings$',
    ).firstMatch(lower);
    if (settingsTrigger != null) {
      final rawSection = settingsTrigger.group(1)?.trim() ?? '';
      final mapped = sections[rawSection];
      if (mapped != null) {
        return DeviceActionRequest(
          type: DeviceActionType.openSettings,
          target: mapped,
          displaySummary: 'Open ${mapped.toUpperCase()} settings',
        );
      }
    }

    if (lower == 'open settings' ||
        lower == 'open system settings' ||
        original.contains('सेटिंग्स खोलो') ||
        original.contains('સેટિંગ્સ ખોલો')) {
      const indicSectionMap = <String, String>{
        'वाईफाई': 'wifi',
        'वाई-फाई': 'wifi',
        'વાઇફાઇ': 'wifi',
        'ब्लूटूथ': 'bluetooth',
        'બ્લૂટૂથ': 'bluetooth',
        'साउंड': 'sound',
        'સાઉન્ડ': 'sound',
        'डिस्प्ले': 'display',
        'ડિસ્પ્લે': 'display',
        'बैटरी': 'battery',
        'બેટરી': 'battery',
        'लोकेशन': 'location',
        'લોકેશન': 'location',
      };
      for (final entry in indicSectionMap.entries) {
        if (original.contains(entry.key)) {
          return DeviceActionRequest(
            type: DeviceActionType.openSettings,
            target: entry.value,
            displaySummary: 'Open ${entry.value.toUpperCase()} settings',
          );
        }
      }
      return const DeviceActionRequest(
        type: DeviceActionType.openSettings,
        target: 'main',
        displaySummary: 'Open system settings',
      );
    }

    return null;
  }

  static DeviceActionRequest? _parseNotifications(
    String original,
    String lower,
  ) {
    final asksNotif =
        RegExp(
          r'\b(read|check|show|get|any|recent|latest)\b.*\bnotifications?\b',
        ).hasMatch(lower) ||
        original.contains('नोटिफिकेशन') ||
        original.contains('નોટિફિકેશન');
    if (!asksNotif) return null;
    return const DeviceActionRequest(
      type: DeviceActionType.readNotifications,
      displaySummary: 'Check recent notifications',
    );
  }

  static DeviceActionRequest? _parseWhatsApp(String original) {
    final enWa = RegExp(
      r'^(?:send\s+(?:a\s+)?whatsapp(?:\s+message)?\s+to|whatsapp)\s+([+0-9\-\s]{3,}|[a-zA-Z][a-zA-Z0-9\s]{1,30}?)(?:\s+(?:saying|that|:)\s+(.+))?$',
      caseSensitive: false,
    ).firstMatch(original);
    if (enWa != null) {
      final target = enWa.group(1)?.trim() ?? '';
      final message = enWa.group(2)?.trim();
      if (target.isNotEmpty) {
        return DeviceActionRequest(
          type: DeviceActionType.sendWhatsapp,
          target: target,
          message: message,
          displaySummary: 'Compose WhatsApp to $target',
        );
      }
    }

    final hiWa = RegExp(
      r'^(.+?)\s+को\s+(?:व्हाट्सएप|व्हाट्सऐप)\s+(?:करो|भेजो)(?:\s+कि\s+(.+))?$',
    ).firstMatch(original);
    if (hiWa != null) {
      final target = hiWa.group(1)?.trim() ?? '';
      final message = hiWa.group(2)?.trim();
      if (target.isNotEmpty) {
        return DeviceActionRequest(
          type: DeviceActionType.sendWhatsapp,
          target: target,
          message: message,
          displaySummary: 'Compose WhatsApp to $target',
        );
      }
    }

    final guWa = RegExp(
      r'^(.+?)\s*ને\s+(?:વોટ્સએપ|વ્હોટ્સએપ)\s+(?:કરો|મોકલો)(?:\s+કે\s+(.+))?$',
    ).firstMatch(original);
    if (guWa != null) {
      final target = guWa.group(1)?.trim() ?? '';
      final message = guWa.group(2)?.trim();
      if (target.isNotEmpty) {
        return DeviceActionRequest(
          type: DeviceActionType.sendWhatsapp,
          target: target,
          message: message,
          displaySummary: 'Compose WhatsApp to $target',
        );
      }
    }

    return null;
  }

  static DeviceActionRequest? _parseSms(String original) {
    final smsMatch = RegExp(
      r'^(?:send\s+(?:an?\s+)?(?:sms|text|message)\s+to|text)\s+([+0-9\-\s]{3,}|[a-zA-Z][a-zA-Z0-9\s]{1,30}?)(?:\s+(?:saying|that|:)\s+(.+))?$',
      caseSensitive: false,
    ).firstMatch(original);
    if (smsMatch != null) {
      final target = smsMatch.group(1)?.trim() ?? '';
      final message = smsMatch.group(2)?.trim();
      if (target.isNotEmpty) {
        return DeviceActionRequest(
          type: DeviceActionType.sendSms,
          target: target,
          message: message,
          displaySummary: 'Compose SMS to $target',
        );
      }
    }

    final hiSms = RegExp(
      r'^(.+?)\s+को\s+(?:मैसेज|एसएमएस)\s+भेजो(?:\s+कि\s+(.+))?$',
    ).firstMatch(original);
    if (hiSms != null) {
      final target = hiSms.group(1)?.trim() ?? '';
      final message = hiSms.group(2)?.trim();
      if (target.isNotEmpty) {
        return DeviceActionRequest(
          type: DeviceActionType.sendSms,
          target: target,
          message: message,
          displaySummary: 'Compose SMS to $target',
        );
      }
    }

    final guSms = RegExp(
      r'^(.+?)\s*ને\s+(?:મેસેજ|એસએમએસ)\s+મોકલો(?:\s+કે\s+(.+))?$',
    ).firstMatch(original);
    if (guSms != null) {
      final target = guSms.group(1)?.trim() ?? '';
      final message = guSms.group(2)?.trim();
      if (target.isNotEmpty) {
        return DeviceActionRequest(
          type: DeviceActionType.sendSms,
          target: target,
          message: message,
          displaySummary: 'Compose SMS to $target',
        );
      }
    }

    return null;
  }

  static DeviceActionRequest? _parseContactLookup(String original) {
    final match = RegExp(
      r'^(?:find|search|lookup|look up|get)\s+contact\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(original);
    if (match != null) {
      final query = match.group(1)?.trim() ?? '';
      if (query.isNotEmpty) {
        return DeviceActionRequest(
          type: DeviceActionType.lookupContacts,
          target: query,
          displaySummary: 'Search contacts for "$query"',
        );
      }
    }

    final hiMatch = RegExp(
      r'^(.+?)\s+का\s+(?:कॉन्टैक्ट|नंबर)\s+(?:ढूंढो|खोजो|बताओ)$',
    ).firstMatch(original);
    if (hiMatch != null) {
      final query = hiMatch.group(1)?.trim() ?? '';
      if (query.isNotEmpty) {
        return DeviceActionRequest(
          type: DeviceActionType.lookupContacts,
          target: query,
          displaySummary: 'Search contacts for "$query"',
        );
      }
    }

    final guMatch = RegExp(
      r'^(.+?)\s*(?:નો|ના)\s+(?:કોન્ટેક્ટ|નંબર)\s+(?:શોધો|બતાવો)$',
    ).firstMatch(original);
    if (guMatch != null) {
      final query = guMatch.group(1)?.trim() ?? '';
      if (query.isNotEmpty) {
        return DeviceActionRequest(
          type: DeviceActionType.lookupContacts,
          target: query,
          displaySummary: 'Search contacts for "$query"',
        );
      }
    }

    return null;
  }

  static DeviceActionRequest? _parsePhoneCall(String original) {
    final match = RegExp(
      r'^(?:call|dial|phone|ring)\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(original);
    if (match != null) {
      final target = match.group(1)?.trim() ?? '';
      if (target.isNotEmpty) {
        return DeviceActionRequest(
          type: DeviceActionType.callPhone,
          target: target,
          displaySummary: 'Call $target',
          requiresConfirmation: true,
        );
      }
    }

    final hiCall = RegExp(r'^(.+?)\s+को\s+(?:कॉल|फोन)\s+(?:करो|लगाओ)$')
        .firstMatch(original);
    if (hiCall != null) {
      final target = hiCall.group(1)?.trim() ?? '';
      if (target.isNotEmpty) {
        return DeviceActionRequest(
          type: DeviceActionType.callPhone,
          target: target,
          displaySummary: 'Call $target',
          requiresConfirmation: true,
        );
      }
    }

    final guCall = RegExp(r'^(.+?)\s*ને\s+(?:કૉલ|કોલ|ફોન)\s+(?:કરો|લગાવો)$')
        .firstMatch(original);
    if (guCall != null) {
      final target = guCall.group(1)?.trim() ?? '';
      if (target.isNotEmpty) {
        return DeviceActionRequest(
          type: DeviceActionType.callPhone,
          target: target,
          displaySummary: 'Call $target',
          requiresConfirmation: true,
        );
      }
    }

    return null;
  }

  static DeviceActionRequest? _parseNavigation(String original) {
    final match = RegExp(
      r'^(?:navigate\s+to|directions\s+to|route\s+to|take\s+me\s+to)\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(original);
    if (match != null) {
      final dest = match.group(1)?.trim() ?? '';
      if (dest.isNotEmpty) {
        return DeviceActionRequest(
          type: DeviceActionType.navigateTo,
          target: dest,
          displaySummary: 'Navigate to $dest',
        );
      }
    }
    return null;
  }

  static DeviceActionRequest? _parseWebSearch(String original) {
    final match = RegExp(
      r'^(?:search\s+(?:the\s+web|google)\s+for|web\s+search|google\s+search)\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(original);
    if (match != null) {
      final query = match.group(1)?.trim() ?? '';
      if (query.isNotEmpty) {
        return DeviceActionRequest(
          type: DeviceActionType.webSearch,
          target: query,
          displaySummary: 'Search web for "$query"',
        );
      }
    }

    final hiSearch = RegExp(r'^गूगल\s+पर\s+(.+?)\s+(?:खोजो|सर्च\s+करो)$')
        .firstMatch(original);
    if (hiSearch != null) {
      final query = hiSearch.group(1)?.trim() ?? '';
      if (query.isNotEmpty) {
        return DeviceActionRequest(
          type: DeviceActionType.webSearch,
          target: query,
          displaySummary: 'Search web for "$query"',
        );
      }
    }

    final guSearch = RegExp(r'^ગૂગલ\s+પર\s+(.+?)\s+(?:શોધો|સર્ચ\s+કરો)$')
        .firstMatch(original);
    if (guSearch != null) {
      final query = guSearch.group(1)?.trim() ?? '';
      if (query.isNotEmpty) {
        return DeviceActionRequest(
          type: DeviceActionType.webSearch,
          target: query,
          displaySummary: 'Search web for "$query"',
        );
      }
    }

    return null;
  }

  static DeviceActionRequest? _parseOpenUrl(String original) {
    final match = RegExp(
      r'^(?:open|browse|visit)\s+(https?://\S+|(?:www\.)?[a-zA-Z0-9-]+\.[a-zA-Z]{2,}(?:/\S*)?)$',
      caseSensitive: false,
    ).firstMatch(original);
    if (match == null) return null;
    final url = match.group(1)?.trim() ?? '';
    if (url.isEmpty) return null;

    return DeviceActionRequest(
      type: DeviceActionType.openUrl,
      target: url,
      displaySummary: 'Open $url',
    );
  }

  static DeviceActionRequest? _parseLaunchApp(String original) {
    final match = RegExp(
      r'^(?:open|launch|start)\s+(?:the\s+)?(?:app\s+)?(.+?)(?:\s+app)?$',
      caseSensitive: false,
    ).firstMatch(original);
    if (match != null) {
      final appName = match.group(1)?.trim() ?? '';
      if (appName.isNotEmpty) {
        return DeviceActionRequest(
          type: DeviceActionType.launchApp,
          target: appName,
          displaySummary: 'Launch $appName',
        );
      }
    }

    final hiApp = RegExp(r'^(.+?)\s+(?:ऐप\s+)?(?:खोलो|चालू\s+करो)$')
        .firstMatch(original);
    if (hiApp != null) {
      final appName = hiApp.group(1)?.trim() ?? '';
      if (appName.isNotEmpty) {
        return DeviceActionRequest(
          type: DeviceActionType.launchApp,
          target: appName,
          displaySummary: 'Launch $appName',
        );
      }
    }

    final guApp = RegExp(r'^(.+?)\s+(?:એપ\s+)?(?:ખોલો|ચાલુ\s+કરો)$')
        .firstMatch(original);
    if (guApp != null) {
      final appName = guApp.group(1)?.trim() ?? '';
      if (appName.isNotEmpty) {
        return DeviceActionRequest(
          type: DeviceActionType.launchApp,
          target: appName,
          displaySummary: 'Launch $appName',
        );
      }
    }

    return null;
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
