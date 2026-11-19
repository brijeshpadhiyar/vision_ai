import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

/// Thrown when decrypting a [EncryptedVaultBlob] fails (e.g., incorrect
/// Sync Passphrase or corrupted ciphertext/MAC).
class VaultDecryptionException implements Exception {
  const VaultDecryptionException(this.message);

  final String message;

  @override
  String toString() => 'VaultDecryptionException: $message';
}

/// Encrypted zero-knowledge API key vault payload stored in Supabase
/// `user_api_keys`. Plaintext keys never leave the device.
@immutable
class EncryptedVaultBlob {
  const EncryptedVaultBlob({
    required this.ciphertextBase64,
    required this.nonceBase64,
    required this.saltBase64,
    required this.macBase64,
    this.iterations = ZeroKnowledgeKeyVault.defaultIterations,
    this.version = 1,
  });

  final String ciphertextBase64;
  final String nonceBase64;
  final String saltBase64;
  final String macBase64;
  final int iterations;
  final int version;

  Map<String, dynamic> toSupabaseRow(String userId) {
    return <String, dynamic>{
      'user_id': userId,
      'ciphertext': ciphertextBase64,
      'nonce': nonceBase64,
      'salt': saltBase64,
      'mac': macBase64,
      'kdf_iterations': iterations,
      'vault_version': version,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  factory EncryptedVaultBlob.fromSupabaseRow(Map<String, dynamic> row) {
    return EncryptedVaultBlob(
      ciphertextBase64: row['ciphertext'] as String? ?? '',
      nonceBase64: row['nonce'] as String? ?? '',
      saltBase64: row['salt'] as String? ?? '',
      macBase64: row['mac'] as String? ?? '',
      iterations:
          (row['kdf_iterations'] as num?)?.toInt() ??
          ZeroKnowledgeKeyVault.defaultIterations,
      version: (row['vault_version'] as num?)?.toInt() ?? 1,
    );
  }
}

/// Zero-knowledge client-side AES-256-GCM + PBKDF2-HMAC-SHA256 encryption vault
/// for protecting user AI provider API keys prior to Supabase cloud backup.
class ZeroKnowledgeKeyVault {
  ZeroKnowledgeKeyVault({int? iterations})
    : _iterations = iterations ?? defaultIterations;

  /// PBKDF2-HMAC-SHA256 iteration count for production key derivation.
  static const int defaultIterations = 120000;
  static const int _saltLengthBytes = 16;
  static const int _nonceLengthBytes = 12;

  final int _iterations;
  final AesGcm _aesGcm = AesGcm.with256bits();
  final Random _secureRandom = Random.secure();

  List<int> _randomBytes(int length) {
    return List<int>.generate(
      length,
      (_) => _secureRandom.nextInt(256),
      growable: false,
    );
  }

  Future<SecretKey> _deriveKey({
    required String passphrase,
    required List<int> salt,
    required int iterations,
  }) {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    );
    return pbkdf2.deriveKeyFromPassword(password: passphrase, nonce: salt);
  }

  /// Encrypts a map of `{providerId: apiKey}` with [passphrase].
  Future<EncryptedVaultBlob> encryptKeys({
    required Map<String, String> apiKeys,
    required String passphrase,
  }) async {
    if (passphrase.trim().length < 6) {
      throw const VaultDecryptionException(
        'Sync Passphrase must be at least 6 characters long.',
      );
    }

    final salt = _randomBytes(_saltLengthBytes);
    final nonce = _randomBytes(_nonceLengthBytes);
    final secretKey = await _deriveKey(
      passphrase: passphrase,
      salt: salt,
      iterations: _iterations,
    );

    final plaintextBytes = utf8.encode(jsonEncode(apiKeys));
    final secretBox = await _aesGcm.encrypt(
      plaintextBytes,
      secretKey: secretKey,
      nonce: nonce,
    );

    return EncryptedVaultBlob(
      ciphertextBase64: base64Encode(secretBox.cipherText),
      nonceBase64: base64Encode(secretBox.nonce),
      saltBase64: base64Encode(salt),
      macBase64: base64Encode(secretBox.mac.bytes),
      iterations: _iterations,
    );
  }

  /// Decrypts an [EncryptedVaultBlob] with [passphrase].
  Future<Map<String, String>> decryptKeys({
    required EncryptedVaultBlob blob,
    required String passphrase,
  }) async {
    try {
      final salt = base64Decode(blob.saltBase64);
      final nonce = base64Decode(blob.nonceBase64);
      final cipherText = base64Decode(blob.ciphertextBase64);
      final macBytes = base64Decode(blob.macBase64);

      final secretKey = await _deriveKey(
        passphrase: passphrase,
        salt: salt,
        iterations: blob.iterations,
      );

      final secretBox = SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes));

      final clearBytes = await _aesGcm.decrypt(secretBox, secretKey: secretKey);
      final decoded = jsonDecode(utf8.decode(clearBytes));
      if (decoded is! Map<String, dynamic>) {
        throw const VaultDecryptionException(
          'Unexpected vault payload format.',
        );
      }

      final result = <String, String>{};
      for (final entry in decoded.entries) {
        if (entry.value is String &&
            (entry.value as String).trim().isNotEmpty) {
          result[entry.key] = (entry.value as String).trim();
        }
      }
      return result;
    } on SecretBoxAuthenticationError {
      throw const VaultDecryptionException(
        'Incorrect Sync Passphrase or tampered vault data.',
      );
    } on VaultDecryptionException {
      rethrow;
    } catch (_) {
      throw const VaultDecryptionException(
        'Unable to decrypt cloud API key vault.',
      );
    }
  }
}
