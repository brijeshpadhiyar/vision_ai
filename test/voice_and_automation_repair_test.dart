import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vision_ai/core/intelligence/command_normalizer.dart';
import 'package:vision_ai/core/intelligence/conversation_context.dart';
import 'package:vision_ai/core/intelligence/intent_engine.dart';
import 'package:vision_ai/core/utils/secure_storage_provider.dart';
import 'package:vision_ai/core/utils/shared_preferences_provider.dart';
import 'package:vision_ai/features/assistant/presentation/screens/assistant_experience_screen.dart';
import 'package:vision_ai/features/automation/data/repositories/device_automation_repository_impl.dart';
import 'package:vision_ai/features/automation/domain/entities/device_action.dart';
import 'package:vision_ai/features/automation/domain/repositories/device_automation_repository.dart';
import 'package:vision_ai/features/automation/presentation/controllers/automation_controller.dart';
import 'package:vision_ai/features/automation/presentation/widgets/automation_action_prompt_card.dart';
import 'package:vision_ai/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:vision_ai/features/chat/domain/entities/ai_completion_request.dart';
import 'package:vision_ai/features/chat/domain/repositories/ai_provider_client.dart';
import 'package:vision_ai/features/settings/domain/entities/ai_provider_type.dart';
import 'package:vision_ai/features/settings/domain/entities/voice_language.dart';
import 'package:vision_ai/features/settings/presentation/controllers/settings_controller.dart';
import 'package:vision_ai/features/voice/data/repositories/voice_repository_impl.dart';
import 'package:vision_ai/features/voice/domain/entities/voice_session_state.dart';
import 'package:vision_ai/features/voice/domain/repositories/voice_repository.dart';
import 'package:vision_ai/features/voice/presentation/controllers/voice_controller.dart';

class _RepairCredentialStore extends SecureCredentialStore {
  _RepairCredentialStore() : super(const FlutterSecureStorage());
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

class _RepairAiClient implements AiProviderClient {
  const _RepairAiClient(this.providerType);

  @override
  final AiProviderType providerType;

  @override
  Future<String> generateReply({
    required AiCompletionRequest request,
    required String apiKey,
  }) async => 'Stub AI reply.';
}

class _RepairVoiceRepository implements VoiceRepository {
  final StreamController<VoiceEvent> controller =
      StreamController<VoiceEvent>.broadcast();

  int? lastEndpointSilenceMs;
  bool stopCalled = false;
  bool cancelCalled = false;

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
  }) async {
    lastEndpointSilenceMs = endpointSilenceMs;
  }

  @override
  Future<void> stopListening() async {
    stopCalled = true;
  }

  @override
  Future<void> cancelListening() async {
    cancelCalled = true;
  }

  @override
  Future<bool> speak({
    required String text,
    required VoiceLanguage language,
    double speechRate = 1.0,
  }) async => true;

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

class _RepairAutomationRepository implements DeviceAutomationRepository {
  List<ContactMatch> contacts = const <ContactMatch>[
    ContactMatch(
      contactId: 'c_soel',
      name: 'Soel Kht',
      phoneNumber: '+919825010101',
      label: 'Mobile',
    ),
    ContactMatch(
      contactId: 'c_tisha',
      name: 'Tisha Patel',
      phoneNumber: '+919825099999',
      label: 'Mobile',
    ),
    ContactMatch(
      contactId: 'c_mom',
      name: 'Mom',
      phoneNumber: '+919876543210',
      label: 'Home',
    ),
  ];

  String? lastCalledNumber;
  int? lastAlarmHour;
  int? lastAlarmMinute;
  bool? lastAlarmTomorrow;
  bool? lastFlashlightState;

  @override
  Future<bool> checkPermission(AutomationPermission permission) async => true;

  @override
  Future<bool> requestPermission(AutomationPermission permission) async => true;

  @override
  Future<List<ContactMatch>> lookupContacts(String query) async {
    final lower = query.toLowerCase();
    return contacts
        .where(
          (c) =>
              c.name.toLowerCase().contains(lower) ||
              c.phoneNumber.contains(query),
        )
        .toList(growable: false);
  }

  @override
  Future<List<ContactMatch>> getAllContacts() async => contacts;

  @override
  Future<DeviceActionResult> makePhoneCall({
    required String phoneNumber,
    bool directCall = false,
  }) async {
    lastCalledNumber = phoneNumber;
    return DeviceActionResult(
      success: true,
      actionType: DeviceActionType.callPhone,
      summary: 'Dialed $phoneNumber',
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
    lastAlarmTomorrow = isTomorrow;
    return DeviceActionResult(
      success: true,
      actionType: DeviceActionType.setAlarm,
      summary:
          'Alarm set for ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}${isTomorrow ? ' (tomorrow)' : ''}',
    );
  }

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
    summary: 'Dismissed.',
  );

  @override
  Future<DeviceActionResult> dismissTimer() async => const DeviceActionResult(
    success: true,
    actionType: DeviceActionType.dismissTimer,
    summary: 'Dismissed.',
  );

  @override
  Future<List<InstalledAppInfo>> getInstalledApps() async =>
      const <InstalledAppInfo>[];

  @override
  Future<DeviceActionResult> launchApp(String appNameOrPackage) async =>
      DeviceActionResult(
        success: true,
        actionType: DeviceActionType.launchApp,
        summary: 'Opened $appNameOrPackage',
      );

  @override
  Future<DeviceActionResult> openSystemSettings(String section) async =>
      DeviceActionResult(
        success: true,
        actionType: DeviceActionType.openSettings,
        summary: 'Opened $section settings',
      );

  @override
  Future<DeviceActionResult> sendSms({
    required String phoneNumber,
    String? message,
  }) async => const DeviceActionResult(
    success: true,
    actionType: DeviceActionType.sendSms,
    summary: 'SMS opened',
  );

  @override
  Future<DeviceActionResult> sendWhatsApp({
    String? phoneNumber,
    String? message,
  }) async => const DeviceActionResult(
    success: true,
    actionType: DeviceActionType.sendWhatsapp,
    summary: 'WhatsApp opened',
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
        summary: 'Opened URL',
      );

  @override
  Future<DeviceActionResult> setFlashlight({required bool enabled}) async {
    lastFlashlightState = enabled;
    return DeviceActionResult(
      success: true,
      actionType: DeviceActionType.toggleFlashlight,
      summary: enabled ? 'Flashlight ON' : 'Flashlight OFF',
    );
  }

  @override
  Future<DeviceActionResult> setRingerMode(String mode) async =>
      const DeviceActionResult(
        success: true,
        actionType: DeviceActionType.setRingerMode,
        summary: 'Ringer updated',
      );

  @override
  Future<DeviceActionResult> adjustVolume(String direction) async =>
      const DeviceActionResult(
        success: true,
        actionType: DeviceActionType.adjustVolume,
        summary: 'Volume adjusted',
      );

  @override
  Future<DeviceActionResult> webSearch(String query) async =>
      const DeviceActionResult(
        success: true,
        actionType: DeviceActionType.webSearch,
        summary: 'Searched',
      );

  @override
  Future<DeviceActionResult> navigateTo(String destination) async =>
      const DeviceActionResult(
        success: true,
        actionType: DeviceActionType.navigateTo,
        summary: 'Navigating',
      );

  @override
  Future<DeviceStatusSnapshot> getDeviceStatus() async =>
      const DeviceStatusSnapshot(
        manufacturer: 'OPPO',
        model: 'Reno 16',
        androidVersion: '16',
        sdkInt: 36,
        batteryLevel: 85,
        isCharging: false,
        networkType: 'Wi-Fi',
        ringerMode: 'normal',
        isColorOs: true,
      );
}

void main() {
  late SharedPreferences prefs;
  late _RepairCredentialStore credStore;
  late _RepairVoiceRepository voiceRepo;
  late _RepairAutomationRepository autoRepo;

  ProviderContainer makeContainer() {
    return ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        secureCredentialStoreProvider.overrideWithValue(credStore),
        voiceRepositoryProvider.overrideWithValue(voiceRepo),
        deviceAutomationRepositoryProvider.overrideWithValue(autoRepo),
        aiProviderClientsProvider.overrideWithValue({
          AiProviderType.gemini: const _RepairAiClient(AiProviderType.gemini),
          AiProviderType.openAi: const _RepairAiClient(AiProviderType.openAi),
          AiProviderType.claude: const _RepairAiClient(AiProviderType.claude),
        }),
      ],
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
    credStore = _RepairCredentialStore();
    voiceRepo = _RepairVoiceRepository();
    autoRepo = _RepairAutomationRepository();
  });

  tearDown(() {
    voiceRepo.dispose();
  });

  test(
    'Priority 1: Voice state machine maps phases, forwards configurable pause silence, and supports Done/Cancel',
    () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      // Update pause tolerance setting (clamped 2000..6500ms)
      await container
          .read(settingsControllerProvider.notifier)
          .setVoiceEndpointSilenceMs(4500);
      expect(
        container.read(settingsControllerProvider).voiceEndpointSilenceMs,
        4500,
      );

      final voiceNotifier = container.read(voiceControllerProvider.notifier);
      await voiceNotifier.startCommandListening();
      expect(voiceRepo.lastEndpointSilenceMs, 4500);
      expect(
        container.read(voiceControllerProvider).phase,
        VoiceListeningPhase.listeningCommand,
      );

      // Emit multi-segment partial + endpointing transitions
      voiceRepo.controller.add(
        const VoiceTranscriptEvent(
          text: 'Hey VISION please call',
          isFinal: false,
          segmentCount: 1,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      var vs = container.read(voiceControllerProvider);
      expect(vs.phase, VoiceListeningPhase.partialTranscription);
      expect(vs.segmentCount, 1);

      voiceRepo.controller.add(
        const VoiceStateChangedEvent(
          isListening: true,
          isSpeaking: false,
          phase: 'endpointing',
          segmentCount: 1,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      vs = container.read(voiceControllerProvider);
      expect(vs.phase, VoiceListeningPhase.endpointing);

      // User continues speaking second segment after pause
      voiceRepo.controller.add(
        const VoiceTranscriptEvent(
          text: 'Hey VISION please call Soel Kht',
          isFinal: false,
          segmentCount: 2,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(container.read(voiceControllerProvider).segmentCount, 2);

      // Manual Done triggers finalizing + stopListening
      await voiceNotifier.finishListening();
      expect(voiceRepo.stopCalled, isTrue);
      expect(
        container.read(voiceControllerProvider).phase,
        VoiceListeningPhase.finalizing,
      );

      // Cancel transitions cleanly without executing partial text
      await voiceNotifier.startCommandListening();
      voiceRepo.controller.add(
        const VoiceTranscriptEvent(
          text: 'turn flashlight on',
          isFinal: false,
          segmentCount: 1,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await voiceNotifier.cancelListening();
      expect(voiceRepo.cancelCalled, isTrue);
      expect(autoRepo.lastFlashlightState, isNull);
    },
  );

  test(
    'Priority 2 & 4: Pronunciation fixes, indic phrases, hypothesis recovery, clarification follow-up & false-positive guards',
    () {
      expect(CommandNormalizer.normalize('Whats app').canonicalText, 'whatsapp');
      final whatsAppOpen = IntentEngine.analyze('Open Whats app');
      expect(whatsAppOpen.request?.type, DeviceActionType.launchApp);
      expect(whatsAppOpen.request?.target.toLowerCase(), 'whatsapp');
      expect(whatsAppOpen.originalTranscript, 'Open Whats app');

      final waTypo = IntentEngine.analyze('watsapp Mom saying hello');
      expect(waTypo.request?.type, DeviceActionType.sendWhatsapp);
      expect(waTypo.request?.target.toLowerCase(), 'mom');
      expect(waTypo.request?.message?.toLowerCase(), 'hello');

      final calTypo = IntentEngine.analyze('cal Tisha');
      expect(calTypo.request?.type, DeviceActionType.callPhone);
      expect(calTypo.request?.target.toLowerCase(), 'tisha');

      final hindiCall = IntentEngine.analyze('phone lagao Soel');
      expect(hindiCall.request?.type, DeviceActionType.callPhone);
      expect(hindiCall.request?.target.toLowerCase(), 'soel');

      final gujAlarm = IntentEngine.analyze('alarm muk 7 vage');
      expect(gujAlarm.request?.type, DeviceActionType.setAlarm);
      expect(gujAlarm.request?.hour, 7);
      expect(gujAlarm.request?.minute, 0);

      final gujTomorrow = IntentEngine.analyze('kal savare 7 vage');
      expect(gujTomorrow.request?.type, DeviceActionType.setAlarm);
      expect(gujTomorrow.request?.hour, 7);
      expect(gujTomorrow.request?.isTomorrow, isTrue);

      // Multi-hypothesis ASR recovery without altering originalTranscript
      final recovered = IntentEngine.analyzeWithHypotheses(const <String>[
        'all tisha',
        'call Tisha',
      ]);
      expect(recovered.request?.type, DeviceActionType.callPhone);
      expect(recovered.request?.target.toLowerCase(), 'tisha');
      expect(recovered.originalTranscript, 'all tisha');

      // Pending clarification follow-up ("Set alarm" -> "7 AM")
      final clarify = IntentEngine.analyze('Set alarm');
      expect(clarify.needsClarification, isTrue);
      final followUp = IntentEngine.analyze(
        '7 AM',
        context: ConversationIntelligenceContext(
          pendingClarificationIntentId: clarify.intentId,
          pendingClarificationPrompt: clarify.clarificationPrompt,
        ),
      );
      expect(followUp.request?.type, DeviceActionType.setAlarm);
      expect(followUp.request?.hour, 7);
      expect(followUp.request?.minute, 0);

      // Informational questions must go to AI (general_query), never trigger device actions
      for (final query in const <String>[
        'what is whatsapp',
        'my phone is slow',
        'Explain Flutter Riverpod',
        'how long is a marathon',
      ]) {
        final qRes = IntentEngine.analyze(query);
        expect(
          qRes.shouldHandleLocally,
          isFalse,
          reason: 'Expected general_query for "$query", got ${qRes.intentId}',
        );
      }
    },
  );

  test(
    'Priority 3 & 6: Phonetic cancel via "No", multi-step confirmation preserves followUpActions, and isTomorrow propagates',
    () async {
      final container = makeContainer();
      addTearDown(container.dispose);
      final auto = container.read(automationControllerProvider.notifier);

      // 1. Uncertain contact confirmation cancelled cleanly by natural "No"
      final firstCall = await auto.tryHandleNaturalCommand('Call Shohil Jht');
      expect(firstCall?.status, DeviceActionStatus.confirmationRequired);
      expect(firstCall?.summary, 'Did you mean Soel Kht?');

      final noIntent = IntentEngine.analyze(
        'No',
        context: ConversationIntelligenceContext(
          pendingAction: container
              .read(automationControllerProvider)
              .pendingConfirmation,
        ),
      );
      expect(noIntent.request?.type, DeviceActionType.cancelAction);
      final cancelled = await auto.executeRequest(noIntent.request!);
      expect(cancelled.success, isTrue);
      expect(autoRepo.lastCalledNumber, isNull);
      expect(
        container.read(automationControllerProvider).pendingConfirmation,
        isNull,
      );

      // 2. Multi-step command holds Step 1 for confirmation & executes Step 2 after confirm
      await container
          .read(settingsControllerProvider.notifier)
          .setDirectPhoneCallsEnabled(enabled: true);
      final multiStep = await auto.tryHandleNaturalCommand(
        'Call Tisha Patel and then turn flashlight on',
      );
      expect(multiStep?.status, DeviceActionStatus.confirmationRequired);
      expect(autoRepo.lastFlashlightState, isNull);

      final done = await auto.confirmPendingAction();
      expect(done?.success, isTrue);
      expect(autoRepo.lastCalledNumber, '+919825099999');
      expect(autoRepo.lastFlashlightState, isTrue);

      // 3. "kal savare 7 vage" propagates isTomorrow = true to native repository
      final alarmRes = await auto.tryHandleNaturalCommand('kal savare 7 vage');
      expect(alarmRes?.success, isTrue);
      expect(autoRepo.lastAlarmHour, 7);
      expect(autoRepo.lastAlarmMinute, 0);
      expect(autoRepo.lastAlarmTomorrow, isTrue);
    },
  );

  testWidgets(
    'UI: AutomationActionPromptCard hides duplicate Confirm button on alias suggestion & AssistantExperienceScreen shows endpointing controls',
    (WidgetTester tester) async {
      final container = makeContainer();
      addTearDown(container.dispose);

      const suggestedState = AutomationState(
        pendingConfirmation: DeviceActionRequest(
          type: DeviceActionType.callPhone,
          target: '+919825010101',
          requiresConfirmation: true,
          displaySummary: 'Call Soel Kht (+919825010101)',
        ),
        suggestedContact: ContactMatch(
          contactId: 'c_soel',
          name: 'Soel Kht',
          phoneNumber: '+919825010101',
          label: 'Mobile',
        ),
        suggestSaveAlias: true,
        spokenContactQuery: 'Shohil Jht',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AutomationActionPromptCard(
              automationState: suggestedState,
              compact: true,
              onConfirm: () {},
              onConfirmAndSaveAlias: () {},
              onCancel: () {},
              onSelectContact: (_) {},
              onGrantPermission: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Did you mean Soel Kht?'), findsOneWidget);
      expect(find.text('Yes, Confirm'), findsOneWidget);
      expect(find.text('Yes & Save Alias'), findsOneWidget);
      // Duplicate generic Confirm button must NOT be rendered!
      expect(find.text('Confirm'), findsNothing);
      expect(find.text('Confirm & Execute'), findsNothing);

      // Now test AssistantExperienceScreen endpointing UI + Done button
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: AssistantExperienceScreen()),
        ),
      );
      await tester.pump();

      await container
          .read(voiceControllerProvider.notifier)
          .startCommandListening();
      voiceRepo.controller.add(
        const VoiceTranscriptEvent(
          text: 'Hey VISION call',
          isFinal: false,
          segmentCount: 1,
        ),
      );
      voiceRepo.controller.add(
        const VoiceStateChangedEvent(
          isListening: true,
          isSpeaking: false,
          phase: 'endpointing',
          segmentCount: 1,
        ),
      );
      await tester.pump();

      expect(find.text('Pause detected — listening...'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    },
  );
}
