import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/features/settings/domain/entities/ai_provider_type.dart';
import 'package:vision_ai/features/settings/domain/entities/app_settings.dart';
import 'package:vision_ai/features/settings/domain/entities/assistant_identity.dart';
import 'package:vision_ai/features/settings/domain/entities/voice_language.dart';

/// Contract for reading and persisting user preferences.
abstract interface class SettingsRepository {
  /// Synchronously loads current settings from local cache.
  AppSettings loadSettings();

  /// Persists the preferred [ThemeMode].
  Future<void> updateThemeMode(ThemeMode mode);

  /// Persists the preferred [AiProviderType].
  Future<void> updateAiProvider(AiProviderType provider);

  /// Persists the selected model ID for [provider].
  Future<void> updateProviderModel(AiProviderType provider, String modelId);

  /// Persists whether [provider] is enabled.
  Future<void> updateProviderEnabled(
    AiProviderType provider, {
    required bool enabled,
  });

  /// Persists whether opt-in fallback to another enabled provider is allowed.
  Future<void> updateFallbackEnabled({required bool enabled});

  /// Persists whether streaming SSE responses are enabled.
  Future<void> updateStreamingEnabled({required bool enabled});

  /// Persists whether conversation history should be saved across restarts.
  Future<void> updateSaveConversationHistory({required bool enabled});

  /// Persists the preferred [VoiceLanguage].
  Future<void> updateVoiceLanguage(VoiceLanguage language);

  /// Persists customizable [AssistantIdentity] preferences (Module 01).
  Future<void> updateAssistantIdentity(AssistantIdentity identity);

  /// Persists selected native Android TTS voice name (Module 02).
  Future<void> updateTtsVoiceName(String voiceName);

  /// Persists TTS speech rate (`0.5` - `2.0`).
  Future<void> updateTtsSpeechRate(double rate);

  /// Persists TTS voice pitch (`0.5` - `2.0`).
  Future<void> updateTtsPitch(double pitch);

  /// Persists whether haptic feedback is enabled.
  Future<void> updateHapticFeedback({required bool enabled});

  /// Persists whether AI replies should be spoken automatically via TTS.
  Future<void> updateAutoSpeakReplies({required bool enabled});

  /// Persists configurable voice endpoint silence duration in milliseconds.
  Future<void> updateVoiceEndpointSilenceMs(int silenceMs);

  /// Persists whether "Hey VISION" wake-word detection is enabled.
  Future<void> updateWakeWordEnabled({required bool enabled});

  /// Persists whether background wake-word foreground service is enabled.
  Future<void> updateWakeWordBackgroundEnabled({required bool enabled});

  /// Persists wake-word sensitivity threshold (`0.2` - `0.9`).
  Future<void> updateWakeWordSensitivity(double sensitivity);

  /// Persists whether Android device automation intents are enabled.
  Future<void> updateDeviceActionsEnabled({required bool enabled});

  /// Persists whether phone call actions place direct calls when permitted.
  Future<void> updateDirectPhoneCallsEnabled({required bool enabled});

  /// Persists explicit user consent for local notification listener access.
  Future<void> updateNotificationListenerConsent({required bool consented});

  /// Persists whether onboarding has been completed.
  Future<void> updateOnboardingCompleted({required bool completed});

  /// Resets all preferences back to factory defaults.
  Future<AppSettings> resetToDefaults();
}
