/// Base sealed exception hierarchy for structured error handling in VISION AI.
sealed class AppException implements Exception {
  const AppException({
    required this.message,
    this.code,
    this.cause,
    this.stackTrace,
  });

  /// Human-readable description of the failure.
  final String message;

  /// Optional machine-readable error code for diagnostics.
  final String? code;

  /// Underlying exception or error object, if any.
  final Object? cause;

  /// Optional captured stack trace.
  final StackTrace? stackTrace;

  @override
  String toString() {
    final codeSegment = code != null ? ' [$code]' : '';
    return '$runtimeType$codeSegment: $message';
  }
}

/// Thrown when local preference or secure keystore persistence fails.
final class StorageException extends AppException {
  const StorageException({
    required super.message,
    super.code = 'STORAGE_ERROR',
    super.cause,
    super.stackTrace,
  });
}

/// Thrown when required application or environment configuration is invalid.
final class ConfigurationException extends AppException {
  const ConfigurationException({
    required super.message,
    super.code = 'CONFIG_ERROR',
    super.cause,
    super.stackTrace,
  });
}

/// Thrown when an AI request is attempted without a stored API key for the provider.
final class MissingApiKeyException extends AppException {
  const MissingApiKeyException({
    required this.providerId,
    required this.providerName,
  }) : super(
         message:
             'No API key configured for $providerName. Add your encrypted key in Settings.',
         code: 'MISSING_API_KEY',
       );

  final String providerId;
  final String providerName;
}

/// Thrown when an AI provider REST call fails due to network, auth, quota, or schema errors.
base class AiProviderException extends AppException {
  const AiProviderException({
    required super.message,
    required this.providerName,
    this.statusCode,
    super.code = 'AI_PROVIDER_ERROR',
    super.cause,
    super.stackTrace,
  });

  final String providerName;
  final int? statusCode;
}

/// Thrown when route resolution or navigation fails.
final class NavigationException extends AppException {
  const NavigationException({
    required super.message,
    super.code = 'NAVIGATION_ERROR',
    super.cause,
    super.stackTrace,
  });
}

/// Thrown when an Android device automation intent or permission check fails.
final class DeviceAutomationException extends AppException {
  const DeviceAutomationException({
    required super.message,
    super.code = 'DEVICE_AUTOMATION_ERROR',
    super.cause,
    super.stackTrace,
  });
}

/// Fallback exception for unclassified runtime errors.
final class UnexpectedAppException extends AppException {
  const UnexpectedAppException({
    required super.message,
    super.code = 'UNEXPECTED_ERROR',
    super.cause,
    super.stackTrace,
  });
}
