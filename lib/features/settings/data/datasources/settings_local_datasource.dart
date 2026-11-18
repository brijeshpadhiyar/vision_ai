import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vision_ai/core/constants/storage_keys.dart';
import 'package:vision_ai/core/errors/app_exception.dart';
import 'package:vision_ai/features/chat/domain/entities/ai_model_config.dart';
import 'package:vision_ai/features/settings/domain/entities/ai_provider_type.dart';
import 'package:vision_ai/features/settings/domain/entities/app_settings.dart';
import 'package:vision_ai/features/settings/domain/entities/voice_language.dart';

/// Local data source backed by [SharedPreferences] for persisting [AppSettings].
class SettingsLocalDataSource {
  const SettingsLocalDataSource(this._prefs);

  final SharedPreferences _prefs;

  /// Reads persisted settings or returns safe defaults.
  ///
  /// Any deprecated persisted model IDs are automatically migrated to their
  /// active replacement while preserving all other user configuration.
  AppSettings readSettings() {
    final themeRaw = _prefs.getString(StorageKeys.themeMode);
    final providerRaw = _prefs.getString(StorageKeys.selectedAiProvider);
    final languageRaw = _prefs.getString(StorageKeys.selectedVoiceLanguage);

    final models = <AiProviderType, String>{};
    final enabledProviders = <AiProviderType>{};
    for (final provider in AiProviderType.values) {
      final rawModel = _prefs.getString(
        StorageKeys.modelKeyForProvider(provider.id),
      );
      models[provider] = AIModelRegistry.normalizeModelId(
        provider,
        rawModel,
        upgradeDeprecated: true,
      );
      final isEnabled =
          _prefs.getBool(StorageKeys.enabledKeyForProvider(provider.id)) ??
          true;
      if (isEnabled) {
        enabledProviders.add(provider);
      }
    }

    final autoRouting = _prefs.getBool(StorageKeys.autoRoutingEnabled) ?? false;
    final fallback = _prefs.getBool(StorageKeys.fallbackEnabled) ?? true;
    final streaming = _prefs.getBool(StorageKeys.streamingEnabled) ?? true;
    final haptics = _prefs.getBool(StorageKeys.hapticFeedbackEnabled) ?? true;
    final autoSpeak = _prefs.getBool(StorageKeys.autoSpeakReplies) ?? true;
    final wakeWord = _prefs.getBool(StorageKeys.wakeWordEnabled) ?? false;
    final wakeWordBg =
        _prefs.getBool(StorageKeys.wakeWordBackgroundEnabled) ?? false;
    final wakeSensitivity =
        (_prefs.getDouble(StorageKeys.wakeWordSensitivity) ?? 0.55).clamp(
          0.2,
          0.9,
        );
    final deviceActions =
        _prefs.getBool(StorageKeys.deviceActionsEnabled) ?? true;
    final directCalls =
        _prefs.getBool(StorageKeys.directPhoneCallsEnabled) ?? false;
    final notificationConsent =
        _prefs.getBool(StorageKeys.notificationListenerConsent) ?? false;
    final onboarding = _prefs.getBool(StorageKeys.onboardingCompleted) ?? false;

    return AppSettings(
      themeMode: _parseThemeMode(themeRaw),
      selectedAiProvider: AiProviderType.fromId(providerRaw),
      providerModels: Map<AiProviderType, String>.unmodifiable(models),
      enabledProviders: Set<AiProviderType>.unmodifiable(enabledProviders),
      autoRoutingEnabled: autoRouting,
      fallbackEnabled: fallback,
      streamingEnabled: streaming,
      selectedVoiceLanguage: VoiceLanguage.fromId(languageRaw),
      hapticFeedbackEnabled: haptics,
      autoSpeakReplies: autoSpeak,
      wakeWordEnabled: wakeWord,
      wakeWordBackgroundEnabled: wakeWordBg,
      wakeWordSensitivity: wakeSensitivity,
      deviceActionsEnabled: deviceActions,
      directPhoneCallsEnabled: directCalls,
      notificationListenerConsent: notificationConsent,
      onboardingCompleted: onboarding,
    );
  }

  Future<void> writeThemeMode(ThemeMode mode) async {
    await _writeString(
      StorageKeys.themeMode,
      mode.name,
      'Unable to save theme preference.',
    );
  }

  Future<void> writeAiProvider(AiProviderType provider) async {
    await _writeString(
      StorageKeys.selectedAiProvider,
      provider.id,
      'Unable to save AI provider preference.',
    );
  }

  Future<void> writeProviderModel(
    AiProviderType provider,
    String modelId,
  ) async {
    final normalized = AIModelRegistry.normalizeModelId(provider, modelId);
    await _writeString(
      StorageKeys.modelKeyForProvider(provider.id),
      normalized,
      'Unable to save model selection for ${provider.displayName}.',
    );
  }

  Future<void> writeProviderEnabled(
    AiProviderType provider, {
    required bool enabled,
  }) async {
    await _writeBool(
      StorageKeys.enabledKeyForProvider(provider.id),
      enabled,
      'Unable to save enabled state for ${provider.displayName}.',
    );
  }

  Future<void> writeAutoRoutingEnabled({required bool enabled}) async {
    await _writeBool(
      StorageKeys.autoRoutingEnabled,
      enabled,
      'Unable to save auto-routing preference.',
    );
  }

  Future<void> writeFallbackEnabled({required bool enabled}) async {
    await _writeBool(
      StorageKeys.fallbackEnabled,
      enabled,
      'Unable to save provider fallback preference.',
    );
  }

  Future<void> writeStreamingEnabled({required bool enabled}) async {
    await _writeBool(
      StorageKeys.streamingEnabled,
      enabled,
      'Unable to save streaming preference.',
    );
  }

  Future<void> writeVoiceLanguage(VoiceLanguage language) async {
    await _writeString(
      StorageKeys.selectedVoiceLanguage,
      language.id,
      'Unable to save voice language preference.',
    );
  }

  Future<void> writeHapticFeedback({required bool enabled}) async {
    await _writeBool(
      StorageKeys.hapticFeedbackEnabled,
      enabled,
      'Unable to save haptic feedback preference.',
    );
  }

  Future<void> writeAutoSpeakReplies({required bool enabled}) async {
    await _writeBool(
      StorageKeys.autoSpeakReplies,
      enabled,
      'Unable to save auto-speak preference.',
    );
  }

  Future<void> writeWakeWordEnabled({required bool enabled}) async {
    await _writeBool(
      StorageKeys.wakeWordEnabled,
      enabled,
      'Unable to save wake-word preference.',
    );
  }

  Future<void> writeWakeWordBackgroundEnabled({required bool enabled}) async {
    await _writeBool(
      StorageKeys.wakeWordBackgroundEnabled,
      enabled,
      'Unable to save background wake-word preference.',
    );
  }

  Future<void> writeWakeWordSensitivity(double sensitivity) async {
    final clamped = sensitivity.clamp(0.2, 0.9);
    final success = await _prefs.setDouble(
      StorageKeys.wakeWordSensitivity,
      clamped,
    );
    if (!success) {
      throw const StorageException(
        message: 'Unable to save wake-word sensitivity.',
      );
    }
  }

  Future<void> writeDeviceActionsEnabled({required bool enabled}) async {
    await _writeBool(
      StorageKeys.deviceActionsEnabled,
      enabled,
      'Unable to save device automation preference.',
    );
  }

  Future<void> writeDirectPhoneCallsEnabled({required bool enabled}) async {
    await _writeBool(
      StorageKeys.directPhoneCallsEnabled,
      enabled,
      'Unable to save direct calling preference.',
    );
  }

  Future<void> writeNotificationListenerConsent({
    required bool consented,
  }) async {
    await _writeBool(
      StorageKeys.notificationListenerConsent,
      consented,
      'Unable to save notification consent.',
    );
  }

  Future<void> writeOnboardingCompleted({required bool completed}) async {
    await _writeBool(
      StorageKeys.onboardingCompleted,
      completed,
      'Unable to save onboarding completion status.',
    );
  }

  Future<void> clearAllSettings() async {
    await _prefs.remove(StorageKeys.themeMode);
    await _prefs.remove(StorageKeys.selectedAiProvider);
    for (final provider in AiProviderType.values) {
      await _prefs.remove(StorageKeys.modelKeyForProvider(provider.id));
      await _prefs.remove(StorageKeys.enabledKeyForProvider(provider.id));
    }
    await _prefs.remove(StorageKeys.autoRoutingEnabled);
    await _prefs.remove(StorageKeys.fallbackEnabled);
    await _prefs.remove(StorageKeys.streamingEnabled);
    await _prefs.remove(StorageKeys.selectedVoiceLanguage);
    await _prefs.remove(StorageKeys.hapticFeedbackEnabled);
    await _prefs.remove(StorageKeys.autoSpeakReplies);
    await _prefs.remove(StorageKeys.wakeWordEnabled);
    await _prefs.remove(StorageKeys.wakeWordBackgroundEnabled);
    await _prefs.remove(StorageKeys.wakeWordSensitivity);
    await _prefs.remove(StorageKeys.deviceActionsEnabled);
    await _prefs.remove(StorageKeys.directPhoneCallsEnabled);
    await _prefs.remove(StorageKeys.notificationListenerConsent);
    await _prefs.remove(StorageKeys.onboardingCompleted);
  }

  Future<void> _writeString(String key, String value, String err) async {
    final success = await _prefs.setString(key, value);
    if (!success) throw StorageException(message: err);
  }

  Future<void> _writeBool(String key, bool value, String err) async {
    final success = await _prefs.setBool(key, value);
    if (!success) throw StorageException(message: err);
  }

  static ThemeMode _parseThemeMode(String? raw) {
    return switch (raw) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    };
  }
}
