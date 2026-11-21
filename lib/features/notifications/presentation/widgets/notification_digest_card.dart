import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/theme/vision_radius.dart';
import 'package:vision_ai/core/theme/vision_spacing.dart';
import 'package:vision_ai/core/theme/vision_theme_extension.dart';
import 'package:vision_ai/core/widgets/glass/vision_glass_widgets.dart';
import 'package:vision_ai/core/widgets/vision_bottom_sheet.dart';
import 'package:vision_ai/core/widgets/vision_primary_button.dart';
import 'package:vision_ai/core/widgets/vision_secondary_button.dart';
import 'package:vision_ai/features/notifications/domain/entities/notification_digest.dart';
import 'package:vision_ai/features/notifications/presentation/controllers/notification_digest_controller.dart';
import 'package:vision_ai/features/voice/presentation/controllers/voice_controller.dart';

/// Compact Home Screen card for Smart Notification Digest & Voice Catch-Up.
class NotificationDigestCard extends ConsumerWidget {
  const NotificationDigestCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationDigestControllerProvider);
    final controller = ref.read(notificationDigestControllerProvider.notifier);
    final colors = context.visionColors;
    final textTheme = Theme.of(context).textTheme;
    final digest = state.digest;

    return VisionGlassCard(
      padding: const EdgeInsets.all(VisionSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.notifications_active_outlined,
                size: 20,
                color: colors.primary,
              ),
              const SizedBox(width: VisionSpacing.xs),
              Expanded(
                child: Text(
                  'SMART CATCH-UP DIGEST',
                  style: textTheme.labelLarge?.copyWith(
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (digest != null && digest.protectedLocalCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: colors.elevatedSurface,
                    borderRadius: VisionRadius.smBorder,
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.shield_outlined,
                        size: 12,
                        color: colors.success,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${digest.protectedLocalCount} OTP/Bank local',
                        style: textTheme.labelSmall?.copyWith(
                          color: colors.success,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (!state.isReady) ...<Widget>[
            Text(
              'Let VISION summarize unread WhatsApp & SMS in EN/HI/GU with 1-tap smart replies. OTPs & banking alerts stay 100% private on device.',
              style: textTheme.bodySmall,
            ),
            const SizedBox(height: VisionSpacing.sm),
            VisionPrimaryButton(
              label: 'Enable Smart Catch-Up',
              icon: Icons.auto_awesome_rounded,
              isLoading: state.isLoading,
              expanded: true,
              onPressed: controller.enableNotificationCatchUp,
            ),
          ] else ...<Widget>[
            Text(
              digest == null
                  ? 'Tap Refresh or say "What did I miss?" for an instant voice catch-up.'
                  : digest.spokenSummary,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: VisionSpacing.sm),
            Wrap(
              spacing: VisionSpacing.xs,
              runSpacing: VisionSpacing.xs,
              children: <Widget>[
                VisionPrimaryButton(
                  label: 'Speak Catch-Up',
                  icon: Icons.record_voice_over_rounded,
                  isLoading: state.isLoading,
                  onPressed: () => unawaited(
                    controller.refreshDigest(speak: true),
                  ),
                ),
                VisionSecondaryButton(
                  label: digest != null && digest.items.isNotEmpty
                      ? 'Open Digest (${digest.items.length})'
                      : 'Open Digest',
                  icon: Icons.inbox_rounded,
                  onPressed: state.isLoading
                      ? null
                      : () async {
                          if (digest == null) {
                            await controller.refreshDigest();
                          }
                          if (context.mounted) {
                            await NotificationDigestSheet.show(context);
                          }
                        },
                ),
              ],
            ),
          ],
          if (state.statusMessage != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              state.statusMessage!,
              style: textTheme.labelSmall?.copyWith(color: colors.success),
            ),
          ],
          if (state.errorMessage != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              state.errorMessage!,
              style: textTheme.labelSmall?.copyWith(color: colors.error),
            ),
          ],
        ],
      ),
    );
  }
}

/// Interactive bottom sheet displaying prioritized notifications with 1-tap
/// contextual Smart Reply chips, Open, and Dismiss controls.
class NotificationDigestSheet extends ConsumerWidget {
  const NotificationDigestSheet({super.key});

  static Future<void> show(BuildContext context) {
    return VisionBottomSheet.show<void>(
      context,
      title: 'Smart Notification Digest',
      child: const NotificationDigestSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationDigestControllerProvider);
    final controller = ref.read(notificationDigestControllerProvider.notifier);
    final colors = context.visionColors;
    final textTheme = Theme.of(context).textTheme;
    final digest = state.digest;

    if (state.isLoading && digest == null) {
      return const Padding(
        padding: EdgeInsets.all(VisionSpacing.lg),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (digest == null || digest.isEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'You are all caught up! No unread notifications captured yet.',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: VisionSpacing.md),
          VisionPrimaryButton(
            label: 'Refresh Notifications',
            icon: Icons.refresh_rounded,
            isLoading: state.isLoading,
            expanded: true,
            onPressed: () => unawaited(controller.refreshDigest()),
          ),
        ],
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 520),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(VisionSpacing.sm),
              decoration: BoxDecoration(
                color: colors.elevatedSurface,
                borderRadius: VisionRadius.mdBorder,
                border: Border.all(color: colors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(digest.spokenSummary, style: textTheme.bodyMedium),
                  const SizedBox(height: VisionSpacing.xs),
                  Row(
                    children: <Widget>[
                      TextButton.icon(
                        onPressed: () => unawaited(
                          ref
                              .read(voiceControllerProvider.notifier)
                              .speakReply(digest.spokenSummary),
                        ),
                        icon: const Icon(Icons.volume_up_rounded, size: 16),
                        label: const Text('Read Aloud'),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: state.isLoading
                            ? null
                            : () => unawaited(controller.refreshDigest()),
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Refresh'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (digest.protectedLocalCount > 0) ...<Widget>[
              const SizedBox(height: VisionSpacing.sm),
              Row(
                children: <Widget>[
                  Icon(Icons.shield_outlined, size: 16, color: colors.success),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${digest.protectedLocalCount} sensitive OTP / banking alert(s) were kept strictly on-device and never sent to AI.',
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.success,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: VisionSpacing.sm),
            for (final item in digest.items) ...<Widget>[
              _DigestItemTile(
                item: item,
                onReply: (replyText) => unawaited(
                  controller.sendQuickReply(
                    notificationKey: item.notification.key,
                    replyText: replyText,
                  ),
                ),
                onOpen: () => unawaited(
                  controller.openNotification(item.notification.key),
                ),
                onDismiss: () => unawaited(
                  controller.dismissNotification(item.notification.key),
                ),
              ),
              const SizedBox(height: VisionSpacing.xs),
            ],
          ],
        ),
      ),
    );
  }
}

class _DigestItemTile extends StatelessWidget {
  const _DigestItemTile({
    required this.item,
    required this.onReply,
    required this.onOpen,
    required this.onDismiss,
  });

  final DigestItemSummary item;
  final ValueChanged<String> onReply;
  final VoidCallback onOpen;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = context.visionColors;
    final textTheme = Theme.of(context).textTheme;
    final priorityLabel = switch (item.priority) {
      DigestItemPriority.urgent => 'URGENT',
      DigestItemPriority.people => 'MESSAGE',
      DigestItemPriority.update => 'UPDATE',
    };

    return Container(
      padding: const EdgeInsets.all(VisionSpacing.sm),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: VisionRadius.mdBorder,
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                item.notification.appName,
                style: textTheme.labelMedium?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '• $priorityLabel',
                style: textTheme.labelSmall?.copyWith(
                  color: item.priority == DigestItemPriority.urgent
                      ? colors.error
                      : colors.textSecondary,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Open app',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                onPressed: onOpen,
              ),
              IconButton(
                tooltip: 'Dismiss',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close_rounded, size: 16),
                onPressed: onDismiss,
              ),
            ],
          ),
          Text(item.oneLineSummary, style: textTheme.bodyMedium),
          if (item.suggestedReplies.isNotEmpty) ...<Widget>[
            const SizedBox(height: VisionSpacing.xs),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                for (final suggestion in item.suggestedReplies)
                  ActionChip(
                    label: Text(suggestion.label),
                    avatar: const Icon(Icons.reply_rounded, size: 14),
                    onPressed: () => onReply(suggestion.replyText),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
