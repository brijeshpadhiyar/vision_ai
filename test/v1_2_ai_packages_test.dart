import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';

import 'package:vision_ai/core/utils/secure_storage_provider.dart';
import 'package:vision_ai/features/chat/data/datasources/claude_remote_datasource.dart';
import 'package:vision_ai/features/chat/data/datasources/gemini_remote_datasource.dart';
import 'package:vision_ai/features/chat/data/datasources/openai_remote_datasource.dart';
import 'package:vision_ai/features/chat/domain/entities/ai_models.dart';
import 'package:vision_ai/features/chat/domain/entities/chat_message.dart';
import 'package:vision_ai/features/chat/domain/entities/image_attachment.dart';
import 'package:vision_ai/features/chat/domain/repositories/ai_provider.dart';
import 'package:vision_ai/features/chat/domain/services/ai_router.dart';
import 'package:vision_ai/features/chat/domain/services/vision_llm_provider.dart';
import 'package:vision_ai/features/chat/presentation/widgets/chat_message_bubble.dart';
import 'package:vision_ai/features/research/domain/entities/research_source.dart';
import 'package:vision_ai/features/research/domain/services/internet_research_service.dart';
import 'package:vision_ai/features/settings/domain/entities/ai_provider_type.dart';
import 'package:vision_ai/features/settings/domain/entities/app_settings.dart';
import 'package:vision_ai/features/settings/domain/entities/voice_language.dart';

class _EmptyKeyStore implements SecureCredentialStore {
  @override
  Future<void> deleteApiKey(String providerId) async {}

  @override
  Future<bool> hasApiKey(String providerId) async => false;

  @override
  Future<String?> readApiKey(String providerId) async => null;

  @override
  Future<void> saveApiKey({
    required String providerId,
    required String apiKey,
  }) async {}
}

class _FakeEdgeProvider implements AIProvider {
  @override
  AiProviderType get providerType => AiProviderType.edgeAi;

  @override
  String get providerName => providerType.displayName;

  @override
  Future<AIResponse> generate(
    AIRequest request, {
    required String apiKey,
    AICancellationToken? cancellationToken,
  }) async => AIResponse(
    text: 'Edge Nano offline reply',
    provider: providerType,
    modelId: request.modelId,
  );

  @override
  Stream<AIStreamChunk> stream(
    AIRequest request, {
    required String apiKey,
    AICancellationToken? cancellationToken,
  }) async* {
    yield const AITextDeltaChunk('Edge Nano ');
    yield const AITextDeltaChunk('stream');
    yield AICompletedChunk(
      AIResponse(
        text: 'Edge Nano stream',
        provider: providerType,
        modelId: request.modelId,
      ),
    );
  }

  @override
  Future<List<String>> listAvailableModels({
    required String apiKey,
    AICancellationToken? cancellationToken,
  }) async => const <String>['gemini-nano'];

  @override
  Future<AIConnectionTestResult> testConnection({
    required String apiKey,
    String? modelId,
    AICancellationToken? cancellationToken,
  }) async => AIConnectionTestResult(
    provider: providerType,
    modelId: 'gemini-nano',
    connected: true,
    message: 'Ready',
    testedAt: DateTime.now(),
  );
}

void main() {
  test('v1.2 AiProviderType.edgeAi requires no API key and routes cleanly via AIRouter & VisionLlmProvider', () async {
    expect(AiProviderType.edgeAi.requiresApiKey, isFalse);
    expect(AiProviderType.gemini.requiresApiKey, isTrue);

    final router = AIRouter(
      registry: AIProviderRegistry(<AiProviderType, AIProvider>{
        AiProviderType.edgeAi: _FakeEdgeProvider(),
      }),
      credentialStore: _EmptyKeyStore(),
    );

    const edgeSettings = AppSettings(selectedAiProvider: AiProviderType.edgeAi);
    final candidates = await router.resolveCandidates(
      settings: edgeSettings,
      promptText: 'Summarize this offline',
    );
    expect(candidates.length, 1);
    expect(candidates.first.target.provider, AiProviderType.edgeAi);

    final toolkitProvider = VisionLlmProvider(
      router: router,
      settingsReader: () => edgeSettings,
    );
    final chunks = await toolkitProvider
        .sendMessageStream('Hello Nano')
        .toList();
    expect(chunks.join(), 'Edge Nano stream');
    expect(toolkitProvider.history.length, 2);
  });

  test('v1.2 Multimodal image payloads serialize for Gemini, OpenAI, and Claude while ChatMessage.toJson omits base64 bytes', () async {
    final fakeBytes = Uint8List.fromList(<int>[
      137,
      80,
      78,
      71,
      13,
      10,
      26,
      10,
    ]);
    final attachment = ImageAttachment.fromBytes(
      fakeBytes,
      mimeType: 'image/jpeg',
      label: 'receipt.jpg',
    );
    final userMsg = ChatMessage(
      id: 'm1',
      sender: MessageSender.user,
      content: 'What is in this photo?',
      createdAt: DateTime.utc(2026, 11, 19),
      imageAttachment: attachment,
      citations: const <ResearchSource>[
        ResearchSource(
          title: 'Flutter Docs',
          url: 'https://flutter.dev',
          snippet: 'Official Flutter site',
        ),
      ],
    );

    // Privacy check: raw base64 is never persisted in ChatMessage.toJson()
    final serialized = jsonEncode(userMsg.toJson());
    expect(serialized, isNot(contains(attachment.base64Data)));
    expect(ChatMessage.fromJson(userMsg.toJson()).citations.length, 1);

    // Verify Gemini inlineData, OpenAI input_image, and Claude base64 image payloads
    Map<String, dynamic>? capturedGemini;
    final geminiClient = MockClient((req) async {
      capturedGemini = jsonDecode(req.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode(<String, Object?>{
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': 'Receipt image'},
                ],
              },
            },
          ],
        }),
        200,
      );
    });
    final gemini = GeminiProvider(geminiClient);
    await gemini.generate(
      AIRequest(
        provider: AiProviderType.gemini,
        modelId: 'gemini-3.5-flash-lite',
        messages: <ChatMessage>[userMsg],
        systemInstruction: 'Be helpful',
        responseLanguage: VoiceLanguage.english,
      ),
      apiKey: 'AIza-test',
    );
    expect(jsonEncode(capturedGemini), contains('"inlineData"'));

    Map<String, dynamic>? capturedOpenAi;
    final openAiClient = MockClient((req) async {
      capturedOpenAi = jsonDecode(req.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode(<String, Object?>{'output_text': 'Receipt image'}),
        200,
      );
    });
    final openAi = OpenAIProvider(openAiClient);
    await openAi.generate(
      AIRequest(
        provider: AiProviderType.openAi,
        modelId: 'gpt-5.4-mini',
        messages: <ChatMessage>[userMsg],
        systemInstruction: 'Be helpful',
        responseLanguage: VoiceLanguage.english,
      ),
      apiKey: 'sk-test',
    );
    expect(jsonEncode(capturedOpenAi), contains('"input_image"'));

    Map<String, dynamic>? capturedClaude;
    final claudeClient = MockClient((req) async {
      capturedClaude = jsonDecode(req.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode(<String, Object?>{
          'content': [
            {'type': 'text', 'text': 'Receipt image'},
          ],
        }),
        200,
      );
    });
    final claude = ClaudeProvider(claudeClient);
    await claude.generate(
      AIRequest(
        provider: AiProviderType.claude,
        modelId: 'claude-haiku-5-5',
        messages: <ChatMessage>[userMsg],
        systemInstruction: 'Be helpful',
        responseLanguage: VoiceLanguage.english,
      ),
      apiKey: 'sk-ant-test',
    );
    expect(jsonEncode(capturedClaude), contains('"type":"base64"'));
  });

  test('v1.2 InternetResearchService detects triggers, parses DuckDuckGo + Wikipedia, and deduplicates sources', () async {
    expect(
      InternetResearchService.shouldAutoTriggerResearch(
        'research Flutter 3.40 release notes',
      ),
      isTrue,
    );
    expect(
      InternetResearchService.shouldAutoTriggerResearch('hello vision'),
      isFalse,
    );
    expect(
      InternetResearchService.normalizeQuery('search the web for Dart 3.14'),
      'Dart 3.14',
    );

    final mockHttp = MockClient((req) async {
      if (req.url.host.contains('duckduckgo')) {
        return http.Response(
          jsonEncode(<String, Object?>{
            'Heading': 'Flutter',
            'AbstractText': 'Flutter is an open-source UI SDK by Google.',
            'AbstractURL': 'https://flutter.dev',
            'RelatedTopics': [
              {
                'Text': 'Dart - Programming language for Flutter',
                'FirstURL': 'https://dart.dev',
              },
            ],
          }),
          200,
        );
      }
      return http.Response(
        jsonEncode(<Object?>[
          'Flutter',
          <String>['Flutter (software)'],
          <String>['Cross-platform UI framework'],
          <String>['https://en.wikipedia.org/wiki/Flutter_(software)'],
        ]),
        200,
      );
    });

    final service = InternetResearchService(mockHttp);
    final bundle = await service.search('research Flutter');
    expect(bundle.sources.length, 3);
    expect(bundle.buildPromptContext(), contains('[1] Flutter (flutter.dev)'));
    expect(bundle.buildPromptContext(), contains('en.wikipedia.org'));
  });

  testWidgets('v1.2 ChatMessageBubble renders clickable citation chips', (
    tester,
  ) async {
    String? tappedUrl;
    final msg = ChatMessage(
      id: 'a1',
      sender: MessageSender.assistant,
      content: 'Flutter is an open-source UI SDK [1].',
      createdAt: DateTime.now(),
      provider: AiProviderType.gemini,
      citations: const <ResearchSource>[
        ResearchSource(
          title: 'Flutter Official',
          url: 'https://flutter.dev',
          snippet: 'Build apps for any screen.',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatMessageBubble(
            message: msg,
            onCitationTap: (url) => tappedUrl = url,
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('[1] flutter.dev'), findsOneWidget);
    await tester.tap(find.text('[1] flutter.dev'));
    expect(tappedUrl, 'https://flutter.dev');
  });
}
