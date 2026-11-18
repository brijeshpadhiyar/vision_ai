import 'package:vision_ai/core/intelligence/phonetics/indic_transliterator.dart';
import 'package:vision_ai/core/intelligence/phonetics/phonetic_algorithms.dart';

/// Normalized multi-script representation of a spoken or stored contact name.
class NormalizedContactName {
  const NormalizedContactName({
    required this.original,
    required this.normalizedFull,
    required this.romanizedFull,
    required this.tokens,
    required this.consonantSkeleton,
    required this.phoneticForm,
    required this.containsIndicScript,
  });

  final String original;
  final String normalizedFull;
  final String romanizedFull;
  final List<String> tokens;
  final String consonantSkeleton;
  final String phoneticForm;
  final bool containsIndicScript;
}

/// Dedicated normalization processor for contact names and spoken name queries.
///
/// Kept separate from command/global text autocorrect so personal names are
/// never mangled into dictionary words.
abstract final class ContactNormalizationService {
  static const Set<String> _honorifics = <String>{
    'mr',
    'mrs',
    'ms',
    'dr',
    'sir',
    'madam',
    'ji',
    'bhai',
    'ben',
  };

  /// Normalizes [rawName] cleanly into tokens, Indic-transliterated Roman text,
  /// and phonetic representations.
  static NormalizedContactName normalize(
    String rawName, {
    bool stripHonorifics = false,
  }) {
    final trimmed = rawName.trim();
    final hasIndic = IndicTransliterator.containsIndicScript(trimmed);
    final romanized = IndicTransliterator.toRomanizedLatin(trimmed)
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .replaceAll('_', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final normalizedFull = trimmed
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    var rawTokens = romanized.isEmpty
        ? const <String>[]
        : romanized.split(' ').where((t) => t.isNotEmpty).toList();

    if (stripHonorifics && rawTokens.length > 1) {
      rawTokens = rawTokens
          .where((t) => !_honorifics.contains(t))
          .toList(growable: false);
    }

    final joinedRoman = rawTokens.join(' ');
    return NormalizedContactName(
      original: rawName,
      normalizedFull: normalizedFull,
      romanizedFull: joinedRoman,
      tokens: rawTokens,
      consonantSkeleton: PhoneticAlgorithms.indicRomanConsonantSkeleton(
        joinedRoman,
      ),
      phoneticForm: PhoneticAlgorithms.indicPhoneticForm(joinedRoman),
      containsIndicScript: hasIndic,
    );
  }
}
