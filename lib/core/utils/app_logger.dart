import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import 'package:vision_ai/core/utils/secret_redactor.dart';

/// Provides the application-wide [AppLogger] instance.
final appLoggerProvider = Provider<AppLogger>((ref) {
  return AppLogger();
});

/// Centralized logging utility wrapping [Logger] for consistent diagnostics.
class AppLogger {
  AppLogger({Logger? logger})
    : _logger =
          logger ??
          Logger(
            level: kReleaseMode ? Level.warning : Level.debug,
            printer: PrettyPrinter(
              methodCount: 0,
              errorMethodCount: 6,
              lineLength: 90,
              colors: true,
              printEmojis: false,
              dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
            ),
          );

  final Logger _logger;

  /// Logs fine-grained diagnostic messages during development.
  void debug(String message, {Object? error, StackTrace? stackTrace}) {
    _logger.d(
      SecretRedactor.redact(message),
      error: _sanitizeError(error),
      stackTrace: stackTrace,
    );
  }

  /// Logs normal application lifecycle events and state transitions.
  void info(String message, {Object? error, StackTrace? stackTrace}) {
    _logger.i(
      SecretRedactor.redact(message),
      error: _sanitizeError(error),
      stackTrace: stackTrace,
    );
  }

  /// Logs recoverable anomalies or unsupported user actions.
  void warning(String message, {Object? error, StackTrace? stackTrace}) {
    _logger.w(
      SecretRedactor.redact(message),
      error: _sanitizeError(error),
      stackTrace: stackTrace,
    );
  }

  /// Logs unexpected exceptions and serious operational failures.
  void error(String message, {Object? error, StackTrace? stackTrace}) {
    _logger.e(
      SecretRedactor.redact(message),
      error: _sanitizeError(error),
      stackTrace: stackTrace,
    );
  }

  Object? _sanitizeError(Object? error) {
    if (error == null) return null;
    return SecretRedactor.redact(error.toString());
  }
}
