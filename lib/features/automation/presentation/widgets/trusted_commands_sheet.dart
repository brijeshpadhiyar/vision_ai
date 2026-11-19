import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/theme/vision_colors.dart';
import 'package:vision_ai/features/automation/domain/entities/trusted_command_policy.dart';
import 'package:vision_ai/features/automation/presentation/controllers/trusted_commands_controller.dart';

/// Bottom sheet allowing users to inspect, grant, and revoke trusted sensitive commands
/// as well as manage the notification privacy blocklist (Modules 10, 15, Section 6).
class TrustedCommandsSheet extends ConsumerStatefulWidget {
  const TrustedCommandsSheet({super.key});

  @override
  ConsumerState<TrustedCommandsSheet> createState() =>
      _TrustedCommandsSheetState();
}

class _TrustedCommandsSheetState extends ConsumerState<TrustedCommandsSheet> {
  final TextEditingController _pkgController = TextEditingController();

  @override
  void dispose() {
    _pkgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trustState = ref.watch(trustedCommandsControllerProvider);
    final controller = ref.read(trustedCommandsControllerProvider.notifier);
    final brightness = Theme.of(context).brightness;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Trusted Commands & Privacy',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: VisionColors.primaryText(brightness),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (trustState.trustedSensitiveActions.isNotEmpty)
                  TextButton(
                    onPressed: controller.revokeAll,
                    child: const Text('Revoke All'),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Safe commands (alarms, timers, apps, settings, flashlight, volume) are trusted by default. '
              'Sensitive commands below require confirmation unless explicitly trusted.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: VisionColors.secondaryText(brightness),
              ),
            ),
            const SizedBox(height: 12),
            for (final action in TrustedCommandPolicy.sensitiveActionTypes)
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(action.displayName),
                subtitle: Text(
                  trustState.isActionTrusted(action)
                      ? 'Trusted • Executes without extra confirmation'
                      : 'Confirmation required before executing',
                ),
                value: trustState.isActionTrusted(action),
                onChanged: (val) async {
                  if (val) {
                    await controller.trustAction(action);
                  } else {
                    await controller.revokeAction(action);
                  }
                },
              ),
            const Divider(height: 28),
            Text(
              'Notification Privacy Blocklist',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: VisionColors.primaryText(brightness),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Notifications from blocked packages (e.g., banking or OTP apps) are ignored by VISION.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: VisionColors.secondaryText(brightness),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _pkgController,
                    decoration: const InputDecoration(
                      hintText: 'Package name (e.g. com.bank.app)',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () async {
                    final pkg = _pkgController.text.trim();
                    if (pkg.isEmpty) return;
                    await controller.blockNotificationPackage(pkg);
                    _pkgController.clear();
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
                  for (final pkg in trustState.blockedNotificationPackages)
                    Chip(
                      label: Text(pkg),
                      onDeleted: () =>
                          controller.unblockNotificationPackage(pkg),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
