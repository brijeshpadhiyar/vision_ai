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

/// Coordinates optional Google Sign-In, Supabase Auth sessions, conversation
/// thread cloud sync, and Zero-Knowledge AES-256-GCM API key backup/restore.
class CloudAuthController extends Notifier<CloudAuthState> {
  StreamSubscription<AuthState>? _authSub;
  bool _googleInitialized = false;

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
      _authSub ??= client.auth.onAuthStateChange.listen((authState) {
        final user = authState.session?.user;
        if (user != null) {
          state = state.copyWith(
            isSignedIn: true,
            userId: user.id,
            email: user.email,
            displayName: user.userMetadata?['full_name'] as String?,
            avatarUrl: user.userMetadata?['avatar_url'] as String?,
          );
        } else {
          state = state.copyWith(isSignedIn: false, clearUser: true);
        }
      });

      final currentUser = client.auth.currentUser;
      return CloudAuthState(
        isConfigured: true,
        isSignedIn: currentUser != null,
        userId: currentUser?.id,
        email: currentUser?.email,
        displayName: currentUser?.userMetadata?['full_name'] as String?,
        avatarUrl: currentUser?.userMetadata?['avatar_url'] as String?,
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

  /// Signs in with Google (`google_sign_in` 7.x) and exchanges the ID token
  /// with Supabase Auth.
  Future<bool> signInWithGoogle() async {
    if (!CloudConfig.isGoogleSignInConfigured) {
      state = state.copyWith(
        errorMessage: 'Supabase or Google Web Client ID is not configured via --dart-define.',
      );
      return false;
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
        state = state.copyWith(
          isBusy: false,
          errorMessage: 'Google Sign-In did not return an ID token.',
        );
        return false;
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
        displayName:
            user.userMetadata?['full_name'] as String? ?? account.displayName,
        avatarUrl:
            user.userMetadata?['avatar_url'] as String? ?? account.photoUrl,
        statusMessage: 'Signed in as ${user.email ?? 'Google User'}.',
      );
      ref.read(appLoggerProvider).info('Google + Supabase sign-in succeeded.');

      if (state.cloudHistorySyncEnabled) {
        unawaited(syncThreadsNow());
      }
      return true;
    } catch (error, stackTrace) {
      ref
          .read(appLoggerProvider)
          .error('Google Sign-In failed', error: error, stackTrace: stackTrace);
      state = state.copyWith(
        isBusy: false,
        errorMessage: 'Google Sign-In failed. Check network and OAuth setup.',
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
        errorMessage: 'Cloud sync failed. Verify connectivity and schema.',
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
        errorMessage: 'Unable to back up encrypted API keys.',
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
        errorMessage: 'Unable to restore encrypted API keys.',
      );
      return false;
    }
  }
}
