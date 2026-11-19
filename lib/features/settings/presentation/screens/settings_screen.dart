import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/app/router/app_routes.dart';
import 'package:vision_ai/core/constants/app_constants.dart';
import 'package:vision_ai/core/theme/vision_colors.dart';
import 'package:vision_ai/core/theme/vision_radii.dart';
import 'package:vision_ai/core/theme/vision_spacing.dart';
import 'package:vision_ai/core/widgets/glass/vision_glass_widgets.dart';
import 'package:vision_ai/core/widgets/vision_app_bar.dart';
import 'package:vision_ai/core/widgets/vision_scaffold.dart';
import 'package:vision_ai/core/widgets/vision_status_badge.dart';
import 'package:vision_ai/features/automation/domain/entities/device_action.dart';
import 'package:vision_ai/features/automation/presentation/controllers/automation_controller.dart';
import 'package:vision_ai/features/automation/presentation/controllers/trusted_commands_controller.dart';
import 'package:vision_ai/features/automation/presentation/widgets/trusted_commands_sheet.dart';
import 'package:vision_ai/features/chat/domain/entities/ai_model_config.dart';
import 'package:vision_ai/features/chat/domain/entities/ai_models.dart';
import 'package:vision_ai/features/chat/domain/entities/ai_usage_stats.dart';
import 'package:vision_ai/features/chat/presentation/controllers/chat_controller.dart';
import 'package:vision_ai/features/chat/presentation/controllers/usage_stats_controller.dart';
import 'package:vision_ai/features/memory/presentation/controllers/memory_controller.dart';
import 'package:vision_ai/features/memory/presentation/widgets/personal_memory_sheet.dart';
import 'package:vision_ai/features/settings/domain/entities/ai_provider_type.dart';
import 'package:vision_ai/features/settings/domain/entities/app_settings.dart';
import 'package:vision_ai/features/settings/domain/entities/voice_language.dart';
import 'package:vision_ai/features/settings/presentation/controllers/api_key_controller.dart';
import 'package:vision_ai/features/settings/presentation/controllers/provider_connection_controller.dart';
import 'package:vision_ai/features/settings/presentation/controllers/settings_controller.dart';
import 'package:vision_ai/features/settings/presentation/widgets/api_key_config_dialog.dart';
import 'package:vision_ai/features/settings/presentation/widgets/assistant_identity_section.dart';
import 'package:vision_ai/features/settings/presentation/widgets/coloros_setup_guide_sheet.dart';
import 'package:vision_ai/features/settings/presentation/widgets/settings_section_card.dart';
import 'package:vision_ai/features/settings/presentation/widgets/settings_tile.dart';
import 'package:vision_ai/features/voice/domain/entities/voice_session_state.dart';
import 'package:vision_ai/features/voice/presentation/controllers/voice_controller.dart';

enum _SettingsCategory { all, ai, voice, system }

/// Liquid Glass Settings dashboard covering General, Appearance, AI Providers,
/// Voice & Language, Wake Word, Permissions, Automation, Memory, Privacy, and About.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  _SettingsCategory _category = _SettingsCategory.all;

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
        unawaited(
          ref.read(automationControllerProvider.notifier).refreshEnvironment(),
        );
      }
    });
  }

  void _triggerHaptic(AppSettings settings) {
    if (settings.hapticFeedbackEnabled) {
      HapticFeedback.selectionClick();
    }
  }

  Future<void> _openApiKeyDialog(
    AiProviderType provider,
    bool hasKey,
    AppSettings settings,
  ) async {
    _triggerHaptic(settings);
    final result = await showVisionGlassDialog<bool>(
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
    final selected = await showVisionGlassDialog<String>(
      context: context,
      builder: (dialogContext) => VisionGlassDialog(
        title: '${provider.displayName} Model',
        icon: Icons.memory_rounded,
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: SingleChildScrollView(
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
                          ? VisionColors.primaryAccent(
                              Theme.of(dialogContext).brightness,
                            )
                          : VisionColors.secondaryText(
                              Theme.of(dialogContext).brightness,
                            ),
                    ),
                    title: Text(modelId),
                    onTap: () => Navigator.of(dialogContext).pop(modelId),
                  ),
                const SizedBox(height: 12),
                VisionGlassInput(
                  controller: customController,
                  labelText: 'Custom Model ID',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          VisionGlassButton(
            label: 'Apply',
            compact: true,
            onPressed: () =>
                Navigator.of(dialogContext).pop(customController.text.trim()),
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
        backgroundColor: result.connected
            ? VisionColors.success
            : VisionColors.error,
      ),
    );
  }

  Future<void> _openVoicePickerDialog(AppSettings settings) async {
    final localeArg = settings.selectedVoiceLanguage == VoiceLanguage.auto
        ? null
        : settings.selectedVoiceLanguage.localeCode;
    final voices = await ref
        .read(voiceControllerProvider.notifier)
        .getAvailableVoices(locale: localeArg);
    if (!mounted) return;

    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Select Native Android Voice'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  title: const Text('System Default Voice'),
                  subtitle: const Text('Match active language automatically'),
                  trailing: settings.ttsVoiceName.isEmpty
                      ? const Icon(Icons.check_rounded)
                      : null,
                  onTap: () => Navigator.of(dialogContext).pop(''),
                ),
                if (voices.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'No extra Android TTS voices reported on this host. '
                      'Installed voices appear on Android hardware.',
                    ),
                  )
                else
                  for (final voice in voices)
                    ListTile(
                      title: Text(voice.friendlyLabel),
                      subtitle: Text(voice.name),
                      trailing: settings.ttsVoiceName == voice.name
                          ? const Icon(Icons.check_rounded)
                          : null,
                      onTap: () => Navigator.of(dialogContext).pop(voice.name),
                    ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
    if (selected != null) {
      await ref
          .read(settingsControllerProvider.notifier)
          .setTtsVoiceName(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);
    final voiceState = ref.watch(voiceControllerProvider);
    final chatState = ref.watch(chatControllerProvider);
    final usageStats = ref.watch(usageStatsControllerProvider);
    final memoryState = ref.watch(memoryControllerProvider);
    final automationState = ref.watch(automationControllerProvider);
    final keyStatusAsync = ref.watch(apiKeyStatusControllerProvider);
    final connectionMap = ref.watch(providerConnectionControllerProvider);
    final keyMap =
        keyStatusAsync.asData?.value ?? const <AiProviderType, bool>{};

    final showGeneral =
        _category == _SettingsCategory.all ||
        _category == _SettingsCategory.system;
    final showAppearance =
        _category == _SettingsCategory.all ||
        _category == _SettingsCategory.system;
    final showAi =
        _category == _SettingsCategory.all || _category == _SettingsCategory.ai;
    final showVoice =
        _category == _SettingsCategory.all ||
        _category == _SettingsCategory.voice;
    final showSystem =
        _category == _SettingsCategory.all ||
        _category == _SettingsCategory.system;

    return VisionScaffold(
      appBar: const VisionAppBar(
        title: 'SETTINGS',
        subtitle: 'AI Providers, Voice, Memory & Privacy',
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: VisionSpacing.navBarClearance),
        children: [
          const SizedBox(height: 4),
          _CategoryFilterStrip(
            selected: _category,
            onSelected: (cat) {
              _triggerHaptic(settings);
              setState(() => _category = cat);
            },
          ),
          const SizedBox(height: 18),

          if (showGeneral) ...[
            _GeneralSection(
              settings: settings,
              onOpenAssistant: () {
                _triggerHaptic(settings);
                context.push(AppRoutes.assistantPath);
              },
              onOpenRoadmap: () {
                _triggerHaptic(settings);
                context.push(AppRoutes.onboardingPath);
              },
            ),
            const SizedBox(height: 20),
          ],

          if (showAppearance) ...[
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
            const SizedBox(height: 20),
          ],

          if (showAi) ...[
            AssistantIdentitySection(
              identity: settings.assistantIdentity,
              onIdentityChanged: (identity) async {
                _triggerHaptic(settings);
                await controller.setAssistantIdentity(identity);
              },
            ),
            const SizedBox(height: 20),
            _MultiProviderAiSection(
              settings: settings,
              keyMap: keyMap,
              connectionMap: connectionMap,
              usageStats: usageStats,
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
              onFallbackChanged: (enabled) =>
                  controller.setFallbackEnabled(enabled: enabled),
              onStreamingChanged: (enabled) =>
                  controller.setStreamingEnabled(enabled: enabled),
              onResetUsage: () async {
                _triggerHaptic(settings);
                await ref
                    .read(usageStatsControllerProvider.notifier)
                    .clearUsage();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Local AI usage counters cleared.'),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 20),
          ],

          if (showVoice) ...[
            _VoiceAndLanguageSection(
              settings: settings,
              onLanguageSelected: (language) async {
                _triggerHaptic(settings);
                await controller.setVoiceLanguage(language);
              },
              onAutoSpeakChanged: (enabled) =>
                  controller.setAutoSpeakReplies(enabled: enabled),
              onEndpointSilenceChanged: (silenceMs) =>
                  controller.setVoiceEndpointSilenceMs(silenceMs),
              onSpeechRateChanged: (rate) => controller.setTtsSpeechRate(rate),
              onPitchChanged: (pitch) => controller.setTtsPitch(pitch),
              onSelectVoice: () => _openVoicePickerDialog(settings),
              onPreviewVoice: () => ref
                  .read(voiceControllerProvider.notifier)
                  .speakReply(
                    'Hello, I am VISION. Your intelligence. Your assistant.',
                  ),
            ),
            const SizedBox(height: 20),
            _WakeWordSection(
              settings: settings,
              voiceState: voiceState,
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
              onOpenOverlayPreview: () {
                unawaited(
                  ref
                      .read(voiceControllerProvider.notifier)
                      .openAssistantOverlay(),
                );
              },
            ),
            const SizedBox(height: 20),
          ],

          if (showSystem) ...[
            _PermissionsSection(
              voiceState: voiceState,
              automationState: automationState,
              onRequestMic: () => unawaited(
                ref
                    .read(voiceControllerProvider.notifier)
                    .startCommandListening(),
              ),
              onRequestContacts: () => unawaited(
                ref
                    .read(automationControllerProvider.notifier)
                    .requestPermission(AutomationPermission.readContacts),
              ),
              onRequestCall: () => unawaited(
                ref
                    .read(automationControllerProvider.notifier)
                    .requestPermission(AutomationPermission.callPhone),
              ),
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
              onOpenColorOsGuide: () {
                _triggerHaptic(settings);
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => VisionGlassBottomSheet(
                    child: ColorOsSetupGuideSheet(
                      isDefaultAssistant: voiceState.isDefaultAssistant,
                      onOpenBatterySettings: () {
                        unawaited(
                          ref
                              .read(automationControllerProvider.notifier)
                              .executeRequest(
                                const DeviceActionRequest(
                                  type: DeviceActionType.openSettings,
                                  target: 'battery_optimization',
                                  displaySummary:
                                      'Open battery optimization settings',
                                ),
                              ),
                        );
                      },
                      onRequestDefaultAssistant: () {
                        unawaited(
                          ref
                              .read(voiceControllerProvider.notifier)
                              .requestDefaultAssistantRole(),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
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
                context.go(AppRoutes.automationPath);
              },
              onManageTrustedCommands: () {
                _triggerHaptic(settings);
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const VisionGlassBottomSheet(
                    child: TrustedCommandsSheet(),
                  ),
                );
              },
              trustedCount: ref
                  .watch(trustedCommandsControllerProvider)
                  .trustedSensitiveActions
                  .length,
              blockedNotifCount: ref
                  .watch(trustedCommandsControllerProvider)
                  .blockedNotificationPackages
                  .length,
            ),
            const SizedBox(height: 20),
            _MemorySection(
              messageCount: chatState.messages.length,
              saveConversationHistory: settings.saveConversationHistory,
              personalMemoryEnabled: memoryState.memoryEnabled,
              personalMemoryCount: memoryState.entries.length,
              onSaveConversationHistoryChanged: (enabled) async {
                _triggerHaptic(settings);
                await controller.setSaveConversationHistory(enabled: enabled);
              },
              onManagePersonalMemory: () {
                _triggerHaptic(settings);
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const VisionGlassBottomSheet(
                    child: PersonalMemorySheet(),
                  ),
                );
              },
              onClearMemory: () async {
                _triggerHaptic(settings);
                await ref
                    .read(chatControllerProvider.notifier)
                    .clearConversation();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Local conversation memory cleared.'),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 20),
            _PrivacySection(
              configuredKeyCount: keyMap.values.where((v) => v).length,
            ),
            const SizedBox(height: 20),
            _AboutVisionSection(
              onOpenOnboarding: () {
                _triggerHaptic(settings);
                context.push(AppRoutes.onboardingPath);
              },
              onOpenDiagnostics: () {
                _triggerHaptic(settings);
                context.push(AppRoutes.diagnosticsPath);
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
        ],
      ),
    );
  }
}

class _CategoryFilterStrip extends StatelessWidget {
  const _CategoryFilterStrip({
    required this.selected,
    required this.onSelected,
  });

  final _SettingsCategory selected;
  final ValueChanged<_SettingsCategory> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          VisionGlassChip(
            label: 'All Sections',
            icon: Icons.dashboard_outlined,
            selected: selected == _SettingsCategory.all,
            onTap: () => onSelected(_SettingsCategory.all),
          ),
          const SizedBox(width: 8),
          VisionGlassChip(
            label: 'AI Providers',
            icon: Icons.hub_outlined,
            selected: selected == _SettingsCategory.ai,
            onTap: () => onSelected(_SettingsCategory.ai),
          ),
          const SizedBox(width: 8),
          VisionGlassChip(
            label: 'Voice & Wake',
            icon: Icons.mic_none_rounded,
            selected: selected == _SettingsCategory.voice,
            onTap: () => onSelected(_SettingsCategory.voice),
          ),
          const SizedBox(width: 8),
          VisionGlassChip(
            label: 'System & Privacy',
            icon: Icons.shield_outlined,
            selected: selected == _SettingsCategory.system,
            onTap: () => onSelected(_SettingsCategory.system),
          ),
        ],
      ),
    );
  }
}

class _GeneralSection extends StatelessWidget {
  const _GeneralSection({
    required this.settings,
    required this.onOpenAssistant,
    required this.onOpenRoadmap,
  });

  final AppSettings settings;
  final VoidCallback onOpenAssistant;
  final VoidCallback onOpenRoadmap;

  @override
  Widget build(BuildContext context) {
    return SettingsSectionCard(
      title: 'General',
      icon: Icons.tune_rounded,
      subtitle: 'Assistant shortcuts and active configuration overview',
      children: [
        SettingsTile(
          icon: Icons.auto_awesome_rounded,
          title: 'Direct Voice Assistant Mode',
          subtitle: 'Launch full-screen animated orb & hands-free session',
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onOpenAssistant,
        ),
        SettingsTile(
          icon: Icons.hub_outlined,
          title: 'Active Provider & Model',
          subtitle:
              '${settings.selectedAiProvider.displayName} • ${settings.selectedModelId}',
        ),
        SettingsTile(
          icon: Icons.timeline_rounded,
          title: 'Implementation Roadmap',
          subtitle: AppConstants.currentPhaseLabel,
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onOpenRoadmap,
        ),
      ],
    );
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
      title: 'Appearance',
      icon: Icons.palette_outlined,
      subtitle: 'Liquid Glass theme mode and tactile feedback',
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
              VisionGlassTabBar<ThemeMode>(
                selectedValue: settings.themeMode,
                onSelected: onThemeSelected,
                items: const [
                  (
                    value: ThemeMode.dark,
                    label: 'Dark',
                    icon: Icons.dark_mode_outlined,
                  ),
                  (
                    value: ThemeMode.light,
                    label: 'Light',
                    icon: Icons.light_mode_outlined,
                  ),
                  (
                    value: ThemeMode.system,
                    label: 'System',
                    icon: Icons.brightness_auto_outlined,
                  ),
                ],
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
    required this.usageStats,
    required this.onSelectDefaultProvider,
    required this.onToggleProviderEnabled,
    required this.onChooseModel,
    required this.onConfigureKey,
    required this.onTestConnection,
    required this.onFallbackChanged,
    required this.onStreamingChanged,
    required this.onResetUsage,
  });

  final AppSettings settings;
  final Map<AiProviderType, bool> keyMap;
  final Map<AiProviderType, ProviderRuntimeStatus> connectionMap;
  final UsageStatsState usageStats;
  final ValueChanged<AiProviderType> onSelectDefaultProvider;
  final void Function(AiProviderType provider, bool enabled)
  onToggleProviderEnabled;
  final void Function(AiProviderType provider, List<String> discovered)
  onChooseModel;
  final void Function(AiProviderType provider, bool hasKey) onConfigureKey;
  final ValueChanged<AiProviderType> onTestConnection;
  final ValueChanged<bool> onFallbackChanged;
  final ValueChanged<bool> onStreamingChanged;
  final VoidCallback onResetUsage;

  @override
  Widget build(BuildContext context) {
    return SettingsSectionCard(
      title: 'AI Providers',
      icon: Icons.hub_outlined,
      subtitle: 'Manual provider & model selection across Gemini, OpenAI, and Claude with encrypted keys and local usage tracking.',
      children: [
        for (final provider in AiProviderType.values)
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
        SettingsTile(
          icon: Icons.alt_route_rounded,
          title: 'Opt-In Provider Fallback',
          subtitle: 'OFF by default. When enabled, falls back to another enabled provider if your selected provider fails (always displays a notice)',
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
        SettingsTile(
          icon: Icons.bar_chart_rounded,
          title: 'Local Usage Counters',
          subtitle:
              '${usageStats.totalRequests} request${usageStats.totalRequests == 1 ? '' : 's'} • '
              '${usageStats.totalInputTokens} in / ${usageStats.totalOutputTokens} out tokens',
          trailing: usageStats.totalRequests > 0
              ? TextButton(
                  onPressed: onResetUsage,
                  child: const Text('Reset'),
                )
              : null,
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
    final brightness = theme.brightness;
    final accent = VisionColors.primaryAccent(brightness);
    final state =
        runtimeStatus?.connectionState ?? ProviderConnectionState.untested;

    final badgeLabel = switch (state) {
      ProviderConnectionState.connected =>
        runtimeStatus?.latency != null
            ? 'Connected • ${runtimeStatus!.latency!.inMilliseconds}ms'
            : 'Connected',
      ProviderConnectionState.testing => 'Testing...',
      ProviderConnectionState.failed => 'Failed',
      ProviderConnectionState.missingKey => 'Missing Key',
      ProviderConnectionState.disabled => 'Disabled',
      ProviderConnectionState.untested => hasKey ? 'Untested' : 'Missing Key',
    };
    final badgeColor = switch (state) {
      ProviderConnectionState.connected => VisionColors.success,
      ProviderConnectionState.failed => VisionColors.error,
      ProviderConnectionState.testing => VisionColors.accentPrimary,
      ProviderConnectionState.disabled => VisionColors.mutedText(brightness),
      _ => VisionColors.warning,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: isDefault
          ? BoxDecoration(
              color: accent.withValues(
                alpha: brightness == Brightness.dark ? 0.06 : 0.05,
              ),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: onSelectDefault,
                  borderRadius: VisionRadii.pillBorder,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          isDefault
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded,
                          size: 20,
                          color: isDefault
                              ? accent
                              : VisionColors.secondaryText(brightness),
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
              ),
              const SizedBox(width: 8),
              VisionStatusBadge(
                label: badgeLabel,
                indicatorColor: badgeColor,
                compact: true,
              ),
              const SizedBox(width: 6),
              Switch.adaptive(value: isEnabled, onChanged: onToggleEnabled),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            runtimeStatus?.statusMessage ?? provider.summary,
            style: theme.textTheme.bodySmall?.copyWith(
              color: state == ProviderConnectionState.failed
                  ? VisionColors.error
                  : VisionColors.secondaryText(brightness),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              VisionGlassChip(
                icon: Icons.memory_rounded,
                label: modelId,
                compact: true,
                onTap: () => onChooseModel(
                  runtimeStatus?.availableModels ?? const <String>[],
                ),
              ),
              VisionGlassChip(
                icon: Icons.key_rounded,
                label: hasKey ? 'Update Key' : 'Add Key',
                compact: true,
                accentColor: hasKey
                    ? VisionColors.success
                    : VisionColors.warning,
                selected: !hasKey,
                onTap: onConfigureKey,
              ),
              VisionGlassButton(
                label: state == ProviderConnectionState.testing
                    ? 'Testing...'
                    : 'Test Connection',
                icon: Icons.wifi_tethering_rounded,
                compact: true,
                style: VisionGlassButtonStyle.tonal,
                isLoading: state == ProviderConnectionState.testing,
                onPressed:
                    (hasKey &&
                        isEnabled &&
                        state != ProviderConnectionState.testing)
                    ? onTestConnection
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VoiceAndLanguageSection extends StatelessWidget {
  const _VoiceAndLanguageSection({
    required this.settings,
    required this.onLanguageSelected,
    required this.onAutoSpeakChanged,
    required this.onEndpointSilenceChanged,
    required this.onSpeechRateChanged,
    required this.onPitchChanged,
    required this.onSelectVoice,
    required this.onPreviewVoice,
  });

  final AppSettings settings;
  final ValueChanged<VoiceLanguage> onLanguageSelected;
  final ValueChanged<bool> onAutoSpeakChanged;
  final ValueChanged<int> onEndpointSilenceChanged;
  final ValueChanged<double> onSpeechRateChanged;
  final ValueChanged<double> onPitchChanged;
  final VoidCallback onSelectVoice;
  final VoidCallback onPreviewVoice;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final accent = VisionColors.primaryAccent(brightness);
    final selectedLanguage = settings.selectedVoiceLanguage;

    return SettingsSectionCard(
      title: 'Voice & Language',
      icon: Icons.translate_rounded,
      subtitle: 'Multilingual Speech-to-Text and Text-to-Speech output',
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
                  ? accent
                  : VisionColors.secondaryText(brightness),
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Speech Pause Tolerance',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: VisionColors.primaryText(brightness),
                    ),
                  ),
                  Text(
                    '${(settings.voiceEndpointSilenceMs / 1000).toStringAsFixed(1)}s',
                    style: Theme.of(
                      context,
                    ).textTheme.labelMedium?.copyWith(color: accent),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'How long VISION waits after a pause before finalizing your speech.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: VisionColors.secondaryText(brightness),
                ),
              ),
              Slider(
                value: settings.voiceEndpointSilenceMs
                    .clamp(2000, 6500)
                    .toDouble(),
                min: 2000,
                max: 6500,
                divisions: 9,
                onChanged: (value) =>
                    onEndpointSilenceChanged(value.round()),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Speech Rate',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: VisionColors.primaryText(brightness),
                    ),
                  ),
                  Text(
                    '${settings.ttsSpeechRate.toStringAsFixed(2)}x',
                    style: Theme.of(
                      context,
                    ).textTheme.labelMedium?.copyWith(color: accent),
                  ),
                ],
              ),
              Slider(
                value: settings.ttsSpeechRate.clamp(0.5, 2.0),
                min: 0.5,
                max: 2.0,
                divisions: 15,
                onChanged: onSpeechRateChanged,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Voice Pitch',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: VisionColors.primaryText(brightness),
                    ),
                  ),
                  Text(
                    '${settings.ttsPitch.toStringAsFixed(2)}x',
                    style: Theme.of(
                      context,
                    ).textTheme.labelMedium?.copyWith(color: accent),
                  ),
                ],
              ),
              Slider(
                value: settings.ttsPitch.clamp(0.5, 2.0),
                min: 0.5,
                max: 2.0,
                divisions: 15,
                onChanged: onPitchChanged,
              ),
            ],
          ),
        ),
        SettingsTile(
          icon: Icons.record_voice_over_outlined,
          title: 'Native Android TTS Voice',
          subtitle: settings.ttsVoiceName.isEmpty
              ? 'System default voice (auto-matched to language)'
              : settings.ttsVoiceName,
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onSelectVoice,
        ),
        SettingsTile(
          icon: Icons.play_circle_outline_rounded,
          title: 'Preview Voice',
          subtitle: 'Speak a short sample using your active voice, rate, and pitch',
          trailing: const Icon(Icons.volume_up_rounded, size: 18),
          onTap: onPreviewVoice,
        ),
      ],
    );
  }
}

class _WakeWordSection extends StatelessWidget {
  const _WakeWordSection({
    required this.settings,
    required this.voiceState,
    required this.onWakeWordChanged,
    required this.onWakeBackgroundChanged,
    required this.onSensitivityChanged,
    required this.onOpenOverlayPreview,
  });

  final AppSettings settings;
  final VoiceSessionState voiceState;
  final ValueChanged<bool> onWakeWordChanged;
  final ValueChanged<bool> onWakeBackgroundChanged;
  final ValueChanged<double> onSensitivityChanged;
  final VoidCallback onOpenOverlayPreview;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final accent = VisionColors.primaryAccent(brightness);

    return SettingsSectionCard(
      title: 'Wake Word ("Hey VISION")',
      icon: Icons.hearing_rounded,
      subtitle:
          'Offline low-CPU DSP wake-word detector and system assistant overlay',
      children: [
        SettingsTile(
          icon: Icons.hearing_rounded,
          title: '"Hey VISION" Wake-Word Standby',
          subtitle: voiceState.isWakeServiceRunning
              ? (voiceState.isWakeMicActive
                    ? 'Offline AudioRecord foreground service active'
                    : 'Wake service paused while speech/TTS is active')
              : 'Offline AudioRecord DSP detector (zero cloud audio streaming)',
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Wake-Word Sensitivity',
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: VisionColors.primaryText(brightness)),
                  ),
                  Text(
                    '${(settings.wakeWordSensitivity * 100).round()}%',
                    style: Theme.of(context).textTheme.labelMedium
                        ?.copyWith(color: accent),
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
          icon: Icons.layers_rounded,
          title: 'Launch Assistant Overlay Sheet',
          subtitle: 'Preview system VoiceInteraction floating assistant sheet',
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onOpenOverlayPreview,
        ),
      ],
    );
  }
}

class _PermissionsSection extends StatelessWidget {
  const _PermissionsSection({
    required this.voiceState,
    required this.automationState,
    required this.onRequestMic,
    required this.onRequestContacts,
    required this.onRequestCall,
    required this.onRequestDefaultAssistant,
    required this.onOpenBatteryOptimization,
    required this.onOpenColorOsGuide,
  });

  final VoiceSessionState voiceState;
  final AutomationState automationState;
  final VoidCallback onRequestMic;
  final VoidCallback onRequestContacts;
  final VoidCallback onRequestCall;
  final VoidCallback onRequestDefaultAssistant;
  final VoidCallback onOpenBatteryOptimization;
  final VoidCallback onOpenColorOsGuide;

  @override
  Widget build(BuildContext context) {
    return SettingsSectionCard(
      title: 'Permissions',
      icon: Icons.admin_panel_settings_outlined,
      subtitle: 'Runtime Android permissions and OPPO ColorOS system roles',
      children: [
        SettingsTile(
          icon: Icons.mic_none_rounded,
          title: 'Microphone (RECORD_AUDIO)',
          subtitle: 'Required for STT voice input and "Hey VISION" standby',
          trailing: VisionStatusBadge(
            label: voiceState.hasMicPermission ? 'Granted' : 'Check',
            indicatorColor: voiceState.hasMicPermission
                ? VisionColors.success
                : VisionColors.warning,
            compact: true,
          ),
          onTap: onRequestMic,
        ),
        SettingsTile(
          icon: Icons.contacts_outlined,
          title: 'Contacts (READ_CONTACTS)',
          subtitle: 'Resolve contact names for calls, SMS, and WhatsApp',
          trailing: VisionStatusBadge(
            label: automationState.hasContactsPermission ? 'Granted' : 'Grant',
            indicatorColor: automationState.hasContactsPermission
                ? VisionColors.success
                : VisionColors.warning,
            compact: true,
          ),
          onTap: onRequestContacts,
        ),
        SettingsTile(
          icon: Icons.call_outlined,
          title: 'Phone Calls (CALL_PHONE)',
          subtitle: 'Required only when direct calling is enabled',
          trailing: VisionStatusBadge(
            label: automationState.hasCallPermission ? 'Granted' : 'Grant',
            indicatorColor: automationState.hasCallPermission
                ? VisionColors.success
                : VisionColors.warning,
            compact: true,
          ),
          onTap: onRequestCall,
        ),
        SettingsTile(
          icon: Icons.assistant_rounded,
          title: 'Default Digital Assistant (ROLE_ASSISTANT)',
          subtitle: voiceState.isDefaultAssistant
              ? 'VISION is active as your Android Default Assistant'
              : 'Set VISION for Android Assist gestures & lock-screen launch',
          trailing: VisionStatusBadge(
            label: voiceState.isDefaultAssistant ? 'Active' : 'Configure',
            indicatorColor: voiceState.isDefaultAssistant
                ? VisionColors.success
                : VisionColors.warning,
            compact: true,
          ),
          onTap: onRequestDefaultAssistant,
        ),
        SettingsTile(
          icon: Icons.battery_saver_rounded,
          title: 'OPPO ColorOS Battery Optimization',
          subtitle: 'Allow unrestricted background activity for wake-word',
          trailing: const Icon(Icons.open_in_new_rounded, size: 18),
          onTap: onOpenBatteryOptimization,
        ),
        SettingsTile(
          icon: Icons.checklist_rounded,
          title: 'OPPO Reno 16 / ColorOS Setup Guide',
          subtitle: 'Step-by-step Auto-launch, Recents lock & post-reboot recovery',
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onOpenColorOsGuide,
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
    required this.onManageTrustedCommands,
    required this.trustedCount,
    required this.blockedNotifCount,
  });

  final AppSettings settings;
  final ValueChanged<bool> onDeviceActionsChanged;
  final ValueChanged<bool> onDirectCallsChanged;
  final ValueChanged<bool> onNotificationConsentChanged;
  final VoidCallback onOpenDeviceControlHub;
  final VoidCallback onManageTrustedCommands;
  final int trustedCount;
  final int blockedNotifCount;

  @override
  Widget build(BuildContext context) {
    return SettingsSectionCard(
      title: 'Automation',
      icon: Icons.bolt_rounded,
      subtitle: 'Android system intents, permission-guarded calling, and notifications',
      children: [
        SettingsTile(
          icon: Icons.bolt_rounded,
          title: 'Voice & Chat Device Commands',
          subtitle:
              'Allow commands like alarms, timers, app launches, and settings',
          trailing: Switch.adaptive(
            value: settings.deviceActionsEnabled,
            onChanged: onDeviceActionsChanged,
          ),
          onTap: () => onDeviceActionsChanged(!settings.deviceActionsEnabled),
        ),
        SettingsTile(
          icon: Icons.call_rounded,
          title: 'Direct Phone Calls (ACTION_CALL)',
          subtitle: 'Place calls directly after confirmation instead of dialer',
          trailing: Switch.adaptive(
            value: settings.directPhoneCallsEnabled,
            onChanged: onDirectCallsChanged,
          ),
          onTap: () => onDirectCallsChanged(!settings.directPhoneCallsEnabled),
        ),
        SettingsTile(
          icon: Icons.notifications_none_rounded,
          title: 'Local Notification Reader Consent',
          subtitle: 'Allow reading recent notifications locally when asked (requires Notification Access)',
          trailing: Switch.adaptive(
            value: settings.notificationListenerConsent,
            onChanged: onNotificationConsentChanged,
          ),
          onTap: () => onNotificationConsentChanged(
            !settings.notificationListenerConsent,
          ),
        ),
        SettingsTile(
          icon: Icons.verified_user_outlined,
          title: 'Trusted Commands & Notification Privacy',
          subtitle:
              '$trustedCount trusted sensitive command${trustedCount == 1 ? '' : 's'} • '
              '$blockedNotifCount blocked app${blockedNotifCount == 1 ? '' : 's'}',
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onManageTrustedCommands,
        ),
        SettingsTile(
          icon: Icons.phonelink_setup_rounded,
          title: 'Open Device Control Hub',
          subtitle: 'Inspect OPPO Reno 16 telemetry and execute system actions',
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onOpenDeviceControlHub,
        ),
      ],
    );
  }
}

class _MemorySection extends StatelessWidget {
  const _MemorySection({
    required this.messageCount,
    required this.saveConversationHistory,
    required this.personalMemoryEnabled,
    required this.personalMemoryCount,
    required this.onSaveConversationHistoryChanged,
    required this.onManagePersonalMemory,
    required this.onClearMemory,
  });

  final int messageCount;
  final bool saveConversationHistory;
  final bool personalMemoryEnabled;
  final int personalMemoryCount;
  final ValueChanged<bool> onSaveConversationHistoryChanged;
  final VoidCallback onManagePersonalMemory;
  final VoidCallback onClearMemory;

  @override
  Widget build(BuildContext context) {
    return SettingsSectionCard(
      title: 'Memory',
      icon: Icons.psychology_outlined,
      subtitle: 'Current-session context by default with opt-in history & personalization',
      children: [
        SettingsTile(
          icon: Icons.save_outlined,
          title: 'Save Conversation History',
          subtitle: saveConversationHistory
              ? 'Enabled • Chat turns persist locally across app restarts'
              : 'Disabled (Default) • Current session only; cleared on restart',
          trailing: Switch.adaptive(
            value: saveConversationHistory,
            onChanged: onSaveConversationHistoryChanged,
          ),
          onTap: () =>
              onSaveConversationHistoryChanged(!saveConversationHistory),
        ),
        SettingsTile(
          icon: Icons.manage_accounts_outlined,
          title: 'Personalization Memory',
          subtitle:
              '${personalMemoryEnabled ? 'Enabled' : 'Disabled (Default)'} • '
              '$personalMemoryCount saved preference${personalMemoryCount == 1 ? '' : 's'} (view, edit, delete)',
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onManagePersonalMemory,
        ),
        SettingsTile(
          icon: Icons.history_rounded,
          title: 'Session Conversation Messages',
          subtitle:
              '$messageCount message${messageCount == 1 ? '' : 's'} in current session • '
              '${AppConstants.maxContextMessages}-message rolling AI context window',
        ),
        SettingsTile(
          icon: Icons.delete_sweep_outlined,
          iconColor: VisionColors.error,
          title: 'Clear Session & Saved History',
          subtitle: 'Reset current session context and delete any saved transcript',
          onTap: messageCount > 0 ? onClearMemory : null,
        ),
      ],
    );
  }
}

class _PrivacySection extends StatelessWidget {
  const _PrivacySection({required this.configuredKeyCount});

  final int configuredKeyCount;

  @override
  Widget build(BuildContext context) {
    return SettingsSectionCard(
      title: 'Privacy',
      icon: Icons.lock_outline_rounded,
      subtitle: 'On-device credential protection and telemetry safeguards',
      children: [
        SettingsTile(
          icon: Icons.security_rounded,
          iconColor: VisionColors.success,
          title: 'Android Keystore Encryption',
          subtitle:
              '$configuredKeyCount of ${AiProviderType.values.length} provider keys configured • '
              'Encrypted with AES-GCM & excluded from Android Auto Backup (allowBackup=false)',
        ),
        const SettingsTile(
          icon: Icons.visibility_off_outlined,
          title: 'Automatic Secret Redaction',
          subtitle: 'API keys and bearer tokens are scrubbed from diagnostics and error banners',
        ),
        const SettingsTile(
          icon: Icons.mic_off_outlined,
          title: 'Offline Wake-Word Standby',
          subtitle: 'AudioRecord wake-word detection runs locally without cloud audio streaming',
        ),
      ],
    );
  }
}

class _AboutVisionSection extends StatelessWidget {
  const _AboutVisionSection({
    required this.onOpenOnboarding,
    required this.onOpenDiagnostics,
    required this.onResetDefaults,
  });

  final VoidCallback onOpenOnboarding;
  final VoidCallback onOpenDiagnostics;
  final VoidCallback onResetDefaults;

  @override
  Widget build(BuildContext context) {
    return SettingsSectionCard(
      title: 'About VISION',
      icon: Icons.info_outline_rounded,
      subtitle: '${AppConstants.appFullTitle} — "${AppConstants.appTagline}"',
      children: [
        SettingsTile(
          icon: Icons.monitor_heart_outlined,
          iconColor: VisionColors.accentPrimary,
          title: 'Developer Diagnostics',
          subtitle: 'Inspect live provider health, latency metrics, voice state & export logs',
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onOpenDiagnostics,
        ),
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
          iconColor: VisionColors.warning,
          title: 'Reset Preferences',
          subtitle: 'Restore default Liquid Glass dark theme and settings',
          onTap: onResetDefaults,
        ),
      ],
    );
  }
}
