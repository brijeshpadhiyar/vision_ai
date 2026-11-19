import 'package:flutter/services.dart';

import 'package:vision_ai/core/constants/app_constants.dart';
import 'package:vision_ai/core/errors/app_exception.dart';
import 'package:vision_ai/features/settings/domain/entities/voice_language.dart';
import 'package:vision_ai/features/voice/domain/entities/voice_session_state.dart';

/// Platform channel data source communicating with `VisionVoiceChannel.kt` on Android.
class VoicePlatformDataSource {
  VoicePlatformDataSource({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  }) : _methodChannel =
           methodChannel ??
           const MethodChannel(AppConstants.voiceMethodChannel),
       _eventChannel =
           eventChannel ?? const EventChannel(AppConstants.voiceEventChannel);

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;

  Stream<VoiceEvent>? _eventStream;

  /// Broadcast stream of [VoiceEvent] items decoded from the native EventChannel.
  Stream<VoiceEvent> watchVoiceEvents() {
    return _eventStream ??= _eventChannel.receiveBroadcastStream().map((event) {
      if (event is Map<Object?, Object?>) {
        return VoiceEvent.fromMap(event);
      }
      return const VoiceErrorEvent(
        code: 'INVALID_EVENT_PAYLOAD',
        message: 'Unexpected payload from native voice channel.',
      );
    });
  }

  Future<bool> checkMicrophonePermission() async {
    try {
      final granted = await _methodChannel.invokeMethod<bool>(
        'checkMicrophonePermission',
      );
      return granted ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> requestMicrophonePermission() async {
    try {
      final granted = await _methodChannel.invokeMethod<bool>(
        'requestMicrophonePermission',
      );
      return granted ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> isSpeechRecognitionAvailable() async {
    try {
      final available = await _methodChannel.invokeMethod<bool>(
        'isSpeechAvailable',
      );
      return available ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> startListening({
    required VoiceLanguage language,
    int endpointSilenceMs = 3800,
    int initialTimeoutMs = 7500,
    int maxDurationMs = 45000,
  }) async {
    try {
      await _methodChannel.invokeMethod<bool>(
        'startListening',
        <String, Object>{
          'locale': language.localeCode,
          'endpointSilenceMs': endpointSilenceMs,
          'initialTimeoutMs': initialTimeoutMs,
          'maxDurationMs': maxDurationMs,
        },
      );
    } on MissingPluginException catch (error, stackTrace) {
      throw UnexpectedAppException(
        message: 'Native voice engine is only available on Android.',
        cause: error,
        stackTrace: stackTrace,
      );
    } on PlatformException catch (error, stackTrace) {
      throw UnexpectedAppException(
        message: error.message ?? 'Failed to start speech recognition.',
        code: error.code,
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> stopListening() async {
    try {
      await _methodChannel.invokeMethod<bool>('stopListening');
    } on MissingPluginException {
      // Ignore on non-Android test environments.
    } on PlatformException {
      // Ignore stop errors.
    }
  }

  Future<void> cancelListening() async {
    try {
      await _methodChannel.invokeMethod<bool>('cancelListening');
    } on MissingPluginException {
      // Ignore on non-Android test environments.
    } on PlatformException {
      // Ignore cancel errors.
    }
  }

  Future<bool> speak({
    required String text,
    required VoiceLanguage language,
    double speechRate = 1.0,
  }) async {
    try {
      final spoke = await _methodChannel.invokeMethod<bool>(
        'speak',
        <String, Object>{
          'text': text,
          'locale': language.localeCode,
          'speechRate': speechRate,
        },
      );
      return spoke ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> stopSpeaking() async {
    try {
      await _methodChannel.invokeMethod<bool>('stopSpeaking');
    } on MissingPluginException {
      // Ignore on non-Android test environments.
    } on PlatformException {
      // Ignore stopSpeaking errors.
    }
  }

  Future<bool> startWakeWordService({double sensitivity = 0.55}) async {
    try {
      final started = await _methodChannel.invokeMethod<bool>(
        'startWakeWordService',
        <String, Object>{'sensitivity': sensitivity},
      );
      return started ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (error, stackTrace) {
      throw UnexpectedAppException(
        message: error.message ?? 'Unable to start Hey VISION standby service.',
        code: error.code,
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> stopWakeWordService() async {
    try {
      await _methodChannel.invokeMethod<bool>('stopWakeWordService');
    } on MissingPluginException {
      // Ignore outside Android.
    } on PlatformException {
      // Ignore stop errors.
    }
  }

  Future<void> setWakeWordSensitivity(double sensitivity) async {
    try {
      await _methodChannel.invokeMethod<bool>(
        'setWakeWordSensitivity',
        <String, Object>{'sensitivity': sensitivity},
      );
    } on MissingPluginException {
      // Ignore outside Android.
    } on PlatformException {
      // Ignore update errors.
    }
  }

  Future<({bool isRunning, bool isMicActive})>
  getWakeWordServiceStatus() async {
    try {
      final raw = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
        'getWakeWordServiceStatus',
      );
      return (
        isRunning: (raw?['isRunning'] as bool?) ?? false,
        isMicActive: (raw?['isMicActive'] as bool?) ?? false,
      );
    } on MissingPluginException {
      return (isRunning: false, isMicActive: false);
    } on PlatformException {
      return (isRunning: false, isMicActive: false);
    }
  }

  Future<bool> isDefaultAssistant() async {
    try {
      final isDefault = await _methodChannel.invokeMethod<bool>(
        'isDefaultAssistant',
      );
      return isDefault ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> requestAssistantRole() async {
    try {
      final granted = await _methodChannel.invokeMethod<bool>(
        'requestAssistantRole',
      );
      return granted ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> openAssistantOverlay() async {
    try {
      await _methodChannel.invokeMethod<bool>('openAssistantOverlay');
    } on MissingPluginException {
      // Ignore outside Android.
    } on PlatformException {
      // Ignore launch errors.
    }
  }

  Future<String?> consumeOverlayPrompt() async {
    try {
      return await _methodChannel.invokeMethod<String>('consumeOverlayPrompt');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  Future<({String prompt, List<String> hypotheses})?>
  consumeOverlayPayload() async {
    try {
      final raw = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
        'consumeOverlayPayload',
      );
      final prompt = (raw?['prompt'] as String?)?.trim() ?? '';
      if (prompt.isEmpty) return null;
      final hypotheses =
          (raw?['hypotheses'] as List<Object?>?)
              ?.whereType<String>()
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList(growable: false) ??
          const <String>[];
      return (prompt: prompt, hypotheses: hypotheses);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
