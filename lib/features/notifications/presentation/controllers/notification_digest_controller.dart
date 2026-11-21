import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vision_ai/features/automation/data/repositories/device_automation_repository_impl.dart';
import 'package:vision_ai/features/automation/domain/entities/device_action.dart';
import 'package:vision_ai/features/automation/presentation/controllers/trusted_commands_controller.dart';
import 'package:vision_ai/features/notifications/domain/entities/notification_digest.dart';
import 'package:vision_ai/features/notifications/domain/services/notification_digest_service.dart';
import 'package:vision_ai/features/settings/presentation/controllers/settings_controller.dart';
import 'package:vision_ai/features/voice/presentation/controllers/voice_controller.dart';

@immutable
class NotificationDigestState {
  const NotificationDigestState({
    this.isLoading = false,
    this.hasPermission = false,
    this.hasConsent = false,
    this.digest,
    this.statusMessage,
    this.errorMessage,
  });

  final bool isLoading;
  final bool hasPermission;
  final bool hasConsent;
  final NotificationDigest? digest;
  final String? statusMessage;
  final String? errorMessage;

  bool get isReady => hasPermission && hasConsent;

  NotificationDigestState copyWith({
    bool? isLoading,
    bool? hasPermission,
    bool? hasConsent,
    NotificationDigest? digest,
    String? statusMessage,
    String? errorMessage,
    bool clearMessages = false,
  }) {
    return NotificationDigestState(
      isLoading: isLoading ?? this.isLoading,
      hasPermission: hasPermission ?? this.hasPermission,
      hasConsent: hasConsent ?? this.hasConsent,
      digest: digest ?? this.digest,
      statusMessage: clearMessages
          ? null
          : (statusMessage ?? this.statusMessage),
      errorMessage: clearMessages ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final notificationDigestControllerProvider =
    NotifierProvider<NotificationDigestController, NotificationDigestState>(
      NotificationDigestController.new,
    );

/// Coordinates Smart Notification Digest generation, spoken EN/HI/GU catch-up,
/// and 1-tap inline replies via Android `RemoteInput`.
class NotificationDigestController extends Notifier<NotificationDigestState> {
  @override
  NotificationDigestState build() {
    final settings = ref.watch(settingsControllerProvider);
    return NotificationDigestState(
      hasConsent: settings.notificationListenerConsent,
    );
  }

  /// Checks Android Notification Access & enables consent when requested.
  Future<void> enableNotificationCatchUp() async {
    await ref
        .read(settingsControllerProvider.notifier)
        .setNotificationListenerConsent(consented: true);
    final repo = ref.read(deviceAutomationRepositoryProvider);
    final granted = await repo.checkPermission(
      AutomationPermission.notifications,
    );
    if (!granted) {
      await repo.requestPermission(AutomationPermission.notifications);
    }
    final recheck = await repo.checkPermission(
      AutomationPermission.notifications,
    );
    state = state.copyWith(
      hasConsent: true,
      hasPermission: recheck,
      clearMessages: true,
      statusMessage: recheck
          ? 'Smart Catch-Up is active.'
          : 'Enable VISION in Android Notification Access, then tap Refresh.',
    );
    if (recheck) {
      await refreshDigest();
    }
  }

  /// Refreshes unread notifications, filters sensitive OTP/UPI alerts locally,
  /// generates the Smart Digest, and optionally reads it aloud via TTS.
  Future<NotificationDigest?> refreshDigest({bool speak = false}) async {
    final settings = ref.read(settingsControllerProvider);
    final repo = ref.read(deviceAutomationRepositoryProvider);
    final granted = await repo.checkPermission(
      AutomationPermission.notifications,
    );
    final consent = settings.notificationListenerConsent;

    if (!consent || !granted) {
      state = state.copyWith(
        isLoading: false,
        hasConsent: consent,
        hasPermission: granted,
        clearMessages: true,
        errorMessage: !consent
            ? 'Enable Smart Catch-Up consent to summarize notifications.'
            : 'Grant Android Notification Access to read unread notifications.',
      );
      return null;
    }

    state = state.copyWith(
      isLoading: true,
      hasConsent: true,
      hasPermission: true,
      clearMessages: true,
    );

    try {
      final blocked = ref
          .read(trustedCommandsControllerProvider)
          .blockedNotificationPackages;
      final raw = await repo.getRecentNotifications(limit: 15);
      final allowed = raw
          .where((n) => !blocked.contains(n.packageName))
          .toList(growable: false);

      final digest = await ref
          .read(notificationDigestServiceProvider)
          .generateDigest(notifications: allowed, settings: settings);

      state = state.copyWith(
        isLoading: false,
        digest: digest,
        statusMessage: digest.isEmpty
            ? 'All caught up — no unread notifications.'
            : (digest.usedAi
                  ? 'AI Catch-Up Digest updated.'
                  : 'Local Catch-Up Digest updated.'),
      );

      if (speak) {
        unawaited(
          ref
              .read(voiceControllerProvider.notifier)
              .speakReply(digest.spokenSummary),
        );
      }
      return digest;
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unable to build notification digest: $error',
      );
      return null;
    }
  }

  /// Sends a 1-tap inline reply to [notificationKey] using Android `RemoteInput`.
  Future<bool> sendQuickReply({
    required String notificationKey,
    required String replyText,
  }) async {
    if (notificationKey.trim().isEmpty || replyText.trim().isEmpty) return false;
    final ok = await ref
        .read(automationPlatformDataSourceProvider)
        .replyNotification(key: notificationKey, text: replyText.trim());
    state = state.copyWith(
      clearMessages: true,
      statusMessage: ok ? 'Reply sent: "$replyText"' : null,
      errorMessage: ok ? null : 'Could not send inline reply to this notification.',
    );
    if (ok) {
      unawaited(refreshDigest());
    }
    return ok;
  }

  Future<void> openNotification(String notificationKey) async {
    if (notificationKey.trim().isEmpty) return;
    await ref
        .read(automationPlatformDataSourceProvider)
        .openNotification(notificationKey);
  }

  Future<void> dismissNotification(String notificationKey) async {
    if (notificationKey.trim().isEmpty) return;
    final ok = await ref
        .read(automationPlatformDataSourceProvider)
        .dismissNotification(notificationKey);
    if (ok) {
      unawaited(refreshDigest());
    }
  }
}
