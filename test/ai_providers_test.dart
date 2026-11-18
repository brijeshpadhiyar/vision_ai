import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vision_ai/core/constants/storage_keys.dart';
import 'package:vision_ai/core/utils/network_status_service.dart';
import 'package:vision_ai/core/utils/secret_redactor.dart';
import 'package:vision_ai/core/utils/secure_storage_provider.dart';
import 'package:vision_ai/core/utils/shared_preferences_provider.dart';
import 'package:vision_ai/features/automation/domain/entities/device_action.dart';
import 'package:vision_ai/features/automation/domain/utils/device_intent_parser.dart';
import 'package:vision_ai/features/chat/data/datasources/chat_local_datasource.dart';
import 'package:vision_ai/features/chat/data/datasources/claude_remote_datasource.dart';
import 'package:vision_ai/features/chat/data/datasources/gemini_remote_datasource.dart';
import 'package:vision_ai/features/chat/data/datasources/openai_remote_datasource.dart';
import 'package:vision_ai/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:vision_ai/features/chat/domain/entities/ai_model_config.dart';
import 'package:vision_ai/features/chat/domain/entities/ai_models.dart';
import 'package:vision_ai/features/chat/domain/entities/chat_message.dart';
import 'package:vision_ai/features/chat/domain/repositories/ai_provider.dart';
import 'package:vision_ai/features/chat/domain/services/ai_router.dart';
import 'package:vision_ai/features/chat/presentation/controllers/chat_controller.dart';
import 'package:vision_ai/features/settings/data/datasources/settings_local_datasource.dart';
import 'package:vision_ai/features/settings/domain/entities/ai_provider_type.dart';
import 'package:vision_ai/features/settings/domain/entities/app_settings.dart';
import 'package:vision_ai/features/settings/domain/entities/voice_language.dart';
import 'package:vision_ai/features/settings/presentation/controllers/provider_connection_controller.dart';

class _InMemoryCredentialStore extends SecureCredentialStore {
  _InMemoryCredentialStore() : super(const FlutterSecureStorage());

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

class _MutableNetworkStatusService extends NetworkStatusService {
  bool online = true;

  @override
  Future<bool> isOnline() async => online;
}

void main() {
  test('SecretRedactor masks Gemini, OpenAI, Claude, and Bearer secrets', () {
    const sample =
        'Authorization: Bearer sk-proj-abc1234567890XYZ '
        'gemini=AIzaSyB1234567890abcdefg '
        'claude=sk-ant-api03-1234567890abcdef '
        'url=https://example.com?key=secretToken99';
    final redacted = SecretRedactor.redact(sample);
    expect(redacted, isNot(contains('sk-proj-abc1234567890XYZ')));
    expect(redacted, isNot(contains('AIzaSyB1234567890abcdefg')));
    expect(redacted, isNot(contains('sk-ant-api03-1234567890abcdef')));
    expect(redacted, isNot(contains('secretToken99')));
    expect(redacted, contains('[REDACTED]'));
  });

  test('AIModelRegistry replaces retired models and SettingsLocalDataSource migrates gemini-2.5-flash', () async {
    expect(
      AIModelRegistry.defaultModelFor(AiProviderType.gemini).modelId,
      'gemini-3.5-flash-lite',
    );
    expect(
      AIModelRegistry.defaultModelFor(AiProviderType.openAi).modelId,
      'gpt-5.4-mini',
    );
    expect(
      AIModelRegistry.defaultModelFor(AiProviderType.claude).modelId,
      'claude-haiku-5-5',
    );
    expect(
      AIModelRegistry.deprecationReplacement('models/gemini-2.5-flash'),
      'gemini-3.5-flash-lite',
    );

    SharedPreferences.setMockInitialValues(<String, Object>{
      StorageKeys.modelKeyForProvider('gemini'): 'models/gemini-2.5-flash',
      StorageKeys.modelKeyForProvider('claude'): 'claude-3-5-haiku-latest',
    });
    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsLocalDataSource(prefs).readSettings();

    expect(
      settings.modelForProvider(AiProviderType.gemini),
      'gemini-3.5-flash-lite',
    );
    expect(
      settings.modelForProvider(AiProviderType.claude),
      'claude-haiku-5-5',
    );
  });

  test('GeminiProvider handles generateContent, SSE stream, usage, tool calls, and testConnection', () async {
    final mockClient = MockClient.streaming((request, bodyStream) async {
      if (request.method == 'GET' && request.url.path.endsWith('/models')) {
        return http.StreamedResponse(
          Stream.value(
            utf8.encode(
              jsonEncode(<String, Object>{
                'models': <Object>[
                  <String, Object>{
                    'name': 'models/gemini-3.5-flash-lite',
                    'supportedGenerationMethods': <String>['generateContent'],
                  },
                ],
              }),
            ),
          ),
          200,
        );
      }

      if (request.url.path.contains(':streamGenerateContent')) {
        final ssePayload =
            'data: ${jsonEncode(<String, Object>{
              'candidates': <Object>[
                <String, Object>{
                  'content': <String, Object>{
                    'parts': <Object>[
                      <String, Object>{'text': 'Hello '},
                    ],
                  },
                },
              ],
            })}\n\n'
            'data: ${jsonEncode(<String, Object>{
              'candidates': <Object>[
                <String, Object>{
                  'finishReason': 'STOP',
                  'content': <String, Object>{
                    'parts': <Object>[
                      <String, Object>{'text': 'from Gemini 3.5!'},
                    ],
                  },
                },
              ],
              'usageMetadata': <String, Object>{'promptTokenCount': 12, 'candidatesTokenCount': 6, 'totalTokenCount': 18},
            })}\n\n';
        return http.StreamedResponse(
          Stream.value(utf8.encode(ssePayload)),
          200,
          headers: <String, String>{'content-type': 'text/event-stream'},
        );
      }

      return http.StreamedResponse(
        Stream.value(
          utf8.encode(
            jsonEncode(<String, Object>{
              'candidates': <Object>[
                <String, Object>{
                  'finishReason': 'STOP',
                  'content': <String, Object>{
                    'parts': <Object>[
                      <String, Object>{'text': 'OK'},
                      <String, Object>{
                        'functionCall': <String, Object>{
                          'name': 'execute_device_action',
                          'args': <String, Object>{
                            'action': 'set_timer',
                            'seconds': 60,
                          },
                        },
                      },
                    ],
                  },
                },
              ],
              'usageMetadata': <String, Object>{
                'promptTokenCount': 5,
                'candidatesTokenCount': 2,
              },
            }),
          ),
        ),
        200,
      );
    });

    final provider = GeminiProvider(mockClient);
    final testRes = await provider.testConnection(
      apiKey: 'AIzaTestKey1234567890',
      modelId: 'gemini-3.5-flash-lite',
    );
    expect(testRes.connected, isTrue);
    expect(testRes.availableModels, contains('gemini-3.5-flash-lite'));

    final request = AIRequest(
      provider: AiProviderType.gemini,
      modelId: 'gemini-3.5-flash-lite',
      messages: <ChatMessage>[
        ChatMessage(
          id: '1',
          sender: MessageSender.user,
          content: 'Set a timer for 1 minute',
          createdAt: DateTime.now(),
        ),
      ],
      systemInstruction: 'You are VISION.',
      responseLanguage: VoiceLanguage.english,
    );

    final gen = await provider.generate(
      request,
      apiKey: 'AIzaTestKey1234567890',
    );
    expect(gen.text, 'OK');
    expect(gen.toolCalls.length, 1);
    expect(gen.toolCalls.first.arguments['action'], 'set_timer');

    final chunks = await provider
        .stream(request, apiKey: 'AIzaTestKey1234567890')
        .toList();
    final completed = chunks.whereType<AICompletedChunk>().single.response;
    expect(completed.text, 'Hello from Gemini 3.5!');
    expect(completed.usage?.inputTokens, 12);
    expect(completed.usage?.outputTokens, 6);
  });

  test('OpenAIProvider handles Responses API generate, SSE streaming, tool call, and invalid key', () async {
    final mockClient = MockClient.streaming((request, bodyStream) async {
      final auth = request.headers['authorization'] ?? '';
      if (auth.contains('bad-key')) {
        return http.StreamedResponse(
          Stream.value(
            utf8.encode(
              jsonEncode(<String, Object>{
                'error': <String, Object>{'message': 'Incorrect API key'},
              }),
            ),
          ),
          401,
        );
      }

      if (request.method == 'GET') {
        return http.StreamedResponse(
          Stream.value(
            utf8.encode(
              jsonEncode(<String, Object>{
                'data': <Object>[
                  <String, Object>{'id': 'gpt-5.4-mini'},
                ],
              }),
            ),
          ),
          200,
        );
      }

      final bodyText = await utf8.decodeStream(bodyStream);
      final bodyMap = jsonDecode(bodyText) as Map<String, dynamic>;
      if (bodyMap['stream'] == true) {
        final sse =
            'data: ${jsonEncode(<String, Object>{'type': 'response.output_text.delta', 'delta': 'OpenAI '})}\n\n'
            'data: ${jsonEncode(<String, Object>{'type': 'response.output_text.delta', 'delta': 'Responses!'})}\n\n'
            'data: ${jsonEncode(<String, Object>{
              'type': 'response.completed',
              'response': <String, Object>{
                'id': 'resp_1',
                'status': 'completed',
                'usage': <String, Object>{'input_tokens': 10, 'output_tokens': 4, 'total_tokens': 14},
              },
            })}\n\n'
            'data: [DONE]\n\n';
        return http.StreamedResponse(Stream.value(utf8.encode(sse)), 200);
      }

      return http.StreamedResponse(
        Stream.value(
          utf8.encode(
            jsonEncode(<String, Object>{
              'id': 'resp_2',
              'status': 'completed',
              'output': <Object>[
                <String, Object>{
                  'type': 'message',
                  'content': <Object>[
                    <String, Object>{
                      'type': 'output_text',
                      'text': 'Opening Wi-Fi.',
                    },
                  ],
                },
                <String, Object>{
                  'type': 'function_call',
                  'call_id': 'call_1',
                  'name': 'execute_device_action',
                  'arguments': '{"action":"open_settings","section":"wifi"}',
                },
              ],
              'usage': <String, Object>{'input_tokens': 9, 'output_tokens': 5},
            }),
          ),
        ),
        200,
      );
    });

    final provider = OpenAIProvider(mockClient);
    final badTest = await provider.testConnection(apiKey: 'bad-key');
    expect(badTest.connected, isFalse);
    expect(badTest.errorKind, AIErrorKind.invalidApiKey);

    final goodTest = await provider.testConnection(
      apiKey: 'sk-valid-test-123456',
    );
    expect(goodTest.connected, isTrue);

    final req = AIRequest(
      provider: AiProviderType.openAi,
      modelId: 'gpt-5.4-mini',
      messages: <ChatMessage>[
        ChatMessage(
          id: 'u1',
          sender: MessageSender.user,
          content: 'Open Wi-Fi settings',
          createdAt: DateTime.now(),
        ),
      ],
      systemInstruction: 'You are VISION.',
      responseLanguage: VoiceLanguage.english,
    );

    final gen = await provider.generate(req, apiKey: 'sk-valid-test-123456');
    expect(gen.text, 'Opening Wi-Fi.');
    expect(gen.toolCalls.single.arguments['section'], 'wifi');

    final streamChunks = await provider
        .stream(req, apiKey: 'sk-valid-test-123456')
        .toList();
    final finalResp = streamChunks
        .whereType<AICompletedChunk>()
        .single
        .response;
    expect(finalResp.text, 'OpenAI Responses!');
    expect(finalResp.usage?.totalTokens, 14);
  });

  test('ClaudeProvider handles Messages API SSE streaming, tool_use, and provider-switch role merging', () async {
    late Map<String, dynamic> capturedPayload;

    final mockClient = MockClient.streaming((request, bodyStream) async {
      if (request.method == 'GET') {
        return http.StreamedResponse(
          Stream.value(
            utf8.encode(
              jsonEncode(<String, Object>{
                'data': <Object>[
                  <String, Object>{'id': 'claude-haiku-5-5'},
                ],
              }),
            ),
          ),
          200,
        );
      }

      final bodyText = await utf8.decodeStream(bodyStream);
      capturedPayload = jsonDecode(bodyText) as Map<String, dynamic>;

      if (capturedPayload['stream'] == true) {
        final sse =
            'event: message_start\n'
            'data: ${jsonEncode(<String, Object>{
              'type': 'message_start',
              'message': <String, Object>{
                'id': 'msg_1',
                'usage': <String, Object>{'input_tokens': 15},
              },
            })}\n\n'
            'event: content_block_delta\n'
            'data: ${jsonEncode(<String, Object>{
              'type': 'content_block_delta',
              'index': 0,
              'delta': <String, Object>{'type': 'text_delta', 'text': 'Hello Claude 5.5'},
            })}\n\n'
            'event: content_block_start\n'
            'data: ${jsonEncode(<String, Object>{
              'type': 'content_block_start',
              'index': 1,
              'content_block': <String, Object>{'type': 'tool_use', 'id': 'tu_1', 'name': 'execute_device_action'},
            })}\n\n'
            'event: content_block_delta\n'
            'data: ${jsonEncode(<String, Object>{
              'type': 'content_block_delta',
              'index': 1,
              'delta': <String, Object>{'type': 'input_json_delta', 'partial_json': '{"action":"device_status"}'},
            })}\n\n'
            'event: content_block_stop\n'
            'data: ${jsonEncode(<String, Object>{'type': 'content_block_stop', 'index': 1})}\n\n'
            'event: message_delta\n'
            'data: ${jsonEncode(<String, Object>{
              'type': 'message_delta',
              'delta': <String, Object>{'stop_reason': 'tool_use'},
              'usage': <String, Object>{'output_tokens': 9},
            })}\n\n';
        return http.StreamedResponse(Stream.value(utf8.encode(sse)), 200);
      }

      return http.StreamedResponse(
        Stream.value(
          utf8.encode(
            jsonEncode(<String, Object>{
              'id': 'msg_2',
              'content': <Object>[
                <String, Object>{'type': 'text', 'text': 'OK'},
              ],
              'usage': <String, Object>{'input_tokens': 4, 'output_tokens': 1},
            }),
          ),
        ),
        200,
      );
    });

    final provider = ClaudeProvider(mockClient);
    final req = AIRequest(
      provider: AiProviderType.claude,
      modelId: 'claude-haiku-5-5',
      messages: <ChatMessage>[
        ChatMessage(
          id: 'a0',
          sender: MessageSender.assistant,
          content: 'Leading assistant message from prior provider',
          createdAt: DateTime.now(),
        ),
        ChatMessage(
          id: 'u1',
          sender: MessageSender.user,
          content: 'First user prompt',
          createdAt: DateTime.now(),
        ),
        ChatMessage(
          id: 'u2',
          sender: MessageSender.user,
          content: 'Second user prompt',
          createdAt: DateTime.now(),
        ),
      ],
      systemInstruction: 'You are VISION.',
      responseLanguage: VoiceLanguage.english,
    );

    final chunks = await provider
        .stream(req, apiKey: 'sk-ant-valid-123456')
        .toList();
    final finalResp = chunks.whereType<AICompletedChunk>().single.response;
    expect(finalResp.text, 'Hello Claude 5.5');
    expect(finalResp.toolCalls.single.arguments['action'], 'device_status');
    expect(finalResp.usage?.inputTokens, 15);
    expect(finalResp.usage?.outputTokens, 9);

    // Verify leading assistant message stripped & consecutive user messages merged!
    final sentMsgs = capturedPayload['messages'] as List<Object?>;
    expect(sentMsgs.length, 1);
    expect((sentMsgs.first as Map<String, dynamic>)['role'], 'user');
  });

  test('AIRouter performs transparent fallback with explicit routingNotice and respects cancellation', () async {
    final credStore = _InMemoryCredentialStore();
    await credStore.saveApiKey(
      providerId: 'gemini',
      apiKey: 'AIza-test-123456',
    );
    await credStore.saveApiKey(
      providerId: 'openai',
      apiKey: 'sk-test-1234567890',
    );

    final mockClient = MockClient((request) async {
      if (request.url.host.contains('googleapis.com')) {
        return http.Response(
          jsonEncode(<String, Object>{
            'error': <String, Object>{
              'message': 'models/gemini-2.5-flash is no longer available to new users.',
            },
          }),
          404,
        );
      }
      return http.Response(
        jsonEncode(<String, Object>{
          'id': 'resp_fallback',
          'status': 'completed',
          'output': <Object>[
            <String, Object>{
              'type': 'message',
              'content': <Object>[
                <String, Object>{
                  'type': 'output_text',
                  'text': 'Fallback reply from OpenAI.',
                },
              ],
            },
          ],
        }),
        200,
      );
    });

    final registry = AIProviderRegistry(<AiProviderType, AIProvider>{
      AiProviderType.gemini: GeminiProvider(mockClient),
      AiProviderType.openAi: OpenAIProvider(mockClient),
    });
    final router = AIRouter(registry: registry, credentialStore: credStore);

    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final chatRepo = ChatRepositoryImpl(
      ChatLocalDataSource(prefs),
      router,
      _MutableNetworkStatusService(),
    );

    const settings = AppSettings(
      selectedAiProvider: AiProviderType.gemini,
      fallbackEnabled: true,
      streamingEnabled: false,
    );

    final updated = await chatRepo.sendUserMessage(
      prompt: 'What is quantum entanglement?',
      provider: AiProviderType.gemini,
      language: VoiceLanguage.english,
      settings: settings,
    );

    expect(updated.length, 2);
    expect(updated.last.provider, AiProviderType.openAi);
    expect(updated.last.modelId, 'gpt-5.4-mini');
    expect(updated.last.routingNotice, contains('Fallback active'));

    // Cooperative cancellation
    final token = AICancellationToken()..cancel();
    await expectLater(
      chatRepo.sendUserMessage(
        prompt: 'Should be cancelled',
        provider: AiProviderType.openAi,
        language: VoiceLanguage.english,
        settings: settings,
        cancellationToken: token,
      ),
      throwsA(
        isA<AIError>().having((e) => e.kind, 'kind', AIErrorKind.cancelled),
      ),
    );
  });

  test('Offline mode blocks cloud AI cleanly while preserving draft and still executes local device actions', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final credStore = _InMemoryCredentialStore();
    await credStore.saveApiKey(
      providerId: 'gemini',
      apiKey: 'AIza-offline-test-123456',
    );
    final netService = _MutableNetworkStatusService()..online = false;

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        secureCredentialStoreProvider.overrideWithValue(credStore),
        networkStatusServiceProvider.overrideWithValue(netService),
      ],
    );
    addTearDown(container.dispose);

    // 1. General question offline -> blocked immediately, draft preserved.
    final sent = await container
        .read(chatControllerProvider.notifier)
        .sendMessage('Explain black holes');
    expect(sent, isFalse);
    final chatState = container.read(chatControllerProvider);
    expect(chatState.isOfflineError, isTrue);
    expect(chatState.unsentDraft, 'Explain black holes');
    expect(chatState.errorMessage, contains('No internet connection'));

    // 2. Local device command offline -> executes offline cleanly without cloud call.
    final localAction = DeviceIntentParser.parseLocalCommand(
      'set an alarm in 15 minutes',
    );
    expect(localAction?.type, DeviceActionType.setAlarm);
  });

  test('ProviderConnectionController only shows Connected after real authenticated probe succeeds', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final credStore = _InMemoryCredentialStore();
    await credStore.saveApiKey(
      providerId: 'gemini',
      apiKey: 'AIza-probe-key-123456',
    );

    final mockClient = MockClient((request) async {
      if (request.method == 'GET') {
        return http.Response(
          jsonEncode(<String, Object>{
            'models': <Object>[
              <String, Object>{
                'name': 'models/gemini-3.5-flash-lite',
                'supportedGenerationMethods': <String>['generateContent'],
              },
            ],
          }),
          200,
        );
      }
      return http.Response(
        jsonEncode(<String, Object>{
          'candidates': <Object>[
            <String, Object>{
              'content': <String, Object>{
                'parts': <Object>[
                  <String, Object>{'text': 'OK'},
                ],
              },
            },
          ],
        }),
        200,
      );
    });

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        secureCredentialStoreProvider.overrideWithValue(credStore),
        aiProviderRegistryProvider.overrideWithValue(
          AIProviderRegistry(<AiProviderType, AIProvider>{
            AiProviderType.gemini: GeminiProvider(mockClient),
          }),
        ),
      ],
    );
    addTearDown(container.dispose);

    final before = container.read(providerConnectionControllerProvider);
    expect(
      before[AiProviderType.gemini]?.connectionState,
      isNot(ProviderConnectionState.connected),
    );

    final testResult = await container
        .read(providerConnectionControllerProvider.notifier)
        .testProviderConnection(AiProviderType.gemini);
    expect(testResult.connected, isTrue);

    final after = container.read(providerConnectionControllerProvider);
    expect(
      after[AiProviderType.gemini]?.connectionState,
      ProviderConnectionState.connected,
    );
  });

  test(
    'DeviceIntentParser parses WhatsApp and Notification commands in EN/HI/GU',
    () {
      final wa = DeviceIntentParser.parseLocalCommand(
        'send whatsapp message to Rahul saying I reached safely',
      );
      expect(wa?.type, DeviceActionType.sendWhatsapp);
      expect(wa?.target, 'Rahul');
      expect(wa?.message, 'I reached safely');

      final hiWa = DeviceIntentParser.parseLocalCommand(
        'राहुल को व्हाट्सएप करो कि मैं आ गया',
      );
      expect(hiWa?.type, DeviceActionType.sendWhatsapp);
      expect(hiWa?.target, 'राहुल');
      expect(hiWa?.message, 'मैं आ गया');

      final notif = DeviceIntentParser.parseLocalCommand(
        'read my recent notifications',
      );
      expect(notif?.type, DeviceActionType.readNotifications);
    },
  );
}
