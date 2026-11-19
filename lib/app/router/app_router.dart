import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/app/router/app_routes.dart';
import 'package:vision_ai/app/router/vision_shell_scaffold.dart';
import 'package:vision_ai/core/constants/app_constants.dart';
import 'package:vision_ai/core/theme/vision_animations.dart';
import 'package:vision_ai/core/widgets/vision_app_bar.dart';
import 'package:vision_ai/core/widgets/vision_scaffold.dart';
import 'package:vision_ai/features/assistant/presentation/screens/assistant_experience_screen.dart';
import 'package:vision_ai/features/assistant/presentation/screens/assistant_home_screen.dart';
import 'package:vision_ai/features/assistant/presentation/screens/assistant_overlay_screen.dart';
import 'package:vision_ai/features/automation/presentation/screens/automation_screen.dart';
import 'package:vision_ai/features/chat/presentation/screens/chat_screen.dart';
import 'package:vision_ai/features/developer/presentation/screens/developer_assistant_screen.dart';
import 'package:vision_ai/features/diagnostics/presentation/screens/diagnostics_screen.dart';
import 'package:vision_ai/features/help/presentation/screens/help_center_screen.dart';
import 'package:vision_ai/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:vision_ai/features/planner/presentation/screens/daily_planner_screen.dart';
import 'package:vision_ai/features/privacy/presentation/screens/privacy_dashboard_screen.dart';
import 'package:vision_ai/features/settings/presentation/screens/settings_screen.dart';
import 'package:vision_ai/features/smart_home/presentation/screens/smart_home_screen.dart';
import 'package:vision_ai/features/splash/presentation/screens/splash_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'visionRootNavigator',
);

/// Provides the application's [GoRouter] configuration with a persistent
/// Liquid Glass navigation shell and dedicated modal Assistant routes.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.splashPath,
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.splashPath,
        name: AppRoutes.splashName,
        builder: (context, state) => const VisionSplashScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return VisionShellScaffold(navigationShell: navigationShell);
        },
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.homePath,
                name: AppRoutes.homeName,
                pageBuilder: (context, state) => _fadeSlidePage(
                  key: state.pageKey,
                  duration: AppConstants.splashTransitionDuration,
                  child: const AssistantHomeScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.chatPath,
                name: AppRoutes.chatName,
                pageBuilder: (context, state) => _fadeSlidePage(
                  key: state.pageKey,
                  child: const ChatScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.automationPath,
                name: AppRoutes.automationName,
                pageBuilder: (context, state) => _fadeSlidePage(
                  key: state.pageKey,
                  child: const AutomationScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.settingsPath,
                name: AppRoutes.settingsName,
                pageBuilder: (context, state) => _fadeSlidePage(
                  key: state.pageKey,
                  child: const SettingsScreen(),
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.assistantPath,
        name: AppRoutes.assistantName,
        pageBuilder: (context, state) {
          final autoListen = state.uri.queryParameters['listen'] == '1';
          return _assistantModalPage(
            key: state.pageKey,
            child: AssistantExperienceScreen(autoListenOnOpen: autoListen),
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.onboardingPath,
        name: AppRoutes.onboardingName,
        pageBuilder: (context, state) =>
            _fadeSlidePage(key: state.pageKey, child: const OnboardingScreen()),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.assistantOverlayPath,
        name: AppRoutes.assistantOverlayName,
        pageBuilder: (context, state) => _assistantModalPage(
          key: state.pageKey,
          child: const AssistantOverlayScreen(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.diagnosticsPath,
        name: AppRoutes.diagnosticsName,
        pageBuilder: (context, state) => _fadeSlidePage(
          key: state.pageKey,
          child: const DiagnosticsScreen(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.privacyDashboardPath,
        name: AppRoutes.privacyDashboardName,
        pageBuilder: (context, state) => _fadeSlidePage(
          key: state.pageKey,
          child: const PrivacyDashboardScreen(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.helpPath,
        name: AppRoutes.helpName,
        pageBuilder: (context, state) => _fadeSlidePage(
          key: state.pageKey,
          child: const HelpCenterScreen(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.plannerPath,
        name: AppRoutes.plannerName,
        pageBuilder: (context, state) => _fadeSlidePage(
          key: state.pageKey,
          child: const DailyPlannerScreen(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.smartHomePath,
        name: AppRoutes.smartHomeName,
        pageBuilder: (context, state) => _fadeSlidePage(
          key: state.pageKey,
          child: const SmartHomeScreen(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.developerPath,
        name: AppRoutes.developerName,
        pageBuilder: (context, state) => _fadeSlidePage(
          key: state.pageKey,
          child: const DeveloperAssistantScreen(),
        ),
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

CustomTransitionPage<void> _fadeSlidePage({
  required LocalKey key,
  required Widget child,
  Duration duration = VisionAnimations.standard,
}) {
  return CustomTransitionPage<void>(
    key: key,
    transitionDuration: duration,
    reverseTransitionDuration: VisionAnimations.standardFast,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (VisionAnimations.isReducedMotion(context)) {
        return child;
      }
      final curved = CurvedAnimation(
        parent: animation,
        curve: VisionAnimations.standardCurve,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.025),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

CustomTransitionPage<void> _assistantModalPage({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: key,
    transitionDuration: VisionAnimations.large,
    reverseTransitionDuration: VisionAnimations.standard,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (VisionAnimations.isReducedMotion(context)) {
        return child;
      }
      final curved = CurvedAnimation(
        parent: animation,
        curve: VisionAnimations.emphasizedCurve,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}
