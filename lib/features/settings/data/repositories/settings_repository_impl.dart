import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/utils/shared_preferences_provider.dart';
import 'package:vision_ai/features/settings/data/datasources/settings_local_datasource.dart';
import 'package:vision_ai/features/settings/domain/entities/ai_provider_type.dart';
import 'package:vision_ai/features/settings/domain/entities/app_settings.dart';
import 'package:vision_ai/features/settings/domain/entities/assistant_identity.dart';
import 'package:vision_ai/features/settings/domain/entities/voice_language.dart';
import 'package:vision_ai/features/settings/domain/repositories/settings_repository.dart';

/// Provides the [SettingsLocalDataSource] backed by [sharedPreferencesProvider].
final settingsLocalDataSourceProvider = Provider<SettingsLocalDataSource>((
  ref,
) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SettingsLocalDataSource(prefs);
});

/// Provides the concrete [SettingsRepository] implementation.
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final dataSource = ref.watch(settingsLocalDataSourceProvider);
  return SettingsRepositoryImpl(dataSource);
});

/// Concrete implementation of [SettingsRepository] using local storage.
class SettingsRepositoryImpl implements SettingsRepository {
  const SettingsRepositoryImpl(this._localDataSource);

  final SettingsLocalDataSource _localDataSource;

  @override
  AppSettings loadSettings() => _localDataSource.readSettings();

  @override
  Future<void> updateThemeMode(ThemeMode mode) =>
      _localDataSource.writeThemeMode(mode);

  @override
  Future<void> updateAiProvider(AiProviderType provider) =>
      _localDataSource.writeAiProvider(provider);

  @override
  Future<void> updateProviderModel(AiProviderType provider, String modelId) =>
      _localDataSource.writeProviderModel(provider, modelId);

  @override
  Future<void> updateProviderEnabled(
    AiProviderType provider, {
    required bool enabled,
  }) => _localDataSource.writeProviderEnabled(provider, enabled: enabled);

  @override
  Future<void> updateFallbackEnabled({required bool enabled}) =>
      _localDataSource.writeFallbackEnabled(enabled: enabled);

  @override
  Future<void> updateStreamingEnabled({required bool enabled}) =>
      _localDataSource.writeStreamingEnabled(enabled: enabled);

  @override
  Future<void> updateSaveConversationHistory({required bool enabled}) =>
      _localDataSource.writeSaveConversationHistory(enabled: enabled);

  @override
  Future<void> updateVoiceLanguage(VoiceLanguage language) =>
      _localDataSource.writeVoiceLanguage(language);

  @override
  Future<void> updateAssistantIdentity(AssistantIdentity identity) =>
      _localDataSource.writeAssistantIdentity(identity);

  @override
  Future<void> updateTtsVoiceName(String voiceName) =>
      _localDataSource.writeTtsVoiceName(voiceName);

  @override
  Future<void> updateTtsSpeechRate(double rate) =>
      _localDataSource.writeTtsSpeechRate(rate);

  @override
  Future<void> updateTtsPitch(double pitch) =>
      _localDataSource.writeTtsPitch(pitch);

  @override
  Future<void> updateHapticFeedback({required bool enabled}) =>
      _localDataSource.writeHapticFeedback(enabled: enabled);

  @override
  Future<void> updateAutoSpeakReplies({required bool enabled}) =>
      _localDataSource.writeAutoSpeakReplies(enabled: enabled);

  @override
  Future<void> updateVoiceEndpointSilenceMs(int silenceMs) =>
      _localDataSource.writeVoiceEndpointSilenceMs(silenceMs);

  @override
  Future<void> updateWakeWordEnabled({required bool enabled}) =>
      _localDataSource.writeWakeWordEnabled(enabled: enabled);

  @override
  Future<void> updateWakeWordBackgroundEnabled({required bool enabled}) =>
      _localDataSource.writeWakeWordBackgroundEnabled(enabled: enabled);

  @override
  Future<void> updateWakeWordSensitivity(double sensitivity) =>
      _localDataSource.writeWakeWordSensitivity(sensitivity);

  @override
  Future<void> updateDeviceActionsEnabled({required bool enabled}) =>
      _localDataSource.writeDeviceActionsEnabled(enabled: enabled);

  @override
  Future<void> updateDirectPhoneCallsEnabled({required bool enabled}) =>
      _localDataSource.writeDirectPhoneCallsEnabled(enabled: enabled);

  @override
  Future<void> updateNotificationListenerConsent({required bool consented}) =>
      _localDataSource.writeNotificationListenerConsent(consented: consented);

  @override
  Future<void> updateOnboardingCompleted({required bool completed}) =>
      _localDataSource.writeOnboardingCompleted(completed: completed);

  @override
  Future<AppSettings> resetToDefaults() async {
    await _localDataSource.clearAllSettings();
    return _localDataSource.readSettings();
  }
}
