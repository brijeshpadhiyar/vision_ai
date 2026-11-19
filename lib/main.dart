import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rive/rive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:vision_ai/app/app.dart';
import 'package:vision_ai/core/config/cloud_config.dart';
import 'package:vision_ai/core/constants/app_constants.dart';
import 'package:vision_ai/core/errors/error_handler.dart';
import 'package:vision_ai/core/utils/app_logger.dart';
import 'package:vision_ai/core/utils/shared_preferences_provider.dart';

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Enforce strict offline-first typography using bundled Manrope assets.
  GoogleFonts.config.allowRuntimeFetching = false;

  final logger = AppLogger();
  AppErrorHandler.initialize(logger);

  try {
    await RiveNative.init();
  } catch (error, stackTrace) {
    logger.warning(
      'RiveNative initialization skipped; Flutter-native VisionOrb fallback active.',
      error: error,
      stackTrace: stackTrace,
    );
  }

  if (CloudConfig.isSupabaseConfigured) {
    try {
      await Supabase.initialize(
        url: CloudConfig.supabaseUrl,
        publishableKey: CloudConfig.supabaseAnonKey,
      );
      logger.info('Supabase cloud sync initialized.');
    } catch (error, stackTrace) {
      logger.warning(
        'Supabase initialization skipped; continuing in offline/local mode.',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

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
