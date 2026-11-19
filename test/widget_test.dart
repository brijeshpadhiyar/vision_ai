import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vision_ai/app/app.dart';
import 'package:vision_ai/app/theme/app_colors.dart';
import 'package:vision_ai/core/constants/app_constants.dart';
import 'package:vision_ai/core/utils/secure_storage_provider.dart';
import 'package:vision_ai/core/utils/shared_preferences_provider.dart';
import 'package:vision_ai/core/widgets/vision_brand_logo.dart';
import 'package:vision_ai/features/assistant/presentation/widgets/assistant_mic_button.dart';
import 'package:vision_ai/features/assistant/presentation/widgets/assistant_orb.dart';
import 'package:vision_ai/features/automation/data/repositories/device_automation_repository_impl.dart';
import 'package:vision_ai/features/automation/domain/entities/device_action.dart';
import 'package:vision_ai/features/automation/domain/repositories/device_automation_repository.dart';
import 'package:vision_ai/features/automation/domain/utils/device_intent_parser.dart';
import 'package:vision_ai/features/automation/presentation/controllers/automation_controller.dart';
import 'package:vision_ai/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:vision_ai/features/chat/domain/entities/ai_completion_request.dart';
import 'package:vision_ai/features/chat/domain/entities/chat_message.dart';
import 'package:vision_ai/features/chat/domain/repositories/ai_provider_client.dart';
import 'package:vision_ai/features/chat/presentation/controllers/chat_controller.dart';
import 'package:vision_ai/features/settings/domain/entities/ai_provider_type.dart';
import 'package:vision_ai/features/settings/domain/entities/voice_language.dart';
import 'package:vision_ai/features/settings/presentation/controllers/settings_controller.dart';
import 'package:vision_ai/features/splash/presentation/screens/splash_screen.dart';
import 'package:vision_ai/features/voice/data/repositories/voice_repository_impl.dart';
import 'package:vision_ai/features/voice/domain/entities/tts_voice_info.dart';
import 'package:vision_ai/features/voice/domain/entities/voice_session_state.dart';
import 'package:vision_ai/features/voice/domain/repositories/voice_repository.dart';
import 'package:vision_ai/features/voice/domain/utils/wake_word_detector.dart';
import 'package:vision_ai/features/voice/presentation/controllers/voice_controller.dart';

/// In-memory [SecureCredentialStore] used in tests without platform channels.
class _InMemoryCredentialStore extends SecureCredentialStore {
  _InMemoryCredentialStore() : super(const FlutterSecureStorage());

  final Map<String, String> _keys = <String, String>{};

  @override
  Future<String?> readApiKey(String providerId) async => _keys[providerId];

  @override
  Future<bool> hasApiKey(String providerId) async =>
      _keys.containsKey(providerId) && _keys[providerId]!.isNotEmpty;

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

/// Deterministic [AiProviderClient] stub for verifying multi-provider routing.
class _StubAiProviderClient implements AiProviderClient {
  const _StubAiProviderClient(this.providerType);

  @override
  final AiProviderType providerType;

  @override
  Future<String> generateReply({
    required AiCompletionRequest request,
    required String apiKey,
  }) async {
    final latestPrompt = request.messages.last.content;
    return '[${providerType.displayName} • ${request.responseLanguage.localeCode}] '
        'Ack: $latestPrompt';
  }
}

/// Programmable [VoiceRepository] fake for testing STT, TTS, and wake-word flows.
class _FakeVoiceRepository implements VoiceRepository {
  final StreamController<VoiceEvent> eventController =
      StreamController<VoiceEvent>.broadcast();

  bool permissionGranted = true;
  VoiceLanguage? lastListeningLanguage;
  String? lastSpokenText;
  VoiceLanguage? lastSpokenLanguage;

  @override
  Stream<VoiceEvent> watchVoiceEvents() => eventController.stream;

  @override
  Future<bool> checkMicrophonePermission() async => permissionGranted;

  @override
  Future<bool> requestMicrophonePermission() async => permissionGranted;

  @override
  Future<bool> isSpeechRecognitionAvailable() async => true;

  @override
  Future<void> startListening({
    required VoiceLanguage language,
    int endpointSilenceMs = 3800,
  }) async {
    lastListeningLanguage = language;
  }

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
  }) async {
    lastSpokenText = text;
    lastSpokenLanguage = language;
    return true;
  }

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

  void dispose() {
    unawaited(eventController.close());
  }
}

/// Programmable [DeviceAutomationRepository] fake for testing Phase 4 Android automation.
class _FakeDeviceAutomationRepository implements DeviceAutomationRepository {
  bool callPermissionGranted = true;
  bool contactsPermissionGranted = true;
  bool notificationsPermissionGranted = true;
  List<ContactMatch> contactsToReturn = const <ContactMatch>[
    ContactMatch(name: 'Mom', phoneNumber: '+91 9876543210', label: 'Mobile'),
  ];

  String? lastCalledNumber;
  bool? lastDirectCallFlag;
  int? lastAlarmHour;
  int? lastAlarmMinute;
  int? lastTimerSeconds;
  String? lastLaunchedApp;
  String? lastOpenedSettingsSection;
  bool? lastFlashlightState;
  String ringerModeState = 'normal';
  String? lastVolumeDirection;
  String? lastSearchQuery;
  String? lastNavigationDestination;

  @override
  Future<bool> checkPermission(AutomationPermission permission) async {
    return switch (permission) {
      AutomationPermission.callPhone => callPermissionGranted,
      AutomationPermission.readContacts => contactsPermissionGranted,
      AutomationPermission.notifications => notificationsPermissionGranted,
    };
  }

  @override
  Future<bool> requestPermission(AutomationPermission permission) async {
    return checkPermission(permission);
  }

  @override
  Future<List<ContactMatch>> lookupContacts(String query) async {
    return contactsToReturn
        .where(
          (c) =>
              c.name.toLowerCase().contains(query.toLowerCase()) ||
              c.phoneNumber.contains(query),
        )
        .toList(growable: false);
  }

  @override
  Future<List<ContactMatch>> getAllContacts() async => contactsToReturn;

  @override
  Future<DeviceActionResult> makePhoneCall({
    required String phoneNumber,
    bool directCall = false,
  }) async {
    lastCalledNumber = phoneNumber;
    lastDirectCallFlag = directCall;
    return DeviceActionResult(
      success: true,
      actionType: DeviceActionType.callPhone,
      summary: directCall
          ? 'Calling $phoneNumber directly...'
          : 'Opened dialer for $phoneNumber.',
    );
  }

  @override
  Future<DeviceActionResult> setAlarm({
    required int hour,
    required int minute,
    String? label,
    bool skipUi = false,
    bool isTomorrow = false,
  }) async {
    lastAlarmHour = hour;
    lastAlarmMinute = minute;
    return DeviceActionResult(
      success: true,
      actionType: DeviceActionType.setAlarm,
      summary:
          'Alarm scheduled for ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}.',
    );
  }

  @override
  Future<DeviceActionResult> setTimer({
    required int seconds,
    String? label,
    bool skipUi = false,
  }) async {
    lastTimerSeconds = seconds;
    return DeviceActionResult(
      success: true,
      actionType: DeviceActionType.setTimer,
      summary: 'Timer started for ${seconds}s.',
    );
  }

  @override
  Future<DeviceActionResult> dismissAlarm() async {
    return const DeviceActionResult(
      success: true,
      actionType: DeviceActionType.dismissAlarm,
      summary: 'Alarm manager opened.',
    );
  }

  @override
  Future<DeviceActionResult> dismissTimer() async {
    return const DeviceActionResult(
      success: true,
      actionType: DeviceActionType.dismissTimer,
      summary: 'Timer manager opened.',
    );
  }

  @override
  Future<List<InstalledAppInfo>> getInstalledApps() async {
    return const <InstalledAppInfo>[
      InstalledAppInfo(appName: 'Camera', packageName: 'com.oppo.camera'),
      InstalledAppInfo(appName: 'WhatsApp', packageName: 'com.whatsapp'),
    ];
  }

  @override
  Future<DeviceActionResult> launchApp(String appNameOrPackage) async {
    lastLaunchedApp = appNameOrPackage;
    return DeviceActionResult(
      success: true,
      actionType: DeviceActionType.launchApp,
      summary: 'Launched $appNameOrPackage.',
    );
  }

  @override
  Future<DeviceActionResult> openSystemSettings(String section) async {
    lastOpenedSettingsSection = section;
    return DeviceActionResult(
      success: true,
      actionType: DeviceActionType.openSettings,
      summary: 'Opened $section settings.',
    );
  }

  @override
  Future<DeviceActionResult> sendSms({
    required String phoneNumber,
    String? message,
  }) async {
    return DeviceActionResult(
      success: true,
      actionType: DeviceActionType.sendSms,
      summary: 'Opened SMS composer for $phoneNumber.',
    );
  }

  @override
  Future<DeviceActionResult> sendWhatsApp({
    String? phoneNumber,
    String? message,
  }) async {
    return DeviceActionResult(
      success: true,
      actionType: DeviceActionType.sendWhatsapp,
      summary: 'Opened WhatsApp composer for ${phoneNumber ?? 'share'}.',
    );
  }

  @override
  Future<List<DeviceNotificationSummary>> getRecentNotifications({
    int limit = 10,
  }) async {
    return const <DeviceNotificationSummary>[
      DeviceNotificationSummary(
        appName: 'Messages',
        packageName: 'com.google.android.apps.messaging',
        title: 'Mom',
        text: 'Call me when free',
        postedAtMillis: 1000,
      ),
    ];
  }

  @override
  Future<DeviceActionResult> openUrl(String url) async {
    return DeviceActionResult(
      success: true,
      actionType: DeviceActionType.openUrl,
      summary: 'Opened $url.',
    );
  }

  @override
  Future<DeviceActionResult> setFlashlight({required bool enabled}) async {
    lastFlashlightState = enabled;
    return DeviceActionResult(
      success: true,
      actionType: DeviceActionType.toggleFlashlight,
      summary: enabled ? 'Flashlight turned on.' : 'Flashlight turned off.',
    );
  }

  @override
  Future<DeviceActionResult> setRingerMode(String mode) async {
    ringerModeState = mode;
    return DeviceActionResult(
      success: true,
      actionType: DeviceActionType.setRingerMode,
      summary: 'Ringer mode set to $mode.',
    );
  }

  @override
  Future<DeviceActionResult> adjustVolume(String direction) async {
    lastVolumeDirection = direction;
    return DeviceActionResult(
      success: true,
      actionType: DeviceActionType.adjustVolume,
      summary: 'Media volume $direction.',
    );
  }

  @override
  Future<DeviceActionResult> webSearch(String query) async {
    lastSearchQuery = query;
    return DeviceActionResult(
      success: true,
      actionType: DeviceActionType.webSearch,
      summary: 'Searched the web for "$query".',
    );
  }

  @override
  Future<DeviceActionResult> navigateTo(String destination) async {
    lastNavigationDestination = destination;
    return DeviceActionResult(
      success: true,
      actionType: DeviceActionType.navigateTo,
      summary: 'Opened navigation to "$destination".',
    );
  }

  @override
  Future<DeviceStatusSnapshot> getDeviceStatus() async {
    return DeviceStatusSnapshot(
      manufacturer: 'OPPO',
      model: 'Reno 16',
      androidVersion: '16',
      sdkInt: 36,
      batteryLevel: 84,
      isCharging: false,
      networkType: 'Wi-Fi',
      ringerMode: ringerModeState,
      isColorOs: true,
      isFlashlightOn: lastFlashlightState ?? false,
    );
  }
}

void main() {
  late SharedPreferences sharedPreferences;
  late _InMemoryCredentialStore credentialStore;
  late _FakeVoiceRepository voiceRepository;
  late _FakeDeviceAutomationRepository automationRepository;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    sharedPreferences = await SharedPreferences.getInstance();
    credentialStore = _InMemoryCredentialStore();
    voiceRepository = _FakeVoiceRepository();
    automationRepository = _FakeDeviceAutomationRepository();
  });

  tearDown(() {
    voiceRepository.dispose();
  });

  ProviderContainer createTestContainer() {
    return ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        secureCredentialStoreProvider.overrideWithValue(credentialStore),
        voiceRepositoryProvider.overrideWithValue(voiceRepository),
        deviceAutomationRepositoryProvider.overrideWithValue(
          automationRepository,
        ),
        aiProviderClientsProvider.overrideWithValue(
          <AiProviderType, AiProviderClient>{
            AiProviderType.gemini: const _StubAiProviderClient(
              AiProviderType.gemini,
            ),
            AiProviderType.openAi: const _StubAiProviderClient(
              AiProviderType.openAi,
            ),
            AiProviderType.claude: const _StubAiProviderClient(
              AiProviderType.claude,
            ),
          },
        ),
      ],
    );
  }

  test('ChatMessage serializes and deserializes accurately via JSON', () {
    final original = ChatMessage(
      id: 'msg_1',
      sender: MessageSender.assistant,
      content: 'Hello from VISION.',
      createdAt: DateTime.utc(2026, 11, 17, 10, 30),
      provider: AiProviderType.gemini,
    );

    final jsonMap = original.toJson();
    final restored = ChatMessage.fromJson(jsonMap);

    expect(restored.id, original.id);
    expect(restored.sender, MessageSender.assistant);
    expect(restored.content, original.content);
    expect(restored.provider, AiProviderType.gemini);
    expect(restored.createdAt, original.createdAt);
  });

  test('WakeWordDetector matches English, Hindi, and Gujarati wake phrases and extracts commands', () {
    final enMatch = WakeWordDetector.evaluate(
      'Hey VISION, summarize my schedule',
    );
    expect(enMatch.isTriggered, isTrue);
    expect(enMatch.trailingCommand, 'summarize my schedule');

    final hiMatch = WakeWordDetector.evaluate('हे विज़न आज का मौसम बताओ');
    expect(hiMatch.isTriggered, isTrue);
    expect(hiMatch.trailingCommand, 'आज का मौसम बताओ');

    final guMatch = WakeWordDetector.evaluate('હે વિઝન કેમ છો');
    expect(guMatch.isTriggered, isTrue);
    expect(guMatch.trailingCommand, 'કેમ છો');

    final nonMatch = WakeWordDetector.evaluate('Good morning everyone');
    expect(nonMatch.isTriggered, isFalse);
  });

  testWidgets(
    'Renders VISION home screen and toggles live voice listening on mic button tap',
    (WidgetTester tester) async {
      final container = createTestContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const VisionApp(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text(AppConstants.appName), findsOneWidget);
      expect(find.text(AppConstants.homeGreeting), findsOneWidget);
      expect(find.text(AppConstants.homeSubtitle), findsOneWidget);
      expect(find.byType(AssistantOrb), findsOneWidget);
      expect(find.byType(AssistantMicButton), findsOneWidget);

      await tester.ensureVisible(find.byIcon(Icons.mic_none_rounded));
      await tester.tap(find.byIcon(Icons.mic_none_rounded));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.runAsync(() => GoogleFonts.pendingFonts());
      await tester.pump();

      final voiceState = container.read(voiceControllerProvider);
      expect(voiceState.isListening, isTrue);
      expect(voiceState.phase, VoiceListeningPhase.listeningCommand);
      expect(voiceRepository.lastListeningLanguage, VoiceLanguage.english);
    },
  );

  testWidgets(
    'Navigates to Settings screen and persists provider, language, TTS, and wake-word preferences',
    (WidgetTester tester) async {
      final container = createTestContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const VisionApp(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pump(const Duration(milliseconds: 600));

      await tester.tap(find.byTooltip('Settings'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('SETTINGS'), findsOneWidget);

      final settingsNotifier = container.read(
        settingsControllerProvider.notifier,
      );
      await settingsNotifier.setAiProvider(AiProviderType.claude);
      await settingsNotifier.setVoiceLanguage(VoiceLanguage.gujarati);
      await settingsNotifier.setThemeMode(ThemeMode.light);
      await settingsNotifier.setAutoSpeakReplies(enabled: false);
      await settingsNotifier.setWakeWordEnabled(enabled: true);

      final updated = container.read(settingsControllerProvider);
      expect(updated.selectedAiProvider, AiProviderType.claude);
      expect(updated.selectedVoiceLanguage, VoiceLanguage.gujarati);
      expect(updated.themeMode, ThemeMode.light);
      expect(updated.autoSpeakReplies, isFalse);
      expect(updated.wakeWordEnabled, isTrue);
    },
  );

  test('VoiceController processes final speech transcript, invokes AI provider, and speaks reply via TTS', () async {
    final container = createTestContainer();
    addTearDown(container.dispose);

    // Configure Gemini API key and Hindi voice locale.
    await credentialStore.saveApiKey(
      providerId: AiProviderType.gemini.id,
      apiKey: 'AIza-test-gemini-key',
    );
    await container
        .read(settingsControllerProvider.notifier)
        .setVoiceLanguage(VoiceLanguage.hindi);

    final voiceNotifier = container.read(voiceControllerProvider.notifier);
    await voiceNotifier.startCommandListening();

    // Emit final speech transcript from the voice stream.
    voiceRepository.eventController.add(
      const VoiceTranscriptEvent(text: 'नमस्ते विज़न', isFinal: true),
    );

    // Allow async stream listener and AI completion to settle cleanly under parallel load.
    for (var i = 0; i < 12; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 25));
      if (container.read(chatControllerProvider).messages.length >= 2 &&
          voiceRepository.lastSpokenText != null) {
        break;
      }
    }

    final chatState = container.read(chatControllerProvider);
    expect(chatState.messages.length, 2);
    expect(
      chatState.messages.last.content,
      '[Google Gemini • hi-IN] Ack: नमस्ते विज़न',
    );
    expect(
      voiceRepository.lastSpokenText,
      '[Google Gemini • hi-IN] Ack: नमस्ते विज़न',
    );
    expect(voiceRepository.lastSpokenLanguage, VoiceLanguage.hindi);
  });

  test('DeviceIntentParser parses local Android commands and extracts AI action tags', () {
    final alarm = DeviceIntentParser.parseLocalCommand(
      'Set an alarm for 6:30 PM called Workout',
    );
    expect(alarm?.type, DeviceActionType.setAlarm);
    expect(alarm?.hour, 18);
    expect(alarm?.minute, 30);
    expect(alarm?.label, 'Workout');

    final timer = DeviceIntentParser.parseLocalCommand(
      'Start timer for 5 minutes',
    );
    expect(timer?.type, DeviceActionType.setTimer);
    expect(timer?.durationSeconds, 300);

    final settings = DeviceIntentParser.parseLocalCommand(
      'open Wi-Fi settings',
    );
    expect(settings?.type, DeviceActionType.openSettings);
    expect(settings?.target, 'wifi');

    final app = DeviceIntentParser.parseLocalCommand('open WhatsApp');
    expect(app?.type, DeviceActionType.launchApp);
    expect(app?.target, 'WhatsApp');

    final torch = DeviceIntentParser.parseLocalCommand('turn on flashlight');
    expect(torch?.type, DeviceActionType.toggleFlashlight);
    expect(torch?.enabled, isTrue);

    expect(
      DeviceIntentParser.parseLocalCommand('What is the capital of India?'),
      isNull,
    );

    final aiExtraction = DeviceIntentParser.extractAiAction(
      'Sure, opening Bluetooth settings for you. '
      '[[VISION_ACTION:{"action":"open_settings","section":"bluetooth"}]]',
    );
    expect(aiExtraction.cleanText, 'Sure, opening Bluetooth settings for you.');
    expect(aiExtraction.action?.type, DeviceActionType.openSettings);
    expect(aiExtraction.action?.target, 'bluetooth');
  });

  test('AutomationController enforces permission guards, contact disambiguation, and direct call confirmation', () async {
    final container = createTestContainer();
    addTearDown(container.dispose);

    final controller = container.read(automationControllerProvider.notifier);

    // 1. Contact permission denied blocks name-based calling cleanly.
    automationRepository.contactsPermissionGranted = false;
    final deniedResult = await controller.tryHandleNaturalCommand('call Mom');
    expect(deniedResult?.success, isFalse);
    expect(deniedResult?.requiresPermission, isTrue);
    expect(deniedResult?.missingPermission, AutomationPermission.readContacts);

    // 2. Multiple matching contacts triggers disambiguation choice.
    automationRepository.contactsPermissionGranted = true;
    automationRepository.contactsToReturn = const <ContactMatch>[
      ContactMatch(name: 'Rahul Work', phoneNumber: '+91 9000011111'),
      ContactMatch(name: 'Rahul Home', phoneNumber: '+91 9000022222'),
    ];
    final multiResult = await controller.tryHandleNaturalCommand('call Rahul');
    expect(multiResult?.success, isFalse);
    expect(
      container.read(automationControllerProvider).contactChoices.length,
      2,
    );

    // Selecting a contact opens dialer safely when directPhoneCallsEnabled is false.
    final selectedResult = await controller.selectContactForPendingAction(
      const ContactMatch(name: 'Rahul Home', phoneNumber: '+91 9000022222'),
    );
    expect(selectedResult.success, isTrue);
    expect(automationRepository.lastCalledNumber, '+91 9000022222');
    expect(automationRepository.lastDirectCallFlag, isFalse);

    // 3. Enabling directPhoneCallsEnabled queues confirmation before ACTION_CALL.
    await container
        .read(settingsControllerProvider.notifier)
        .setDirectPhoneCallsEnabled(enabled: true);
    final pendingResult = await controller.tryHandleNaturalCommand(
      'call +91 9876543210',
    );
    expect(pendingResult?.success, isFalse);
    expect(
      container.read(automationControllerProvider).pendingConfirmation,
      isNotNull,
    );

    final confirmed = await controller.confirmPendingAction();
    expect(confirmed?.success, isTrue);
    expect(automationRepository.lastDirectCallFlag, isTrue);
  });

  test('VoiceController executes local Android device command via speech without needing an API key', () async {
    final container = createTestContainer();
    addTearDown(container.dispose);

    final voiceNotifier = container.read(voiceControllerProvider.notifier);
    await voiceNotifier.startCommandListening();

    voiceRepository.eventController.add(
      const VoiceTranscriptEvent(
        text: 'set timer for 5 minutes',
        isFinal: true,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(automationRepository.lastTimerSeconds, 300);
    expect(voiceRepository.lastSpokenText, 'Timer started for 300s.');
    expect(container.read(chatControllerProvider).messages.length, 2);
  });

  testWidgets(
    'Navigates to Device Control Hub, displays OPPO Reno 16 telemetry, and executes a command',
    (WidgetTester tester) async {
      final container = createTestContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const VisionApp(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pump(const Duration(milliseconds: 600));

      await tester.tap(find.byTooltip('Device Control'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('DEVICE CONTROL'), findsOneWidget);
      expect(find.text('OPPO Reno 16'), findsOneWidget);
      expect(find.text('ColorOS'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'turn on flashlight');
      await tester.tap(find.text('Run'));
      await tester.pump(const Duration(milliseconds: 200));

      expect(automationRepository.lastFlashlightState, isTrue);
      expect(find.text('Flashlight turned on.'), findsWidgets);
    },
  );

  testWidgets(
    'Displays branded VISION splash screen and smoothly transitions to home screen',
    (WidgetTester tester) async {
      final container = createTestContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const VisionApp(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(VisionSplashScreen), findsOneWidget);
      expect(find.byType(VisionBrandLogo), findsOneWidget);
      expect(find.text(AppConstants.appName), findsOneWidget);
      expect(find.text(AppConstants.appTagline), findsOneWidget);

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, AppColors.brandBackgroundPrimary);

      await tester.pump(AppConstants.splashMinimumDuration);
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byType(VisionSplashScreen), findsNothing);
      expect(find.text(AppConstants.homeGreeting), findsOneWidget);
    },
  );

  test('DeviceIntentParser supports Hindi, Gujarati, and expanded Phase 4 Android actions', () {
    final hiTorch = DeviceIntentParser.parseLocalCommand('टॉर्च चालू करो');
    expect(hiTorch?.type, DeviceActionType.toggleFlashlight);
    expect(hiTorch?.enabled, isTrue);

    final guTorchOff = DeviceIntentParser.parseLocalCommand(
      'ફ્લેશલાઇટ બંધ કરો',
    );
    expect(guTorchOff?.type, DeviceActionType.toggleFlashlight);
    expect(guTorchOff?.enabled, isFalse);

    final hiTimer = DeviceIntentParser.parseLocalCommand(
      '5 मिनट का टाइमर लगाओ',
    );
    expect(hiTimer?.type, DeviceActionType.setTimer);
    expect(hiTimer?.durationSeconds, 300);

    final guCall = DeviceIntentParser.parseLocalCommand('મમ્મી ને કૉલ કરો');
    expect(guCall?.type, DeviceActionType.callPhone);
    expect(guCall?.target, 'મમ્મી');

    final ringer = DeviceIntentParser.parseLocalCommand('put phone on vibrate');
    expect(ringer?.type, DeviceActionType.setRingerMode);
    expect(ringer?.target, 'vibrate');

    final volume = DeviceIntentParser.parseLocalCommand(
      'increase media volume',
    );
    expect(volume?.type, DeviceActionType.adjustVolume);
    expect(volume?.target, 'up');

    final search = DeviceIntentParser.parseLocalCommand(
      'search google for Flutter 3.50',
    );
    expect(search?.type, DeviceActionType.webSearch);
    expect(search?.target, 'Flutter 3.50');

    final nav = DeviceIntentParser.parseLocalCommand(
      'navigate to Ahmedabad Airport',
    );
    expect(nav?.type, DeviceActionType.navigateTo);
    expect(nav?.target, 'Ahmedabad Airport');

    final aiNav = DeviceIntentParser.extractAiAction(
      'Starting route now. [[VISION_ACTION:{"action":"navigate_to","destination":"Sabarmati Riverfront"}]]',
    );
    expect(aiNav.cleanText, 'Starting route now.');
    expect(aiNav.action?.type, DeviceActionType.navigateTo);
    expect(aiNav.action?.target, 'Sabarmati Riverfront');
  });

  test('AutomationController handles ringer mode, volume, search, navigation, and non-pending contact search', () async {
    final container = createTestContainer();
    addTearDown(container.dispose);

    final controller = container.read(automationControllerProvider.notifier);

    final lookupRes = await controller.tryHandleNaturalCommand(
      'find contact Mom',
    );
    expect(lookupRes?.success, isTrue);
    final afterLookup = container.read(automationControllerProvider);
    expect(afterLookup.pendingConfirmation, isNull);
    expect(afterLookup.contactChoices, isEmpty);
    expect(afterLookup.contactSearchResults.length, 1);

    final ringerRes = await controller.tryHandleNaturalCommand(
      'put phone on vibrate',
    );
    expect(ringerRes?.success, isTrue);
    expect(automationRepository.ringerModeState, 'vibrate');

    final volRes = await controller.tryHandleNaturalCommand('volume up');
    expect(volRes?.success, isTrue);
    expect(automationRepository.lastVolumeDirection, 'up');

    final searchRes = await controller.tryHandleNaturalCommand(
      'web search OPPO Reno 16',
    );
    expect(searchRes?.success, isTrue);
    expect(automationRepository.lastSearchQuery, 'OPPO Reno 16');

    final navRes = await controller.tryHandleNaturalCommand(
      'navigate to Surat Railway Station',
    );
    expect(navRes?.success, isTrue);
    expect(
      automationRepository.lastNavigationDestination,
      'Surat Railway Station',
    );
  });

  testWidgets(
    'AssistantHomeScreen displays confirmation card for voice-triggered direct calls',
    (WidgetTester tester) async {
      final container = createTestContainer();
      addTearDown(container.dispose);

      await container
          .read(settingsControllerProvider.notifier)
          .setDirectPhoneCallsEnabled(enabled: true);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const VisionApp(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pump(const Duration(milliseconds: 600));

      await container
          .read(automationControllerProvider.notifier)
          .tryHandleNaturalCommand('call +91 9876543210');
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Confirm Device Action'), findsOneWidget);
      expect(find.text('Confirm'), findsOneWidget);
    },
  );

  test('VoiceController handles microphone permission denied without showing active mic indicator and processes Gujarati commands', () async {
    final container = createTestContainer();
    addTearDown(container.dispose);

    // 1. Microphone permission denied
    voiceRepository.permissionGranted = false;
    final voiceNotifier = container.read(voiceControllerProvider.notifier);
    await voiceNotifier.startCommandListening();

    final deniedState = container.read(voiceControllerProvider);
    expect(deniedState.phase, VoiceListeningPhase.error);
    expect(deniedState.isListening, isFalse);
    expect(deniedState.isMicActuallyActive, isFalse);
    expect(deniedState.errorMessage, contains('Microphone permission'));

    // 2. Gujarati voice command execution
    voiceRepository.permissionGranted = true;
    await container
        .read(settingsControllerProvider.notifier)
        .setVoiceLanguage(VoiceLanguage.gujarati);
    await voiceNotifier.startCommandListening();
    voiceRepository.eventController.add(
      const VoiceTranscriptEvent(text: 'ફ્લેશલાઇટ ચાલુ કરો', isFinal: true),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(automationRepository.lastFlashlightState, isTrue);
    expect(voiceRepository.lastSpokenLanguage, VoiceLanguage.gujarati);
  });

  test('AutomationController enforces notification consent & WhatsApp contact resolution', () async {
    final container = createTestContainer();
    addTearDown(container.dispose);
    final controller = container.read(automationControllerProvider.notifier);

    // Notifications blocked without explicit consent
    final blockedNotif = await controller.tryHandleNaturalCommand(
      'read my notifications',
    );
    expect(blockedNotif?.success, isFalse);
    expect(blockedNotif?.status, DeviceActionStatus.confirmationRequired);

    // With consent + permission -> reads notifications locally
    await container
        .read(settingsControllerProvider.notifier)
        .setNotificationListenerConsent(consented: true);
    final okNotif = await controller.tryHandleNaturalCommand(
      'read my notifications',
    );
    expect(okNotif?.success, isTrue);
    expect(okNotif?.notifications.length, 1);

    // WhatsApp requires confirmation under tiered trusted-commands policy, then executes on confirm
    final waPrompt = await controller.tryHandleNaturalCommand(
      'whatsapp Mom saying Good evening',
    );
    expect(waPrompt?.status, DeviceActionStatus.confirmationRequired);
    expect(waPrompt?.actionType, DeviceActionType.sendWhatsapp);

    final waRes = await controller.confirmPendingAction();
    expect(waRes?.success, isTrue);
    expect(waRes?.actionType, DeviceActionType.sendWhatsapp);
  });

  test('VoiceController handles microphone permission denied without showing active mic indicator and processes Gujarati commands', () async {
    final container = createTestContainer();
    addTearDown(container.dispose);

    // 1. Microphone permission denied
    voiceRepository.permissionGranted = false;
    final voiceNotifier = container.read(voiceControllerProvider.notifier);
    await voiceNotifier.startCommandListening();

    final deniedState = container.read(voiceControllerProvider);
    expect(deniedState.phase, VoiceListeningPhase.error);
    expect(deniedState.isListening, isFalse);
    expect(deniedState.isMicActuallyActive, isFalse);
    expect(deniedState.errorMessage, contains('Microphone permission'));

    // 2. Gujarati voice command execution
    voiceRepository.permissionGranted = true;
    await container
        .read(settingsControllerProvider.notifier)
        .setVoiceLanguage(VoiceLanguage.gujarati);
    await voiceNotifier.startCommandListening();
    voiceRepository.eventController.add(
      const VoiceTranscriptEvent(text: 'ફ્લેશલાઇટ ચાલુ કરો', isFinal: true),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(automationRepository.lastFlashlightState, isTrue);
    expect(voiceRepository.lastSpokenLanguage, VoiceLanguage.gujarati);
  });

  test('AutomationController enforces notification consent & WhatsApp contact resolution', () async {
    final container = createTestContainer();
    addTearDown(container.dispose);
    final controller = container.read(automationControllerProvider.notifier);

    // Notifications blocked without explicit consent
    final blockedNotif = await controller.tryHandleNaturalCommand(
      'read my notifications',
    );
    expect(blockedNotif?.success, isFalse);
    expect(blockedNotif?.status, DeviceActionStatus.confirmationRequired);

    // With consent + permission -> reads notifications locally
    await container
        .read(settingsControllerProvider.notifier)
        .setNotificationListenerConsent(consented: true);
    final okNotif = await controller.tryHandleNaturalCommand(
      'read my notifications',
    );
    expect(okNotif?.success, isTrue);
    expect(okNotif?.notifications.length, 1);

    // WhatsApp requires confirmation under tiered trusted-commands policy, then executes on confirm
    final waPrompt = await controller.tryHandleNaturalCommand(
      'whatsapp Mom saying Good evening',
    );
    expect(waPrompt?.status, DeviceActionStatus.confirmationRequired);
    expect(waPrompt?.actionType, DeviceActionType.sendWhatsapp);

    final waRes = await controller.confirmPendingAction();
    expect(waRes?.success, isTrue);
    expect(waRes?.actionType, DeviceActionType.sendWhatsapp);
  });
}
