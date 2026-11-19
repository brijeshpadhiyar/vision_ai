import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:skeletonizer/skeletonizer.dart';

import 'package:vision_ai/app/router/app_router.dart';
import 'package:vision_ai/app/theme/app_theme.dart';
import 'package:vision_ai/core/constants/app_constants.dart';
import 'package:vision_ai/core/theme/vision_animations.dart';
import 'package:vision_ai/core/theme/vision_colors.dart';
import 'package:vision_ai/core/theme/vision_motion.dart';
import 'package:vision_ai/features/settings/presentation/controllers/settings_controller.dart';

/// Root widget configuring Midnight Violet & Pearl Lavender themes, smooth
/// [AnimatedTheme] transitions, global [SkeletonizerConfig], routing, and
/// providers for VISION AI.
class VisionApp extends ConsumerWidget {
  const VisionApp({super.key});

  /// Builds a theme- and reduced-motion-aware [SkeletonizerConfigData].
  static SkeletonizerConfigData buildSkeletonizerConfig({
    required Brightness brightness,
    required bool reducedMotion,
  }) {
    final tokens = VisionColorTokens.ofBrightness(brightness);
    final baseColor = brightness == Brightness.dark
        ? tokens.elevatedSurface
        : tokens.secondaryBackground;
    final highlightColor = brightness == Brightness.dark
        ? tokens.border
        : tokens.surface;

    return SkeletonizerConfigData(
      brightness: brightness,
      containersColor: tokens.surface,
      justifyMultiLineText: true,
      enableSwitchAnimation: !reducedMotion,
      switchAnimationConfig: SwitchAnimationConfig(
        duration: reducedMotion ? Duration.zero : VisionAnimations.standardFast,
        switchInCurve: VisionAnimations.standardCurve,
        switchOutCurve: VisionAnimations.standardCurve,
      ),
      effectResolver: (_) => reducedMotion
          ? SolidColorEffect(color: baseColor)
          : ShimmerEffect(
              baseColor: baseColor,
              highlightColor: highlightColor,
              duration: VisionAnimations.shimmerCycle,
            ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(
      settingsControllerProvider.select((settings) => settings.themeMode),
    );

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      themeAnimationDuration: VisionMotion.standard,
      themeAnimationCurve: VisionMotion.standardCurve,
      routerConfig: router,
      builder: (context, child) {
        final brightness = Theme.of(context).brightness;
        final reducedMotion = VisionAnimations.isReducedMotion(context);
        return SkeletonizerConfig(
          data: buildSkeletonizerConfig(
            brightness: brightness,
            reducedMotion: reducedMotion,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
