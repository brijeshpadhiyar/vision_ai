/// Detected language/script category for user utterances.
enum DetectedLanguage {
  english('English', 'en'),
  hindi('Hindi', 'hi'),
  gujarati('Gujarati', 'gu'),
  hinglish('Hinglish', 'hi-Latn'),
  gujlish('Gujlish', 'gu-Latn');

  const DetectedLanguage(this.displayName, this.bcp47Tag);

  final String displayName;
  final String bcp47Tag;
}

/// Output of normalizing an utterance without destroying domain meaning.
class NormalizedCommand {
  const NormalizedCommand({
    required this.rawText,
    required this.cleanedText,
    required this.canonicalText,
    required this.tokens,
    required this.language,
    required this.hasIndicDigitsNormalized,
    required this.clauses,
  });

  final String rawText;
  final String cleanedText;
  final String canonicalText;
  final List<String> tokens;
  final DetectedLanguage language;
  final bool hasIndicDigitsNormalized;
  final List<String> clauses;
}

/// Normalizes multilingual commands across English, Hindi, Gujarati,
/// Hinglish, and Gujlish while preserving entity fidelity.
abstract final class CommandNormalizer {
  static const Map<String, String> _spellingFixes = <String, String>{
    'wattsapp': 'whatsapp',
    'watsapp': 'whatsapp',
    'whatsap': 'whatsapp',
    'whatapp': 'whatsapp',
    'whastapp': 'whatsapp',
    'whasapp': 'whatsapp',
    'watsap': 'whatsapp',
    'watsup': 'whatsapp',
    'whatsup': 'whatsapp',
    'whatsaap': 'whatsapp',
    'alram': 'alarm',
    'alrm': 'alarm',
    'alaam': 'alarm',
    'alam': 'alarm',
    'allaam': 'alarm',
    'timmer': 'timer',
    'tmer': 'timer',
    'timar': 'timer',
    'taimer': 'timer',
    'blutooth': 'bluetooth',
    'bluetoth': 'bluetooth',
    'bluethooth': 'bluetooth',
    'seting': 'settings',
    'setings': 'settings',
    'settngs': 'settings',
    'flshlight': 'flashlight',
    'flashlite': 'flashlight',
    'tarch': 'torch',
    'notfication': 'notifications',
    'notfications': 'notifications',
    'notifcation': 'notifications',
    'notifications': 'notifications',
    'calender': 'calendar',
    'calculater': 'calculator',
    'gallary': 'gallery',
    'camra': 'camera',
    'utube': 'youtube',
    'yutube': 'youtube',
    'gmaps': 'maps',
    'vibrat': 'vibrate',
    'silnt': 'silent',
    'volum': 'volume',
    'batry': 'battery',
    'batery': 'battery',
    'mesage': 'message',
    'massege': 'message',
    'contect': 'contact',
    'contects': 'contacts',
    'phne': 'phone',
    'fone': 'phone',
    'foun': 'phone',
    'phon': 'phone',
    'kholna': 'khol',
    'kholo': 'khol',
    'kholje': 'khol',
    'karo': 'kar',
    'karde': 'kar',
    'krde': 'kar',
    'lagana': 'lagao',
    'lagav': 'lagao',
    'lagavo': 'lagao',
    'lagaao': 'lagao',
    'mukjo': 'muk',
    'muko': 'muk',
    'mukje': 'muk',
    'chaluu': 'chalu',
    'baje': 'vage',
    'vaje': 'vage',
    'vaage': 'vage',
    'savare': 'savare',
    'savar': 'savare',
    'savaare': 'savare',
    'subha': 'subah',
    'subah': 'subah',
  };

  /// Multilingual spoken numbers (English, Hindi, Gujarati, Devanagari, Gujarati script).
  static const Map<String, int> numberWords = <String, int>{
    'zero': 0,
    'one': 1,
    'two': 2,
    'three': 3,
    'four': 4,
    'five': 5,
    'six': 6,
    'seven': 7,
    'eight': 8,
    'nine': 9,
    'ten': 10,
    'eleven': 11,
    'twelve': 12,
    'thirteen': 13,
    'fourteen': 14,
    'fifteen': 15,
    'sixteen': 16,
    'seventeen': 17,
    'eighteen': 18,
    'nineteen': 19,
    'twenty': 20,
    'thirty': 30,
    'forty': 40,
    'fortyfive': 45,
    'fifty': 50,
    'sixty': 60,
    // Hindi / Hinglish
    'ek': 1,
    'do': 2,
    'teen': 3,
    'tin': 3,
    'char': 4,
    'chaar': 4,
    'paanch': 5,
    'panch': 5,
    'chhe': 6,
    'che': 6,
    'chhah': 6,
    'saat': 7,
    'sat': 7,
    'aath': 8,
    'aat': 8,
    'nau': 9,
    'das': 10,
    'gyarah': 11,
    'barah': 12,
    'terah': 13,
    'chaudah': 14,
    'pandrah': 15,
    'solah': 16,
    'satrah': 17,
    'atharah': 18,
    'unnis': 19,
    'bees': 20,
    'pachis': 25,
    'tees': 30,
    'chalis': 40,
    'pachas': 50,
    'saath': 60,
    // Gujarati / Gujlish
    'be': 2,
    'tran': 3,
    'chha': 6,
    'nav': 9,
    'agyar': 11,
    'bar': 12,
    'pandar': 15,
    'vis': 20,
    'tris': 30,
    'sath': 60,
    // Devanagari words
    'एक': 1,
    'दो': 2,
    'तीन': 3,
    'चार': 4,
    'पांच': 5,
    'पाँच': 5,
    'छह': 6,
    'सात': 7,
    'आठ': 8,
    'नौ': 9,
    'दस': 10,
    'ग्यारह': 11,
    'बारह': 12,
    'पंद्रह': 15,
    'बीस': 20,
    'तीस': 30,
    'पैंतालीस': 45,
    // Gujarati words
    'એક': 1,
    'બે': 2,
    'ત્રણ': 3,
    'ચાર': 4,
    'પાંચ': 5,
    'છ': 6,
    'સાત': 7,
    'આઠ': 8,
    'નવ': 9,
    'દસ': 10,
    'અગિયાર': 11,
    'બાર': 12,
    'પંદર': 15,
    'વીસ': 20,
    'ત્રીસ': 30,
    'પિસ્તાળીસ': 45,
  };

  static const Set<String> _hinglishMarkers = <String>{
    'ko',
    'ka',
    'ki',
    'ke',
    'kar',
    'lagao',
    'khol',
    'batao',
    'banao',
    'rakho',
    'dikhao',
    'chalu',
    'bandh',
    'band',
    'subah',
    'shaam',
    'raat',
    'kal',
    'aaj',
    'aur',
    'phir',
    'saat',
    'paanch',
    'aath',
    'bolo',
    'chup',
    'rehne',
    'mat',
  };

  static const Set<String> _gujlishMarkers = <String>{
    'ne',
    'ma',
    'thi',
    'muk',
    'muko',
    'vage',
    'savare',
    'sanje',
    'ratre',
    'bapore',
    'ane',
    'pachi',
    'karje',
    'karo',
    'batav',
    'fari',
    'bol',
    'rad',
  };

  static final RegExp _devanagariRange = RegExp(r'[\u0900-\u097F]');
  static final RegExp _gujaratiRange = RegExp(r'[\u0A80-\u0AFF]');
  static final RegExp _zeroWidthChars = RegExp(r'[\u200B-\u200D\uFEFF\u00AD]');
  static final RegExp _curlyDoubleQuotes = RegExp(r'[“”]');
  static final RegExp _curlySingleQuotes = RegExp(r'[\u2018\u2019]');
  static final RegExp _multiSpace = RegExp(r'\s+');
  static final RegExp _trailingEndPunct = RegExp(r'[?!।]+$');
  static final RegExp _tokenEdgePunct = RegExp(r'^[\.,:;]+|[\.,:;]+$');
  static final RegExp _whatsAppSplit = RegExp(
    r"\b(?:what's|whats|what|wats|watts)\s+app\b",
  );
  static final RegExp _youTubeSplit = RegExp(r'\byou\s+tube\b');
  static final RegExp _playStoreSplit = RegExp(r'\bplay\s+store\b');
  static final RegExp _wifiSplit = RegExp(r'\bwi\s+fi\b');
  static final RegExp _bluetoothSplit = RegExp(r'\bblue\s+tooth\b');
  static final RegExp _flashlightSplit = RegExp(r'\bflash\s+light\b');
  static final RegExp _leadingCalVerb = RegExp(
    r'^(?:please\s+)?(?:cal|caal|kall|kol)\s+',
  );
  static final RegExp _indicCalVerb = RegExp(
    r'\b(?:cal|caal|kall|kol)\s+(?:kar|lagao|laga)\b',
  );
  static final RegExp _independentClauseKeywords = RegExp(
    r'(call|cal|kol|dial|phone|fone|ring|alarm|alram|timer|timmer|open|launch|start|close|find|search|lookup|look up|check|send|message|whatsapp|whats\s*app|watsapp|sms|text|flashlight|torch|silent|vibrate|normal|volume|mute|unmute|settings|battery|navigate|directions|route|stop|cancel|repeat|કૉલ|ફોન|અલાર્મ|ટાઇમર|ખોલ|ચાલુ|બંધ|બતાવ|મૂક|कॉल|फोन|अलार्म|टाइमर|खोल|चालू|बंद|बताओ|लगा|khol|kar|muk|lagao|batao)',
  );
  static final RegExp _clauseDelimiter = RegExp(
    r'\s*(?:\band\s+then\b|\band\b|\bthen\b|\baur\b|\bphir\b|\bfir\b|\bpachi\b|\bane\b|\balso\b|;|,|પછી|અને|और|फिर)\s+',
    caseSensitive: false,
  );

  /// Normalizes [input] into script-safe cleaned & canonical forms plus clauses.
  static NormalizedCommand normalize(String input) {
    final unicodeNormalized = _normalizeUnicode(input.trim());
    final normalizedDigits = _replaceIndicDigits(unicodeNormalized);
    final hasIndicDigits = normalizedDigits != unicodeNormalized;

    final cleaned = normalizedDigits
        .replaceAll(_curlyDoubleQuotes, '"')
        .replaceAll(_curlySingleQuotes, "'")
        .replaceAll(_multiSpace, ' ')
        .trim();

    final strippedPunctuation = cleaned
        .replaceAll(_trailingEndPunct, '')
        .trim();

    final rawTokens = strippedPunctuation.isEmpty
        ? const <String>[]
        : strippedPunctuation.split(_multiSpace);

    final fixedTokens = <String>[];
    for (final token in rawTokens) {
      final lower = token.toLowerCase().replaceAll(_tokenEdgePunct, '');
      if (lower.isEmpty) continue;
      fixedTokens.add(_spellingFixes[lower] ?? lower);
    }

    var canonical = fixedTokens.join(' ');
    canonical = _applyCommandPhraseFixes(canonical);
    final finalTokens = canonical.isEmpty
        ? const <String>[]
        : canonical.split(_multiSpace);
    final language = detectLanguage(strippedPunctuation, finalTokens);
    final clauses = splitSequentialClauses(strippedPunctuation);

    return NormalizedCommand(
      rawText: input,
      cleanedText: strippedPunctuation,
      canonicalText: canonical,
      tokens: finalTokens,
      language: language,
      hasIndicDigitsNormalized: hasIndicDigits,
      clauses: clauses,
    );
  }

  /// Strips invisible zero-width formatting codepoints without altering
  /// canonical Hindi/Gujarati orthography (such as candra vowels `ॉ` / `ૉ`) or digits.
  static String _normalizeUnicode(String input) {
    if (input.isEmpty) return input;
    return input.replaceAll(_zeroWidthChars, '');
  }

  /// Fixes ASR word-splits and command-verb typos in canonical command text
  /// without altering raw transcripts or blindly mutating contact names.
  static String _applyCommandPhraseFixes(String canonical) {
    return canonical
        .replaceAll(_whatsAppSplit, 'whatsapp')
        .replaceAll(_youTubeSplit, 'youtube')
        .replaceAll(_playStoreSplit, 'play store')
        .replaceAll(_wifiSplit, 'wifi')
        .replaceAll(_bluetoothSplit, 'bluetooth')
        .replaceAll(_flashlightSplit, 'flashlight')
        .replaceFirst(_leadingCalVerb, 'call ')
        .replaceAll(_indicCalVerb, 'call kar');
  }

  /// Detects language category for telemetry, TTS locale & prompt routing.
  static DetectedLanguage detectLanguage(String text, List<String> tokens) {
    if (_gujaratiRange.hasMatch(text)) return DetectedLanguage.gujarati;
    if (_devanagariRange.hasMatch(text)) return DetectedLanguage.hindi;

    var gujlishHits = 0;
    var hinglishHits = 0;
    for (final token in tokens) {
      if (_gujlishMarkers.contains(token)) gujlishHits++;
      if (_hinglishMarkers.contains(token)) hinglishHits++;
    }
    if (gujlishHits > hinglishHits && gujlishHits > 0) {
      return DetectedLanguage.gujlish;
    }
    if (hinglishHits > 0) {
      return DetectedLanguage.hinglish;
    }
    return DetectedLanguage.english;
  }

  /// Splits sequential multi-step clauses while avoiding false splits inside
  /// message bodies, search queries, or URLs.
  static List<String> splitSequentialClauses(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return const <String>[];

    // Never split single search/message/url payloads if the whole phrase starts
    // with search/message/say/type without another clear action verb after conjunction.
    final parts = trimmed
        .split(_clauseDelimiter)
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.length <= 1) {
      return <String>[trimmed];
    }

    // Only accept splitting when at least two clauses start/contain recognizable action words.
    var actionableCount = 0;
    for (final part in parts) {
      if (_looksLikeIndependentClause(part)) {
        actionableCount++;
      }
    }
    if (actionableCount >= 2) {
      return parts;
    }
    return <String>[trimmed];
  }

  static bool _looksLikeIndependentClause(String clause) {
    return _independentClauseKeywords.hasMatch(clause.toLowerCase());
  }

  /// Replaces Devanagari and Gujarati digits with ASCII equivalents.
  static String _replaceIndicDigits(String input) {
    const devanagari = '०१२३४५६७८९';
    const gujarati = '૦૧૨૩૪૫૬૭૮૯';
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      final char = String.fromCharCode(rune);
      final dIndex = devanagari.indexOf(char);
      if (dIndex >= 0) {
        buffer.write(dIndex);
        continue;
      }
      final gIndex = gujarati.indexOf(char);
      if (gIndex >= 0) {
        buffer.write(gIndex);
        continue;
      }
      buffer.write(char);
    }
    return buffer.toString();
  }

  /// Replaces standalone spoken number words inside numeric/time segments.
  static int? parseNumberToken(String token) {
    final clean = token.trim().toLowerCase();
    final direct = int.tryParse(clean);
    if (direct != null) return direct;
    return numberWords[clean];
  }
}
