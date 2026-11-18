import 'package:material_ui/material_ui.dart';

/// Lifecycle phases of the VISION voice and wake-word engine.
enum VoiceListeningPhase {
  idle,
  requestingPermission,
  listeningCommand,
  listeningWakeWord,
  processingAi,
  speaking,
  error,
}

/// Sealed event hierarchy emitted by the native Android voice EventChannel.
sealed class VoiceEvent {
  const VoiceEvent();

  /// Parses a raw platform map into a strongly-typed [VoiceEvent] using Dart 3 pattern matching.
  factory VoiceEvent.fromMap(Map<Object?, Object?> raw) {
    return switch (raw) {
      {
        'type': 'state',
        'isListening': final bool isListening,
        'isSpeaking': final bool isSpeaking,
      } =>
        VoiceStateChangedEvent(
          isListening: isListening,
          isSpeaking: isSpeaking,
        ),
      {
        'type': 'amplitude',
        'rmsDb': final num rmsDb,
        'normalizedLevel': final num normalizedLevel,
      } =>
        VoiceAmplitudeEvent(
          rmsDb: rmsDb.toDouble(),
          normalizedLevel: normalizedLevel.toDouble().clamp(0.0, 1.0),
        ),
      {
        'type': 'transcript',
        'text': final String text,
        'isFinal': final bool isFinal,
      } =>
        VoiceTranscriptEvent(text: text, isFinal: isFinal),
      {
        'type': 'wakeServiceState',
        'isRunning': final bool isRunning,
        'isMicActive': final bool isMicActive,
      } =>
        VoiceWakeServiceStateEvent(
          isRunning: isRunning,
          isMicActive: isMicActive,
          error: (raw['error'] as String?)?.isNotEmpty == true
              ? raw['error'] as String
              : null,
        ),
      {'type': 'wakeWordTriggered', 'confidence': final num confidence} =>
        VoiceWakeWordTriggeredEvent(confidence: confidence.toDouble()),
      {'type': 'overlayPrompt', 'prompt': final String prompt} =>
        VoiceOverlayPromptEvent(prompt: prompt),
      {
        'type': 'error',
        'code': final String code,
        'message': final String message,
      } =>
        VoiceErrorEvent(code: code, message: message),
      _ => const VoiceErrorEvent(
        code: 'UNKNOWN_EVENT',
        message: 'Unrecognized voice engine event.',
      ),
    };
  }
}

/// Emitted when native STT or TTS state transitions occur.
final class VoiceStateChangedEvent extends VoiceEvent {
  const VoiceStateChangedEvent({
    required this.isListening,
    required this.isSpeaking,
  });

  final bool isListening;
  final bool isSpeaking;
}

/// Emitted with real-time microphone RMS dB and normalized `[0.0, 1.0]` level.
final class VoiceAmplitudeEvent extends VoiceEvent {
  const VoiceAmplitudeEvent({
    required this.rmsDb,
    required this.normalizedLevel,
  });

  final double rmsDb;
  final double normalizedLevel;
}

/// Emitted when partial or final speech recognition transcripts arrive.
final class VoiceTranscriptEvent extends VoiceEvent {
  const VoiceTranscriptEvent({required this.text, required this.isFinal});

  final String text;
  final bool isFinal;
}

/// Emitted when the background foreground wake-word service changes state.
final class VoiceWakeServiceStateEvent extends VoiceEvent {
  const VoiceWakeServiceStateEvent({
    required this.isRunning,
    required this.isMicActive,
    this.error,
  });

  final bool isRunning;
  final bool isMicActive;
  final String? error;
}

/// Emitted when the offline `AudioRecord` engine detects "Hey VISION".
final class VoiceWakeWordTriggeredEvent extends VoiceEvent {
  const VoiceWakeWordTriggeredEvent({required this.confidence});

  final double confidence;
}

/// Emitted when `VoiceInteractionSession` hands off a spoken prompt to Flutter.
final class VoiceOverlayPromptEvent extends VoiceEvent {
  const VoiceOverlayPromptEvent({required this.prompt});

  final String prompt;
}

/// Emitted when the speech recognizer encounters an operational error.
final class VoiceErrorEvent extends VoiceEvent {
  const VoiceErrorEvent({required this.code, required this.message});

  final String code;
  final String message;
}

/// Immutable state representing the active voice and wake-word session.
@immutable
class VoiceSessionState {
  const VoiceSessionState({
    this.phase = VoiceListeningPhase.idle,
    this.liveTranscript = '',
    this.lastReplyText = '',
    this.normalizedAmplitude = 0.0,
    this.hasMicPermission = false,
    this.isListening = false,
    this.isSpeaking = false,
    this.isWakeWordArmed = false,
    this.isWakeServiceRunning = false,
    this.isWakeMicActive = false,
    this.isDefaultAssistant = false,
    this.lastWakeWordDetected,
    this.wakeTriggerSequence = 0,
    this.errorMessage,
  });

  final VoiceListeningPhase phase;
  final String liveTranscript;
  final String lastReplyText;
  final double normalizedAmplitude;
  final bool hasMicPermission;
  final bool isListening;
  final bool isSpeaking;
  final bool isWakeWordArmed;
  final bool isWakeServiceRunning;
  final bool isWakeMicActive;
  final bool isDefaultAssistant;
  final String? lastWakeWordDetected;
  final int wakeTriggerSequence;
  final String? errorMessage;

  /// True only when either STT or the foreground wake-word AudioRecord loop
  /// genuinely holds an active microphone stream.
  bool get isMicActuallyActive =>
      isListening || (isWakeServiceRunning && isWakeMicActive);

  VoiceSessionState copyWith({
    VoiceListeningPhase? phase,
    String? liveTranscript,
    String? lastReplyText,
    double? normalizedAmplitude,
    bool? hasMicPermission,
    bool? isListening,
    bool? isSpeaking,
    bool? isWakeWordArmed,
    bool? isWakeServiceRunning,
    bool? isWakeMicActive,
    bool? isDefaultAssistant,
    String? lastWakeWordDetected,
    int? wakeTriggerSequence,
    String? errorMessage,
    bool clearError = false,
  }) {
    return VoiceSessionState(
      phase: phase ?? this.phase,
      liveTranscript: liveTranscript ?? this.liveTranscript,
      lastReplyText: lastReplyText ?? this.lastReplyText,
      normalizedAmplitude: normalizedAmplitude ?? this.normalizedAmplitude,
      hasMicPermission: hasMicPermission ?? this.hasMicPermission,
      isListening: isListening ?? this.isListening,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      isWakeWordArmed: isWakeWordArmed ?? this.isWakeWordArmed,
      isWakeServiceRunning: isWakeServiceRunning ?? this.isWakeServiceRunning,
      isWakeMicActive: isWakeMicActive ?? this.isWakeMicActive,
      isDefaultAssistant: isDefaultAssistant ?? this.isDefaultAssistant,
      lastWakeWordDetected: lastWakeWordDetected ?? this.lastWakeWordDetected,
      wakeTriggerSequence: wakeTriggerSequence ?? this.wakeTriggerSequence,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
