import 'package:material_ui/material_ui.dart';

/// Supported Android system automation and device control action categories.
enum DeviceActionType {
  callPhone('Call / Dial', 'call_phone'),
  lookupContacts('Lookup Contacts', 'lookup_contacts'),
  setAlarm('Set Alarm', 'set_alarm'),
  setTimer('Set Timer', 'set_timer'),
  launchApp('Launch App', 'launch_app'),
  openSettings('System Settings', 'open_settings'),
  sendSms('Send SMS', 'send_sms'),
  sendWhatsapp('WhatsApp', 'send_whatsapp'),
  readNotifications('Notifications', 'read_notifications'),
  openUrl('Open URL', 'open_url'),
  toggleFlashlight('Flashlight', 'toggle_flashlight'),
  setRingerMode('Ringer Mode', 'set_ringer_mode'),
  adjustVolume('Volume Control', 'adjust_volume'),
  webSearch('Web Search', 'web_search'),
  navigateTo('Navigation', 'navigate_to'),
  deviceStatus('Device Status', 'device_status'),
  dismissAlarm('Dismiss Alarm', 'dismiss_alarm'),
  dismissTimer('Dismiss Timer', 'dismiss_timer'),
  stopSpeaking('Stop Speaking', 'stop_speaking'),
  repeatLast('Repeat Response', 'repeat_last'),
  cancelAction('Cancel Action', 'cancel_action');

  const DeviceActionType(this.displayName, this.wireId);

  final String displayName;
  final String wireId;
}

/// Structured outcome status for all Android automation commands.
enum DeviceActionStatus {
  success,
  failed,
  permissionRequired,
  confirmationRequired,
  notSupported,
  ambiguousContact,
  cancelled,
}

/// Runtime and special Android permissions guarded by the automation engine.
enum AutomationPermission {
  callPhone('call_phone', 'Phone Calls (CALL_PHONE)'),
  readContacts('read_contacts', 'Contacts (READ_CONTACTS)'),
  notifications('notifications', 'Notification Access (Special Access)');

  const AutomationPermission(this.channelKey, this.displayName);

  final String channelKey;
  final String displayName;
}

/// Contact match resolved from Android `ContactsContract`.
@immutable
class ContactMatch {
  const ContactMatch({
    required this.name,
    required this.phoneNumber,
    this.label = 'Phone',
    this.contactId = '',
  });

  factory ContactMatch.fromMap(Map<Object?, Object?> raw) {
    return ContactMatch(
      name: (raw['name'] as String?) ?? 'Unknown',
      phoneNumber: (raw['phoneNumber'] as String?) ?? '',
      label: (raw['label'] as String?) ?? 'Phone',
      contactId: (raw['contactId'] as String?) ?? '',
    );
  }

  final String name;
  final String phoneNumber;
  final String label;
  final String contactId;
}

/// Installed launcher application metadata returned by `PackageManager`.
@immutable
class InstalledAppInfo {
  const InstalledAppInfo({required this.appName, required this.packageName});

  factory InstalledAppInfo.fromMap(Map<Object?, Object?> raw) {
    return InstalledAppInfo(
      appName: (raw['appName'] as String?) ?? '',
      packageName: (raw['packageName'] as String?) ?? '',
    );
  }

  final String appName;
  final String packageName;
}

/// Local notification summary read via [NotificationListenerService] after
/// explicit user consent and special access grant.
@immutable
class DeviceNotificationSummary {
  const DeviceNotificationSummary({
    required this.appName,
    required this.packageName,
    required this.title,
    required this.text,
    required this.postedAtMillis,
  });

  factory DeviceNotificationSummary.fromMap(Map<Object?, Object?> raw) {
    return DeviceNotificationSummary(
      appName: (raw['appName'] as String?) ?? 'App',
      packageName: (raw['packageName'] as String?) ?? '',
      title: (raw['title'] as String?) ?? '',
      text: (raw['text'] as String?) ?? '',
      postedAtMillis: (raw['postedAtMillis'] as num?)?.toInt() ?? 0,
    );
  }

  final String appName;
  final String packageName;
  final String title;
  final String text;
  final int postedAtMillis;
}

/// Contextual telemetry snapshot of the Android / OPPO Reno 16 device.
@immutable
class DeviceStatusSnapshot {
  const DeviceStatusSnapshot({
    required this.manufacturer,
    required this.model,
    required this.androidVersion,
    required this.sdkInt,
    required this.batteryLevel,
    required this.isCharging,
    required this.networkType,
    required this.ringerMode,
    required this.isColorOs,
    this.isFlashlightOn = false,
    this.isDefaultAssistant = false,
    this.isIgnoringBatteryOptimizations = false,
    this.canScheduleExactAlarms = true,
  });

  factory DeviceStatusSnapshot.fromMap(Map<Object?, Object?> raw) {
    return DeviceStatusSnapshot(
      manufacturer: (raw['manufacturer'] as String?) ?? 'Android',
      model: (raw['model'] as String?) ?? 'Device',
      androidVersion: (raw['androidVersion'] as String?) ?? '',
      sdkInt: (raw['sdkInt'] as num?)?.toInt() ?? 0,
      batteryLevel: (raw['batteryLevel'] as num?)?.toInt() ?? -1,
      isCharging: (raw['isCharging'] as bool?) ?? false,
      networkType: (raw['networkType'] as String?) ?? 'Unknown',
      ringerMode: (raw['ringerMode'] as String?) ?? 'normal',
      isColorOs: (raw['isColorOs'] as bool?) ?? false,
      isFlashlightOn: (raw['isFlashlightOn'] as bool?) ?? false,
      isDefaultAssistant: (raw['isDefaultAssistant'] as bool?) ?? false,
      isIgnoringBatteryOptimizations:
          (raw['isIgnoringBatteryOptimizations'] as bool?) ?? false,
      canScheduleExactAlarms: (raw['canScheduleExactAlarms'] as bool?) ?? true,
    );
  }

  final String manufacturer;
  final String model;
  final String androidVersion;
  final int sdkInt;
  final int batteryLevel;
  final bool isCharging;
  final String networkType;
  final String ringerMode;
  final bool isColorOs;
  final bool isFlashlightOn;
  final bool isDefaultAssistant;
  final bool isIgnoringBatteryOptimizations;
  final bool canScheduleExactAlarms;

  String toReadableSummary() {
    final batteryPart = batteryLevel >= 0
        ? '$batteryLevel%${isCharging ? ' (charging)' : ''}'
        : 'unknown battery';
    final osTag = isColorOs
        ? 'ColorOS / Android $androidVersion'
        : 'Android $androidVersion';
    return '$manufacturer $model ($osTag): battery $batteryPart, '
        'network $networkType, ringer $ringerMode.';
  }
}

/// Structured device automation intent ready for execution or user confirmation.
@immutable
class DeviceActionRequest {
  const DeviceActionRequest({
    required this.type,
    required this.displaySummary,
    this.target = '',
    this.hour,
    this.minute,
    this.durationSeconds,
    this.label,
    this.message,
    this.enabled,
    this.requiresConfirmation = false,
    this.contactOrdinalIndex,
    this.isTomorrow = false,
    this.followUpActions = const <DeviceActionRequest>[],
  });

  final DeviceActionType type;
  final String displaySummary;
  final String target;
  final int? hour;
  final int? minute;
  final int? durationSeconds;
  final String? label;
  final String? message;
  final bool? enabled;
  final bool requiresConfirmation;
  final int? contactOrdinalIndex;
  final bool isTomorrow;
  final List<DeviceActionRequest> followUpActions;
}

/// Outcome returned after executing or attempting a [DeviceActionRequest].
@immutable
class DeviceActionResult {
  const DeviceActionResult({
    required this.success,
    required this.actionType,
    required this.summary,
    DeviceActionStatus? status,
    this.details,
    this.requiresPermission = false,
    this.missingPermission,
    this.contacts = const <ContactMatch>[],
    this.notifications = const <DeviceNotificationSummary>[],
    this.deviceStatus,
    this.suggestedContact,
    this.spokenContactQuery,
    this.contactConfidence,
  }) : status =
           status ??
           (success
               ? DeviceActionStatus.success
               : (requiresPermission
                     ? DeviceActionStatus.permissionRequired
                     : DeviceActionStatus.failed));

  final bool success;
  final DeviceActionStatus status;
  final DeviceActionType actionType;
  final String summary;
  final String? details;
  final bool requiresPermission;
  final AutomationPermission? missingPermission;
  final List<ContactMatch> contacts;
  final List<DeviceNotificationSummary> notifications;
  final DeviceStatusSnapshot? deviceStatus;
  final ContactMatch? suggestedContact;
  final String? spokenContactQuery;
  final double? contactConfidence;
}

/// Historical record of an executed automation request for UI inspection.
@immutable
class AutomationExecutionEntry {
  const AutomationExecutionEntry({
    required this.id,
    required this.timestamp,
    required this.request,
    required this.result,
  });

  final String id;
  final DateTime timestamp;
  final DeviceActionRequest request;
  final DeviceActionResult result;
}
