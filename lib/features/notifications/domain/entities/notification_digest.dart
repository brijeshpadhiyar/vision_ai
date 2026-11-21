import 'package:flutter/foundation.dart';

import 'package:vision_ai/features/automation/domain/entities/device_action.dart';

/// Priority level assigned to a summarized unread notification.
enum DigestItemPriority { urgent, people, update }

/// A 1-tap inline reply suggestion rendered as a chip in the Catch-Up Digest.
@immutable
class SmartReplySuggestion {
  const SmartReplySuggestion({required this.label, required this.replyText});

  final String label;
  final String replyText;
}

/// Summary and optional inline reply actions for one privacy-cleared notification.
@immutable
class DigestItemSummary {
  const DigestItemSummary({
    required this.notification,
    required this.priority,
    required this.oneLineSummary,
    this.suggestedReplies = const <SmartReplySuggestion>[],
  });

  final DeviceNotificationSummary notification;
  final DigestItemPriority priority;
  final String oneLineSummary;
  final List<SmartReplySuggestion> suggestedReplies;
}

/// Result of classifying raw device notifications on-device before any AI call.
@immutable
class PrivacyFilteredNotifications {
  const PrivacyFilteredNotifications({
    required this.safeForAi,
    required this.protectedLocal,
  });

  /// Notifications cleared of OTPs, banking, and UPI data.
  final List<DeviceNotificationSummary> safeForAi;

  /// Sensitive alerts kept strictly on-device and never sent to cloud AI.
  final List<DeviceNotificationSummary> protectedLocal;
}

/// Complete Smart Notification Digest ready for UI display and TTS catch-up.
@immutable
class NotificationDigest {
  const NotificationDigest({
    required this.generatedAt,
    required this.spokenSummary,
    required this.items,
    required this.protectedLocalCount,
    required this.usedAi,
  });

  final DateTime generatedAt;
  final String spokenSummary;
  final List<DigestItemSummary> items;
  final int protectedLocalCount;
  final bool usedAi;

  int get totalUnreadCount => items.length + protectedLocalCount;
  bool get isEmpty => totalUnreadCount == 0;
}
