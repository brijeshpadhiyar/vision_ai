import 'package:vision_ai/features/settings/domain/entities/voice_language.dart';
import 'package:vision_ai/features/voice/domain/entities/voice_session_state.dart';

/// Domain contract for interacting with the native speech recognition, TTS,
/// foreground wake-word service, and Android Assistant Role engine.
abstract interface class VoiceRepository {
  /// Stream of real-time [VoiceEvent] updates from the platform engine.
  Stream<VoiceEvent> watchVoiceEvents();

  /// Checks whether `RECORD_AUDIO` permission is currently granted.
  Future<bool> checkMicrophonePermission();

  /// Requests `RECORD_AUDIO` permission from the user at runtime.
  Future<bool> requestMicrophonePermission();

  /// Checks whether speech recognition services are available on the device.
  Future<bool> isSpeechRecognitionAvailable();

  /// Starts speech recognition using the BCP-47 locale tag of [language]
  /// and configurable pause/endpointing duration [endpointSilenceMs].
  Future<void> startListening({
    required VoiceLanguage language,
    int endpointSilenceMs = 3800,
  });

  /// Stops active speech recognition and requests final transcript resolution.
  Future<void> stopListening();

  /// Cancels active speech recognition immediately.
  Future<void> cancelListening();

  /// Synthesizes [text] aloud in the given [language].
  Future<bool> speak({
    required String text,
    required VoiceLanguage language,
    double speechRate = 1.0,
  });

  /// Stops any active TTS playback.
  Future<void> stopSpeaking();

  /// Starts the foreground microphone wake-word service ("Hey VISION").
  Future<bool> startWakeWordService({double sensitivity = 0.55});

  /// Stops the foreground microphone wake-word service.
  Future<void> stopWakeWordService();

  /// Updates the wake-word detector sensitivity threshold (`0.2` - `0.9`).
  Future<void> setWakeWordSensitivity(double sensitivity);

  /// Queries live status (`isRunning`, `isMicActive`) of the wake-word service.
  Future<({bool isRunning, bool isMicActive})> getWakeWordServiceStatus();

  /// Checks whether VISION holds Android's `ROLE_ASSISTANT`.
  Future<bool> isDefaultAssistant();

  /// Prompts the user to set VISION as Android's default digital assistant.
  Future<bool> requestAssistantRole();

  /// Opens VISION's Gemini-like translucent assistant overlay sheet.
  Future<void> openAssistantOverlay();

  /// Consumes any spoken prompt handed off by `VoiceInteractionSession`.
  Future<String?> consumeOverlayPrompt();

  /// Consumes any spoken prompt and alternative ASR hypotheses handed off by `VoiceInteractionSession`.
  Future<({String prompt, List<String> hypotheses})?> consumeOverlayPayload();
}
