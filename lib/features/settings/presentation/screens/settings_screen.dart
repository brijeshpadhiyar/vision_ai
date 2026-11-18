import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/app/router/app_routes.dart';
import 'package:vision_ai/app/theme/app_colors.dart';
import 'package:vision_ai/core/constants/app_constants.dart';
import 'package:vision_ai/core/widgets/vision_app_bar.dart';
import 'package:vision_ai/core/widgets/vision_scaffold.dart';
import 'package:vision_ai/core/widgets/vision_status_badge.dart';
import 'package:vision_ai/features/automation/domain/entities/device_action.dart';
import 'package:vision_ai/features/automation/presentation/controllers/automation_controller.dart';
import 'package:vision_ai/features/chat/domain/entities/ai_model_config.dart';
import 'package:vision_ai/features/chat/domain/entities/ai_models.dart';
import 'package:vision_ai/features/settings/domain/entities/ai_provider_type.dart';
import 'package:vision_ai/features/settings/domain/entities/app_settings.dart';
import 'package:vision_ai/features/settings/domain/entities/voice_language.dart';
import 'package:vision_ai/features/settings/presentation/controllers/api_key_controller.dart';
import 'package:vision_ai/features/settings/presentation/controllers/provider_connection_controller.dart';
import 'package:vision_ai/features/settings/presentation/controllers/settings_controller.dart';
import 'package:vision_ai/features/settings/presentation/widgets/api_key_config_dialog.dart';
import 'package:vision_ai/features/settings/presentation/widgets/settings_section_card.dart';
import 'package:vision_ai/features/settings/presentation/widgets/settings_tile.dart';
import 'package:vision_ai/features/voice/domain/entities/voice_session_state.dart';
import 'package:vision_ai/features/voice/presentation/controllers/voice_controller.dart';

/// Settings screen for configuring appearance, multi-provider AI orchestration,
/// encrypted API keys, voice/wake-word engine, and Android automation permissions.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(
          ref
              .read(voiceControllerProvider.notifier)
              .refreshAssistantCapabilities(),
        );
      }
    });
  }

  Future<void> _openApiKeyDialog(
    AiProviderType provider,
    bool hasKey,
    AppSettings settings,
  ) async {
    _triggerHaptic(settings);
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => ApiKeyConfigDialog(
        provider: provider,
        hasExistingKey: hasKey,
        onSave: (apiKey) async {
          await ref
              .read(apiKeyStatusControllerProvider.notifier)
              .saveApiKey(provider: provider, apiKey: apiKey);
          ref
              .read(providerConnectionControllerProvider.notifier)
              .invalidateProvider(provider);
        },
        onRemove: () async {
          await ref
              .read(apiKeyStatusControllerProvider.notifier)
              .removeApiKey(provider);
          ref
              .read(providerConnectionControllerProvider.notifier)
              .invalidateProvider(provider);
        },
      ),
    );

    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result
                ? 'Encrypted API key saved for ${provider.displayName}. Tap Test Connection to verify.'
                : 'API key removed for ${provider.displayName}.',
          ),
        ),
      );
    }
  }

  Future<void> _openModelPickerDialog(
    AiProviderType provider,
    AppSettings settings,
    List<String> discoveredModels,
  ) async {
    _triggerHaptic(settings);
    final currentModel = settings.modelForProvider(provider);
    final builtIn = AIModelRegistry.modelsForProvider(provider);
    final candidates = <String>{
      for (final m in builtIn) m.modelId,
      currentModel,
      ...discoveredModels,
    }.toList(growable: false);

    final customController = TextEditingController(text: currentModel);
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${provider.displayName} Model'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose a verified model or enter any supported model ID for ${provider.displayName}:',
                style: Theme.of(dialogContext).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              for (final modelId in candidates.take(10))
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    modelId == currentModel
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: modelId == currentModel
                        ? Theme.of(dialogContext).colorScheme.primary
                        : Theme.of(dialogContext).colorScheme.onSurfaceVariant,
                  ),
                  title: Text(modelId),
                  onTap: () => Navigator.of(dialogContext).pop(modelId),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: customController,
                decoration: const InputDecoration(
                  labelText: 'Custom Model ID',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(customController.text.trim()),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    customController.dispose();

    if (selected != null && selected.isNotEmpty && mounted) {
      await ref
          .read(settingsControllerProvider.notifier)
          .setProviderModel(provider, selected);
      ref
          .read(providerConnectionControllerProvider.notifier)
          .invalidateProvider(provider);
    }
  }

  Future<void> _testProvider(AiProviderType provider) async {
    final result = await ref
        .read(providerConnectionControllerProvider.notifier)
        .testProviderConnection(provider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.connected ? AppColors.success : AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);
    final voiceState = ref.watch(voiceControllerProvider);
    final keyStatusAsync = ref.watch(apiKeyStatusControllerProvider);
    final connectionMap = ref.watch(providerConnectionControllerProvider);
    final keyMap =
        keyStatusAsync.asData?.value ?? const <AiProviderType, bool>{};

    return VisionScaffold(
      appBar: const VisionAppBar(
        title: 'SETTINGS',
        subtitle: 'AI Providers, Voice & Android Control',
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const Center(
            child: VisionStatusBadge(
              label: AppConstants.currentPhaseLabel,
              icon: Icons.auto_awesome_rounded,
            ),
          ),
          const SizedBox(height: 20),
          _AppearanceSection(
            settings: settings,
            onThemeSelected: (mode) async {
              _triggerHaptic(settings);
              await controller.setThemeMode(mode);
            },
            onHapticsChanged: (enabled) async {
              await controller.setHapticFeedback(enabled: enabled);
            },
          ),
          const SizedBox(height: 24),
          _MultiProviderAiSection(
            settings: settings,
            keyMap: keyMap,
            connectionMap: connectionMap,
            onSelectDefaultProvider: (provider) async {
              _triggerHaptic(settings);
              await controller.setAiProvider(provider);
            },
            onToggleProviderEnabled: (provider, enabled) async {
              _triggerHaptic(settings);
              await controller.setProviderEnabled(provider, enabled: enabled);
            },
            onChooseModel: (provider, discovered) =>
                _openModelPickerDialog(provider, settings, discovered),
            onConfigureKey: (provider, hasKey) =>
                _openApiKeyDialog(provider, hasKey, settings),
            onTestConnection: _testProvider,
            onAutoRoutingChanged: (enabled) =>
                controller.setAutoRoutingEnabled(enabled: enabled),
            onFallbackChanged: (enabled) =>
                controller.setFallbackEnabled(enabled: enabled),
            onStreamingChanged: (enabled) =>
                controller.setStreamingEnabled(enabled: enabled),
          ),
          const SizedBox(height: 24),
          _VoiceAndAssistantSection(
            settings: settings,
            voiceState: voiceState,
            onLanguageSelected: (language) async {
              _triggerHaptic(settings);
              await controller.setVoiceLanguage(language);
            },
            onAutoSpeakChanged: (enabled) =>
                controller.setAutoSpeakReplies(enabled: enabled),
            onWakeWordChanged: (enabled) async {
              if (enabled) {
                await ref
                    .read(voiceControllerProvider.notifier)
                    .startWakeWordSession();
              } else {
                await ref
                    .read(voiceControllerProvider.notifier)
                    .stopWakeWordSession();
              }
            },
            onWakeBackgroundChanged: (enabled) async {
              await controller.setWakeWordBackgroundEnabled(enabled: enabled);
              if (enabled) {
                await ref
                    .read(voiceControllerProvider.notifier)
                    .startWakeWordSession();
              }
            },
            onSensitivityChanged: (value) async {
              await controller.setWakeWordSensitivity(value);
              await ref
                  .read(voiceControllerProvider.notifier)
                  .refreshAssistantCapabilities();
            },
            onRequestDefaultAssistant: () async {
              final ok = await ref
                  .read(voiceControllerProvider.notifier)
                  .requestDefaultAssistantRole();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    ok
                        ? 'VISION is now set as your Android Default Assistant.'
                        : 'Select VISION in Android Default Digital Assistant settings.',
                  ),
                ),
              );
            },
            onOpenOverlayPreview: () {
              unawaited(
                ref
                    .read(voiceControllerProvider.notifier)
                    .openAssistantOverlay(),
              );
            },
            onOpenBatteryOptimization: () {
              unawaited(
                ref
                    .read(automationControllerProvider.notifier)
                    .executeRequest(
                      const DeviceActionRequest(
                        type: DeviceActionType.openSettings,
                        target: 'battery_optimization',
                        displaySummary: 'Open battery optimization settings',
                      ),
                    ),
              );
            },
          ),
          const SizedBox(height: 24),
          _DeviceAutomationSection(
            settings: settings,
            onDeviceActionsChanged: (enabled) async {
              _triggerHaptic(settings);
              await controller.setDeviceActionsEnabled(enabled: enabled);
            },
            onDirectCallsChanged: (enabled) async {
              _triggerHaptic(settings);
              await controller.setDirectPhoneCallsEnabled(enabled: enabled);
            },
            onNotificationConsentChanged: (consented) async {
              _triggerHaptic(settings);
              await controller.setNotificationListenerConsent(
                consented: consented,
              );
              if (consented) {
                await ref
                    .read(automationControllerProvider.notifier)
                    .requestPermission(AutomationPermission.notifications);
              }
            },
            onOpenDeviceControlHub: () {
              _triggerHaptic(settings);
              context.push(AppRoutes.automationPath);
            },
          ),
          const SizedBox(height: 24),
          _SystemInfoSection(
            onOpenOnboarding: () {
              _triggerHaptic(settings);
              context.push(AppRoutes.onboardingPath);
            },
            onResetDefaults: () async {
              _triggerHaptic(settings);
              await controller.resetDefaults();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Preferences restored to defaults.'),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _triggerHaptic(AppSettings settings) {
    if (settings.hapticFeedbackEnabled) {
      HapticFeedback.selectionClick();
    }
  }
}

class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection({
    required this.settings,
    required this.onThemeSelected,
    required this.onHapticsChanged,
  });

  final AppSettings settings;
  final ValueChanged<ThemeMode> onThemeSelected;
  final ValueChanged<bool> onHapticsChanged;

  @override
  Widget build(BuildContext context) {
    return SettingsSectionCard(
      title: 'Appearance & Interaction',
      subtitle: 'Customize visual theme and tactile feedback',
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Theme Mode',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontSize: 15),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode_outlined, size: 18),
                      label: Text('Dark'),
                    ),
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode_outlined, size: 18),
                      label: Text('Light'),
                    ),
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.system,
                      icon: Icon(Icons.brightness_auto_outlined, size: 18),
                      label: Text('System'),
                    ),
                  ],
                  selected: <ThemeMode>{settings.themeMode},
                  onSelectionChanged: (selection) {
                    if (selection.isNotEmpty) {
                      onThemeSelected(selection.first);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        SettingsTile(
          icon: Icons.vibration_rounded,
          title: 'Haptic Feedback',
          subtitle: 'Subtle tactile response when interacting with controls',
          trailing: Switch.adaptive(
            value: settings.hapticFeedbackEnabled,
            onChanged: onHapticsChanged,
          ),
          onTap: () => onHapticsChanged(!settings.hapticFeedbackEnabled),
        ),
      ],
    );
  }
}

class _MultiProviderAiSection extends StatelessWidget {
  const _MultiProviderAiSection({
    required this.settings,
    required this.keyMap,
    required this.connectionMap,
    required this.onSelectDefaultProvider,
    required this.onToggleProviderEnabled,
    required this.onChooseModel,
    required this.onConfigureKey,
    required this.onTestConnection,
    required this.onAutoRoutingChanged,
    required this.onFallbackChanged,
    required this.onStreamingChanged,
  });

  final AppSettings settings;
  final Map<AiProviderType, bool> keyMap;
  final Map<AiProviderType, ProviderRuntimeStatus> connectionMap;
  final ValueChanged<AiProviderType> onSelectDefaultProvider;
  final void Function(AiProviderType provider, bool enabled)
  onToggleProviderEnabled;
  final void Function(AiProviderType provider, List<String> discovered)
  onChooseModel;
  final void Function(AiProviderType provider, bool hasKey) onConfigureKey;
  final ValueChanged<AiProviderType> onTestConnection;
  final ValueChanged<bool> onAutoRoutingChanged;
  final ValueChanged<bool> onFallbackChanged;
  final ValueChanged<bool> onStreamingChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SettingsSectionCard(
      title: 'Multi-Provider AI Orchestration',
      subtitle: 'Configure Gemini, OpenAI, and Claude models, encrypted keys, routing, and live connection checks.',
      children: [
        for (final provider in AiProviderType.values) ...[
          _ProviderCardBlock(
            provider: provider,
            isDefault: settings.selectedAiProvider == provider,
            isEnabled: settings.isProviderEnabled(provider),
            modelId: settings.modelForProvider(provider),
            hasKey: keyMap[provider] ?? false,
            runtimeStatus: connectionMap[provider],
            onSelectDefault: () => onSelectDefaultProvider(provider),
            onToggleEnabled: (val) => onToggleProviderEnabled(provider, val),
            onChooseModel: (discovered) => onChooseModel(provider, discovered),
            onConfigureKey: () =>
                onConfigureKey(provider, keyMap[provider] ?? false),
            onTestConnection: () => onTestConnection(provider),
          ),
          Divider(height: 1, color: colorScheme.outline.withValues(alpha: 0.4)),
        ],
        SettingsTile(
          icon: Icons.auto_awesome_mosaic_outlined,
          title: 'Automatic AI Routing',
          subtitle: 'Route complex reasoning/coding vs quick queries automatically across enabled providers',
          trailing: Switch.adaptive(
            value: settings.autoRoutingEnabled,
            onChanged: onAutoRoutingChanged,
          ),
          onTap: () => onAutoRoutingChanged(!settings.autoRoutingEnabled),
        ),
        SettingsTile(
          icon: Icons.alt_route_rounded,
          title: 'Provider Fallback',
          subtitle: 'Fall back to another enabled provider if primary fails (always informs you)',
          trailing: Switch.adaptive(
            value: settings.fallbackEnabled,
            onChanged: onFallbackChanged,
          ),
          onTap: () => onFallbackChanged(!settings.fallbackEnabled),
        ),
        SettingsTile(
          icon: Icons.bolt_outlined,
          title: 'Streaming Responses (SSE)',
          subtitle: 'Stream assistant replies incrementally as tokens arrive',
          trailing: Switch.adaptive(
            value: settings.streamingEnabled,
            onChanged: onStreamingChanged,
          ),
          onTap: () => onStreamingChanged(!settings.streamingEnabled),
        ),
      ],
    );
  }
}

class _ProviderCardBlock extends StatelessWidget {
  const _ProviderCardBlock({
    required this.provider,
    required this.isDefault,
    required this.isEnabled,
    required this.modelId,
    required this.hasKey,
    required this.runtimeStatus,
    required this.onSelectDefault,
    required this.onToggleEnabled,
    required this.onChooseModel,
    required this.onConfigureKey,
    required this.onTestConnection,
  });

  final AiProviderType provider;
  final bool isDefault;
  final bool isEnabled;
  final String modelId;
  final bool hasKey;
  final ProviderRuntimeStatus? runtimeStatus;
  final VoidCallback onSelectDefault;
  final ValueChanged<bool> onToggleEnabled;
  final ValueChanged<List<String>> onChooseModel;
  final VoidCallback onConfigureKey;
  final VoidCallback onTestConnection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final state =
        runtimeStatus?.connectionState ?? ProviderConnectionState.untested;

    final badgeLabel = switch (state) {
      ProviderConnectionState.connected => 'Connected',
      ProviderConnectionState.testing => 'Testing...',
      ProviderConnectionState.failed => 'Failed',
      ProviderConnectionState.missingKey => 'Missing Key',
      ProviderConnectionState.disabled => 'Disabled',
      ProviderConnectionState.untested => hasKey ? 'Untested' : 'Missing Key',
    };
    final badgeColor = switch (state) {
      ProviderConnectionState.connected => AppColors.success,
      ProviderConnectionState.failed => AppColors.error,
      ProviderConnectionState.testing => AppColors.cyanAccent,
      ProviderConnectionState.disabled => colorScheme.onSurfaceVariant,
      _ => AppColors.warning,
    };

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: onSelectDefault,
                  borderRadius: BorderRadius.circular(20),
                  child: Row(
                    children: [
                      Icon(
                        isDefault
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_off_rounded,
                        size: 20,
                        color: isDefault
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          provider.displayName,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              VisionStatusBadge(label: badgeLabel, indicatorColor: badgeColor),
              const SizedBox(width: 6),
              Switch.adaptive(value: isEnabled, onChanged: onToggleEnabled),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            runtimeStatus?.statusMessage ?? provider.summary,
            style: theme.textTheme.bodySmall?.copyWith(
              color: state == ProviderConnectionState.failed
                  ? AppColors.error
                  : colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => onChooseModel(
                  runtimeStatus?.availableModels ?? const <String>[],
                ),
                icon: const Icon(Icons.memory_rounded, size: 16),
                label: Text('Model: $modelId'),
              ),
              OutlinedButton.icon(
                onPressed: onConfigureKey,
                icon: const Icon(Icons.key_rounded, size: 16),
                label: Text(hasKey ? 'Update Key' : 'Add Key'),
              ),
              FilledButton.tonalIcon(
                onPressed:
                    (hasKey &&
                        isEnabled &&
                        state != ProviderConnectionState.testing)
                    ? onTestConnection
                    : null,
                icon: const Icon(Icons.wifi_tethering_rounded, size: 16),
                label: Text(
                  state == ProviderConnectionState.testing
                      ? 'Testing...'
                      : 'Test Connection',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VoiceAndAssistantSection extends StatelessWidget {
  const _VoiceAndAssistantSection({
    required this.settings,
    required this.voiceState,
    required this.onLanguageSelected,
    required this.onAutoSpeakChanged,
    required this.onWakeWordChanged,
    required this.onWakeBackgroundChanged,
    required this.onSensitivityChanged,
    required this.onRequestDefaultAssistant,
    required this.onOpenOverlayPreview,
    required this.onOpenBatteryOptimization,
  });

  final AppSettings settings;
  final VoiceSessionState voiceState;
  final ValueChanged<VoiceLanguage> onLanguageSelected;
  final ValueChanged<bool> onAutoSpeakChanged;
  final ValueChanged<bool> onWakeWordChanged;
  final ValueChanged<bool> onWakeBackgroundChanged;
  final ValueChanged<double> onSensitivityChanged;
  final VoidCallback onRequestDefaultAssistant;
  final VoidCallback onOpenOverlayPreview;
  final VoidCallback onOpenBatteryOptimization;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final selectedLanguage = settings.selectedVoiceLanguage;

    return SettingsSectionCard(
      title: 'Voice, "Hey VISION" & System Assistant',
      subtitle: 'Multilingual STT/TTS, offline foreground wake-word standby, and Android Default Assistant role.',
      children: [
        for (final language in VoiceLanguage.values)
          SettingsTile(
            icon: Icons.translate_rounded,
            title: language.nativeName,
            subtitle: '${language.displayName} • ${language.localeCode}',
            trailing: Icon(
              language == selectedLanguage
                  ? Icons.check_circle_rounded
                  : Icons.circle_outlined,
              color: language == selectedLanguage
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
            onTap: () => onLanguageSelected(language),
          ),
        SettingsTile(
          icon: Icons.volume_up_outlined,
          title: 'Auto-Speak AI Replies (TTS)',
          subtitle: 'Speak assistant responses aloud in your selected language',
          trailing: Switch.adaptive(
            value: settings.autoSpeakReplies,
            onChanged: onAutoSpeakChanged,
          ),
          onTap: () => onAutoSpeakChanged(!settings.autoSpeakReplies),
        ),
        SettingsTile(
          icon: Icons.hearing_rounded,
          title: '"Hey VISION" Wake-Word Standby',
          subtitle: voiceState.isWakeServiceRunning
              ? (voiceState.isWakeMicActive
                    ? 'Offline AudioRecord foreground service active'
                    : 'Wake service paused while speech/TTS is active')
              : 'Offline low-CPU DSP wake-word detector (no cloud audio streaming)',
          trailing: Switch.adaptive(
            value: settings.wakeWordEnabled,
            onChanged: onWakeWordChanged,
          ),
          onTap: () => onWakeWordChanged(!settings.wakeWordEnabled),
        ),
        SettingsTile(
          icon: Icons.notifications_active_outlined,
          title: 'Background Mic Foreground Service',
          subtitle: 'Keep visible microphone notification active while app is minimized',
          trailing: Switch.adaptive(
            value: settings.wakeWordBackgroundEnabled,
            onChanged: onWakeBackgroundChanged,
          ),
          onTap: () =>
              onWakeBackgroundChanged(!settings.wakeWordBackgroundEnabled),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Wake-Word Sensitivity',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Text(
                    '${(settings.wakeWordSensitivity * 100).round()}%',
                    style: Theme.of(context).textTheme.labelMedium
                        ?.copyWith(color: colorScheme.primary),
                  ),
                ],
              ),
              Slider(
                value: settings.wakeWordSensitivity,
                min: 0.2,
                max: 0.9,
                divisions: 14,
                onChanged: onSensitivityChanged,
              ),
            ],
          ),
        ),
        SettingsTile(
          icon: Icons.assistant_rounded,
          title: 'Default Digital Assistant (ROLE_ASSISTANT)',
          subtitle: voiceState.isDefaultAssistant
              ? 'VISION is active as your Android Default Assistant'
              : 'Set VISION as Android default assistant for Assist gestures & overlay',
          trailing: VisionStatusBadge(
            label: voiceState.isDefaultAssistant ? 'Active' : 'Configure',
            indicatorColor: voiceState.isDefaultAssistant
                ? AppColors.success
                : AppColors.warning,
          ),
          onTap: onRequestDefaultAssistant,
        ),
        SettingsTile(
          icon: Icons.layers_rounded,
          title: 'Launch Assistant Overlay Sheet',
          subtitle: 'Preview Gemini-like floating voice assistant interface',
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onOpenOverlayPreview,
        ),
        SettingsTile(
          icon: Icons.battery_saver_rounded,
          title: 'OPPO ColorOS Battery Optimization',
          subtitle: 'Allow unrestricted background activity so ColorOS keeps standby alive',
          trailing: const Icon(Icons.open_in_new_rounded, size: 18),
          onTap: onOpenBatteryOptimization,
        ),
      ],
    );
  }
}

class _DeviceAutomationSection extends StatelessWidget {
  const _DeviceAutomationSection({
    required this.settings,
    required this.onDeviceActionsChanged,
    required this.onDirectCallsChanged,
    required this.onNotificationConsentChanged,
    required this.onOpenDeviceControlHub,
  });

  final AppSettings settings;
  final ValueChanged<bool> onDeviceActionsChanged;
  final ValueChanged<bool> onDirectCallsChanged;
  final ValueChanged<bool> onNotificationConsentChanged;
  final VoidCallback onOpenDeviceControlHub;

  @override
  Widget build(BuildContext context) {
    return SettingsSectionCard(
      title: 'Device Automation & Control',
      subtitle: 'Manage Android system intents, permission-guarded phone calls, WhatsApp, and notifications.',
      children: [
        SettingsTile(
          icon: Icons.bolt_rounded,
          title: 'Voice & Chat Device Commands',
          subtitle: 'Allow commands like alarms, timers, app launches, and system settings',
          trailing: Switch.adaptive(
            value: settings.deviceActionsEnabled,
            onChanged: onDeviceActionsChanged,
          ),
          onTap: () => onDeviceActionsChanged(!settings.deviceActionsEnabled),
        ),
        SettingsTile(
          icon: Icons.call_rounded,
          title: 'Direct Phone Calls (CALL_PHONE)',
          subtitle: 'Place calls directly after confirmation instead of opening the dialer',
          trailing: Switch.adaptive(
            value: settings.directPhoneCallsEnabled,
            onChanged: onDirectCallsChanged,
          ),
          onTap: () => onDirectCallsChanged(!settings.directPhoneCallsEnabled),
        ),
        SettingsTile(
          icon: Icons.notifications_none_rounded,
          title: 'Local Notification Reader Consent',
          subtitle: 'Allow reading recent notifications locally when asked (requires Android Notification Access)',
          trailing: Switch.adaptive(
            value: settings.notificationListenerConsent,
            onChanged: onNotificationConsentChanged,
          ),
          onTap: () => onNotificationConsentChanged(
            !settings.notificationListenerConsent,
          ),
        ),
        SettingsTile(
          icon: Icons.phonelink_setup_rounded,
          title: 'Device Control Hub',
          subtitle: 'Test permissions, inspect OPPO Reno 16 telemetry, and run system actions',
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onOpenDeviceControlHub,
        ),
      ],
    );
  }
}

class _SystemInfoSection extends StatelessWidget {
  const _SystemInfoSection({
    required this.onOpenOnboarding,
    required this.onResetDefaults,
  });

  final VoidCallback onOpenOnboarding;
  final VoidCallback onResetDefaults;

  @override
  Widget build(BuildContext context) {
    return SettingsSectionCard(
      title: 'System & Architecture',
      subtitle: 'Application build metadata and diagnostics',
      children: [
        const SettingsTile(
          icon: Icons.apps_rounded,
          title: 'Application ID',
          subtitle: AppConstants.applicationId,
        ),
        const SettingsTile(
          icon: Icons.phone_android_rounded,
          title: 'Target Hardware Profile',
          subtitle: AppConstants.targetDeviceName,
        ),
        const SettingsTile(
          icon: Icons.tag_rounded,
          title: 'Version',
          subtitle: AppConstants.appVersion,
        ),
        SettingsTile(
          icon: Icons.layers_outlined,
          title: 'Architecture & Roadmap',
          subtitle: 'Inspect verified phase completion status',
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onOpenOnboarding,
        ),
        SettingsTile(
          icon: Icons.restore_rounded,
          title: 'Reset Preferences',
          subtitle: 'Restore default dark theme and configuration',
          onTap: onResetDefaults,
        ),
      ],
    );
  }
}
