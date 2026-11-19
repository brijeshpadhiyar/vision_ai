import 'package:vision_ai/features/settings/domain/entities/voice_language.dart';

/// Lightweight on-device language detector for English, Hindi, and Gujarati
/// (including Devanagari, Gujarati Unicode scripts, and common Hinglish/Gujlish cues).
abstract final class LanguageDetector {
  static final RegExp _devanagariRe = RegExp(r'[\u0900-\u097F]');
  static final RegExp _gujaratiRe = RegExp(r'[\u0A80-\u0AFF]');

  static const Set<String> _gujlishMarkers = <String>{
    'kem',
    'cho',
    'che',
    'chhe',
    'mane',
    'tame',
    'tamne',
    'su',
    'shu',
    'karo',
    'karjo',
    'boljo',
    'kholo',
    'lagavo',
    'moko',
    'aavjo',
    'aabhar',
    'gujarati',
  };

  static const Set<String> _hinglishMarkers = <String>{
    'namaste',
    'kya',
    'kaise',
    'kaisa',
    'kaisi',
    'mujhe',
    'mera',
    'meri',
    'batao',
    'bataiye',
    'kijiye',
    'hai',
    'hain',
    'nahi',
    'nahin',
    'karna',
    'kholna',
    'lagao',
    'bhejo',
    'shukriya',
    'dhanyawad',
    'hindi',
  };

  /// Detects the dominant language of [text] across English, Hindi, and Gujarati.
  static VoiceLanguage detect(
    String text, {
    VoiceLanguage fallback = VoiceLanguage.english,
  }) {
    final safeFallback = fallback == VoiceLanguage.auto
        ? VoiceLanguage.english
        : fallback;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return safeFallback;

    final gujaratiCount = _gujaratiRe.allMatches(trimmed).length;
    final hindiCount = _devanagariRe.allMatches(trimmed).length;

    if (gujaratiCount > 0 && gujaratiCount >= hindiCount) {
      return VoiceLanguage.gujarati;
    }
    if (hindiCount > 0) {
      return VoiceLanguage.hindi;
    }

    final words = trimmed
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList(growable: false);
    if (words.isEmpty) return safeFallback;

    var guScore = 0;
    var hiScore = 0;
    for (final word in words) {
      if (_gujlishMarkers.contains(word)) guScore++;
      if (_hinglishMarkers.contains(word)) hiScore++;
    }

    if (guScore >= 2 && guScore > hiScore) {
      return VoiceLanguage.gujarati;
    }
    if (hiScore >= 2 && hiScore >= guScore) {
      return VoiceLanguage.hindi;
    }
    return safeFallback;
  }

  /// Resolves the best concrete TTS language (`en-IN`, `hi-IN`, `gu-IN`) for [replyText].
  ///
  /// Even when a manual language is selected, native Devanagari or Gujarati script
  /// in the reply automatically switches TTS locale so Android TTS pronounces it properly.
  static VoiceLanguage resolveTtsLanguage(
    String replyText, {
    required VoiceLanguage configuredLanguage,
  }) {
    final gujaratiCount = _gujaratiRe.allMatches(replyText).length;
    final hindiCount = _devanagariRe.allMatches(replyText).length;

    if (gujaratiCount >= 3 && gujaratiCount >= hindiCount) {
      return VoiceLanguage.gujarati;
    }
    if (hindiCount >= 3) {
      return VoiceLanguage.hindi;
    }

    if (configuredLanguage == VoiceLanguage.auto) {
      return detect(replyText, fallback: VoiceLanguage.english);
    }
    return configuredLanguage;
  }
}
