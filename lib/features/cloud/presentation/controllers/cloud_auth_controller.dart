import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:vision_ai/core/config/cloud_config.dart';
import 'package:vision_ai/core/constants/storage_keys.dart';
import 'package:vision_ai/core/utils/app_logger.dart';
import 'package:vision_ai/core/utils/secure_storage_provider.dart';
import 'package:vision_ai/core/utils/shared_preferences_provider.dart';
import 'package:vision_ai/features/chat/presentation/controllers/chat_controller.dart';
import 'package:vision_ai/features/chat/presentation/controllers/conversation_threads_controller.dart';
import 'package:vision_ai/features/cloud/data/services/supabase_sync_service.dart';
import 'package:vision_ai/features/cloud/domain/services/zero_knowledge_key_vault.dart';
import 'package:vision_ai/features/settings/domain/entities/ai_provider_type.dart';
import 'package:vision_ai/features/settings/presentation/controllers/api_key_controller.dart';

/// Immutable state for Google Sign-In & Supabase Cloud Sync.
@immutable
class CloudAuthState {
  const CloudAuthState({
    this.isConfigured = false,
    this.isSignedIn = false,
    this.userId,
    this.email,
    this.displayName,
    this.avatarUrl,
    this.isBusy = false,
    this.cloudHistorySyncEnabled = true,
    this.lastSyncedAt,
    this.statusMessage,
    this.errorMessage,
  });

  final bool isConfigured;
  final bool isSignedIn;
  final String? userId;
  final String? email;
  final String? displayName;
  final String? avatarUrl;
  final bool isBusy;
  final bool cloudHistorySyncEnabled;
  final DateTime? lastSyncedAt;
  final String? statusMessage;
  final String? errorMessage;

  /// Human-readable initials fallback when avatar image is unavailable.
  String get initials {
    final source = (displayName?.trim().isNotEmpty == true)
        ? displayName!.trim()
        : (email?.trim() ?? 'V');
    final parts = source
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return source.isNotEmpty ? source[0].toUpperCase() : 'V';
  }

  CloudAuthState copyWith({
    bool? isConfigured,
    bool? isSignedIn,
    String? userId,
    String? email,
    String? displayName,
    String? avatarUrl,
    bool? isBusy,
    bool? cloudHistorySyncEnabled,
    DateTime? lastSyncedAt,
    String? statusMessage,
    String? errorMessage,
    bool clearUser = false,
    bool clearMessages = false,
  }) {
    return CloudAuthState(
      isConfigured: isConfigured ?? this.isConfigured,
      isSignedIn: isSignedIn ?? this.isSignedIn,
      userId: clearUser ? null : (userId ?? this.userId),
      email: clearUser ? null : (email ?? this.email),
      displayName: clearUser ? null : (displayName ?? this.displayName),
      avatarUrl: clearUser ? null : (avatarUrl ?? this.avatarUrl),
      isBusy: isBusy ?? this.isBusy,
      cloudHistorySyncEnabled:
          cloudHistorySyncEnabled ?? this.cloudHistorySyncEnabled,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      statusMessage: clearMessages
          ? null
          : (statusMessage ?? this.statusMessage),
      errorMessage: clearMessages ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Global Riverpod provider for [CloudAuthController].
final cloudAuthControllerProvider =
    NotifierProvider<CloudAuthController, CloudAuthState>(
      CloudAuthController.new,
    );

/// Coordinates optional Google Sign-In (native Credential Manager with
/// automatic Supabase Browser OAuth fallback), conversation thread cloud sync,
/// and Zero-Knowledge AES-256-GCM API key backup/restore.
class CloudAuthController extends Notifier<CloudAuthState> {
  static const String oauthRedirectUrl = 'com.brijesh.vision://login-callback/';

  /// Returns `true` only when [error] represents an explicit user cancellation
  /// rather than an Android Credential Manager configuration/reauth failure
  /// (which `google_sign_in` v7 maps to [GoogleSignInExceptionCode.canceled]).
  @visibleForTesting
  static bool isUserInitiatedCancel(GoogleSignInException error) {
    if (error.code != GoogleSignInExceptionCode.canceled) return false;
    final desc = (error.description ?? '').trim().toLowerCase();
    if (desc.isEmpty) return true;
    const configFailureMarkers = <String>[
      'reauth',
      'developer',
      'configuration',
      'no credential',
      'cannot find a matching credential',
      'sha-1',
      'sha1',
      '[16]',
      '[10]',
      '28436',
      '28444',
    ];
    for (final marker in configFailureMarkers) {
      if (desc.contains(marker)) return false;
    }
    return true;
  }

  StreamSubscription<AuthState>? _authSub;
  bool _googleInitialized = false;

  static String? _extractDisplayName(User? user) {
    final meta = user?.userMetadata;
    if (meta == null) return null;
    final full = (meta['full_name'] as String?)?.trim();
    if (full != null && full.isNotEmpty) return full;
    final name = (meta['name'] as String?)?.trim();
    if (name != null && name.isNotEmpty) return name;
    return null;
  }

  static String? _extractAvatarUrl(User? user) {
    final meta = user?.userMetadata;
    if (meta == null) return null;
    final avatar = (meta['avatar_url'] as String?)?.trim();
    if (avatar != null && avatar.isNotEmpty) return avatar;
    final picture = (meta['picture'] as String?)?.trim();
    if (picture != null && picture.isNotEmpty) return picture;
    return null;
  }

  @override
  CloudAuthState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final historySyncEnabled =
        prefs.getBool(StorageKeys.cloudHistorySyncEnabled) ?? true;

    ref.onDispose(() {
      unawaited(_authSub?.cancel());
    });

    if (!CloudConfig.isSupabaseConfigured) {
      return CloudAuthState(
        isConfigured: false,
        cloudHistorySyncEnabled: historySyncEnabled,
      );
    }

    try {
      final client = Supabase.instance.client;
      _authSub ??= client.auth.onAuthStateChange.listen(
        (authState) {
          final user = authState.session?.user;
          if (user != null) {
            final wasSignedIn = state.isSignedIn;
            state = state.copyWith(
              isBusy: false,
              isSignedIn: true,
              userId: user.id,
              email: user.email,
              displayName: _extractDisplayName(user),
              avatarUrl: _extractAvatarUrl(user),
              clearMessages: true,
              statusMessage: 'Signed in as ${user.email ?? 'Google User'}.',
            );
            if (!wasSignedIn && state.cloudHistorySyncEnabled) {
              unawaited(syncThreadsNow());
            }
          } else {
            state = state.copyWith(
              isBusy: false,
              isSignedIn: false,
              clearUser: true,
            );
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          ref
              .read(appLoggerProvider)
              .error(
                'Supabase Auth callback error',
                error: error,
                stackTrace: stackTrace,
              );
          final message = error is AuthException ? error.message : '$error';
          state = state.copyWith(
            isBusy: false,
            clearMessages: true,
            errorMessage: 'Sign-in callback error: $message',
          );
        },
      );

      final currentUser = client.auth.currentUser;
      return CloudAuthState(
        isConfigured: true,
        isSignedIn: currentUser != null,
        userId: currentUser?.id,
        email: currentUser?.email,
        displayName: _extractDisplayName(currentUser),
        avatarUrl: _extractAvatarUrl(currentUser),
        cloudHistorySyncEnabled: historySyncEnabled,
      );
    } catch (_) {
      return CloudAuthState(
        isConfigured: false,
        cloudHistorySyncEnabled: historySyncEnabled,
      );
    }
  }

  /// Toggles whether signed-in cloud sync includes conversation threads.
  Future<void> setCloudHistorySyncEnabled(bool enabled) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(StorageKeys.cloudHistorySyncEnabled, enabled);
    state = state.copyWith(cloudHistorySyncEnabled: enabled);
  }

  /// Signs in with Google. Tries native Android Credential Manager first when
  /// `GOOGLE_WEB_CLIENT_ID` is configured, and automatically falls back to
  /// Supabase Browser OAuth (`com.brijesh.vision://login-callback/`) if native
  /// Android OAuth configuration (SHA-1) is missing.
  Future<bool> signInWithGoogle() async {
    if (!CloudConfig.isSupabaseConfigured) {
      state = state.copyWith(
        errorMessage: 'Supabase is not configured via --dart-define.',
      );
      return false;
    }

    if (!CloudConfig.isGoogleSignInConfigured) {
      return signInWithGoogleBrowser();
    }

    state = state.copyWith(isBusy: true, clearMessages: true);
    try {
      if (!_googleInitialized) {
        await GoogleSignIn.instance.initialize(
          serverClientId: CloudConfig.googleWebClientId,
        );
        _googleInitialized = true;
      }

      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        ref
            .read(appLoggerProvider)
            .warning(
              'Native Google Sign-In returned empty idToken; falling back to OAuth browser.',
            );
        return await signInWithGoogleBrowser();
      }

      final response = await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );

      final user = response.user;
      if (user == null) {
        state = state.copyWith(
          isBusy: false,
          errorMessage: 'Supabase sign-in did not establish a user session.',
        );
        return false;
      }

      state = state.copyWith(
        isBusy: false,
        isSignedIn: true,
        userId: user.id,
        email: user.email,
        displayName: _extractDisplayName(user) ?? account.displayName,
        avatarUrl: _extractAvatarUrl(user) ?? account.photoUrl,
        statusMessage: 'Signed in as ${user.email ?? 'Google User'}.',
      );
      ref.read(appLoggerProvider).info('Google + Supabase sign-in succeeded.');

      if (state.cloudHistorySyncEnabled) {
        unawaited(syncThreadsNow());
      }
      return true;
    } on GoogleSignInException catch (error, stackTrace) {
      if (isUserInitiatedCancel(error)) {
        state = state.copyWith(isBusy: false, clearMessages: true);
        return false;
      }
      ref
          .read(appLoggerProvider)
          .warning(
            'Native Google Sign-In failed (${error.code.name}: ${error.description}); '
            'falling back to Supabase Browser OAuth.',
            error: error,
            stackTrace: stackTrace,
          );
      return signInWithGoogleBrowser();
    } on AuthException catch (error, stackTrace) {
      ref
          .read(appLoggerProvider)
          .error('Supabase Auth error', error: error, stackTrace: stackTrace);
      state = state.copyWith(
        isBusy: false,
        errorMessage: 'Supabase Auth error: ${error.message}',
      );
      return false;
    } catch (error, stackTrace) {
      ref
          .read(appLoggerProvider)
          .warning(
            'Native Google Sign-In error ($error); falling back to Supabase Browser OAuth.',
            error: error,
            stackTrace: stackTrace,
          );
      return signInWithGoogleBrowser();
    }
  }

  /// Launches Google OAuth via Supabase Browser / Custom Tab and returns to
  /// VISION AI via the `com.brijesh.vision://login-callback/` deep link.
  Future<bool> signInWithGoogleBrowser() async {
    if (!CloudConfig.isSupabaseConfigured) {
      state = state.copyWith(
        errorMessage: 'Supabase is not configured via --dart-define.',
      );
      return false;
    }

    state = state.copyWith(isBusy: true, clearMessages: true);
    try {
      final launched = await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: oauthRedirectUrl,
        authScreenLaunchMode: LaunchMode.externalApplication,
        queryParams: const <String, String>{'prompt': 'select_account'},
      );
      if (!launched) {
        state = state.copyWith(
          isBusy: false,
          errorMessage: 'Could not launch browser for Google Sign-In.',
        );
        return false;
      }
      state = state.copyWith(
        isBusy: false,
        statusMessage: 'Complete Google Sign-In in your browser to return.',
      );
      return true;
    } on AuthException catch (error, stackTrace) {
      ref
          .read(appLoggerProvider)
          .error('Browser OAuth failed', error: error, stackTrace: stackTrace);
      state = state.copyWith(
        isBusy: false,
        errorMessage: 'OAuth error: ${error.message}',
      );
      return false;
    } catch (error, stackTrace) {
      ref
          .read(appLoggerProvider)
          .error('Browser OAuth failed', error: error, stackTrace: stackTrace);
      state = state.copyWith(
        isBusy: false,
        errorMessage: 'Google Sign-In failed: $error',
      );
      return false;
    }
  }

  /// Signs out of both Google Sign-In and Supabase Auth.
  Future<void> signOut() async {
    state = state.copyWith(isBusy: true, clearMessages: true);
    try {
      if (_googleInitialized) {
        await GoogleSignIn.instance.signOut();
      }
      if (CloudConfig.isSupabaseConfigured) {
        await Supabase.instance.client.auth.signOut();
      }
      state = state.copyWith(
        isBusy: false,
        isSignedIn: false,
        clearUser: true,
        statusMessage: 'Signed out. Local data remains on this device.',
      );
    } catch (error) {
      state = state.copyWith(
        isBusy: false,
        errorMessage: 'Sign-out failed: $error',
      );
    }
  }

  /// Bidirectional conversation thread sync with Supabase (last-write-wins).
  Future<bool> syncThreadsNow() async {
    final userId = state.userId;
    if (!state.isSignedIn || userId == null) {
      state = state.copyWith(
        errorMessage: 'Sign in with Google to sync conversations.',
      );
      return false;
    }

    final threadsController = ref.read(
      conversationThreadsControllerProvider.notifier,
    );
    final syncService = ref.read(supabaseSyncServiceProvider);

    state = state.copyWith(isBusy: true, clearMessages: true);
    threadsController.setSyncing(true);
    try {
      final remote = await syncService.fetchRemoteThreads(userId);
      await threadsController.mergeRemoteThreads(remote);
      final merged = ref.read(conversationThreadsControllerProvider).threads;
      await syncService.upsertThreads(userId: userId, threads: merged);

      final active = ref
          .read(conversationThreadsControllerProvider)
          .activeThread;
      if (active != null && active.messages.isNotEmpty) {
        await ref.read(chatControllerProvider.notifier).openThread(active);
      }

      state = state.copyWith(
        isBusy: false,
        lastSyncedAt: DateTime.now(),
        statusMessage: 'Synced ${merged.length} conversation thread(s).',
      );
      return true;
    } catch (error, stackTrace) {
      ref
          .read(appLoggerProvider)
          .error('Thread sync failed', error: error, stackTrace: stackTrace);
      state = state.copyWith(
        isBusy: false,
        errorMessage: 'Cloud sync failed: $error',
      );
      return false;
    } finally {
      threadsController.setSyncing(false);
    }
  }

  /// Encrypts all local AI provider API keys with [passphrase] (AES-256-GCM)
  /// and uploads the ciphertext blob to Supabase `user_api_keys`.
  Future<bool> backupApiKeysToCloud(String passphrase) async {
    final userId = state.userId;
    if (!state.isSignedIn || userId == null) {
      state = state.copyWith(
        errorMessage: 'Sign in with Google to back up encrypted API keys.',
      );
      return false;
    }

    state = state.copyWith(isBusy: true, clearMessages: true);
    try {
      final credentialStore = ref.read(secureCredentialStoreProvider);
      final keysToBackup = <String, String>{};
      for (final provider in AiProviderType.values) {
        if (!provider.requiresApiKey) continue;
        final key = await credentialStore.readApiKey(provider.id);
        if (key != null && key.trim().isNotEmpty) {
          keysToBackup[provider.id] = key.trim();
        }
      }

      if (keysToBackup.isEmpty) {
        state = state.copyWith(
          isBusy: false,
          errorMessage: 'No local API keys found to back up.',
        );
        return false;
      }

      final vault = ref.read(zeroKnowledgeKeyVaultProvider);
      final blob = await vault.encryptKeys(
        apiKeys: keysToBackup,
        passphrase: passphrase,
      );
      await ref
          .read(supabaseSyncServiceProvider)
          .upsertEncryptedApiKeys(userId: userId, blob: blob);

      state = state.copyWith(
        isBusy: false,
        lastSyncedAt: DateTime.now(),
        statusMessage:
            'Encrypted & backed up ${keysToBackup.length} API key(s) to Supabase.',
      );
      return true;
    } on VaultDecryptionException catch (error) {
      state = state.copyWith(isBusy: false, errorMessage: error.message);
      return false;
    } catch (error, stackTrace) {
      ref
          .read(appLoggerProvider)
          .error('API key backup failed', error: error, stackTrace: stackTrace);
      state = state.copyWith(
        isBusy: false,
        errorMessage: 'Unable to back up encrypted API keys: $error',
      );
      return false;
    }
  }

  /// Downloads the encrypted vault from Supabase, decrypts with [passphrase],
  /// and saves keys into local Android Keystore (`FlutterSecureStorage`).
  Future<bool> restoreApiKeysFromCloud(String passphrase) async {
    final userId = state.userId;
    if (!state.isSignedIn || userId == null) {
      state = state.copyWith(
        errorMessage: 'Sign in with Google to restore encrypted API keys.',
      );
      return false;
    }

    state = state.copyWith(isBusy: true, clearMessages: true);
    try {
      final blob = await ref
          .read(supabaseSyncServiceProvider)
          .fetchEncryptedApiKeys(userId);
      if (blob == null) {
        state = state.copyWith(
          isBusy: false,
          errorMessage: 'No encrypted API key backup found in Supabase.',
        );
        return false;
      }

      final vault = ref.read(zeroKnowledgeKeyVaultProvider);
      final restored = await vault.decryptKeys(
        blob: blob,
        passphrase: passphrase,
      );

      final keyController = ref.read(apiKeyStatusControllerProvider.notifier);
      var count = 0;
      for (final provider in AiProviderType.values) {
        final key = restored[provider.id];
        if (key != null && key.trim().isNotEmpty) {
          await keyController.saveApiKey(provider: provider, apiKey: key);
          count++;
        }
      }

      state = state.copyWith(
        isBusy: false,
        lastSyncedAt: DateTime.now(),
        statusMessage:
            'Decrypted & restored $count API key(s) to Android Keystore.',
      );
      return true;
    } on VaultDecryptionException catch (error) {
      state = state.copyWith(isBusy: false, errorMessage: error.message);
      return false;
    } catch (error, stackTrace) {
      ref
          .read(appLoggerProvider)
          .error(
            'API key restore failed',
            error: error,
            stackTrace: stackTrace,
          );
      state = state.copyWith(
        isBusy: false,
        errorMessage: 'Unable to restore encrypted API keys: $error',
      );
      return false;
    }
  }
}
