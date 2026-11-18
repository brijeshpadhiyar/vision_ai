import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/theme/vision_colors.dart';
import 'package:vision_ai/core/theme/vision_glass.dart';
import 'package:vision_ai/core/widgets/glass/vision_glass_button.dart';
import 'package:vision_ai/core/widgets/glass/vision_glass_card.dart';
import 'package:vision_ai/features/automation/domain/entities/device_action.dart';
import 'package:vision_ai/features/automation/presentation/controllers/automation_controller.dart';

/// Shared Liquid Glass card for pending device confirmations, contact
/// disambiguation, contact lookup results, and runtime permission recovery.
class AutomationActionPromptCard extends StatelessWidget {
  const AutomationActionPromptCard({
    required this.automationState,
    required this.onConfirm,
    required this.onCancel,
    required this.onSelectContact,
    required this.onGrantPermission,
    this.onCallContact,
    this.onMessageContact,
    this.onClearSearchResults,
    this.compact = false,
    super.key,
  });

  final AutomationState automationState;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final ValueChanged<ContactMatch> onSelectContact;
  final ValueChanged<AutomationPermission> onGrantPermission;
  final ValueChanged<ContactMatch>? onCallContact;
  final ValueChanged<ContactMatch>? onMessageContact;
  final VoidCallback? onClearSearchResults;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final hasPending =
        automationState.pendingConfirmation != null ||
        automationState.contactChoices.isNotEmpty;
    final hasLookupResults = automationState.contactSearchResults.isNotEmpty;
    final lastResult = automationState.lastResult;
    final missingPermission =
        (lastResult != null &&
            lastResult.requiresPermission &&
            lastResult.missingPermission != null)
        ? lastResult.missingPermission
        : null;

    if (!hasPending && !hasLookupResults && missingPermission == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final accent = VisionColors.primaryAccent(brightness);

    if (hasPending) {
      final isDisambiguation = automationState.contactChoices.isNotEmpty;
      final isSmsPending =
          automationState.pendingConfirmation?.type == DeviceActionType.sendSms;

      return VisionGlassCard(
        variant: VisionGlassVariant.accent,
        borderColor: VisionColors.warning.withValues(alpha: 0.72),
        padding: EdgeInsets.all(compact ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.verified_user_outlined,
                  color: VisionColors.warning,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isDisambiguation
                        ? 'Select Contact'
                        : 'Confirm Device Action',
                    style: compact
                        ? theme.textTheme.titleSmall
                        : theme.textTheme.titleMedium,
                  ),
                ),
                TextButton(onPressed: onCancel, child: const Text('Cancel')),
              ],
            ),
            if (automationState.pendingConfirmation != null) ...[
              const SizedBox(height: 4),
              Text(
                automationState.pendingConfirmation!.displaySummary,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: VisionColors.primaryText(brightness),
                ),
              ),
            ],
            if (isDisambiguation) ...[
              const SizedBox(height: 8),
              for (final contact in automationState.contactChoices.take(
                compact ? 4 : 8,
              ))
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.person_outline_rounded, color: accent),
                  title: Text(contact.name),
                  subtitle: Text('${contact.phoneNumber} • ${contact.label}'),
                  trailing: Icon(
                    isSmsPending ? Icons.sms_outlined : Icons.call_outlined,
                    size: 18,
                  ),
                  onTap: () => onSelectContact(contact),
                ),
            ] else ...[
              const SizedBox(height: 12),
              VisionGlassButton(
                expand: true,
                compact: compact,
                icon: Icons.check_rounded,
                label: compact ? 'Confirm' : 'Confirm & Execute',
                onPressed: onConfirm,
              ),
            ],
          ],
        ),
      );
    }

    if (hasLookupResults) {
      return VisionGlassCard(
        borderColor: accent.withValues(alpha: 0.55),
        padding: EdgeInsets.all(compact ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.contacts_outlined, color: accent, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Matching Contacts',
                    style: compact
                        ? theme.textTheme.titleSmall
                        : theme.textTheme.titleMedium,
                  ),
                ),
                if (onClearSearchResults != null)
                  TextButton(
                    onPressed: onClearSearchResults,
                    child: const Text('Dismiss'),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            for (final contact in automationState.contactSearchResults.take(
              compact ? 4 : 8,
            ))
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(contact.name),
                subtitle: Text('${contact.phoneNumber} • ${contact.label}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onMessageContact != null)
                      IconButton(
                        tooltip: 'Send SMS to ${contact.name}',
                        icon: const Icon(Icons.sms_outlined, size: 18),
                        onPressed: () => onMessageContact!(contact),
                      ),
                    if (onCallContact != null)
                      IconButton(
                        tooltip: 'Call ${contact.name}',
                        icon: const Icon(Icons.call_outlined, size: 18),
                        onPressed: () => onCallContact!(contact),
                      ),
                  ],
                ),
              ),
          ],
        ),
      );
    }

    return VisionGlassCard(
      borderColor: VisionColors.warning.withValues(alpha: 0.7),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          const Icon(
            Icons.admin_panel_settings_outlined,
            color: VisionColors.warning,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              lastResult?.summary ??
                  'Permission required: ${missingPermission!.displayName}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: VisionColors.primaryText(brightness),
              ),
            ),
          ),
          const SizedBox(width: 8),
          VisionGlassButton(
            label: 'Grant',
            compact: true,
            onPressed: () => onGrantPermission(missingPermission!),
          ),
        ],
      ),
    );
  }
}
