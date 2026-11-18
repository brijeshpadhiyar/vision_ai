import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vision_ai/core/errors/app_exception.dart';

/// Synchronous access to [SharedPreferences], overridden at startup in `main()`.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw const ConfigurationException(
    message: 'sharedPreferencesProvider must be overridden in ProviderScope at startup.',
  );
});
