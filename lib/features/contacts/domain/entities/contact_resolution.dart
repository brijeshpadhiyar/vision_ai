import 'package:material_ui/material_ui.dart';
import 'package:vision_ai/features/automation/domain/entities/device_action.dart';

/// Calibrated confidence policy tiers for resolved device contacts.
enum ContactConfidenceBand {
  /// >= 0.88: unambiguous match (exact / alias / high phonetic certainty).
  high,

  /// 0.68 .. 0.87: likely phonetic match -> confirm `"Did you mean <Name>?"`.
  medium,

  /// < 0.68: unreliable match -> ask user to repeat or pick manually.
  low,

  /// Multiple top candidates within ambiguity margin or multi-number contact.
  ambiguous,

  /// Zero contacts or permission unavailable.
  none,
}

/// Explainable candidate score produced by [ContactConfidenceScorer].
@immutable
class ContactMatchCandidate {
  const ContactMatchCandidate({
    required this.contact,
    required this.score,
    required this.explainableSignals,
    required this.matchedReason,
    this.fromSavedAlias = false,
    this.matchedHypothesis = '',
  });

  final ContactMatch contact;
  final double score;
  final Map<String, double> explainableSignals;
  final String matchedReason;
  final bool fromSavedAlias;
  final String matchedHypothesis;
}

/// Final outcome returned by [ContactResolver].
@immutable
class ContactResolutionResult {
  const ContactResolutionResult({
    required this.confidenceBand,
    required this.spokenQuery,
    required this.promptMessage,
    required this.latencyMs,
    this.bestCandidate,
    this.candidates = const <ContactMatchCandidate>[],
    this.suggestSaveAlias = false,
  });

  final ContactConfidenceBand confidenceBand;
  final String spokenQuery;
  final String promptMessage;
  final int latencyMs;
  final ContactMatchCandidate? bestCandidate;
  final List<ContactMatchCandidate> candidates;
  final bool suggestSaveAlias;
}
