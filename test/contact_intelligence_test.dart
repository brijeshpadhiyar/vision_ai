import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vision_ai/core/intelligence/command_normalizer.dart';
import 'package:vision_ai/core/intelligence/conversation_context.dart';
import 'package:vision_ai/core/intelligence/intent_engine.dart';
import 'package:vision_ai/core/intelligence/phonetics/indic_transliterator.dart';
import 'package:vision_ai/core/intelligence/phonetics/phonetic_algorithms.dart';
import 'package:vision_ai/core/utils/shared_preferences_provider.dart';
import 'package:vision_ai/features/automation/data/repositories/device_automation_repository_impl.dart';
import 'package:vision_ai/features/automation/domain/entities/device_action.dart';
import 'package:vision_ai/features/automation/domain/repositories/device_automation_repository.dart';
import 'package:vision_ai/features/automation/presentation/controllers/automation_controller.dart';
import 'package:vision_ai/features/contacts/data/repositories/contact_alias_repository.dart';
import 'package:vision_ai/features/contacts/data/repositories/contact_search_repository.dart';
import 'package:vision_ai/features/contacts/domain/entities/contact_resolution.dart';
import 'package:vision_ai/features/contacts/domain/services/contact_resolver.dart';
import 'package:vision_ai/features/voice/domain/entities/voice_session_state.dart';

class _PhoneticContactAutomationRepo implements DeviceAutomationRepository {
  _PhoneticContactAutomationRepo(this.contacts);

  List<ContactMatch> contacts;
  String? lastCalledNumber;

  @override
  Future<bool> checkPermission(AutomationPermission permission) async => true;

  @override
  Future<bool> requestPermission(AutomationPermission permission) async => true;

  @override
  Future<List<ContactMatch>> lookupContacts(String query) async {
    final lower = query.toLowerCase();
    return contacts
        .where((c) => c.name.toLowerCase().contains(lower))
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
      summary: 'Opened dialer for $phoneNumber',
    );
  }

  @override
  Future<DeviceActionResult> setAlarm({
    required int hour,
    required int minute,
    String? label,
    bool skipUi = false,
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
        summary: 'Opening $appNameOrPackage.',
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
        summary: 'Ringer changed.',
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
        summary: 'Searched web.',
      );

  @override
  Future<DeviceActionResult> navigateTo(String destination) async =>
      const DeviceActionResult(
        success: true,
        actionType: DeviceActionType.navigateTo,
        summary: 'Navigation started.',
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
        isFlashlightOn: false,
        isDefaultAssistant: true,
        isIgnoringBatteryOptimizations: true,
        canScheduleExactAlarms: true,
      );
}

void main() {
  test('Phonetic algorithms, Indic transliteration & ASR split command repairs work accurately', () {
    expect(
      PhoneticAlgorithms.indicRomanConsonantSkeleton('Shohil'),
      PhoneticAlgorithms.indicRomanConsonantSkeleton('Soel'),
    );
    expect(
      PhoneticAlgorithms.damerauLevenshteinSimilarity('alram', 'alarm'),
      greaterThanOrEqualTo(0.80),
    );
    expect(
      PhoneticAlgorithms.jaroWinklerSimilarity('brijesh', 'brijes'),
      greaterThan(0.90),
    );
    expect(IndicTransliterator.toRomanizedLatin('તિષા'), contains('tisha'));
    expect(IndicTransliterator.toRomanizedLatin('सोएल'), contains('soel'));

    // Command split phrases ("Whats app", "what's app") resolve without corrupting names
    for (final cmd in <String>[
      'open whats app',
      "what's app khol",
      'watsapp open',
    ]) {
      final norm = CommandNormalizer.normalize(cmd);
      expect(norm.canonicalText, contains('whatsapp'));
      final intent = IntentEngine.analyze(cmd);
      expect(intent.request?.type, DeviceActionType.launchApp);
      expect(intent.request?.target, 'WhatsApp');
    }

    // Proper names remain preserved in original rawText
    final callNorm = CommandNormalizer.normalize('Call Shohil Jht');
    expect(callNorm.rawText, 'Call Shohil Jht');
  });

  test('ContactResolver handles "Shohil Jht" -> "Soel Kht" with Medium confidence, alias confirmation & Contact-ID updates', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final repo = _PhoneticContactAutomationRepo(const <ContactMatch>[
      ContactMatch(
        contactId: 'cid_101',
        name: 'Soel Kht',
        phoneNumber: '+919825010101',
        label: 'Mobile',
      ),
      ContactMatch(
        contactId: 'cid_102',
        name: 'Mom',
        phoneNumber: '+919825099999',
        label: 'Home',
      ),
      ContactMatch(
        contactId: 'cid_103',
        name: 'Rahul Sharma',
        phoneNumber: '+919825077777',
        label: 'Work',
      ),
    ]);

    final aliasRepo = ContactAliasRepository(prefs);
    final resolver = ContactResolver(
      searchRepository: ContactSearchRepository(repo),
      aliasRepository: aliasRepo,
    );

    // 1. Real-world divergence "Shohil Jht" vs saved "Soel Kht" -> Medium confidence suggestion
    final res = await resolver.resolve(primaryQuery: 'Shohil Jht');
    expect(res.confidenceBand, ContactConfidenceBand.medium);
    expect(res.bestCandidate?.contact.name, 'Soel Kht');
    expect(res.promptMessage, 'Did you mean Soel Kht?');
    expect(res.suggestSaveAlias, isTrue);
    expect(res.latencyMs, lessThan(250));

    // 2. Unrelated low-confidence name never guesses a real person to call
    final lowRes = await resolver.resolve(primaryQuery: 'Zyxwvut Random');
    expect(lowRes.confidenceBand, ContactConfidenceBand.low);

    // 3. Confirmed Contact-ID alias upgrades subsequent matches to High confidence
    await aliasRepo.saveConfirmedAlias(
      spokenPhrase: 'Shohil Jht',
      contact: res.bestCandidate!.contact,
    );
    // Simulate contact rename in Android Contacts Book preserving same contactId!
    repo.contacts = const <ContactMatch>[
      ContactMatch(
        contactId: 'cid_101',
        name: 'Soel Kht Updated',
        phoneNumber: '+919825010101',
        label: 'Mobile',
      ),
      ContactMatch(
        contactId: 'cid_102',
        name: 'Mom',
        phoneNumber: '+919825099999',
        label: 'Home',
      ),
    ];

    final aliasedRes = await resolver.resolve(primaryQuery: 'Shohil Jht');
    expect(aliasedRes.confidenceBand, ContactConfidenceBand.high);
    expect(aliasedRes.bestCandidate?.contact.contactId, 'cid_101');
    expect(aliasedRes.bestCandidate?.contact.name, 'Soel Kht Updated');
    expect(aliasedRes.bestCandidate?.fromSavedAlias, isTrue);

    // 4. Edit & Delete Alias support
    final aliases = aliasRepo.getAliases();
    expect(aliases.length, 1);
    await aliasRepo.updateAliasSpokenPhrase(aliases.first.aliasId, 'Sohil Jat');
    expect(aliasRepo.getAliases().first.spokenPhrase, 'Sohil Jat');
    await aliasRepo.deleteAlias(aliases.first.aliasId);
    expect(aliasRepo.getAliases(), isEmpty);
  });

  test('ContactResolver leverages alternative speech hypotheses and word-order variations', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final repo = _PhoneticContactAutomationRepo(const <ContactMatch>[
      ContactMatch(
        contactId: 'cid_201',
        name: 'Tisha Patel',
        phoneNumber: '+919825055555',
      ),
      ContactMatch(
        contactId: 'cid_202',
        name: 'તિષા પટેલ',
        phoneNumber: '+919825066666',
      ),
    ]);
    final resolver = ContactResolver(
      searchRepository: ContactSearchRepository(repo),
      aliasRepository: ContactAliasRepository(prefs),
    );

    // Word-order swap ("Patel Tisha")
    final swapped = await resolver.resolve(primaryQuery: 'Patel Tisha');
    expect(swapped.bestCandidate?.contact.phoneNumber, '+919825055555');
    expect(
      swapped.confidenceBand,
      anyOf(ContactConfidenceBand.high, ContactConfidenceBand.ambiguous),
    );

    // Alternative ASR hypothesis recovery
    final hypRes = await resolver.resolve(
      primaryQuery: 'Dish Pattern',
      alternativeQueries: const <String>['Tisha Patel'],
    );
    expect(hypRes.bestCandidate?.contact.name, 'Tisha Patel');
    expect(hypRes.bestCandidate?.score, greaterThanOrEqualTo(0.88));
  });

  test('AutomationController medium-confidence flow asks "Did you mean Soel Kht?", confirms & learns alias', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final repo = _PhoneticContactAutomationRepo(const <ContactMatch>[
      ContactMatch(
        contactId: 'cid_101',
        name: 'Soel Kht',
        phoneNumber: '+919825010101',
        label: 'Mobile',
      ),
    ]);

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        deviceAutomationRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(automationControllerProvider.notifier);

    // First attempt: holds cleanly at confirmationRequired ("Did you mean Soel Kht?") without calling!
    final firstAttempt = await controller.tryHandleNaturalCommand(
      'Call Shohil Jht',
    );
    expect(firstAttempt?.status, DeviceActionStatus.confirmationRequired);
    expect(firstAttempt?.summary, 'Did you mean Soel Kht?');
    expect(repo.lastCalledNumber, isNull);

    // User confirms & saves voice alias -> calls Soel Kht & records alias
    final confirmed = await controller.confirmPendingAction(saveAsAlias: true);
    expect(confirmed?.success, isTrue);
    expect(repo.lastCalledNumber, '+919825010101');

    // Second attempt later: saved Contact-ID alias resolves directly with High confidence!
    repo.lastCalledNumber = null;
    final secondAttempt = await controller.tryHandleNaturalCommand(
      'Call Shohil Jht',
    );
    expect(secondAttempt?.success, isTrue);
    expect(repo.lastCalledNumber, '+919825010101');
  });

  test('Multi-turn task context ("Open WhatsApp" -> "Now message Tisha") & VoiceTranscriptEvent nullable scores', () {
    final step1 = IntentEngine.analyze('Open WhatsApp.');
    expect(step1.request?.type, DeviceActionType.launchApp);
    expect(step1.request?.target, 'WhatsApp');

    final ctx = ConversationIntelligenceContext(
      lastIntentId: step1.intentId,
      lastAppName: step1.request?.target,
    );
    final step2 = IntentEngine.analyze('Now message Tisha.', context: ctx);
    expect(step2.request?.type, DeviceActionType.sendWhatsapp);
    expect(step2.request?.target, 'Tisha');

    // VoiceEvent preserves alternative hypotheses and leaves missing scores null (never fabricated)
    final parsedWithoutScores = VoiceEvent.fromMap(<Object?, Object?>{
      'type': 'transcript',
      'text': 'Call Shohil Jht',
      'isFinal': true,
      'hypotheses': <Object?>['Call Shohil Jht', 'Call Soel Kht'],
    });
    expect(parsedWithoutScores, isA<VoiceTranscriptEvent>());
    final tx = parsedWithoutScores as VoiceTranscriptEvent;
    expect(tx.hypotheses, <String>['Call Shohil Jht', 'Call Soel Kht']);
    expect(tx.confidenceScores, isNull);
  });
}
