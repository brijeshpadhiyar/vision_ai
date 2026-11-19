import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:vision_ai/core/constants/storage_keys.dart';
import 'package:vision_ai/core/errors/app_exception.dart';

/// Provides a configured [FlutterSecureStorage] instance backed by Android Keystore.
///
/// Preserves existing user credentials across upgrades (`resetOnError: false`,
/// `migrateOnAlgorithmChange: true`, `migrateWithBackup: true`).
final flutterSecureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(
      resetOnError: false,
      migrateOnAlgorithmChange: true,
      migrateWithBackup: true,
    ),
  );
});

/// Provides the [SecureCredentialStore] wrapper for encrypted credential storage.
final secureCredentialStoreProvider = Provider<SecureCredentialStore>((ref) {
  final storage = ref.watch(flutterSecureStorageProvider);
  return SecureCredentialStore(storage);
});

/// Encrypted key-value wrapper for sensitive credentials (such as AI provider API keys).
///
/// No API keys are hardcoded or bundled with the application.
class SecureCredentialStore {
  SecureCredentialStore(this._storage);

  final FlutterSecureStorage _storage;
  final Map<String, String?> _memoryCache = <String, String?>{};

  /// Reads the decrypted API key for [providerId], or returns `null` if not set.
  Future<String?> readApiKey(String providerId) async {
    if (_memoryCache.containsKey(providerId)) {
      return _memoryCache[providerId];
    }
    try {
      final value = await _storage.read(
        key: StorageKeys.apiKeyForProvider(providerId),
      );
      if (value == null || value.trim().isEmpty) {
        _memoryCache[providerId] = null;
        return null;
      }
      final trimmed = value.trim();
      _memoryCache[providerId] = trimmed;
      return trimmed;
    } on Exception catch (error, stackTrace) {
      throw StorageException(
        message: 'Failed to read encrypted credential for $providerId.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Checks whether an encrypted API key is stored for [providerId].
  Future<bool> hasApiKey(String providerId) async {
    final key = await readApiKey(providerId);
    return key != null;
  }

  /// Saves an encrypted API key for [providerId] in Android Keystore.
  Future<void> saveApiKey({
    required String providerId,
    required String apiKey,
  }) async {
    final trimmed = apiKey.trim();
    if (trimmed.isEmpty) {
      throw const StorageException(message: 'API key cannot be empty.');
    }
    try {
      await _storage.write(
        key: StorageKeys.apiKeyForProvider(providerId),
        value: trimmed,
      );
      _memoryCache[providerId] = trimmed;
    } on Exception catch (error, stackTrace) {
      throw StorageException(
        message: 'Failed to save encrypted credential for $providerId.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Deletes the stored API key for [providerId].
  Future<void> deleteApiKey(String providerId) async {
    try {
      await _storage.delete(key: StorageKeys.apiKeyForProvider(providerId));
      _memoryCache[providerId] = null;
    } on Exception catch (error, stackTrace) {
      throw StorageException(
        message: 'Failed to remove encrypted credential for $providerId.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }
}
