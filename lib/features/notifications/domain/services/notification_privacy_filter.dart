import 'package:vision_ai/features/automation/domain/entities/device_action.dart';
import 'package:vision_ai/features/notifications/domain/entities/notification_digest.dart';

/// Pure, 100% on-device privacy filter that prevents OTPs, banking SMS, and
/// UPI/payment alerts from ever being sent to any cloud AI model.
abstract final class NotificationPrivacyFilter {
  /// Known Indian UPI, banking, and wallet package names kept strictly local.
  static const Set<String> sensitivePackages = <String>{
    'com.google.android.apps.nbu.paisa.user', // Google Pay
    'com.phonepe.app', // PhonePe
    'net.one97.paytm', // Paytm
    'in.org.npci.upiapp', // BHIM UPI
    'com.dreamplug.androidapp', // CRED
    'com.csam.icici.bank.imobile', // ICICI iMobile
    'com.snapwork.hdfc', // HDFC Bank
    'com.sbi.lotusintouch', // YONO SBI
    'com.axis.mobile', // Axis Mobile
    'com.msf.kbank.mobile', // Kotak Bank
    'com.fss.pnbpsp', // PNB
    'com.bankofbaroda.mconnect', // BOB World
  };

  static final RegExp _otpKeywordRegex = RegExp(
    r'\b(otp|one[\s-]?time[\s-]?password|verification\s+code|security\s+code|login\s+code|passcode|mpin|cvv|pin\s+is|secret\s+code)\b',
    caseSensitive: false,
  );

  static final RegExp _numericCodeRegex = RegExp(r'\b\d{4,8}\b');

  static final RegExp _financialKeywordRegex = RegExp(
    r'\b(upi|debited|credited|a/c|acct|account\s+no|imps|neft|rtgs|bank\s+alert|txn|transaction|vpa|rs\.?\s?\d|inr\s?\d|₹\s?\d|balance\s+is|card\s+ending)\b',
    caseSensitive: false,
  );

  /// Returns `true` if [notification] contains OTP, UPI, or banking content
  /// and MUST remain strictly on-device.
  static bool isSensitive(DeviceNotificationSummary notification) {
    final pkg = notification.packageName.trim().toLowerCase();
    if (sensitivePackages.contains(pkg)) {
      return true;
    }

    final combined = '${notification.appName} ${notification.title} ${notification.text}';
    if (_otpKeywordRegex.hasMatch(combined)) {
      return true;
    }
    if (_financialKeywordRegex.hasMatch(combined)) {
      return true;
    }
    // Catch standalone 6-digit auth codes phrased like "Use 482910 to sign in".
    if (_numericCodeRegex.hasMatch(combined) &&
        RegExp(r'\b(use|enter|verify|sign\s?in|log\s?in|valid\s+for|do\s+not\s+share)\b', caseSensitive: false)
            .hasMatch(combined)) {
      return true;
    }
    return false;
  }

  /// Splits [notifications] into AI-safe messages and local-only protected alerts.
  static PrivacyFilteredNotifications partition(
    List<DeviceNotificationSummary> notifications,
  ) {
    final safe = <DeviceNotificationSummary>[];
    final protected = <DeviceNotificationSummary>[];
    for (final item in notifications) {
      if (isSensitive(item)) {
        protected.add(item);
      } else {
        safe.add(item);
      }
    }
    return PrivacyFilteredNotifications(
      safeForAi: List<DeviceNotificationSummary>.unmodifiable(safe),
      protectedLocal: List<DeviceNotificationSummary>.unmodifiable(protected),
    );
  }
}
