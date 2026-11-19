import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/theme/vision_colors.dart';
import 'package:vision_ai/features/automation/domain/entities/device_action.dart';

/// Device-adaptive Android reliability setup guide for background wake-word,
/// scheduled routines, boot recovery, and Default Digital Assistant (v1.1 Wave 1).
///
/// Automatically adapts its title and OEM battery/auto-launch instructions to
/// the installed phone's detected manufacturer, model, and ROM skin.
class DeviceSetupGuideSheet extends StatelessWidget {
  const DeviceSetupGuideSheet({
    super.key,
    required this.deviceStatus,
    required this.isDefaultAssistant,
    required this.onOpenBatterySettings,
    required this.onRequestDefaultAssistant,
  });

  final DeviceStatusSnapshot? deviceStatus;
  final bool isDefaultAssistant;
  final VoidCallback onOpenBatterySettings;
  final VoidCallback onRequestDefaultAssistant;

  String get _deviceName =>
      deviceStatus?.deviceDisplayName ?? 'Your Android Device';

  String get _oemSkin => deviceStatus?.resolvedOemSkin ?? 'Android';

  String _batteryInstructions() {
    return switch (_oemSkin) {
      'ColorOS' || 'Realme UI' => 'Settings → Apps → VISION → Battery usage → Enable "Allow background activity" & "Allow foreground activity".',
      'OxygenOS' => 'Settings → Apps → App management → VISION → Battery usage → Allow background activity.',
      'One UI' => 'Settings → Apps → VISION → Battery → Select "Unrestricted" and remove VISION from Sleeping / Deep sleeping apps.',
      'HyperOS / MIUI' => 'Settings → Apps → Manage apps → VISION → Battery saver → Select "No restrictions".',
      'Funtouch OS' => 'Settings → Apps → VISION → Battery → Select "Unrestricted" / Allow high background power consumption.',
      'Nothing OS' => 'Settings → Apps → VISION → App battery usage → Allow background usage (Unrestricted).',
      _ => 'Settings → Apps → VISION → App battery usage → Set to "Unrestricted" so background standby stays active.',
    };
  }

  String _autoLaunchInstructions() {
    return switch (_oemSkin) {
      'ColorOS' || 'Realme UI' || 'OxygenOS' =>
        'Enable "Allow auto-launch" in App Info, then open Recent Apps → tap ⋮ on VISION → Lock so $_oemSkin does not kill standby.',
      'HyperOS / MIUI' =>
        'Enable "Autostart" in App Info and lock VISION in Recent Apps so $_oemSkin keeps wake-word standby alive.',
      'One UI' => 'In Recent Apps, tap the VISION app icon → "Keep open" to prevent One UI memory management from stopping standby.',
      'Funtouch OS' => 'Enable "Autostart" in iManager / App Info and lock VISION in Recent Apps.',
      _ => 'Avoid force-stopping VISION from App Info, and lock it in Recent Apps if your device aggressively closes background apps.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final title = _oemSkin != 'Android'
        ? '$_deviceName • $_oemSkin Guide'
        : '$_deviceName • Android Setup Guide';

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: VisionColors.primaryText(brightness),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tailored steps for your installed $_deviceName ($_oemSkin) so '
              '"Hey VISION", scheduled routines, and lock-screen activation stay reliable.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: VisionColors.secondaryText(brightness)),
            ),
            const SizedBox(height: 14),
            _GuideStepTile(
              stepNumber: '1',
              title: 'Set VISION as Default Digital Assistant',
              description: isDefaultAssistant
                  ? 'Active! Power/corner Assist gestures launch VISION.'
                  : 'Required for system Assist gestures & lock-screen overlay.',
              actionLabel: isDefaultAssistant ? 'Active' : 'Configure',
              onAction: isDefaultAssistant ? null : onRequestDefaultAssistant,
            ),
            _GuideStepTile(
              stepNumber: '2',
              title: 'Allow Unrestricted Background Activity',
              description: _batteryInstructions(),
              actionLabel: 'Open Battery',
              onAction: onOpenBatterySettings,
            ),
            _GuideStepTile(
              stepNumber: '3',
              title: 'Auto-Launch & Recents Protection',
              description: _autoLaunchInstructions(),
            ),
            const _GuideStepTile(
              stepNumber: '4',
              title: 'After Device Reboot (Android 14+)',
              description:
                  'Android 14+ requires a tap to re-arm microphone standby after reboot. '
                  'Tap the "Re-arm Hey VISION" notification or use the VISION Home-Screen Widget.',
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideStepTile extends StatelessWidget {
  const _GuideStepTile({
    required this.stepNumber,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  final String stepNumber;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: VisionColors.primaryAccent(brightness),
            child: Text(
              stepNumber,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: VisionColors.primaryText(brightness),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: VisionColors.secondaryText(brightness)),
                ),
              ],
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(width: 8),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
