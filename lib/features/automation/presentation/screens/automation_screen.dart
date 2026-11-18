import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/app/theme/app_colors.dart';
import 'package:vision_ai/core/constants/app_constants.dart';
import 'package:vision_ai/core/widgets/vision_app_bar.dart';
import 'package:vision_ai/core/widgets/vision_card.dart';
import 'package:vision_ai/core/widgets/vision_scaffold.dart';
import 'package:vision_ai/core/widgets/vision_status_badge.dart';
import 'package:vision_ai/features/automation/domain/entities/device_action.dart';
import 'package:vision_ai/features/automation/presentation/controllers/automation_controller.dart';
import 'package:vision_ai/features/automation/presentation/widgets/automation_action_prompt_card.dart';
import 'package:vision_ai/features/settings/presentation/controllers/settings_controller.dart';

/// Phase 4 Android Device Automation & System Control Hub.
class AutomationScreen extends ConsumerStatefulWidget {
  const AutomationScreen({super.key});

  @override
  ConsumerState<AutomationScreen> createState() => _AutomationScreenState();
}

class _AutomationScreenState extends ConsumerState<AutomationScreen> {
  final TextEditingController _commandController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(
          ref.read(automationControllerProvider.notifier).refreshEnvironment(),
        );
      }
    });
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
    final query = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Call or Lookup Contact'),
        content: TextField(
          controller: targetController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Contact name or phone number',
            hintText: 'e.g. Mom or +91 9876543210',
          ),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(targetController.text.trim()),
            child: const Text('Call / Dial'),
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
    final minutes = await showDialog<int>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Start Countdown Timer'),
        children: [
          for (final preset in const <int>[1, 5, 10, 15, 30])
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(preset),
              child: Text('$preset minute${preset == 1 ? '' : 's'}'),
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

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
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
    final payload = await showDialog<(String, String)>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Compose SMS'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: targetController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Contact name or phone number',
                hintText: 'e.g. Mom or +91 9876543210',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: messageController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Message (optional)',
                hintText: 'On my way!',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop((
              targetController.text.trim(),
              messageController.text.trim(),
            )),
            child: const Text('Open SMS'),
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
    final query = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Search Contacts'),
        content: TextField(
          controller: queryController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Name or phone digits',
            hintText: 'e.g. Rahul',
          ),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(queryController.text.trim()),
            child: const Text('Search'),
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
    required String Function(String input) summaryBuilder,
  }) async {
    _triggerHaptic();
    final inputController = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: inputController,
          autofocus: true,
          decoration: InputDecoration(labelText: label, hintText: hint),
          onSubmitted: (val) => Navigator.of(dialogContext).pop(val.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(inputController.text.trim()),
            child: Text(buttonLabel),
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
              unawaited(controller.refreshEnvironment());
            },
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh device status',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const Center(
            child: VisionStatusBadge(
              label: AppConstants.currentPhaseLabel,
              icon: Icons.phonelink_setup_rounded,
            ),
          ),
          const SizedBox(height: 16),
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
          _DeviceTelemetryCard(status: automationState.deviceStatus),
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
              actionType: DeviceActionType.webSearch,
              summaryBuilder: (q) => 'Search web for "$q"',
            ),
            onNavigateTap: () => _openTextInputActionDialog(
              title: 'Maps Navigation',
              label: 'Destination or place',
              hint: 'e.g. Ahmedabad Airport',
              buttonLabel: 'Navigate',
              actionType: DeviceActionType.navigateTo,
              summaryBuilder: (dest) => 'Navigate to $dest',
            ),
            onOpenUrlTap: () => _openTextInputActionDialog(
              title: 'Open Web URL',
              label: 'Website URL',
              hint: 'https://flutter.dev',
              buttonLabel: 'Open',
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
          if (automationState.recentActions.isNotEmpty) ...[
            const SizedBox(height: 16),
            _RecentActionsCard(entries: automationState.recentActions),
          ],
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
    return VisionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Run Device Command', style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            'Try "set alarm for 6:30 am", "set timer for 5 minutes", '
            '"open Camera", "open Wi-Fi settings", or "call Mom".',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onExecute(),
                  decoration: const InputDecoration(
                    hintText: 'Enter an Android action command...',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: isExecuting ? null : onExecute,
                icon: isExecuting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('Run'),
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
    return VisionCard(
      borderColor: AppColors.error.withValues(alpha: 0.7),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.error,
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
  const _DeviceTelemetryCard({required this.status});

  final DeviceStatusSnapshot? status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final snapshot = status;
    final batteryLabel = snapshot != null && snapshot.batteryLevel >= 0
        ? '${snapshot.batteryLevel}%${snapshot.isCharging ? ' (Charging)' : ''}'
        : 'Unavailable';

    return VisionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.phone_android_rounded,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  snapshot != null
                      ? '${snapshot.manufacturer} ${snapshot.model}'
                      : AppConstants.targetDeviceName,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              VisionStatusBadge(
                label: snapshot?.isColorOs == true ? 'ColorOS' : 'Android',
                indicatorColor: AppColors.success,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
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
                      ? AppColors.success
                      : AppColors.warning,
                ),
              if (snapshot != null && snapshot.isColorOs)
                VisionStatusBadge(
                  label: snapshot.isIgnoringBatteryOptimizations
                      ? 'Battery: Unrestricted'
                      : 'Battery: Optimized',
                  indicatorColor: snapshot.isIgnoringBatteryOptimizations
                      ? AppColors.success
                      : AppColors.warning,
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
    return VisionCard(
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
            indicatorColor: AppColors.success,
          )
        else
          OutlinedButton(onPressed: onRequest, child: const Text('Grant')),
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
    return VisionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('System Intents & Actions', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ActionChip(
                avatar: const Icon(Icons.call_rounded, size: 18),
                label: const Text('Call / Contact'),
                onPressed: onCallTap,
              ),
              ActionChip(
                avatar: const Icon(Icons.sms_outlined, size: 18),
                label: const Text('Send SMS'),
                onPressed: onSmsTap,
              ),
              ActionChip(
                avatar: const Icon(Icons.contacts_outlined, size: 18),
                label: const Text('Lookup Contact'),
                onPressed: onLookupContactTap,
              ),
              ActionChip(
                avatar: const Icon(Icons.alarm_add_rounded, size: 18),
                label: const Text('Set Alarm'),
                onPressed: onAlarmTap,
              ),
              ActionChip(
                avatar: const Icon(Icons.timer_outlined, size: 18),
                label: const Text('Start Timer'),
                onPressed: onTimerTap,
              ),
              ActionChip(
                avatar: const Icon(Icons.apps_rounded, size: 18),
                label: const Text('Launch App'),
                onPressed: onLaunchAppTap,
              ),
              ActionChip(
                avatar: const Icon(Icons.travel_explore_rounded, size: 18),
                label: const Text('Web Search'),
                onPressed: onWebSearchTap,
              ),
              ActionChip(
                avatar: const Icon(Icons.directions_rounded, size: 18),
                label: const Text('Navigate'),
                onPressed: onNavigateTap,
              ),
              ActionChip(
                avatar: const Icon(Icons.open_in_browser_rounded, size: 18),
                label: const Text('Open URL'),
                onPressed: onOpenUrlTap,
              ),
              ActionChip(
                avatar: Icon(
                  flashlightOn
                      ? Icons.flashlight_on_rounded
                      : Icons.flashlight_off_rounded,
                  size: 18,
                ),
                label: Text(flashlightOn ? 'Torch On' : 'Torch Off'),
                onPressed: onFlashlightTap,
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Text(
            'AUDIO & RINGER MODE',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
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
                ChoiceChip(
                  label: Text(mode.$2),
                  selected: ringerMode == mode.$1,
                  onSelected: (_) => onSetRingerMode(mode.$1),
                ),
              ActionChip(
                avatar: const Icon(Icons.volume_up_rounded, size: 18),
                label: const Text('Vol +'),
                onPressed: () => onAdjustVolume('up'),
              ),
              ActionChip(
                avatar: const Icon(Icons.volume_down_rounded, size: 18),
                label: const Text('Vol -'),
                onPressed: () => onAdjustVolume('down'),
              ),
              ActionChip(
                avatar: const Icon(Icons.volume_off_rounded, size: 18),
                label: const Text('Mute'),
                onPressed: () => onAdjustVolume('mute'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Text(
            'SYSTEM SETTINGS SHORTCUTS',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
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
                OutlinedButton(
                  onPressed: () => onOpenSettingsSection(entry.$1),
                  child: Text(entry.$2),
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
    return VisionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recent Automation Log', style: theme.textTheme.titleMedium),
          const SizedBox(height: 10),
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
                        ? AppColors.success
                        : AppColors.warning,
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

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            children: [
              Text(
                'Launch Installed App (${widget.apps.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              TextField(
                onChanged: (value) => setState(() => _filter = value),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'Search installed apps...',
                  isDense: true,
                ),
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
                        controller: scrollController,
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
      },
    );
  }
}
