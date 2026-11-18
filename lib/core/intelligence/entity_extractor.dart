import 'package:vision_ai/core/intelligence/command_normalizer.dart';
import 'package:vision_ai/core/intelligence/conversation_context.dart';

/// Parsed alarm clock entities including relative day and period inference.
class ExtractedAlarmTime {
  const ExtractedAlarmTime({
    required this.hour,
    required this.minute,
    this.isTomorrow = false,
    this.isRelativeDayMentioned = false,
    this.label,
  });

  final int hour;
  final int minute;
  final bool isTomorrow;
  final bool isRelativeDayMentioned;
  final String? label;
}

/// Extracted domain entities derived from a normalized command clause.
class ExtractedEntities {
  const ExtractedEntities({
    this.contactQuery = '',
    this.contactOrdinalIndex,
    this.phoneNumber = '',
    this.alarmTime,
    this.timerSeconds,
    this.appName = '',
    this.settingsSection = '',
    this.messageBody = '',
    this.searchQuery = '',
    this.url = '',
    this.destination = '',
    this.flashlightOn,
    this.ringerMode,
    this.volumeDirection,
    this.usedConversationContext = false,
  });

  final String contactQuery;
  final int? contactOrdinalIndex;
  final String phoneNumber;
  final ExtractedAlarmTime? alarmTime;
  final int? timerSeconds;
  final String appName;
  final String settingsSection;
  final String messageBody;
  final String searchQuery;
  final String url;
  final String destination;
  final bool? flashlightOn;
  final String? ringerMode;
  final String? volumeDirection;
  final bool usedConversationContext;
}

/// Deterministic multilingual entity extractor for EN / HI / GU / Hinglish / Gujlish.
abstract final class EntityExtractor {
  static const Map<String, ({String canonical, List<String> aliases})>
  _appAliases = <String, ({String canonical, List<String> aliases})>{
    'whatsapp': (
      canonical: 'WhatsApp',
      aliases: <String>[
        'whatsapp',
        'wa business',
        'whatsapp business',
        'व्हाट्सएप',
        'वॉट्सऐप',
        'વોટ્સએપ',
        'વૉટ્સએપ',
      ],
    ),
    'youtube': (
      canonical: 'YouTube',
      aliases: <String>['youtube', 'yt', 'यूट्यूब', 'યુટ્યુબ'],
    ),
    'chrome': (
      canonical: 'Chrome',
      aliases: <String>['chrome', 'google chrome', 'browser', 'क्रोम', 'ક્રોમ'],
    ),
    'camera': (
      canonical: 'Camera',
      aliases: <String>['camera', 'cam', 'कैमरा', 'કેમેરા'],
    ),
    'calculator': (
      canonical: 'Calculator',
      aliases: <String>['calculator', 'calc', 'कैलकुलेटर', 'કેલ્ક્યુલેટર'],
    ),
    'calendar': (
      canonical: 'Calendar',
      aliases: <String>['calendar', 'कैलेंडर', 'કેલેન્ડર'],
    ),
    'clock': (
      canonical: 'Clock',
      aliases: <String>['clock', 'alarm clock', 'अलार्म', 'ઘડિયાળ'],
    ),
    'contacts': (
      canonical: 'Contacts',
      aliases: <String>['contacts', 'संपर्क', 'કોન્ટેક્ટ્સ'],
    ),
    'gallery': (
      canonical: 'Gallery',
      aliases: <String>['gallery', 'photos', 'गैलरी', 'ગેલેરી', 'ફોટોઝ'],
    ),
    'maps': (
      canonical: 'Maps',
      aliases: <String>['maps', 'google maps', 'मैप्स', 'મેપ્સ'],
    ),
    'messages': (
      canonical: 'Messages',
      aliases: <String>['messages', 'sms app', 'मैसेज', 'મેસેજ'],
    ),
    'phone': (
      canonical: 'Phone',
      aliases: <String>['phone', 'dialer', 'फोन', 'ફોન'],
    ),
    'gmail': (
      canonical: 'Gmail',
      aliases: <String>['gmail', 'email', 'जीमेल', 'જીમેલ'],
    ),
    'spotify': (
      canonical: 'Spotify',
      aliases: <String>['spotify', 'स्पॉटिफाई', 'સ્પોટિફાય'],
    ),
    'instagram': (
      canonical: 'Instagram',
      aliases: <String>['instagram', 'insta', 'इंस्टाग्राम', 'ઇન્સ્ટાગ્રામ'],
    ),
    'telegram': (
      canonical: 'Telegram',
      aliases: <String>['telegram', 'टेलीग्राम', 'ટેલિગ્રામ'],
    ),
    'play store': (
      canonical: 'Play Store',
      aliases: <String>['play store', 'playstore', 'प्ले स्टोर', 'પ્લે સ્ટોર'],
    ),
    'files': (
      canonical: 'Files',
      aliases: <String>['files', 'file manager', 'फाइल', 'ફાઇલ્સ'],
    ),
    'settings': (
      canonical: 'Settings',
      aliases: <String>['settings', 'सेटिंग्स', 'સેટિંગ્સ'],
    ),
  };

  static const Map<String, String> _settingsSections = <String, String>{
    'wifi': 'wifi',
    'wi-fi': 'wifi',
    'वाईफाई': 'wifi',
    'વાઇફાઇ': 'wifi',
    'bluetooth': 'bluetooth',
    'ब्लूटूथ': 'bluetooth',
    'બ્લુટુથ': 'bluetooth',
    'sound': 'sound',
    'ringtone': 'sound',
    'audio': 'sound',
    'साउंड': 'sound',
    'અવાજ': 'sound',
    'display': 'display',
    'brightness': 'display',
    'screen': 'display',
    'डिस्प्ले': 'display',
    'ડિસ્પ્લે': 'display',
    'battery': 'battery',
    'बैटरी': 'battery',
    'બેટરી': 'battery',
    'location': 'location',
    'gps': 'location',
    'लोकेशन': 'location',
    'લોકેશન': 'location',
    'notification_listener': 'notification_listener',
    'notification access': 'notification_listener',
    'notifications': 'notifications',
    'notification': 'notifications',
    'नोटिफिकेशन': 'notifications',
    'નોટિફિકેશન': 'notifications',
    'apps': 'apps',
    'applications': 'apps',
    'storage': 'storage',
    'security': 'security',
    'privacy': 'privacy',
    'accessibility': 'accessibility',
    'network': 'network',
    'internet': 'network',
    'mobile data': 'network',
    'default assistant': 'default_assistant',
    'assistant settings': 'default_assistant',
    'battery optimization': 'battery_optimization',
    'exact alarm': 'exact_alarm',
    'date': 'date',
    'time': 'date',
  };

  static const Set<String> _dayTomorrowTokens = <String>{
    'tomorrow',
    'kal',
    'कल',
    'આવતીકાલે',
    'કાલે',
  };

  static const Set<String> _morningTokens = <String>{
    'am',
    'morning',
    'subah',
    'savare',
    'savaare',
    'सुबह',
    'સવારે',
  };

  static const Set<String> _eveningNightTokens = <String>{
    'pm',
    'afternoon',
    'evening',
    'night',
    'dopahar',
    'bapore',
    'shaam',
    'sham',
    'sanje',
    'raat',
    'ratre',
    'दोपहर',
    'शाम',
    'रात',
    'બપોરે',
    'સાંજે',
    'રાત્રે',
  };

  /// Extracts ordinal contact index ("first" -> 0, "second" -> 1, "third" -> 2).
  static int? extractOrdinalIndex(String canonical) {
    if (RegExp(r'\b(first|1st|pahla|pehla|pehle|pelo)\b|पहला|पहले|પહેલો|પહેલા')
        .hasMatch(canonical)) {
      return 0;
    }
    if (RegExp(r'\b(second|2nd|dusra|doosra|bijo|bijjo)\b|दूसरा|બીજો|બીજા')
        .hasMatch(canonical)) {
      return 1;
    }
    if (RegExp(r'\b(third|3rd|tisra|teesra|trijo)\b|तीसरा|ત્રીજો')
        .hasMatch(canonical)) {
      return 2;
    }
    return null;
  }

  /// Extracts a phone number literal if present in [raw].
  static String extractPhoneNumber(String raw) {
    final match = RegExp(r'(\+?\d[\d\s\-()]{5,18}\d)').firstMatch(raw);
    if (match == null) return '';
    return match.group(1)!.replaceAll(RegExp(r'[\s\-()]'), '');
  }

  /// Extracts a clean contact name or falls back to conversation context.
  static ({String contact, int? ordinalIndex, bool usedContext}) extractContact(
    NormalizedCommand cmd,
    ConversationIntelligenceContext context,
  ) {
    final ordinal = extractOrdinalIndex(cmd.canonicalText);
    final raw = cmd.cleanedText;

    // Ordinal phrasing like "call the first number of Tisha" / "dial 2nd number for Tisha"
    final ofMatch = RegExp(
      r'\b(?:number|no\.?)\s+(?:of|for|ka|ki|no)\s+([a-zA-Z\u0900-\u097F\u0A80-\u0AFF][a-zA-Z0-9\s\u0900-\u097F\u0A80-\u0AFF\._-]{0,40})',
      caseSensitive: false,
    ).firstMatch(raw);
    if (ofMatch != null) {
      final candidate = _cleanContactName(ofMatch.group(1)!);
      if (candidate.isNotEmpty) {
        return (
          contact: candidate,
          ordinalIndex: ordinal ?? 0,
          usedContext: false,
        );
      }
    }

    // Pronoun follow-up ("call him", "message her", "usko phone kar", "tene call kar")
    if (RegExp(
      r'\b(him|her|them|usko|unhe|tene|ene)\b|उसको|उसे|તેને|એને',
      caseSensitive: false,
    ).hasMatch(cmd.canonicalText)) {
      final prior = context.lastContactName ?? context.lastPhoneNumber ?? '';
      if (prior.isNotEmpty) {
        return (contact: prior, ordinalIndex: ordinal, usedContext: true);
      }
    }

    // Hinglish / Gujlish / Hindi / Gujarati postposition pattern: "<Name> ne/ko/no call/phone/number/msg ..."
    final postpositionMatch = RegExp(
      r'^(.+?)\s+(?:ne|ko|no|ka|ki|ke|ane|અને|ને|કો|નો|को|का)\s+(?:call|phone|ring|dial|msg|message|whatsapp|sms|number|કૉલ|કોલ|ફોન|મેસેજ|નંબર|कॉल|फोन|मैसेज|मेसेज|नंबर)(?=\s|$)',
      caseSensitive: false,
    ).firstMatch(raw);
    if (postpositionMatch != null) {
      final candidate = _cleanContactName(postpositionMatch.group(1)!);
      if (candidate.isNotEmpty) {
        return (contact: candidate, ordinalIndex: ordinal, usedContext: false);
      }
    }

    // English & prefix pattern: "call/dial/find/lookup/search contact(s) <Name>"
    final prefixMatch = RegExp(
      r'(?:call|phone|dial|ring|find\s+contacts?|lookup\s+contacts?|look\s+up\s+contacts?|search\s+contacts?|contacts?\s+search|find|lookup|look\s+up|કોલ\s*કરો?|ફોન\s*કરો?|कॉल\s*करो?|फोन\s*करो?)\s+(?:for\s+|to\s+|my\s+)?(.+?)(?:\s+(?:please|plz|pls|kar|karo|laga|lagao|કરો|કર|લગાવો|लगाओ|करो|बोलो))?$',
      caseSensitive: false,
    ).firstMatch(raw);
    if (prefixMatch != null) {
      var candidate = prefixMatch.group(1) ?? '';
      candidate = candidate
          .replaceAll(
            RegExp(
              r'\b(?:the|first|1st|second|2nd|third|3rd|number|no|contact|number of|for)\b',
              caseSensitive: false,
            ),
            ' ',
          )
          .trim();
      candidate = _cleanContactName(candidate);
      if (candidate.isNotEmpty) {
        return (contact: candidate, ordinalIndex: ordinal, usedContext: false);
      }
    }

    return (contact: '', ordinalIndex: ordinal, usedContext: false);
  }

  /// Extracts structured alarm hour/minute/tomorrow across EN/HI/GU/Hinglish/Gujlish.
  static ExtractedAlarmTime? extractAlarmTime(NormalizedCommand cmd) {
    final canonical = cmd.canonicalText;
    final tokens = cmd.tokens;

    final isTomorrow =
        tokens.any(_dayTomorrowTokens.contains) ||
        RegExp(r'कल|આવતીકાલે|કાલે').hasMatch(cmd.cleanedText);
    final hasMorning =
        tokens.any(_morningTokens.contains) ||
        RegExp(r'सुबह|સવારે').hasMatch(cmd.cleanedText);
    final hasEveningNight =
        tokens.any(_eveningNightTokens.contains) ||
        RegExp(r'दोपहर|शाम|रात|બપોરે|સાંજે|રાત્રે').hasMatch(cmd.cleanedText);

    // Pattern 0: Relative offset ("set an alarm in 15 minutes", "alarm after 1 hour")
    final relativeOffset = RegExp(
      r'\b(?:in|after|baad|pachi)\s+([a-z0-9\u0900-\u097F\u0A80-\u0AFF]+)\s*(hours?|hrs?|hr|minutes?|mins?|min)\b',
      caseSensitive: false,
    ).firstMatch(canonical);
    if (relativeOffset != null) {
      final amount = CommandNormalizer.parseNumberToken(
        relativeOffset.group(1)!,
      );
      final unit = relativeOffset.group(2)!.toLowerCase();
      if (amount != null && amount > 0) {
        final targetTime = DateTime.now().add(
          unit.startsWith('h')
              ? Duration(hours: amount)
              : Duration(minutes: amount),
        );
        return ExtractedAlarmTime(
          hour: targetTime.hour,
          minute: targetTime.minute,
          isTomorrow: false,
          isRelativeDayMentioned: false,
        );
      }
    }

    int? hour;
    var minute = 0;

    // Pattern 1: HH:MM (optional am/pm) or "7 30"
    final hhmm = RegExp(
      r'\b(\d{1,2})\s*[:.]\s*(\d{2})\s*(am|pm|a\.m\.|p\.m\.)?\b',
      caseSensitive: false,
    ).firstMatch(canonical);
    if (hhmm != null) {
      hour = int.tryParse(hhmm.group(1)!);
      minute = int.tryParse(hhmm.group(2)!) ?? 0;
      final meridiem = hhmm.group(3)?.replaceAll('.', '').toLowerCase();
      if (hour != null) {
        hour = _applyMeridiem(hour, meridiem, hasMorning, hasEveningNight);
      }
    }

    // Pattern 2: "half past 6" / "quarter past 6" / "quarter to 7"
    if (hour == null) {
      final halfPast = RegExp(
        r'\b(half|quarter)\s+past\s+([a-z0-9\u0900-\u097F\u0A80-\u0AFF]+)\b',
        caseSensitive: false,
      ).firstMatch(canonical);
      if (halfPast != null) {
        final baseHour = CommandNormalizer.parseNumberToken(halfPast.group(2)!);
        if (baseHour != null) {
          hour = _applyMeridiem(baseHour, null, hasMorning, hasEveningNight);
          minute = halfPast.group(1)!.toLowerCase() == 'half' ? 30 : 15;
        }
      }
    }

    // Pattern 3: Digit + optional am/pm/o'clock/baje/vage
    if (hour == null) {
      final simpleDigit = RegExp(
        r'\b(\d{1,2})(?:\s*(am|pm|a\.m\.|p\.m\.|oclock|o\s*clock|vage|baje|बजे|वागे|વાગે|વાગ્યે))?\b',
        caseSensitive: false,
      ).firstMatch(canonical);
      if (simpleDigit != null) {
        final candidateHour = int.tryParse(simpleDigit.group(1)!);
        if (candidateHour != null &&
            candidateHour >= 0 &&
            candidateHour <= 23) {
          final meridiem = simpleDigit
              .group(2)
              ?.replaceAll('.', '')
              .toLowerCase();
          hour = _applyMeridiem(
            candidateHour,
            meridiem == 'am' || meridiem == 'pm' ? meridiem : null,
            hasMorning,
            hasEveningNight,
          );
        }
      }
    }

    // Pattern 4: Spoken number words ("seven", "saat", "સાત", "सात")
    if (hour == null) {
      for (var i = 0; i < tokens.length; i++) {
        final numVal = CommandNormalizer.parseNumberToken(tokens[i]);
        if (numVal != null && numVal >= 1 && numVal <= 23) {
          // Check next token for minutes ("seven thirty", "saat tis")
          if (i + 1 < tokens.length) {
            final minVal = CommandNormalizer.parseNumberToken(tokens[i + 1]);
            if (minVal != null &&
                minVal >= 10 &&
                minVal <= 59 &&
                !tokens[i + 1].contains('vage') &&
                !tokens[i + 1].contains('baje')) {
              minute = minVal;
            }
          }
          hour = _applyMeridiem(numVal, null, hasMorning, hasEveningNight);
          break;
        }
      }
    }

    if (hour == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return null;
    }

    // Support pre-label phrasing such as "Set an alarm for 6:30 PM called Workout"
    final labelMatch = RegExp(
      r'\b(?:called|labeled|named|label)\s+([a-zA-Z0-9\s\u0900-\u097F\u0A80-\u0AFF]{2,30})$',
      caseSensitive: false,
    ).firstMatch(cmd.cleanedText);

    final labelText = labelMatch?.group(1)?.trim();
    final safeLabel =
        (labelText != null &&
            !_dayTomorrowTokens.contains(labelText.toLowerCase()) &&
            !_morningTokens.contains(labelText.toLowerCase()) &&
            !_eveningNightTokens.contains(labelText.toLowerCase()))
        ? labelText
        : (isTomorrow ? 'Tomorrow Alarm' : null);

    return ExtractedAlarmTime(
      hour: hour,
      minute: minute,
      isTomorrow: isTomorrow,
      isRelativeDayMentioned: isTomorrow,
      label: safeLabel,
    );
  }

  /// Extracts timer duration in seconds across digits and spoken number words.
  static int? extractTimerSeconds(NormalizedCommand cmd) {
    final canonical = cmd.canonicalText;

    // Fractional shortcut ("half a minute", "aadha minute")
    if (RegExp(r'\b(half\s+(?:a\s+)?minute|aadha\s+minute)\b')
        .hasMatch(canonical)) {
      return 30;
    }
    if (RegExp(r'\b(half\s+(?:an?\s+)?hour)\b').hasMatch(canonical)) {
      return 1800;
    }

    // Numeric or spoken word before hr/min/sec unit
    final unitPattern = RegExp(
      r'([a-z0-9\u0900-\u097F\u0A80-\u0AFF]+)\s*(hours?|hrs?|hr|minutes?|mins?|min|seconds?|secs?|sec|घंटे|घंटा|मिनट|सेकंड|કલાક|મિનિટ|સેકન્ડ)(?=\s|$)',
      caseSensitive: false,
    );

    var totalSeconds = 0;
    for (final match in unitPattern.allMatches(canonical)) {
      final rawAmount = match.group(1)!;
      final unit = match.group(2)!.toLowerCase();
      final amount = CommandNormalizer.parseNumberToken(rawAmount);
      if (amount == null || amount <= 0) continue;

      if (unit.startsWith('h') ||
          unit.contains('घंट') ||
          unit.contains('કલાક')) {
        totalSeconds += amount * 3600;
      } else if (unit.startsWith('m') ||
          unit.contains('मिन') ||
          unit.contains('મિન')) {
        totalSeconds += amount * 60;
      } else {
        totalSeconds += amount;
      }
    }

    return totalSeconds > 0 ? totalSeconds : null;
  }

  /// Resolves application query across aliases & Indic scripts.
  static String extractAppName(NormalizedCommand cmd) {
    final canonical = cmd.canonicalText;
    final cleanedLower = cmd.cleanedText.toLowerCase();

    for (final entry in _appAliases.values) {
      for (final alias in entry.aliases) {
        if (cleanedLower.contains(alias) || canonical.contains(alias)) {
          return entry.canonical;
        }
      }
    }

    // "open my <app>" / "launch <app>" / "<app> khol"
    final suffixMatch = RegExp(
      r'^(.+?)\s+(?:khol|chalu\s+kar|start\s+kar|open\s+kar|ખોલો?|ચાલુ\s*કર|खोलो?|चालू\s*कर)$',
      caseSensitive: false,
    ).firstMatch(canonical);
    if (suffixMatch != null) {
      final candidate = _cleanAppTarget(suffixMatch.group(1)!);
      if (candidate.isNotEmpty) return candidate;
    }

    final prefixMatch = RegExp(
      r'^(?:please\s+)?(?:open|launch|start|run)\s+(?:the\s+|my\s+)?(.+?)(?:\s+app)?$',
      caseSensitive: false,
    ).firstMatch(canonical);
    if (prefixMatch != null) {
      final candidate = _cleanAppTarget(prefixMatch.group(1)!);
      if (candidate.isNotEmpty) return candidate;
    }

    return '';
  }

  /// Resolves Android system settings section.
  static String extractSettingsSection(NormalizedCommand cmd) {
    final lower = cmd.cleanedText.toLowerCase();
    final canonical = cmd.canonicalText;
    for (final entry in _settingsSections.entries) {
      if (canonical.contains(entry.key) || lower.contains(entry.key)) {
        return entry.value;
      }
    }
    return 'main';
  }

  /// Extracts WhatsApp/SMS recipient and optional message body.
  static ({String recipient, String message, bool usedContext})
  extractMessageTargets(
    NormalizedCommand cmd,
    ConversationIntelligenceContext context,
  ) {
    final raw = cmd.cleanedText;

    // Pattern A: Hinglish / Hindi / Gujarati "<Name> ne/ko whatsapp/message kar [ki/ke/કે/saying] <msg>"
    final hinglish = RegExp(
      r'^(.+?)\s+(?:ne|ko|ને|કો|को)\s+(?:whatsapp|message|msg|sms|व्हाट्सएप|વૉટ્સએપ|વોટ્સએપ|ટેક્સ્ટ|મેસેજ|मैसेज)\s+(?:kar|karo|bhej|bhejo|moklo|કરો?|करो?|भेजो?)?\s*(?:(?:ki|ke|that|saying|कि|કે)\s+)?(.*)$',
      caseSensitive: false,
    ).firstMatch(raw);
    if (hinglish != null) {
      var recipient = _cleanContactName(hinglish.group(1)!);
      var usedContext = false;
      if (RegExp(
        r'^(?:usko|tene|him|her)$',
        caseSensitive: false,
      ).hasMatch(recipient)) {
        recipient = context.lastContactName ?? context.lastPhoneNumber ?? '';
        usedContext = recipient.isNotEmpty;
      }
      return (
        recipient: recipient,
        message: hinglish.group(2)!.trim(),
        usedContext: usedContext,
      );
    }

    // Pattern B: "WhatsApp/message/sms [message] [to] <recipient> saying/that/: <msg>"
    final explicitSplit = RegExp(
      r'(?:send\s+(?:a\s+)?(?:whatsapp|sms|text|message)(?:\s+message)?|(?:whatsapp|wa|sms|text|message|msg)(?:\s+message)?)\s+(?:to\s+)?(.+?)\s+(?:saying|that|:|message\s+that|bol\s+ke|kaho|લખો)\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(raw);
    if (explicitSplit != null) {
      var recipient = _cleanContactName(explicitSplit.group(1)!);
      var usedContext = false;
      if (RegExp(
        r'^(?:him|her|them|usko|tene|ene)$',
        caseSensitive: false,
      ).hasMatch(recipient)) {
        final prior = context.lastContactName ?? context.lastPhoneNumber ?? '';
        if (prior.isNotEmpty) {
          recipient = prior;
          usedContext = true;
        }
      }
      final msg = explicitSplit.group(2)!.trim();
      return (recipient: recipient, message: msg, usedContext: usedContext);
    }

    // Pattern C: "[now] WhatsApp/message <recipient>" with no body
    final recipientOnly = RegExp(
      r'(?:now\s+|then\s+)?(?:send\s+(?:a\s+)?(?:whatsapp|sms|text|message)\s+(?:to\s+)?|(?:whatsapp|sms|text|message|msg)\s+(?:to\s+)?)([a-zA-Z0-9\+\u0900-\u097F\u0A80-\u0AFF][a-zA-Z0-9\+\s\u0900-\u097F\u0A80-\u0AFF_-]{0,35})[\.\?!\s]*$',
      caseSensitive: false,
    ).firstMatch(raw);
    if (recipientOnly != null) {
      final candidate = recipientOnly.group(1)!.trim();
      if (RegExp(
        r'^(?:him|her|them|usko|tene)$',
        caseSensitive: false,
      ).hasMatch(candidate)) {
        return (
          recipient: context.lastContactName ?? context.lastPhoneNumber ?? '',
          message: '',
          usedContext:
              (context.lastContactName ?? context.lastPhoneNumber ?? '')
                  .isNotEmpty,
        );
      }
      if (!RegExp(
        r'^(?:on\s+whatsapp|by\s+sms|app)$',
        caseSensitive: false,
      ).hasMatch(candidate)) {
        return (
          recipient: _cleanContactName(candidate),
          message: '',
          usedContext: false,
        );
      }
    }

    return (recipient: '', message: '', usedContext: false);
  }

  /// Extracts search query, URL, or navigation destination.
  static String extractTrailingPayload(String raw, RegExp pattern) {
    final match = pattern.firstMatch(raw);
    if (match == null || match.groupCount < 1) return '';
    return match.group(1)?.trim() ?? '';
  }

  static int _applyMeridiem(
    int hour,
    String? meridiem,
    bool hasMorning,
    bool hasEveningNight,
  ) {
    if (meridiem == 'pm' && hour < 12) return hour + 12;
    if (meridiem == 'am' && hour == 12) return 0;
    if (meridiem == null) {
      if (hasEveningNight && hour >= 1 && hour < 12) return hour + 12;
      if (hasMorning && hour == 12) return 0;
    }
    return hour;
  }

  static String _cleanContactName(String raw) {
    return raw
        .replaceAll(
          RegExp(r'^(?:to|my|contact|number|for|the)\s+', caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'[\.\?!,]+$'), '')
        .trim();
  }

  static String _cleanAppTarget(String raw) {
    return raw
        .replaceAll(RegExp(r'^(?:my|the|app)\s+', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+app$', caseSensitive: false), '')
        .trim();
  }
}
