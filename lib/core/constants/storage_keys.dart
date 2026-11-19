/// Centralized storage keys for local preferences and encrypted secure storage.
abstract final class StorageKeys {
  /// Key for persisted theme mode (`system`, `light`, `dark`).
  static const String themeMode = 'vision_pref_theme_mode';

  /// Key for persisted default AI provider (`openai`, `gemini`, `claude`).
  static const String selectedAiProvider = 'vision_pref_ai_provider';

  /// Key prefix for per-provider selected model ID.
  static const String providerModelPrefix = 'vision_pref_model_';

  static String modelKeyForProvider(String providerId) =>
      '$providerModelPrefix$providerId';

  /// Key prefix for per-provider enabled/disabled state.
  static const String providerEnabledPrefix = 'vision_pref_provider_enabled_';

  static String enabledKeyForProvider(String providerId) =>
      '$providerEnabledPrefix$providerId';

  /// Key for opt-in provider fallback toggle (OFF by default).
  static const String fallbackEnabled = 'vision_pref_provider_fallback';

  /// Key for persisted per-provider/model request & token usage counters.
  static const String aiUsageStats = 'vision_pref_ai_usage_stats';

  /// Key for opt-in local conversation history persistence (OFF by default).
  static const String saveConversationHistory = 'vision_pref_save_chat_history';

  /// Key for SSE streaming toggle.
  static const String streamingEnabled = 'vision_pref_streaming_enabled';

  /// Key for persisted voice interaction language (`auto`, `english`, `hindi`, `gujarati`).
  static const String selectedVoiceLanguage = 'vision_pref_voice_language';

  /// Keys for Assistant Identity customization (Module 01).
  static const String assistantPersonality = 'vision_pref_assistant_personality';
  static const String assistantCommunicationStyle =
      'vision_pref_assistant_style';
  static const String assistantCustomGreeting =
      'vision_pref_assistant_greeting';
  static const String assistantCustomInstructions =
      'vision_pref_assistant_instructions';

  /// Keys for Voice Identity customization (Module 02).
  static const String ttsVoiceName = 'vision_pref_tts_voice_name';
  static const String ttsSpeechRate = 'vision_pref_tts_speech_rate';
  static const String ttsPitch = 'vision_pref_tts_pitch';

  /// Key for persisted haptic feedback preference.
  static const String hapticFeedbackEnabled = 'vision_pref_haptic_feedback';

  /// Key for persisted automatic TTS voice reply playback preference.
  static const String autoSpeakReplies = 'vision_pref_auto_speak_replies';

  /// Key for configurable voice endpoint silence window in milliseconds.
  static const String voiceEndpointSilenceMs =
      'vision_pref_endpoint_silence_ms';

  /// Key for persisted "Hey VISION" wake-word listener preference.
  static const String wakeWordEnabled = 'vision_pref_wake_word_enabled';

  /// Key for background foreground-service wake-word standby preference.
  static const String wakeWordBackgroundEnabled =
      'vision_pref_wake_word_background';

  /// Key for wake-word sensitivity threshold (`0.2` - `0.9`).
  static const String wakeWordSensitivity = 'vision_pref_wake_word_sensitivity';

  /// Key tracking whether initial onboarding has been reviewed.
  static const String onboardingCompleted = 'vision_pref_onboarding_completed';

  /// Key for enabling voice & chat Android device automation intents.
  static const String deviceActionsEnabled = 'vision_pref_device_actions';

  /// Key for placing phone calls directly (`ACTION_CALL`) instead of opening dialer.
  static const String directPhoneCallsEnabled =
      'vision_pref_direct_phone_calls';

  /// Key for explicit user consent before reading Android notifications locally.
  static const String notificationListenerConsent =
      'vision_pref_notification_consent';

  /// Key for locally persisted conversation transcript JSON list.
  static const String chatHistory = 'vision_pref_chat_history';

  /// Key for explicit consent gating local personalization memory injection.
  static const String personalMemoryEnabled = 'vision_pref_memory_enabled';

  /// Key for locally persisted explicit personalization memory entries.
  static const String personalMemoryEntries = 'vision_pref_memory_entries';

  /// Key for user-confirmed Contact-ID voice alias mappings.
  static const String contactVoiceAliases = 'vision_pref_contact_voice_aliases';

  /// Key for user-trusted sensitive Android command wire IDs (Module 10).
  static const String trustedSensitiveCommands =
      'vision_pref_trusted_sensitive_commands';

  /// Key for per-app notification privacy blocklist package names (Module 15).
  static const String blockedNotificationPackages =
      'vision_pref_blocked_notification_packages';

  /// Key for user-defined Trusted Routines JSON list (Module 17).
  static const String automationRoutines = 'vision_pref_automation_routines';

  /// Key for persisted automation execution history JSON list (Module 17).
  static const String automationExecutionHistory =
      'vision_pref_automation_history';

  /// Prefix used for storing encrypted provider API keys in Android Keystore.
  static const String secureApiKeyPrefix = 'vision_secure_api_key_';

  /// Builds the encrypted storage key for a specific provider identifier.
  static String apiKeyForProvider(String providerId) =>
      '$secureApiKeyPrefix$providerId';
}
