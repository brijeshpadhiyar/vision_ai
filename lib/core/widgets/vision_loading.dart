import 'package:material_ui/material_ui.dart';
import 'package:skeletonizer/skeletonizer.dart';

import 'package:vision_ai/core/theme/vision_animations.dart';
import 'package:vision_ai/core/theme/vision_colors.dart';
import 'package:vision_ai/core/theme/vision_radius.dart';
import 'package:vision_ai/core/theme/vision_spacing.dart';
import 'package:vision_ai/core/theme/vision_theme_extension.dart';

/// Theme-aware, reduced-motion-safe [Skeletonizer] wrapper and reusable
/// loading placeholders for VISION AI.
class VisionLoading extends StatelessWidget {
  const VisionLoading({
    required this.child,
    super.key,
    this.enabled = true,
    this.ignoreContainers = false,
  });

  final Widget child;
  final bool enabled;
  final bool ignoreContainers;

  static PaintingEffect _resolveEffect(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final tokens = VisionColorTokens.ofBrightness(brightness);
    final baseColor = brightness == Brightness.dark
        ? tokens.elevatedSurface
        : tokens.secondaryBackground;
    final highlightColor = brightness == Brightness.dark
        ? tokens.border
        : tokens.surface;

    if (!VisionAnimations.shouldAnimate(context)) {
      return SolidColorEffect(color: baseColor);
    }

    return ShimmerEffect(
      baseColor: baseColor,
      highlightColor: highlightColor,
      duration: VisionAnimations.shimmerCycle,
    );
  }

  /// AI provider status / configuration card loading placeholder.
  static Widget providerCard({Key? key}) {
    return _VisionProviderCardSkeleton(key: key);
  }

  /// Model list loading placeholder.
  static Widget modelList({Key? key, int itemCount = 3}) {
    return _VisionModelListSkeleton(key: key, itemCount: itemCount);
  }

  /// Chat assistant reply loading placeholder.
  static Widget chatPlaceholder({Key? key}) {
    return _VisionChatLoadingSkeleton(key: key);
  }

  /// Settings section loading placeholder.
  static Widget settingsSection({Key? key, int itemCount = 3}) {
    return _VisionSettingsLoadingSkeleton(key: key, itemCount: itemCount);
  }

  /// Conversation list / history loading placeholder.
  static Widget conversationList({Key? key, int itemCount = 4}) {
    return _VisionConversationLoadingSkeleton(key: key, itemCount: itemCount);
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = VisionAnimations.isReducedMotion(context);
    final colors = context.visionColors;
    final hasGlobalConfig = SkeletonizerConfig.maybeOf(context) != null;

    return Skeletonizer(
      enabled: enabled,
      ignoreContainers: ignoreContainers,
      containersColor: hasGlobalConfig ? null : colors.surface,
      effect: hasGlobalConfig ? null : _resolveEffect(context),
      enableSwitchAnimation: !reducedMotion,
      child: child,
    );
  }
}

class _VisionProviderCardSkeleton extends StatelessWidget {
  const _VisionProviderCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.visionColors;
    final textTheme = Theme.of(context).textTheme;

    return VisionLoading(
      child: Container(
        padding: VisionSpacing.cardPadding,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: VisionRadius.lgBorder,
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: <Widget>[
            const Bone.circle(size: 40),
            const SizedBox(width: VisionSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('AI Provider Name', style: textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(
                    'Checking provider credentials and status',
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: VisionSpacing.sm),
            const Bone(
              width: 64,
              height: 24,
              borderRadius: VisionRadius.pillBorder,
            ),
          ],
        ),
      ),
    );
  }
}

class _VisionModelListSkeleton extends StatelessWidget {
  const _VisionModelListSkeleton({super.key, this.itemCount = 3});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final colors = context.visionColors;
    final textTheme = Theme.of(context).textTheme;

    return VisionLoading(
      child: Column(
        children: List<Widget>.generate(itemCount, (index) {
          return Container(
            margin: EdgeInsets.only(
              bottom: index < itemCount - 1 ? VisionSpacing.xs : 0,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: VisionSpacing.md,
              vertical: VisionSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: VisionRadius.mdBorder,
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: <Widget>[
                const Bone.icon(size: 20),
                const SizedBox(width: VisionSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'vision-model-identifier',
                        style: textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Context window & capability',
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const Bone(
                  width: 48,
                  height: 20,
                  borderRadius: VisionRadius.pillBorder,
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _VisionChatLoadingSkeleton extends StatelessWidget {
  const _VisionChatLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.visionColors;
    final textTheme = Theme.of(context).textTheme;

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: VisionLoading(
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(VisionRadius.lg),
                topRight: Radius.circular(VisionRadius.lg),
                bottomLeft: Radius.circular(VisionRadius.xs),
                bottomRight: Radius.circular(VisionRadius.lg),
              ),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Bone.circle(size: 14),
                    const SizedBox(width: 6),
                    Text('VISION • Thinking', style: textTheme.labelMedium),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Synthesizing a concise and helpful response for you',
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: 6),
                Text('Preparing answer details', style: textTheme.bodyMedium),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VisionSettingsLoadingSkeleton extends StatelessWidget {
  const _VisionSettingsLoadingSkeleton({super.key, this.itemCount = 3});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final colors = context.visionColors;
    final textTheme = Theme.of(context).textTheme;

    return VisionLoading(
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: VisionRadius.lgBorder,
          border: Border.all(color: colors.border),
        ),
        child: Column(
          children: List<Widget>.generate(itemCount, (index) {
            return Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: VisionSpacing.md,
                    vertical: VisionSpacing.sm,
                  ),
                  child: Row(
                    children: <Widget>[
                      const Bone.circle(size: 32),
                      const SizedBox(width: VisionSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Preference Title',
                              style: textTheme.titleSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Configuration subtitle description',
                              style: textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const Bone(
                        width: 42,
                        height: 24,
                        borderRadius: VisionRadius.pillBorder,
                      ),
                    ],
                  ),
                ),
                if (index < itemCount - 1) const Divider(height: 1),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _VisionConversationLoadingSkeleton extends StatelessWidget {
  const _VisionConversationLoadingSkeleton({super.key, this.itemCount = 4});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final colors = context.visionColors;
    final textTheme = Theme.of(context).textTheme;

    return VisionLoading(
      child: Column(
        children: List<Widget>.generate(itemCount, (index) {
          return Container(
            margin: EdgeInsets.only(
              bottom: index < itemCount - 1 ? VisionSpacing.xs : 0,
            ),
            padding: const EdgeInsets.all(VisionSpacing.sm),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: VisionRadius.mdBorder,
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: <Widget>[
                const Bone.circle(size: 36),
                const SizedBox(width: VisionSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Recent Conversation Title',
                        style: textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Last assistant reply preview text goes here',
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

/// Backward-compatible lightweight skeleton bone backed by [VisionLoading].
class VisionLoadingSkeleton extends StatelessWidget {
  const VisionLoadingSkeleton({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = VisionRadius.smBorder,
  });

  final double width;
  final double height;
  final BorderRadius borderRadius;

  /// Pre-composed skeleton card matching AI provider & settings cards.
  static Widget cardPlaceholder() {
    return VisionLoading.providerCard();
  }

  @override
  Widget build(BuildContext context) {
    return VisionLoading(
      child: Bone(width: width, height: height, borderRadius: borderRadius),
    );
  }
}
