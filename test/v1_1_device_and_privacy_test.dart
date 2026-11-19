import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vision_ai/core/utils/shared_preferences_provider.dart';
import 'package:vision_ai/features/automation/domain/entities/device_action.dart';
import 'package:vision_ai/features/automation/presentation/controllers/trusted_commands_controller.dart';
import 'package:vision_ai/features/privacy/presentation/screens/privacy_dashboard_screen.dart';
import 'package:vision_ai/features/settings/presentation/widgets/device_setup_guide_sheet.dart';

void main() {
  test('v1.1 DeviceStatusSnapshot detects installed OEM skin & deduplicates model name dynamically', () {
    final samsung = DeviceStatusSnapshot.fromMap(const <Object?, Object?>{
      'manufacturer': 'samsung',
      'model': 'Samsung SM-S938B',
      'androidVersion': '15',
      'sdkInt': 35,
      'batteryLevel': 82,
      'isCharging': false,
      'networkType': 'Wi-Fi',
      'ringerMode': 'normal',
      'isColorOs': false,
    });
    expect(samsung.resolvedOemSkin, 'One UI');
    expect(samsung.deviceDisplayName, 'Samsung SM-S938B');
    expect(samsung.toReadableSummary(), contains('One UI / Android 15'));

    final xiaomi = DeviceStatusSnapshot.fromMap(const <Object?, Object?>{
      'manufacturer': 'Xiaomi',
      'model': '24129PN74G',
      'androidVersion': '15',
      'sdkInt': 35,
      'batteryLevel': 65,
      'isCharging': true,
      'networkType': 'Cellular',
      'ringerMode': 'vibrate',
      'isColorOs': false,
    });
    expect(xiaomi.resolvedOemSkin, 'HyperOS / MIUI');
    expect(xiaomi.deviceDisplayName, 'Xiaomi 24129PN74G');

    final oppo = DeviceStatusSnapshot.fromMap(const <Object?, Object?>{
      'manufacturer': 'OPPO',
      'model': 'Reno 16',
      'androidVersion': '16',
      'sdkInt': 36,
      'batteryLevel': 90,
      'isCharging': false,
      'networkType': 'Wi-Fi',
      'ringerMode': 'normal',
      'isColorOs': true,
    });
    expect(oppo.resolvedOemSkin, 'ColorOS');
    expect(oppo.deviceDisplayName, 'OPPO Reno 16');

    final pixel = DeviceStatusSnapshot.fromMap(const <Object?, Object?>{
      'manufacturer': 'Google',
      'model': 'Pixel 9',
      'androidVersion': '15',
      'sdkInt': 35,
      'batteryLevel': 70,
      'isCharging': false,
      'networkType': 'Wi-Fi',
      'ringerMode': 'normal',
      'isColorOs': false,
    });
    expect(pixel.resolvedOemSkin, 'Pixel Android');
    expect(pixel.deviceDisplayName, 'Google Pixel 9');
  });

  testWidgets('v1.1 DeviceSetupGuideSheet adapts title and steps to detected Samsung One UI', (tester) async {
    const samsung = DeviceStatusSnapshot(
      manufacturer: 'Samsung',
      model: 'Galaxy S25',
      androidVersion: '15',
      sdkInt: 35,
      batteryLevel: 80,
      isCharging: false,
      networkType: 'Wi-Fi',
      ringerMode: 'normal',
      isColorOs: false,
      oemSkin: 'One UI',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DeviceSetupGuideSheet(
            deviceStatus: samsung,
            isDefaultAssistant: false,
            onOpenBatterySettings: () {},
            onRequestDefaultAssistant: () {},
          ),
        ),
      ),
    );

    expect(find.text('Samsung Galaxy S25 • One UI Guide'), findsOneWidget);
    expect(find.textContaining('Sleeping / Deep sleeping apps'), findsOneWidget);
  });

  testWidgets('v1.1 PrivacyDashboardScreen renders security posture and revokes trusted commands', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    await container
        .read(trustedCommandsControllerProvider.notifier)
        .trustAction(DeviceActionType.sendWhatsapp);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: PrivacyDashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PRIVACY & SECURITY'), findsOneWidget);
    expect(find.text('SECURITY POSTURE'), findsOneWidget);
    expect(find.text('Android Keystore Encryption'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Revoke All Trusted Commands'),
      300,
    );
    await tester.ensureVisible(find.text('Revoke All Trusted Commands'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Revoke All Trusted Commands'));
    await tester.pumpAndSettle();

    expect(
      container
          .read(trustedCommandsControllerProvider)
          .trustedSensitiveActions,
      isEmpty,
    );
  });
}
