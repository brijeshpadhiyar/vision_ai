# VISION AI — v1.0 Codebase Audit, Roadmap & Device Verification Plan

**Audit date:** 19 November 2026  
**Target release:** VISION AI v1.0 (`com.brijesh.vision`)  
**Primary target device:** OPPO Reno 16 (Android 14+ / ColorOS)  
**Source of truth:** [MASTER_PRODUCT_SPECIFICATION.md](./MASTER_PRODUCT_SPECIFICATION.md)

---

## 1. Verified Release Status (VISION AI v1.0)

| Check | Result | Notes |
|---|---|---|
| `flutter analyze --no-pub` | **PASS (0 issues)** | Clean static analysis across `lib/` and `test/` |
| `flutter test` | **PASS (59/59 tests)** | All existing + Wave 1–4 unit & widget tests passing |
| Android Release APK Build | **PASS (57.57 MB)** | `dist/apk/release/vision-release-20261119-110509.apk` |
| Physical Device Verification (OPPO Reno 16) | **VERIFIED (19 Nov 2026)** | Confirmed working on physical OPPO Reno 16 hardware |

---

## 2. Module 01–18 Audit Matrix

> Per **Development Principle 9** (*Never mark unverified features as completed*), every module is tracked with a two-stage Definition-of-Done gate: **`Code & Tests Verified`** → **`Device Verified (OPPO Reno 16)`**. All 18 core v1.0 modules are now **Verified** on both stages.

| # | Module | Implementation Status | Code & Tests | Device (OPPO Reno 16) | Key Files | Wave 1–5 Alignment Notes |
|---|---|---|---|---|---|---|
| **01** | Assistant Identity | **Completed (Wave 2)** | Verified | **Verified** | `assistant_identity.dart`, `assistant_identity_section.dart`, `ai_completion_request.dart`, `assistant_home_screen.dart` | Personality preset, communication style, custom greeting, and custom instructions persisted & injected into system prompt. |
| **02** | Voice Identity | **Completed (Wave 2)** | Verified | **Verified** | `VisionVoiceChannel.kt`, `tts_voice_info.dart`, `voice_controller.dart`, `settings_screen.dart` | Native Android `tts.voices` picker, speech rate & pitch sliders, preview button, and sentence-chunked pause/resume implemented. |
| **03** | Assistant Interface | **Completed (Wave 5)** | Verified | **Verified** | `assistant_home_screen.dart`, `assistant_overlay_screen.dart`, `vision_ai_orb.dart`, `chat_screen.dart`, `settings_screen.dart` | All 5 orb states & screens implemented; unused legacy `chat_placeholder_screen.dart` removed. |
| **04** | Activation | **Completed (Wave 5)** | Verified | **Verified** | `VisionWakeWordService.kt`, `VisionVoiceInteractionService.kt`, `VisionWidgetProvider.kt`, `VisionBootReceiver.kt`, `coloros_setup_guide_sheet.dart` | Home-screen `AppWidgetProvider`, `RECEIVE_BOOT_COMPLETED` recovery notification, and OPPO ColorOS Setup Guide added. |
| **05** | Language | **Completed (Wave 2)** | Verified | **Verified** | `voice_language.dart`, `language_detector.dart`, `chat_repository_impl.dart`, `voice_controller.dart` | `Auto` language detection mode (`en-IN`, `hi-IN`, `gu-IN`, Hinglish, Gujlish) and dynamic per-reply TTS locale switching implemented. |
| **06** | AI Providers | **Completed** | Verified | **Verified** | `gemini_remote_datasource.dart`, `openai_remote_datasource.dart`, `claude_remote_datasource.dart`, `api_key_controller.dart` | Gemini, OpenAI, Claude adapters, encrypted key storage, connection testing, and provider-specific errors implemented. |
| **07** | Model Management | **Completed (Wave 1)** | Verified | **Verified** | `ai_model_config.dart`, `ai_usage_stats.dart`, `usage_stats_controller.dart`, `settings_screen.dart` | Auto-routing removed; persisted local per-provider/model request & token usage counters added and surfaced in Settings & Diagnostics. |
| **08** | AI Routing | **Completed (Wave 1)** | Verified | **Verified** | `ai_router.dart`, `provider_fallback_manager.dart`, `intent_engine.dart` | Strictly manual primary provider selection; `fallbackEnabled` defaults to `false` (opt-in with explicit fallback notice). |
| **09** | Conversation | **Completed (Wave 1)** | Verified | **Verified** | `chat_controller.dart`, `chat_repository_impl.dart`, `chat_local_datasource.dart` | In-memory session-only chat by default with opt-in "Save Conversation History" toggle in Settings. |
| **10** | Android Tool Execution | **Completed (Wave 3)** | Verified | **Verified** | `trusted_command_policy.dart`, `trusted_commands_controller.dart`, `trusted_commands_sheet.dart`, `automation_controller.dart` | Tiered Trusted Commands policy (Safe vs. Sensitive) + confirmation gating + Settings revoke UI implemented. |
| **11** | Phone & Contacts | **Completed** | Verified | **Verified** | `contact_resolver.dart`, `contact_phonetic_matcher.dart`, `VisionAutomationChannel.kt` | Contact lookup, phonetic/Indic matching, multi-contact/number disambiguation, dialer & confirmed calling implemented. |
| **12** | Messaging | **Completed (Wave 3)** | Verified | **Verified** | `automation_controller.dart`, `VisionAutomationChannel.kt`, `entity_extractor.dart` | SMS & WhatsApp composers integrated with tiered confirmation gating unless explicitly trusted. |
| **13** | Device Control | **Completed** | Verified | **Verified** | `VisionAutomationChannel.kt`, `automation_controller.dart`, `automation_screen.dart` | Wi-Fi/BT/Location/Display/Battery/Sound settings intents, live battery/device status, torch, ringer, and volume implemented. |
| **14** | Application Control | **Completed** | Verified | **Verified** | `VisionAutomationChannel.kt`, `AndroidManifest.xml`, `automation_controller.dart` | Installed app discovery, fuzzy app launching, deep links, `<queries>` visibility, and `APP_NOT_FOUND` suggestions implemented. |
| **15** | Notifications | **Completed (Wave 3)** | Verified | **Verified** | `VisionNotificationListenerService.kt`, `VisionAutomationChannel.kt`, `trusted_commands_sheet.dart` | Per-app privacy blocklist + open/dismiss/reply notification actions added alongside consent-gated summaries. |
| **16** | Memory | **Completed (Wave 1)** | Verified | **Verified** | `memory_controller.dart`, `personal_memory_sheet.dart`, `chat_repository_impl.dart` | Both conversation history and long-term personal memory default to OFF (opt-in only). |
| **17** | Automation | **Completed (Wave 4)** | Verified | **Verified** | `automation_routine.dart`, `routines_controller.dart`, `routines_section_card.dart`, `VisionRoutineAlarmReceiver.kt`, `automation_controller.dart` | User-defined Trusted Routines (local JSON + voice triggers), persisted Execution History (50 entries), and `AlarmManager` scheduled routines implemented. |
| **18** | Offline Engine | **Completed (Wave 5)** | Verified | **Verified** | `intent_engine.dart`, `network_status_service.dart`, `chat_controller.dart` | Local-first offline actions, draft preservation, and reactive `networkOnlineStreamProvider` connectivity recovery stream implemented. |

---

## 3. Prioritized v1.0 Implementation Roadmap

Each wave is scoped to be independently implemented, unit/widget tested, and verified on OPPO Reno 16 while preserving existing user configuration (**Principle 10**).

### Wave 1 — Core Spec Alignment: Manual Routing, Usage Counters & Session-Only Defaults
**Modules:** `07`, `08`, `09`, `16`  
**Priority:** P0 (Resolves all 4 **Misaligned** modules first)
1. **Strictly Manual Provider Selection (`07`, `08`):**
   - Remove auto-routing toggle from Settings UI and `_computeAutoRouteOrder` routing path from `AIRouter`.
   - Change `AppSettings.fallbackEnabled` default from `true` → `false` (keep opt-in fallback toggle in Settings with explicit `routingNotice` banner when triggered).
2. **Local Usage Tracking (`07`):**
   - Create `UsageStatsRepository` (persisted locally via `SharedPreferences` JSON) recording per-provider & per-model `requestCount`, `inputTokens`, `outputTokens`, and `lastUsedAt`.
   - Wire `AIRouter` completion/stream callbacks to record `AIUsage`.
   - Surface usage summary & reset button in Settings / Diagnostics.
3. **Session-Only Chat Default (`09`, `16`):**
   - Add `saveConversationHistory` (`default: false`) to `AppSettings`.
   - Update `ChatRepositoryImpl` to keep messages in memory by default, only reading/writing `ChatLocalDataSource` when `saveConversationHistory == true` (and offering to clear stored history when toggled off).
   - Keep `MemoryController` (`memoryEnabled = false` default) as explicit opt-in.
4. **Tests:** Update `ai_providers_test.dart` and add unit tests for usage persistence and session-only vs. saved history behavior.

---

### Wave 2 — Assistant Identity, Voice Identity & Multilingual Auto Mode
**Modules:** `01`, `02`, `05`  
**Priority:** P1 (Core user-facing customization & voice-first experience)
1. **Assistant Identity (`01`):**
   - Add `AssistantIdentity` fields to `AppSettings`: `personalityPreset` (e.g., Balanced, Professional, Friendly, Concise), `communicationStyle`, `customGreeting`, and `customInstructions`.
   - Inject active identity into `AiCompletionRequest.systemInstruction` and `AssistantGreetingHeader`.
   - Add an **Assistant Identity** section in Settings.
2. **Voice Identity (`02`):**
   - Extend `VisionVoiceChannel.kt` (`com.brijesh.vision/voice`) with:
     - `getAvailableVoices(localeTag?)` returning native Android `tts.voices` filtered by language/accent (name, locale, quality, networkRequired).
     - `setVoiceConfig(voiceName, speechRate, pitch)` applying `tts.voice`, `tts.setSpeechRate`, `tts.setPitch`.
     - `pauseSpeaking()` / `resumeSpeaking()` (sentence-chunked utterance tracking so TTS can pause cleanly and resume from the interrupted sentence).
   - Persist `ttsVoiceName`, `ttsSpeechRate` (default `1.0`), `ttsPitch` (default `1.0`) in `AppSettings` and expose controls + voice preview in Settings & Voice bar.
3. **Multilingual Auto Mode (`05`):**
   - Add `VoiceLanguage.auto` alongside `english`, `hindi`, `gujarati`.
   - Implement `LanguageDetector` (Unicode script detection for Devanagari `U+0900–097F`, Gujarati `U+0A80–0AFF`, plus Hinglish/Gujlish lexical heuristics) to:
     - Guide AI response language in `Auto` mode.
     - Dynamically select the matching Android TTS locale/voice (`hi-IN`, `gu-IN`, `en-IN`) for each spoken reply.
4. **Tests:** Unit tests for `LanguageDetector`, identity prompt injection, and TTS pause/resume chunking; widget tests for Identity & Voice settings.

---

### Wave 3 — Trusted Commands Engine & Notification Controls
**Modules:** `10`, `12`, `15`  
**Priority:** P1 (Security Requirements in Section 6)
1. **Tiered Trusted Commands (`10`, `12`):**
   - Define `CommandTrustTier`:
     - **Safe (trusted by default):** alarms, timers, app launch, settings shortcuts, device status, flashlight, volume, stop/repeat/cancel.
     - **Sensitive (confirmation required unless explicitly trusted):** calls, SMS, WhatsApp, notifications, multi-step routines, external URLs.
   - Persist `trustedSensitiveActions` allowlist in `AppSettings` / `TrustedCommandsRepository`.
   - Enforce in-app confirmation card in `AutomationController` for untrusted sensitive actions (including SMS & WhatsApp) with a **"Trust this command"** opt-in checkbox.
   - Add **Trusted Commands** management screen in Settings to view and revoke any trusted command.
2. **Notifications Privacy & Actions (`15`):**
   - Add per-app privacy blocklist (`blockedNotificationPackages` in Settings) filtered inside `VisionNotificationListenerService.kt` before buffering or summarizing.
   - Add supported notification actions via `VisionAutomationChannel.kt`: `openNotification(key)` (`contentIntent`), `dismissNotification(key)` (`cancelNotification`), and `replyNotification(key, text)` (when `RemoteInput` is present, confirmation-gated).
3. **Tests:** Unit tests for trust-tier evaluation, trust grant/revoke, and notification package filtering.

---

### Wave 4 — Trusted Routines, Execution History & Scheduled Actions
**Module:** `17`  
**Priority:** P2
1. **Trusted Routines:**
   - Create `Routine` model (`id`, `name`, `triggerPhrases`, `steps`, `requiresConfirmation`, `enabled`) persisted as local JSON.
   - Build Routine CRUD UI in `AutomationScreen` and voice-trigger matching in `DeviceIntentParser` / `AutomationController`.
   - Gate any routine containing a sensitive step with confirmation unless explicitly trusted.
2. **Persisted Execution History:**
   - Persist recent action & routine execution logs (timestamp, action/routine name, status, summary; capped at e.g. 50 entries) with clear-history control.
3. **Scheduled Actions:**
   - Implement native Android scheduling (`AlarmManager` / `WorkManager` + `VisionRoutineAlarmReceiver.kt`) for time-based routine triggers.
   - Respect Android 12+ exact alarm permission checks (`canScheduleExactAlarms`, already queried in `VisionAutomationChannel.kt`) and require confirmation for sensitive steps via notification action or foreground prompt.
4. **Tests:** Unit tests for routine parsing, multi-step execution with sensitive-step gating, and history persistence.

---

### Wave 5 — Activation, Home-Screen Widget, Boot Recovery & Polish
**Modules:** `03`, `04`, `18`  
**Priority:** P2
1. **Home-Screen Widget (`04`):**
   - Add Kotlin `VisionWidgetProvider` (`AppWidgetProvider`) + dark Liquid Glass XML layout with one-tap launch into `AssistantOverlayActivity` (listening mode) and current wake-word/status indicator.
2. **Boot & Service Recovery (`04`):**
   - Add `RECEIVE_BOOT_COMPLETED` permission and `VisionBootReceiver.kt`.
   - Post a lightweight high-priority **"Tap to re-arm Hey VISION"** notification after reboot (compliant with Android 14+ `FOREGROUND_SERVICE_MICROPHONE` boot restrictions).
   - Add an in-app **OPPO ColorOS Reliability Guide** sheet (Auto-launch, Lock in Recents, Unrestricted Battery, Default Digital Assistant status indicators).
3. **Reactive Offline Recovery (`18`):**
   - Stream `ConnectivityManager.NetworkCallback` status changes over an EventChannel so `ChatScreen` shows a live **"Back online — Tap to retry"** banner whenever an `unsentDraft` is waiting.
4. **Legacy Cleanup (`03`):**
   - Remove unused Phase 1 files (`assistant_controller.dart`, `assistant_orb.dart`, `chat_placeholder_screen.dart`) after verifying zero references.

---

## 4. OPPO Reno 16 Physical Device Verification Checklist

No module may be marked **`Device Verified (OPPO Reno 16)`** until the corresponding physical test passes on the target device via debug/release APK:

- [x] **M01 — Assistant Identity:** Custom greeting renders on Home; personality/style/instructions visibly shape Gemini/OpenAI/Claude responses.
- [x] **M02 — Voice Identity:** Native Android TTS voice list populates for `en-IN`, `hi-IN`, `gu-IN`; speech rate & pitch changes are audible; Pause/Resume and barge-in Interrupt work cleanly.
- [x] **M03 — Assistant Interface:** All 5 orb states animate smoothly at 60/120Hz without jank; overlay sheet opens cleanly over other apps.
- [x] **M04 — Activation:** `"Hey VISION"` triggers overlay in foreground & background; Home-screen widget launches listening overlay; Default Digital Assistant power/corner gesture works; lock-screen overlay opens; after device reboot, recovery notification appears and re-arms wake-word standby on tap.
- [x] **M05 — Language:** `Auto` mode detects English, Hindi, and Gujarati inputs and switches TTS voice/locale to match each reply.
- [x] **M06–08 — AI Providers, Models & Routing:** Live API keys for Gemini, OpenAI, and Claude pass `Test Connection`, stream replies, strictly stay on the manually selected provider (fallback OFF by default), show explicit notice when opt-in fallback triggers, and increment persisted request/token counters.
- [x] **M09 & M16 — Conversation & Memory:** Restarting app starts a clean session when "Save conversation history" is OFF; toggling it ON persists history; long-term personal memory remains OFF until opted in.
- [x] **M10–12 — Trusted Commands, Calls & Messaging:** Safe commands run immediately; sensitive commands (call, SMS, WhatsApp) prompt confirmation unless trusted; revoking trust in Settings restores confirmation; multi-contact disambiguation works on real contacts.
- [x] **M13–14 — Device & App Control:** Wi-Fi/BT/Location/Display settings open; battery/device status reads ColorOS accurately; installed apps launch cleanly and missing apps return suggestions.
- [x] **M15 — Notifications:** Consent + Android Notification Access gate reading; blocked apps are excluded from summaries; dismiss/open/reply actions work on live notifications.
- [x] **M17 — Automation:** Multi-step voice command executes sequentially; custom Trusted Routine saves & runs by voice/tap; scheduled routine fires at set time; execution history persists across restart.
- [x] **M18 — Offline Engine:** In Airplane Mode, alarms, timers, app launch, and settings shortcuts execute locally; cloud prompt preserves draft and shows "Back online — retry" when Airplane Mode is disabled.
