import 'package:vision_ai/features/automation/domain/entities/device_action.dart';

/// Decision on whether a classified utterance should run locally,
/// request clarification, require user confirmation, or escalate to an AI model.
enum ConfidenceDisposition {
  executeLocally,
  requestConfirmation,
  askClarification,
  delegateToAi,
}

/// Evaluates intent classification score and parameter completeness.
abstract final class ConfidenceManager {
  static const double localExecuteThreshold = 0.72;
  static const double clarifyThreshold = 0.55;

  /// Evaluates [confidence] and missing-slot metadata to select execution path.
  static ConfidenceDisposition evaluate({
    required double confidence,
    required DeviceActionRequest? request,
    required String? clarificationPrompt,
  }) {
    if (clarificationPrompt != null && clarificationPrompt.isNotEmpty) {
      return ConfidenceDisposition.askClarification;
    }
    if (request == null || confidence < clarifyThreshold) {
      return ConfidenceDisposition.delegateToAi;
    }
    if (confidence >= localExecuteThreshold) {
      return request.requiresConfirmation
          ? ConfidenceDisposition.requestConfirmation
          : ConfidenceDisposition.executeLocally;
    }
    return ConfidenceDisposition.delegateToAi;
  }

  /// Validates required parameters for any candidate [DeviceActionRequest].
  static String? validateRequiredParameters(DeviceActionRequest request) {
    switch (request.type) {
      case DeviceActionType.callPhone:
      case DeviceActionType.lookupContacts:
        if (request.target.trim().isEmpty) {
          return 'Who would you like me to look up or call?';
        }
        return null;
      case DeviceActionType.setAlarm:
        if (request.hour == null || request.hour! < 0 || request.hour! > 23) {
          return 'What time would you like me to set the alarm for?';
        }
        return null;
      case DeviceActionType.setTimer:
        if (request.durationSeconds == null || request.durationSeconds! <= 0) {
          return 'How long should the timer run?';
        }
        return null;
      case DeviceActionType.launchApp:
        if (request.target.trim().isEmpty) {
          return 'Which app would you like me to open?';
        }
        return null;
      case DeviceActionType.sendSms:
        if (request.target.trim().isEmpty) {
          return 'Who should I send the SMS to?';
        }
        return null;
      case DeviceActionType.openUrl:
      case DeviceActionType.webSearch:
      case DeviceActionType.navigateTo:
        if (request.target.trim().isEmpty) {
          return 'Please specify a destination, query, or URL.';
        }
        return null;
      case DeviceActionType.openSettings:
      case DeviceActionType.sendWhatsapp:
      case DeviceActionType.readNotifications:
      case DeviceActionType.toggleFlashlight:
      case DeviceActionType.setRingerMode:
      case DeviceActionType.adjustVolume:
      case DeviceActionType.deviceStatus:
      case DeviceActionType.dismissAlarm:
      case DeviceActionType.dismissTimer:
      case DeviceActionType.stopSpeaking:
      case DeviceActionType.repeatLast:
      case DeviceActionType.cancelAction:
        return null;
    }
  }
}
