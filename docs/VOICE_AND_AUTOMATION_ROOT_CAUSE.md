# VISION AI — Voice, Intelligence, Automation & Liquid Glass Root Cause Analysis

Date: 2026-11-18  
Package ID: `com.brijesh.vision`  
Workspace: `c:\A1\vision_ai`

---

## Executive Summary

A full-stack audit of VISION AI across its native Android Kotlin layer (`VisionVoiceChannel.kt`, `VisionWakeWordService.kt`, `VisionVoiceInteractionSession.kt`, `AssistantOverlayActivity.kt`, `VisionAutomationChannel.kt`, `MainActivity.kt`, `vision_assistant_overlay.xml`) and Flutter/Dart layers (`VoiceController`, `VoiceSessionState`, `CommandNormalizer`, `EntityExtractor`, `IntentClassifier`, `IntentEngine`, `ContactResolver`, `AutomationController`, `ChatController`, `ChatRepositoryImpl`, `AIRouter`, `AIModelRegistry`, `AssistantExperienceScreen`, `AssistantHomeScreen`, `AutomationActionPromptCard`, `VisionGlass*`) identified the exact code-level root causes behind all nine reported failures.

---

## 1. Microphone Stopping During Pauses (CRITICAL)

### Observed Root Causes
1. **Single-shot Android `SpeechRecognizer` termination on short pauses**:
   - `VisionVoiceChannel.kt` (`startSpeechListening`, lines 314–348) configures a single `SpeechRecognizer` request with `EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS = 1800L`, `EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS = 1400L`, and `EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS = 1200L`.
   - On real Android devices (especially Google Speech Services and ColorOS), `SpeechRecognizer` frequently ignores or clamps those extras and fires `onEndOfSpeech()` after ~1–1.5s of natural mid-sentence pause (e.g., `"Hey VISION... [pause] ...please call... [pause] ...Soel Kht."`).
2. **Immediate session teardown in `onEndOfSpeech()` and `onResults()`**:
   - `VisionVoiceChannel.kt` (`onEndOfSpeech`, lines 418–421) immediately flips `isListening = false` and emits a `"state"` event before speech is finalized.
   - `onResults()` (lines 437–470) emits `"isFinal": true` for only that first short segment and resumes `VisionWakeWordService`.
   - `VoiceController._handleVoiceEvent` (`lib/features/voice/presentation/controllers/voice_controller.dart`, lines 114–116) immediately dispatches `_processFinalTranscript(text)` on that partial utterance fragment.
3. **Wake-word prefix gap & premature dispatch**:
   - In `VoiceController._processFinalTranscript` (lines 172–212), if the user says `"Hey VISION"` and pauses before `"please call..."`:
     - In `listeningWakeWord` mode, it restarts `startCommandListening()`, creating a gap during recognizer re-creation where the next words are lost.
     - In normal command mode, `WakeWordDetector.evaluate(trimmed)` only strips the wake prefix when `match.trailingCommand.isNotEmpty`, so `"Hey VISION"` alone is forwarded to `ChatController` as an AI query.
4. **`VisionVoiceInteractionSession.kt` shares the same single-shot bug**:
   - `VisionVoiceInteractionSession.kt` (lines 123–162, 198–235) uses identical 1800ms/1400ms hints, stops immediately on `onEndOfSpeech()` / `onResults()`, and launches `AssistantOverlayActivity` on the first fragment.
5. **Missing explicit voice state machine**:
   - `VoiceListeningPhase` (`lib/features/voice/domain/entities/voice_session_state.dart`) lacks `partialTranscription`, `endpointing`, `finalizing`, and `cancelled` states, and manual completion (`stopListening`) vs cancellation (`cancelListening`) do not flush/preserve accumulated segments cleanly.
6. **Wake-word listener ownership conflict on overlay launch**:
   - `AssistantOverlayActivity.kt` instantiates a second `VisionVoiceChannel` which overwrites `VisionWakeWordService.listener = this` (`VisionVoiceChannel.kt` line 64). When `AssistantOverlayActivity` closes (`onDestroy`), `MainActivity`'s `VisionVoiceChannel` never reclaims the listener.

---

## 2. Incorrect Speech Transcription

### Observed Root Causes
1. **Partial results drop alternatives**:
   - `VisionVoiceChannel.kt` (`onPartialResults`, lines 472–485) emits only `matches?.firstOrNull()` and does not accumulate confirmed segments across pauses.
2. **Alternative ASR hypotheses discarded before intent/contact resolution**:
   - `VisionVoiceChannel.kt` (`onResults`, lines 441–468) sends `hypotheses` (`RESULTS_RECOGNITION`) to Dart and `VoiceController` stores them in `VoiceSessionState.alternativeTranscripts`, **but `VoiceController._dispatchVoiceCommandToAi` (line 246) only passes `commandText` (`String`) to `ChatController.sendMessage(commandText)`**.
   - Neither `IntentEngine.analyze()` nor `AutomationController._resolveContactForAction()` receives `alternativeTranscripts`.
3. **No multi-language / hint optimization**:
   - `VisionVoiceChannel.kt` sends a single `EXTRA_LANGUAGE` without extra language preference/offline support metadata or session telemetry for STT segment count and duration.
4. **Original transcript diagnostics gap**:
   - `VoiceSessionState.originalTranscript` is stored in `VoiceController`, but not propagated to `IntentResolution` / `DiagnosticsScreen` when normalization or hypothesis selection occurs.

---

## 3. Incorrect Spelling and Pronunciation Understanding

### Observed Root Causes
1. **Incomplete Unicode and script normalization**:
   - `CommandNormalizer.normalize` (`lib/core/intelligence/command_normalizer.dart`) normalizes Indic digits and curly quotes, but does not strip zero-width joiners/BOM (`\u200B-\u200D\uFEFF`) or normalize Indic Devanagari/Gujarati phonetic variants (e.g., `ऑ`/`ओ`, `ऍ`/`ए`, nukta consonants, anusvara).
2. **Incomplete command-specific phonetic/spelling normalization**:
   - `CommandNormalizer._spellingFixes` and `_applyCommandPhraseFixes` miss real ASR variants such as `"cal Tisha"` (`cal` -> `call`), `"kol"`, `"fone"`, `"watsup"`, `"whatsup"`, `"alam"`, `"timar"`, `"savar"`, `"baje"`/`"vaje"`.
   - `"kal savare 7 vage"` (time + day without the explicit word `"alarm"`) fails `IntentClassifier._classifyAlarm` (line 390), because `_classifyAlarm` requires `\balarm\b|अलार्म|अलाउम|અલાર્મ|એલાર્મ`.
   - `CommandNormalizer.splitSequentialClauses` (line 303) runs on `strippedPunctuation` **before** `_spellingFixes` and `_applyCommandPhraseFixes`, missing clause detection when command words were misspelled.
3. **`EntityExtractor` bypasses `canonicalText` in contact/message extraction**:
   - `EntityExtractor.extractContact` (line 264) and `extractMessageTargets` (line 572) match regexes against `cmd.cleanedText` rather than also leveraging normalized command tokens, causing ASR typos in verbs (`"cal Tisha"`, `"watsapp Rahul"`) to fail extraction.
4. **Over-aggressive `phone` / `whatsapp` matching on informational questions**:
   - `IntentClassifier._classifyCallOrContact` (line 629) matches bare `\bphone\b`, causing general queries like `"which phone is best"` or `"my phone is slow"` to trigger `call_phone` clarification (`"Who would you like me to call?"`).
   - `IntentClassifier._classifyWhatsApp` (lines 546–585) matches bare `\bwhatsapp\b` for any phrase other than `"open whatsapp"`, causing `"what is whatsapp"` or `"tell me about whatsapp"` to trigger `send_whatsapp`!

---

## 4. Contact-Name Recognition Failures

### Observed Root Causes
1. **600-row cursor truncation in `VisionAutomationChannel.kt`**:
   - `handleGetAllContacts` (`VisionAutomationChannel.kt`, line 466) stops at `contacts.size < 600` while iterating alphabetically by `DISPLAY_NAME`. On real Android devices with WhatsApp/Google/SIM contact rows exceeding 600 entries, contacts later in the alphabet (e.g., `"Soel Kht"`, `"Tisha"`) are silently omitted from `getAllContacts()` and invisible to `ContactResolver`!
2. **Alternative ASR hypotheses never forwarded to `ContactResolver`**:
   - `AutomationController._resolveContactForAction` (line 618) calls `contactResolver.resolve(primaryQuery: request.target)` without passing `alternativeQueries` extracted from ASR hypotheses.
3. **Single-token / partial phonetic name gaps & alias matching**:
   - `ContactAliasRepository.resolveAliasForQuery` (line 116) only performs exact `a.normalizedPhrase == normalized` matching and does not check `alternativeQueries` or expose alias management in Settings/Automation UI.
4. **Medium-confidence confirmation UX & `"No"` handling bugs**:
   - `AutomationActionPromptCard` (`lib/features/automation/presentation/widgets/automation_action_prompt_card.dart`, lines 112–184) renders both the `"Yes, Confirm" / "Yes & Save Alias"` row AND a duplicate full-width `"Confirm"` button underneath when `isSuggestionConfirm` is true.
   - `AssistantHomeScreen`, `ChatScreen`, and `AutomationScreen` omit `onConfirmAndSaveAlias` when rendering `AutomationActionPromptCard`.
   - `IntentClassifier._isCancelPendingAction` (line 258) omits `"no"`, `"nope"`, `"wrong"`, `"nahi"`, `"na"`, so saying `"No"` to `"Did you mean Soel Kht?"` escapes to the cloud AI instead of cancelling.

---

## 5. Incorrect Command Interpretation

### Observed Root Causes
1. **`ConversationIntelligenceContext.pendingClarificationIntentId` is dead state**:
   - `ChatController.sendMessage` (lines 144–148) records `pendingClarificationIntentId` when asking `"What time would you like me to set the alarm for?"`, `"Who would you like me to call?"`, `"How long should the timer run?"`, or `"Which app would you like me to open?"`.
   - Neither `IntentEngine.analyze` nor `IntentClassifier.classifyClause` ever reads `context.pendingClarificationIntentId`! Follow-up answers like `"7 AM"`, `"5 minutes"`, or `"Soel Kht"` fall through to the cloud LLM instead of completing the local command.
2. **Narrow `_informationalQuestionGuard`**:
   - `IntentClassifier._informationalQuestionGuard` (line 27) misses `"which ..."`, `"who ..."`, `"tell me ..."`, `"what is <noun>"` (without article `a/an/the`), `"can you explain ..."`, `"how much ..."`, `"is <app> ..."`, allowing general questions containing `"phone"`, `"whatsapp"`, `"alarm"`, or `"timer"` to misfire local device intents.
3. **Multi-hypothesis recovery missing in `IntentEngine`**:
   - If the top ASR hypothesis fails local intent classification (or has low confidence), alternative ASR hypotheses from `SpeechRecognizer` are never checked.

---

## 6. Slow AI Responses

### Observed Root Causes
1. **Per-turn Keystore & Network IPC overhead before request dispatch**:
   - `ChatRepositoryImpl.streamUserMessage` (lines 242–263) awaits `NetworkStatusService.isOnline()` (MethodChannel IPC to `VisionAutomationChannel`) AND sequentially awaits `FlutterSecureStorage.readApiKey()` for every fallback provider in `AIRouter.resolveCandidates` (lines 106–112) on every single chat turn, adding 60–200ms+ before the HTTP connection even opens.
2. **Heavy tool schema & `maxOutputTokens` sent on simple/conversational prompts**:
   - `AiCompletionRequest` always attaches the full `execute_device_action` JSON schema (`tools`) and `maxOutputTokens = 1024` even for `TaskComplexityTier.simpleFast` queries where local deterministic parsing already handled device commands and the user only needs a short factual answer.
3. **Duplicate request & stale timeout handling**:
   - `ChatController` guards `state.isLoading`, but does not guard identical rapid duplicate voice dispatches right after completion (cooldown dedup), and `AiHttpHelper.streamSse` waits the full 45s `aiRequestTimeout` before first-byte timeout instead of using a tighter connection/first-byte timeout.
4. **Stage-level measurement gaps**:
   - `TelemetryNotifier` lacks dedicated `localExecutionMs` / `intentRecognitionMicros` breakdown in voice diagnostics export and doesn't track per-utterance STT segment count or endpointing latency.

---

## 7. Failed Android Automation

### Observed Root Causes
1. **Multi-step confirmation drops `followUpActions`**:
   - `AutomationController._handlePhoneCallRequest` (line 505) and `_resolveContactForAction` (line 630) construct a brand-new `DeviceActionRequest` for `pendingConfirmation` without preserving `request.followUpActions`. Confirming Step 1 in `"Call Mom and turn on flashlight"` silently discards Step 2.
   - In `AutomationController.executeRequest` (lines 219–233), if Step 2 returns `confirmationRequired` (`success: false`), the loop labels it `"Step 2 failed: Did you mean ...?"` instead of surfacing `confirmationRequired` cleanly.
2. **`setAlarm` drops `isTomorrow` / `EXTRA_DAYS`**:
   - `IntentEngine` / `EntityExtractor` parses `isTomorrow`, but `AutomationController`, `AutomationPlatformDataSource`, and `VisionAutomationChannel.handleSetAlarm` never pass `isTomorrow` or set `AlarmClock.EXTRA_DAYS` for next-day alarms.
3. **Missing `try/catch` in `handleLaunchApp` direct package launch**:
   - `VisionAutomationChannel.kt` line 727 calls `activity.startActivity(directIntent)` without catching `ActivityNotFoundException` or `SecurityException`.
4. **`handleGetAllContacts` 600-contact limit** (see Section 4).
5. **Action cancellation only clears `AutomationState`**:
   - `cancelPendingAction` / `cancel_action` does not stop active TTS or in-flight AI streams when invoked globally.

---

## 8. Incomplete Direct Assistant Interface

### Observed Root Causes
1. **`VisionVoiceInteractionSession.kt` forces cold-boot redirect instead of direct interactive feedback**:
   - `VisionVoiceInteractionSession` discards `initialHypotheses` (never consumed by `AssistantOverlayActivity.kt`), never uses its initialized `TextToSpeech` instance, has no multi-segment pause-tolerant listening, and forces `AssistantOverlayActivity` launch on every result.
2. **Incomplete voice phase controls in `AssistantExperienceScreen.dart`**:
   - `AssistantExperienceScreen` does not expose distinct visual states or controls for `partialTranscription`, `endpointing` (with manual **Done** action), `finalizing`, and `cancelled`, nor does it show alternative ASR hypotheses or original vs normalized transcript indicators.
   - `VisionShellScaffold` and `AssistantHomeScreen` push `AppRoutes.assistantPath` without `listen=1`, forcing an extra tap when opening Assistant mode directly.

---

## 9. Inconsistent Liquid Glass UI

### Observed Root Causes
1. **Split glass styling implementations**:
   - `VisionGlass.decoration()` defines tokenized gradients and borders, while `VisionGlassDialog`, `VisionGlassBottomSheet`, `VisionGlassAppBar`, `AssistantMicButton`, `ChatInputBar`, and `SettingsTile` hardcode separate opacity formulas and foreground colors (`VisionColors.backgroundPrimary` hardcoded in `AssistantMicButton` and `ChatInputBar` even in light mode).
2. **Duplicate confirmation button in `AutomationActionPromptCard`**:
   - When `isSuggestionConfirm` is true, `AutomationActionPromptCard` renders both the `"Yes, Confirm" / "Yes & Save Alias"` row and an extra full-width `"Confirm"` button right below it.
3. **Double horizontal padding in `DiagnosticsScreen`**:
   - `DiagnosticsScreen` passes `padding: VisionSpacing.screenPadding` to `ListView` inside `VisionScaffold` (which already applies horizontal padding).
4. **Native overlay (`vision_assistant_overlay.xml`) lacks state-driven glass feedback**:
   - Uses static opaque dark background (`#FA050812`) with plain `Button` text and no state-colored badge/orb/endpointing controls matching Flutter's Liquid Glass design system.
