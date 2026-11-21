import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vision_ai/core/theme/vision_dark_theme.dart';
import 'package:vision_ai/core/theme/vision_light_theme.dart';
import 'package:vision_ai/core/utils/shared_preferences_provider.dart';
import 'package:vision_ai/features/chat/data/datasources/chat_local_datasource.dart';
import 'package:vision_ai/features/chat/domain/entities/chat_message.dart';
import 'package:vision_ai/features/chat/domain/entities/conversation_thread.dart';
import 'package:vision_ai/features/chat/presentation/controllers/conversation_threads_controller.dart';
import 'package:vision_ai/features/chat/presentation/widgets/conversation_threads_sheet.dart';
import 'package:vision_ai/features/cloud/domain/services/zero_knowledge_key_vault.dart';
import 'package:vision_ai/features/cloud/presentation/controllers/cloud_auth_controller.dart';
import 'package:vision_ai/features/cloud/presentation/widgets/cloud_sync_settings_section.dart';
import 'package:vision_ai/features/settings/domain/entities/ai_provider_type.dart';
import 'package:vision_ai/features/settings/presentation/controllers/settings_controller.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('ConversationThread & Local Migration', () {
    test('derives concise title, exports Markdown, and round-trips JSON/Supabase rows', () {
      final now = DateTime(2026, 11, 19, 17, 30);
      final messages = <ChatMessage>[
        ChatMessage(
          id: 'm1',
          sender: MessageSender.user,
          content: 'Explain Flutter Riverpod architecture for my Android app',
          createdAt: now,
          provider: AiProviderType.gemini,
        ),
        ChatMessage(
          id: 'm2',
          sender: MessageSender.assistant,
          content:
              'Riverpod separates state providers from widget trees cleanly.',
          createdAt: now.add(const Duration(seconds: 2)),
          provider: AiProviderType.gemini,
        ),
      ];

      final thread = ConversationThread.create(
        id: 'thread_test_1',
        title: ConversationThread.deriveTitle(messages),
        messages: messages,
        now: now,
        isPinned: true,
      );

      expect(thread.title.length, lessThanOrEqualTo(42));
      expect(thread.matchesQuery('riverpod'), isTrue);
      expect(thread.matchesQuery('nonexistent_xyz'), isFalse);

      final md = thread.toMarkdown();
      expect(md, contains('# ${thread.title}'));
      expect(md, contains('**You**'));
      expect(md, contains('**VISION** (Google Gemini)'));

      final fromJson = ConversationThread.fromJson(thread.toJson());
      expect(fromJson.id, thread.id);
      expect(fromJson.isPinned, isTrue);
      expect(fromJson.messages.length, 2);

      final fromRow = ConversationThread.fromSupabaseRow(
        thread.toSupabaseRow('user-123'),
      );
      expect(fromRow.id, thread.id);
      expect(fromRow.title, thread.title);
      expect(fromRow.messages.length, 2);
    });

    test('ChatLocalDataSource migrates legacy chatHistory into a thread automatically', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final ds = ChatLocalDataSource(prefs);

      await ds.writeMessages(<ChatMessage>[
        ChatMessage(
          id: 'legacy_1',
          sender: MessageSender.user,
          content: 'Legacy question from v1.4',
          createdAt: DateTime(2026, 11, 18, 12, 0),
        ),
      ]);

      final threads = ds.readThreads();
      expect(threads.length, 1);
      expect(threads.first.title, 'Legacy question from v1.4');
      expect(threads.first.messages.length, 1);
    });
  });

  group('ConversationThreadsController', () {
    test(
      'creates, pins, renames, searches, merges remote, and deletes threads',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final prefs = await SharedPreferences.getInstance();
        final container = ProviderContainer(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        );
        addTearDown(container.dispose);

        // Enable local history persistence and verify persistence.
        await container
            .read(settingsControllerProvider.notifier)
            .setSaveConversationHistory(enabled: true);

        final ctrl = container.read(
          conversationThreadsControllerProvider.notifier,
        );
        final t1 = await ctrl.createNewThread(title: 'Alpha Thread');
        final t2 = await ctrl.createNewThread(title: 'Beta Thread');

        await ctrl.togglePin(t1.id);
        await ctrl.renameThread(t2.id, 'Beta Renamed');

        var state = container.read(conversationThreadsControllerProvider);
        expect(state.filteredThreads.first.id, t1.id);

        ctrl.setSearchQuery('renamed');
        state = container.read(conversationThreadsControllerProvider);
        expect(state.filteredThreads.length, 1);
        expect(state.filteredThreads.first.title, 'Beta Renamed');

        ctrl.setSearchQuery('');
        final remote = ConversationThread.create(
          id: 'remote_1',
          title: 'Synced From Cloud',
          now: DateTime.now().add(const Duration(minutes: 5)),
        );
        await ctrl.mergeRemoteThreads(<ConversationThread>[remote]);
        expect(
          container
              .read(conversationThreadsControllerProvider)
              .threads
              .any((t) => t.id == 'remote_1'),
          isTrue,
        );

        await ctrl.deleteThread(t1.id);
        expect(
          container
              .read(conversationThreadsControllerProvider)
              .threads
              .any((t) => t.id == t1.id),
          isFalse,
        );
      },
    );
  });

  group('ZeroKnowledgeKeyVault (AES-256-GCM + PBKDF2)', () {
    test(
      'encrypts and decrypts API keys cleanly and rejects wrong passphrase',
      () async {
        // Lower iterations in unit test for fast CI while verifying exact algorithm.
        final vault = ZeroKnowledgeKeyVault(iterations: 1000);
        final keys = <String, String>{
          'gemini': 'AIzaSyTestKey123456',
          'openai': 'sk-proj-TestSecret789',
        };

        final blob1 = await vault.encryptKeys(
          apiKeys: keys,
          passphrase: 'strong-passphrase-2026',
        );
        final blob2 = await vault.encryptKeys(
          apiKeys: keys,
          passphrase: 'strong-passphrase-2026',
        );

        // Random salt and nonce must produce distinct ciphertexts every time.
        expect(blob1.saltBase64, isNot(blob2.saltBase64));
        expect(blob1.nonceBase64, isNot(blob2.nonceBase64));
        expect(blob1.ciphertextBase64, isNot(blob2.ciphertextBase64));

        final decrypted = await vault.decryptKeys(
          blob: blob1,
          passphrase: 'strong-passphrase-2026',
        );
        expect(decrypted, equals(keys));

        await expectLater(
          vault.decryptKeys(blob: blob1, passphrase: 'wrong-passphrase'),
          throwsA(isA<VaultDecryptionException>()),
        );
      },
    );
  });

  group('v1.5 UI Widgets', () {
    testWidgets(
      'ConversationThreadsSheet and CloudSyncSettingsSection render cleanly',
      (tester) async {
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
                  body: SingleChildScrollView(
                    child: Column(
                      children: <Widget>[
                        CloudSyncSettingsSection(),
                        SizedBox(height: 16),
                        ConversationThreadsSheet(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.runAsync(() => GoogleFonts.pendingFonts());
          await tester.pumpAndSettle();

          expect(find.text('ACCOUNT & CLOUD SYNC'), findsOneWidget);
          expect(find.text('Guest / Local Mode Active'), findsOneWidget);
          expect(find.text('New'), findsOneWidget);
        }
      },
    );
  });

  group('CloudAuthController mobile sign-in fallback', () {
    test('treats Credential Manager reauth/SHA-1 errors as fallback, not user cancel', () {
      const reauthError = GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
        description: '[16] Account reauth failed.',
      );
      const devConfigError = GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
        description: 'Developer console is not set up correctly.',
      );
      const trueCancel = GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
        description: 'activity is cancelled by the user.',
      );
      const emptyCancel = GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
      );

      expect(CloudAuthController.isUserInitiatedCancel(reauthError), isFalse);
      expect(CloudAuthController.isUserInitiatedCancel(devConfigError), isFalse);
      expect(CloudAuthController.isUserInitiatedCancel(trueCancel), isTrue);
      expect(CloudAuthController.isUserInitiatedCancel(emptyCancel), isTrue);
    });
  });
}
