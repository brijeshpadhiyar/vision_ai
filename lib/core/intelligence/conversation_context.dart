import 'package:material_ui/material_ui.dart';
import 'package:vision_ai/features/automation/domain/entities/device_action.dart';

/// Holds recent multi-turn assistant state so follow-up commands
/// ("repeat that", "yes confirm", "message her hello", "cancel")
/// can resolve deterministically without unnecessary LLM round-trips.
@immutable
class ConversationIntelligenceContext {
  const ConversationIntelligenceContext({
    this.lastIntentId,
    this.lastContactName,
    this.lastPhoneNumber,
    this.lastAppName,
    this.lastSpokenReply,
    this.pendingAction,
    this.pendingClarificationIntentId,
    this.pendingClarificationPrompt,
    this.activeTaskLabel,
  });

  final String? lastIntentId;
  final String? lastContactName;
  final String? lastPhoneNumber;
  final String? lastAppName;
  final String? lastSpokenReply;
  final DeviceActionRequest? pendingAction;
  final String? pendingClarificationIntentId;
  final String? pendingClarificationPrompt;
  final String? activeTaskLabel;

  ConversationIntelligenceContext copyWith({
    String? lastIntentId,
    String? lastContactName,
    String? lastPhoneNumber,
    String? lastAppName,
    String? lastSpokenReply,
    DeviceActionRequest? pendingAction,
    bool clearPendingAction = false,
    String? pendingClarificationIntentId,
    String? pendingClarificationPrompt,
    bool clearClarification = false,
    String? activeTaskLabel,
  }) {
    return ConversationIntelligenceContext(
      lastIntentId: lastIntentId ?? this.lastIntentId,
      lastContactName: lastContactName ?? this.lastContactName,
      lastPhoneNumber: lastPhoneNumber ?? this.lastPhoneNumber,
      lastAppName: lastAppName ?? this.lastAppName,
      lastSpokenReply: lastSpokenReply ?? this.lastSpokenReply,
      pendingAction: clearPendingAction
          ? null
          : (pendingAction ?? this.pendingAction),
      pendingClarificationIntentId: clearClarification
          ? null
          : (pendingClarificationIntentId ?? this.pendingClarificationIntentId),
      pendingClarificationPrompt: clearClarification
          ? null
          : (pendingClarificationPrompt ?? this.pendingClarificationPrompt),
      activeTaskLabel: activeTaskLabel ?? this.activeTaskLabel,
    );
  }
}
