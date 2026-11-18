import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vision_ai/core/errors/app_exception.dart';
import 'package:vision_ai/core/utils/app_logger.dart';
import 'package:vision_ai/features/chat/domain/entities/chat_message.dart';
import 'package:vision_ai/features/chat/presentation/controllers/chat_controller.dart';
import 'package:vision_ai/features/settings/presentation/controllers/settings_controller.dart';
import 'package:vision_ai/features/voice/data/repositories/voice_repository_impl.dart';
import 'package:vision_ai/features/voice/domain/entities/voice_session_state.dart';
import 'package:vision_ai/features/voice/domain/utils/wake_word_detector.dart';

/// Global Riverpod provider for the [VoiceController].
final voiceControllerProvider =
    NotifierProvider<VoiceController, VoiceSessionState>(VoiceController.new);

/// Orchestrates multilingual Speech-to-Text (STT), Text-to-Speech (TTS),
/// offline foreground "Hey VISION" wake-word detection, and Assistant Role state
/// across English (`en-IN`), Hindi (`hi-IN`), and Gujarati (`gu-IN`).
class VoiceController extends Notifier<VoiceSessionState> {
  StreamSubscription<VoiceEvent>? _eventSubscription;

  @override
  VoiceSessionState build() {
    final repository = ref.watch(voiceRepositoryProvider);
    final wakeWordSetting = ref.watch(
      settingsControllerProvider.select((s) => s.wakeWordEnabled),
    );

    unawaited(_subscribeToEvents(repository));

    ref.onDispose(() {
      unawaited(_eventSubscription?.cancel());
    });

    return VoiceSessionState(isWakeWordArmed: wakeWordSetting);
  }

  Future<void> _subscribeToEvents(dynamic repository) async {
    await _eventSubscription?.cancel();
    final voiceRepo = ref.read(voiceRepositoryProvider);
    try {
      _eventSubscription = voiceRepo.watchVoiceEvents().listen(
        _handleVoiceEvent,
        onError: (Object error) {
          // Platform stream may not be active in unit test host environments.
        },
      );
    } on Exception {
      // Safe fallback when running in non-Android test environments.
    }
  }

  void _handleVoiceEvent(VoiceEvent event) {
    switch (event) {
      case VoiceStateChangedEvent(:final isListening, :final isSpeaking):
        final currentPhase = state.phase;
        final nextPhase = isSpeaking
            ? VoiceListeningPhase.speaking
            : isListening
            ? (currentPhase == VoiceListeningPhase.listeningWakeWord
                  ? VoiceListeningPhase.listeningWakeWord
                  : VoiceListeningPhase.listeningCommand)
            : (currentPhase == VoiceListeningPhase.processingAi
                  ? VoiceListeningPhase.processingAi
                  : VoiceListeningPhase.idle);

        state = state.copyWith(
          isListening: isListening,
          isSpeaking: isSpeaking,
          phase: nextPhase,
          normalizedAmplitude: isListening ? state.normalizedAmplitude : 0.0,
        );

      case VoiceAmplitudeEvent(:final normalizedLevel):
        state = state.copyWith(normalizedAmplitude: normalizedLevel);

      case VoiceTranscriptEvent(:final text, :final isFinal):
        state = state.copyWith(liveTranscript: text, clearError: true);
        if (isFinal) {
          unawaited(_processFinalTranscript(text));
        }

      case VoiceWakeServiceStateEvent(
        :final isRunning,
        :final isMicActive,
        :final error,
      ):
        state = state.copyWith(
          isWakeServiceRunning: isRunning,
          isWakeMicActive: isMicActive,
          isWakeWordArmed: isRunning || state.isWakeWordArmed,
          errorMessage: error,
          clearError: error == null,
        );

      case VoiceWakeWordTriggeredEvent():
        ref.read(appLoggerProvider).info('Hardware/DSP wake-word triggered!');
        state = state.copyWith(
          lastWakeWordDetected: 'Hey VISION',
          liveTranscript: 'Hey VISION detected — listening for command...',
          clearError: true,
        );
        unawaited(startCommandListening());

      case VoiceOverlayPromptEvent(:final prompt):
        if (prompt.trim().isNotEmpty) {
          unawaited(_dispatchVoiceCommandToAi(prompt.trim()));
        }

      case VoiceErrorEvent(:final message):
        state = state.copyWith(
          phase: VoiceListeningPhase.error,
          isListening: false,
          normalizedAmplitude: 0.0,
          errorMessage: message,
        );
    }
  }

  Future<void> _processFinalTranscript(String transcript) async {
    final trimmed = transcript.trim();
    if (trimmed.isEmpty) return;

    final logger = ref.read(appLoggerProvider);

    // Check if we were listening in wake-word standby mode.
    if (state.phase == VoiceListeningPhase.listeningWakeWord ||
        state.isWakeWordArmed) {
      final match = WakeWordDetector.evaluate(trimmed);
      if (match.isTriggered) {
        logger.info('Wake word detected: "${match.matchedPhrase}"');
        state = state.copyWith(
          lastWakeWordDetected: match.matchedPhrase,
          clearError: true,
        );

        if (match.trailingCommand.isNotEmpty) {
          await _dispatchVoiceCommandToAi(match.trailingCommand);
        } else {
          // User said "Hey VISION" — immediately listen for their spoken question.
          state = state.copyWith(
            liveTranscript: 'Wake word detected! Listening for your command...',
          );
          await startCommandListening();
        }
        return;
      } else if (state.phase == VoiceListeningPhase.listeningWakeWord) {
        // Ignore non-wake-word ambient speech when strictly in wake-word mode.
        state = state.copyWith(
          phase: VoiceListeningPhase.idle,
          liveTranscript: '',
        );
        return;
      }
    }

    await _dispatchVoiceCommandToAi(trimmed);
  }

  Future<void> _dispatchVoiceCommandToAi(String commandText) async {
    state = state.copyWith(
      phase: VoiceListeningPhase.processingAi,
      liveTranscript: commandText,
      isListening: false,
      normalizedAmplitude: 0.0,
      clearError: true,
    );

    final accepted = await ref
        .read(chatControllerProvider.notifier)
        .sendMessage(commandText);

    final chatState = ref.read(chatControllerProvider);
    if (!accepted || chatState.errorMessage != null) {
      final msg =
          chatState.errorMessage ?? 'Unable to complete voice AI request.';
      state = state.copyWith(
        phase: VoiceListeningPhase.error,
        lastReplyText: msg,
        errorMessage: msg,
      );
      return;
    }

    final latestReply =
        chatState.messages.isNotEmpty &&
            chatState.messages.last.sender == MessageSender.assistant
        ? chatState.messages.last.content
        : '';

    state = state.copyWith(
      phase: VoiceListeningPhase.idle,
      lastReplyText: latestReply,
    );

    final settings = ref.read(settingsControllerProvider);
    if (settings.autoSpeakReplies && latestReply.isNotEmpty) {
      await speakReply(latestReply);
    }
  }

  /// Toggles voice command capture on or off.
  Future<void> toggleVoiceCapture() async {
    final voiceRepo = ref.read(voiceRepositoryProvider);

    if (state.isSpeaking) {
      await voiceRepo.stopSpeaking();
      state = state.copyWith(
        isSpeaking: false,
        phase: VoiceListeningPhase.idle,
      );
      return;
    }

    if (state.isListening) {
      await voiceRepo.stopListening();
      state = state.copyWith(
        isListening: false,
        phase: VoiceListeningPhase.idle,
        normalizedAmplitude: 0.0,
      );
      return;
    }

    await startCommandListening();
  }

  /// Interrupts active TTS speech and immediately opens voice listening again.
  Future<void> interruptAndListen() async {
    if (state.isSpeaking) {
      await stopSpeaking();
    }
    await startCommandListening();
  }

  /// Requests microphone permission if needed and starts active voice command capture.
  Future<void> startCommandListening({bool wakeWordMode = false}) async {
    final voiceRepo = ref.read(voiceRepositoryProvider);
    final settings = ref.read(settingsControllerProvider);
    final logger = ref.read(appLoggerProvider);

    state = state.copyWith(
      phase: VoiceListeningPhase.requestingPermission,
      isListening: false,
      clearError: true,
    );

    var hasPermission = await voiceRepo.checkMicrophonePermission();
    if (!hasPermission) {
      hasPermission = await voiceRepo.requestMicrophonePermission();
    }

    if (!hasPermission) {
      state = state.copyWith(
        hasMicPermission: false,
        isListening: false,
        phase: VoiceListeningPhase.error,
        errorMessage:
            'Microphone permission is required for VISION voice interaction.',
      );
      return;
    }

    final targetPhase = wakeWordMode
        ? VoiceListeningPhase.listeningWakeWord
        : VoiceListeningPhase.listeningCommand;

    try {
      await voiceRepo.startListening(language: settings.selectedVoiceLanguage);
      state = state.copyWith(
        hasMicPermission: true,
        phase: targetPhase,
        isListening: true,
        liveTranscript: '',
        clearError: true,
      );
      logger.info(
        'Started ${wakeWordMode ? 'wake-word' : 'command'} listening '
        'in ${settings.selectedVoiceLanguage.localeCode}',
      );
    } on AppException catch (error) {
      state = state.copyWith(
        phase: VoiceListeningPhase.error,
        isListening: false,
        errorMessage: error.message,
      );
    }
  }

  /// Arms the offline foreground "Hey VISION" wake-word service (or falls back
  /// to foreground wake listening if background service is unavailable).
  Future<void> startWakeWordSession() async {
    final voiceRepo = ref.read(voiceRepositoryProvider);
    final settings = ref.read(settingsControllerProvider);

    var hasPermission = await voiceRepo.checkMicrophonePermission();
    if (!hasPermission) {
      hasPermission = await voiceRepo.requestMicrophonePermission();
    }
    if (!hasPermission) {
      state = state.copyWith(
        hasMicPermission: false,
        isWakeWordArmed: false,
        phase: VoiceListeningPhase.error,
        errorMessage: 'Microphone permission is required for "Hey VISION" wake-word standby.',
      );
      return;
    }

    await ref
        .read(settingsControllerProvider.notifier)
        .setWakeWordEnabled(enabled: true);
    state = state.copyWith(hasMicPermission: true, isWakeWordArmed: true);

    try {
      final started = await voiceRepo.startWakeWordService(
        sensitivity: settings.wakeWordSensitivity,
      );
      if (started) {
        state = state.copyWith(
          isWakeServiceRunning: true,
          isWakeMicActive: true,
          phase: VoiceListeningPhase.listeningWakeWord,
          clearError: true,
        );
        return;
      }
    } on AppException catch (error) {
      state = state.copyWith(
        phase: VoiceListeningPhase.error,
        isWakeServiceRunning: false,
        isWakeMicActive: false,
        errorMessage: error.message,
      );
      return;
    }

    // Fallback in non-Android test environments or when foreground service isn't started.
    await startCommandListening(wakeWordMode: true);
  }

  /// Disarms and stops the foreground "Hey VISION" wake-word service.
  Future<void> stopWakeWordSession() async {
    await ref.read(voiceRepositoryProvider).stopWakeWordService();
    await ref
        .read(settingsControllerProvider.notifier)
        .setWakeWordEnabled(enabled: false);
    state = state.copyWith(
      isWakeWordArmed: false,
      isWakeServiceRunning: false,
      isWakeMicActive: false,
      phase: VoiceListeningPhase.idle,
    );
  }

  /// Syncs Android Digital Assistant role and wake-word service status.
  Future<void> refreshAssistantCapabilities() async {
    final voiceRepo = ref.read(voiceRepositoryProvider);
    final hasMic = await voiceRepo.checkMicrophonePermission();
    final isAssistant = await voiceRepo.isDefaultAssistant();
    final serviceStatus = await voiceRepo.getWakeWordServiceStatus();
    state = state.copyWith(
      hasMicPermission: hasMic,
      isDefaultAssistant: isAssistant,
      isWakeServiceRunning: serviceStatus.isRunning,
      isWakeMicActive: serviceStatus.isMicActive,
    );
  }

  /// Prompts the user to set VISION as Android's Default Digital Assistant (`ROLE_ASSISTANT`).
  Future<bool> requestDefaultAssistantRole() async {
    final granted = await ref
        .read(voiceRepositoryProvider)
        .requestAssistantRole();
    final verified =
        granted || await ref.read(voiceRepositoryProvider).isDefaultAssistant();
    state = state.copyWith(isDefaultAssistant: verified);
    return verified;
  }

  /// Opens the translucent Gemini-like assistant overlay sheet.
  Future<void> openAssistantOverlay() =>
      ref.read(voiceRepositoryProvider).openAssistantOverlay();

  /// Consumes and processes any pending prompt passed by `VoiceInteractionSession`.
  Future<void> checkQueuedOverlayPrompt() async {
    final prompt = await ref
        .read(voiceRepositoryProvider)
        .consumeOverlayPrompt();
    if (prompt != null && prompt.trim().isNotEmpty) {
      await _dispatchVoiceCommandToAi(prompt.trim());
    }
  }

  /// Speaks [text] aloud in the user's selected [VoiceLanguage].
  Future<void> speakReply(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final voiceRepo = ref.read(voiceRepositoryProvider);
    final settings = ref.read(settingsControllerProvider);

    if (state.isSpeaking) {
      await voiceRepo.stopSpeaking();
      state = state.copyWith(
        isSpeaking: false,
        phase: VoiceListeningPhase.idle,
      );
      return;
    }

    state = state.copyWith(
      isSpeaking: true,
      phase: VoiceListeningPhase.speaking,
    );

    final started = await voiceRepo.speak(
      text: trimmed,
      language: settings.selectedVoiceLanguage,
    );

    if (!started) {
      state = state.copyWith(
        isSpeaking: false,
        phase: VoiceListeningPhase.idle,
      );
    }
  }

  /// Stops any active TTS playback.
  Future<void> stopSpeaking() async {
    await ref.read(voiceRepositoryProvider).stopSpeaking();
    state = state.copyWith(isSpeaking: false, phase: VoiceListeningPhase.idle);
  }

  /// Dismisses any voice error message.
  void dismissError() {
    state = state.copyWith(phase: VoiceListeningPhase.idle, clearError: true);
  }
}
