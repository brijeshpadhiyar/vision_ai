import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/errors/app_exception.dart';
import 'package:vision_ai/core/utils/app_logger.dart';
import 'package:vision_ai/core/utils/secret_redactor.dart';

/// Centralized error handling and global uncaught exception boundary.
abstract final class AppErrorHandler {
  /// Registers global Flutter framework and platform dispatcher error hooks.
  static void initialize(AppLogger logger) {
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      logger.error(
        'Flutter framework error: ${details.exceptionAsString()}',
        error: details.exception,
        stackTrace: details.stack,
      );
    };

    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      logger.error('Uncaught platform error', error: error, stackTrace: stack);
      return true;
    };

    ErrorWidget.builder = (FlutterErrorDetails details) {
      return Material(
        color: const Color(0xFF070B12),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Color(0xFFEF4444),
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Something went wrong in VISION.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFF8FAFC),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    kDebugMode
                        ? SecretRedactor.redact(details.exceptionAsString())
                        : 'An unexpected rendering issue occurred.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    };
  }

  /// Normalizes any caught [error] into a user-safe message string.
  static String toUserMessage(Object error) {
    if (error is AppException) {
      return SecretRedactor.redact(error.message);
    }
    return 'An unexpected error occurred. Please try again.';
  }
}
