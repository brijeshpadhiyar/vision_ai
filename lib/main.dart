import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vision_ai/app/app.dart';
import 'package:vision_ai/core/constants/app_constants.dart';
import 'package:vision_ai/core/errors/error_handler.dart';
import 'package:vision_ai/core/utils/app_logger.dart';
import 'package:vision_ai/core/utils/shared_preferences_provider.dart';

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  final logger = AppLogger();
  AppErrorHandler.initialize(logger);

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  final sharedPreferences = await SharedPreferences.getInstance();

  logger.info(
    'Starting ${AppConstants.appFullTitle} (${AppConstants.applicationId}) '
    '— ${AppConstants.currentPhaseLabel}',
  );

  runApp(
    ProviderScope(
      overrides: [
        appLoggerProvider.overrideWithValue(logger),
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const VisionApp(),
    ),
  );
}
