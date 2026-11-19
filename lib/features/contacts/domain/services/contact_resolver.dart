import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vision_ai/core/telemetry/performance_telemetry.dart';
import 'package:vision_ai/features/automation/domain/entities/device_action.dart';
import 'package:vision_ai/features/contacts/data/repositories/contact_alias_repository.dart';
import 'package:vision_ai/features/contacts/data/repositories/contact_search_repository.dart';
import 'package:vision_ai/features/contacts/domain/entities/contact_resolution.dart';
import 'package:vision_ai/features/contacts/domain/services/contact_confidence_scorer.dart';

final contactResolverProvider = Provider<ContactResolver>((ref) {
  final searchRepo = ref.watch(contactSearchRepositoryProvider);
  final aliasRepo = ref.watch(contactAliasRepositoryProvider);
  final telemetry = ref.read(telemetryProvider.notifier);
  return ContactResolver(
    searchRepository: searchRepo,
    aliasRepository: aliasRepo,
    telemetry: telemetry,
  );
});

/// Orchestrates intelligent, explainable, privacy-safe contact resolution across
/// exact matches, multilingual phonetic variation, alternative ASR hypotheses,
/// ordinal selection, and user-confirmed voice aliases.
class ContactResolver {
  const ContactResolver({
    required this.searchRepository,
    required this.aliasRepository,
    this.telemetry,
  });

  final ContactSearchRepository searchRepository;
  final ContactAliasRepository aliasRepository;
  final TelemetryNotifier? telemetry;

  /// Resolves [primaryQuery] and any [alternativeQueries] against real Android
  /// contacts with optional [ordinalIndex] and supporting context.
  Future<ContactResolutionResult> resolve({
    required String primaryQuery,
    List<String> alternativeQueries = const <String>[],
    int? ordinalIndex,
    String? recentSelectedContactId,
    String? conversationContextContactName,
  }) async {
    final sw = Stopwatch()..start();
    final trimmed = primaryQuery.trim();

    if (trimmed.isEmpty) {
      sw.stop();
      return ContactResolutionResult(
        confidenceBand: ContactConfidenceBand.low,
        spokenQuery: primaryQuery,
        promptMessage: 'Who would you like to contact?',
        latencyMs: sw.elapsedMilliseconds,
      );
    }

    // Load real Android Contacts via SearchRepository (prefer full list for phonetic scoring;
    // merge direct lookup results in case test stubs override lookupContacts only).
    final allSaved = await searchRepository.loadAllSavedContacts();
    final directMatches = await searchRepository.queryDirectContacts(trimmed);
    final combined = <String, ContactMatch>{};
    for (final c in <ContactMatch>[...allSaved, ...directMatches]) {
      combined['${c.contactId}:${c.name}:${c.phoneNumber}'] = c;
    }
    final contacts = combined.values.toList(growable: false);

    if (contacts.isEmpty) {
      sw.stop();
      telemetry?.recordContactResolution(sw.elapsedMilliseconds);
      return ContactResolutionResult(
        confidenceBand: ContactConfidenceBand.none,
        spokenQuery: trimmed,
        promptMessage: 'No contact found matching "$trimmed".',
        latencyMs: sw.elapsedMilliseconds,
      );
    }

    final queries = <String>{
      trimmed,
      ...alternativeQueries,
    }.map((q) => q.trim()).where((q) => q.isNotEmpty).toList(growable: false);

    final aliasMatches = aliasRepository.resolveAliasForQuery(
      trimmed,
      contacts,
      alternativeQueries: alternativeQueries,
    );
    final aliasContactIds = aliasMatches
        .map((c) => c.contactId)
        .where((id) => id.isNotEmpty)
        .toSet();

    final ranked = ContactConfidenceScorer.rankCandidates(
      spokenQueries: queries,
      contacts: contacts,
      confirmedAliasContactIds: aliasContactIds,
      recentSelectedContactId: recentSelectedContactId,
      conversationContextContactName: conversationContextContactName,
    );

    if (ranked.isEmpty) {
      sw.stop();
      telemetry?.recordContactResolution(sw.elapsedMilliseconds);
      return ContactResolutionResult(
        confidenceBand: ContactConfidenceBand.low,
        spokenQuery: trimmed,
        promptMessage:
            'Could not find a confident match for "$trimmed". Please repeat or select a contact.',
        latencyMs: sw.elapsedMilliseconds,
      );
    }

    // Handle explicit ordinal selection ("first number of Tisha", "second number")
    // when multiple numbers share high confidence for the top contact name.
    if (ordinalIndex != null) {
      final viableCandidates = ranked
          .where(
            (c) => c.score >= ContactConfidenceScorer.mediumConfidenceThreshold,
          )
          .toList(growable: false);
      if (ordinalIndex >= 0 && ordinalIndex < viableCandidates.length) {
        final chosen = viableCandidates[ordinalIndex];
        sw.stop();
        telemetry?.recordContactResolution(sw.elapsedMilliseconds);
        return ContactResolutionResult(
          confidenceBand:
              chosen.score >= ContactConfidenceScorer.highConfidenceThreshold
              ? ContactConfidenceBand.high
              : ContactConfidenceBand.medium,
          spokenQuery: trimmed,
          promptMessage:
              chosen.score >= ContactConfidenceScorer.highConfidenceThreshold
              ? 'Resolved ${chosen.contact.name} (${chosen.contact.phoneNumber}).'
              : 'Did you mean ${chosen.contact.name}?',
          latencyMs: sw.elapsedMilliseconds,
          bestCandidate: chosen,
          candidates: viableCandidates,
          suggestSaveAlias:
              !chosen.fromSavedAlias &&
              chosen.score < ContactConfidenceScorer.highConfidenceThreshold,
        );
      }
    }

    final best = ranked.first;

    // Check for ambiguous multiple contacts or multiple phone numbers for same person.
    final competing = ranked
        .where(
          (c) =>
              c.score >= ContactConfidenceScorer.mediumConfidenceThreshold &&
              (best.score - c.score) <= ContactConfidenceScorer.ambiguityMargin,
        )
        .toList(growable: false);

    if (competing.length > 1) {
      sw.stop();
      telemetry?.recordContactResolution(sw.elapsedMilliseconds);
      return ContactResolutionResult(
        confidenceBand: ContactConfidenceBand.ambiguous,
        spokenQuery: trimmed,
        promptMessage:
            'Multiple contacts matched "$trimmed". Select one to proceed.',
        latencyMs: sw.elapsedMilliseconds,
        bestCandidate: best,
        candidates: competing.take(5).toList(growable: false),
      );
    }

    if (best.score >= ContactConfidenceScorer.highConfidenceThreshold) {
      sw.stop();
      telemetry?.recordContactResolution(sw.elapsedMilliseconds);
      return ContactResolutionResult(
        confidenceBand: ContactConfidenceBand.high,
        spokenQuery: trimmed,
        promptMessage:
            'Matched ${best.contact.name} (${best.contact.phoneNumber}).',
        latencyMs: sw.elapsedMilliseconds,
        bestCandidate: best,
        candidates: ranked.take(3).toList(growable: false),
      );
    }

    if (best.score >= ContactConfidenceScorer.mediumConfidenceThreshold) {
      sw.stop();
      telemetry?.recordContactResolution(sw.elapsedMilliseconds);
      return ContactResolutionResult(
        confidenceBand: ContactConfidenceBand.medium,
        spokenQuery: trimmed,
        promptMessage: 'Did you mean ${best.contact.name}?',
        latencyMs: sw.elapsedMilliseconds,
        bestCandidate: best,
        candidates: ranked.take(3).toList(growable: false),
        suggestSaveAlias: !best.fromSavedAlias,
      );
    }

    sw.stop();
    telemetry?.recordContactResolution(sw.elapsedMilliseconds);
    return ContactResolutionResult(
      confidenceBand: ContactConfidenceBand.low,
      spokenQuery: trimmed,
      promptMessage:
          'I could not find "$trimmed" with certainty. Please repeat the name or pick a contact.',
      latencyMs: sw.elapsedMilliseconds,
      bestCandidate: best,
      candidates: ranked.take(3).toList(growable: false),
    );
  }
}
