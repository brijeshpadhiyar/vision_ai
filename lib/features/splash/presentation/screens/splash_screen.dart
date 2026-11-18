import 'dart:async';

import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/app/router/app_routes.dart';
import 'package:vision_ai/app/theme/app_colors.dart';
import 'package:vision_ai/core/constants/app_constants.dart';
import 'package:vision_ai/core/widgets/vision_brand_logo.dart';

/// Controls how long the coordinated Flutter splash screen displays before
/// smoothly transitioning to the home screen.
final splashDurationProvider = Provider<Duration>(
  (ref) => AppConstants.splashMinimumDuration,
);

/// Branded Flutter splash screen coordinated with the native Android splash.
class VisionSplashScreen extends ConsumerStatefulWidget {
  const VisionSplashScreen({super.key});

  @override
  ConsumerState<VisionSplashScreen> createState() => _VisionSplashScreenState();
}

class _VisionSplashScreenState extends ConsumerState<VisionSplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _revealController;
  late final AnimationController _loaderController;
  late final Animation<double> _logoScale;
  late final Animation<double> _textOpacity;
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();

    // Release the native Android splash hold as soon as the Flutter splash
    // widget mounts so the first Flutter frame replaces it seamlessly.
    FlutterNativeSplash.remove();

    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    )..forward();

    _loaderController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();

    _logoScale = Tween<double>(begin: 0.96, end: 1.0).animate(
      CurvedAnimation(parent: _revealController, curve: Curves.easeOutCubic),
    );
    _textOpacity = CurvedAnimation(
      parent: _revealController,
      curve: const Interval(0.15, 1.0, curve: Curves.easeOut),
    );

    final duration = ref.read(splashDurationProvider);
    _navigationTimer = Timer(duration, _navigateToHome);
  }

  void _navigateToHome() {
    if (!mounted) {
      return;
    }
    context.go(AppRoutes.homePath);
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _revealController.dispose();
    _loaderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.brandBackgroundPrimary,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.0, -0.08),
                  radius: 0.85,
                  colors: [
                    Color(0x2000D4FF),
                    Color(0x0E397BFF),
                    AppColors.brandBackgroundPrimary,
                  ],
                  stops: [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ScaleTransition(
                      scale: _logoScale,
                      child: const VisionBrandLogo(
                        size: 132,
                        isDarkBackground: true,
                      ),
                    ),
                    const SizedBox(height: 24),
                    FadeTransition(
                      opacity: _textOpacity,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            AppConstants.appName,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.brandTextPrimary,
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 8.0,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            AppConstants.appTagline,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.brandTextSecondary,
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0.4,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 36),
                          _MinimalBrandLoader(animation: _loaderController),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MinimalBrandLoader extends StatelessWidget {
  const _MinimalBrandLoader({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 112,
      height: 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: ColoredBox(
          color: AppColors.brandBackgroundSecondary,
          child: AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              final alignmentX = -1.6 + (animation.value * 3.2);
              return Align(
                alignment: Alignment(alignmentX, 0),
                child: Container(
                  width: 48,
                  height: 3,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(99),
                    gradient: const LinearGradient(
                      colors: [
                        AppColors.brandAccentPrimary,
                        AppColors.brandAccentSecondary,
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
