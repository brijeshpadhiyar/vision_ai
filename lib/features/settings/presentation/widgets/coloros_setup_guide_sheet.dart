import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/theme/vision_colors.dart';

/// Dedicated OPPO Reno 16 / ColorOS setup guide for background wake-word,
/// boot recovery, and Default Digital Assistant reliability (Module 04).
class ColorOsSetupGuideSheet extends StatelessWidget {
  const ColorOsSetupGuideSheet({
    super.key,
    required this.isDefaultAssistant,
    required this.onOpenBatterySettings,
    required this.onRequestDefaultAssistant,
  });

  final bool isDefaultAssistant;
  final VoidCallback onOpenBatterySettings;
  final VoidCallback onRequestDefaultAssistant;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'OPPO Reno 16 / ColorOS Setup Guide',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: VisionColors.primaryText(brightness),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Complete these 4 ColorOS steps so "Hey VISION", scheduled routines, '
              'and lock-screen activation remain reliable.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: VisionColors.secondaryText(brightness),
              ),
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
              title: 'Allow Background Activity (Battery)',
              description:
                  'Settings → Apps → VISION → Battery usage → Allow background activity & Allow foreground activity.',
              actionLabel: 'Open Battery',
              onAction: onOpenBatterySettings,
            ),
            const _GuideStepTile(
              stepNumber: '3',
              title: 'Enable Auto-Launch & Lock in Recents',
              description:
                  'Enable "Allow auto-launch" in App Info, then open Recent Apps → tap ⋮ on VISION → Lock so ColorOS does not kill standby.',
            ),
            const _GuideStepTile(
              stepNumber: '4',
              title: 'After Device Reboot (Android 14+)',
              description:
                  'Android 14+ requires a tap to re-arm microphone standby after reboot. Tap the "Re-arm Hey VISION" notification or add the VISION Home-Screen Widget.',
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
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: VisionColors.secondaryText(brightness),
                  ),
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
