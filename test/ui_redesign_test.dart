import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vision_ai/app/app.dart';
import 'package:vision_ai/app/router/app_routes.dart';
import 'package:vision_ai/core/constants/app_constants.dart';
import 'package:vision_ai/core/utils/secure_storage_provider.dart';
import 'package:vision_ai/core/utils/shared_preferences_provider.dart';
import 'package:vision_ai/core/widgets/glass/vision_glass_navigation.dart';
import 'package:vision_ai/features/assistant/presentation/screens/assistant_experience_screen.dart';
import 'package:vision_ai/features/assistant/presentation/screens/assistant_overlay_screen.dart';
import 'package:vision_ai/features/assistant/presentation/widgets/vision_ai_orb.dart';
import 'package:vision_ai/features/automation/data/repositories/device_automation_repository_impl.dart';
import 'package:vision_ai/features/automation/domain/entities/device_action.dart';
import 'package:vision_ai/features/automation/domain/repositories/device_automation_repository.dart';
import 'package:vision_ai/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:vision_ai/features/chat/domain/entities/ai_completion_request.dart';
import 'package:vision_ai/features/chat/domain/repositories/ai_provider_client.dart';
import 'package:vision_ai/features/chat/presentation/controllers/chat_controller.dart';
import 'package:vision_ai/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:vision_ai/features/settings/domain/entities/ai_provider_type.dart';
import 'package:vision_ai/features/settings/domain/entities/voice_language.dart';
import 'package:vision_ai/features/settings/presentation/controllers/settings_controller.dart';
import 'package:vision_ai/features/settings/presentation/screens/settings_screen.dart';
import 'package:vision_ai/features/voice/data/repositories/voice_repository_impl.dart';
import 'package:vision_ai/features/voice/domain/entities/tts_voice_info.dart';
import 'package:vision_ai/features/voice/domain/entities/voice_session_state.dart';
import 'package:vision_ai/features/voice/domain/repositories/voice_repository.dart';

class _TestCredentialStore extends SecureCredentialStore {
  _TestCredentialStore() : super(const FlutterSecureStorage());
  final Map<String, String> _keys = <String, String>{};

  @override
  Future<String?> readApiKey(String providerId) async => _keys[providerId];

  @override
  Future<bool> hasApiKey(String providerId) async =>
      _keys[providerId]?.isNotEmpty == true;

  @override
  Future<void> saveApiKey({
    required String providerId,
    required String apiKey,
  }) async {
    _keys[providerId] = apiKey.trim();
  }

  @override
  Future<void> deleteApiKey(String providerId) async {
    _keys.remove(providerId);
  }
}

class _MarkdownStubClient implements AiProviderClient {
  const _MarkdownStubClient(this.providerType);

  @override
  final AiProviderType providerType;

  @override
  Future<String> generateReply({
    required AiCompletionRequest request,
    required String apiKey,
  }) async {
    return '# Summary\nHere is **bold** guidance and code:\n\n'
        '```dart\nvoid hello() => print("VISION");\n```';
  }
}

class _TestVoiceRepository implements VoiceRepository {
  final StreamController<VoiceEvent> controller =
      StreamController<VoiceEvent>.broadcast();

  @override
  Stream<VoiceEvent> watchVoiceEvents() => controller.stream;

  @override
  Future<bool> checkMicrophonePermission() async => true;

  @override
  Future<bool> requestMicrophonePermission() async => true;

  @override
  Future<bool> isSpeechRecognitionAvailable() async => true;

  @override
  Future<void> startListening({
    required VoiceLanguage language,
    int endpointSilenceMs = 3800,
  }) async {}

  @override
  Future<void> stopListening() async {}

  @override
  Future<void> cancelListening() async {}

  @override
  Future<bool> speak({
    required String text,
    required VoiceLanguage language,
    double speechRate = 1.0,
    double pitch = 1.0,
    String voiceName = '',
  }) async => true;

  @override
  Future<bool> pauseSpeaking() async => true;

  @override
  Future<bool> resumeSpeaking() async => true;

  @override
  Future<List<TtsVoiceInfo>> getAvailableVoices({String? locale}) async =>
      const <TtsVoiceInfo>[];

  @override
  Future<void> stopSpeaking() async {}

  @override
  Future<bool> startWakeWordService({double sensitivity = 0.55}) async => false;

  @override
  Future<void> stopWakeWordService() async {}

  @override
  Future<void> setWakeWordSensitivity(double sensitivity) async {}

  @override
  Future<({bool isRunning, bool isMicActive})>
  getWakeWordServiceStatus() async => (isRunning: false, isMicActive: false);

  @override
  Future<bool> isDefaultAssistant() async => false;

  @override
  Future<bool> requestAssistantRole() async => false;

  @override
  Future<void> openAssistantOverlay() async {}

  @override
  Future<String?> consumeOverlayPrompt() async => null;

  @override
  Future<({String prompt, List<String> hypotheses})?>
  consumeOverlayPayload() async => null;

  void dispose() => unawaited(controller.close());
}

class _TestAutomationRepository implements DeviceAutomationRepository {
  @override
  Future<bool> checkPermission(AutomationPermission permission) async => true;

  @override
  Future<bool> requestPermission(AutomationPermission permission) async => true;

  @override
  Future<List<ContactMatch>> lookupContacts(String query) async =>
      const <ContactMatch>[];

  @override
  Future<List<ContactMatch>> getAllContacts() async => const <ContactMatch>[];

  @override
  Future<DeviceActionResult> makePhoneCall({
    required String phoneNumber,
    bool directCall = false,
  }) async => const DeviceActionResult(
    success: true,
    actionType: DeviceActionType.callPhone,
    summary: 'Dialed.',
  );

  @override
  Future<DeviceActionResult> setAlarm({
    required int hour,
    required int minute,
    String? label,
    bool skipUi = false,
    bool isTomorrow = false,
  }) async => const DeviceActionResult(
    success: true,
    actionType: DeviceActionType.setAlarm,
    summary: 'Alarm set.',
  );

  @override
  Future<DeviceActionResult> setTimer({
    required int seconds,
    String? label,
    bool skipUi = false,
  }) async => const DeviceActionResult(
    success: true,
    actionType: DeviceActionType.setTimer,
    summary: 'Timer set.',
  );

  @override
  Future<DeviceActionResult> dismissAlarm() async => const DeviceActionResult(
    success: true,
    actionType: DeviceActionType.dismissAlarm,
    summary: 'Alarm manager opened.',
  );

  @override
  Future<DeviceActionResult> dismissTimer() async => const DeviceActionResult(
    success: true,
    actionType: DeviceActionType.dismissTimer,
    summary: 'Timer manager opened.',
  );

  @override
  Future<List<InstalledAppInfo>> getInstalledApps() async =>
      const <InstalledAppInfo>[];

  @override
  Future<DeviceActionResult> launchApp(String appNameOrPackage) async =>
      const DeviceActionResult(
        success: true,
        actionType: DeviceActionType.launchApp,
        summary: 'Launched.',
      );

  @override
  Future<DeviceActionResult> openSystemSettings(String section) async =>
      const DeviceActionResult(
        success: true,
        actionType: DeviceActionType.openSettings,
        summary: 'Opened settings.',
      );

  @override
  Future<DeviceActionResult> sendSms({
    required String phoneNumber,
    String? message,
  }) async => const DeviceActionResult(
    success: true,
    actionType: DeviceActionType.sendSms,
    summary: 'SMS opened.',
  );

  @override
  Future<DeviceActionResult> sendWhatsApp({
    String? phoneNumber,
    String? message,
  }) async => const DeviceActionResult(
    success: true,
    actionType: DeviceActionType.sendWhatsapp,
    summary: 'WhatsApp opened.',
  );

  @override
  Future<List<DeviceNotificationSummary>> getRecentNotifications({
    int limit = 10,
  }) async => const <DeviceNotificationSummary>[];

  @override
  Future<DeviceActionResult> openUrl(String url) async =>
      const DeviceActionResult(
        success: true,
        actionType: DeviceActionType.openUrl,
        summary: 'URL opened.',
      );

  @override
  Future<DeviceActionResult> setFlashlight({required bool enabled}) async =>
      const DeviceActionResult(
        success: true,
        actionType: DeviceActionType.toggleFlashlight,
        summary: 'Flashlight toggled.',
      );

  @override
  Future<DeviceActionResult> setRingerMode(String mode) async =>
      const DeviceActionResult(
        success: true,
        actionType: DeviceActionType.setRingerMode,
        summary: 'Ringer updated.',
      );

  @override
  Future<DeviceActionResult> adjustVolume(String direction) async =>
      const DeviceActionResult(
        success: true,
        actionType: DeviceActionType.adjustVolume,
        summary: 'Volume adjusted.',
      );

  @override
  Future<DeviceActionResult> webSearch(String query) async =>
      const DeviceActionResult(
        success: true,
        actionType: DeviceActionType.webSearch,
        summary: 'Searched.',
      );

  @override
  Future<DeviceActionResult> navigateTo(String destination) async =>
      const DeviceActionResult(
        success: true,
        actionType: DeviceActionType.navigateTo,
        summary: 'Navigating.',
      );

  @override
  Future<DeviceStatusSnapshot> getDeviceStatus() async =>
      const DeviceStatusSnapshot(
        manufacturer: 'OPPO',
        model: 'Reno 16',
        androidVersion: '16',
        sdkInt: 36,
        batteryLevel: 90,
        isCharging: false,
        networkType: 'Wi-Fi',
        ringerMode: 'normal',
        isColorOs: true,
      );
}

void main() {
  late SharedPreferences prefs;
  late _TestCredentialStore credStore;
  late _TestVoiceRepository voiceRepo;
  late _TestAutomationRepository autoRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
    credStore = _TestCredentialStore();
    voiceRepo = _TestVoiceRepository();
    autoRepo = _TestAutomationRepository();
  });

  tearDown(() {
    voiceRepo.dispose();
  });

  ProviderContainer buildContainer() {
    return ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        secureCredentialStoreProvider.overrideWithValue(credStore),
        voiceRepositoryProvider.overrideWithValue(voiceRepo),
        deviceAutomationRepositoryProvider.overrideWithValue(autoRepo),
        aiProviderClientsProvider.overrideWithValue(
          <AiProviderType, AiProviderClient>{
            AiProviderType.gemini: const _MarkdownStubClient(
              AiProviderType.gemini,
            ),
            AiProviderType.openAi: const _MarkdownStubClient(
              AiProviderType.openAi,
            ),
            AiProviderType.claude: const _MarkdownStubClient(
              AiProviderType.claude,
            ),
          },
        ),
      ],
    );
  }

  Future<void> pumpPastSplash(WidgetTester tester) async {
    await tester.pump(AppConstants.splashMinimumDuration);
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets(
    'VisionAiOrb renders all 5 states, handles reduced motion, and disposes cleanly',
    (WidgetTester tester) async {
      for (final orbState in VisionOrbState.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                disableAnimations: orbState == VisionOrbState.idle,
              ),
              child: Scaffold(
                body: Center(
                  child: VisionAiOrb(state: orbState, audioLevel: 0.72),
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.byType(VisionAiOrb), findsOneWidget);
      }

      // Unmount and confirm no ticker leak
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Floating navigation switches across Home, Chat, Automation, Settings, and dedicated Assistant',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final container = buildContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const VisionApp(),
        ),
      );
      await pumpPastSplash(tester);

      expect(find.byType(VisionGlassNavigationBar), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Recent Conversations'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Recent Conversations'), findsOneWidget);

      // Switch to Chat tab
      await tester.tap(find.text('Chat'));
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('VISION CHAT'), findsOneWidget);

      // Switch to Automation tab
      await tester.tap(find.text('Automation'));
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('DEVICE CONTROL'), findsOneWidget);

      // Switch to Settings tab & verify organized sections
      await tester.tap(find.text('Settings'));
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('SETTINGS'), findsOneWidget);
      expect(find.text('GENERAL'), findsOneWidget);
      expect(find.text('APPEARANCE'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('AI PROVIDERS'),
        220,
        scrollable: find
            .descendant(
              of: find.byType(SettingsScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('AI PROVIDERS'), findsOneWidget);

      // Open dedicated Assistant experience from prominent center button
      await tester.tap(find.byTooltip('Open VISION Voice Assistant'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(AssistantExperienceScreen), findsOneWidget);
      expect(find.text('Ready.'), findsOneWidget);

      // Toggle optional keyboard input inside Assistant experience
      await tester.tap(find.byTooltip('Type command'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Type a command or question...'), findsOneWidget);

      // Dismiss Assistant back to shell
      await tester.tap(find.byTooltip('Dismiss Assistant'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
      expect(find.byType(AssistantExperienceScreen), findsNothing);
    },
  );

  testWidgets(
    'ChatScreen renders Markdown code blocks, timestamps, and Regenerate action',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await credStore.saveApiKey(
        providerId: AiProviderType.gemini.id,
        apiKey: 'AIza-test-chat-key',
      );
      final container = buildContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const VisionApp(),
        ),
      );
      await pumpPastSplash(tester);

      await tester.tap(find.text('Chat'));
      await tester.pump(const Duration(milliseconds: 350));

      await tester.enterText(find.byType(TextField), 'Show me Dart code');
      await tester.tap(find.byTooltip('Send'));
      await tester.pump();
      for (int i = 0; i < 6; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 350));

      final chatState = container.read(chatControllerProvider);
      expect(chatState.errorMessage, isNull);
      expect(chatState.messages.length, 2);
      expect(find.text('DART'), findsOneWidget);
      expect(find.byTooltip('Copy code snippet'), findsOneWidget);
      expect(find.byTooltip('Regenerate response'), findsOneWidget);
    },
  );

  testWidgets(
    'Roadmap screen renders timeline progress and Light theme switches cleanly on compact & landscape viewports',
    (WidgetTester tester) async {
      final container = buildContainer();
      addTearDown(container.dispose);
      await container
          .read(settingsControllerProvider.notifier)
          .setThemeMode(ThemeMode.light);

      // Compact portrait (360x640)
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: OnboardingScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('VISION ROADMAP'), findsOneWidget);
      expect(find.text('Implementation Progress'), findsOneWidget);

      // Landscape OPPO Reno 16 (854x400) on AssistantOverlayScreen
      tester.view.physicalSize = const Size(854, 400);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: AssistantOverlayScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(VisionAiOrb), findsOneWidget);
    },
  );

  test('AppRoutes exposes dedicated assistant route path', () {
    expect(AppRoutes.assistantPath, '/assistant');
    expect(AppRoutes.assistantOverlayPath, '/assistant-overlay');
  });
}
