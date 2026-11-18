# VISION AI — Multi-Phase Implementation Plan

## Target Profile
- **Application Name**: VISION (`vision_ai`)
- **Android Application ID**: `com.brijesh.vision`
- **Primary Target Device**: OPPO Reno 16 (Android, ARM64)
- **AI Providers**: Google Gemini (`gemini-3.5-flash-lite` / `3.8-flash` / `4`), OpenAI (`gpt-5.4-mini` / `5.4`), Anthropic Claude (`claude-haiku-5-5` / `sonnet-5-5` / `opus-5-5`)
- **Voice Locales**: English (`en-IN`), Hindi (`hi-IN`), Gujarati (`gu-IN`)

---

## Phase 1: Production Project Foundation — **Completed**
- Feature-first modular architecture (`app`, `core`, `features/*`), Riverpod, GoRouter, Material 3 themes, secret-redacted `AppErrorHandler` & `AppLogger`, and `SharedPreferences` persistence.

---

## Phase 2: Multi-Provider AI Orchestration — **Implemented (Pending Live User API Key Verification)**
- Unified `AIProvider`, `AIModelRegistry`, `AIProviderRegistry`, `AIRouter`, `AIConversationManager`, `AIRequest`, `AIResponse`, `AIError`, `AIUsage`.
- Live REST + SSE streaming + tool-calling clients for Gemini, OpenAI Responses API (`/v1/responses`), and Claude Messages API (`/v1/messages`).
- Centralized model selection, deprecated model migration (`gemini-2.5-flash` -> `gemini-3.5-flash-lite`), real authenticated `Test Connection`, automatic routing, transparent fallback, and cooperative cancellation.
- Hardware-backed Android Keystore storage (`FlutterSecureStorage` with `resetOnError: false`, `migrateWithBackup: true`) and `SecretRedactor`.

---

## Phase 3: Multilingual Voice, Wake-Word & Assistant Integration — **Implemented (Pending Physical Device Verification)**
- Multilingual `SpeechRecognizer` STT & `TextToSpeech` for `en-IN`, `hi-IN`, `gu-IN` with interrupt/stop/listen-again flow.
- Foreground `VisionWakeWordService.kt` (`FOREGROUND_SERVICE_MICROPHONE`) with offline `AudioRecord` DSP cadence gate for `"Hey VISION"` and configurable sensitivity.
- `VisionVoiceInteractionService`, `VisionVoiceInteractionSessionService`, `VisionVoiceInteractionSession`, `ROLE_ASSISTANT`, and translucent `AssistantOverlayActivity` (`/assistant-overlay`).

---

## Phase 4: Android Device Automation & Actions — **In Progress (Pending Physical Device Verification)**
- Typed `DeviceActionStatus` (`success`, `failed`, `permissionRequired`, `confirmationRequired`, `notSupported`, `ambiguousContact`, `cancelled`).
- Permission-guarded calls, contacts, alarms/timers, app launching, system settings, SMS, WhatsApp composer, consent-gated `VisionNotificationListenerService`, torch, ringer/volume, search, maps, offline connectivity guard, and ColorOS telemetry.
- See `docs/PHASE_4_COMPLETION_REPORT.md` and `docs/AUDIT_REPORT.md`.
