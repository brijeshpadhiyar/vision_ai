/// Prompt complexity tier used by intelligent routing & prompt depth selection.
enum TaskComplexityTier {
  simpleFast('Simple / Quick Q&A'),
  balancedMultilingual('Conversational / Multilingual'),
  deepReasoningCoding('Deep Reasoning / Coding');

  const TaskComplexityTier(this.label);

  final String label;
}

/// Multilingual task classifier separating quick factual/action follow-ups
/// from multi-step analytical, coding, architecture, or comparison queries.
abstract final class TaskComplexityClassifier {
  static final RegExp _codingOrDeepMarkers = RegExp(
    r'(```|stack\s*trace|exception:|error\s+at|traceback|\b(?:code|debug|refactor|architecture|algorithm|benchmark|trade-?off|compare|contrast|analyze|analyse|design\s+pattern|unit\s+test|kotlin|flutter|dart|python|typescript|sql|database\s+schema|explain\s+in\s+detail|step\s+by\s+step)\b|\b(?:samjhao|vishleshan|tulna|farak)\b|समझाओ|विश्लेषण|तुलना|ફરક|વિશ્લેષણ|સમજાવો)',
    caseSensitive: false,
  );

  static final RegExp _simpleGreetingOrShortQuery = RegExp(
    r'^(?:hi|hello|hey|thanks|thank\s+you|good\s+(?:morning|afternoon|evening|night)|namaste|kem\s+cho|what\s+time\s+is\s+it|who\s+are\s+you)\b',
    caseSensitive: false,
  );

  /// Classifies [prompt] into [TaskComplexityTier] cleanly in O(n) locally.
  static TaskComplexityTier classify(String prompt) {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty) return TaskComplexityTier.simpleFast;

    if (trimmed.length > 260 || _codingOrDeepMarkers.hasMatch(trimmed)) {
      return TaskComplexityTier.deepReasoningCoding;
    }

    if (trimmed.length <= 70 && _simpleGreetingOrShortQuery.hasMatch(trimmed)) {
      return TaskComplexityTier.simpleFast;
    }

    final hasNonLatinOrHinglish =
        RegExp(r'[\u0900-\u097F\u0A80-\u0AFF]').hasMatch(trimmed) ||
        RegExp(
          r'\b(?:kya|kaise|kyu|kab|kaha|kem|shu|chhe|batao|batav|karo|samjho)\b',
          caseSensitive: false,
        ).hasMatch(trimmed);
    if (hasNonLatinOrHinglish || trimmed.length > 90) {
      return TaskComplexityTier.balancedMultilingual;
    }

    return TaskComplexityTier.simpleFast;
  }
}
