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
    this.key = '',
    this.canReply = false,
  });

  factory DeviceNotificationSummary.fromMap(Map<Object?, Object?> raw) {
    return DeviceNotificationSummary(
      key: (raw['key'] as String?) ?? '',
      appName: (raw['appName'] as String?) ?? 'App',
      packageName: (raw['packageName'] as String?) ?? '',
      title: (raw['title'] as String?) ?? '',
      text: (raw['text'] as String?) ?? '',
      postedAtMillis: (raw['postedAtMillis'] as num?)?.toInt() ?? 0,
      canReply: (raw['canReply'] as bool?) ?? false,
    );
  }

  final String key;
  final String appName;
  final String packageName;
  final String title;
  final String text;
  final int postedAtMillis;
  final bool canReply;
}

/// Contextual telemetry snapshot of the installed Android device.
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
    this.oemSkin = '',
    this.isFlashlightOn = false,
    this.isDefaultAssistant = false,
    this.isIgnoringBatteryOptimizations = false,
    this.canScheduleExactAlarms = true,
  });

  factory DeviceStatusSnapshot.fromMap(Map<Object?, Object?> raw) {
    final manufacturer = (raw['manufacturer'] as String?) ?? 'Android';
    final isColorOs = (raw['isColorOs'] as bool?) ?? false;
    final rawSkin = (raw['oemSkin'] as String?)?.trim() ?? '';
    final resolvedSkin = rawSkin.isNotEmpty
        ? rawSkin
        : detectOemSkin(manufacturer, isColorOsHint: isColorOs);
    return DeviceStatusSnapshot(
      manufacturer: manufacturer,
      model: (raw['model'] as String?) ?? 'Device',
      androidVersion: (raw['androidVersion'] as String?) ?? '',
      sdkInt: (raw['sdkInt'] as num?)?.toInt() ?? 0,
      batteryLevel: (raw['batteryLevel'] as num?)?.toInt() ?? -1,
      isCharging: (raw['isCharging'] as bool?) ?? false,
      networkType: (raw['networkType'] as String?) ?? 'Unknown',
      ringerMode: (raw['ringerMode'] as String?) ?? 'normal',
      isColorOs: isColorOs,
      oemSkin: resolvedSkin,
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
  final String oemSkin;
  final bool isFlashlightOn;
  final bool isDefaultAssistant;
  final bool isIgnoringBatteryOptimizations;
  final bool canScheduleExactAlarms;

  /// Clean device name avoiding duplicate manufacturer prefixes (e.g. "Samsung S25").
  String get deviceDisplayName {
    final mfg = manufacturer.trim();
    final mdl = model.trim();
    if (mfg.isEmpty) return mdl.isEmpty ? 'Android Device' : mdl;
    if (mdl.isEmpty) return mfg;
    if (mdl.toLowerCase().startsWith(mfg.toLowerCase())) return mdl;
    return '$mfg $mdl';
  }

  /// Resolved OEM ROM skin label for the installed device.
  String get resolvedOemSkin =>
      oemSkin.trim().isNotEmpty
          ? oemSkin.trim()
          : detectOemSkin(manufacturer, isColorOsHint: isColorOs);

  /// Classifies the OEM ROM skin from [manufacturer] name.
  static String detectOemSkin(String manufacturer, {bool isColorOsHint = false}) {
    final lower = manufacturer.trim().toLowerCase();
    if (lower.contains('oppo')) return 'ColorOS';
    if (lower.contains('realme')) return 'Realme UI';
    if (lower.contains('oneplus')) return 'OxygenOS';
    if (lower.contains('samsung')) return 'One UI';
    if (lower.contains('xiaomi') ||
        lower.contains('redmi') ||
        lower.contains('poco')) {
      return 'HyperOS / MIUI';
    }
    if (lower.contains('vivo') || lower.contains('iqoo')) return 'Funtouch OS';
    if (lower.contains('nothing')) return 'Nothing OS';
    if (lower.contains('google')) return 'Pixel Android';
    if (lower.contains('motorola')) return 'Hello UI';
    if (isColorOsHint) return 'ColorOS';
    return 'Android';
  }

  String toReadableSummary() {
    final batteryPart = batteryLevel >= 0
        ? '$batteryLevel%${isCharging ? ' (charging)' : ''}'
        : 'unknown battery';
    final skin = resolvedOemSkin;
    final osTag = skin != 'Android'
        ? '$skin / Android $androidVersion'
        : 'Android $androidVersion';
    return '$deviceDisplayName ($osTag): battery $batteryPart, '
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

  factory AutomationExecutionEntry.fromJson(Map<String, dynamic> json) {
    final wireId = (json['actionWireId'] as String?) ?? '';
    final actionType = DeviceActionType.values.firstWhere(
      (t) => t.wireId == wireId,
      orElse: () => DeviceActionType.deviceStatus,
    );
    final statusName = (json['status'] as String?) ?? 'success';
    final status = DeviceActionStatus.values.firstWhere(
      (s) => s.name == statusName,
      orElse: () => DeviceActionStatus.success,
    );
    return AutomationExecutionEntry(
      id: (json['id'] as String?) ?? '',
      timestamp:
          DateTime.tryParse((json['timestamp'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      request: DeviceActionRequest(
        type: actionType,
        displaySummary: (json['requestSummary'] as String?) ?? '',
        target: (json['target'] as String?) ?? '',
      ),
      result: DeviceActionResult(
        success: (json['success'] as bool?) ?? false,
        status: status,
        actionType: actionType,
        summary: (json['resultSummary'] as String?) ?? '',
      ),
    );
  }

  final String id;
  final DateTime timestamp;
  final DeviceActionRequest request;
  final DeviceActionResult result;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'actionWireId': request.type.wireId,
    'requestSummary': request.displaySummary,
    'target': request.target,
    'success': result.success,
    'status': result.status.name,
    'resultSummary': result.summary,
  };
}
