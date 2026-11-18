import 'dart:math' as math;

import 'package:vision_ai/core/intelligence/phonetics/phonetic_algorithms.dart';
import 'package:vision_ai/features/contacts/domain/services/contact_normalization_service.dart';

/// Explainable sub-scores emitted when comparing a spoken query to a contact.
class PhoneticMatchScores {
  const PhoneticMatchScores({
    required this.exactMatch,
    required this.partialTokenMatch,
    required this.damerauSimilarity,
    required this.jaroWinklerSimilarity,
    required this.phoneticSimilarity,
    required this.wordOrderInvariantScore,
  });

  final double exactMatch;
  final double partialTokenMatch;
  final double damerauSimilarity;
  final double jaroWinklerSimilarity;
  final double phoneticSimilarity;
  final double wordOrderInvariantScore;
}

/// Evaluates phonetic, edit-distance, and token-order similarities between
/// spoken names (including Indian-English & Indic pronunciation variations)
/// and saved Android Contacts.
abstract final class ContactPhoneticMatcher {
  /// Compares normalized [query] against normalized [contact].
  static PhoneticMatchScores scorePair(
    NormalizedContactName query,
    NormalizedContactName contact,
  ) {
    final qFull = query.romanizedFull;
    final cFull = contact.romanizedFull;

    if (qFull.isEmpty || cFull.isEmpty) {
      return const PhoneticMatchScores(
        exactMatch: 0,
        partialTokenMatch: 0,
        damerauSimilarity: 0,
        jaroWinklerSimilarity: 0,
        phoneticSimilarity: 0,
        wordOrderInvariantScore: 0,
      );
    }

    // 1. Exact full & exact partial name checks
    final exact =
        (query.normalizedFull == contact.normalizedFull || qFull == cFull)
        ? 1.0
        : 0.0;

    var partial = 0.0;
    if (cFull.startsWith(qFull) || contact.tokens.any((t) => t == qFull)) {
      partial = 0.92;
    } else if (cFull.contains(qFull) && qFull.length >= 3) {
      partial = 0.78;
    }

    // 2. Full-string Damerau-Levenshtein & Jaro-Winkler
    final damerauFull = PhoneticAlgorithms.damerauLevenshteinSimilarity(
      qFull,
      cFull,
    );
    final jaroFull = PhoneticAlgorithms.jaroWinklerSimilarity(qFull, cFull);

    // 3. Phonetic representation similarity (Indic consonant skeleton + phonetic form)
    final skelSim = PhoneticAlgorithms.jaroWinklerSimilarity(
      query.consonantSkeleton,
      contact.consonantSkeleton,
    );
    final skelEdit = PhoneticAlgorithms.damerauLevenshteinSimilarity(
      query.consonantSkeleton,
      contact.consonantSkeleton,
    );
    final formSim = PhoneticAlgorithms.damerauLevenshteinSimilarity(
      query.phoneticForm,
      contact.phoneticForm,
    );

    var engMetaSim = 0.0;
    if (!query.containsIndicScript && !contact.containsIndicScript) {
      engMetaSim = PhoneticAlgorithms.damerauLevenshteinSimilarity(
        PhoneticAlgorithms.englishPhoneticCode(qFull),
        PhoneticAlgorithms.englishPhoneticCode(cFull),
      );
    }

    final fullPhonetic = math.max(
      (skelSim * 0.45 + skelEdit * 0.30 + formSim * 0.25),
      engMetaSim * 0.85,
    );

    // 4. Token-by-token & word-order-invariant best pairing ("Shohil Jht" <-> "Soel Kht",
    //    or reversed "Kht Soel" <-> "Shohil Jht")
    final tokenPairScore = _computeWordOrderInvariantTokenScore(
      query.tokens,
      contact.tokens,
    );

    return PhoneticMatchScores(
      exactMatch: exact,
      partialTokenMatch: partial,
      damerauSimilarity: damerauFull,
      jaroWinklerSimilarity: jaroFull,
      phoneticSimilarity: math.max(fullPhonetic, tokenPairScore.phoneticAvg),
      wordOrderInvariantScore: tokenPairScore.combinedAvg,
    );
  }

  static ({double phoneticAvg, double combinedAvg})
  _computeWordOrderInvariantTokenScore(
    List<String> qTokens,
    List<String> cTokens,
  ) {
    if (qTokens.isEmpty || cTokens.isEmpty) {
      return (phoneticAvg: 0.0, combinedAvg: 0.0);
    }

    final usedContactIndices = <int>{};
    var phoneticSum = 0.0;
    var combinedSum = 0.0;

    for (final qTok in qTokens) {
      var bestCombined = 0.0;
      var bestPhonetic = 0.0;
      var bestIdx = -1;

      final qSkel = PhoneticAlgorithms.indicRomanConsonantSkeleton(qTok);
      final qForm = PhoneticAlgorithms.indicPhoneticForm(qTok);

      for (var i = 0; i < cTokens.length; i++) {
        if (usedContactIndices.contains(i)) continue;
        final cTok = cTokens[i];
        final cSkel = PhoneticAlgorithms.indicRomanConsonantSkeleton(cTok);
        final cForm = PhoneticAlgorithms.indicPhoneticForm(cTok);

        final rawDamerau = PhoneticAlgorithms.damerauLevenshteinSimilarity(
          qTok,
          cTok,
        );
        final rawJaro = PhoneticAlgorithms.jaroWinklerSimilarity(qTok, cTok);
        final skelJaro = PhoneticAlgorithms.jaroWinklerSimilarity(qSkel, cSkel);
        final skelDamerau = PhoneticAlgorithms.damerauLevenshteinSimilarity(
          qSkel,
          cSkel,
        );
        final formDamerau = PhoneticAlgorithms.damerauLevenshteinSimilarity(
          qForm,
          cForm,
        );

        final tokPhonetic = (qSkel.isNotEmpty && qSkel == cSkel)
            ? math.max(0.88, (skelDamerau * 0.5 + formDamerau * 0.5))
            : (skelJaro * 0.40 + skelDamerau * 0.35 + formDamerau * 0.25);

        final tokCombined = (qTok == cTok)
            ? 1.0
            : (tokPhonetic * 0.55 + rawJaro * 0.25 + rawDamerau * 0.20);

        if (tokCombined > bestCombined) {
          bestCombined = tokCombined;
          bestPhonetic = tokPhonetic;
          bestIdx = i;
        }
      }

      if (bestIdx != -1) {
        usedContactIndices.add(bestIdx);
      }
      phoneticSum += bestPhonetic;
      combinedSum += bestCombined;
    }

    final denom = math.max(qTokens.length, 1);
    return (
      phoneticAvg: (phoneticSum / denom).clamp(0.0, 1.0),
      combinedAvg: (combinedSum / denom).clamp(0.0, 1.0),
    );
  }
}
