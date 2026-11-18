import 'package:vision_ai/features/automation/domain/entities/device_action.dart';

/// Domain contract for permission-guarded Android system automation and intents.
abstract interface class DeviceAutomationRepository {
  /// Checks whether [permission] is currently granted on Android.
  Future<bool> checkPermission(AutomationPermission permission);

  /// Requests [permission] from the user at runtime (or opens special access settings).
  Future<bool> requestPermission(AutomationPermission permission);

  /// Searches device contacts matching [query] (`READ_CONTACTS` guarded).
  Future<List<ContactMatch>> lookupContacts(String query);

  /// Places a direct call (`ACTION_CALL`) or opens the pre-filled dialer (`ACTION_DIAL`).
  Future<DeviceActionResult> makePhoneCall({
    required String phoneNumber,
    bool directCall = false,
  });

  /// Schedules an alarm using Android's `AlarmClock.ACTION_SET_ALARM`.
  Future<DeviceActionResult> setAlarm({
    required int hour,
    required int minute,
    String? label,
    bool skipUi = false,
  });

  /// Starts a countdown timer using Android's `AlarmClock.ACTION_SET_TIMER`.
  Future<DeviceActionResult> setTimer({
    required int seconds,
    String? label,
    bool skipUi = false,
  });

  /// Returns installed launcher applications visible on the device.
  Future<List<InstalledAppInfo>> getInstalledApps();

  /// Launches an installed application by display name or package ID.
  Future<DeviceActionResult> launchApp(String appNameOrPackage);

  /// Opens an Android / ColorOS system settings screen (e.g. `wifi`, `bluetooth`).
  Future<DeviceActionResult> openSystemSettings(String section);

  /// Opens the default SMS composer pre-populated with [phoneNumber] and [message].
  Future<DeviceActionResult> sendSms({
    required String phoneNumber,
    String? message,
  });

  /// Opens WhatsApp share or user-confirmed chat composer (`com.whatsapp` / `wa.me`).
  Future<DeviceActionResult> sendWhatsApp({
    String? phoneNumber,
    String? message,
  });

  /// Reads recent local notifications when Notification Access + user consent are granted.
  Future<List<DeviceNotificationSummary>> getRecentNotifications({
    int limit = 10,
  });

  /// Opens an `http://` or `https://` URL in the system browser.
  Future<DeviceActionResult> openUrl(String url);

  /// Turns the rear camera torch on or off.
  Future<DeviceActionResult> setFlashlight({required bool enabled});

  /// Sets the Android ringer mode (`normal`, `vibrate`, or `silent`).
  Future<DeviceActionResult> setRingerMode(String mode);

  /// Adjusts media volume (`up`, `down`, `mute`, or `unmute`).
  Future<DeviceActionResult> adjustVolume(String direction);

  /// Launches an Android web search for [query].
  Future<DeviceActionResult> webSearch(String query);

  /// Launches Maps / navigation toward [destination].
  Future<DeviceActionResult> navigateTo(String destination);

  /// Reads live device telemetry (battery, network, ringer mode, OS/model).
  Future<DeviceStatusSnapshot> getDeviceStatus();
}
