import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vision_ai/features/settings/domain/entities/voice_language.dart';
import 'package:vision_ai/features/voice/data/datasources/voice_platform_datasource.dart';
import 'package:vision_ai/features/voice/domain/entities/tts_voice_info.dart';
import 'package:vision_ai/features/voice/domain/entities/voice_session_state.dart';
import 'package:vision_ai/features/voice/domain/repositories/voice_repository.dart';

/// Provides the [VoicePlatformDataSource] instance.
final voicePlatformDataSourceProvider = Provider<VoicePlatformDataSource>((
  ref,
) {
  return VoicePlatformDataSource();
});

/// Provides the [VoiceRepository] implementation.
final voiceRepositoryProvider = Provider<VoiceRepository>((ref) {
  final dataSource = ref.watch(voicePlatformDataSourceProvider);
  return VoiceRepositoryImpl(dataSource);
});

/// Concrete implementation of [VoiceRepository] backed by [VoicePlatformDataSource].
class VoiceRepositoryImpl implements VoiceRepository {
  const VoiceRepositoryImpl(this._dataSource);

  final VoicePlatformDataSource _dataSource;

  @override
  Stream<VoiceEvent> watchVoiceEvents() => _dataSource.watchVoiceEvents();

  @override
  Future<bool> checkMicrophonePermission() =>
      _dataSource.checkMicrophonePermission();

  @override
  Future<bool> requestMicrophonePermission() =>
      _dataSource.requestMicrophonePermission();

  @override
  Future<bool> isSpeechRecognitionAvailable() =>
      _dataSource.isSpeechRecognitionAvailable();

  @override
  Future<void> startListening({
    required VoiceLanguage language,
    int endpointSilenceMs = 3800,
  }) => _dataSource.startListening(
    language: language,
    endpointSilenceMs: endpointSilenceMs,
  );

  @override
  Future<void> stopListening() => _dataSource.stopListening();

  @override
  Future<void> cancelListening() => _dataSource.cancelListening();

  @override
  Future<bool> speak({
    required String text,
    required VoiceLanguage language,
    double speechRate = 1.0,
    double pitch = 1.0,
    String voiceName = '',
  }) => _dataSource.speak(
    text: text,
    language: language,
    speechRate: speechRate,
    pitch: pitch,
    voiceName: voiceName,
  );

  @override
  Future<bool> pauseSpeaking() => _dataSource.pauseSpeaking();

  @override
  Future<bool> resumeSpeaking() => _dataSource.resumeSpeaking();

  @override
  Future<List<TtsVoiceInfo>> getAvailableVoices({String? locale}) =>
      _dataSource.getAvailableVoices(locale: locale);

  @override
  Future<void> stopSpeaking() => _dataSource.stopSpeaking();

  @override
  Future<bool> startWakeWordService({double sensitivity = 0.55}) =>
      _dataSource.startWakeWordService(sensitivity: sensitivity);

  @override
  Future<void> stopWakeWordService() => _dataSource.stopWakeWordService();

  @override
  Future<void> setWakeWordSensitivity(double sensitivity) =>
      _dataSource.setWakeWordSensitivity(sensitivity);

  @override
  Future<({bool isRunning, bool isMicActive})> getWakeWordServiceStatus() =>
      _dataSource.getWakeWordServiceStatus();

  @override
  Future<bool> isDefaultAssistant() => _dataSource.isDefaultAssistant();

  @override
  Future<bool> requestAssistantRole() => _dataSource.requestAssistantRole();

  @override
  Future<void> openAssistantOverlay() => _dataSource.openAssistantOverlay();

  @override
  Future<String?> consumeOverlayPrompt() => _dataSource.consumeOverlayPrompt();

  @override
  Future<({String prompt, List<String> hypotheses})?> consumeOverlayPayload() =>
      _dataSource.consumeOverlayPayload();
}
