import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vision_ai/features/automation/data/datasources/automation_platform_datasource.dart';
import 'package:vision_ai/features/automation/domain/entities/device_action.dart';
import 'package:vision_ai/features/automation/domain/repositories/device_automation_repository.dart';

/// Provides the [AutomationPlatformDataSource] instance.
final automationPlatformDataSourceProvider =
    Provider<AutomationPlatformDataSource>((ref) {
      return AutomationPlatformDataSource();
    });

/// Provides the concrete [DeviceAutomationRepository] implementation.
final deviceAutomationRepositoryProvider = Provider<DeviceAutomationRepository>(
  (ref) {
    final dataSource = ref.watch(automationPlatformDataSourceProvider);
    return DeviceAutomationRepositoryImpl(dataSource);
  },
);

/// Concrete [DeviceAutomationRepository] backed by [AutomationPlatformDataSource].
class DeviceAutomationRepositoryImpl implements DeviceAutomationRepository {
  const DeviceAutomationRepositoryImpl(this._dataSource);

  final AutomationPlatformDataSource _dataSource;

  @override
  Future<bool> checkPermission(AutomationPermission permission) =>
      _dataSource.checkPermission(permission);

  @override
  Future<bool> requestPermission(AutomationPermission permission) =>
      _dataSource.requestPermission(permission);

  @override
  Future<List<ContactMatch>> lookupContacts(String query) =>
      _dataSource.lookupContacts(query);

  @override
  Future<List<ContactMatch>> getAllContacts() => _dataSource.getAllContacts();

  @override
  Future<DeviceActionResult> makePhoneCall({
    required String phoneNumber,
    bool directCall = false,
  }) => _dataSource.makePhoneCall(
    phoneNumber: phoneNumber,
    directCall: directCall,
  );

  @override
  Future<DeviceActionResult> setAlarm({
    required int hour,
    required int minute,
    String? label,
    bool skipUi = false,
  }) => _dataSource.setAlarm(
    hour: hour,
    minute: minute,
    label: label,
    skipUi: skipUi,
  );

  @override
  Future<DeviceActionResult> setTimer({
    required int seconds,
    String? label,
    bool skipUi = false,
  }) => _dataSource.setTimer(seconds: seconds, label: label, skipUi: skipUi);

  @override
  Future<DeviceActionResult> dismissAlarm() => _dataSource.dismissAlarm();

  @override
  Future<DeviceActionResult> dismissTimer() => _dataSource.dismissTimer();

  @override
  Future<List<InstalledAppInfo>> getInstalledApps() =>
      _dataSource.getInstalledApps();

  @override
  Future<DeviceActionResult> launchApp(String appNameOrPackage) =>
      _dataSource.launchApp(appNameOrPackage);

  @override
  Future<DeviceActionResult> openSystemSettings(String section) =>
      _dataSource.openSystemSettings(section);

  @override
  Future<DeviceActionResult> sendSms({
    required String phoneNumber,
    String? message,
  }) => _dataSource.sendSms(phoneNumber: phoneNumber, message: message);

  @override
  Future<DeviceActionResult> sendWhatsApp({
    String? phoneNumber,
    String? message,
  }) => _dataSource.sendWhatsApp(phoneNumber: phoneNumber, message: message);

  @override
  Future<List<DeviceNotificationSummary>> getRecentNotifications({
    int limit = 10,
  }) => _dataSource.getRecentNotifications(limit: limit);

  @override
  Future<DeviceActionResult> openUrl(String url) => _dataSource.openUrl(url);

  @override
  Future<DeviceActionResult> setFlashlight({required bool enabled}) =>
      _dataSource.setFlashlight(enabled: enabled);

  @override
  Future<DeviceActionResult> setRingerMode(String mode) =>
      _dataSource.setRingerMode(mode);

  @override
  Future<DeviceActionResult> adjustVolume(String direction) =>
      _dataSource.adjustVolume(direction);

  @override
  Future<DeviceActionResult> webSearch(String query) =>
      _dataSource.webSearch(query);

  @override
  Future<DeviceActionResult> navigateTo(String destination) =>
      _dataSource.navigateTo(destination);

  @override
  Future<DeviceStatusSnapshot> getDeviceStatus() =>
      _dataSource.getDeviceStatus();
}
