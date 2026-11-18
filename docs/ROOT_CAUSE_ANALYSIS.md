# VISION AI — Complete Root Cause Analysis

Date: 2026-11-18  
Package ID: `com.brijesh.vision`  
Target Platform: Android (OPPO Reno 16 / ColorOS & stock Android)

---

## Executive Summary

End-to-end inspection of VISION AI's Kotlin native layer (`VisionVoiceChannel.kt`, `VisionWakeWordService.kt`, `VisionVoiceInteractionSession.kt`, `AssistantOverlayActivity.kt`, `VisionAutomationChannel.kt`, `vision_assistant_overlay.xml`) and Flutter domain/presentation layers (`VoiceController`, `IntentEngine`, `AutomationController`, `AIConversationManager`, `AiCompletionRequest`, `AIRouter`, `AssistantExperienceScreen`, `VisionAiOrb`) revealed exact code-level root causes behind all nine reported issues.

---

## Problem-by-Problem Diagnosis

### 1. Speech Recognition Is Not Accurate
- **Actual Root Cause:**
  - `VisionVoiceChannel.kt` (`onResults`) reads only `matches?.firstOrNull()` from `SpeechRecognizer.RESULTS_RECOGNITION` and discards alternative hypotheses (`matches[1..4]`), while ignoring `SpeechRecognizer.CONFIDENCE_SCORES` completely.
  - Background `VisionWakeWordService` audio lifecycle contention and unconfigured offline fallback hints reduce capture reliability.
  - `VisionVoiceInteractionSession.kt` (`startListening`) hardcodes `"en-IN"` instead of the user's selected locale and captures zero alternatives/confidence scores.
- **Relevant Files:**
  - `android/app/src/main/kotlin/com/brijesh/vision/VisionVoiceChannel.kt`
  - `android/app/src/main/kotlin/com/brijesh/vision/VisionVoiceInteractionSession.kt`
  - `lib/features/voice/domain/entities/voice_session_state.dart`
  - `lib/features/voice/presentation/controllers/voice_controller.dart`
- **Why Current Implementation Fails:** When ASR picks an imperfect 1-best candidate (e.g., `"Shohil Jht"` vs `"Soel Kht"` or `"Whats app"` vs `"WhatsApp"`), discarding `RESULTS_RECOGNITION` alternatives prevents downstream entity & contact resolution from recovering valid candidates.
- **Proposed Solution:** Forward all `RESULTS_RECOGNITION` hypotheses + `CONFIDENCE_SCORES` (explicitly nullable/uninvented when `-1` or absent on OEM engines) over `VoiceEvent`, preserve raw transcripts in telemetry/diagnostics without destructive mutation, evaluate hypotheses cleanly inside the speech/contact pipeline, and share user locale prefs into `VoiceInteractionSession`.
- **Required Test:** Unit tests verifying `VoiceTranscriptEvent` preserves `hypotheses` and nullable `confidenceScores` without inventing scores, plus multi-hypothesis evaluation in `ContactResolver`.

---

### 2. VISION Fails to Understand Mispronounced or Misspelled Words
- **Actual Root Cause:**
  - `CommandNormalizer` only holds a small static typo map and exact regexes; `"Whats app"`, `"what's app"`, or phonetic transcription variations fail app/command normalization when punctuation/apostrophes or space splits occur.
  - Zero dedicated phonetic similarity algorithms (Damerau-Levenshtein, Jaro-Winkler, Consonant/Metaphone skeleton, Indic transliteration-aware normalization) exist in the repository.
- **Relevant Files:**
  - `lib/core/intelligence/command_normalizer.dart`
  - `lib/core/intelligence/entity_extractor.dart`
  - `lib/core/intelligence/intent_classifier.dart`
- **Why Current Implementation Fails:** Global string replacement alone breaks proper names and brand names, while exact regexes fail on ASR space insertions (`"what's app"`) and Indian-English consonant swaps.
- **Proposed Solution:** Build dedicated normalization and phonetic comparison modules (`PhoneticAlgorithms`, `IndicTransliterator`, `ContactNormalizationService`) separating general text cleanup, command canonicalization, contact-name normalization, and phonetic scoring without blindly applying English Metaphone to Devanagari/Gujarati scripts.
- **Required Test:** Unit test suite covering `"Whats app"`, `"what's app"`, `"watsapp"`, Damerau-Levenshtein transpositions, Jaro-Winkler prefix similarity, and Indic script phonetic alignment.

---

### 3. Fails to Identify Saved Contacts When Spoken Name Differs from Contact Spelling
- **Actual Root Cause:**
  - `VisionAutomationChannel.kt` (`handleLookupContacts`) filters contacts inside Android using `name.lowercase().contains(normalizedQuery)` plus an `editDistance(token, normalizedQuery) <= 2` token check capped before full ranking.
  - Real-world phonetic divergence such as spoken `"Shohil Jht"` vs saved `"Soel Kht"` has edit distance > 2 on `"shohil"` vs `"soel"` (distance 3), causing Android to return **zero matches**.
  - Android cursor query does not return `ContactsContract.CommonDataKinds.Phone.CONTACT_ID`, preventing Contact-ID-based personal voice alias storage.
  - No multi-band confidence policy exists: no `"Did you mean Soel Kht?"` confirmation loop or confirmed voice-alias learning (`shohil jht -> Soel Kht`).
- **Relevant Files:**
  - `android/app/src/main/kotlin/com/brijesh/vision/VisionAutomationChannel.kt`
  - `lib/features/automation/domain/entities/device_action.dart`
  - `lib/features/automation/presentation/controllers/automation_controller.dart`
- **Why Current Implementation Fails:** Naive string containment cannot bridge Indian-English vowel/aspiration shifts (`sh/s`, `oh/o`, `j/k` clusters or initials `"Jht"` / `"Kht"`), and lacks `ContactResolver`, `ContactPhoneticMatcher`, `ContactConfidenceScorer`, and `ContactAliasRepository`.
- **Proposed Solution:**
  - Return `contactId` alongside `name`, `phoneNumber`, `label` in `VisionAutomationChannel.kt` and add `getAllContactsSnapshot` after permission grant.
  - Implement `ContactResolver`, `ContactSearchRepository`, `ContactNormalizationService`, `ContactPhoneticMatcher`, `ContactConfidenceScorer`, and Contact-ID-backed `ContactAliasRepository`.
  - Apply strict High / Medium (`"Did you mean ...?"` + save alias option) / Low / Ambiguous confidence policy.
- **Required Test:** Contact matching test suite verifying `"Shohil Jht"` -> `"Soel Kht"`, phonetic/word-order variations, multi-hypothesis ranking, duplicate contact changes, low-confidence safety rejection, and alias CRUD lifecycle.

---

### 4. Does Not Understand Natural Gujarati, Hindi, English & Hinglish Properly
- **Actual Root Cause:**
  - While `IntentEngine` added major EN/HI/GU/Hinglish/Gujlish patterns, conversational follow-ups across apps/tasks (e.g. `"Open WhatsApp."` -> `"Now message Tisha."`), spoken ASR space splits (`"what's app"`), mixed Indic transliterated names, and colloquial phonetic spellings need unified transliteration + task-context continuation.
- **Relevant Files:**
  - `lib/core/intelligence/command_normalizer.dart`
  - `lib/core/intelligence/entity_extractor.dart`
  - `lib/core/intelligence/intent_classifier.dart`
  - `lib/core/intelligence/conversation_context.dart`
- **Why Current Implementation Fails:** Context tracking records `lastAppName` cleanly in `ChatController`, but `IntentClassifier` did not previously consume `context.lastAppName == 'WhatsApp'` when user says `"Now message Tisha."`.
- **Proposed Solution:** Wire `IndicTransliterator` and task-continuation rules into `IntentClassifier` & `EntityExtractor`, enabling natural multi-turn resolution while preserving local-first speed.
- **Required Test:** Multi-turn context tests (`"Open WhatsApp."` -> `"Now message Tisha."`), transliterated script commands, and mixed Hinglish/Gujlish command assertions.

---

### 5. AI Responses Take Too Much Time
- **Actual Root Cause:**
  - Any misunderstood voice/spelling variation (such as `"Shohil Jht"` failing contacts or `"what's app"` missing aliases) falls through local execution and waits for external cloud LLM round-trips.
  - Per-stage latencies lacked separate instrumentation for wake-word detection, STT, intent classification, contact resolution, local execution, AI startup, first token, full completion, and TTS startup.
- **Relevant Files:**
  - `lib/core/telemetry/performance_telemetry.dart`
  - `lib/features/chat/domain/services/ai_router.dart`
  - `lib/features/chat/data/datasources/ai_http_helper.dart`
- **Why Current Implementation Fails:** Missing per-stage visibility and local contact/spelling fallback push fast local intents onto slow network paths.
- **Proposed Solution:** Expand `TelemetryNotifier` to measure all 9 pipeline stages individually (`contactResolutionMs`, `intentRecognitionMicros`, `localExecutionMs`, `aiRequestStartupMs`, `aiFirstTokenMs`, `aiFullResponseMs`, `ttsStartupMs`, `sttFinalMs`, `wakeWordDetectionMs`), reuse `http.Client` connections cleanly, and resolve fuzzy/phonetic intents locally `< 200ms` / contacts `< 250ms`.
- **Required Test:** Latency assertions verifying local classification & phonetic contact matching complete far under `200ms`/`250ms` and separate stage metrics populate accurately.

---

### 6. Responses Are Sometimes Irrelevant or Incorrect
- **Actual Root Cause:**
  - `AiCompletionRequest.systemInstruction` still benefits from stricter anti-parroting rules (never repeat the user's question back or add generic filler introductions) and post-execution confirmation accuracy (e.g., `"Your alarm is set for 7 AM."` only after real Android confirmation).
  - Unstructured AI replies during voice automation previously spoke filler without checking actual Android action outcome.
- **Relevant Files:**
  - `lib/features/chat/domain/entities/ai_completion_request.dart`
  - `lib/features/chat/presentation/controllers/chat_controller.dart`
- **Why Current Implementation Fails:** Generic assistant persona encourages verbose introductions instead of crisp factual answers or grounded execution confirmations.
- **Proposed Solution:** Tighten `AiCompletionRequest.systemInstruction` rules against echoing questions/introductions, ground automation confirmations on actual `DeviceActionResult` summaries (`"Your alarm is set for 7 AM."`), and carry `ConversationIntelligenceContext` across turns.
- **Required Test:** Prompt builder assertions + offline/local alarm/contact execution response verification tests.

---

### 7. Mobile Automation Is Unreliable
- **Actual Root Cause:**
  - `Call` / `SMS` / `WhatsApp` flows lacked Contact-ID-aware phonetic resolution (`ContactResolver`), failing when spoken names diverged from saved spelling.
  - `VoiceController` and `ChatController` confirmation cards didn't expose interactive medium-confidence `"Did you mean Soel Kht?"` confirmation + alias saving.
  - Multi-step & error-recovery flows (`ActivityNotFoundException`, denied permissions, missing app) need unified status feedback.
- **Relevant Files:**
  - `android/app/src/main/kotlin/com/brijesh/vision/VisionAutomationChannel.kt`
  - `lib/features/automation/presentation/controllers/automation_controller.dart`
  - `lib/features/automation/presentation/widgets/automation_action_prompt_card.dart`
- **Why Current Implementation Fails:** Relying solely on raw substring cursor filtering causes real contacts like `"Soel Kht"` to appear "not found".
- **Proposed Solution:** Integrate `ContactResolver` into `AutomationController` for calls, SMS, WhatsApp, and contact lookups; add interactive medium-confidence suggestion + `"Confirm & Save Alias"` state to `AutomationState` & `AutomationActionPromptCard`.
- **Required Test:** `AutomationController` tests covering High / Medium (`Did you mean...?`) / Low / Ambiguous contact confidence flows, alias creation/reuse, permission denials, alarms, timers, apps, and settings.

---

### 8. Direct Android Assistant Activation Opens an Unattractive or Incomplete Interface
- **Actual Root Cause:**
  - `VisionVoiceInteractionSession.kt` inflates `R.layout.vision_assistant_overlay` (`android/app/src/main/res/layout/vision_assistant_overlay.xml`), a static flat `#F0050812` linear layout with 3 bare buttons (`Speak`, `Open VISION`, `Dismiss`), no animated orb/visualizer, no hypothesis/clarification UI, and hardcoded `"en-IN"` STT locale.
- **Relevant Files:**
  - `android/app/src/main/kotlin/com/brijesh/vision/VisionVoiceInteractionSession.kt`
  - `android/app/src/main/res/layout/vision_assistant_overlay.xml`
  - `android/app/src/main/res/drawable/*`
  - `android/app/src/main/kotlin/com/brijesh/vision/AssistantOverlayActivity.kt`
  - `lib/features/assistant/presentation/screens/assistant_overlay_screen.dart`
- **Why Current Implementation Fails:** System assist trigger shows a bare legacy Android XML panel with no motion, no visual polish, and wrong locale configuration, creating a stark mismatch against the Flutter Liquid Glass UI.
- **Proposed Solution:** Redesign `vision_assistant_overlay.xml` with rounded layered glass surfaces, custom native animated `VisionPulseOrbView` (`ObjectAnimator` / `Canvas` pulse + RMS wave feedback), locale-aware `SharedPreferences` reading (`flutter.vision_pref_voice_language`), smooth alpha/translation entrance animation on `onShow`, AND seamless interactive Flutter `/assistant-overlay` upgrade.
- **Required Test:** Android Gradle APK compilation verifying custom Kotlin View / drawables / resources + widget tests for Flutter `AssistantExperienceScreen` & `AssistantOverlayScreen`.

---

### 9. Assistant UI Lacks Proper Animations & Interaction Feedback
- **Actual Root Cause:**
  - `AssistantExperienceScreen` ignores `VoiceListeningPhase.understanding`, `VoiceListeningPhase.executing`, and `VoiceListeningPhase.confirmationRequired` in its orb/state mapping (lines 188-210 only handle `idle`, `listening`, `thinking`, `speaking`, `error`).
  - No live interactive amplitude waveform indicator accompanies the orb or response card, and medium-confidence `"Did you mean Soel Kht?"` alias confirmation lacks dedicated animated glass feedback in `AutomationActionPromptCard` / `AssistantExperienceScreen`.
- **Relevant Files:**
  - `lib/features/assistant/presentation/screens/assistant_experience_screen.dart`
  - `lib/features/assistant/presentation/widgets/vision_ai_orb.dart`
  - `lib/features/automation/presentation/widgets/automation_action_prompt_card.dart`
- **Why Current Implementation Fails:** Users cannot distinguish *Understanding* vs *Executing* vs *Confirmation Required* vs *Speaking*, and confirmation flows look static rather than interactive.
- **Proposed Solution:** Map all assistant lifecycle phases in `AssistantExperienceScreen` and `VisionAiOrb`, add a smooth lightweight `CustomPainter` / animated bar equalizer widget reacting to `voiceState.normalizedAmplitude`, animate transitions cleanly with `AnimatedSwitcher` + `Curves.easeOutCubic`, and surface interactive `"Did you mean <Contact>?"` + `"Save Voice Alias"` feedback cleanly.
- **Required Test:** Widget tests verifying animated orb/feedback states (`listening`, `understanding`, `executing`, `confirmationRequired`, `speaking`, `error`) and interactive `"Did you mean...?"` alias confirmation card.
