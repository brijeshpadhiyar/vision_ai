import 'package:vision_ai/core/intelligence/command_normalizer.dart';
import 'package:vision_ai/core/intelligence/command_registry.dart';
import 'package:vision_ai/core/intelligence/confidence_manager.dart';
import 'package:vision_ai/core/intelligence/conversation_context.dart';
import 'package:vision_ai/core/intelligence/intent_classifier.dart';
import 'package:vision_ai/features/automation/domain/entities/device_action.dart';

/// Full resolution result returned by [IntentEngine.analyze].
class IntentResolution {
  const IntentResolution({
    required this.intentId,
    required this.confidence,
    required this.language,
    required this.disposition,
    required this.lifecycleStatus,
    required this.parseTimeMicros,
    this.originalTranscript = '',
    this.alternativeTranscripts = const <String>[],
    this.request,
    this.clarificationPrompt,
    this.descriptor,
    this.steps = const <DeviceActionRequest>[],
  });

  final String intentId;
  final double confidence;
  final DetectedLanguage language;
  final ConfidenceDisposition disposition;
  final CommandLifecycleStatus lifecycleStatus;
  final int parseTimeMicros;
  final String originalTranscript;
  final List<String> alternativeTranscripts;
  final DeviceActionRequest? request;
  final String? clarificationPrompt;
  final CommandDescriptor? descriptor;
  final List<DeviceActionRequest> steps;

  bool get shouldHandleLocally =>
      disposition == ConfidenceDisposition.executeLocally ||
      disposition == ConfidenceDisposition.requestConfirmation;

  bool get needsClarification =>
      disposition == ConfidenceDisposition.askClarification;
}

/// Top-level intent recognition orchestrator for local-first execution.
abstract final class IntentEngine {
  /// Evaluates multiple ASR [hypotheses] in priority order while preserving
  /// the original raw transcript and alternative candidates for contact/entity resolution.
  static IntentResolution analyzeWithHypotheses(
    List<String> hypotheses, {
    ConversationIntelligenceContext context =
        const ConversationIntelligenceContext(),
  }) {
    final cleaned = hypotheses
        .map((h) => h.trim())
        .where((h) => h.isNotEmpty)
        .toList(growable: false);
    if (cleaned.isEmpty) {
      return analyze('', context: context);
    }

    final primary = analyze(cleaned.first, context: context);
    if (primary.shouldHandleLocally || primary.needsClarification) {
      return IntentResolution(
        intentId: primary.intentId,
        confidence: primary.confidence,
        language: primary.language,
        disposition: primary.disposition,
        lifecycleStatus: primary.lifecycleStatus,
        parseTimeMicros: primary.parseTimeMicros,
        originalTranscript: cleaned.first,
        alternativeTranscripts: cleaned,
        request: primary.request,
        clarificationPrompt: primary.clarificationPrompt,
        descriptor: primary.descriptor,
        steps: primary.steps,
      );
    }

    // Check secondary ASR hypotheses for misrecognized command verbs ("tall Tisha" -> "call Tisha")
    for (final alt in cleaned.skip(1)) {
      final candidate = analyze(alt, context: context);
      if (candidate.shouldHandleLocally && candidate.confidence >= 0.85) {
        return IntentResolution(
          intentId: candidate.intentId,
          confidence: candidate.confidence,
          language: candidate.language,
          disposition: candidate.disposition,
          lifecycleStatus: candidate.lifecycleStatus,
          parseTimeMicros: primary.parseTimeMicros + candidate.parseTimeMicros,
          originalTranscript: cleaned.first,
          alternativeTranscripts: cleaned,
          request: candidate.request,
          clarificationPrompt: candidate.clarificationPrompt,
          descriptor: candidate.descriptor,
          steps: candidate.steps,
        );
      }
    }

    return IntentResolution(
      intentId: primary.intentId,
      confidence: primary.confidence,
      language: primary.language,
      disposition: primary.disposition,
      lifecycleStatus: primary.lifecycleStatus,
      parseTimeMicros: primary.parseTimeMicros,
      originalTranscript: cleaned.first,
      alternativeTranscripts: cleaned,
      request: primary.request,
      clarificationPrompt: primary.clarificationPrompt,
      descriptor: primary.descriptor,
      steps: primary.steps,
    );
  }
  /// Evaluates [rawInput] with optional [context], handling single or multi-step
  /// local commands without calling external AI providers.
  static IntentResolution analyze(
    String rawInput, {
    ConversationIntelligenceContext context =
        const ConversationIntelligenceContext(),
  }) {
    final stopwatch = Stopwatch()..start();
    final normalized = CommandNormalizer.normalize(rawInput);

    // Handle confirmation reply when an action is awaiting explicit user confirmation.
    if (context.pendingAction != null &&
        _isConfirmationReply(normalized.canonicalText)) {
      stopwatch.stop();
      final confirmed = DeviceActionRequest(
        type: context.pendingAction!.type,
        displaySummary: context.pendingAction!.displaySummary,
        target: context.pendingAction!.target,
        hour: context.pendingAction!.hour,
        minute: context.pendingAction!.minute,
        durationSeconds: context.pendingAction!.durationSeconds,
        label: context.pendingAction!.label,
        message: context.pendingAction!.message,
        enabled: context.pendingAction!.enabled,
        requiresConfirmation: false,
        contactOrdinalIndex: context.pendingAction!.contactOrdinalIndex,
        isTomorrow: context.pendingAction!.isTomorrow,
        followUpActions: context.pendingAction!.followUpActions,
      );
      return IntentResolution(
        intentId: 'confirm_pending',
        confidence: 0.99,
        language: normalized.language,
        disposition: ConfidenceDisposition.executeLocally,
        lifecycleStatus: CommandLifecycleStatus.validated,
        parseTimeMicros: stopwatch.elapsedMicroseconds,
        request: confirmed,
        descriptor: CommandRegistry.descriptorFor(confirmed.type),
        steps: <DeviceActionRequest>[confirmed, ...confirmed.followUpActions],
      );
    }

    // Sequential multi-clause parsing ("Open WhatsApp and find Tisha")
    if (normalized.clauses.length > 1) {
      final parsedSteps = <DeviceActionRequest>[];
      var totalConfidence = 0.0;
      for (final clause in normalized.clauses) {
        final clauseNorm = CommandNormalizer.normalize(clause);
        final stepResult = IntentClassifier.classifyClause(clauseNorm, context);
        if (stepResult.request != null &&
            stepResult.confidence >= ConfidenceManager.localExecuteThreshold) {
          parsedSteps.add(stepResult.request!);
          totalConfidence += stepResult.confidence;
        }
      }

      if (parsedSteps.length >= 2) {
        stopwatch.stop();
        final primary = parsedSteps.first;
        final combined = DeviceActionRequest(
          type: primary.type,
          displaySummary: parsedSteps
              .map((step) => step.displaySummary)
              .join(' -> '),
          target: primary.target,
          hour: primary.hour,
          minute: primary.minute,
          durationSeconds: primary.durationSeconds,
          label: primary.label,
          message: primary.message,
          enabled: primary.enabled,
          requiresConfirmation: parsedSteps.any(
            (step) => step.requiresConfirmation,
          ),
          contactOrdinalIndex: primary.contactOrdinalIndex,
          isTomorrow: primary.isTomorrow,
          followUpActions: parsedSteps.skip(1).toList(growable: false),
        );
        final avgConfidence = totalConfidence / parsedSteps.length;
        return IntentResolution(
          intentId: 'multi_step',
          confidence: avgConfidence,
          language: normalized.language,
          disposition: combined.requiresConfirmation
              ? ConfidenceDisposition.requestConfirmation
              : ConfidenceDisposition.executeLocally,
          lifecycleStatus: combined.requiresConfirmation
              ? CommandLifecycleStatus.confirmationRequired
              : CommandLifecycleStatus.validated,
          parseTimeMicros: stopwatch.elapsedMicroseconds,
          originalTranscript: rawInput,
          request: combined,
          descriptor: CommandRegistry.descriptorFor(combined.type),
          steps: parsedSteps,
        );
      }
    }

    final classification = IntentClassifier.classifyClause(normalized, context);
    var clarification = classification.clarificationPrompt;
    final descriptor = classification.request != null
        ? CommandRegistry.descriptorFor(classification.request!.type)
        : null;

    if (clarification == null &&
        classification.request != null &&
        descriptor != null) {
      clarification = descriptor.validate(classification.request!);
    }

    final disposition = ConfidenceManager.evaluate(
      confidence: classification.confidence,
      request: classification.request,
      clarificationPrompt: clarification,
    );

    final lifecycle = switch (disposition) {
      ConfidenceDisposition.askClarification =>
        CommandLifecycleStatus.understood,
      ConfidenceDisposition.requestConfirmation =>
        CommandLifecycleStatus.confirmationRequired,
      ConfidenceDisposition.executeLocally => CommandLifecycleStatus.validated,
      ConfidenceDisposition.delegateToAi => CommandLifecycleStatus.received,
    };

    stopwatch.stop();
    return IntentResolution(
      intentId: classification.intentId,
      confidence: classification.confidence,
      language: normalized.language,
      disposition: disposition,
      lifecycleStatus: lifecycle,
      parseTimeMicros: stopwatch.elapsedMicroseconds,
      originalTranscript: rawInput,
      request: classification.request,
      clarificationPrompt: clarification,
      descriptor: descriptor,
      steps: classification.request != null
          ? <DeviceActionRequest>[classification.request!]
          : const <DeviceActionRequest>[],
    );
  }

  static bool _isConfirmationReply(String canonical) {
    return RegExp(
      r'^(?:yes(?:\s*,?\s+.+)?|yeah|yep|confirm|ok(?:\s+confirm)?|okay|do\s+it|proceed|go\s+ahead|haa|haan|ha|kar|karde|karo|theek\s+hai|બરાબર|હા|हाँ|ठीक\s*है)$',
      caseSensitive: false,
    ).hasMatch(canonical);
  }
}
