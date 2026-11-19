import 'package:vision_ai/features/automation/domain/entities/device_action.dart';

/// Security trust tier for Android device actions (Modules 10, 12, Section 6).
enum CommandTrustTier {
  /// Safe commands trusted by default (alarms, timers, app launch, settings, flashlight, volume, status).
  safe,

  /// Sensitive commands requiring user confirmation unless explicitly trusted (calls, SMS, WhatsApp, notifications, URLs).
  sensitive,
}

/// Centralized tier classification for Android device commands.
abstract final class TrustedCommandPolicy {
  static const Set<DeviceActionType> sensitiveActionTypes = <DeviceActionType>{
    DeviceActionType.callPhone,
    DeviceActionType.sendSms,
    DeviceActionType.sendWhatsapp,
    DeviceActionType.readNotifications,
    DeviceActionType.openUrl,
  };

  static CommandTrustTier tierFor(DeviceActionType type) {
    return sensitiveActionTypes.contains(type)
        ? CommandTrustTier.sensitive
        : CommandTrustTier.safe;
  }

  static bool isSensitive(DeviceActionType type) =>
      tierFor(type) == CommandTrustTier.sensitive;
}
