import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/theme/vision_radius.dart';
import 'package:vision_ai/core/theme/vision_spacing.dart';
import 'package:vision_ai/core/theme/vision_theme_extension.dart';
import 'package:vision_ai/core/widgets/vision_dialog.dart';
import 'package:vision_ai/core/widgets/vision_primary_button.dart';
import 'package:vision_ai/core/widgets/vision_secondary_button.dart';
import 'package:vision_ai/core/widgets/vision_text_field.dart';
import 'package:vision_ai/features/cloud/presentation/controllers/cloud_auth_controller.dart';
import 'package:vision_ai/features/cloud/presentation/widgets/user_profile_widgets.dart';
import 'package:vision_ai/features/settings/presentation/widgets/settings_section_card.dart';

/// Settings card for optional Google Sign-In, logged-in user profile display,
/// Supabase conversation sync, and Zero-Knowledge AES-256-GCM API key backup.
class CloudSyncSettingsSection extends ConsumerWidget {
  const CloudSyncSettingsSection({super.key});

  Future<String?> _promptSyncPassphrase(
    BuildContext context, {
    required String title,
    required String actionLabel,
  }) async {
    final controller = TextEditingController();
    final passphrase = await VisionDialog.show<String>(
      context,
      title: title,
      icon: Icons.enhanced_encryption_outlined,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Your API keys are encrypted on-device with AES-256-GCM before '
            'uploading to Supabase. Supabase never sees plaintext keys.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: VisionSpacing.sm),
          VisionTextField(
            controller: controller,
            labelText: 'Sync Passphrase (min 6 chars)',
            hintText: 'Enter passphrase',
            prefixIcon: Icons.key_rounded,
            obscureText: true,
          ),
        ],
      ),
      actions: <Widget>[
        VisionSecondaryButton(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
        ),
        VisionPrimaryButton(
          label: actionLabel,
          onPressed: () => Navigator.of(context).pop(controller.text),
        ),
      ],
    );
    controller.dispose();
    return passphrase;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cloud = ref.watch(cloudAuthControllerProvider);
    final controller = ref.read(cloudAuthControllerProvider.notifier);
    final colors = context.visionColors;
    final textTheme = Theme.of(context).textTheme;

    return SettingsSectionCard(
      title: 'Account & Cloud Sync',
      subtitle: 'Optional Google Sign-In & Supabase encrypted backup',
      icon: Icons.cloud_sync_outlined,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(VisionSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (!cloud.isConfigured) ...<Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.cloud_off_rounded,
                      size: 20,
                      color: colors.textSecondary,
                    ),
                    const SizedBox(width: VisionSpacing.xs),
                    Expanded(
                      child: Text(
                        'Guest / Local Mode Active',
                        style: textTheme.titleSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Build with --dart-define=SUPABASE_URL, SUPABASE_ANON_KEY, '
                  'and GOOGLE_WEB_CLIENT_ID to enable Google Sign-In and '
                  'encrypted cloud backup. See docs/CLOUD_SYNC_AND_THREADS.md.',
                  style: textTheme.bodySmall,
                ),
              ] else if (!cloud.isSignedIn) ...<Widget>[
                Text(
                  'Sign in with Google to sync your conversation threads and '
                  'zero-knowledge encrypted API keys across devices.',
                  style: textTheme.bodySmall,
                ),
                const SizedBox(height: VisionSpacing.sm),
                VisionPrimaryButton(
                  label: 'Sign in with Google',
                  icon: Icons.login_rounded,
                  isLoading: cloud.isBusy,
                  expanded: true,
                  onPressed: controller.signInWithGoogle,
                ),
                const SizedBox(height: VisionSpacing.xs),
                VisionSecondaryButton(
                  label: 'Sign in via Browser (OAuth)',
                  icon: Icons.open_in_browser_rounded,
                  expanded: true,
                  onPressed: cloud.isBusy
                      ? null
                      : controller.signInWithGoogleBrowser,
                ),
              ] else ...<Widget>[
                Container(
                  padding: const EdgeInsets.all(VisionSpacing.sm),
                  decoration: BoxDecoration(
                    color: colors.elevatedSurface,
                    borderRadius: VisionRadius.mdBorder,
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    children: <Widget>[
                      VisionUserAvatar(authState: cloud, radius: 24),
                      const SizedBox(width: VisionSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              cloud.displayName ?? 'Google Account',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.titleSmall,
                            ),
                            Text(
                              cloud.email ?? 'Signed in',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodySmall,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: <Widget>[
                                Icon(
                                  Icons.verified_user_outlined,
                                  size: 13,
                                  color: colors.success,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Signed in with Google',
                                  style: textTheme.labelSmall?.copyWith(
                                    color: colors.success,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: cloud.isBusy ? null : controller.signOut,
                        child: const Text('Sign Out'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: VisionSpacing.sm),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Sync Conversation History',
                    style: textTheme.bodyLarge,
                  ),
                  subtitle: Text(
                    'Sync multi-thread chats with your Supabase account',
                    style: textTheme.bodySmall,
                  ),
                  value: cloud.cloudHistorySyncEnabled,
                  onChanged: (value) =>
                      controller.setCloudHistorySyncEnabled(value),
                ),
                const SizedBox(height: VisionSpacing.xs),
                Wrap(
                  spacing: VisionSpacing.xs,
                  runSpacing: VisionSpacing.xs,
                  children: <Widget>[
                    VisionPrimaryButton(
                      label: 'Sync Threads',
                      icon: Icons.sync_rounded,
                      isLoading: cloud.isBusy,
                      onPressed: controller.syncThreadsNow,
                    ),
                    VisionSecondaryButton(
                      label: 'Backup Keys',
                      icon: Icons.cloud_upload_outlined,
                      onPressed: cloud.isBusy
                          ? null
                          : () async {
                              final pass = await _promptSyncPassphrase(
                                context,
                                title: 'Encrypt & Backup API Keys',
                                actionLabel: 'Encrypt & Upload',
                              );
                              if (pass != null && pass.isNotEmpty) {
                                await controller.backupApiKeysToCloud(pass);
                              }
                            },
                    ),
                    VisionSecondaryButton(
                      label: 'Restore Keys',
                      icon: Icons.cloud_download_outlined,
                      onPressed: cloud.isBusy
                          ? null
                          : () async {
                              final pass = await _promptSyncPassphrase(
                                context,
                                title: 'Decrypt & Restore API Keys',
                                actionLabel: 'Decrypt & Restore',
                              );
                              if (pass != null && pass.isNotEmpty) {
                                await controller.restoreApiKeysFromCloud(pass);
                              }
                            },
                    ),
                  ],
                ),
              ],
              if (cloud.statusMessage != null) ...<Widget>[
                const SizedBox(height: VisionSpacing.xs),
                Text(
                  cloud.statusMessage!,
                  style: textTheme.bodySmall?.copyWith(color: colors.success),
                ),
              ],
              if (cloud.errorMessage != null) ...<Widget>[
                const SizedBox(height: VisionSpacing.xs),
                Text(
                  cloud.errorMessage!,
                  style: textTheme.bodySmall?.copyWith(color: colors.error),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
