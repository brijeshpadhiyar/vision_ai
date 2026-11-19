import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vision_ai/core/utils/shared_preferences_provider.dart';
import 'package:vision_ai/features/automation/domain/entities/device_action.dart';
import 'package:vision_ai/features/automation/domain/entities/trusted_command_policy.dart';
import 'package:vision_ai/features/automation/presentation/controllers/trusted_commands_controller.dart';

void main() {
  test('Wave 3 TrustedCommandPolicy classifies safe vs sensitive tiers accurately', () {
    expect(TrustedCommandPolicy.isSensitive(DeviceActionType.setAlarm), isFalse);
    expect(TrustedCommandPolicy.isSensitive(DeviceActionType.launchApp), isFalse);
    expect(TrustedCommandPolicy.isSensitive(DeviceActionType.toggleFlashlight), isFalse);

    expect(TrustedCommandPolicy.isSensitive(DeviceActionType.callPhone), isTrue);
    expect(TrustedCommandPolicy.isSensitive(DeviceActionType.sendSms), isTrue);
    expect(TrustedCommandPolicy.isSensitive(DeviceActionType.sendWhatsapp), isTrue);
    expect(TrustedCommandPolicy.isSensitive(DeviceActionType.readNotifications), isTrue);
    expect(TrustedCommandPolicy.isSensitive(DeviceActionType.openUrl), isTrue);
  });

  test('Wave 3 TrustedCommandsController grants, persists, and revokes trust & notification blocklist', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(trustedCommandsControllerProvider.notifier);
    expect(
      container
          .read(trustedCommandsControllerProvider)
          .isActionTrusted(DeviceActionType.sendWhatsapp),
      isFalse,
    );
    expect(
      container
          .read(trustedCommandsControllerProvider)
          .isActionTrusted(DeviceActionType.setAlarm),
      isTrue,
    );

    await notifier.trustAction(DeviceActionType.sendWhatsapp);
    await notifier.blockNotificationPackage('com.bank.secure');

    final reloaded = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(reloaded.dispose);
    final loaded = reloaded.read(trustedCommandsControllerProvider);
    expect(loaded.isActionTrusted(DeviceActionType.sendWhatsapp), isTrue);
    expect(loaded.blockedNotificationPackages, contains('com.bank.secure'));

    await reloaded
        .read(trustedCommandsControllerProvider.notifier)
        .revokeAction(DeviceActionType.sendWhatsapp);
    expect(
      reloaded
          .read(trustedCommandsControllerProvider)
          .isActionTrusted(DeviceActionType.sendWhatsapp),
      isFalse,
    );
  });
}
