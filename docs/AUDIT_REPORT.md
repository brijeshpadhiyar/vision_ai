# VISION AI — Complete Project Audit Report

**Audit Date:** 2026-11-17 (Asia/Kolkata)  
**Application:** VISION AI (`com.brijesh.vision`)  
**Target Device Profile:** OPPO Reno 16 (Android / ColorOS)  
**Frameworks:** Flutter `3.50.0` (Dart `3.14.0`), Riverpod `3.5.0`, GoRouter `18.1.4`, Native Android Kotlin

---

## 1. Executive Summary

The existing VISION AI codebase has a clean feature-first modular Flutter architecture and working native Kotlin `MethodChannel` bridges for basic Android intents and single-shot `SpeechRecognizer`/`TextToSpeech`. However, **Phases 2, 3, and 4 were prematurely marked "Completed"** in `docs/IMPLEMENTATION_PLAN.md` and `OnboardingScreen`:

1. **Google Gemini is broken out-of-the-box** because `AiProviderType.gemini` hardcodes the retired/deprecated model ID `gemini-2.5-flash` (`models/gemini-2.5-flash is no longer available to new users`).
2. **All three AI providers** lack centralized model configuration, model discovery/validation, streaming SSE support, native tool/function calling, usage metadata, cancellation, retry/backoff, and real authenticated connection testing.
3. **Hands-free `"Hey VISION"` wake-word detection is not a real wake-word engine** — `VoiceController.startWakeWordSession()` invokes Android's single-shot `SpeechRecognizer` once, which times out or stops after one utterance and cannot run continuously offline in the background.
4. **System Assistant integration is absent** — there is no `VoiceInteractionService`, `VoiceInteractionSessionService`, `VoiceInteractionSession` overlay, `ROLE_ASSISTANT` integration, or `FOREGROUND_SERVICE_MICROPHONE` service.
5. **Phase 4 Device Automation is incomplete** — missing typed outcome statuses (`Success`, `Failed`, `PermissionRequired`, `ConfirmationRequired`, `NotSupported`, `AmbiguousContact`, `Cancelled`), `NotificationListenerService` integration, WhatsApp intent support, and explicit offline/online hybrid routing checks.

---

## 2. Existing Working Features (Verified in Code)

| Area | Verified Implementation | Status |
| :--- | :--- | :--- |
| **App Bootstrap & Architecture** | `lib/main.dart`, `lib/app/app.dart`, `lib/app/router/app_router.dart`, `AppErrorHandler`, `AppLogger`, dark/light Material 3 theme (`material_ui`) | **Working** |
| **Settings Persistence** | `SettingsLocalDataSource` (`SharedPreferences`) for theme, provider, voice language, haptics, auto-speak, wake-word flag, device actions, direct calls, onboarding flag | **Working** |
| **Encrypted Key Storage** | `SecureCredentialStore` wrapping `flutter_secure_storage: ^11.2.0` (Android Keystore AES-GCM + RSA OAEP) | **Working (Needs hardening)** |
| **Local Chat History** | `ChatLocalDataSource` serializing `ChatMessage` JSON list in `SharedPreferences` | **Working** |
| **Single-Shot Voice STT & TTS** | `VisionVoiceChannel.kt` (`SpeechRecognizer` + `TextToSpeech`) for `en-IN`, `hi-IN`, `gu-IN` with RMS amplitude `EventChannel` | **Working (Foreground only)** |
| **Basic Native Android Automation** | `VisionAutomationChannel.kt`: `ContactsContract` lookup, `ACTION_CALL`/`ACTION_DIAL`, `SET_ALARM`/`SET_TIMER`, `PackageManager` launcher query & launch, `Settings.*` intents, SMS `ACTION_SENDTO`, URL `ACTION_VIEW`, Camera2 torch, `AudioManager` ringer/volume, `ACTION_WEB_SEARCH`, `geo:` navigation, `BatteryManager`/`ConnectivityManager` status | **Working (Incomplete scope)** |
| **Local Multilingual Intent Parser** | `DeviceIntentParser` (EN/HI/GU regex + `[[VISION_ACTION:...]]` tag extraction) | **Working** |
| **Automated APK Archiving** | `android/app/build.gradle.kts` & `scripts/build_apk.ps1` generating timestamped APKs + metadata JSON in `dist/apk/` | **Working** |

---

## 3. Broken Features & Root Causes

### 3.1 Gemini Integration Broken (`gemini-2.5-flash` Retired)
- **Root Cause:** `lib/features/settings/domain/entities/ai_provider_type.dart` hardcodes `defaultModel: 'gemini-2.5-flash'`, and `GeminiRemoteDataSource` reads `request.provider.defaultModel` directly into `POST /v1beta/models/${request.provider.defaultModel}:generateContent`.
- **Impact:** New API accounts receive HTTP 404/400 (`models/gemini-2.5-flash is no longer available to new users`). Users cannot change or select a supported Gemini model (`gemini-3.5-flash-lite`, `gemini-3.8-flash`, `gemini-4-argon`, etc.).

### 3.2 OpenAI & Claude Hardcoded Legacy Models and Schemas
- **Root Cause:** `AiProviderType.openAi` hardcodes `gpt-4o-mini` via legacy `/v1/chat/completions` with `max_tokens` (unsupported by newer reasoning models). `AiProviderType.claude` hardcodes `claude-3-5-haiku-latest` with `anthropic-version: 2023-06-01`.
- **Impact:** Outdated/deprecated model IDs fail or degrade; neither provider supports configurable models, SSE streaming, native tool calling, token usage reporting, or connection testing.

### 3.3 Wake-Word Engine ("Hey VISION") Not Real On-Device Detection
- **Root Cause:** `VoiceController.startWakeWordSession()` triggers `SpeechRecognizer.startListening()` once (`VisionVoiceChannel.kt`), which requires Google Speech Services, stops on `onResults`/`onError`, emits `ERROR_NO_MATCH`/`ERROR_SPEECH_TIMEOUT`, and has no background service.
- **Impact:** Does not operate continuously, cannot run offline without SpeechRecognizer, drains battery if looped, and stops completely when the app is minimized or the screen is off.

### 3.4 Missing Gemini-like Assistant Entry Points & Overlay
- **Root Cause:** `AndroidManifest.xml` only declares a standard launcher `MainActivity`. No `VoiceInteractionService`, `VoiceInteractionSessionService`, `VoiceInteractionSession`, or `FOREGROUND_SERVICE_MICROPHONE` exists.
- **Impact:** VISION cannot be selected as Android's default digital assistant (`ROLE_ASSISTANT`), cannot appear as an overlay/session over other apps, and cannot maintain hands-free standby in the background.

### 3.5 Over-Claimed Roadmap Status
- **Root Cause:** `docs/IMPLEMENTATION_PLAN.md` and `lib/features/onboarding/presentation/screens/onboarding_screen.dart` hardcode Phase 2, Phase 3, and Phase 4 as "Completed" / "Complete" without live API verification, real wake-word architecture, or physical device tests.

---

## 4. Missing Implementations

1. **Multi-Provider AI Core & Orchestration:**
   - `AIProvider`, `AIProviderRegistry`, `AIModelRegistry`, `AIRouter`, `AIConversationManager`, `AIRequest`, `AIResponse`, `AIError`, `AIUsage`.
   - Per-provider enable/disable, model selector + custom model ID input, real authenticated `testConnection()`, automatic routing, optional fallback with explicit user notice, streaming SSE, cancellation, and safe retry with backoff.
2. **Hybrid Offline + Online Execution:**
   - Pre-flight network connectivity detection so offline devices immediately inform the user and still execute local Android commands without wasting cloud timeouts.
3. **Complete Phase 4 Android Automation:**
   - Typed `DeviceActionResult` statuses (`Success`, `Failed`, `PermissionRequired`, `ConfirmationRequired`, `NotSupported`, `AmbiguousContact`, `Cancelled`).
   - `NotificationListenerService` (explicit consent + `ACTION_NOTIFICATION_LISTENER_SETTINGS` status/access + local-only reading).
   - WhatsApp integration via supported Android `Intent.ACTION_SEND` / `https://wa.me/` user-confirmed composer intents.
   - Exact alarm / package visibility / DND permission diagnostics.
4. **Hands-Free `"Hey VISION"` & Android Assistant Architecture:**
   - `ForegroundService` (`foregroundServiceType="microphone"`) running an on-device low-CPU `AudioRecord` wake-word engine (acoustic energy-gated VAD + template/phonetic frame detector + configurable sensitivity + cooldown, with honest accuracy/OPPO ColorOS limitations documented).
   - `VoiceInteractionService` + `VoiceInteractionSessionService` + `VoiceInteractionSession` overlay UI + `ROLE_ASSISTANT` integration.
   - Dedicated Assistant Session overlay/bottom-sheet UI that allows speaking, interrupting, continuing conversation, dismissing, or opening the full VISION app.

---

## 5. Security Audit Findings

1. **Android Backup Exposure (`AndroidManifest.xml`):** `android:allowBackup` is not explicitly set to `false` (defaults to `true`), which can cause Android Auto Backup / ADB backup to include app state alongside Keystore-wrapped preference files.
2. **Missing Keystore Resilience Options (`SecureCredentialStore`):** `FlutterSecureStorage()` uses default `resetOnError: true`, which can silently wipe stored API keys on transient Keystore glitches instead of surfacing a safe error. Setting `AndroidOptions(resetOnError: false, migrateOnAlgorithmChange: true, migrateWithBackup: true)` preserves existing user keys.
3. **Unredacted Exception Strings:** `ApiKeyConfigDialog` displays `error.toString()` and `AppLogger` logs raw error objects without scrubbing accidental key patterns (`AIza...`, `sk-...`, `sk-ant-...`).
4. **Client-Side Key Threat Model:** Storing personal provider API keys on-device exposes them to memory inspection on rooted/compromised devices; production commercial deployments must proxy requests through a backend server with user auth and rate limits.

---

## 6. Recommended Implementation Order

1. **Step 1 — Security & Keystore Hardening:** Secret redaction utility, `SecureCredentialStore` `AndroidOptions` preserving existing keys, `AndroidManifest.xml` `allowBackup="false"`, and safe error display.
2. **Step 2 — Multi-Provider AI Architecture + Gemini/OpenAI/Claude Live Clients:** Central `AIModelRegistry`, `AIProvider`, `AIProviderRegistry`, `AIRouter`, `AIConversationManager`, `AIRequest`/`AIResponse`/`AIError`/`AIUsage`, live SSE streaming, function/tool calling, cancellation, timeout/retry, real `testConnection()`, and Settings/Chat UI updates.
3. **Step 3 — Hybrid Offline/Online Mode & Complete Phase 4 Automation:** Network availability check, typed `DeviceActionStatus`, `NotificationListenerService`, WhatsApp intent integration, and expanded unit/widget tests.
4. **Step 4 — Hands-Free Wake-Word Engine & Android Assistant (`VoiceInteractionService`):** `AudioRecord` foreground wake-word service, `VoiceInteractionService`/`SessionService`/`Session`, `ROLE_ASSISTANT`, OPPO ColorOS battery/autostart guidance, and enhanced voice state UI.
5. **Step 5 — Honest Roadmap, Verification Suite, APK Build & Documentation:** Update `OnboardingScreen` and roadmap status strictly from verified work, run `flutter pub get`, `dart format .`, `flutter analyze`, `flutter test`, build debug APK, and write all required `docs/*.md` reports.
