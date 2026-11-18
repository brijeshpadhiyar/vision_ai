/// Lightweight bidirectional phonetic transliterator normalizing Devanagari
/// (Hindi) and Gujarati script names/words into Romanized phonetic approximations
/// so cross-script contact and command matching works without AI calls.
abstract final class IndicTransliterator {
  static const Map<int, String> _indicToLatin = <int, String>{
    // Devanagari vowels & matras
    0x0905: 'a', 0x0906: 'a', 0x0907: 'i', 0x0908: 'i', 0x0909: 'u',
    0x090A: 'u', 0x090F: 'e', 0x0910: 'ai', 0x0913: 'o', 0x0914: 'au',
    0x093E: 'a', 0x093F: 'i', 0x0940: 'i', 0x0941: 'u', 0x0942: 'u',
    0x0947: 'e', 0x0948: 'ai', 0x094B: 'o', 0x094C: 'au',
    0x0949: 'o', 0x0911: 'o', 0x0902: 'n', 0x0901: 'n',
    // Devanagari consonants
    0x0915: 'k', 0x0916: 'kh', 0x0917: 'g', 0x0918: 'gh', 0x091A: 'ch',
    0x091B: 'chh', 0x091C: 'j', 0x091D: 'jh', 0x091F: 't', 0x0920: 'th',
    0x0921: 'd', 0x0922: 'dh', 0x0923: 'n', 0x0924: 't', 0x0925: 'th',
    0x0926: 'd', 0x0927: 'dh', 0x0928: 'n', 0x092A: 'p', 0x092B: 'f',
    0x092C: 'b', 0x092D: 'bh', 0x092E: 'm', 0x092F: 'y', 0x0930: 'r',
    0x0932: 'l', 0x0935: 'v', 0x0936: 'sh', 0x0937: 'sh', 0x0938: 's',
    0x0939: 'h',
    // Gujarati vowels & matras
    0x0A85: 'a', 0x0A86: 'a', 0x0A87: 'i', 0x0A88: 'i', 0x0A89: 'u',
    0x0A8A: 'u', 0x0A8F: 'e', 0x0A90: 'ai', 0x0A93: 'o', 0x0A94: 'au',
    0x0ABE: 'a', 0x0ABF: 'i', 0x0AC0: 'i', 0x0AC1: 'u', 0x0AC2: 'u',
    0x0AC7: 'e', 0x0AC8: 'ai', 0x0ACB: 'o', 0x0ACC: 'au',
    0x0AC9: 'o', 0x0A91: 'o', 0x0A82: 'n', 0x0A81: 'n',
    // Gujarati consonants
    0x0A95: 'k', 0x0A96: 'kh', 0x0A97: 'g', 0x0A98: 'gh', 0x0A9A: 'ch',
    0x0A9B: 'chh', 0x0A9C: 'j', 0x0A9D: 'jh', 0x0A9F: 't', 0x0AA0: 'th',
    0x0AA1: 'd', 0x0AA2: 'dh', 0x0AA3: 'n', 0x0AA4: 't', 0x0AA5: 'th',
    0x0AA6: 'd', 0x0AA7: 'dh', 0x0AA8: 'n', 0x0AAA: 'p', 0x0AAB: 'f',
    0x0AAC: 'b', 0x0AAD: 'bh', 0x0AAE: 'm', 0x0AAF: 'y', 0x0AB0: 'r',
    0x0AB2: 'l', 0x0AB5: 'v', 0x0AB6: 'sh', 0x0AB7: 'sh', 0x0AB8: 's',
    0x0AB9: 'h',
  };

  static final RegExp _hasIndicRegex = RegExp(r'[\u0900-\u097F\u0A80-\u0AFF]');

  static bool containsIndicScript(String text) => _hasIndicRegex.hasMatch(text);

  /// Converts Devanagari / Gujarati characters into lowercase Latin approximations
  /// while leaving existing ASCII/spaces intact.
  static String toRomanizedLatin(String input) {
    if (!_hasIndicRegex.hasMatch(input)) {
      return input.toLowerCase();
    }
    final out = StringBuffer();
    for (final rune in input.runes) {
      // Virama / halant suppresses inherent vowel (skip cleanly)
      if (rune == 0x094D ||
          rune == 0x0ACD ||
          rune == 0x093C ||
          rune == 0x0ABC) {
        continue;
      }
      final mapped = _indicToLatin[rune];
      if (mapped != null) {
        out.write(mapped);
      } else {
        out.write(String.fromCharCode(rune).toLowerCase());
      }
    }
    return out.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
