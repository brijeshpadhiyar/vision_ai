import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/features/settings/domain/entities/ai_provider_type.dart';
import 'package:vision_ai/features/settings/domain/entities/voice_language.dart';

/// Immutable domain model representing user-configurable VISION AI settings.
@immutable
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.dark,
    this.selectedAiProvider = AiProviderType.gemini,
    this.providerModels = defaultProviderModels,
    this.enabledProviders = defaultEnabledProviders,
    this.autoRoutingEnabled = false,
    this.fallbackEnabled = true,
    this.streamingEnabled = true,
    this.selectedVoiceLanguage = VoiceLanguage.english,
    this.hapticFeedbackEnabled = true,
    this.autoSpeakReplies = true,
    this.voiceEndpointSilenceMs = 3800,
    this.wakeWordEnabled = false,
    this.wakeWordBackgroundEnabled = false,
    this.wakeWordSensitivity = 0.55,
    this.deviceActionsEnabled = true,
    this.directPhoneCallsEnabled = false,
    this.notificationListenerConsent = false,
    this.onboardingCompleted = false,
  });

  static const Map<AiProviderType, String> defaultProviderModels =
      <AiProviderType, String>{
        AiProviderType.gemini: 'gemini-3.5-flash-lite',
        AiProviderType.openAi: 'gpt-5.4-mini',
        AiProviderType.claude: 'claude-haiku-5-5',
      };

  static const Set<AiProviderType> defaultEnabledProviders = <AiProviderType>{
    AiProviderType.gemini,
    AiProviderType.openAi,
    AiProviderType.claude,
  };

  /// Active theme mode. Defaults to [ThemeMode.dark] for VISION's dark aesthetic.
  final ThemeMode themeMode;

  /// Active default AI provider selected for orchestration.
  final AiProviderType selectedAiProvider;

  /// Selected model ID per provider.
  final Map<AiProviderType, String> providerModels;

  /// Providers currently enabled by the user.
  final Set<AiProviderType> enabledProviders;

  /// Whether automatic routing selects the optimal enabled provider/model.
  final bool autoRoutingEnabled;

  /// Whether VISION may fall back to another enabled provider when primary fails.
  final bool fallbackEnabled;

  /// Whether responses stream incrementally over SSE when supported.
  final bool streamingEnabled;

  /// Preferred voice interaction and TTS language (`en-IN`, `hi-IN`, `gu-IN`).
  final VoiceLanguage selectedVoiceLanguage;

  /// Whether tactile haptic feedback is enabled on button interactions.
  final bool hapticFeedbackEnabled;

  /// Whether VISION automatically speaks AI replies aloud via TTS.
  final bool autoSpeakReplies;

  /// Pause duration (ms) after speech before finalizing a voice utterance.
  final int voiceEndpointSilenceMs;

  /// Whether hands-free "Hey VISION" wake-word detection is enabled.
  final bool wakeWordEnabled;

  /// Whether the Android microphone foreground service stays armed in background.
  final bool wakeWordBackgroundEnabled;

  /// Configurable wake-word detector sensitivity (`0.2` low - `0.9` high).
  final double wakeWordSensitivity;

  /// Whether voice and AI chat commands can execute Android device actions.
  final bool deviceActionsEnabled;

  /// Whether phone call actions place direct calls (`ACTION_CALL`) when permitted.
  final bool directPhoneCallsEnabled;

  /// Explicit user consent for local notification listener inspection.
  final bool notificationListenerConsent;

  /// Whether the user has completed the architectural onboarding overview.
  final bool onboardingCompleted;

  /// Returns the active model ID configured for [provider].
  String modelForProvider(AiProviderType provider) {
    final configured = providerModels[provider]?.trim();
    if (configured != null && configured.isNotEmpty) {
      return configured;
    }
    return provider.defaultModel;
  }

  /// Convenience getter for the currently selected provider's model ID.
  String get selectedModelId => modelForProvider(selectedAiProvider);

  /// Returns whether [provider] is enabled for manual or fallback routing.
  bool isProviderEnabled(AiProviderType provider) =>
      enabledProviders.contains(provider);

  /// Creates a copy of [AppSettings] with the specified fields replaced.
  AppSettings copyWith({
    ThemeMode? themeMode,
    AiProviderType? selectedAiProvider,
    Map<AiProviderType, String>? providerModels,
    Set<AiProviderType>? enabledProviders,
    bool? autoRoutingEnabled,
    bool? fallbackEnabled,
    bool? streamingEnabled,
    VoiceLanguage? selectedVoiceLanguage,
    bool? hapticFeedbackEnabled,
    bool? autoSpeakReplies,
    int? voiceEndpointSilenceMs,
    bool? wakeWordEnabled,
    bool? wakeWordBackgroundEnabled,
    double? wakeWordSensitivity,
    bool? deviceActionsEnabled,
    bool? directPhoneCallsEnabled,
    bool? notificationListenerConsent,
    bool? onboardingCompleted,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      selectedAiProvider: selectedAiProvider ?? this.selectedAiProvider,
      providerModels: providerModels ?? this.providerModels,
      enabledProviders: enabledProviders ?? this.enabledProviders,
      autoRoutingEnabled: autoRoutingEnabled ?? this.autoRoutingEnabled,
      fallbackEnabled: fallbackEnabled ?? this.fallbackEnabled,
      streamingEnabled: streamingEnabled ?? this.streamingEnabled,
      selectedVoiceLanguage:
          selectedVoiceLanguage ?? this.selectedVoiceLanguage,
      hapticFeedbackEnabled:
          hapticFeedbackEnabled ?? this.hapticFeedbackEnabled,
      autoSpeakReplies: autoSpeakReplies ?? this.autoSpeakReplies,
      voiceEndpointSilenceMs:
          voiceEndpointSilenceMs ?? this.voiceEndpointSilenceMs,
      wakeWordEnabled: wakeWordEnabled ?? this.wakeWordEnabled,
      wakeWordBackgroundEnabled:
          wakeWordBackgroundEnabled ?? this.wakeWordBackgroundEnabled,
      wakeWordSensitivity: wakeWordSensitivity ?? this.wakeWordSensitivity,
      deviceActionsEnabled: deviceActionsEnabled ?? this.deviceActionsEnabled,
      directPhoneCallsEnabled:
          directPhoneCallsEnabled ?? this.directPhoneCallsEnabled,
      notificationListenerConsent:
          notificationListenerConsent ?? this.notificationListenerConsent,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppSettings &&
        other.themeMode == themeMode &&
        other.selectedAiProvider == selectedAiProvider &&
        mapEquals(other.providerModels, providerModels) &&
        setEquals(other.enabledProviders, enabledProviders) &&
        other.autoRoutingEnabled == autoRoutingEnabled &&
        other.fallbackEnabled == fallbackEnabled &&
        other.streamingEnabled == streamingEnabled &&
        other.selectedVoiceLanguage == selectedVoiceLanguage &&
        other.hapticFeedbackEnabled == hapticFeedbackEnabled &&
        other.autoSpeakReplies == autoSpeakReplies &&
        other.voiceEndpointSilenceMs == voiceEndpointSilenceMs &&
        other.wakeWordEnabled == wakeWordEnabled &&
        other.wakeWordBackgroundEnabled == wakeWordBackgroundEnabled &&
        other.wakeWordSensitivity == wakeWordSensitivity &&
        other.deviceActionsEnabled == deviceActionsEnabled &&
        other.directPhoneCallsEnabled == directPhoneCallsEnabled &&
        other.notificationListenerConsent == notificationListenerConsent &&
        other.onboardingCompleted == onboardingCompleted;
  }

  @override
  int get hashCode => Object.hash(
    themeMode,
    selectedAiProvider,
    Object.hashAll(
      providerModels.entries.map((e) => Object.hash(e.key, e.value)),
    ),
    Object.hashAll(enabledProviders),
    autoRoutingEnabled,
    fallbackEnabled,
    streamingEnabled,
    selectedVoiceLanguage,
    hapticFeedbackEnabled,
    autoSpeakReplies,
    voiceEndpointSilenceMs,
    wakeWordEnabled,
    wakeWordBackgroundEnabled,
    wakeWordSensitivity,
    deviceActionsEnabled,
    directPhoneCallsEnabled,
    notificationListenerConsent,
    onboardingCompleted,
  );
}
