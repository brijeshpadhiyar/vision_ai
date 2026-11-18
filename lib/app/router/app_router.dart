import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/app/router/app_routes.dart';
import 'package:vision_ai/core/constants/app_constants.dart';
import 'package:vision_ai/core/widgets/vision_app_bar.dart';
import 'package:vision_ai/core/widgets/vision_scaffold.dart';
import 'package:vision_ai/features/assistant/presentation/screens/assistant_home_screen.dart';
import 'package:vision_ai/features/assistant/presentation/screens/assistant_overlay_screen.dart';
import 'package:vision_ai/features/automation/presentation/screens/automation_screen.dart';
import 'package:vision_ai/features/chat/presentation/screens/chat_screen.dart';
import 'package:vision_ai/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:vision_ai/features/settings/presentation/screens/settings_screen.dart';
import 'package:vision_ai/features/splash/presentation/screens/splash_screen.dart';

/// Provides the application's [GoRouter] configuration.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.splashPath,
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.splashPath,
        name: AppRoutes.splashName,
        builder: (context, state) => const VisionSplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.homePath,
        name: AppRoutes.homeName,
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          transitionDuration: AppConstants.splashTransitionDuration,
          child: const AssistantHomeScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
              child: child,
            );
          },
        ),
      ),
      GoRoute(
        path: AppRoutes.settingsPath,
        name: AppRoutes.settingsName,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.chatPath,
        name: AppRoutes.chatName,
        builder: (context, state) => const ChatScreen(),
      ),
      GoRoute(
        path: AppRoutes.automationPath,
        name: AppRoutes.automationName,
        builder: (context, state) => const AutomationScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboardingPath,
        name: AppRoutes.onboardingName,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.assistantOverlayPath,
        name: AppRoutes.assistantOverlayName,
        builder: (context, state) => const AssistantOverlayScreen(),
      ),
    ],
    errorBuilder: (context, state) => VisionScaffold(
      appBar: const VisionAppBar(title: 'NAVIGATION ERROR'),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.route_outlined, size: 48),
            const SizedBox(height: 16),
            Text(
              'Route not found: ${state.uri}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => context.go(AppRoutes.homePath),
              child: const Text('Return Home'),
            ),
          ],
        ),
      ),
    ),
  );
});
