import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vision_ai/core/intelligence/language_detector.dart';
import 'package:vision_ai/core/utils/shared_preferences_provider.dart';
import 'package:vision_ai/features/chat/domain/entities/ai_completion_request.dart';
import 'package:vision_ai/features/settings/domain/entities/ai_provider_type.dart';
import 'package:vision_ai/features/settings/domain/entities/assistant_identity.dart';
import 'package:vision_ai/features/settings/domain/entities/voice_language.dart';
import 'package:vision_ai/features/settings/presentation/controllers/settings_controller.dart';

void main() {
  test('Wave 2 AssistantIdentity persists and injects into AiCompletionRequest.systemInstruction', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    const custom = AssistantIdentity(
      personality: AssistantPersonality.professional,
      communicationStyle: CommunicationStyle.direct,
      customGreeting: 'Welcome back, Brijesh',
      customInstructions: 'Always reply in IST timezone.',
    );

    await container
        .read(settingsControllerProvider.notifier)
        .setAssistantIdentity(custom);

    final reloaded = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(reloaded.dispose);
    final loadedIdentity = reloaded
        .read(settingsControllerProvider)
        .assistantIdentity;

    expect(loadedIdentity, custom);
    expect(loadedIdentity.effectiveGreeting, 'Welcome back, Brijesh');

    final req = AiCompletionRequest(
      provider: AiProviderType.gemini,
      messages: const [],
      responseLanguage: VoiceLanguage.english,
      assistantIdentity: loadedIdentity,
    );
    expect(req.systemInstruction, contains('Personality (Professional)'));
    expect(
      req.systemInstruction,
      contains('Communication style (Direct & Brief)'),
    );
    expect(req.systemInstruction, contains('Always reply in IST timezone.'));
  });

  test('Wave 2 Voice Identity settings clamp and persist cleanly', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(settingsControllerProvider.notifier);
    await notifier.setTtsVoiceName('en-in-x-end-local');
    await notifier.setTtsSpeechRate(2.8); // clamps to 2.0
    await notifier.setTtsPitch(0.2); // clamps to 0.5

    final reloaded = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(reloaded.dispose);
    final loaded = reloaded.read(settingsControllerProvider);
    expect(loaded.ttsVoiceName, 'en-in-x-end-local');
    expect(loaded.ttsSpeechRate, 2.0);
    expect(loaded.ttsPitch, 0.5);
  });

  test('Wave 2 LanguageDetector detects English, Hindi, Gujarati, Hinglish, and Gujlish accurately', () {
    expect(
      LanguageDetector.detect('Set an alarm for 7 AM'),
      VoiceLanguage.english,
    );
    expect(
      LanguageDetector.detect('नमस्ते, आज का मौसम कैसा है?'),
      VoiceLanguage.hindi,
    );
    expect(
      LanguageDetector.detect('નમસ્તે, તમે કેમ છો?'),
      VoiceLanguage.gujarati,
    );
    expect(
      LanguageDetector.detect('namaste mujhe weather batao'),
      VoiceLanguage.hindi,
    );
    expect(
      LanguageDetector.detect('tame kem cho mane time boljo'),
      VoiceLanguage.gujarati,
    );

    // TTS language switching automatically matches native script even if configured=english
    expect(
      LanguageDetector.resolveTtsLanguage(
        'આજનું હવામાન સારું છે.',
        configuredLanguage: VoiceLanguage.english,
      ),
      VoiceLanguage.gujarati,
    );
    expect(
      LanguageDetector.resolveTtsLanguage(
        'आज का मौसम बहुत अच्छा है।',
        configuredLanguage: VoiceLanguage.auto,
      ),
      VoiceLanguage.hindi,
    );
  });
}
