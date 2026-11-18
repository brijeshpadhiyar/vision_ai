import 'package:flutter/services.dart';

import 'package:vision_ai/core/constants/app_constants.dart';
import 'package:vision_ai/core/errors/app_exception.dart';
import 'package:vision_ai/features/automation/domain/entities/device_action.dart';

/// Platform channel data source communicating with `VisionAutomationChannel.kt`.
class AutomationPlatformDataSource {
  AutomationPlatformDataSource({MethodChannel? methodChannel})
    : _methodChannel =
          methodChannel ??
          const MethodChannel(AppConstants.automationMethodChannel);

  final MethodChannel _methodChannel;

  Future<bool> checkPermission(AutomationPermission permission) async {
    try {
      final granted = await _methodChannel.invokeMethod<bool>(
        'checkPermission',
        <String, Object>{'permission': permission.channelKey},
      );
      return granted ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> requestPermission(AutomationPermission permission) async {
    try {
      final granted = await _methodChannel.invokeMethod<bool>(
        'requestPermission',
        <String, Object>{'permission': permission.channelKey},
      );
      return granted ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (error, stackTrace) {
      throw DeviceAutomationException(
        message:
            error.message ??
            'Unable to request ${permission.displayName} permission.',
        code: error.code,
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<List<ContactMatch>> lookupContacts(String query) async {
    try {
      final raw = await _methodChannel.invokeMethod<List<Object?>>(
        'lookupContacts',
        <String, Object>{'query': query},
      );
      if (raw == null) return const <ContactMatch>[];
      return raw
          .whereType<Map<Object?, Object?>>()
          .map(ContactMatch.fromMap)
          .toList(growable: false);
    } on MissingPluginException catch (error, stackTrace) {
      throw DeviceAutomationException(
        message: 'Native contact lookup is only available on Android.',
        cause: error,
        stackTrace: stackTrace,
      );
    } on PlatformException catch (error, stackTrace) {
      throw DeviceAutomationException(
        message: error.message ?? 'Unable to query device contacts.',
        code: error.code,
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<DeviceActionResult> makePhoneCall({
    required String phoneNumber,
    bool directCall = false,
  }) async {
    try {
      final raw = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
        'makePhoneCall',
        <String, Object>{'phoneNumber': phoneNumber, 'directCall': directCall},
      );
      final mode = (raw?['mode'] as String?) ?? 'dialer';
      final resolvedNumber = (raw?['phoneNumber'] as String?) ?? phoneNumber;
      return DeviceActionResult(
        success: true,
        actionType: DeviceActionType.callPhone,
        summary: mode == 'direct_call'
            ? 'Calling $resolvedNumber directly...'
            : 'Opened dialer for $resolvedNumber.',
        details: mode == 'direct_call'
            ? 'Placed via Android ACTION_CALL.'
            : 'Pre-filled via Android ACTION_DIAL.',
      );
    } on MissingPluginException {
      return const DeviceActionResult(
        success: false,
        actionType: DeviceActionType.callPhone,
        summary: 'Phone calling is only available on Android.',
      );
    } on PlatformException catch (error) {
      return DeviceActionResult(
        success: false,
        actionType: DeviceActionType.callPhone,
        summary: error.message ?? 'Unable to start phone call.',
      );
    }
  }

  Future<DeviceActionResult> setAlarm({
    required int hour,
    required int minute,
    String? label,
    bool skipUi = false,
  }) async {
    try {
      await _methodChannel.invokeMethod<Map<Object?, Object?>>(
        'setAlarm',
        <String, Object>{
          'hour': hour,
          'minute': minute,
          if (label != null && label.isNotEmpty) 'label': label,
          'skipUi': skipUi,
        },
      );
      final hh = hour.toString().padLeft(2, '0');
      final mm = minute.toString().padLeft(2, '0');
      return DeviceActionResult(
        success: true,
        actionType: DeviceActionType.setAlarm,
        summary:
            'Alarm scheduled for $hh:$mm${label != null && label.isNotEmpty ? ' ($label)' : ''}.',
      );
    } on MissingPluginException {
      return const DeviceActionResult(
        success: false,
        status: DeviceActionStatus.notSupported,
        actionType: DeviceActionType.setAlarm,
        summary: 'Alarm scheduling is only available on Android.',
      );
    } on PlatformException catch (error) {
      return DeviceActionResult(
        success: false,
        status: error.code == 'ACTIVITY_NOT_FOUND'
            ? DeviceActionStatus.notSupported
            : DeviceActionStatus.failed,
        actionType: DeviceActionType.setAlarm,
        summary: error.message ?? 'Unable to set alarm.',
      );
    }
  }

  Future<DeviceActionResult> setTimer({
    required int seconds,
    String? label,
    bool skipUi = false,
  }) async {
    try {
      await _methodChannel.invokeMethod<Map<Object?, Object?>>(
        'setTimer',
        <String, Object>{
          'seconds': seconds,
          if (label != null && label.isNotEmpty) 'label': label,
          'skipUi': skipUi,
        },
      );
      return DeviceActionResult(
        success: true,
        status: DeviceActionStatus.success,
        actionType: DeviceActionType.setTimer,
        summary:
            'Timer started for ${seconds}s${label != null && label.isNotEmpty ? ' ($label)' : ''}.',
      );
    } on MissingPluginException {
      return const DeviceActionResult(
        success: false,
        status: DeviceActionStatus.notSupported,
        actionType: DeviceActionType.setTimer,
        summary: 'Timer creation is only available on Android.',
      );
    } on PlatformException catch (error) {
      return DeviceActionResult(
        success: false,
        status: error.code == 'ACTIVITY_NOT_FOUND'
            ? DeviceActionStatus.notSupported
            : DeviceActionStatus.failed,
        actionType: DeviceActionType.setTimer,
        summary: error.message ?? 'Unable to start timer.',
      );
    }
  }

  Future<DeviceActionResult> dismissAlarm() async {
    try {
      await _methodChannel.invokeMethod<Map<Object?, Object?>>('dismissAlarm');
      return const DeviceActionResult(
        success: true,
        actionType: DeviceActionType.dismissAlarm,
        summary: 'Opened alarm manager to dismiss or review alarms.',
      );
    } on MissingPluginException {
      return const DeviceActionResult(
        success: false,
        status: DeviceActionStatus.notSupported,
        actionType: DeviceActionType.dismissAlarm,
        summary: 'Alarm management is only available on Android.',
      );
    } on PlatformException catch (error) {
      return DeviceActionResult(
        success: false,
        status: DeviceActionStatus.failed,
        actionType: DeviceActionType.dismissAlarm,
        summary: error.message ?? 'Unable to dismiss alarm.',
      );
    }
  }

  Future<DeviceActionResult> dismissTimer() async {
    try {
      await _methodChannel.invokeMethod<Map<Object?, Object?>>('dismissTimer');
      return const DeviceActionResult(
        success: true,
        actionType: DeviceActionType.dismissTimer,
        summary: 'Opened timer controls to stop or review active timers.',
      );
    } on MissingPluginException {
      return const DeviceActionResult(
        success: false,
        status: DeviceActionStatus.notSupported,
        actionType: DeviceActionType.dismissTimer,
        summary: 'Timer management is only available on Android.',
      );
    } on PlatformException catch (error) {
      return DeviceActionResult(
        success: false,
        status: DeviceActionStatus.failed,
        actionType: DeviceActionType.dismissTimer,
        summary: error.message ?? 'Unable to manage timer.',
      );
    }
  }

  Future<List<InstalledAppInfo>> getInstalledApps() async {
    try {
      final raw = await _methodChannel.invokeMethod<List<Object?>>(
        'getInstalledApps',
      );
      if (raw == null) return const <InstalledAppInfo>[];
      return raw
          .whereType<Map<Object?, Object?>>()
          .map(InstalledAppInfo.fromMap)
          .toList(growable: false);
    } on MissingPluginException {
      return const <InstalledAppInfo>[];
    } on PlatformException {
      return const <InstalledAppInfo>[];
    }
  }

  Future<DeviceActionResult> launchApp(String appNameOrPackage) async {
    try {
      final raw = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
        'launchApp',
        <String, Object>{'query': appNameOrPackage},
      );
      final appName = (raw?['appName'] as String?) ?? appNameOrPackage;
      final packageName = (raw?['packageName'] as String?) ?? '';
      return DeviceActionResult(
        success: true,
        actionType: DeviceActionType.launchApp,
        summary: 'Launched $appName.',
        details: packageName.isNotEmpty ? packageName : null,
      );
    } on MissingPluginException {
      return const DeviceActionResult(
        success: false,
        actionType: DeviceActionType.launchApp,
        summary: 'App launching is only available on Android.',
      );
    } on PlatformException catch (error) {
      return DeviceActionResult(
        success: false,
        actionType: DeviceActionType.launchApp,
        summary: error.message ?? 'Unable to launch $appNameOrPackage.',
      );
    }
  }

  Future<DeviceActionResult> openSystemSettings(String section) async {
    try {
      final raw = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
        'openSystemSettings',
        <String, Object>{'section': section},
      );
      final opened = (raw?['section'] as String?) ?? section;
      return DeviceActionResult(
        success: true,
        actionType: DeviceActionType.openSettings,
        summary: 'Opened $opened settings.',
      );
    } on MissingPluginException {
      return const DeviceActionResult(
        success: false,
        actionType: DeviceActionType.openSettings,
        summary: 'System settings intents are only available on Android.',
      );
    } on PlatformException catch (error) {
      return DeviceActionResult(
        success: false,
        actionType: DeviceActionType.openSettings,
        summary: error.message ?? 'Unable to open system settings.',
      );
    }
  }

  Future<DeviceActionResult> sendSms({
    required String phoneNumber,
    String? message,
  }) async {
    try {
      await _methodChannel.invokeMethod<Map<Object?, Object?>>(
        'sendSms',
        <String, Object>{
          'phoneNumber': phoneNumber,
          if (message != null && message.isNotEmpty) 'message': message,
        },
      );
      return DeviceActionResult(
        success: true,
        actionType: DeviceActionType.sendSms,
        summary: 'Opened SMS composer for $phoneNumber.',
      );
    } on MissingPluginException {
      return const DeviceActionResult(
        success: false,
        actionType: DeviceActionType.sendSms,
        summary: 'SMS intents are only available on Android.',
      );
    } on PlatformException catch (error) {
      return DeviceActionResult(
        success: false,
        status: DeviceActionStatus.failed,
        actionType: DeviceActionType.sendSms,
        summary: error.message ?? 'Unable to open SMS composer.',
      );
    }
  }

  Future<DeviceActionResult> sendWhatsApp({
    String? phoneNumber,
    String? message,
  }) async {
    try {
      await _methodChannel.invokeMethod<Map<Object?, Object?>>(
        'sendWhatsApp',
        <String, Object>{
          if (phoneNumber != null && phoneNumber.isNotEmpty)
            'phoneNumber': phoneNumber,
          if (message != null && message.isNotEmpty) 'message': message,
        },
      );
      return DeviceActionResult(
        success: true,
        status: DeviceActionStatus.success,
        actionType: DeviceActionType.sendWhatsapp,
        summary: phoneNumber != null && phoneNumber.isNotEmpty
            ? 'Opened WhatsApp composer for $phoneNumber (tap Send in WhatsApp to confirm).'
            : 'Opened WhatsApp share sheet (choose recipient to confirm).',
      );
    } on MissingPluginException {
      return const DeviceActionResult(
        success: false,
        status: DeviceActionStatus.notSupported,
        actionType: DeviceActionType.sendWhatsapp,
        summary: 'WhatsApp intent integration is only available on Android.',
      );
    } on PlatformException catch (error) {
      return DeviceActionResult(
        success: false,
        status: error.code == 'APP_NOT_FOUND'
            ? DeviceActionStatus.notSupported
            : DeviceActionStatus.failed,
        actionType: DeviceActionType.sendWhatsapp,
        summary: error.message ?? 'Unable to open WhatsApp.',
      );
    }
  }

  Future<List<DeviceNotificationSummary>> getRecentNotifications({
    int limit = 10,
  }) async {
    try {
      final raw = await _methodChannel.invokeMethod<List<Object?>>(
        'getRecentNotifications',
        <String, Object>{'limit': limit},
      );
      if (raw == null) return const <DeviceNotificationSummary>[];
      return raw
          .whereType<Map<Object?, Object?>>()
          .map(DeviceNotificationSummary.fromMap)
          .toList(growable: false);
    } on MissingPluginException {
      return const <DeviceNotificationSummary>[];
    } on PlatformException catch (error, stackTrace) {
      throw DeviceAutomationException(
        message:
            error.message ??
            'Notification listener access is required to read notifications.',
        code: error.code,
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<DeviceActionResult> openUrl(String url) async {
    try {
      final raw = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
        'openUrl',
        <String, Object>{'url': url},
      );
      final openedUrl = (raw?['url'] as String?) ?? url;
      return DeviceActionResult(
        success: true,
        actionType: DeviceActionType.openUrl,
        summary: 'Opened $openedUrl.',
      );
    } on MissingPluginException {
      return const DeviceActionResult(
        success: false,
        actionType: DeviceActionType.openUrl,
        summary: 'Opening web links via Android intent requires Android.',
      );
    } on PlatformException catch (error) {
      return DeviceActionResult(
        success: false,
        actionType: DeviceActionType.openUrl,
        summary: error.message ?? 'Unable to open URL.',
      );
    }
  }

  Future<DeviceActionResult> setFlashlight({required bool enabled}) async {
    try {
      await _methodChannel.invokeMethod<Map<Object?, Object?>>(
        'setFlashlight',
        <String, Object>{'enabled': enabled},
      );
      return DeviceActionResult(
        success: true,
        actionType: DeviceActionType.toggleFlashlight,
        summary: enabled ? 'Flashlight turned on.' : 'Flashlight turned off.',
      );
    } on MissingPluginException {
      return const DeviceActionResult(
        success: false,
        actionType: DeviceActionType.toggleFlashlight,
        summary: 'Flashlight control is only available on Android.',
      );
    } on PlatformException catch (error) {
      return DeviceActionResult(
        success: false,
        actionType: DeviceActionType.toggleFlashlight,
        summary: error.message ?? 'Unable to control flashlight.',
      );
    }
  }

  Future<DeviceActionResult> setRingerMode(String mode) async {
    try {
      final raw = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
        'setRingerMode',
        <String, Object>{'mode': mode},
      );
      final resolved = (raw?['mode'] as String?) ?? mode;
      return DeviceActionResult(
        success: true,
        actionType: DeviceActionType.setRingerMode,
        summary: 'Ringer mode set to $resolved.',
      );
    } on MissingPluginException {
      return const DeviceActionResult(
        success: false,
        actionType: DeviceActionType.setRingerMode,
        summary: 'Ringer mode control is only available on Android.',
      );
    } on PlatformException catch (error) {
      return DeviceActionResult(
        success: false,
        actionType: DeviceActionType.setRingerMode,
        summary: error.message ?? 'Unable to change ringer mode.',
      );
    }
  }

  Future<DeviceActionResult> adjustVolume(String direction) async {
    try {
      final raw = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
        'adjustVolume',
        <String, Object>{'direction': direction},
      );
      final current = (raw?['currentVolume'] as num?)?.toInt();
      final max = (raw?['maxVolume'] as num?)?.toInt();
      final levelSuffix = (current != null && max != null && max > 0)
          ? ' ($current/$max)'
          : '';
      return DeviceActionResult(
        success: true,
        actionType: DeviceActionType.adjustVolume,
        summary: 'Media volume $direction$levelSuffix.',
      );
    } on MissingPluginException {
      return const DeviceActionResult(
        success: false,
        actionType: DeviceActionType.adjustVolume,
        summary: 'Volume control is only available on Android.',
      );
    } on PlatformException catch (error) {
      return DeviceActionResult(
        success: false,
        actionType: DeviceActionType.adjustVolume,
        summary: error.message ?? 'Unable to adjust volume.',
      );
    }
  }

  Future<DeviceActionResult> webSearch(String query) async {
    try {
      await _methodChannel.invokeMethod<Map<Object?, Object?>>(
        'webSearch',
        <String, Object>{'query': query},
      );
      return DeviceActionResult(
        success: true,
        actionType: DeviceActionType.webSearch,
        summary: 'Searched the web for "$query".',
      );
    } on MissingPluginException {
      return const DeviceActionResult(
        success: false,
        actionType: DeviceActionType.webSearch,
        summary: 'Web search intent is only available on Android.',
      );
    } on PlatformException catch (error) {
      return DeviceActionResult(
        success: false,
        actionType: DeviceActionType.webSearch,
        summary: error.message ?? 'Unable to open web search.',
      );
    }
  }

  Future<DeviceActionResult> navigateTo(String destination) async {
    try {
      await _methodChannel.invokeMethod<Map<Object?, Object?>>(
        'navigateTo',
        <String, Object>{'destination': destination},
      );
      return DeviceActionResult(
        success: true,
        actionType: DeviceActionType.navigateTo,
        summary: 'Opened navigation to "$destination".',
      );
    } on MissingPluginException {
      return const DeviceActionResult(
        success: false,
        actionType: DeviceActionType.navigateTo,
        summary: 'Maps navigation intent is only available on Android.',
      );
    } on PlatformException catch (error) {
      return DeviceActionResult(
        success: false,
        actionType: DeviceActionType.navigateTo,
        summary: error.message ?? 'Unable to launch navigation.',
      );
    }
  }

  Future<DeviceStatusSnapshot> getDeviceStatus() async {
    try {
      final raw = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
        'getDeviceStatus',
      );
      if (raw != null) {
        return DeviceStatusSnapshot.fromMap(raw);
      }
    } on MissingPluginException {
      // Fallback for unit test host environments.
    } on PlatformException {
      // Fallback on unexpected platform error.
    }
    return const DeviceStatusSnapshot(
      manufacturer: 'Android',
      model: 'Device Standby',
      androidVersion: 'N/A',
      sdkInt: 0,
      batteryLevel: -1,
      isCharging: false,
      networkType: 'Unknown',
      ringerMode: 'normal',
      isColorOs: false,
    );
  }
}
