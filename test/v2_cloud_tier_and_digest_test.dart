import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vision_ai/core/theme/vision_dark_theme.dart';
import 'package:vision_ai/core/theme/vision_light_theme.dart';
import 'package:vision_ai/core/utils/shared_preferences_provider.dart';
import 'package:vision_ai/features/automation/domain/entities/device_action.dart';
import 'package:vision_ai/features/automation/domain/utils/device_intent_parser.dart';
import 'package:vision_ai/features/chat/data/datasources/vision_cloud_datasource.dart';
import 'package:vision_ai/features/chat/domain/entities/ai_models.dart';
import 'package:vision_ai/features/chat/domain/entities/chat_message.dart';
import 'package:vision_ai/features/notifications/domain/entities/notification_digest.dart';
import 'package:vision_ai/features/notifications/domain/services/notification_digest_service.dart';
import 'package:vision_ai/features/notifications/domain/services/notification_privacy_filter.dart';
import 'package:vision_ai/features/notifications/presentation/widgets/notification_digest_card.dart';
import 'package:vision_ai/features/settings/domain/entities/ai_provider_type.dart';
import 'package:vision_ai/features/settings/domain/entities/voice_language.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('Pillar 1 — VisionCloudProvider (Built-in Free Tier)', () {
    AIRequest buildRequest() {
      return AIRequest(
        provider: AiProviderType.visionCloud,
        modelId: 'gemini-2.5-flash',
        messages: <ChatMessage>[
          ChatMessage(
            id: 'm1',
            sender: MessageSender.user,
            content: 'Namaste VISION!',
            createdAt: DateTime(2026, 11, 21, 12, 0),
          ),
        ],
        systemInstruction: 'You are VISION.',
        responseLanguage: VoiceLanguage.english,
      );
    }

    test('parses response text, usage, and updates daily quota state', () async {
      VisionCloudQuota? observedQuota;
      final provider = VisionCloudProvider(
        invoker: (body) async {
          expect(body['model'], 'gemini-2.5-flash');
          return (
            status: 200,
            data: <String, dynamic>{
              'text': 'Namaste! How can I help you today?',
              'model': 'gemini-2.5-flash',
              'quota': <String, dynamic>{
                'allowed': true,
                'used': 1,
                'remaining': 29,
                'daily_limit': 30,
                'reset_at': '2026-11-22T00:00:00Z',
              },
              'usage': <String, dynamic>{
                'input_tokens': 12,
                'output_tokens': 9,
                'total_tokens': 21,
              },
            },
          );
        },
        onQuotaUpdated: (q) => observedQuota = q,
      );

      final response = await provider.generate(buildRequest(), apiKey: 'cloud');
      expect(response.text, 'Namaste! How can I help you today?');
      expect(response.provider, AiProviderType.visionCloud);
      expect(response.usage?.totalTokens, 21);
      expect(observedQuota, isNotNull);
      expect(observedQuota!.remaining, 29);
      expect(observedQuota!.badgeLabel, '29/30 free left');
    });

    test('maps HTTP 429 to rateLimited AIError and marks quota exhausted', () async {
      VisionCloudQuota? observedQuota;
      final provider = VisionCloudProvider(
        invoker: (_) async => (
          status: 429,
          data: <String, dynamic>{
            'error': 'daily_quota_exceeded',
            'message': 'Daily limit of 30 reached.',
            'quota': <String, dynamic>{
              'allowed': false,
              'used': 30,
              'remaining': 0,
              'daily_limit': 30,
            },
          },
        ),
        onQuotaUpdated: (q) => observedQuota = q,
      );

      await expectLater(
        provider.generate(buildRequest(), apiKey: 'cloud'),
        throwsA(
          isA<AIError>()
              .having((e) => e.kind, 'kind', AIErrorKind.rateLimited)
              .having((e) => e.statusCode, 'statusCode', 429),
        ),
      );
      expect(observedQuota?.isExhausted, isTrue);
    });

    test('maps HTTP 401 to invalidApiKey AIError', () async {
      final provider = VisionCloudProvider(
        invoker: (_) async => (
          status: 401,
          data: <String, dynamic>{
            'error': 'unauthorized',
            'message': 'Sign in required.',
          },
        ),
      );

      await expectLater(
        provider.generate(buildRequest(), apiKey: 'cloud'),
        throwsA(
          isA<AIError>().having(
            (e) => e.kind,
            'kind',
            AIErrorKind.invalidApiKey,
          ),
        ),
      );
    });
  });

  group('Pillar 2 — NotificationPrivacyFilter & NotificationDigestService', () {
    final sampleNotifications = <DeviceNotificationSummary>[
      const DeviceNotificationSummary(
        key: 'wa_1',
        appName: 'WhatsApp',
        packageName: 'com.whatsapp',
        title: 'Mom',
        text: 'Dinner is ready at 8 PM, call me when you leave office.',
        postedAtMillis: 1700000001000,
        canReply: true,
      ),
      const DeviceNotificationSummary(
        key: 'sms_otp',
        appName: 'Messages',
        packageName: 'com.google.android.apps.messaging',
        title: 'HDFCBK',
        text: 'Your OTP for login is 482910. Do not share with anyone.',
        postedAtMillis: 1700000002000,
      ),
      const DeviceNotificationSummary(
        key: 'gpay_1',
        appName: 'GPay',
        packageName: 'com.google.android.apps.nbu.paisa.user',
        title: 'Paid ₹450',
        text: 'Debited from your SBI A/C via UPI.',
        postedAtMillis: 1700000003000,
      ),
    ];

    test('filters OTPs, banking SMS, and UPI apps strictly on-device', () {
      final partitioned = NotificationPrivacyFilter.partition(
        sampleNotifications,
      );
      expect(partitioned.safeForAi.length, 1);
      expect(partitioned.safeForAi.first.key, 'wa_1');
      expect(partitioned.protectedLocal.length, 2);
      expect(
        partitioned.protectedLocal.map((n) => n.key),
        containsAll(<String>['sms_otp', 'gpay_1']),
      );
    });

    test('parses AI digest JSON and preserves smart reply chips', () {
      final partitioned = NotificationPrivacyFilter.partition(
        sampleNotifications,
      );
      const rawJson = '''
```json
{
  "spoken_summary": "Mom sent a WhatsApp message about dinner at 8 PM. Two private banking or OTP alerts were kept local.",
  "items": [
    {
      "index": 0,
      "priority": "people",
      "summary": "Mom: Dinner ready at 8 PM, asked you to call.",
      "replies": ["Leaving in 10 mins", "Will call soon"]
    }
  ]
}
```
''';
      final digest = NotificationDigestService.parseAiDigestJson(
        rawText: rawJson,
        safeItems: partitioned.safeForAi,
        protectedLocalCount: partitioned.protectedLocal.length,
        language: VoiceLanguage.english,
        now: DateTime(2026, 11, 21, 13, 0),
      );

      expect(digest, isNotNull);
      expect(digest!.usedAi, isTrue);
      expect(digest.protectedLocalCount, 2);
      expect(digest.items.length, 1);
      expect(digest.items.first.priority, DigestItemPriority.people);
      expect(digest.items.first.suggestedReplies.length, 2);
      expect(
        digest.items.first.suggestedReplies.first.replyText,
        'Leaving in 10 mins',
      );
    });

    test('builds multilingual offline fallback digest in Hindi and Gujarati', () {
      final partitioned = NotificationPrivacyFilter.partition(
        sampleNotifications,
      );
      final hiDigest = NotificationDigestService.buildOfflineFallback(
        filtered: partitioned,
        language: VoiceLanguage.hindi,
        now: DateTime(2026, 11, 21, 13, 0),
      );
      expect(hiDigest.usedAi, isFalse);
      expect(hiDigest.items.first.suggestedReplies.first.label, 'ठीक है 👍');

      final guDigest = NotificationDigestService.buildOfflineFallback(
        filtered: partitioned,
        language: VoiceLanguage.gujarati,
        now: DateTime(2026, 11, 21, 13, 0),
      );
      expect(guDigest.items.first.suggestedReplies.first.label, 'બરાબર 👍');
    });

    test('recognizes EN/HI/GU "What did I miss?" voice catch-up phrases', () {
      for (final phrase in <String>[
        'What did I miss?',
        'Catch me up',
        'Kya miss hua?',
        'Mera message padho',
        'મારા મેસેજ વાંચો',
      ]) {
        final action = DeviceIntentParser.parseLocalCommand(phrase);
        expect(
          action?.type,
          DeviceActionType.readNotifications,
          reason: 'Expected readNotifications for "$phrase"',
        );
      }
    });

    testWidgets('NotificationDigestCard renders cleanly in Dark & Light themes', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();

      for (final theme in <ThemeData>[
        VisionDarkTheme.build(),
        VisionLightTheme.build(),
      ]) {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
            child: MaterialApp(
              theme: theme,
              home: const Scaffold(
                body: Padding(
                  padding: EdgeInsets.all(16),
                  child: NotificationDigestCard(),
                ),
              ),
            ),
          ),
        );
        await tester.runAsync(() => GoogleFonts.pendingFonts());
        await tester.pumpAndSettle();

        expect(find.text('SMART CATCH-UP DIGEST'), findsOneWidget);
        expect(find.text('Enable Smart Catch-Up'), findsOneWidget);
      }
    });
  });
}
