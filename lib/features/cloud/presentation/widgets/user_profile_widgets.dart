import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/app/router/app_routes.dart';
import 'package:vision_ai/core/theme/vision_radius.dart';
import 'package:vision_ai/core/theme/vision_spacing.dart';
import 'package:vision_ai/core/theme/vision_theme_extension.dart';
import 'package:vision_ai/core/widgets/vision_bottom_sheet.dart';
import 'package:vision_ai/core/widgets/vision_primary_button.dart';
import 'package:vision_ai/core/widgets/vision_secondary_button.dart';
import 'package:vision_ai/features/cloud/presentation/controllers/cloud_auth_controller.dart';

/// Displays the signed-in Google user's avatar photo with a graceful offline
/// fallback to themed initials or a guest icon.
class VisionUserAvatar extends StatelessWidget {
  const VisionUserAvatar({
    required this.authState,
    super.key,
    this.radius = 18,
  });

  final CloudAuthState authState;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = context.visionColors;
    final textTheme = Theme.of(context).textTheme;
    final url = authState.avatarUrl;

    if (!authState.isSignedIn) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: colors.elevatedSurface,
        child: Icon(
          Icons.person_outline_rounded,
          size: radius * 1.1,
          color: colors.textSecondary,
        ),
      );
    }

    if (url != null && url.isNotEmpty) {
      return ClipOval(
        child: SizedBox(
          width: radius * 2,
          height: radius * 2,
          child: Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _InitialsCircle(
              radius: radius,
              initials: authState.initials,
              background: colors.primaryContainer,
              foreground: colors.primary,
              style: textTheme.labelLarge,
            ),
          ),
        ),
      );
    }

    return _InitialsCircle(
      radius: radius,
      initials: authState.initials,
      background: colors.primaryContainer,
      foreground: colors.primary,
      style: textTheme.labelLarge,
    );
  }
}

class _InitialsCircle extends StatelessWidget {
  const _InitialsCircle({
    required this.radius,
    required this.initials,
    required this.background,
    required this.foreground,
    required this.style,
  });

  final double radius;
  final String initials;
  final Color background;
  final Color foreground;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: background,
      child: Text(
        initials,
        style: style?.copyWith(
          color: foreground,
          fontSize: radius * 0.78,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Interactive profile sheet displaying the signed-in Google user's photo,
/// display name, email, sync status, and quick account actions.
class VisionUserProfileSheet extends ConsumerWidget {
  const VisionUserProfileSheet({super.key});

  static Future<void> show(BuildContext context) {
    return VisionBottomSheet.show<void>(
      context,
      title: 'VISION Account',
      child: const VisionUserProfileSheet(),
    );
  }

  static String _formatSyncTime(DateTime dt) {
    final local = dt.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cloud = ref.watch(cloudAuthControllerProvider);
    final controller = ref.read(cloudAuthControllerProvider.notifier);
    final colors = context.visionColors;
    final textTheme = Theme.of(context).textTheme;

    if (!cloud.isSignedIn) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              VisionUserAvatar(authState: cloud, radius: 24),
              const SizedBox(width: VisionSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Guest Mode', style: textTheme.titleMedium),
                    Text(
                      cloud.isConfigured
                          ? 'Sign in with Google to sync history & encrypted API keys'
                          : 'Running locally on device',
                      style: textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: VisionSpacing.md),
          if (cloud.isConfigured)
            VisionPrimaryButton(
              label: 'Sign in with Google',
              icon: Icons.login_rounded,
              isLoading: cloud.isBusy,
              expanded: true,
              onPressed: controller.signInWithGoogle,
            )
          else
            VisionSecondaryButton(
              label: 'Open Cloud Sync Settings',
              icon: Icons.tune_rounded,
              expanded: true,
              onPressed: () {
                Navigator.of(context).pop();
                context.go(AppRoutes.settingsPath);
              },
            ),
          if (cloud.errorMessage != null) ...<Widget>[
            const SizedBox(height: VisionSpacing.xs),
            Text(
              cloud.errorMessage!,
              style: textTheme.bodySmall?.copyWith(color: colors.error),
            ),
          ],
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(VisionSpacing.md),
          decoration: BoxDecoration(
            color: colors.elevatedSurface,
            borderRadius: VisionRadius.lgBorder,
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: <Widget>[
              VisionUserAvatar(authState: cloud, radius: 28),
              const SizedBox(width: VisionSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      cloud.displayName ?? 'Google User',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      cloud.email ?? 'Signed in',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.verified_user_outlined,
                          size: 14,
                          color: colors.success,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          cloud.lastSyncedAt != null
                              ? 'Synced at ${_formatSyncTime(cloud.lastSyncedAt!)}'
                              : 'Connected to Supabase',
                          style: textTheme.labelSmall?.copyWith(
                            color: colors.success,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: VisionSpacing.md),
        Row(
          children: <Widget>[
            Expanded(
              child: VisionPrimaryButton(
                label: 'Sync Now',
                icon: Icons.sync_rounded,
                isLoading: cloud.isBusy,
                onPressed: controller.syncThreadsNow,
              ),
            ),
            const SizedBox(width: VisionSpacing.xs),
            Expanded(
              child: VisionSecondaryButton(
                label: 'Sign Out',
                icon: Icons.logout_rounded,
                onPressed: cloud.isBusy
                    ? null
                    : () async {
                        await controller.signOut();
                        if (context.mounted) Navigator.of(context).pop();
                      },
              ),
            ),
          ],
        ),
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
    );
  }
}
