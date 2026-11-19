import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/theme/vision_colors.dart';
import 'package:vision_ai/core/theme/vision_spacing.dart';
import 'package:vision_ai/core/widgets/glass/vision_glass_widgets.dart';
import 'package:vision_ai/core/widgets/vision_app_bar.dart';
import 'package:vision_ai/core/widgets/vision_scaffold.dart';
import 'package:vision_ai/core/widgets/vision_status_badge.dart';
import 'package:vision_ai/features/automation/domain/entities/device_action.dart';
import 'package:vision_ai/features/automation/domain/entities/trusted_command_policy.dart';
import 'package:vision_ai/features/automation/presentation/controllers/automation_controller.dart';
import 'package:vision_ai/features/automation/presentation/controllers/routines_controller.dart';
import 'package:vision_ai/features/automation/presentation/controllers/trusted_commands_controller.dart';
import 'package:vision_ai/features/chat/presentation/controllers/chat_controller.dart';
import 'package:vision_ai/features/chat/presentation/controllers/usage_stats_controller.dart';
import 'package:vision_ai/features/memory/presentation/controllers/memory_controller.dart';
import 'package:vision_ai/features/settings/domain/entities/ai_provider_type.dart';
import 'package:vision_ai/features/settings/presentation/controllers/api_key_controller.dart';
import 'package:vision_ai/features/settings/presentation/controllers/settings_controller.dart';
import 'package:vision_ai/features/settings/presentation/widgets/settings_section_card.dart';
import 'package:vision_ai/features/settings/presentation/widgets/settings_tile.dart';
import 'package:vision_ai/features/voice/presentation/controllers/voice_controller.dart';

/// Unified Privacy & Security Dashboard (Module 25 — v1.1).
///
/// Consolidates credential encryption posture, runtime Android permissions,
/// tiered Trusted Commands grant/revoke controls, microphone & notification
/// privacy safeguards, and local data footprint management in one screen.
class PrivacyDashboardScreen extends ConsumerStatefulWidget {
  const PrivacyDashboardScreen({super.key});

  @override
  ConsumerState<PrivacyDashboardScreen> createState() =>
      _PrivacyDashboardScreenState();
}

class _PrivacyDashboardScreenState
    extends ConsumerState<PrivacyDashboardScreen> {
  final TextEditingController _blockPkgController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      if (!mounted) return;
      unawaited(
        ref.read(automationControllerProvider.notifier).refreshEnvironment(),
      );
      unawaited(
        ref
            .read(voiceControllerProvider.notifier)
            .refreshAssistantCapabilities(),
      );
    });
  }

  @override
  void dispose() {
    _blockPkgController.dispose();
    super.dispose();
  }

  Future<void> _confirmClearAllLocalActivity() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear All Local Activity Data?'),
        content: const Text(
          'This clears your current chat session, any saved transcript, '
          'automation execution history, and local usage counters. '
          'Your encrypted API keys and saved routines will be preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Clear Data'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await ref.read(chatControllerProvider.notifier).clearConversation();
    await ref
        .read(automationControllerProvider.notifier)
        .clearExecutionHistory();
    await ref.read(usageStatsControllerProvider.notifier).clearUsage();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cleared chat, execution history, and usage counters.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsControllerProvider);
    final settingsCtrl = ref.read(settingsControllerProvider.notifier);
    final voiceState = ref.watch(voiceControllerProvider);
    final automationState = ref.watch(automationControllerProvider);
    final trustState = ref.watch(trustedCommandsControllerProvider);
    final trustCtrl = ref.read(trustedCommandsControllerProvider.notifier);
    final chatState = ref.watch(chatControllerProvider);
    final memoryState = ref.watch(memoryControllerProvider);
    final usageStats = ref.watch(usageStatsControllerProvider);
    final routines = ref.watch(routinesControllerProvider);
    final keyMap =
        ref.watch(apiKeyStatusControllerProvider).asData?.value ??
        const <AiProviderType, bool>{};
    final configuredKeys = keyMap.values.where((v) => v).length;
    final deviceLabel =
        automationState.deviceStatus?.deviceDisplayName ?? 'Android Device';
    final oemSkin = automationState.deviceStatus?.resolvedOemSkin ?? 'Android';

    return VisionScaffold(
      appBar: const VisionAppBar(
        title: 'PRIVACY & SECURITY',
        subtitle: 'Permissions, Trusted Commands & Data Controls',
      ),
      body: ListView(
        padding: const EdgeInsets.only(
          top: 8,
          bottom: VisionSpacing.navBarClearance,
        ),
        children: [
          // 1. Security Posture Overview
          SettingsSectionCard(
            title: 'Security Posture',
            icon: Icons.shield_outlined,
            subtitle: '$deviceLabel • $oemSkin',
            children: [
              SettingsTile(
                icon: Icons.vpn_key_outlined,
                iconColor: VisionColors.success,
                title: 'Android Keystore Encryption',
                subtitle:
                    '$configuredKeys of ${AiProviderType.values.length} API keys encrypted (AES-GCM, allowBackup=false)',
                trailing: const VisionStatusBadge(
                  label: 'Protected',
                  indicatorColor: VisionColors.success,
                  compact: true,
                ),
              ),
              SettingsTile(
                icon: Icons.visibility_off_outlined,
                iconColor: VisionColors.success,
                title: 'Secret Redaction & Manual Routing',
                subtitle:
                    'Active provider: ${settings.selectedAiProvider.displayName} • '
                    'Opt-in fallback: ${settings.fallbackEnabled ? 'ON' : 'OFF'}',
                trailing: const VisionStatusBadge(
                  label: 'Active',
                  indicatorColor: VisionColors.success,
                  compact: true,
                ),
              ),
              SettingsTile(
                icon: Icons.memory_rounded,
                title: 'Session-Only Memory Posture',
                subtitle:
                    'Chat history saving: ${settings.saveConversationHistory ? 'ON' : 'OFF (Default)'} • '
                    'Personal memory: ${memoryState.memoryEnabled ? 'ON' : 'OFF (Default)'}',
                trailing: VisionStatusBadge(
                  label:
                      (!settings.saveConversationHistory &&
                          !memoryState.memoryEnabled)
                      ? 'Strict'
                      : 'Custom',
                  indicatorColor:
                      (!settings.saveConversationHistory &&
                          !memoryState.memoryEnabled)
                      ? VisionColors.success
                      : VisionColors.warning,
                  compact: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 2. Permissions Audit
          SettingsSectionCard(
            title: 'Permissions Audit',
            icon: Icons.admin_panel_settings_outlined,
            subtitle: 'Minimum required runtime & special Android permissions',
            children: [
              SettingsTile(
                icon: Icons.mic_none_rounded,
                title: 'Microphone (RECORD_AUDIO)',
                subtitle: voiceState.hasMicPermission
                    ? 'Granted for voice commands & offline wake-word'
                    : 'Not granted',
                trailing: VisionStatusBadge(
                  label: voiceState.hasMicPermission ? 'Granted' : 'Grant',
                  indicatorColor: voiceState.hasMicPermission
                      ? VisionColors.success
                      : VisionColors.warning,
                  compact: true,
                ),
                onTap: () => ref
                    .read(voiceControllerProvider.notifier)
                    .refreshAssistantCapabilities(),
              ),
              SettingsTile(
                icon: Icons.contacts_outlined,
                title: 'Contacts (READ_CONTACTS)',
                subtitle: automationState.hasContactsPermission
                    ? 'Granted for local contact resolution'
                    : 'Not granted',
                trailing: VisionStatusBadge(
                  label: automationState.hasContactsPermission
                      ? 'Granted'
                      : 'Grant',
                  indicatorColor: automationState.hasContactsPermission
                      ? VisionColors.success
                      : VisionColors.warning,
                  compact: true,
                ),
                onTap: () => ref
                    .read(automationControllerProvider.notifier)
                    .requestPermission(AutomationPermission.readContacts),
              ),
              SettingsTile(
                icon: Icons.call_outlined,
                title: 'Phone Calls (CALL_PHONE)',
                subtitle: automationState.hasCallPermission
                    ? 'Granted (only used if direct calls enabled)'
                    : 'Not granted (uses safe dialer)',
                trailing: VisionStatusBadge(
                  label: automationState.hasCallPermission
                      ? 'Granted'
                      : 'Optional',
                  indicatorColor: automationState.hasCallPermission
                      ? VisionColors.success
                      : VisionColors.accentPrimary,
                  compact: true,
                ),
                onTap: () => ref
                    .read(automationControllerProvider.notifier)
                    .requestPermission(AutomationPermission.callPhone),
              ),
              SettingsTile(
                icon: Icons.assistant_rounded,
                title: 'Default Digital Assistant',
                subtitle: voiceState.isDefaultAssistant
                    ? 'VISION holds ROLE_ASSISTANT'
                    : 'Not set as default assistant',
                trailing: VisionStatusBadge(
                  label: voiceState.isDefaultAssistant ? 'Active' : 'Configure',
                  indicatorColor: voiceState.isDefaultAssistant
                      ? VisionColors.success
                      : VisionColors.warning,
                  compact: true,
                ),
                onTap: () => ref
                    .read(voiceControllerProvider.notifier)
                    .requestDefaultAssistantRole(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 3. Trusted Commands Audit & Instant Revoke
          SettingsSectionCard(
            title: 'Trusted Commands',
            icon: Icons.verified_user_outlined,
            subtitle:
                '${trustState.trustedSensitiveActions.length} sensitive command'
                '${trustState.trustedSensitiveActions.length == 1 ? '' : 's'} currently trusted',
            children: [
              for (final action in TrustedCommandPolicy.sensitiveActionTypes)
                SettingsTile(
                  icon: Icons.bolt_outlined,
                  title: action.displayName,
                  subtitle: trustState.isActionTrusted(action)
                      ? 'Trusted • Runs without extra prompt'
                      : 'Protected • Confirmation required',
                  trailing: Switch.adaptive(
                    value: trustState.isActionTrusted(action),
                    onChanged: (trusted) => trusted
                        ? trustCtrl.trustAction(action)
                        : trustCtrl.revokeAction(action),
                  ),
                ),
              if (trustState.trustedSensitiveActions.isNotEmpty)
                SettingsTile(
                  icon: Icons.gpp_bad_outlined,
                  iconColor: VisionColors.error,
                  title: 'Revoke All Trusted Commands',
                  subtitle:
                      'Restore confirmation prompts for all sensitive actions',
                  onTap: trustCtrl.revokeAll,
                ),
            ],
          ),
          const SizedBox(height: 16),

          // 4. Microphone & Notification Privacy
          SettingsSectionCard(
            title: 'Microphone & Notification Privacy',
            icon: Icons.hearing_disabled_outlined,
            subtitle: 'Control local wake-word standby and blocked apps',
            children: [
              SettingsTile(
                icon: Icons.mic_external_on_outlined,
                title: 'Background Wake-Word Standby',
                subtitle: settings.wakeWordBackgroundEnabled
                    ? 'Enabled • On-device AudioRecord only (zero cloud audio)'
                    : 'Disabled • Mic only listens when you tap or trigger Assist',
                trailing: Switch.adaptive(
                  value: settings.wakeWordBackgroundEnabled,
                  onChanged: (enabled) => settingsCtrl
                      .setWakeWordBackgroundEnabled(enabled: enabled),
                ),
              ),
              SettingsTile(
                icon: Icons.notifications_paused_outlined,
                title: 'Notification Reader Consent',
                subtitle: settings.notificationListenerConsent
                    ? 'Enabled • Local ring buffer only (max 20)'
                    : 'Disabled • VISION will not read notifications',
                trailing: Switch.adaptive(
                  value: settings.notificationListenerConsent,
                  onChanged: (consented) => settingsCtrl
                      .setNotificationListenerConsent(consented: consented),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: VisionGlassInput(
                            controller: _blockPkgController,
                            hintText: 'Block app package (e.g. com.bank.app)',
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () async {
                            final pkg = _blockPkgController.text.trim();
                            if (pkg.isEmpty) return;
                            await trustCtrl.blockNotificationPackage(pkg);
                            _blockPkgController.clear();
                          },
                          child: const Text('Block'),
                        ),
                      ],
                    ),
                    if (trustState.blockedNotificationPackages.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final pkg
                              in trustState.blockedNotificationPackages)
                            Chip(
                              label: Text(pkg),
                              onDeleted: () =>
                                  trustCtrl.unblockNotificationPackage(pkg),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 5. Local Data & Footprint Controls
          SettingsSectionCard(
            title: 'Local Data & Footprint',
            icon: Icons.storage_rounded,
            subtitle:
                'Inspect and clear locally stored session & activity data',
            children: [
              SettingsTile(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'Session & Saved Transcript',
                subtitle:
                    '${chatState.messages.length} message${chatState.messages.length == 1 ? '' : 's'} • '
                    'Persistence ${settings.saveConversationHistory ? 'ON' : 'OFF'}',
              ),
              SettingsTile(
                icon: Icons.history_rounded,
                title: 'Automation History & Routines',
                subtitle:
                    '${automationState.recentActions.length} execution log entries • '
                    '${routines.length} saved routine${routines.length == 1 ? '' : 's'}',
              ),
              SettingsTile(
                icon: Icons.bar_chart_rounded,
                title: 'Local AI Usage Counters',
                subtitle:
                    '${usageStats.totalRequests} requests • ${usageStats.totalTokens} total tokens',
              ),
              SettingsTile(
                icon: Icons.delete_forever_outlined,
                iconColor: VisionColors.error,
                title: 'Clear All Local Activity Data',
                subtitle: 'Clears chat transcript, execution history & usage counters (keeps API keys & routines)',
                onTap: _confirmClearAllLocalActivity,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
