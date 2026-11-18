import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/app/router/app_router.dart';
import 'package:vision_ai/app/theme/app_theme.dart';
import 'package:vision_ai/core/constants/app_constants.dart';
import 'package:vision_ai/features/settings/presentation/controllers/settings_controller.dart';

/// Root widget configuring themes, routing, and global providers for VISION AI.
class VisionApp extends ConsumerWidget {
  const VisionApp({super.key});

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
      routerConfig: router,
    );
  }
}
