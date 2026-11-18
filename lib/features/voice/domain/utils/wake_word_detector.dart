import 'package:material_ui/material_ui.dart';

/// Result of evaluating a speech transcript for a wake-word phrase.
@immutable
class WakeWordMatchResult {
  const WakeWordMatchResult({
    required this.isTriggered,
    this.matchedPhrase,
    this.trailingCommand = '',
  });

  final bool isTriggered;
  final String? matchedPhrase;
  final String trailingCommand;
}

/// Evaluates transcripts for multilingual "Hey VISION" wake-word phrases
/// across English, Hindi, and Gujarati.
abstract final class WakeWordDetector {
  static const List<String> _wakePhrases = <String>[
    'hey vision',
    'hi vision',
    'hello vision',
    'ok vision',
    'okay vision',
    'हे विज़न',
    'हेलो विज़न',
    'हे विजन',
    'हेलो विजन',
    'હે વિઝન',
    'હેલો વિઝન',
    'vision',
    'विज़न',
    'विजन',
    'વિઝન',
  ];

  /// Inspects [transcript] for a leading wake-word phrase and extracts any trailing command.
  static WakeWordMatchResult evaluate(String transcript) {
    final trimmed = transcript.trim();
    if (trimmed.isEmpty) {
      return const WakeWordMatchResult(isTriggered: false);
    }

    final lower = trimmed.toLowerCase();

    for (final phrase in _wakePhrases) {
      final index = lower.indexOf(phrase);
      if (index != -1) {
        final afterIndex = index + phrase.length;
        final rawTrailing = trimmed.substring(afterIndex).trim();
        final cleanedTrailing = rawTrailing.replaceFirst(
          RegExp(r'^[,.:;!\-—\s]+'),
          '',
        );
        return WakeWordMatchResult(
          isTriggered: true,
          matchedPhrase: phrase,
          trailingCommand: cleanedTrailing.trim(),
        );
      }
    }

    return const WakeWordMatchResult(isTriggered: false);
  }
}
