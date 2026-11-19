import 'package:flutter/foundation.dart';
import 'package:vision_ai/core/constants/app_constants.dart';

/// User-selectable personality preset for VISION AI (Module 01).
enum AssistantPersonality {
  balanced(
    id: 'balanced',
    displayName: 'Balanced',
    promptGuidance: 'Be calm, helpful, sharp, and natural.',
  ),
  professional(
    id: 'professional',
    displayName: 'Professional',
    promptGuidance: 'Use a polished, objective, executive tone with crisp precision.',
  ),
  friendly(
    id: 'friendly',
    displayName: 'Friendly',
    promptGuidance: 'Use a warm, approachable, conversational tone while staying helpful.',
  ),
  concise(
    id: 'concise',
    displayName: 'Concise',
    promptGuidance: 'Be ultra-brief and straight to the point with minimal filler.',
  );

  const AssistantPersonality({
    required this.id,
    required this.displayName,
    required this.promptGuidance,
  });

  final String id;
  final String displayName;
  final String promptGuidance;

  static AssistantPersonality fromId(String? id) {
    for (final value in AssistantPersonality.values) {
      if (value.id == id) return value;
    }
    return AssistantPersonality.balanced;
  }
}

/// Preferred response formatting and verbosity style (Module 01).
enum CommunicationStyle {
  conversational(
    id: 'conversational',
    displayName: 'Conversational',
    promptGuidance: 'Prefer natural spoken phrasing suitable for voice-first playback.',
  ),
  direct(
    id: 'direct',
    displayName: 'Direct & Brief',
    promptGuidance: 'Answer in 1-2 short sentences unless asked for detail.',
  ),
  detailed(
    id: 'detailed',
    displayName: 'Detailed & Structured',
    promptGuidance: 'Provide well-structured explanations with key steps or bullet points.',
  );

  const CommunicationStyle({
    required this.id,
    required this.displayName,
    required this.promptGuidance,
  });

  final String id;
  final String displayName;
  final String promptGuidance;

  static CommunicationStyle fromId(String? id) {
    for (final value in CommunicationStyle.values) {
      if (value.id == id) return value;
    }
    return CommunicationStyle.conversational;
  }
}

/// Customizable Assistant Identity configuration (Module 01).
@immutable
class AssistantIdentity {
  const AssistantIdentity({
    this.personality = AssistantPersonality.balanced,
    this.communicationStyle = CommunicationStyle.conversational,
    this.customGreeting = '',
    this.customInstructions = '',
  });

  final AssistantPersonality personality;
  final CommunicationStyle communicationStyle;
  final String customGreeting;
  final String customInstructions;

  /// Returns the custom greeting if configured, otherwise [AppConstants.homeGreeting].
  String get effectiveGreeting {
    final trimmed = customGreeting.trim();
    return trimmed.isEmpty ? AppConstants.homeGreeting : trimmed;
  }

  /// Formats active identity preferences for injection into the AI system prompt.
  String buildPromptBlock() {
    final buffer = StringBuffer()
      ..writeln('ASSISTANT IDENTITY & STYLE:')
      ..writeln('- Personality (${personality.displayName}): ${personality.promptGuidance}')
      ..writeln('- Communication style (${communicationStyle.displayName}): ${communicationStyle.promptGuidance}');
    final trimmedInstructions = customInstructions.trim();
    if (trimmedInstructions.isNotEmpty) {
      buffer.writeln('- User custom behaviour instructions: $trimmedInstructions');
    }
    return buffer.toString().trim();
  }

  AssistantIdentity copyWith({
    AssistantPersonality? personality,
    CommunicationStyle? communicationStyle,
    String? customGreeting,
    String? customInstructions,
  }) {
    return AssistantIdentity(
      personality: personality ?? this.personality,
      communicationStyle: communicationStyle ?? this.communicationStyle,
      customGreeting: customGreeting ?? this.customGreeting,
      customInstructions: customInstructions ?? this.customInstructions,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AssistantIdentity &&
        other.personality == personality &&
        other.communicationStyle == communicationStyle &&
        other.customGreeting == customGreeting &&
        other.customInstructions == customInstructions;
  }

  @override
  int get hashCode => Object.hash(
    personality,
    communicationStyle,
    customGreeting,
    customInstructions,
  );
}
