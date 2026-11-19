import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vision_ai/core/utils/shared_preferences_provider.dart';
import 'package:vision_ai/features/developer/data/services/developer_tools_service.dart';
import 'package:vision_ai/features/developer/presentation/controllers/developer_snippets_controller.dart';
import 'package:vision_ai/features/help/domain/entities/help_guide_catalog.dart';
import 'package:vision_ai/features/integrations/data/services/external_app_integration_service.dart';
import 'package:vision_ai/features/planner/domain/entities/planner_task.dart';
import 'package:vision_ai/features/proactive/presentation/controllers/proactive_intelligence_controller.dart';
import 'package:vision_ai/features/smart_home/domain/entities/smart_home_device.dart';
import 'package:vision_ai/features/smart_home/presentation/controllers/smart_home_controller.dart';

void main() {
  group('VISION AI v1.4 Complete Master Spec Suite', () {
    test('Module 24: ProactiveIntelligenceEngine ranks battery, setup, briefing & respects dismissals', () {
      final tasks = <PlannerTask>[
        PlannerTask(
          id: 't1',
          title: 'Submit release notes',
          priority: PlannerPriority.high,
          createdAt: DateTime(2026, 11, 19, 8),
        ),
      ];

      final suggestions = ProactiveIntelligenceEngine.evaluate(
        now: DateTime(2026, 11, 19, 9, 0),
        tasks: tasks,
        hasConfiguredProvider: false,
        batteryPercent: 15,
        isCharging: false,
      );

      expect(suggestions.first.id, 'low_battery');
      expect(suggestions.any((s) => s.id == 'setup_provider'), isTrue);
      expect(suggestions.any((s) => s.id == 'planner_briefing'), isTrue);

      final afterDismiss = ProactiveIntelligenceEngine.evaluate(
        now: DateTime(2026, 11, 19, 9, 0),
        tasks: tasks,
        hasConfiguredProvider: true,
        batteryPercent: 15,
        isCharging: false,
        dismissedIds: const <String>{'low_battery'},
      );
      expect(afterDismiss.any((s) => s.id == 'low_battery'), isFalse);
      expect(afterDismiss.first.id, 'planner_briefing');
    });

    test('Module 22: ExternalAppIntegrationService parses Maps, YouTube, Spotify, Calendar & Email', () {
      final maps = ExternalAppIntegrationService.parseCommand(
        'Navigate to Ahmedabad Airport',
      );
      expect(maps?.type, ExternalAppCommandType.navigateMaps);
      expect(maps?.primaryValue, 'Ahmedabad Airport');

      final yt = ExternalAppIntegrationService.parseCommand(
        'Play lo-fi beats on YouTube',
      );
      expect(yt?.type, ExternalAppCommandType.searchYouTube);
      expect(yt?.primaryValue, 'lo-fi beats');

      final spotify = ExternalAppIntegrationService.parseCommand(
        'Play Arijit Singh on Spotify',
      );
      expect(spotify?.type, ExternalAppCommandType.searchSpotify);
      expect(spotify?.primaryValue, 'Arijit Singh');

      final cal = ExternalAppIntegrationService.parseCommand(
        'Schedule meeting Sprint Demo',
      );
      expect(cal?.type, ExternalAppCommandType.createCalendarEvent);
      expect(cal?.primaryValue, 'Sprint Demo');

      final email = ExternalAppIntegrationService.parseCommand(
        'Compose email to team@example.com subject Release v1.4',
      );
      expect(email?.type, ExternalAppCommandType.composeEmail);
      expect(email?.primaryValue, 'team@example.com');
      expect(email?.secondaryValue, 'Release v1.4');
    });

    test('Module 23: SmartHomeController persists devices, matches voice commands & triggers webhook', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();

      var calledUrl = '';
      final mockClient = MockClient((request) async {
        calledUrl = request.url.toString();
        return http.Response('{"ok":true}', 200);
      });

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          smartHomeHttpClientProvider.overrideWithValue(mockClient),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(smartHomeControllerProvider.notifier);
      await notifier.addDevice(
        name: 'Living Room Light',
        room: 'Living Room',
        backend: SmartHomeBackend.httpWebhook,
        onWebhookUrl: 'http://192.168.1.50/light/on',
        offWebhookUrl: 'http://192.168.1.50/light/off',
      );

      final parsed = SmartHomeController.parseVoiceCommand(
        'Turn on Living Room Light',
      );
      expect(parsed, isNotNull);
      expect(parsed!.turnOn, isTrue);

      final matched = notifier.matchDevice(parsed.deviceQuery);
      expect(matched, isNotNull);

      final msg = await notifier.setDevicePower(matched!, turnOn: true);
      expect(msg, contains('Turned ON Living Room Light'));
      expect(calledUrl, 'http://192.168.1.50/light/on');
      expect(container.read(smartHomeControllerProvider).devices.first.isOn, isTrue);
    });

    test('Module 26: DeveloperToolsService offline JSON, Base64, JWT, Regex & Snippet Vault', () async {
      final jsonOk = DeveloperToolsService.formatJson('{"a":1,"b":[2,3]}');
      expect(jsonOk.success, isTrue);
      expect(jsonOk.output, contains('  "a": 1'));

      final jsonBad = DeveloperToolsService.formatJson('{invalid}');
      expect(jsonBad.success, isFalse);

      final enc = DeveloperToolsService.encodeBase64('VISION AI v1.4');
      expect(enc.success, isTrue);
      final dec = DeveloperToolsService.decodeBase64(enc.output);
      expect(dec.success, isTrue);
      expect(dec.output, 'VISION AI v1.4');

      final header = base64Url.encode(utf8.encode('{"alg":"HS256","typ":"JWT"}'));
      final payload = base64Url.encode(utf8.encode('{"sub":"vision","role":"dev"}'));
      final jwt = DeveloperToolsService.decodeJwt('$header.$payload.sig');
      expect(jwt.success, isTrue);
      expect(jwt.output, contains('"sub": "vision"'));

      final regexRes = DeveloperToolsService.testRegex(
        pattern: r'\d{4}',
        sampleText: 'Release 2026 build 1405',
      );
      expect(regexRes.success, isTrue);
      expect(regexRes.output, contains('2 match(es)'));

      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      await container
          .read(developerSnippetsControllerProvider.notifier)
          .addSnippet(
            title: 'Flutter Release Build',
            language: 'bash',
            code: 'flutter build apk --release',
          );
      expect(container.read(developerSnippetsControllerProvider).length, 1);

      // Verify Help Hub & Settings Search include v1.4 modules
      expect(HelpGuideCatalog.searchTopics('smart home'), isNotEmpty);
      expect(HelpGuideCatalog.searchTopics('jwt'), isNotEmpty);
      expect(HelpGuideCatalog.searchSettings('developer'), isNotEmpty);
    });
  });
}
