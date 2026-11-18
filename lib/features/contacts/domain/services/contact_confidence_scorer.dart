import 'dart:math' as math;

import 'package:vision_ai/features/automation/domain/entities/device_action.dart';
import 'package:vision_ai/features/contacts/domain/entities/contact_resolution.dart';
import 'package:vision_ai/features/contacts/domain/services/contact_normalization_service.dart';
import 'package:vision_ai/features/contacts/domain/services/contact_phonetic_matcher.dart';

/// Combines measurable lexical, phonetic, token-order, alias, alternative-ASR,
/// recency, and conversational context signals into explainable contact scores.
///
/// Never invents arbitrary AI-generated confidence scores.
abstract final class ContactConfidenceScorer {
  static const double highConfidenceThreshold = 0.88;
  static const double mediumConfidenceThreshold = 0.68;
  static const double ambiguityMargin = 0.06;

  /// Scores [contacts] across [spokenQueries] (primary transcript + any
  /// alternative ASR hypotheses), plus user-confirmed alias matches and optional
  /// supporting context.
  static List<ContactMatchCandidate> rankCandidates({
    required List<String> spokenQueries,
    required List<ContactMatch> contacts,
    Set<String> confirmedAliasContactIds = const <String>{},
    String? recentSelectedContactId,
    String? conversationContextContactName,
  }) {
    if (spokenQueries.isEmpty || contacts.isEmpty) {
      return const <ContactMatchCandidate>[];
    }

    final normalizedQueries = spokenQueries
        .map(
          (q) =>
              ContactNormalizationService.normalize(q, stripHonorifics: true),
        )
        .where((n) => n.romanizedFull.isNotEmpty)
        .toList(growable: false);

    if (normalizedQueries.isEmpty) return const <ContactMatchCandidate>[];

    final normContext = conversationContextContactName != null
        ? ContactNormalizationService.normalize(conversationContextContactName)
              .romanizedFull
        : '';

    final scored = <ContactMatchCandidate>[];

    for (final contact in contacts) {
      final normContact = ContactNormalizationService.normalize(contact.name);
      final isConfirmedAlias =
          confirmedAliasContactIds.contains(contact.contactId) &&
          contact.contactId.isNotEmpty;

      var bestScore = 0.0;
      var bestSignals = const <String, double>{};
      var bestReason = '';
      var bestHypothesis = normalizedQueries.first.original;

      for (var hIdx = 0; hIdx < normalizedQueries.length; hIdx++) {
        final normQuery = normalizedQueries[hIdx];
        final scores = ContactPhoneticMatcher.scorePair(normQuery, normContact);

        // Hypothesis weighting: primary (1.0), alternates slightly tapered
        final hypPenalty = hIdx == 0
            ? 1.0
            : math.max(0.90, 1.0 - (hIdx * 0.03));

        double rawScore;
        String reason;

        if (isConfirmedAlias) {
          rawScore = 0.97;
          reason = 'Confirmed personal voice alias';
        } else if (scores.exactMatch >= 1.0) {
          rawScore = 1.0;
          reason = 'Exact contact name match';
        } else if (scores.partialTokenMatch >= 0.90) {
          rawScore = 0.91;
          reason = 'Exact first/partial name match';
        } else {
          // Weighted measurable fusion: phonetic likeness + token order + prefix/edit
          rawScore =
              (scores.wordOrderInvariantScore * 0.40) +
              (scores.phoneticSimilarity * 0.35) +
              (scores.jaroWinklerSimilarity * 0.15) +
              (scores.damerauSimilarity * 0.10);

          if (scores.partialTokenMatch > 0) {
            rawScore = math.max(rawScore, scores.partialTokenMatch * 0.86);
          }

          reason = rawScore >= highConfidenceThreshold
              ? 'Strong spelling & phonetic match'
              : rawScore >= mediumConfidenceThreshold
              ? 'Phonetic similarity match'
              : 'Weak similarity';
        }

        // Bounded supporting context boost ONLY when base phonetic likeness is meaningful.
        if (!isConfirmedAlias && rawScore >= 0.58) {
          if (recentSelectedContactId != null &&
              recentSelectedContactId.isNotEmpty &&
              recentSelectedContactId == contact.contactId) {
            rawScore = math.min(0.99, rawScore + 0.04);
          }
          if (normContext.isNotEmpty &&
              normContact.romanizedFull == normContext) {
            rawScore = math.min(0.99, rawScore + 0.05);
          }
        }

        final weighted = (rawScore * hypPenalty).clamp(0.0, 1.0);
        if (weighted > bestScore) {
          bestScore = weighted;
          bestReason = reason;
          bestHypothesis = normQuery.original;
          bestSignals = <String, double>{
            'exact': scores.exactMatch,
            'partial': scores.partialTokenMatch,
            'damerau': scores.damerauSimilarity,
            'jaroWinkler': scores.jaroWinklerSimilarity,
            'phonetic': scores.phoneticSimilarity,
            'tokenOrder': scores.wordOrderInvariantScore,
            'alias': isConfirmedAlias ? 1.0 : 0.0,
          };
        }
      }

      if (bestScore >= 0.40) {
        scored.add(
          ContactMatchCandidate(
            contact: contact,
            score: bestScore,
            explainableSignals: bestSignals,
            matchedReason: bestReason,
            fromSavedAlias: isConfirmedAlias,
            matchedHypothesis: bestHypothesis,
          ),
        );
      }
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored;
  }
}
