import 'package:vision_ai/core/intelligence/command_normalizer.dart';
import 'package:vision_ai/core/intelligence/conversation_context.dart';
import 'package:vision_ai/core/intelligence/entity_extractor.dart';
import 'package:vision_ai/features/automation/domain/entities/device_action.dart';

/// Scored classification output for a single normalized command clause.
class IntentClassification {
  const IntentClassification({
    required this.intentId,
    required this.confidence,
    required this.language,
    this.request,
    this.clarificationPrompt,
  });

  final String intentId;
  final double confidence;
  final DetectedLanguage language;
  final DeviceActionRequest? request;
  final String? clarificationPrompt;
}

/// Deterministic multilingual classifier supporting English, Hindi, Gujarati,
/// Hinglish, and Gujlish commands with entity validation and clarification.
abstract final class IntentClassifier {
  static final RegExp _informationalQuestionGuard = RegExp(
    r'^(?:why|which|who|whom|whose|how\s+(?:does|do|can|to|much|many|long|far|old)|what\s+(?:is|are|was|were)\s+(?!my\s+(?:battery|notifications?|device|phone\s+status|network)\b)|explain|define|describe|compare|difference\s+between|write\s+(?:a|an|me|some|code)|summarize|tell\s+me\s+(?:about|why|how|what|who|which)|can\s+you\s+(?:explain|tell|write|compare|describe)|could\s+you\s+(?:explain|tell|write|compare|describe)|suggest|is\s+(?:whatsapp|flutter|dart|android|this|that|it)\b|kya\s+hota|kaise\s+kaam|kyu|kaun\s+sa|કેવી\s*રીતે|શું\s*છે)|(?:कैसे\s+काम\s+करता|क्या\s+होता\s+है|કેવી\s+રીતે\s+કામ\s+કરે)',
    caseSensitive: false,
  );

  /// Classifies a single clause [cmd] with optional [context].
  static IntentClassification classifyClause(
    NormalizedCommand cmd,
    ConversationIntelligenceContext context,
  ) {
    final canonical = cmd.canonicalText;
    final cleaned = cmd.cleanedText;
    final lower = cleaned.toLowerCase();

    if (canonical.isEmpty) {
      return IntentClassification(
        intentId: 'general_query',
        confidence: 0,
        language: cmd.language,
      );
    }

    // 1. Assistant voice/control meta-commands (highest priority, zero latency)
    if (_isStopSpeaking(canonical, lower)) {
      return IntentClassification(
        intentId: 'stop_speaking',
        confidence: 0.98,
        language: cmd.language,
        request: const DeviceActionRequest(
          type: DeviceActionType.stopSpeaking,
          displaySummary: 'Stop current speech',
        ),
      );
    }

    if (_isRepeatLast(canonical, lower)) {
      return IntentClassification(
        intentId: 'repeat_last',
        confidence: 0.96,
        language: cmd.language,
        request: const DeviceActionRequest(
          type: DeviceActionType.repeatLast,
          displaySummary: 'Repeat previous response',
        ),
      );
    }

    // Distinguish cancel alarm / cancel timer before generic cancel pending action.
    if (_isDismissAlarm(canonical, lower)) {
      return IntentClassification(
        intentId: 'dismiss_alarm',
        confidence: 0.93,
        language: cmd.language,
        request: const DeviceActionRequest(
          type: DeviceActionType.dismissAlarm,
          displaySummary: 'Dismiss or manage alarm',
        ),
      );
    }

    if (_isDismissTimer(canonical, lower)) {
      return IntentClassification(
        intentId: 'dismiss_timer',
        confidence: 0.93,
        language: cmd.language,
        request: const DeviceActionRequest(
          type: DeviceActionType.dismissTimer,
          displaySummary: 'Dismiss or manage timer',
        ),
      );
    }

    if (_isCancelPendingAction(canonical, lower, context)) {
      return IntentClassification(
        intentId: 'cancel_action',
        confidence: 0.95,
        language: cmd.language,
        request: const DeviceActionRequest(
          type: DeviceActionType.cancelAction,
          displaySummary: 'Cancel pending action',
        ),
      );
    }

    // Complete pending clarification turn ("What time?" -> "7 AM", "Who?" -> "Soel Kht")
    if (context.pendingClarificationIntentId != null) {
      final followUp = _resolvePendingClarification(cmd, canonical, lower, context);
      if (followUp != null) return followUp;
    }

    // Guard general knowledge questions so we never misfire local actions on
    // queries like "Explain how timers work" or "Why is my battery draining?".
    if (_informationalQuestionGuard.hasMatch(lower) &&
        !_isExplicitDeviceStatus(canonical, lower)) {
      return IntentClassification(
        intentId: 'general_query',
        confidence: 0.1,
        language: cmd.language,
      );
    }

    // 2. Flashlight / Torch
    final torch = _classifyFlashlight(cmd, canonical, lower);
    if (torch != null) return torch;

    // 3. Ringer & Volume
    final ringer = _classifyRinger(cmd, canonical, lower);
    if (ringer != null) return ringer;

    final volume = _classifyVolume(cmd, canonical, lower);
    if (volume != null) return volume;

    // 4. Device status / battery / network
    if (_isExplicitDeviceStatus(canonical, lower)) {
      return IntentClassification(
        intentId: 'device_status',
        confidence: 0.92,
        language: cmd.language,
        request: const DeviceActionRequest(
          type: DeviceActionType.deviceStatus,
          displaySummary: 'Check device battery, network & system status',
        ),
      );
    }

    // 5. Alarm & Timer (before WhatsApp/App checks so "alarm muk" doesn't collide)
    final alarm = _classifyAlarm(cmd, canonical, lower);
    if (alarm != null) return alarm;

    final timer = _classifyTimer(cmd, canonical, lower);
    if (timer != null) return timer;

    // 6. Notifications
    if (_isNotificationQuery(canonical, lower)) {
      return IntentClassification(
        intentId: 'read_notifications',
        confidence: 0.91,
        language: cmd.language,
        request: const DeviceActionRequest(
          type: DeviceActionType.readNotifications,
          displaySummary: 'Read recent Android notifications',
        ),
      );
    }

    // 7. System Settings
    if (_isSettingsIntent(canonical, lower)) {
      final section = EntityExtractor.extractSettingsSection(cmd);
      return IntentClassification(
        intentId: 'open_settings',
        confidence: 0.92,
        language: cmd.language,
        request: DeviceActionRequest(
          type: DeviceActionType.openSettings,
          target: section,
          displaySummary: section == 'main'
              ? 'Open Android Settings'
              : 'Open Android ${section.replaceAll('_', ' ').toUpperCase()} settings',
        ),
      );
    }

    // 8. Messaging (SMS & WhatsApp) - check before Launch App so "WhatsApp Rahul"
    // routes to SendWhatsApp rather than merely opening WhatsApp unless it's "open WhatsApp".
    final sms = _classifySms(cmd, canonical, lower, context);
    if (sms != null) return sms;

    final wa = _classifyWhatsApp(cmd, canonical, lower, context);
    if (wa != null) return wa;

    // 9. Contacts & Phone Calls
    final contactOrCall = _classifyCallOrContact(
      cmd,
      canonical,
      lower,
      context,
    );
    if (contactOrCall != null) return contactOrCall;

    // 10. Navigation, URL & Web Search
    final nav = _classifyNavigation(cmd, canonical, cleaned);
    if (nav != null) return nav;

    final search = _classifyWebSearch(cmd, canonical, cleaned);
    if (search != null) return search;

    final url = _classifyOpenUrl(cmd, canonical, cleaned);
    if (url != null) return url;

    // 11. Open App
    final app = _classifyOpenApp(cmd, canonical, lower);
    if (app != null) return app;

    return IntentClassification(
      intentId: 'general_query',
      confidence: 0,
      language: cmd.language,
    );
  }

  static bool _isStopSpeaking(String canonical, String lower) {
    return RegExp(
          r'^(?:stop\s+(?:speaking|talking|voice|tts)|be\s+quiet|shut\s+up|quiet|silence|mute\s+yourself|chup(?:\s+ho\s+jao?|\s+raho)?|bolna\s+band\s*karo?|bolvanu\s+band\s*kar|શાંત\s*થા|બોલવાનું\s*બંધ\s*કર|आवाज\s*बंद|चुप\s*रहो)$',
          caseSensitive: false,
        ).hasMatch(canonical) ||
        RegExp(
          r'\b(stop\s+speaking|stop\s+talking|bolna\s+bandh?\s+kar|bolvanu\s+bandh?\s+kar)\b',
        ).hasMatch(lower);
  }

  static bool _isRepeatLast(String canonical, String lower) {
    return RegExp(
          r'^(?:repeat(?:\s+that|\s+last|\s+response|\s+please)?|say\s+(?:that\s+)?again|what\s+did\s+you\s+say|pardon|fari(?:\s+thi)?\s+bol(?:o)?|phir\s+se\s+bol(?:o)?|dobara\s+bol(?:o)?|फिर\s*से\s*(?:बोलो|कहो)|ફરીથી\s*બોલ(?:ો)?)$',
          caseSensitive: false,
        ).hasMatch(canonical) ||
        RegExp(
          r'\b(repeat\s+(?:your\s+)?(?:previous|last)\s+(?:response|reply|answer)|fari\s+thi\s+bol)\b',
        ).hasMatch(lower);
  }

  static bool _isDismissAlarm(String canonical, String lower) {
    return RegExp(
          r'\b(?:(?:cancel|stop|dismiss|delete|remove|turn\s+off|band|bandh)\s+(?:the\s+|my\s+|all\s+)?alarms?|alarms?\s+(?:band|bandh|cancel|stop|off|dismiss)(?:\s+kar(?:o)?)?)\b',
          caseSensitive: false,
        ).hasMatch(canonical) ||
        RegExp(r'अलार्म\s*(?:बंद|हटाओ|रद्द)|અલાર્મ\s*(?:બંધ|રદ)')
            .hasMatch(lower);
  }

  static bool _isDismissTimer(String canonical, String lower) {
    return RegExp(
          r'\b(?:(?:cancel|stop|dismiss|delete|remove|turn\s+off|band|bandh)\s+(?:the\s+|my\s+|all\s+)?timers?|timers?\s+(?:band|bandh|cancel|stop|off|dismiss)(?:\s+kar(?:o)?)?)\b',
          caseSensitive: false,
        ).hasMatch(canonical) ||
        RegExp(r'टाइमर\s*(?:बंद|रद्द)|ટાઇમર\s*(?:બંધ|રદ)').hasMatch(lower);
  }

  static bool _isCancelPendingAction(
    String canonical,
    String lower,
    ConversationIntelligenceContext context,
  ) {
    final hasPending =
        context.pendingAction != null ||
        context.pendingClarificationIntentId != null;
    if (hasPending &&
        RegExp(
          r'^(?:no|nope|nah|wrong|not\s+that(?:\s+one)?|nahi|na|mat|rehne\s+de|छोड़ो|रहने\s*दो|નહીં|ના)$',
          caseSensitive: false,
        ).hasMatch(canonical)) {
      return true;
    }
    return RegExp(
          r'^(?:cancel(?:\s+that|\s+it|\s+action|\s+pending(?:\s+action)?)?|abort|nevermind|never\s+mind|mat\s+kar(?:o)?|rehne\s+de|radd\s+kar|rad\s+kar|रद्द\s*करो?|मत\s*करो|રદ\s*કર(?:ો)?)$',
          caseSensitive: false,
        ).hasMatch(canonical) ||
        RegExp(r'\b(cancel\s+pending\s+action)\b').hasMatch(lower);
  }

  static IntentClassification? _resolvePendingClarification(
    NormalizedCommand cmd,
    String canonical,
    String lower,
    ConversationIntelligenceContext context,
  ) {
    if (_informationalQuestionGuard.hasMatch(lower)) return null;
    switch (context.pendingClarificationIntentId) {
      case 'set_alarm':
        final parsed = EntityExtractor.extractAlarmTime(cmd);
        if (parsed != null) {
          final hh = parsed.hour.toString().padLeft(2, '0');
          final mm = parsed.minute.toString().padLeft(2, '0');
          final dayNote = parsed.isTomorrow ? ' (tomorrow)' : '';
          return IntentClassification(
            intentId: 'set_alarm',
            confidence: 0.94,
            language: cmd.language,
            request: DeviceActionRequest(
              type: DeviceActionType.setAlarm,
              hour: parsed.hour,
              minute: parsed.minute,
              label: parsed.label,
              isTomorrow: parsed.isTomorrow,
              displaySummary: 'Set alarm for $hh:$mm$dayNote',
            ),
          );
        }
      case 'set_timer':
        final seconds = EntityExtractor.extractTimerSeconds(cmd);
        if (seconds != null && seconds > 0) {
          final formatted = seconds >= 60 && seconds % 60 == 0
              ? '${seconds ~/ 60} min'
              : '$seconds sec';
          return IntentClassification(
            intentId: 'set_timer',
            confidence: 0.94,
            language: cmd.language,
            request: DeviceActionRequest(
              type: DeviceActionType.setTimer,
              durationSeconds: seconds,
              displaySummary: 'Start $formatted timer',
            ),
          );
        }
      case 'call_phone':
      case 'lookup_contacts':
        final phone = EntityExtractor.extractPhoneNumber(cmd.cleanedText);
        final candidate = phone.isNotEmpty
            ? phone
            : cmd.cleanedText.replaceAll(RegExp(r'[\.\?!,]+$'), '').trim();
        if (candidate.isNotEmpty && cmd.tokens.length <= 4) {
          final isCall = context.pendingClarificationIntentId == 'call_phone';
          return IntentClassification(
            intentId: context.pendingClarificationIntentId!,
            confidence: 0.91,
            language: cmd.language,
            request: DeviceActionRequest(
              type: isCall
                  ? DeviceActionType.callPhone
                  : DeviceActionType.lookupContacts,
              target: candidate,
              requiresConfirmation: isCall,
              displaySummary: isCall
                  ? 'Call $candidate'
                  : 'Search contacts for "$candidate"',
            ),
          );
        }
      case 'launch_app':
        final app = EntityExtractor.extractAppName(cmd);
        final target = app.isNotEmpty ? app : cmd.cleanedText.trim();
        if (target.isNotEmpty && cmd.tokens.length <= 3) {
          return IntentClassification(
            intentId: 'launch_app',
            confidence: 0.90,
            language: cmd.language,
            request: DeviceActionRequest(
              type: DeviceActionType.launchApp,
              target: target,
              displaySummary: 'Open $target',
            ),
          );
        }
      case 'send_sms':
      case 'send_whatsapp':
        final target = cmd.cleanedText.replaceAll(RegExp(r'[\.\?!,]+$'), '').trim();
        if (target.isNotEmpty && cmd.tokens.length <= 4) {
          final isWa = context.pendingClarificationIntentId == 'send_whatsapp';
          return IntentClassification(
            intentId: context.pendingClarificationIntentId!,
            confidence: 0.89,
            language: cmd.language,
            request: DeviceActionRequest(
              type: isWa
                  ? DeviceActionType.sendWhatsapp
                  : DeviceActionType.sendSms,
              target: target,
              displaySummary: isWa
                  ? 'Send WhatsApp message to $target'
                  : 'Draft SMS to $target',
            ),
          );
        }
    }
    return null;
  }

  static IntentClassification? _classifyFlashlight(
    NormalizedCommand cmd,
    String canonical,
    String lower,
  ) {
    if (!RegExp(r'\b(flashlight|torch|flash)\b|टॉर्च|फ्लैशलाइट|ટૉર્ચ|ફ્લેશલાઇટ')
        .hasMatch('$canonical $lower')) {
      return null;
    }

    final turnOff = RegExp(r'\b(off|disable|close|stop|band|bandh)\b|बंद|બંધ')
        .hasMatch('$canonical $lower');
    final turnOn = RegExp(
      r'\b(on|enable|start|open|chalu|jalao|sharuu)\b|चालू|जलाओ|ચાલુ|શરૂ',
    ).hasMatch('$canonical $lower');

    if (!turnOn && !turnOff) return null;
    final enabled = turnOn && !turnOff;
    return IntentClassification(
      intentId: 'toggle_flashlight',
      confidence: 0.95,
      language: cmd.language,
      request: DeviceActionRequest(
        type: DeviceActionType.toggleFlashlight,
        enabled: enabled,
        displaySummary: enabled ? 'Turn flashlight ON' : 'Turn flashlight OFF',
      ),
    );
  }

  static IntentClassification? _classifyRinger(
    NormalizedCommand cmd,
    String canonical,
    String lower,
  ) {
    final text = '$canonical $lower';
    if (!RegExp(
      r'\b(silent|vibrate|vibration|ringer|ring\s+mode|sound\s+mode|normal\s+mode|dnd)\b|साइलेंट|वाइब्रेट|રિંગર|સાઇલેન્ટ|વાઇબ્રેટ',
    ).hasMatch(text)) {
      return null;
    }

    // Avoid hijacking "silent video" etc. unless mode/phone/put/set/kar is present
    if (!RegExp(
      r'\b(phone|device|mode|put|set|make|switch|turn|kar|muk)\b|फोन|मोड|रखो|करो|ફોન|મોડ|મૂકો|કરો',
    ).hasMatch(text)) {
      return null;
    }

    String? mode;
    if (RegExp(r'\bsilent\b|\bdnd\b|साइलेंट|સાઇલેન્ટ').hasMatch(text)) {
      mode = 'silent';
    } else if (RegExp(r'\bvibrate\b|\bvibration\b|वाइब्रेट|વાઇબ્રેટ')
        .hasMatch(text)) {
      mode = 'vibrate';
    } else if (RegExp(r'\b(normal|ring)\b|रिंग|સામાન્ય').hasMatch(text)) {
      mode = 'normal';
    }
    if (mode == null) return null;

    return IntentClassification(
      intentId: 'set_ringer_mode',
      confidence: 0.92,
      language: cmd.language,
      request: DeviceActionRequest(
        type: DeviceActionType.setRingerMode,
        target: mode,
        displaySummary: 'Set ringer mode to $mode',
      ),
    );
  }

  static IntentClassification? _classifyVolume(
    NormalizedCommand cmd,
    String canonical,
    String lower,
  ) {
    final text = '$canonical $lower';
    if (!RegExp(r'\b(volume|sound|audio)\b|वॉल्यूम|आवाज़|आवाज|વોલ્યુમ|અવાજ')
        .hasMatch(text)) {
      return null;
    }
    // Note: "mute" / "unmute" handled when combined with volume/sound/audio
    String? direction;
    if (RegExp(
      r'\b(up|increase|raise|higher|badhao|vadharo|tez)\b|बढ़ाओ|वधारो|વધારો',
    ).hasMatch(text)) {
      direction = 'up';
    } else if (RegExp(
      r'\b(down|decrease|lower|reduce|kam|ghatado|ochho)\b|कम|घटाओ|ઓછો|ઘટાડો',
    ).hasMatch(text)) {
      direction = 'down';
    } else if (RegExp(r'\bunmute\b').hasMatch(text)) {
      direction = 'unmute';
    } else if (RegExp(r'\bmute\b|म्यूट|મ્યૂટ').hasMatch(text)) {
      direction = 'mute';
    }
    if (direction == null) return null;

    return IntentClassification(
      intentId: 'adjust_volume',
      confidence: 0.92,
      language: cmd.language,
      request: DeviceActionRequest(
        type: DeviceActionType.adjustVolume,
        target: direction,
        displaySummary: 'Adjust media volume ($direction)',
      ),
    );
  }

  static bool _isExplicitDeviceStatus(String canonical, String lower) {
    final text = '$canonical $lower';
    return RegExp(
      r'\b(battery\s+(?:level|percent|percentage|status)|device\s+status|phone\s+status|system\s+status|network\s+status|check\s+(?:my\s+)?(?:battery|device|phone)|charge\s+kitna|battery\s+kitni|battery\s+ketli)\b|बैटरी\s*(?:कितनी|स्टेटस)|બેટરી\s*(?:કેટલી|સ્ટેટસ)',
      caseSensitive: false,
    ).hasMatch(text);
  }

  static IntentClassification? _classifyAlarm(
    NormalizedCommand cmd,
    String canonical,
    String lower,
  ) {
    final text = '$canonical $lower';
    final hasExplicitAlarmWord = RegExp(
      r'\balarm\b|अलार्म|अलाउम|અલાર્મ|એલાર્મ',
    ).hasMatch(text);
    final hasWakePhrase = RegExp(
      r'\bwake\s+me(?:\s+up)?\b|\butha\s*(?:dena|do)\b|\buthadje\b',
      caseSensitive: false,
    ).hasMatch(text);
    final hasTimeSchedulePhrase =
        cmd.tokens.length <= 8 &&
        RegExp(
          r'\b(?:kal|tomorrow|subah|savare|shaam|sanje|ratre)\b|कल|આવતીકાલે|કાલે|સવારે|સુબહ',
          caseSensitive: false,
        ).hasMatch(text) &&
        RegExp(
          r"\b(?:vage|baje|am|pm|o'?clock)\b|बजे|वागे|વાગે|વાગ્યે",
          caseSensitive: false,
        ).hasMatch(text) &&
        !RegExp(
          r'\b(?:meeting|train|flight|bus|class|movie|call|message|weather|news)\b',
          caseSensitive: false,
        ).hasMatch(text);

    if (!hasExplicitAlarmWord && !hasWakePhrase && !hasTimeSchedulePhrase) {
      return null;
    }
    // Check show alarms intent vs set alarm intent
    if (RegExp(r'^(?:show|open|view|list)\s+(?:my\s+)?alarms?$')
        .hasMatch(canonical)) {
      return IntentClassification(
        intentId: 'open_settings',
        confidence: 0.78,
        language: cmd.language,
        request: const DeviceActionRequest(
          type: DeviceActionType.launchApp,
          target: 'clock',
          displaySummary: 'Open Clock & Alarms',
        ),
      );
    }

    final parsed = EntityExtractor.extractAlarmTime(cmd);
    if (parsed == null) {
      return IntentClassification(
        intentId: 'set_alarm',
        confidence: 0.85,
        language: cmd.language,
        clarificationPrompt:
            'What time would you like me to set the alarm for?',
      );
    }

    final hh = parsed.hour.toString().padLeft(2, '0');
    final mm = parsed.minute.toString().padLeft(2, '0');
    final dayNote = parsed.isTomorrow ? ' (tomorrow)' : '';
    return IntentClassification(
      intentId: 'set_alarm',
      confidence: 0.95,
      language: cmd.language,
      request: DeviceActionRequest(
        type: DeviceActionType.setAlarm,
        hour: parsed.hour,
        minute: parsed.minute,
        label: parsed.label,
        isTomorrow: parsed.isTomorrow,
        displaySummary: 'Set alarm for $hh:$mm$dayNote',
      ),
    );
  }

  static IntentClassification? _classifyTimer(
    NormalizedCommand cmd,
    String canonical,
    String lower,
  ) {
    final text = '$canonical $lower';
    if (!RegExp(r'\btimer\b|\bcountdown\b|टाइमर|ટાઇમર').hasMatch(text)) {
      return null;
    }

    final seconds = EntityExtractor.extractTimerSeconds(cmd);
    if (seconds == null || seconds <= 0) {
      return IntentClassification(
        intentId: 'set_timer',
        confidence: 0.84,
        language: cmd.language,
        clarificationPrompt: 'How long should the timer run?',
      );
    }

    final formatted = seconds >= 60 && seconds % 60 == 0
        ? '${seconds ~/ 60} min'
        : '$seconds sec';
    return IntentClassification(
      intentId: 'set_timer',
      confidence: 0.95,
      language: cmd.language,
      request: DeviceActionRequest(
        type: DeviceActionType.setTimer,
        durationSeconds: seconds,
        displaySummary: 'Start $formatted timer',
      ),
    );
  }

  static bool _isNotificationQuery(String canonical, String lower) {
    final text = '$canonical $lower';
    return RegExp(
      r'\b(read|check|show|get|what\s+are)\b.*\bnotifications?\b|\bnotifications?\b.*\b(batao|padho|batav|dikhao|dekhao|check|read)\b|नोटिफिकेशन|નોટિફિકેશન',
      caseSensitive: false,
    ).hasMatch(text);
  }

  static bool _isSettingsIntent(String canonical, String lower) {
    final text = '$canonical $lower';
    return RegExp(
          r'\b(settings?|wifi\s+settings|bluetooth\s+settings|display\s+settings|battery\s+settings|sound\s+settings|privacy\s+settings|location\s+settings|default\s+assistant\s+settings)\b|सेटिंग्स|સેટિંગ્સ',
          caseSensitive: false,
        ).hasMatch(text) &&
        RegExp(
          r'\b(open|launch|go\s+to|show|khol|chalu|setting|settings)\b|खोल|ખોલ',
          caseSensitive: false,
        ).hasMatch(text);
  }

  static IntentClassification? _classifySms(
    NormalizedCommand cmd,
    String canonical,
    String lower,
    ConversationIntelligenceContext context,
  ) {
    final text = '$canonical $lower';
    if (!RegExp(
      r'\b(sms|text\s+message|text|message|msg)\b|\bsend\s+(?:a\s+)?message\b|मैसेज|मेसेज|મેસેજ',
    ).hasMatch(text)) {
      return null;
    }
    if (RegExp(r'\bwhatsapp\b|व्हाट्सएप|વોટ્સએપ').hasMatch(text)) {
      return null;
    }
    final explicitSmsOrText = RegExp(r'\b(sms|text\s+message|text)\b')
        .hasMatch(text);
    if (!explicitSmsOrText &&
        context.lastAppName?.toLowerCase() == 'whatsapp') {
      return null;
    }

    final msg = EntityExtractor.extractMessageTargets(cmd, context);
    final phone = EntityExtractor.extractPhoneNumber(cmd.cleanedText);
    final recipient = phone.isNotEmpty ? phone : msg.recipient;

    if (recipient.isEmpty) {
      return IntentClassification(
        intentId: 'send_sms',
        confidence: 0.82,
        language: cmd.language,
        clarificationPrompt: 'Who should I send the SMS to?',
      );
    }

    return IntentClassification(
      intentId: 'send_sms',
      confidence: 0.90,
      language: cmd.language,
      request: DeviceActionRequest(
        type: DeviceActionType.sendSms,
        target: recipient,
        message: msg.message.isEmpty ? null : msg.message,
        displaySummary: 'Draft SMS to $recipient',
      ),
    );
  }

  static IntentClassification? _classifyWhatsApp(
    NormalizedCommand cmd,
    String canonical,
    String lower,
    ConversationIntelligenceContext context,
  ) {
    final text = '$canonical $lower';
    final hasExplicitWhatsApp = RegExp(
      r'\b(whatsapp|wa)\b|व्हाट्सएप|वॉट्सऐप|વોટ્સએપ|વૉટ્સએપ',
    ).hasMatch(text);
    final isFollowUpInWhatsApp =
        !hasExplicitWhatsApp &&
        context.lastAppName?.toLowerCase() == 'whatsapp' &&
        RegExp(
          r'\b(?:now\s+)?(?:send\s+(?:a\s+)?message|message|msg)\b|मैसेज|મેસેજ',
        ).hasMatch(text);

    if (!hasExplicitWhatsApp && !isFollowUpInWhatsApp) {
      return null;
    }

    // Pure "open WhatsApp" / "WhatsApp khol" / "WhatsApp open" -> LaunchApp, NOT SendWhatsApp
    if (RegExp(
      r'^(?:(?:please\s+)?(?:open|launch|start|run)\s+(?:my\s+|the\s+)?whatsapp(?:\s+app)?|whatsapp\s+(?:khol|chalu\s+kar|open(?:\s+kar)?|start(?:\s+kar)?)|व्हाट्सएप\s*खोलो?|વોટ્સએપ\s*ખોલો?)$',
      caseSensitive: false,
    ).hasMatch(canonical)) {
      return null;
    }

    // Do not hijack informational queries mentioning WhatsApp ("what is whatsapp")
    final hasMessagingAction =
        isFollowUpInWhatsApp ||
        RegExp(
          r'\b(?:send|message|msg|text|saying|that|to|kar|bhej|bhejo|moklo|ne|ko)\b|करो|भेजो|કરો|મોકલો|ને|કો',
          caseSensitive: false,
        ).hasMatch(text) ||
        RegExp(r'^(?:whatsapp|wa)\s+[a-zA-Z\u0900-\u097F\u0A80-\u0AFF]+', caseSensitive: false).hasMatch(canonical);
    if (!hasMessagingAction) {
      return null;
    }

    final msg = EntityExtractor.extractMessageTargets(cmd, context);
    final phone = EntityExtractor.extractPhoneNumber(cmd.cleanedText);
    final recipient = phone.isNotEmpty ? phone : msg.recipient;

    return IntentClassification(
      intentId: 'send_whatsapp',
      confidence: 0.91,
      language: cmd.language,
      request: DeviceActionRequest(
        type: DeviceActionType.sendWhatsapp,
        target: recipient,
        message: msg.message.isEmpty ? null : msg.message,
        displaySummary: recipient.isNotEmpty
            ? 'Send WhatsApp message to $recipient'
            : 'Share message on WhatsApp',
      ),
    );
  }

  static IntentClassification? _classifyCallOrContact(
    NormalizedCommand cmd,
    String canonical,
    String lower,
    ConversationIntelligenceContext context,
  ) {
    final text = '$canonical $lower';

    final hasLookupVerb = RegExp(
      r'\b(find|lookup|look\s+up|search)\b|ढूंढो|बताओ|શોધો|બતાવ',
      caseSensitive: false,
    ).hasMatch(text);
    final isExplicitCallVerb = RegExp(
      r'\b(call|dial|ring)\b|कॉल|फोन\s*(?:कर|लगा)|કોલ|કૉલ|ફોન\s*(?:કર|લગાવ)',
      caseSensitive: false,
    ).hasMatch(text);
    final isActionablePhoneCall = RegExp(
      r'\bphone\s+(?:lagao|laga|kar|karje|muk)\b|\b(?:ne|ko)\s+phone\b|^(?:please\s+)?phone\s+[a-zA-Z\u0900-\u097F\u0A80-\u0AFF]+$',
      caseSensitive: false,
    ).hasMatch(canonical);

    final isExplicitContactLookup =
        !isExplicitCallVerb &&
        RegExp(
          r'\b(find\s+contacts?|lookup\s+contacts?|look\s+up\s+contacts?|search\s+contacts?|contacts?\s+number|phone\s+number\s+of|number\s+of)\b|\b(?:no|ka|ko)\s+number\s+(?:search|batao|batav|dikhao)\b|नंबर\s*(?:ढूंढो|बताओ)|નંબર\s*(?:શોધો|બતાવ)',
          caseSensitive: false,
        ).hasMatch(text);
    final isShortFind =
        !isExplicitCallVerb &&
        RegExp(
          r'^(?:find|lookup|look\s+up)\s+[a-zA-Z\u0900-\u097F\u0A80-\u0AFF]{2,20}(?:\s+[a-zA-Z\u0900-\u097F\u0A80-\u0AFF]{2,20})?$',
          caseSensitive: false,
        ).hasMatch(cmd.cleanedText) &&
        !RegExp(
          r'\b(weather|news|restaurants?|recipes?|meaning|price|route|directions?|online)\b',
          caseSensitive: false,
        ).hasMatch(canonical);
    final isLookup =
        isExplicitContactLookup ||
        isShortFind ||
        (hasLookupVerb && text.contains('number'));

    final isCall = !isLookup && (isExplicitCallVerb || isActionablePhoneCall);

    if (!isCall && !isLookup) return null;

    final phone = EntityExtractor.extractPhoneNumber(cmd.cleanedText);
    final extracted = EntityExtractor.extractContact(cmd, context);
    final target = phone.isNotEmpty ? phone : extracted.contact;

    if (target.isEmpty) {
      return IntentClassification(
        intentId: isCall ? 'call_phone' : 'lookup_contacts',
        confidence: 0.80,
        language: cmd.language,
        clarificationPrompt: isCall
            ? 'Who would you like me to call?'
            : 'Which contact would you like me to find?',
      );
    }

    if (isLookup) {
      return IntentClassification(
        intentId: 'lookup_contacts',
        confidence: 0.92,
        language: cmd.language,
        request: DeviceActionRequest(
          type: DeviceActionType.lookupContacts,
          target: target,
          contactOrdinalIndex: extracted.ordinalIndex,
          displaySummary: 'Search contacts for "$target"',
        ),
      );
    }

    final ordinalNote = extracted.ordinalIndex != null
        ? ' (option ${extracted.ordinalIndex! + 1})'
        : '';
    return IntentClassification(
      intentId: 'call_phone',
      confidence: 0.94,
      language: cmd.language,
      request: DeviceActionRequest(
        type: DeviceActionType.callPhone,
        target: target,
        contactOrdinalIndex: extracted.ordinalIndex,
        requiresConfirmation: true,
        displaySummary: 'Call $target$ordinalNote',
      ),
    );
  }

  static IntentClassification? _classifyNavigation(
    NormalizedCommand cmd,
    String canonical,
    String cleaned,
  ) {
    final dest = EntityExtractor.extractTrailingPayload(
      cleaned,
      RegExp(
        r'^(?:navigate\s+to|directions\s+to|route\s+to|take\s+me\s+to|maps\s+to)\s+(.+)$',
        caseSensitive: false,
      ),
    );
    if (dest.isEmpty) return null;

    return IntentClassification(
      intentId: 'navigate_to',
      confidence: 0.92,
      language: cmd.language,
      request: DeviceActionRequest(
        type: DeviceActionType.navigateTo,
        target: dest,
        displaySummary: 'Navigate to $dest',
      ),
    );
  }

  static IntentClassification? _classifyWebSearch(
    NormalizedCommand cmd,
    String canonical,
    String cleaned,
  ) {
    var query = EntityExtractor.extractTrailingPayload(
      cleaned,
      RegExp(
        r'^(?:web\s+search(?:\s+for)?|search\s+(?:the\s+web\s+|google\s+)?for|google\s+search(?:\s+for)?|google|look\s+up\s+online)\s+(.+)$',
        caseSensitive: false,
      ),
    );
    if (query.isEmpty) {
      query = EntityExtractor.extractTrailingPayload(
        cleaned,
        RegExp(
          r'^(?:गूगल\s+(?:पर|पे)|ગૂગલ\s+પર)\s+(.+?)\s+(?:खोजो|सर्च\s*करो|ढूंढो|શોધો|સર્ચ\s*કરો|સર્ચ\s*કર)$',
        ),
      );
    }
    if (query.isEmpty) return null;

    return IntentClassification(
      intentId: 'web_search',
      confidence: 0.90,
      language: cmd.language,
      request: DeviceActionRequest(
        type: DeviceActionType.webSearch,
        target: query,
        displaySummary: 'Search the web for "$query"',
      ),
    );
  }

  static IntentClassification? _classifyOpenUrl(
    NormalizedCommand cmd,
    String canonical,
    String cleaned,
  ) {
    final match = RegExp(
      r'^(?:open|visit|go\s+to|browse)\s+(https?://\S+|(?:www\.)?[a-zA-Z0-9-]+\.[a-zA-Z]{2,}(?:/\S*)?)$',
      caseSensitive: false,
    ).firstMatch(cleaned);
    if (match == null) return null;

    final url = match.group(1)!.trim();
    return IntentClassification(
      intentId: 'open_url',
      confidence: 0.92,
      language: cmd.language,
      request: DeviceActionRequest(
        type: DeviceActionType.openUrl,
        target: url,
        displaySummary: 'Open $url',
      ),
    );
  }

  static IntentClassification? _classifyOpenApp(
    NormalizedCommand cmd,
    String canonical,
    String lower,
  ) {
    if (!RegExp(
      r'\b(open|launch|start|run|khol|chalu)\b|खोल|ખોલ|ચાલુ|चालू',
      caseSensitive: false,
    ).hasMatch('$canonical $lower')) {
      return null;
    }

    final appName = EntityExtractor.extractAppName(cmd);
    if (appName.isEmpty) {
      return IntentClassification(
        intentId: 'launch_app',
        confidence: 0.72,
        language: cmd.language,
        clarificationPrompt: 'Which app would you like me to open?',
      );
    }

    return IntentClassification(
      intentId: 'launch_app',
      confidence: 0.93,
      language: cmd.language,
      request: DeviceActionRequest(
        type: DeviceActionType.launchApp,
        target: appName,
        displaySummary: 'Open $appName',
      ),
    );
  }
}
