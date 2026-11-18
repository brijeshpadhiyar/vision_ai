import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/utils/app_logger.dart';
import 'package:vision_ai/features/chat/domain/entities/ai_model_config.dart';
import 'package:vision_ai/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:vision_ai/features/settings/domain/entities/ai_provider_type.dart';
import 'package:vision_ai/features/settings/domain/entities/app_settings.dart';
import 'package:vision_ai/features/settings/domain/entities/voice_language.dart';

/// Global Riverpod provider exposing reactive [AppSettings] state.
final settingsControllerProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);

/// Manages reactive updates and persistence for user-configurable settings.
class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    final repository = ref.watch(settingsRepositoryProvider);
    return repository.loadSettings();
  }

  /// Updates the active [ThemeMode] and persists it locally.
  Future<void> setThemeMode(ThemeMode mode) async {
    if (state.themeMode == mode) return;
    final previous = state;
    state = state.copyWith(themeMode: mode);
    await _persist(
      () => ref.read(settingsRepositoryProvider).updateThemeMode(mode),
      previous: previous,
      logMessage: 'Theme mode updated to ${mode.name}',
      errorContext: 'theme mode',
    );
  }

  /// Updates the active default [AiProviderType] preference.
  Future<void> setAiProvider(AiProviderType provider) async {
    if (state.selectedAiProvider == provider) return;
    final previous = state;
    final updatedEnabled = <AiProviderType>{
      ...state.enabledProviders,
      provider,
    };
    state = state.copyWith(
      selectedAiProvider: provider,
      enabledProviders: Set<AiProviderType>.unmodifiable(updatedEnabled),
    );
    await _persist(
      () async {
        final repo = ref.read(settingsRepositoryProvider);
        await repo.updateAiProvider(provider);
        if (!previous.isProviderEnabled(provider)) {
          await repo.updateProviderEnabled(provider, enabled: true);
        }
      },
      previous: previous,
      logMessage: 'AI provider updated to ${provider.displayName}',
      errorContext: 'AI provider selection',
    );
  }

  /// Updates the selected model ID for [provider].
  Future<void> setProviderModel(AiProviderType provider, String modelId) async {
    final normalized = AIModelRegistry.normalizeModelId(provider, modelId);
    if (state.modelForProvider(provider) == normalized) return;
    final previous = state;
    final updatedModels = <AiProviderType, String>{
      ...state.providerModels,
      provider: normalized,
    };
    state = state.copyWith(
      providerModels: Map<AiProviderType, String>.unmodifiable(updatedModels),
    );
    await _persist(
      () => ref
          .read(settingsRepositoryProvider)
          .updateProviderModel(provider, normalized),
      previous: previous,
      logMessage: 'Model for ${provider.displayName} updated to $normalized',
      errorContext: 'model selection',
    );
  }

  /// Enables or disables [provider] in multi-provider orchestration.
  Future<void> setProviderEnabled(
    AiProviderType provider, {
    required bool enabled,
  }) async {
    if (state.isProviderEnabled(provider) == enabled) return;
    final previous = state;
    final updated = <AiProviderType>{...state.enabledProviders};
    if (enabled) {
      updated.add(provider);
    } else {
      updated.remove(provider);
    }
    var nextDefault = state.selectedAiProvider;
    if (!enabled && nextDefault == provider && updated.isNotEmpty) {
      nextDefault = updated.first;
    }

    state = state.copyWith(
      enabledProviders: Set<AiProviderType>.unmodifiable(updated),
      selectedAiProvider: nextDefault,
    );
    await _persist(
      () async {
        final repo = ref.read(settingsRepositoryProvider);
        await repo.updateProviderEnabled(provider, enabled: enabled);
        if (nextDefault != previous.selectedAiProvider) {
          await repo.updateAiProvider(nextDefault);
        }
      },
      previous: previous,
      logMessage: '${provider.displayName} enabled set to $enabled',
      errorContext: 'provider enabled state',
    );
  }

  Future<void> setAutoRoutingEnabled({required bool enabled}) async {
    if (state.autoRoutingEnabled == enabled) return;
    final previous = state;
    state = state.copyWith(autoRoutingEnabled: enabled);
    await _persist(
      () => ref
          .read(settingsRepositoryProvider)
          .updateAutoRoutingEnabled(enabled: enabled),
      previous: previous,
      logMessage: 'Automatic AI routing set to $enabled',
      errorContext: 'auto-routing setting',
    );
  }

  Future<void> setFallbackEnabled({required bool enabled}) async {
    if (state.fallbackEnabled == enabled) return;
    final previous = state;
    state = state.copyWith(fallbackEnabled: enabled);
    await _persist(
      () => ref
          .read(settingsRepositoryProvider)
          .updateFallbackEnabled(enabled: enabled),
      previous: previous,
      logMessage: 'Provider fallback set to $enabled',
      errorContext: 'provider fallback setting',
    );
  }

  Future<void> setStreamingEnabled({required bool enabled}) async {
    if (state.streamingEnabled == enabled) return;
    final previous = state;
    state = state.copyWith(streamingEnabled: enabled);
    await _persist(
      () => ref
          .read(settingsRepositoryProvider)
          .updateStreamingEnabled(enabled: enabled),
      previous: previous,
      logMessage: 'Response streaming set to $enabled',
      errorContext: 'streaming setting',
    );
  }

  /// Updates the active [VoiceLanguage] preference (`en-IN`, `hi-IN`, `gu-IN`).
  Future<void> setVoiceLanguage(VoiceLanguage language) async {
    if (state.selectedVoiceLanguage == language) return;
    final previous = state;
    state = state.copyWith(selectedVoiceLanguage: language);
    await _persist(
      () => ref.read(settingsRepositoryProvider).updateVoiceLanguage(language),
      previous: previous,
      logMessage: 'Voice language updated to ${language.displayName}',
      errorContext: 'voice language selection',
    );
  }

  /// Toggles tactile haptic feedback for interactive controls.
  Future<void> setHapticFeedback({required bool enabled}) async {
    if (state.hapticFeedbackEnabled == enabled) return;
    final previous = state;
    state = state.copyWith(hapticFeedbackEnabled: enabled);
    await _persist(
      () => ref
          .read(settingsRepositoryProvider)
          .updateHapticFeedback(enabled: enabled),
      previous: previous,
      logMessage: 'Haptic feedback set to $enabled',
      errorContext: 'haptic feedback setting',
    );
  }

  /// Toggles automatic TTS playback for AI replies.
  Future<void> setAutoSpeakReplies({required bool enabled}) async {
    if (state.autoSpeakReplies == enabled) return;
    final previous = state;
    state = state.copyWith(autoSpeakReplies: enabled);
    await _persist(
      () => ref
          .read(settingsRepositoryProvider)
          .updateAutoSpeakReplies(enabled: enabled),
      previous: previous,
      logMessage: 'Auto-speak replies set to $enabled',
      errorContext: 'auto-speak replies setting',
    );
  }

  /// Toggles "Hey VISION" wake-word listener mode.
  Future<void> setWakeWordEnabled({required bool enabled}) async {
    if (state.wakeWordEnabled == enabled) return;
    final previous = state;
    state = state.copyWith(wakeWordEnabled: enabled);
    await _persist(
      () => ref
          .read(settingsRepositoryProvider)
          .updateWakeWordEnabled(enabled: enabled),
      previous: previous,
      logMessage: 'Wake-word enabled set to $enabled',
      errorContext: 'wake-word setting',
    );
  }

  Future<void> setWakeWordBackgroundEnabled({required bool enabled}) async {
    if (state.wakeWordBackgroundEnabled == enabled) return;
    final previous = state;
    state = state.copyWith(wakeWordBackgroundEnabled: enabled);
    await _persist(
      () => ref
          .read(settingsRepositoryProvider)
          .updateWakeWordBackgroundEnabled(enabled: enabled),
      previous: previous,
      logMessage: 'Background wake-word service set to $enabled',
      errorContext: 'background wake-word setting',
    );
  }

  Future<void> setWakeWordSensitivity(double sensitivity) async {
    final clamped = sensitivity.clamp(0.2, 0.9);
    if (state.wakeWordSensitivity == clamped) return;
    final previous = state;
    state = state.copyWith(wakeWordSensitivity: clamped);
    await _persist(
      () => ref
          .read(settingsRepositoryProvider)
          .updateWakeWordSensitivity(clamped),
      previous: previous,
      logMessage:
          'Wake-word sensitivity updated to ${clamped.toStringAsFixed(2)}',
      errorContext: 'wake-word sensitivity',
    );
  }

  /// Toggles Android device automation execution for voice and chat commands.
  Future<void> setDeviceActionsEnabled({required bool enabled}) async {
    if (state.deviceActionsEnabled == enabled) return;
    final previous = state;
    state = state.copyWith(deviceActionsEnabled: enabled);
    await _persist(
      () => ref
          .read(settingsRepositoryProvider)
          .updateDeviceActionsEnabled(enabled: enabled),
      previous: previous,
      logMessage: 'Device automation enabled set to $enabled',
      errorContext: 'device automation setting',
    );
  }

  /// Toggles direct calling (`ACTION_CALL`) vs dialer confirmation (`ACTION_DIAL`).
  Future<void> setDirectPhoneCallsEnabled({required bool enabled}) async {
    if (state.directPhoneCallsEnabled == enabled) return;
    final previous = state;
    state = state.copyWith(directPhoneCallsEnabled: enabled);
    await _persist(
      () => ref
          .read(settingsRepositoryProvider)
          .updateDirectPhoneCallsEnabled(enabled: enabled),
      previous: previous,
      logMessage: 'Direct phone calls set to $enabled',
      errorContext: 'direct phone calls setting',
    );
  }

  Future<void> setNotificationListenerConsent({required bool consented}) async {
    if (state.notificationListenerConsent == consented) return;
    final previous = state;
    state = state.copyWith(notificationListenerConsent: consented);
    await _persist(
      () => ref
          .read(settingsRepositoryProvider)
          .updateNotificationListenerConsent(consented: consented),
      previous: previous,
      logMessage: 'Notification listener consent set to $consented',
      errorContext: 'notification listener consent',
    );
  }

  /// Marks the onboarding overview as completed.
  Future<void> completeOnboarding() async {
    if (state.onboardingCompleted) return;
    final previous = state;
    state = state.copyWith(onboardingCompleted: true);
    await _persist(
      () => ref
          .read(settingsRepositoryProvider)
          .updateOnboardingCompleted(completed: true),
      previous: previous,
      logMessage: 'Onboarding marked completed',
      errorContext: 'onboarding completion',
    );
  }

  /// Resets all preferences to default values.
  Future<void> resetDefaults() async {
    try {
      final defaults = await ref
          .read(settingsRepositoryProvider)
          .resetToDefaults();
      state = defaults;
      ref.read(appLoggerProvider).info('Settings reset to defaults');
    } on Exception catch (error, stackTrace) {
      ref
          .read(appLoggerProvider)
          .error(
            'Failed to reset settings',
            error: error,
            stackTrace: stackTrace,
          );
    }
  }

  Future<void> _persist(
    Future<void> Function() action, {
    required AppSettings previous,
    required String logMessage,
    required String errorContext,
  }) async {
    try {
      await action();
      ref.read(appLoggerProvider).info(logMessage);
    } on Exception catch (error, stackTrace) {
      state = previous;
      ref
          .read(appLoggerProvider)
          .error(
            'Failed to persist $errorContext',
            error: error,
            stackTrace: stackTrace,
          );
    }
  }
}
