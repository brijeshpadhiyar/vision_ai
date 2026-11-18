import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vision_ai/core/intelligence/confidence_manager.dart';
import 'package:vision_ai/core/intelligence/conversation_context.dart';
import 'package:vision_ai/core/intelligence/intent_engine.dart';
import 'package:vision_ai/core/telemetry/performance_telemetry.dart';
import 'package:vision_ai/core/utils/shared_preferences_provider.dart';
import 'package:vision_ai/features/automation/data/repositories/device_automation_repository_impl.dart';
import 'package:vision_ai/features/automation/domain/entities/device_action.dart';
import 'package:vision_ai/features/automation/domain/repositories/device_automation_repository.dart';
import 'package:vision_ai/features/automation/domain/utils/device_intent_parser.dart';
import 'package:vision_ai/features/automation/presentation/controllers/automation_controller.dart';
import 'package:vision_ai/features/chat/domain/entities/ai_completion_request.dart';
import 'package:vision_ai/features/chat/domain/entities/ai_model_config.dart';
import 'package:vision_ai/features/chat/domain/entities/ai_models.dart';
import 'package:vision_ai/features/chat/domain/entities/chat_message.dart';
import 'package:vision_ai/features/chat/domain/services/ai_conversation_manager.dart';
import 'package:vision_ai/features/chat/domain/services/provider_fallback_manager.dart';
import 'package:vision_ai/features/chat/domain/services/provider_health_manager.dart';
import 'package:vision_ai/features/chat/domain/services/task_complexity_classifier.dart';
import 'package:vision_ai/features/memory/domain/entities/memory_entry.dart';
import 'package:vision_ai/features/memory/presentation/controllers/memory_controller.dart';
import 'package:vision_ai/features/settings/domain/entities/ai_provider_type.dart';
import 'package:vision_ai/features/settings/domain/entities/voice_language.dart';

class _BenchCase {
  const _BenchCase(
    this.utterance, {
    this.expectedType,
    this.expectGeneralQuery = false,
    this.expectClarification = false,
    this.expectedTargetContains,
    this.expectedHour,
    this.expectedMinute,
    this.expectedSeconds,
    this.expectedEnabled,
    this.expectedOrdinal,
    this.expectedTomorrow,
    this.minSteps = 1,
  });

  final String utterance;
  final DeviceActionType? expectedType;
  final bool expectGeneralQuery;
  final bool expectClarification;
  final String? expectedTargetContains;
  final int? expectedHour;
  final int? expectedMinute;
  final int? expectedSeconds;
  final bool? expectedEnabled;
  final int? expectedOrdinal;
  final bool? expectedTomorrow;
  final int minSteps;
}

class _BenchmarkAutomationRepository implements DeviceAutomationRepository {
  bool failLaunchApp = false;
  String? lastCalledNumber;
  bool lastDirectCall = false;

  @override
  Future<bool> checkPermission(AutomationPermission permission) async => true;

  @override
  Future<bool> requestPermission(AutomationPermission permission) async => true;

  @override
  Future<List<ContactMatch>> lookupContacts(String query) async {
    final lower = query.toLowerCase();
    if (lower.contains('tisha')) {
      return const <ContactMatch>[
        ContactMatch(
          contactId: 'c_tisha_1',
          name: 'Tisha',
          phoneNumber: '+919825011111',
          label: 'Mobile',
        ),
        ContactMatch(
          contactId: 'c_tisha_2',
          name: 'Tisha Work',
          phoneNumber: '+919825022222',
          label: 'Work',
        ),
      ];
    }
    return const <ContactMatch>[];
  }

  @override
  Future<List<ContactMatch>> getAllContacts() async => const <ContactMatch>[
    ContactMatch(
      contactId: 'c_tisha_1',
      name: 'Tisha',
      phoneNumber: '+919825011111',
      label: 'Mobile',
    ),
    ContactMatch(
      contactId: 'c_tisha_2',
      name: 'Tisha Work',
      phoneNumber: '+919825022222',
      label: 'Work',
    ),
    ContactMatch(
      contactId: 'c_soel_kht',
      name: 'Soel Kht',
      phoneNumber: '+919825099999',
      label: 'Mobile',
    ),
  ];

  @override
  Future<DeviceActionResult> makePhoneCall({
    required String phoneNumber,
    bool directCall = false,
  }) async {
    lastCalledNumber = phoneNumber;
    lastDirectCall = directCall;
    return DeviceActionResult(
      success: true,
      actionType: DeviceActionType.callPhone,
      summary: 'Dialing $phoneNumber',
    );
  }

  @override
  Future<DeviceActionResult> setAlarm({
    required int hour,
    required int minute,
    String? label,
    bool skipUi = false,
  }) async => DeviceActionResult(
    success: true,
    actionType: DeviceActionType.setAlarm,
    summary: 'Alarm $hour:$minute',
  );

  @override
  Future<DeviceActionResult> setTimer({
    required int seconds,
    String? label,
    bool skipUi = false,
  }) async => DeviceActionResult(
    success: true,
    actionType: DeviceActionType.setTimer,
    summary: 'Timer ${seconds}s',
  );

  @override
  Future<DeviceActionResult> dismissAlarm() async => const DeviceActionResult(
    success: true,
    actionType: DeviceActionType.dismissAlarm,
    summary: 'Dismissed alarms UI',
  );

  @override
  Future<DeviceActionResult> dismissTimer() async => const DeviceActionResult(
    success: true,
    actionType: DeviceActionType.dismissTimer,
    summary: 'Dismissed timers UI',
  );

  @override
  Future<List<InstalledAppInfo>> getInstalledApps() async =>
      const <InstalledAppInfo>[];

  @override
  Future<DeviceActionResult> launchApp(String appNameOrPackage) async {
    if (failLaunchApp) {
      return DeviceActionResult(
        success: false,
        actionType: DeviceActionType.launchApp,
        summary: 'Could not find "$appNameOrPackage"',
      );
    }
    return DeviceActionResult(
      success: true,
      actionType: DeviceActionType.launchApp,
      summary: 'Opened $appNameOrPackage',
    );
  }

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
    summary: 'SMS drafted',
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
  Future<DeviceActionResult> openUrl(String url) async => DeviceActionResult(
    success: true,
    actionType: DeviceActionType.openUrl,
    summary: 'Opened $url',
  );

  @override
  Future<DeviceActionResult> setFlashlight({required bool enabled}) async =>
      DeviceActionResult(
        success: true,
        actionType: DeviceActionType.toggleFlashlight,
        summary: enabled ? 'Torch ON' : 'Torch OFF',
      );

  @override
  Future<DeviceActionResult> setRingerMode(String mode) async =>
      DeviceActionResult(
        success: true,
        actionType: DeviceActionType.setRingerMode,
        summary: 'Mode $mode',
      );

  @override
  Future<DeviceActionResult> adjustVolume(String direction) async =>
      DeviceActionResult(
        success: true,
        actionType: DeviceActionType.adjustVolume,
        summary: 'Volume $direction',
      );

  @override
  Future<DeviceActionResult> webSearch(String query) async =>
      DeviceActionResult(
        success: true,
        actionType: DeviceActionType.webSearch,
        summary: 'Searched $query',
      );

  @override
  Future<DeviceActionResult> navigateTo(String destination) async =>
      DeviceActionResult(
        success: true,
        actionType: DeviceActionType.navigateTo,
        summary: 'Navigating to $destination',
      );

  @override
  Future<DeviceStatusSnapshot> getDeviceStatus() async =>
      const DeviceStatusSnapshot(
        manufacturer: 'OPPO',
        model: 'Reno 16',
        androidVersion: '16',
        sdkInt: 36,
        batteryLevel: 88,
        isCharging: false,
        networkType: 'Wi-Fi',
        ringerMode: 'normal',
        isColorOs: true,
        isFlashlightOn: false,
        isDefaultAssistant: true,
        isIgnoringBatteryOptimizations: true,
        canScheduleExactAlarms: true,
      );
}

void main() {
  void runLanguageSuite(String label, List<_BenchCase> cases) {
    test('$label benchmark (>=30 commands)', () {
      expect(cases.length, greaterThanOrEqualTo(30));

      var passed = 0;
      var falseActions = 0;
      var clarificationsExpected = 0;
      var clarificationsMatched = 0;
      var totalMicros = 0;

      for (final testCase in cases) {
        final res = IntentEngine.analyze(testCase.utterance);
        totalMicros += res.parseTimeMicros;

        if (testCase.expectGeneralQuery) {
          if (res.disposition == ConfidenceDisposition.delegateToAi &&
              res.request == null) {
            passed++;
          } else {
            falseActions++;
            fail(
              '[$label] General query "${testCase.utterance}" misclassified as '
              '${res.intentId} (disposition=${res.disposition}, clarify=${res.clarificationPrompt})',
            );
          }
          continue;
        }

        if (testCase.expectClarification) {
          clarificationsExpected++;
          if (res.needsClarification &&
              res.clarificationPrompt != null &&
              res.intentId == testCase.expectedType?.wireId) {
            clarificationsMatched++;
            passed++;
          }
          continue;
        }

        var ok =
            res.shouldHandleLocally &&
            res.request?.type == testCase.expectedType &&
            res.steps.length >= testCase.minSteps;

        if (ok && testCase.expectedTargetContains != null) {
          ok = (res.request?.target.toLowerCase() ?? '').contains(
            testCase.expectedTargetContains!.toLowerCase(),
          );
        }
        if (ok && testCase.expectedHour != null) {
          ok = res.request?.hour == testCase.expectedHour;
        }
        if (ok && testCase.expectedMinute != null) {
          ok = res.request?.minute == testCase.expectedMinute;
        }
        if (ok && testCase.expectedSeconds != null) {
          ok = res.request?.durationSeconds == testCase.expectedSeconds;
        }
        if (ok && testCase.expectedEnabled != null) {
          ok = res.request?.enabled == testCase.expectedEnabled;
        }
        if (ok && testCase.expectedOrdinal != null) {
          ok = res.request?.contactOrdinalIndex == testCase.expectedOrdinal;
        }
        if (ok && testCase.expectedTomorrow != null) {
          ok = res.request?.isTomorrow == testCase.expectedTomorrow;
        }

        if (!ok) {
          fail(
            '[$label] Failed on "${testCase.utterance}": '
            'got intent=${res.intentId}, type=${res.request?.type}, '
            'target="${res.request?.target}", hour=${res.request?.hour}, '
            'min=${res.request?.minute}, sec=${res.request?.durationSeconds}, '
            'steps=${res.steps.length}, clarify=${res.clarificationPrompt}',
          );
        } else {
          passed++;
        }
      }

      final avgMicros = totalMicros / cases.length;
      expect(passed, cases.length);
      expect(falseActions, 0);
      expect(clarificationsMatched, clarificationsExpected);
      expect(avgMicros, lessThan(5000));
    });
  }

  runLanguageSuite('English (32 commands)', const <_BenchCase>[
    _BenchCase(
      'Call Tisha.',
      expectedType: DeviceActionType.callPhone,
      expectedTargetContains: 'tisha',
    ),
    _BenchCase(
      'Call the first number of Tisha',
      expectedType: DeviceActionType.callPhone,
      expectedTargetContains: 'tisha',
      expectedOrdinal: 0,
    ),
    _BenchCase(
      'Dial the second number for Rahul',
      expectedType: DeviceActionType.callPhone,
      expectedTargetContains: 'rahul',
      expectedOrdinal: 1,
    ),
    _BenchCase(
      'Find contact Priya',
      expectedType: DeviceActionType.lookupContacts,
      expectedTargetContains: 'priya',
    ),
    _BenchCase(
      'Search contacts for Aarav',
      expectedType: DeviceActionType.lookupContacts,
      expectedTargetContains: 'aarav',
    ),
    _BenchCase(
      'Set an alarm for seven tomorrow.',
      expectedType: DeviceActionType.setAlarm,
      expectedHour: 7,
      expectedMinute: 0,
      expectedTomorrow: true,
    ),
    _BenchCase(
      'Set an alarm for 6:30 PM called Gym',
      expectedType: DeviceActionType.setAlarm,
      expectedHour: 18,
      expectedMinute: 30,
    ),
    _BenchCase(
      'Wake me up with an alarm at half past six morning',
      expectedType: DeviceActionType.setAlarm,
      expectedHour: 6,
      expectedMinute: 30,
    ),
    _BenchCase('Cancel my alarm', expectedType: DeviceActionType.dismissAlarm),
    _BenchCase(
      'Start a timer for five minutes',
      expectedType: DeviceActionType.setTimer,
      expectedSeconds: 300,
    ),
    _BenchCase(
      'Set a timer for half a minute',
      expectedType: DeviceActionType.setTimer,
      expectedSeconds: 30,
    ),
    _BenchCase('Stop timer', expectedType: DeviceActionType.dismissTimer),
    _BenchCase(
      'Open my WhatsApp.',
      expectedType: DeviceActionType.launchApp,
      expectedTargetContains: 'whatsapp',
    ),
    _BenchCase(
      'Launch YouTube',
      expectedType: DeviceActionType.launchApp,
      expectedTargetContains: 'youtube',
    ),
    _BenchCase(
      'Open Wi-Fi settings',
      expectedType: DeviceActionType.openSettings,
      expectedTargetContains: 'wifi',
    ),
    _BenchCase(
      'Open Bluetooth settings',
      expectedType: DeviceActionType.openSettings,
      expectedTargetContains: 'bluetooth',
    ),
    _BenchCase(
      'Turn on flashlight',
      expectedType: DeviceActionType.toggleFlashlight,
      expectedEnabled: true,
    ),
    _BenchCase(
      'Turn off torch',
      expectedType: DeviceActionType.toggleFlashlight,
      expectedEnabled: false,
    ),
    _BenchCase(
      'Put phone on silent mode',
      expectedType: DeviceActionType.setRingerMode,
      expectedTargetContains: 'silent',
    ),
    _BenchCase(
      'Switch phone to vibrate mode',
      expectedType: DeviceActionType.setRingerMode,
      expectedTargetContains: 'vibrate',
    ),
    _BenchCase(
      'Increase volume',
      expectedType: DeviceActionType.adjustVolume,
      expectedTargetContains: 'up',
    ),
    _BenchCase(
      'Lower volume',
      expectedType: DeviceActionType.adjustVolume,
      expectedTargetContains: 'down',
    ),
    _BenchCase(
      'Check battery status',
      expectedType: DeviceActionType.deviceStatus,
    ),
    _BenchCase(
      'Read my recent notifications',
      expectedType: DeviceActionType.readNotifications,
    ),
    _BenchCase(
      'Send SMS to Mom saying Reaching home',
      expectedType: DeviceActionType.sendSms,
      expectedTargetContains: 'mom',
    ),
    _BenchCase(
      'Send WhatsApp to Tisha saying Hello there',
      expectedType: DeviceActionType.sendWhatsapp,
      expectedTargetContains: 'tisha',
    ),
    _BenchCase(
      'Navigate to Ahmedabad Airport',
      expectedType: DeviceActionType.navigateTo,
      expectedTargetContains: 'ahmedabad',
    ),
    _BenchCase(
      'Search Google for Flutter 3.50',
      expectedType: DeviceActionType.webSearch,
      expectedTargetContains: 'flutter',
    ),
    _BenchCase(
      'Open https://flutter.dev',
      expectedType: DeviceActionType.openUrl,
      expectedTargetContains: 'flutter.dev',
    ),
    _BenchCase('Stop speaking', expectedType: DeviceActionType.stopSpeaking),
    _BenchCase('Repeat that', expectedType: DeviceActionType.repeatLast),
    _BenchCase(
      'Cancel pending action',
      expectedType: DeviceActionType.cancelAction,
    ),
    _BenchCase(
      'Open WhatsApp and find Tisha',
      expectedType: DeviceActionType.launchApp,
      minSteps: 2,
    ),
    _BenchCase(
      'Set an alarm',
      expectedType: DeviceActionType.setAlarm,
      expectClarification: true,
    ),
    _BenchCase(
      'Call',
      expectedType: DeviceActionType.callPhone,
      expectClarification: true,
    ),
    _BenchCase(
      'Why is my phone battery draining fast?',
      expectGeneralQuery: true,
    ),
  ]);

  runLanguageSuite('Hindi (30 commands)', const <_BenchCase>[
    _BenchCase(
      'मम्मी को कॉल करो',
      expectedType: DeviceActionType.callPhone,
      expectedTargetContains: 'मम्मी',
    ),
    _BenchCase(
      'तिषा को फोन लगाओ',
      expectedType: DeviceActionType.callPhone,
      expectedTargetContains: 'तिषा',
    ),
    _BenchCase(
      'राहुल का नंबर ढूंढो',
      expectedType: DeviceActionType.lookupContacts,
      expectedTargetContains: 'राहुल',
    ),
    _BenchCase(
      'कल सुबह 7 बजे अलार्म लगाओ',
      expectedType: DeviceActionType.setAlarm,
      expectedHour: 7,
      expectedMinute: 0,
      expectedTomorrow: true,
    ),
    _BenchCase(
      'शाम 6:30 बजे का अलार्म',
      expectedType: DeviceActionType.setAlarm,
      expectedHour: 18,
      expectedMinute: 30,
    ),
    _BenchCase('अलार्म बंद करो', expectedType: DeviceActionType.dismissAlarm),
    _BenchCase(
      '5 मिनट का टाइमर लगाओ',
      expectedType: DeviceActionType.setTimer,
      expectedSeconds: 300,
    ),
    _BenchCase(
      'दस सेकंड का टाइमर',
      expectedType: DeviceActionType.setTimer,
      expectedSeconds: 10,
    ),
    _BenchCase('टाइमर बंद करो', expectedType: DeviceActionType.dismissTimer),
    _BenchCase(
      'व्हाट्सएप खोलो',
      expectedType: DeviceActionType.launchApp,
      expectedTargetContains: 'whatsapp',
    ),
    _BenchCase(
      'यूट्यूब खोलो',
      expectedType: DeviceActionType.launchApp,
      expectedTargetContains: 'youtube',
    ),
    _BenchCase(
      'कैमरा खोलो',
      expectedType: DeviceActionType.launchApp,
      expectedTargetContains: 'camera',
    ),
    _BenchCase(
      'सेटिंग्स खोलो',
      expectedType: DeviceActionType.openSettings,
      expectedTargetContains: 'main',
    ),
    _BenchCase(
      'वाईफाई सेटिंग्स खोलो',
      expectedType: DeviceActionType.openSettings,
      expectedTargetContains: 'wifi',
    ),
    _BenchCase(
      'ब्लूटूथ सेटिंग्स खोलो',
      expectedType: DeviceActionType.openSettings,
      expectedTargetContains: 'bluetooth',
    ),
    _BenchCase(
      'टॉर्च चालू करो',
      expectedType: DeviceActionType.toggleFlashlight,
      expectedEnabled: true,
    ),
    _BenchCase(
      'फ्लैशलाइट बंद करो',
      expectedType: DeviceActionType.toggleFlashlight,
      expectedEnabled: false,
    ),
    _BenchCase(
      'फोन साइलेंट मोड पर रखो',
      expectedType: DeviceActionType.setRingerMode,
      expectedTargetContains: 'silent',
    ),
    _BenchCase(
      'फोन वाइब्रेट मोड पर करो',
      expectedType: DeviceActionType.setRingerMode,
      expectedTargetContains: 'vibrate',
    ),
    _BenchCase(
      'वॉल्यूम बढ़ाओ',
      expectedType: DeviceActionType.adjustVolume,
      expectedTargetContains: 'up',
    ),
    _BenchCase(
      'वॉल्यूम कम करो',
      expectedType: DeviceActionType.adjustVolume,
      expectedTargetContains: 'down',
    ),
    _BenchCase('बैटरी कितनी है', expectedType: DeviceActionType.deviceStatus),
    _BenchCase(
      'नोटिफिकेशन बताओ',
      expectedType: DeviceActionType.readNotifications,
    ),
    _BenchCase(
      'राहुल को व्हाट्सएप करो कि मैं आ गया',
      expectedType: DeviceActionType.sendWhatsapp,
      expectedTargetContains: 'राहुल',
    ),
    _BenchCase(
      'प्रिया को मैसेज भेजो हैलो',
      expectedType: DeviceActionType.sendSms,
      expectedTargetContains: 'प्रिया',
    ),
    _BenchCase(
      'गूगल पर मौसम सर्च करो',
      expectedType: DeviceActionType.webSearch,
    ),
    _BenchCase('चुप रहो', expectedType: DeviceActionType.stopSpeaking),
    _BenchCase('फिर से बोलो', expectedType: DeviceActionType.repeatLast),
    _BenchCase('रद्द करो', expectedType: DeviceActionType.cancelAction),
    _BenchCase('अलार्म कैसे काम करता है', expectGeneralQuery: true),
  ]);

  runLanguageSuite('Gujarati (30 commands)', const <_BenchCase>[
    _BenchCase(
      'મમ્મી ને કૉલ કરો',
      expectedType: DeviceActionType.callPhone,
      expectedTargetContains: 'મમ્મી',
    ),
    _BenchCase(
      'તિષા ને ફોન લગાવો',
      expectedType: DeviceActionType.callPhone,
      expectedTargetContains: 'તિષા',
    ),
    _BenchCase(
      'રાહુલ નો નંબર શોધો',
      expectedType: DeviceActionType.lookupContacts,
      expectedTargetContains: 'રાહુલ',
    ),
    _BenchCase(
      'કાલે સવારે સાત વાગે અલાર્મ મૂકો',
      expectedType: DeviceActionType.setAlarm,
      expectedHour: 7,
      expectedMinute: 0,
      expectedTomorrow: true,
    ),
    _BenchCase(
      'સાંજે 6:30 વાગે અલાર્મ મૂકો',
      expectedType: DeviceActionType.setAlarm,
      expectedHour: 18,
      expectedMinute: 30,
    ),
    _BenchCase('અલાર્મ બંધ કરો', expectedType: DeviceActionType.dismissAlarm),
    _BenchCase(
      'પાંચ મિનિટ નો ટાઇમર',
      expectedType: DeviceActionType.setTimer,
      expectedSeconds: 300,
    ),
    _BenchCase(
      'દસ સેકન્ડ નો ટાઇમર',
      expectedType: DeviceActionType.setTimer,
      expectedSeconds: 10,
    ),
    _BenchCase('ટાઇમર બંધ કરો', expectedType: DeviceActionType.dismissTimer),
    _BenchCase(
      'વોટ્સએપ ખોલો',
      expectedType: DeviceActionType.launchApp,
      expectedTargetContains: 'whatsapp',
    ),
    _BenchCase(
      'યુટ્યુબ ખોલો',
      expectedType: DeviceActionType.launchApp,
      expectedTargetContains: 'youtube',
    ),
    _BenchCase(
      'કેમેરા ખોલો',
      expectedType: DeviceActionType.launchApp,
      expectedTargetContains: 'camera',
    ),
    _BenchCase(
      'સેટિંગ્સ ખોલો',
      expectedType: DeviceActionType.openSettings,
      expectedTargetContains: 'main',
    ),
    _BenchCase(
      'વાઇફાઇ સેટિંગ્સ ખોલો',
      expectedType: DeviceActionType.openSettings,
      expectedTargetContains: 'wifi',
    ),
    _BenchCase(
      'બ્લુટુથ સેટિંગ્સ ખોલો',
      expectedType: DeviceActionType.openSettings,
      expectedTargetContains: 'bluetooth',
    ),
    _BenchCase(
      'ટૉર્ચ ચાલુ કરો',
      expectedType: DeviceActionType.toggleFlashlight,
      expectedEnabled: true,
    ),
    _BenchCase(
      'ફ્લેશલાઇટ બંધ કરો',
      expectedType: DeviceActionType.toggleFlashlight,
      expectedEnabled: false,
    ),
    _BenchCase(
      'ફોન સાઇલેન્ટ મોડ પર મૂકો',
      expectedType: DeviceActionType.setRingerMode,
      expectedTargetContains: 'silent',
    ),
    _BenchCase(
      'ફોન વાઇબ્રેટ મોડ પર મૂકો',
      expectedType: DeviceActionType.setRingerMode,
      expectedTargetContains: 'vibrate',
    ),
    _BenchCase(
      'વોલ્યુમ વધારો',
      expectedType: DeviceActionType.adjustVolume,
      expectedTargetContains: 'up',
    ),
    _BenchCase(
      'વોલ્યુમ ઘટાડો',
      expectedType: DeviceActionType.adjustVolume,
      expectedTargetContains: 'down',
    ),
    _BenchCase('બેટરી કેટલી છે', expectedType: DeviceActionType.deviceStatus),
    _BenchCase(
      'નોટિફિકેશન બતાવ',
      expectedType: DeviceActionType.readNotifications,
    ),
    _BenchCase(
      'રાહુલ ને વોટ્સએપ કરો કે હું આવું છું',
      expectedType: DeviceActionType.sendWhatsapp,
      expectedTargetContains: 'રાહુલ',
    ),
    _BenchCase(
      'પ્રિયા ને મેસેજ મોકલો કેમ છો',
      expectedType: DeviceActionType.sendSms,
      expectedTargetContains: 'પ્રિયા',
    ),
    _BenchCase(
      'ગૂગલ પર સુરત સર્ચ કરો',
      expectedType: DeviceActionType.webSearch,
    ),
    _BenchCase('શાંત થા', expectedType: DeviceActionType.stopSpeaking),
    _BenchCase('ફરીથી બોલ', expectedType: DeviceActionType.repeatLast),
    _BenchCase('રદ કર', expectedType: DeviceActionType.cancelAction),
    _BenchCase('કેવી રીતે કોડ લખવો', expectGeneralQuery: true),
  ]);

  runLanguageSuite('Hinglish & Gujlish + Typos (32 commands)', const <
    _BenchCase
  >[
    _BenchCase(
      'Tisha ne call kar.',
      expectedType: DeviceActionType.callPhone,
      expectedTargetContains: 'tisha',
    ),
    _BenchCase(
      'Tisha ko phone lagao.',
      expectedType: DeviceActionType.callPhone,
      expectedTargetContains: 'tisha',
    ),
    _BenchCase(
      'Aarav ko call karo',
      expectedType: DeviceActionType.callPhone,
      expectedTargetContains: 'aarav',
    ),
    _BenchCase(
      'Priya ne phone karje',
      expectedType: DeviceActionType.callPhone,
      expectedTargetContains: 'priya',
    ),
    _BenchCase(
      'Tisha no number search kar',
      expectedType: DeviceActionType.lookupContacts,
    ),
    _BenchCase(
      'Kal savare saat vage alarm muk.',
      expectedType: DeviceActionType.setAlarm,
      expectedHour: 7,
      expectedMinute: 0,
      expectedTomorrow: true,
    ),
    _BenchCase(
      'Kal subah aath baje alram lagao',
      expectedType: DeviceActionType.setAlarm,
      expectedHour: 8,
      expectedMinute: 0,
      expectedTomorrow: true,
    ),
    _BenchCase(
      'Shaam 7 baje alarm rakho',
      expectedType: DeviceActionType.setAlarm,
      expectedHour: 19,
      expectedMinute: 0,
    ),
    _BenchCase('Alarm bandh kar', expectedType: DeviceActionType.dismissAlarm),
    _BenchCase(
      'Paanch minute ka timmer lagao',
      expectedType: DeviceActionType.setTimer,
      expectedSeconds: 300,
    ),
    _BenchCase(
      'Das second ka timer start kar',
      expectedType: DeviceActionType.setTimer,
      expectedSeconds: 10,
    ),
    _BenchCase('Timer bandh kar', expectedType: DeviceActionType.dismissTimer),
    _BenchCase(
      'WhatsApp khol.',
      expectedType: DeviceActionType.launchApp,
      expectedTargetContains: 'whatsapp',
    ),
    _BenchCase(
      'wattsapp khol',
      expectedType: DeviceActionType.launchApp,
      expectedTargetContains: 'whatsapp',
    ),
    _BenchCase(
      'utube chalu kar',
      expectedType: DeviceActionType.launchApp,
      expectedTargetContains: 'youtube',
    ),
    _BenchCase(
      'camra khol',
      expectedType: DeviceActionType.launchApp,
      expectedTargetContains: 'camera',
    ),
    _BenchCase(
      'setings khol',
      expectedType: DeviceActionType.openSettings,
      expectedTargetContains: 'main',
    ),
    _BenchCase(
      'blutooth setings khol',
      expectedType: DeviceActionType.openSettings,
      expectedTargetContains: 'bluetooth',
    ),
    _BenchCase(
      'wifi seting khol',
      expectedType: DeviceActionType.openSettings,
      expectedTargetContains: 'wifi',
    ),
    _BenchCase(
      'tarch chalu kar',
      expectedType: DeviceActionType.toggleFlashlight,
      expectedEnabled: true,
    ),
    _BenchCase(
      'flashlight bandh kar',
      expectedType: DeviceActionType.toggleFlashlight,
      expectedEnabled: false,
    ),
    _BenchCase(
      'phone silent mode par kar',
      expectedType: DeviceActionType.setRingerMode,
      expectedTargetContains: 'silent',
    ),
    _BenchCase(
      'phone vibrat kar',
      expectedType: DeviceActionType.setRingerMode,
      expectedTargetContains: 'vibrate',
    ),
    _BenchCase(
      'volum badhao',
      expectedType: DeviceActionType.adjustVolume,
      expectedTargetContains: 'up',
    ),
    _BenchCase(
      'volume ghatado',
      expectedType: DeviceActionType.adjustVolume,
      expectedTargetContains: 'down',
    ),
    _BenchCase('batry kitni hai', expectedType: DeviceActionType.deviceStatus),
    _BenchCase(
      'notifications batao',
      expectedType: DeviceActionType.readNotifications,
    ),
    _BenchCase(
      'Rahul ne whatsapp kar I reached',
      expectedType: DeviceActionType.sendWhatsapp,
      expectedTargetContains: 'rahul',
    ),
    _BenchCase(
      'Mom ko message kar Reaching soon',
      expectedType: DeviceActionType.sendSms,
      expectedTargetContains: 'mom',
    ),
    _BenchCase('bolna bandh kar', expectedType: DeviceActionType.stopSpeaking),
    _BenchCase('fari thi bol', expectedType: DeviceActionType.repeatLast),
    _BenchCase(
      'Torch chalu kar aur alarm 6 baje laga',
      expectedType: DeviceActionType.toggleFlashlight,
      minSteps: 2,
    ),
  ]);

  test(
    'Conversation context resolves pronouns & pending confirmation locally',
    () {
      const context = ConversationIntelligenceContext(
        lastContactName: 'Tisha',
        pendingAction: DeviceActionRequest(
          type: DeviceActionType.callPhone,
          target: '+919825011111',
          displaySummary: 'Call Tisha',
          requiresConfirmation: true,
        ),
      );
      final confirm = IntentEngine.analyze('yes confirm', context: context);
      expect(confirm.intentId, 'confirm_pending');
      expect(confirm.request?.requiresConfirmation, isFalse);

      final pronounMsg = IntentEngine.analyze(
        'whatsapp her saying On my way',
        context: const ConversationIntelligenceContext(
          lastContactName: 'Tisha',
        ),
      );
      expect(pronounMsg.request?.type, DeviceActionType.sendWhatsapp);
      expect(pronounMsg.request?.target, 'Tisha');
    },
  );

  test('AutomationController handles contact ordinal & sequential multi-step failure attribution', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final repo = _BenchmarkAutomationRepository();

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        deviceAutomationRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);

    await prefs.setBool('vision_pref_direct_phone_calls', true);
    final controller = container.read(automationControllerProvider.notifier);

    // 1. Ordinal selection skips disambiguation & picks second number
    final ordinalRes = await controller.tryHandleNaturalCommand(
      'Call the second number of Tisha',
    );
    expect(ordinalRes?.status, DeviceActionStatus.confirmationRequired);
    expect(ordinalRes?.summary, contains('+919825022222'));

    // 2. Multi-step sequential workflow succeeds all steps
    final multiReq = DeviceIntentParser.parseLocalCommand(
      'Turn on flashlight and check battery status',
    )!;
    final multiOk = await controller.executeRequest(multiReq);
    expect(multiOk.success, isTrue);
    expect(multiOk.summary, contains('Step 1'));
    expect(multiOk.summary, contains('Step 2'));

    // 3. Multi-step sequential workflow attributes partial failure cleanly
    repo.failLaunchApp = true;
    final multiFailReq = DeviceIntentParser.parseLocalCommand(
      'Turn on flashlight and open NotInstalledApp',
    )!;
    final multiFail = await controller.executeRequest(multiFailReq);
    expect(multiFail.success, isFalse);
    expect(multiFail.summary, contains('Step 2 failed'));
  });

  test('TaskComplexityClassifier, ProviderHealthManager, ProviderFallbackManager & AIModelRegistry work together', () {
    expect(
      TaskComplexityClassifier.classify('Hello'),
      TaskComplexityTier.simpleFast,
    );
    expect(
      TaskComplexityClassifier.classify('આજે હવામાન કેવું રહેશે, સરળ જવાબ આપો'),
      TaskComplexityTier.balancedMultilingual,
    );
    expect(
      TaskComplexityClassifier.classify(
        'Compare clean architecture and debug this Flutter stack trace ```dart```',
      ),
      TaskComplexityTier.deepReasoningCoding,
    );

    final health = ProviderHealthManager();
    health.recordFailure(
      AiProviderType.gemini,
      const AIError(
        kind: AIErrorKind.rateLimited,
        provider: AiProviderType.gemini,
        message: '429',
        userMessage: 'Rate limited',
      ),
    );
    expect(health.isProviderAvailable(AiProviderType.gemini), isFalse);

    final ordered = ProviderFallbackManager.orderCandidates(
      preferredProvider: AiProviderType.gemini,
      configuredEnabledProviders: <AiProviderType>{
        AiProviderType.gemini,
        AiProviderType.openAi,
        AiProviderType.claude,
      },
      autoRoutingEnabled: true,
      fallbackEnabled: true,
      complexity: TaskComplexityTier.simpleFast,
      healthManager: health,
    );
    expect(ordered.first, AiProviderType.openAi);

    final rec = AIModelRegistry.recommendModelFor(
      AiProviderType.claude,
      complexity: TaskComplexityTier.deepReasoningCoding,
      userSelectedModelId: 'claude-haiku-5-5',
    );
    expect(rec.modelId, 'claude-sonnet-5-5');

    // Context budget truncation & error filtering
    final convo = AIConversationManager(
      initialMessages: <ChatMessage>[
        ChatMessage(
          id: 'err1',
          sender: MessageSender.assistant,
          content: 'Error occurred',
          createdAt: DateTime.now(),
          isError: true,
        ),
        ChatMessage(
          id: 'u1',
          sender: MessageSender.user,
          content: 'Hi',
          createdAt: DateTime.now(),
        ),
      ],
    );
    expect(convo.buildContextWindow().length, 1);

    // System prompt honesty guard
    final promptReq = AiCompletionRequest(
      provider: AiProviderType.gemini,
      messages: convo.buildContextWindow(),
      responseLanguage: VoiceLanguage.english,
    );
    expect(promptReq.systemInstruction, contains('NEVER claim'));
  });

  test('MemoryController enforces consent gating & secret blocking and TelemetryNotifier redacts secrets', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    final memory = container.read(memoryControllerProvider.notifier);
    // Reject password secret
    final rejected = await memory.addEntry(
      category: MemoryCategory.responseStyle,
      title: 'My password',
      content: 'hunter2',
    );
    expect(rejected, isFalse);

    // Disabled by default -> returns empty prompt context
    final saved = await memory.addEntry(
      category: MemoryCategory.responseStyle,
      title: 'Concise bullets',
      content: 'Prefer short bullet answers',
    );
    expect(saved, isTrue);
    expect(
      container.read(memoryControllerProvider).buildPromptContext(),
      isEmpty,
    );

    // Enable consent -> injects clean prompt block
    await memory.setMemoryEnabled(true);
    expect(
      container.read(memoryControllerProvider).buildPromptContext(),
      contains('Concise bullets'),
    );

    // Telemetry secret scrubbing
    container
        .read(telemetryProvider.notifier)
        .recordSanitizedError(
          'OpenAI',
          'Bearer sk-proj-supersecret12345 failed',
        );
    final errMsg = container.read(telemetryProvider).recentErrors.first.message;
    expect(errMsg, isNot(contains('sk-proj-supersecret12345')));
  });
}
