# VISION AI — Intelligence, Accuracy, Speed & Mobile Automation Audit

Date: 2026-11-18  
Package ID: `com.brijesh.vision`  
Primary Target Device: OPPO Reno 16 (Android / ColorOS)

---

## 1. Executive Summary

An end-to-end technical audit of VISION AI's Flutter intelligence pipeline (`chat`, `voice`, `automation`, `settings`) and Kotlin Android native bridges (`VisionAutomationChannel`, `VisionVoiceChannel`, `VisionWakeWordService`, `AssistantOverlayActivity`) identified concrete architectural bottlenecks behind all seven reported user problems. **The AI models themselves are rarely the primary cause** — most failures stem from deterministic parsing gaps, ungrounded routing heuristics, sequential network/storage overhead, missing lifecycle validation, and voice-wake audio contention.

---

## 2. Root Cause Diagnosis by Problem Area

### Problem 1: AI answers are not accurate enough
- **Weak system prompting (`lib/features/chat/domain/entities/ai_completion_request.dart`):** `systemInstruction` provides only generic assistant framing and asks the model to emit `[[VISION_ACTION:...]]` even when the prompt is purely informational or lacks required parameters. It lacks explicit guidance on admitting uncertainty, avoiding fabricated automation results, asking concise clarifying questions when entities are missing, and adjusting depth by task complexity.
- **Unweighted sliding FIFO context (`lib/features/chat/domain/services/ai_conversation_manager.dart`):** `AppConstants.maxContextMessages = 16` slices raw history strictly by count regardless of turn type, redundant noise, or persisted user preferences/context.
- **No personalization/memory separation:** Long-term preferences (tone, nicknames/contacts, routines) are absent from context unless repeated in the last 16 messages.
- **Action tag stripping without feedback (`lib/features/chat/data/repositories/chat_repository_impl.dart`):** `ChatRepositoryImpl` parses only the first tool call (`toolCalls.firstOrNull`) and strips `[[VISION_ACTION:...]]` tags, discarding multi-step intent plans or invalid parameters silently.

### Problem 2: VISION sometimes misunderstands simple commands
- **Brittle regex-only parsing (`lib/features/automation/domain/utils/device_intent_parser.dart`):**
  - `_parseAlarm` and `_parseTimer` require Arabic numerals (`\b\d{1,2}`); spoken or written number words (`seven`, `saat`, `પાંચ`), `half past six`, `tomorrow`, `kal savare`, `vage`, and `alarm muk` fail completely.
  - `_parseAlarm`'s naive `labelMatch` regex can accidentally treat relative time qualifiers or prepositions (`for seven tomorrow`) as alarm labels.
  - `_parsePhoneCall` matches `"અને"` / `"ને"` + Gujarati script verbs (`કોલ` / `ફોન કરો`) or `"को फोन करो"` in Devanagari, **not** Romanized Hinglish/Gujlish phrasing such as `"Tisha ne call kar"` or `"Tisha ko phone lagao"`.
  - `_parseLaunchApp` expects English verb-first (`open|launch|start <app>`) or Devanagari/Gujarati script verbs (`खोलो` / `ખોલો`), failing completely on `"WhatsApp khol"` or `"YouTube chalu kar"`.
- **Zero spelling/fuzzy normalization:** Common ASR or typing errors (`wattsapp`, `alram`, `timmer`, `blutooth`, `seting`) fail hard without normalization.
- **No confidence scoring or clarification detection:** Partial commands (`"set an alarm"`, `"call"`, `"send message to Tisha"`) fall through to cloud LLMs instead of recognizing the partial intent and asking cleanly for the missing slot.
- **No local assistant meta-commands:** `"Stop speaking"`, `"Repeat that"`, `"Cancel"`, `"Mute yourself"`, `"Stop timer"` are not represented in deterministic local execution.

### Problem 3: Responses are slow
- **Double provider candidate resolution (`lib/features/chat/data/repositories/chat_repository_impl.dart`):** `streamUserMessage` invokes `_router.resolveCandidates(...)` at line 242 before calling `_router.routeAndStream(...)` at line 294, which calls `_router.resolveCandidates(...)` a second time, duplicating async `FlutterSecureStorage` key lookups on every message.
- **Unnecessary cloud round-trips:** Because Hinglish/Gujlish/word-number commands fail `DeviceIntentParser.parseLocalCommand`, simple local commands (`"WhatsApp khol"`, `"Set an alarm for seven tomorrow"`) hit external HTTPS endpoints (`45s` timeout in `AppConstants.aiRequestTimeout`) and return full LLM prose.
- **Voice-to-AI-to-TTS serial wait (`lib/features/voice/presentation/controllers/voice_controller.dart`):** `VoiceController._dispatchVoiceCommandToAi` awaits the entire `ChatController.sendMessage` stream to finish before starting TTS playback, compounding full generation latency + TTS initialization latency.
- **Wake-word / SpeechRecognizer contention (`android/app/src/main/kotlin/com/brijesh/vision/VisionVoiceChannel.kt`):** Immediately on `SpeechRecognizer.onResults`, the Kotlin channel resumes `VisionWakeWordService`'s `AudioRecord` loop right before Dart dispatches AI/TTS, causing audio focus churn and startup delay when TTS initializes.
- **No first-token or per-stage latency telemetry:** Without timing breakdowns across voice STT, intent parsing, AI TTFT (time-to-first-token), full AI latency, native Kotlin execution, and TTS startup, regressions are invisible.

### Problem 4: Mobile automation is unreliable or not working
- **App resolution gaps (`android/.../VisionAutomationChannel.kt`):** `findBestAppMatch` checks lowercase exact -> `startsWith` -> `contains` -> `APP_ALIASES` -> `packageName.contains`, without token normalization, typo tolerance, or Indic script aliases (e.g., `વોટ્સએપ`, `यूट्यूब`, `કેમેરા`), and omits clear available-app suggestions on missing app errors.
- **Contact ordinal selection unsupported:** Multi-number contacts or prompts like `"Call the first number of Tisha"` / `"Call second number"` are not parsed cleanly into ordinal selections in either Dart or `AutomationController`.
- **Alarm & timer limitations:** Relative `"tomorrow"` handling (`Kal savare saat vage alarm muk`), duplicate-alarm messaging, and dismissing alarms/timers (`AlarmClock.ACTION_DISMISS_ALARM` / `ACTION_DISMISS_TIMER` / `ACTION_SHOW_ALARMS` / `ACTION_SHOW_TIMERS`) are missing.
- **No sequential multi-step execution:** Composite commands (`"Open WhatsApp and find Tisha"` or `"Set timer for 10 minutes and put phone on vibrate"`) have no multi-step planner or per-step failure reporting.
- **Confirmation & validation inconsistencies:** Consequential AI-emitted actions lack strict schema allowlisting and field bounds validation before dispatching to `AutomationController`.

### Problem 5: Assistant understands a command but does not execute it
- **Text-only LLM replies without structured dispatch:** When local regex misses a valid device command and the cloud LLM answers conversationally (`"Sure, setting an alarm for 7 AM..."`) without calling `execute_device_action` or emitting `[[VISION_ACTION:...]]`, `ChatController` displays a success-sounding text message while zero Android intents actually ran.
- **Dual-path mismatch between Chat and Voice:** Local command execution existed inside `ChatController.sendMessage` (`_dispatchDeviceAction`), while conversational/contextual follow-ups (`"now text her I'm outside"`, `"yes confirm"`) had no `ConversationContext` to resolve pending actions or pronoun targets locally.

### Problem 6: English, Hindi, Gujarati, and Hinglish recognition needs improvement
- **`VoiceLanguage` rigidity & ASR pause handling (`VisionVoiceChannel.kt`):** Switching between Hindi/Gujarati/Hinglish mid-sentence often needs broader hint tolerance, stabilized partial transcripts, and explicit `EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS` / `EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS` tuning so natural pauses are not clipped prematurely.
- **Missing Romanized Hindi & Gujarati grammar tables:** Standard particles (`ko`, `ka`, `ki`, `ke`, `ne`, `ma`, `thi`, `par`, `kar`, `karo`, `muk`, `laga`, `lagao`, `khol`, `kholo`, `chalu`, `bandh`, `vage`, `savare`, `subah`, `shaam`, `raat`, `kal`, `aaj`, `minute`, `second`, `vagar`) were not modeled.

### Problem 7: AI provider selection and model routing need optimization
- **Crude routing trigger (`lib/features/chat/domain/services/ai_router.dart`):** `_computeAutoRouteOrder` switches away from the user's selected provider whenever `promptText.length > 220` or 6 English substrings (`code`, `debug`, `architecture`, `compare`, `analyze`, `explain in detail`) match, forcing `[claude, openAi, gemini]` and ignoring the user's preferred provider as well as Hindi/Gujarati complexity cues.
- **Missing capability metadata (`lib/features/chat/domain/entities/ai_model_config.dart`):** `AiModelInfo` tracks only display name, description, speed tier, and default/reasoning/deprecated flags; it lacks tool-calling score, multilingual competence, latency profile, cost tier, and recommended task suitability.
- **No circuit breaker / health manager:** A provider returning `401 Unauthorized` (`invalidApiKey`), `429` (`quotaExceeded` / `rateLimited`), or `5xx` is retried on every turn without cooldown tracking or health scoring, adding unnecessary timeout/backoff latency.

---

## 3. Target Architecture & Remediation Plan

1. **Intent Recognition Engine (`lib/core/intelligence/`):** `CommandNormalizer`, `EntityExtractor`, `IntentClassifier`, `ConfidenceManager`, `ConversationContext`, `CommandRegistry`, and `IntentEngine` orchestrator with local deterministic coverage for EN/HI/GU/Hinglish/Gujlish + typos + multi-step commands + clarification.
2. **Local-First Command Execution & Lifecycle (`Received -> Understood -> Validated -> PermissionRequired -> ConfirmationRequired -> Executing -> Success/Failed/Cancelled`):** Zero LLM calls when deterministic execution criteria are met, plus sequential multi-step execution and contact ordinal selection.
3. **AI Accuracy, Capability Registry & Intelligent Routing:** `TaskComplexityClassifier`, `ModelCapabilityProfile`, `ProviderHealthManager`, `ProviderFallbackManager`, updated `AIRouter` (single key lookup, preference-aware, health-gated), grounded `AiCompletionRequest` prompt builder, and relevance-aware `AIConversationManager`.
4. **Latency Telemetry, Personalization Memory & Developer Diagnostics:** Microsecond/millisecond latency instrumentation across every stage, secret-redacted error ring buffer, consent-gated local memory CRUD, and `/diagnostics` route with sanitized export.
5. **Android Kotlin & Voice Reliability Upgrades:** Improved `VisionAutomationChannel.kt` (fuzzy app search, dismiss alarm/timer intents, richer device diagnostics, safer multi-match contact ranking) and `VisionVoiceChannel.kt` (tuned silence thresholds, active state listener arbitration between `MainActivity` and `AssistantOverlayActivity`, TTS markdown cleanup & queued utterance playback without wake-word audio race).
