import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vision_ai/core/errors/app_exception.dart';
import 'package:vision_ai/core/intelligence/language_detector.dart';
import 'package:vision_ai/core/telemetry/performance_telemetry.dart';
import 'package:vision_ai/core/utils/app_logger.dart';
import 'package:vision_ai/features/automation/domain/entities/device_action.dart';
import 'package:vision_ai/features/automation/domain/utils/device_intent_parser.dart';
import 'package:vision_ai/features/automation/presentation/controllers/automation_controller.dart';
import 'package:vision_ai/features/chat/domain/entities/chat_message.dart';
import 'package:vision_ai/features/chat/presentation/controllers/chat_controller.dart';
import 'package:vision_ai/features/settings/presentation/controllers/settings_controller.dart';
import 'package:vision_ai/features/voice/data/repositories/voice_repository_impl.dart';
import 'package:vision_ai/features/voice/domain/entities/tts_voice_info.dart';
import 'package:vision_ai/features/voice/domain/entities/voice_session_state.dart';
import 'package:vision_ai/features/voice/domain/utils/wake_word_detector.dart';

/// Global Riverpod provider for the [VoiceController].
final voiceControllerProvider =
    NotifierProvider<VoiceController, VoiceSessionState>(VoiceController.new);

/// Orchestrates pause-tolerant Speech-to-Text (STT), Text-to-Speech (TTS),
/// offline foreground "Hey VISION" wake-word detection, and Assistant Role state
/// across English (`en-IN`), Hindi (`hi-IN`), and Gujarati (`gu-IN`).
class VoiceController extends Notifier<VoiceSessionState> {
  StreamSubscription<VoiceEvent>? _eventSubscription;
  Stopwatch? _listenStopwatch;

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
      case VoiceStateChangedEvent(
        :final isListening,
        :final isSpeaking,
        :final phase,
        :final segmentCount,
      ):
        final currentPhase = state.phase;
        final mappedNativePhase = _mapNativePhase(phase);
        final nextPhase = isSpeaking
            ? VoiceListeningPhase.speaking
            : isListening
            ? (currentPhase == VoiceListeningPhase.listeningWakeWord
                  ? VoiceListeningPhase.listeningWakeWord
                  : (mappedNativePhase ?? VoiceListeningPhase.listeningCommand))
            : (currentPhase == VoiceListeningPhase.processingAi ||
                      currentPhase == VoiceListeningPhase.understanding ||
                      currentPhase == VoiceListeningPhase.executing ||
                      currentPhase == VoiceListeningPhase.confirmationRequired
                  ? currentPhase
                  : (mappedNativePhase == VoiceListeningPhase.cancelled ||
                            mappedNativePhase == VoiceListeningPhase.error
                        ? mappedNativePhase!
                        : VoiceListeningPhase.idle));

        if (isListening &&
            (_listenStopwatch == null || !_listenStopwatch!.isRunning)) {
          _listenStopwatch = Stopwatch()..start();
        }

        state = state.copyWith(
          isListening: isListening,
          isSpeaking: isSpeaking,
          phase: nextPhase,
          segmentCount: segmentCount > 0 ? segmentCount : state.segmentCount,
          normalizedAmplitude: isListening ? state.normalizedAmplitude : 0.0,
        );

      case VoiceAmplitudeEvent(:final normalizedLevel):
        state = state.copyWith(normalizedAmplitude: normalizedLevel);

      case VoiceTranscriptEvent(
        :final text,
        :final isFinal,
        :final hypotheses,
        :final confidenceScores,
        :final segmentCount,
      ):
        final nextPhase = !isFinal && state.isListening
            ? (state.phase == VoiceListeningPhase.endpointing
                  ? VoiceListeningPhase.endpointing
                  : VoiceListeningPhase.partialTranscription)
            : state.phase;
        state = state.copyWith(
          phase: nextPhase,
          liveTranscript: text,
          originalTranscript: isFinal ? text : state.originalTranscript,
          alternativeTranscripts: hypotheses.isNotEmpty
              ? hypotheses
              : state.alternativeTranscripts,
          segmentCount: segmentCount > 0 ? segmentCount : state.segmentCount,
          engineConfidence:
              (isFinal &&
                  confidenceScores != null &&
                  confidenceScores.isNotEmpty)
              ? confidenceScores.first
              : null,
          clearConfidence:
              isFinal && (confidenceScores == null || confidenceScores.isEmpty),
          clearError: true,
        );
        if (isFinal) {
          unawaited(_processFinalTranscript(text, hypotheses: hypotheses));
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
          wakeTriggerSequence: state.wakeTriggerSequence + 1,
          liveTranscript: 'Hey VISION detected — listening for command...',
          clearError: true,
        );
        unawaited(startCommandListening());

      case VoiceOverlayPromptEvent(:final prompt, :final hypotheses):
        if (prompt.trim().isNotEmpty) {
          unawaited(
            _dispatchVoiceCommandToAi(
              prompt.trim(),
              hypotheses: hypotheses,
            ),
          );
        }

      case VoiceErrorEvent(:final message):
        _listenStopwatch?.stop();
        state = state.copyWith(
          phase: VoiceListeningPhase.error,
          isListening: false,
          normalizedAmplitude: 0.0,
          errorMessage: message,
        );
    }
  }

  VoiceListeningPhase? _mapNativePhase(String? rawPhase) {
    return switch (rawPhase) {
      'listening' => VoiceListeningPhase.listeningCommand,
      'partial_transcription' => VoiceListeningPhase.partialTranscription,
      'endpointing' => VoiceListeningPhase.endpointing,
      'finalizing' => VoiceListeningPhase.finalizing,
      'speaking' => VoiceListeningPhase.speaking,
      'cancelled' => VoiceListeningPhase.cancelled,
      'error' => VoiceListeningPhase.error,
      'idle' => VoiceListeningPhase.idle,
      _ => null,
    };
  }

  Future<void> _processFinalTranscript(
    String transcript, {
    List<String> hypotheses = const <String>[],
  }) async {
    final trimmed = transcript.trim();
    if (trimmed.isEmpty) return;

    final sttElapsedMs = _listenStopwatch?.elapsedMilliseconds;
    _listenStopwatch?.stop();
    if (sttElapsedMs != null) {
      ref
          .read(telemetryProvider.notifier)
          .recordVoiceLatency(sttFinalMs: sttElapsedMs);
    }

    final logger = ref.read(appLoggerProvider);

    // Check wake-word strictly when in wake-word listening mode, or strip a
    // leading multi-word wake prefix ("hey vision ...") when wake-word is armed
    // or when the user begins a command with "Hey VISION ...".
    if (state.phase == VoiceListeningPhase.listeningWakeWord) {
      final match = WakeWordDetector.evaluate(trimmed);
      if (match.isTriggered) {
        logger.info('Wake word detected: "${match.matchedPhrase}"');
        state = state.copyWith(
          lastWakeWordDetected: match.matchedPhrase,
          wakeTriggerSequence: state.wakeTriggerSequence + 1,
          clearError: true,
        );

        if (match.trailingCommand.isNotEmpty) {
          final cleanedHypotheses = _stripWakePrefixFromHypotheses(hypotheses);
          await _dispatchVoiceCommandToAi(
            match.trailingCommand,
            hypotheses: cleanedHypotheses,
            originalRaw: trimmed,
          );
        } else {
          // User said "Hey VISION" — immediately listen for their spoken question.
          state = state.copyWith(
            liveTranscript: 'Wake word detected! Listening for your command...',
          );
          await startCommandListening();
        }
        return;
      } else {
        // Ignore non-wake-word ambient speech when strictly in wake-word mode.
        state = state.copyWith(
          phase: VoiceListeningPhase.idle,
          liveTranscript: '',
        );
        return;
      }
    } else {
      final match = WakeWordDetector.evaluate(trimmed);
      if (match.isTriggered) {
        logger.info('Wake prefix detected: "${match.matchedPhrase}"');
        state = state.copyWith(
          lastWakeWordDetected: match.matchedPhrase,
          wakeTriggerSequence: state.wakeTriggerSequence + 1,
          clearError: true,
        );
        if (match.trailingCommand.isNotEmpty) {
          final cleanedHypotheses = _stripWakePrefixFromHypotheses(hypotheses);
          await _dispatchVoiceCommandToAi(
            match.trailingCommand,
            hypotheses: cleanedHypotheses,
            originalRaw: trimmed,
          );
          return;
        }
        if (state.isWakeWordArmed) {
          state = state.copyWith(
            liveTranscript: 'Listening for your command...',
          );
          await startCommandListening();
          return;
        }
      }
    }

    await _dispatchVoiceCommandToAi(
      trimmed,
      hypotheses: hypotheses,
      originalRaw: trimmed,
    );
  }

  List<String> _stripWakePrefixFromHypotheses(List<String> hypotheses) {
    if (hypotheses.isEmpty) return const <String>[];
    final cleaned = <String>[];
    for (final h in hypotheses) {
      final m = WakeWordDetector.evaluate(h);
      final value = (m.isTriggered && m.trailingCommand.isNotEmpty)
          ? m.trailingCommand
          : h.trim();
      if (value.isNotEmpty && !cleaned.contains(value)) {
        cleaned.add(value);
      }
    }
    return cleaned;
  }

  Future<void> _dispatchVoiceCommandToAi(
    String commandText, {
    List<String> hypotheses = const <String>[],
    String? originalRaw,
  }) async {
    final e2eStopwatch = Stopwatch()..start();

    state = state.copyWith(
      phase: VoiceListeningPhase.understanding,
      liveTranscript: commandText,
      originalTranscript: originalRaw ?? commandText,
      alternativeTranscripts: hypotheses.isNotEmpty
          ? hypotheses
          : state.alternativeTranscripts,
      isListening: false,
      normalizedAmplitude: 0.0,
      clearError: true,
    );

    // Fast-path voice interruption before invoking chat/LLM pipelines.
    final quickIntent = DeviceIntentParser.analyzeIntent(commandText);
    if (quickIntent.shouldHandleLocally &&
        quickIntent.request?.type == DeviceActionType.stopSpeaking) {
      await stopSpeaking();
      state = state.copyWith(
        phase: VoiceListeningPhase.idle,
        lastReplyText: 'Stopped speaking.',
      );
      return;
    }

    if (quickIntent.shouldHandleLocally &&
        quickIntent.request?.type == DeviceActionType.cancelAction) {
      await stopSpeaking();
      ref.read(chatControllerProvider.notifier).cancelActiveRequest();
    }

    state = state.copyWith(
      phase: quickIntent.shouldHandleLocally
          ? VoiceListeningPhase.executing
          : VoiceListeningPhase.processingAi,
    );

    final accepted = await ref
        .read(chatControllerProvider.notifier)
        .sendMessage(
          commandText,
          alternativeTranscripts: hypotheses,
          originalTranscript: originalRaw ?? commandText,
        );
    if (!ref.mounted) return;

    final chatState = ref.read(chatControllerProvider);
    final automationState = ref.read(automationControllerProvider);
    if (!accepted || chatState.errorMessage != null) {
      e2eStopwatch.stop();
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

    final needsConfirm =
        automationState.pendingConfirmation != null ||
        automationState.lastResult?.status ==
            DeviceActionStatus.confirmationRequired;

    state = state.copyWith(
      phase: needsConfirm
          ? VoiceListeningPhase.confirmationRequired
          : VoiceListeningPhase.idle,
      lastReplyText: latestReply,
    );

    final settings = ref.read(settingsControllerProvider);
    if (settings.autoSpeakReplies && latestReply.isNotEmpty) {
      await speakReply(latestReply);
      if (!ref.mounted) return;
    }

    e2eStopwatch.stop();
    ref
        .read(telemetryProvider.notifier)
        .recordVoiceLatency(endToEndMs: e2eStopwatch.elapsedMilliseconds);
  }

  /// Toggles voice command capture on or off.
  ///
  /// When listening, calls [finishListening] to finalize accumulated speech cleanly
  /// rather than discarding spoken segments.
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
      await finishListening();
      return;
    }

    await startCommandListening();
  }

  /// Manually finalizes the current listening session so accumulated speech
  /// is processed immediately without waiting for the silence timer.
  Future<void> finishListening() async {
    if (!state.isListening) return;
    final voiceRepo = ref.read(voiceRepositoryProvider);
    state = state.copyWith(
      phase: VoiceListeningPhase.finalizing,
      normalizedAmplitude: 0.0,
    );
    await voiceRepo.stopListening();
  }

  /// Manually cancels active voice capture (or TTS/AI generation) and resets to cancelled/idle.
  Future<void> cancelListening() async {
    _listenStopwatch?.stop();
    final voiceRepo = ref.read(voiceRepositoryProvider);
    if (state.isSpeaking) {
      await voiceRepo.stopSpeaking();
    }
    await voiceRepo.cancelListening();
    state = state.copyWith(
      isListening: false,
      isSpeaking: false,
      phase: VoiceListeningPhase.cancelled,
      normalizedAmplitude: 0.0,
      liveTranscript: '',
      clearError: true,
    );
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

    // Avoid starting STT while VISION is speaking aloud.
    if (state.isSpeaking) {
      await voiceRepo.stopSpeaking();
      state = state.copyWith(isSpeaking: false);
    }

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
      _listenStopwatch = Stopwatch()..start();
      await voiceRepo.startListening(
        language: settings.selectedVoiceLanguage,
        endpointSilenceMs: settings.voiceEndpointSilenceMs,
      );
      state = state.copyWith(
        hasMicPermission: true,
        phase: targetPhase,
        isListening: true,
        liveTranscript: '',
        originalTranscript: '',
        alternativeTranscripts: const <String>[],
        segmentCount: 0,
        clearConfidence: true,
        clearError: true,
      );
      logger.info(
        'Started ${wakeWordMode ? 'wake-word' : 'command'} listening '
        'in ${settings.selectedVoiceLanguage.localeCode} '
        '(silence=${settings.voiceEndpointSilenceMs}ms)',
      );
    } on AppException catch (error) {
      _listenStopwatch?.stop();
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
        errorMessage:
            'Microphone permission is required for "Hey VISION" wake-word standby.',
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

  /// Consumes and processes any pending prompt & hypotheses passed by `VoiceInteractionSession`.
  Future<void> checkQueuedOverlayPrompt() async {
    final repo = ref.read(voiceRepositoryProvider);
    final payload = await repo.consumeOverlayPayload();
    if (payload != null && payload.prompt.trim().isNotEmpty) {
      await _dispatchVoiceCommandToAi(
        payload.prompt.trim(),
        hypotheses: payload.hypotheses,
      );
      return;
    }
    final prompt = await repo.consumeOverlayPrompt();
    if (prompt != null && prompt.trim().isNotEmpty) {
      await _dispatchVoiceCommandToAi(prompt.trim());
    }
  }

  /// Speaks [text] aloud in the user's selected [VoiceLanguage] after
  /// sanitizing Markdown symbols, code blocks, and raw URLs for natural speech.
  Future<void> speakReply(String text) async {
    final cleaned = _sanitizeForSpeech(text);
    if (cleaned.isEmpty) return;

    final voiceRepo = ref.read(voiceRepositoryProvider);
    final settings = ref.read(settingsControllerProvider);

    if (state.isListening) {
      await voiceRepo.cancelListening();
      state = state.copyWith(isListening: false, normalizedAmplitude: 0.0);
    }
    if (state.isSpeaking) {
      await voiceRepo.stopSpeaking();
    }

    state = state.copyWith(
      isSpeaking: true,
      phase: VoiceListeningPhase.speaking,
    );

    final resolvedTtsLanguage = LanguageDetector.resolveTtsLanguage(
      cleaned,
      configuredLanguage: settings.selectedVoiceLanguage,
    );

    final ttsSw = Stopwatch()..start();
    final started = await voiceRepo.speak(
      text: cleaned,
      language: resolvedTtsLanguage,
      speechRate: settings.ttsSpeechRate,
      pitch: settings.ttsPitch,
      voiceName: settings.ttsVoiceName,
    );
    ttsSw.stop();
    ref
        .read(telemetryProvider.notifier)
        .recordVoiceLatency(ttsStartupMs: ttsSw.elapsedMilliseconds);

    if (!started) {
      state = state.copyWith(
        isSpeaking: false,
        phase: VoiceListeningPhase.idle,
      );
    }
  }

  /// Cleans Markdown markup and code fences for natural TTS pronunciation
  /// while preserving readable punctuation.
  static String _sanitizeForSpeech(String raw) {
    return raw
        .replaceAll(
          RegExp(r'```[\s\S]*?```'),
          ' Code snippet provided on screen. ',
        )
        .replaceAll(RegExp(r'`([^`]+)`'), r'$1')
        .replaceAll(RegExp(r'\[\[VISION_ACTION:.*?\]\]', dotAll: true), '')
        .replaceAll(RegExp(r'[*_~#>]'), '')
        .replaceAll(RegExp(r'\[([^\]]+)\]\([^\)]+\)'), r'$1')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Pauses active TTS playback so it can be resumed later.
  Future<bool> pauseSpeaking() async {
    final paused = await ref.read(voiceRepositoryProvider).pauseSpeaking();
    if (paused) {
      state = state.copyWith(isSpeaking: false, phase: VoiceListeningPhase.idle);
    }
    return paused;
  }

  /// Resumes previously paused TTS playback.
  Future<bool> resumeSpeaking() async {
    final resumed = await ref.read(voiceRepositoryProvider).resumeSpeaking();
    if (resumed) {
      state = state.copyWith(
        isSpeaking: true,
        phase: VoiceListeningPhase.speaking,
      );
    }
    return resumed;
  }

  /// Lists installed native Android TTS voices for the requested or active locale.
  Future<List<TtsVoiceInfo>> getAvailableVoices({String? locale}) {
    return ref.read(voiceRepositoryProvider).getAvailableVoices(locale: locale);
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
