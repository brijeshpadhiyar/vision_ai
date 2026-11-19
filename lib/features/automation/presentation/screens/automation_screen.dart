import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/constants/app_constants.dart';
import 'package:vision_ai/core/theme/vision_colors.dart';
import 'package:vision_ai/core/theme/vision_glass.dart';
import 'package:vision_ai/core/theme/vision_spacing.dart';
import 'package:vision_ai/core/widgets/glass/vision_glass_widgets.dart';
import 'package:vision_ai/core/widgets/vision_app_bar.dart';
import 'package:vision_ai/core/widgets/vision_scaffold.dart';
import 'package:vision_ai/core/widgets/vision_status_badge.dart';
import 'package:vision_ai/features/automation/domain/entities/device_action.dart';
import 'package:vision_ai/features/automation/presentation/controllers/automation_controller.dart';
import 'package:vision_ai/features/automation/presentation/widgets/automation_action_prompt_card.dart';
import 'package:vision_ai/features/automation/presentation/widgets/routines_section_card.dart';
import 'package:vision_ai/features/settings/presentation/controllers/settings_controller.dart';

/// Liquid Glass Android Device Automation & System Control Hub.
class AutomationScreen extends ConsumerStatefulWidget {
  const AutomationScreen({super.key});

  @override
  ConsumerState<AutomationScreen> createState() => _AutomationScreenState();
}

class _AutomationScreenState extends ConsumerState<AutomationScreen> {
  final TextEditingController _commandController = TextEditingController();
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_refresh());
      }
    });
  }

  Future<void> _refresh() async {
    setState(() => _isRefreshing = true);
    await ref.read(automationControllerProvider.notifier).refreshEnvironment();
    if (mounted) {
      setState(() => _isRefreshing = false);
    }
  }

  @override
  void dispose() {
    _commandController.dispose();
    super.dispose();
  }

  void _triggerHaptic() {
    if (ref.read(settingsControllerProvider).hapticFeedbackEnabled) {
      unawaited(HapticFeedback.selectionClick());
    }
  }

  Future<void> _runCommandText() async {
    final text = _commandController.text.trim();
    if (text.isEmpty) return;
    _triggerHaptic();

    final controller = ref.read(automationControllerProvider.notifier);
    final result = await controller.tryHandleNaturalCommand(text);
    if (!mounted) return;

    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unrecognized device command. Try "set alarm for 7 am", '
            '"set timer for 5 minutes", "open Wi-Fi settings", or "call Mom".',
          ),
        ),
      );
      return;
    }

    _commandController.clear();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(result.summary)));
  }

  Future<void> _openCallDialog() async {
    _triggerHaptic();
    final targetController = TextEditingController();
    final query = await showVisionGlassDialog<String>(
      context: context,
      builder: (dialogContext) => VisionGlassDialog(
        title: 'Call or Lookup Contact',
        icon: Icons.call_rounded,
        content: VisionGlassInput(
          controller: targetController,
          autofocus: true,
          labelText: 'Contact name or phone number',
          hintText: 'e.g. Mom or +91 9876543210',
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          VisionGlassButton(
            label: 'Call / Dial',
            compact: true,
            onPressed: () =>
                Navigator.of(dialogContext).pop(targetController.text.trim()),
          ),
        ],
      ),
    );
    targetController.dispose();

    if (query == null || query.isEmpty || !mounted) return;
    await ref
        .read(automationControllerProvider.notifier)
        .executeRequest(
          DeviceActionRequest(
            type: DeviceActionType.callPhone,
            target: query,
            displaySummary: 'Call $query',
          ),
        );
  }

  Future<void> _openAlarmPicker() async {
    _triggerHaptic();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked == null || !mounted) return;

    final result = await ref
        .read(automationControllerProvider.notifier)
        .executeRequest(
          DeviceActionRequest(
            type: DeviceActionType.setAlarm,
            hour: picked.hour,
            minute: picked.minute,
            label: 'VISION Alarm',
            displaySummary:
                'Set alarm for ${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}',
          ),
        );
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result.summary)));
    }
  }

  Future<void> _openTimerDialog() async {
    _triggerHaptic();
    final minutes = await showVisionGlassDialog<int>(
      context: context,
      builder: (dialogContext) => VisionGlassDialog(
        title: 'Start Countdown Timer',
        icon: Icons.timer_outlined,
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final preset in const <int>[1, 5, 10, 15, 30])
              VisionGlassChip(
                icon: Icons.timer_outlined,
                label: '$preset min',
                onTap: () => Navigator.of(dialogContext).pop(preset),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (minutes == null || !mounted) return;

    final result = await ref
        .read(automationControllerProvider.notifier)
        .executeRequest(
          DeviceActionRequest(
            type: DeviceActionType.setTimer,
            durationSeconds: minutes * 60,
            label: 'VISION Timer',
            displaySummary: 'Start $minutes minute timer',
          ),
        );
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result.summary)));
    }
  }

  Future<void> _openAppLauncherSheet() async {
    _triggerHaptic();
    final apps = await ref
        .read(automationControllerProvider.notifier)
        .loadInstalledApps();
    if (!mounted) return;

    await showVisionGlassBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return _InstalledAppsSheet(
          apps: apps,
          onSelectApp: (app) async {
            Navigator.of(sheetContext).pop();
            final result = await ref
                .read(automationControllerProvider.notifier)
                .executeRequest(
                  DeviceActionRequest(
                    type: DeviceActionType.launchApp,
                    target: app.packageName,
                    displaySummary: 'Launch ${app.appName}',
                  ),
                );
            if (mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(result.summary)));
            }
          },
        );
      },
    );
  }

  Future<void> _openSmsDialog() async {
    _triggerHaptic();
    final targetController = TextEditingController();
    final messageController = TextEditingController();
    final payload = await showVisionGlassDialog<(String, String)>(
      context: context,
      builder: (dialogContext) => VisionGlassDialog(
        title: 'Compose SMS',
        icon: Icons.sms_outlined,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            VisionGlassInput(
              controller: targetController,
              autofocus: true,
              labelText: 'Contact name or phone number',
              hintText: 'e.g. Mom or +91 9876543210',
            ),
            const SizedBox(height: 12),
            VisionGlassInput(
              controller: messageController,
              maxLines: 2,
              labelText: 'Message (optional)',
              hintText: 'On my way!',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          VisionGlassButton(
            label: 'Open SMS',
            compact: true,
            onPressed: () => Navigator.of(dialogContext).pop((
              targetController.text.trim(),
              messageController.text.trim(),
            )),
          ),
        ],
      ),
    );
    targetController.dispose();
    messageController.dispose();

    if (payload == null || payload.$1.isEmpty || !mounted) return;
    final result = await ref
        .read(automationControllerProvider.notifier)
        .executeRequest(
          DeviceActionRequest(
            type: DeviceActionType.sendSms,
            target: payload.$1,
            message: payload.$2.isEmpty ? null : payload.$2,
            displaySummary: 'Compose SMS to ${payload.$1}',
          ),
        );
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result.summary)));
    }
  }

  Future<void> _openLookupContactDialog() async {
    _triggerHaptic();
    final queryController = TextEditingController();
    final query = await showVisionGlassDialog<String>(
      context: context,
      builder: (dialogContext) => VisionGlassDialog(
        title: 'Search Contacts',
        icon: Icons.contacts_outlined,
        content: VisionGlassInput(
          controller: queryController,
          autofocus: true,
          labelText: 'Name or phone digits',
          hintText: 'e.g. Rahul',
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          VisionGlassButton(
            label: 'Search',
            compact: true,
            onPressed: () =>
                Navigator.of(dialogContext).pop(queryController.text.trim()),
          ),
        ],
      ),
    );
    queryController.dispose();

    if (query == null || query.isEmpty || !mounted) return;
    final result = await ref
        .read(automationControllerProvider.notifier)
        .executeRequest(
          DeviceActionRequest(
            type: DeviceActionType.lookupContacts,
            target: query,
            displaySummary: 'Search contacts for "$query"',
          ),
        );
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result.summary)));
    }
  }

  Future<void> _openTextInputActionDialog({
    required String title,
    required String label,
    required String hint,
    required String buttonLabel,
    required DeviceActionType actionType,
    required IconData icon,
    required String Function(String input) summaryBuilder,
  }) async {
    _triggerHaptic();
    final inputController = TextEditingController();
    final value = await showVisionGlassDialog<String>(
      context: context,
      builder: (dialogContext) => VisionGlassDialog(
        title: title,
        icon: icon,
        content: VisionGlassInput(
          controller: inputController,
          autofocus: true,
          labelText: label,
          hintText: hint,
          onSubmitted: (val) => Navigator.of(dialogContext).pop(val.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          VisionGlassButton(
            label: buttonLabel,
            compact: true,
            onPressed: () =>
                Navigator.of(dialogContext).pop(inputController.text.trim()),
          ),
        ],
      ),
    );
    inputController.dispose();

    if (value == null || value.isEmpty || !mounted) return;
    final result = await ref
        .read(automationControllerProvider.notifier)
        .executeRequest(
          DeviceActionRequest(
            type: actionType,
            target: value,
            displaySummary: summaryBuilder(value),
          ),
        );
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result.summary)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final automationState = ref.watch(automationControllerProvider);
    final controller = ref.read(automationControllerProvider.notifier);

    return VisionScaffold(
      appBar: VisionAppBar(
        title: 'DEVICE CONTROL',
        subtitle: 'Android System Automation',
        actions: [
          IconButton(
            onPressed: () {
              _triggerHaptic();
              unawaited(_refresh());
            },
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh device status',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: VisionSpacing.navBarClearance),
        children: [
          _CommandBarCard(
            controller: _commandController,
            isExecuting: automationState.isExecuting,
            onExecute: _runCommandText,
          ),
          if (automationState.pendingConfirmation != null ||
              automationState.contactChoices.isNotEmpty ||
              automationState.contactSearchResults.isNotEmpty ||
              (automationState.lastResult?.requiresPermission == true)) ...[
            const SizedBox(height: 14),
            AutomationActionPromptCard(
              automationState: automationState,
              onConfirm: () => unawaited(controller.confirmPendingAction()),
              onConfirmAndSaveAlias: () =>
                  unawaited(controller.confirmPendingAction(saveAsAlias: true)),
              onCancel: controller.cancelPendingAction,
              onSelectContact: (contact) =>
                  unawaited(controller.selectContactForPendingAction(contact)),
              onGrantPermission: (permission) =>
                  unawaited(controller.requestPermission(permission)),
              onCallContact: (contact) => unawaited(
                controller.executeRequest(
                  DeviceActionRequest(
                    type: DeviceActionType.callPhone,
                    target: contact.phoneNumber,
                    displaySummary: 'Call ${contact.name}',
                  ),
                ),
              ),
              onMessageContact: (contact) => unawaited(
                controller.executeRequest(
                  DeviceActionRequest(
                    type: DeviceActionType.sendSms,
                    target: contact.phoneNumber,
                    displaySummary: 'Compose SMS to ${contact.name}',
                  ),
                ),
              ),
              onClearSearchResults: controller.clearContactSearchResults,
            ),
          ],
          if (automationState.errorMessage != null) ...[
            const SizedBox(height: 14),
            _AutomationFeedbackBanner(
              message: automationState.errorMessage!,
              onDismiss: controller.dismissError,
            ),
          ],
          const SizedBox(height: 16),
          _DeviceTelemetryCard(
            status: automationState.deviceStatus,
            isLoading: _isRefreshing && automationState.deviceStatus == null,
          ),
          const SizedBox(height: 16),
          _PermissionsCard(
            hasCallPermission: automationState.hasCallPermission,
            hasContactsPermission: automationState.hasContactsPermission,
            onRequestCall: () => unawaited(
              controller.requestPermission(AutomationPermission.callPhone),
            ),
            onRequestContacts: () => unawaited(
              controller.requestPermission(AutomationPermission.readContacts),
            ),
          ),
          const SizedBox(height: 16),
          _QuickActionsCard(
            flashlightOn: automationState.flashlightOn,
            ringerMode: automationState.deviceStatus?.ringerMode ?? 'normal',
            onCallTap: _openCallDialog,
            onSmsTap: _openSmsDialog,
            onLookupContactTap: _openLookupContactDialog,
            onAlarmTap: _openAlarmPicker,
            onTimerTap: _openTimerDialog,
            onLaunchAppTap: _openAppLauncherSheet,
            onWebSearchTap: () => _openTextInputActionDialog(
              title: 'Web Search',
              label: 'Search query',
              hint: 'e.g. Weather in Ahmedabad',
              buttonLabel: 'Search',
              icon: Icons.travel_explore_rounded,
              actionType: DeviceActionType.webSearch,
              summaryBuilder: (q) => 'Search web for "$q"',
            ),
            onNavigateTap: () => _openTextInputActionDialog(
              title: 'Maps Navigation',
              label: 'Destination or place',
              hint: 'e.g. Ahmedabad Airport',
              buttonLabel: 'Navigate',
              icon: Icons.directions_rounded,
              actionType: DeviceActionType.navigateTo,
              summaryBuilder: (dest) => 'Navigate to $dest',
            ),
            onOpenUrlTap: () => _openTextInputActionDialog(
              title: 'Open Web URL',
              label: 'Website URL',
              hint: 'https://flutter.dev',
              buttonLabel: 'Open',
              icon: Icons.open_in_browser_rounded,
              actionType: DeviceActionType.openUrl,
              summaryBuilder: (url) => 'Open $url',
            ),
            onFlashlightTap: () {
              _triggerHaptic();
              unawaited(
                controller.executeRequest(
                  DeviceActionRequest(
                    type: DeviceActionType.toggleFlashlight,
                    enabled: !automationState.flashlightOn,
                    displaySummary: automationState.flashlightOn
                        ? 'Turn off flashlight'
                        : 'Turn on flashlight',
                  ),
                ),
              );
            },
            onSetRingerMode: (mode) {
              _triggerHaptic();
              unawaited(
                controller.executeRequest(
                  DeviceActionRequest(
                    type: DeviceActionType.setRingerMode,
                    target: mode,
                    displaySummary: 'Set ringer mode to $mode',
                  ),
                ),
              );
            },
            onAdjustVolume: (direction) {
              _triggerHaptic();
              unawaited(
                controller.executeRequest(
                  DeviceActionRequest(
                    type: DeviceActionType.adjustVolume,
                    target: direction,
                    displaySummary: 'Adjust volume ($direction)',
                  ),
                ),
              );
            },
            onOpenSettingsSection: (section) {
              _triggerHaptic();
              unawaited(
                controller.executeRequest(
                  DeviceActionRequest(
                    type: DeviceActionType.openSettings,
                    target: section,
                    displaySummary: 'Open $section settings',
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          const RoutinesSectionCard(),
          const SizedBox(height: 16),
          _RecentActionsCard(entries: automationState.recentActions),
        ],
      ),
    );
  }
}

class _CommandBarCard extends StatelessWidget {
  const _CommandBarCard({
    required this.controller,
    required this.isExecuting,
    required this.onExecute,
  });

  final TextEditingController controller;
  final bool isExecuting;
  final VoidCallback onExecute;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return VisionGlassCard(
      variant: VisionGlassVariant.accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Run Device Command', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Try "set alarm for 6:30 am", "set timer for 5 minutes", '
            '"open Camera", "open Wi-Fi settings", or "call Mom".',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: VisionGlassInput(
                  controller: controller,
                  hintText: 'Enter an Android action command...',
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onExecute(),
                ),
              ),
              const SizedBox(width: 10),
              VisionGlassButton(
                label: 'Run',
                icon: Icons.play_arrow_rounded,
                compact: true,
                isLoading: isExecuting,
                onPressed: isExecuting ? null : onExecute,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AutomationFeedbackBanner extends StatelessWidget {
  const _AutomationFeedbackBanner({
    required this.message,
    required this.onDismiss,
  });

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return VisionGlassCard(
      borderColor: VisionColors.error.withValues(alpha: 0.7),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: VisionColors.error,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodySmall),
          ),
          IconButton(
            onPressed: onDismiss,
            icon: const Icon(Icons.close_rounded, size: 18),
            visualDensity: VisualDensity.compact,
            tooltip: 'Dismiss notice',
          ),
        ],
      ),
    );
  }
}

class _DeviceTelemetryCard extends StatelessWidget {
  const _DeviceTelemetryCard({required this.status, this.isLoading = false});

  final DeviceStatusSnapshot? status;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final snapshot = status;
    final batteryLabel = snapshot != null && snapshot.batteryLevel >= 0
        ? '${snapshot.batteryLevel}%${snapshot.isCharging ? ' (Charging)' : ''}'
        : 'Unavailable';

    return VisionGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.phone_android_rounded,
                size: 18,
                color: VisionColors.primaryAccent(brightness),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  snapshot != null
                      ? snapshot.deviceDisplayName
                      : AppConstants.targetDeviceName,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              VisionStatusBadge(
                label: snapshot?.resolvedOemSkin ?? 'Android',
                indicatorColor: VisionColors.success,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isLoading)
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                VisionShimmer(width: 220, height: 14),
                SizedBox(height: 8),
                VisionShimmer(width: 160, height: 14),
              ],
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                VisionStatusBadge(
                  label: 'Battery: $batteryLabel',
                  icon: Icons.battery_charging_full_rounded,
                ),
                VisionStatusBadge(
                  label: 'Network: ${snapshot?.networkType ?? 'Unknown'}',
                  icon: Icons.wifi_rounded,
                ),
                VisionStatusBadge(
                  label: 'Ringer: ${snapshot?.ringerMode ?? 'normal'}',
                  icon: Icons.notifications_active_outlined,
                ),
                if (snapshot != null)
                  VisionStatusBadge(
                    label: snapshot.isDefaultAssistant
                        ? 'Default Assistant: Active'
                        : 'Default Assistant: Not Set',
                    indicatorColor: snapshot.isDefaultAssistant
                        ? VisionColors.success
                        : VisionColors.warning,
                  ),
                if (snapshot != null)
                  VisionStatusBadge(
                    label: snapshot.isIgnoringBatteryOptimizations
                        ? 'Battery: Unrestricted'
                        : 'Battery: Optimized',
                    indicatorColor: snapshot.isIgnoringBatteryOptimizations
                        ? VisionColors.success
                        : VisionColors.warning,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _PermissionsCard extends StatelessWidget {
  const _PermissionsCard({
    required this.hasCallPermission,
    required this.hasContactsPermission,
    required this.onRequestCall,
    required this.onRequestContacts,
  });

  final bool hasCallPermission;
  final bool hasContactsPermission;
  final VoidCallback onRequestCall;
  final VoidCallback onRequestContacts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return VisionGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Permission Guards', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Runtime Android permissions required for direct calls and contact lookup.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          _PermissionRow(
            title: AutomationPermission.readContacts.displayName,
            granted: hasContactsPermission,
            onRequest: onRequestContacts,
          ),
          const SizedBox(height: 8),
          _PermissionRow(
            title: AutomationPermission.callPhone.displayName,
            granted: hasCallPermission,
            onRequest: onRequestCall,
          ),
        ],
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.title,
    required this.granted,
    required this.onRequest,
  });

  final String title;
  final bool granted;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.bodyMedium),
        ),
        if (granted)
          const VisionStatusBadge(
            label: 'Granted',
            indicatorColor: VisionColors.success,
            compact: true,
          )
        else
          VisionGlassButton(
            label: 'Grant',
            compact: true,
            style: VisionGlassButtonStyle.tonal,
            onPressed: onRequest,
          ),
      ],
    );
  }
}

class _QuickActionsCard extends StatelessWidget {
  const _QuickActionsCard({
    required this.flashlightOn,
    required this.ringerMode,
    required this.onCallTap,
    required this.onSmsTap,
    required this.onLookupContactTap,
    required this.onAlarmTap,
    required this.onTimerTap,
    required this.onLaunchAppTap,
    required this.onWebSearchTap,
    required this.onNavigateTap,
    required this.onOpenUrlTap,
    required this.onFlashlightTap,
    required this.onSetRingerMode,
    required this.onAdjustVolume,
    required this.onOpenSettingsSection,
  });

  final bool flashlightOn;
  final String ringerMode;
  final VoidCallback onCallTap;
  final VoidCallback onSmsTap;
  final VoidCallback onLookupContactTap;
  final VoidCallback onAlarmTap;
  final VoidCallback onTimerTap;
  final VoidCallback onLaunchAppTap;
  final VoidCallback onWebSearchTap;
  final VoidCallback onNavigateTap;
  final VoidCallback onOpenUrlTap;
  final VoidCallback onFlashlightTap;
  final ValueChanged<String> onSetRingerMode;
  final ValueChanged<String> onAdjustVolume;
  final ValueChanged<String> onOpenSettingsSection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = VisionColors.primaryAccent(theme.brightness);

    return VisionGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('System Intents & Actions', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              VisionGlassChip(
                icon: Icons.call_rounded,
                label: 'Call / Contact',
                onTap: onCallTap,
              ),
              VisionGlassChip(
                icon: Icons.sms_outlined,
                label: 'Send SMS',
                onTap: onSmsTap,
              ),
              VisionGlassChip(
                icon: Icons.contacts_outlined,
                label: 'Lookup Contact',
                onTap: onLookupContactTap,
              ),
              VisionGlassChip(
                icon: Icons.alarm_add_rounded,
                label: 'Set Alarm',
                onTap: onAlarmTap,
              ),
              VisionGlassChip(
                icon: Icons.timer_outlined,
                label: 'Start Timer',
                onTap: onTimerTap,
              ),
              VisionGlassChip(
                icon: Icons.apps_rounded,
                label: 'Launch App',
                onTap: onLaunchAppTap,
              ),
              VisionGlassChip(
                icon: Icons.travel_explore_rounded,
                label: 'Web Search',
                onTap: onWebSearchTap,
              ),
              VisionGlassChip(
                icon: Icons.directions_rounded,
                label: 'Navigate',
                onTap: onNavigateTap,
              ),
              VisionGlassChip(
                icon: Icons.open_in_browser_rounded,
                label: 'Open URL',
                onTap: onOpenUrlTap,
              ),
              VisionGlassChip(
                icon: flashlightOn
                    ? Icons.flashlight_on_rounded
                    : Icons.flashlight_off_rounded,
                label: flashlightOn ? 'Torch On' : 'Torch Off',
                selected: flashlightOn,
                accentColor: VisionColors.warning,
                onTap: onFlashlightTap,
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Text(
            'AUDIO & RINGER MODE',
            style: theme.textTheme.labelMedium?.copyWith(
              color: accent,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final mode in const <(String, String)>[
                ('normal', 'Normal'),
                ('vibrate', 'Vibrate'),
                ('silent', 'Silent'),
              ])
                VisionGlassChip(
                  label: mode.$2,
                  selected: ringerMode == mode.$1,
                  onTap: () => onSetRingerMode(mode.$1),
                ),
              VisionGlassChip(
                icon: Icons.volume_up_rounded,
                label: 'Vol +',
                onTap: () => onAdjustVolume('up'),
              ),
              VisionGlassChip(
                icon: Icons.volume_down_rounded,
                label: 'Vol -',
                onTap: () => onAdjustVolume('down'),
              ),
              VisionGlassChip(
                icon: Icons.volume_off_rounded,
                label: 'Mute',
                onTap: () => onAdjustVolume('mute'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Text(
            'SYSTEM SETTINGS SHORTCUTS',
            style: theme.textTheme.labelMedium?.copyWith(
              color: accent,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in const <(String, String)>[
                ('wifi', 'Wi-Fi'),
                ('bluetooth', 'Bluetooth'),
                ('sound', 'Sound'),
                ('display', 'Display'),
                ('battery', 'Battery'),
                ('location', 'Location'),
                ('notifications', 'Notifications'),
                ('storage', 'Storage'),
                ('accessibility', 'Accessibility'),
              ])
                VisionGlassChip(
                  label: entry.$2,
                  compact: true,
                  onTap: () => onOpenSettingsSection(entry.$1),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecentActionsCard extends StatelessWidget {
  const _RecentActionsCard({required this.entries});

  final List<AutomationExecutionEntry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return VisionGlassCard(
      variant: VisionGlassVariant.subtle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recent Automation Log', style: theme.textTheme.titleMedium),
          const SizedBox(height: 10),
          if (entries.isEmpty)
            Text(
              'No automation commands executed yet in this session.',
              style: theme.textTheme.bodySmall,
            )
          else
            for (final entry in entries.take(5))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      entry.result.success
                          ? Icons.check_circle_outline_rounded
                          : Icons.error_outline_rounded,
                      size: 18,
                      color: entry.result.success
                          ? VisionColors.success
                          : VisionColors.warning,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.request.displaySummary,
                            style: theme.textTheme.bodyMedium,
                          ),
                          Text(
                            entry.result.summary,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _InstalledAppsSheet extends StatefulWidget {
  const _InstalledAppsSheet({required this.apps, required this.onSelectApp});

  final List<InstalledAppInfo> apps;
  final ValueChanged<InstalledAppInfo> onSelectApp;

  @override
  State<_InstalledAppsSheet> createState() => _InstalledAppsSheetState();
}

class _InstalledAppsSheetState extends State<_InstalledAppsSheet> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.apps
        .where(
          (app) =>
              _filter.isEmpty ||
              app.appName.toLowerCase().contains(_filter.toLowerCase()) ||
              app.packageName.toLowerCase().contains(_filter.toLowerCase()),
        )
        .toList(growable: false);

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.62,
      child: Column(
        children: [
          Text(
            'Launch Installed App (${widget.apps.length})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          VisionGlassInput(
            prefixIcon: const Icon(Icons.search_rounded),
            hintText: 'Search installed apps...',
            onChanged: (value) => setState(() => _filter = value),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text(
                      'No launchable apps available in this environment.',
                    ),
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final app = filtered[index];
                      return ListTile(
                        leading: const Icon(Icons.android_rounded),
                        title: Text(app.appName),
                        subtitle: Text(app.packageName),
                        onTap: () => widget.onSelectApp(app),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
