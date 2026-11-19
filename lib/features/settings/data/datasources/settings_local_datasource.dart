import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vision_ai/core/constants/storage_keys.dart';
import 'package:vision_ai/core/errors/app_exception.dart';
import 'package:vision_ai/features/chat/domain/entities/ai_model_config.dart';
import 'package:vision_ai/features/settings/domain/entities/ai_provider_type.dart';
import 'package:vision_ai/features/settings/domain/entities/app_settings.dart';
import 'package:vision_ai/features/settings/domain/entities/assistant_identity.dart';
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

    final fallback = _prefs.getBool(StorageKeys.fallbackEnabled) ?? false;
    final streaming = _prefs.getBool(StorageKeys.streamingEnabled) ?? true;
    final saveHistory =
        _prefs.getBool(StorageKeys.saveConversationHistory) ?? false;
    final assistantIdentity = AssistantIdentity(
      personality: AssistantPersonality.fromId(
        _prefs.getString(StorageKeys.assistantPersonality),
      ),
      communicationStyle: CommunicationStyle.fromId(
        _prefs.getString(StorageKeys.assistantCommunicationStyle),
      ),
      customGreeting:
          _prefs.getString(StorageKeys.assistantCustomGreeting) ?? '',
      customInstructions:
          _prefs.getString(StorageKeys.assistantCustomInstructions) ?? '',
    );
    final ttsVoiceName = _prefs.getString(StorageKeys.ttsVoiceName) ?? '';
    final ttsSpeechRate = (_prefs.getDouble(StorageKeys.ttsSpeechRate) ?? 1.0)
        .clamp(0.5, 2.0);
    final ttsPitch = (_prefs.getDouble(StorageKeys.ttsPitch) ?? 1.0).clamp(
      0.5,
      2.0,
    );
    final haptics = _prefs.getBool(StorageKeys.hapticFeedbackEnabled) ?? true;
    final autoSpeak = _prefs.getBool(StorageKeys.autoSpeakReplies) ?? true;
    final endpointSilenceMs =
        (_prefs.getInt(StorageKeys.voiceEndpointSilenceMs) ?? 3800).clamp(
          2000,
          6500,
        );
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
      fallbackEnabled: fallback,
      streamingEnabled: streaming,
      saveConversationHistory: saveHistory,
      assistantIdentity: assistantIdentity,
      selectedVoiceLanguage: VoiceLanguage.fromId(languageRaw),
      ttsVoiceName: ttsVoiceName,
      ttsSpeechRate: ttsSpeechRate,
      ttsPitch: ttsPitch,
      hapticFeedbackEnabled: haptics,
      autoSpeakReplies: autoSpeak,
      voiceEndpointSilenceMs: endpointSilenceMs,
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

  Future<void> writeSaveConversationHistory({required bool enabled}) async {
    await _writeBool(
      StorageKeys.saveConversationHistory,
      enabled,
      'Unable to save conversation history preference.',
    );
    if (!enabled) {
      await _prefs.remove(StorageKeys.chatHistory);
    }
  }

  Future<void> writeVoiceLanguage(VoiceLanguage language) async {
    await _writeString(
      StorageKeys.selectedVoiceLanguage,
      language.id,
      'Unable to save voice language preference.',
    );
  }

  Future<void> writeAssistantIdentity(AssistantIdentity identity) async {
    await _writeString(
      StorageKeys.assistantPersonality,
      identity.personality.id,
      'Unable to save assistant personality.',
    );
    await _writeString(
      StorageKeys.assistantCommunicationStyle,
      identity.communicationStyle.id,
      'Unable to save communication style.',
    );
    await _writeString(
      StorageKeys.assistantCustomGreeting,
      identity.customGreeting.trim(),
      'Unable to save custom greeting.',
    );
    await _writeString(
      StorageKeys.assistantCustomInstructions,
      identity.customInstructions.trim(),
      'Unable to save custom instructions.',
    );
  }

  Future<void> writeTtsVoiceName(String voiceName) async {
    await _writeString(
      StorageKeys.ttsVoiceName,
      voiceName.trim(),
      'Unable to save selected TTS voice.',
    );
  }

  Future<void> writeTtsSpeechRate(double rate) async {
    final clamped = rate.clamp(0.5, 2.0);
    final success = await _prefs.setDouble(StorageKeys.ttsSpeechRate, clamped);
    if (!success) {
      throw const StorageException(message: 'Unable to save speech rate.');
    }
  }

  Future<void> writeTtsPitch(double pitch) async {
    final clamped = pitch.clamp(0.5, 2.0);
    final success = await _prefs.setDouble(StorageKeys.ttsPitch, clamped);
    if (!success) {
      throw const StorageException(message: 'Unable to save voice pitch.');
    }
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

  Future<void> writeVoiceEndpointSilenceMs(int silenceMs) async {
    final clamped = silenceMs.clamp(2000, 6500);
    final success = await _prefs.setInt(
      StorageKeys.voiceEndpointSilenceMs,
      clamped,
    );
    if (!success) {
      throw const StorageException(
        message: 'Unable to save voice pause tolerance.',
      );
    }
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
    await _prefs.remove(StorageKeys.fallbackEnabled);
    await _prefs.remove(StorageKeys.streamingEnabled);
    await _prefs.remove(StorageKeys.saveConversationHistory);
    await _prefs.remove(StorageKeys.assistantPersonality);
    await _prefs.remove(StorageKeys.assistantCommunicationStyle);
    await _prefs.remove(StorageKeys.assistantCustomGreeting);
    await _prefs.remove(StorageKeys.assistantCustomInstructions);
    await _prefs.remove(StorageKeys.selectedVoiceLanguage);
    await _prefs.remove(StorageKeys.ttsVoiceName);
    await _prefs.remove(StorageKeys.ttsSpeechRate);
    await _prefs.remove(StorageKeys.ttsPitch);
    await _prefs.remove(StorageKeys.hapticFeedbackEnabled);
    await _prefs.remove(StorageKeys.autoSpeakReplies);
    await _prefs.remove(StorageKeys.voiceEndpointSilenceMs);
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
