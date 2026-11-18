# VISION AI — "Hey VISION" Wake-Word & Assistant Implementation

## 1. Architecture Summary

VISION implements a two-part native Android architecture for hands-free activation:

1. **`VisionWakeWordService.kt`** — An Android foreground service (`android:foregroundServiceType="microphone"`) displaying a persistent notification with a one-tap **Stop Listening** action.
2. **Offline `AudioRecord` DSP Wake-Word Engine** — Captures 16 kHz mono 16-bit PCM frames (30 ms / 480 samples) locally on-device with zero cloud audio streaming:
   - **Stage 1 (Low-CPU Noise-Floor & VAD Gate):** Computes frame RMS energy and zero-crossing rate against an adaptive Exponential Moving Average (EMA) noise floor. Quiet background frames exit immediately.
   - **Stage 2 (Multi-Syllable Cadence Gate):** Evaluates two-burst / sustained-syllable speech contours characteristic of `"Hey VISION"` using configurable sensitivity (`20%`–`90%`) and a 2.5 s re-trigger cooldown.
3. **Mic Contention Prevention:** When `"Hey VISION"` triggers, `VisionWakeWordService` pauses `AudioRecord` (`ACTION_PAUSE_MIC`) while `SpeechRecognizer` and `TextToSpeech` run, then automatically resumes (`ACTION_RESUME_MIC`) once the reply finishes.

---

## 2. Assistant Entry Points (`VoiceInteractionService` & `ROLE_ASSISTANT`)

- **`VisionVoiceInteractionService.kt`** (`BIND_VOICE_INTERACTION`) and **`VisionVoiceInteractionSessionService.kt`** register VISION as a valid Android Digital Assistant (`ROLE_ASSISTANT` via `RoleManager`).
- **`VisionVoiceInteractionSession.kt`** renders a native bottom-sheet overlay (`res/layout/vision_assistant_overlay.xml`) over the current screen on Assist triggers, captures speech, and hands off complex requests to **`AssistantOverlayActivity.kt`** (`/assistant-overlay` translucent Flutter overlay).

---

## 3. Lifecycle Behavior Matrix

| Scenario | Behavior |
| :--- | :--- |
| **App in foreground** | `VisionWakeWordService` emits `wakeWordTriggered` -> `VoiceController` starts command `SpeechRecognizer` immediately. |
| **App minimized** | Foreground service keeps `AudioRecord` alive with a persistent notification. Trigger launches `AssistantOverlayActivity` over the current screen (requires battery optimization exemption / Display Over Other Apps on strict OEMs). |
| **App swiped/killed** | Standard non-system apps cannot guarantee permanent survival after user force-stop on ColorOS/Android 14+. User must reopen VISION or invoke via Default Assistant gesture (`ROLE_ASSISTANT`). |
| **Phone restarted** | Android restricts starting `microphone` foreground services directly from `BOOT_COMPLETED` on Android 14+ (API 34+). Re-arm wake-word standby after unlocking and opening VISION, or invoke via System Assistant (`ROLE_ASSISTANT`). |
| **Screen locked** | `AssistantOverlayActivity` sets `showWhenLocked="true"` and `turnScreenOn="true"`, and `voice_interaction_service.xml` sets `supportsLaunchVoiceAssistFromKeyguard="true"`; however, ColorOS & Android 14+ restrict background mic recording when locked unless bound as the active System Assistant. |

---

## 4. OPPO Reno 16 (ColorOS) Required Configuration

ColorOS applies aggressive background process killing (`Athena` / `OplusAppStartupManager`). For reliable background standby on OPPO Reno 16:

1. **Battery Optimization:** Settings → **Battery** → **App battery management** → **VISION** → enable **Allow background activity** (or use VISION Settings → **OPPO ColorOS Battery Optimization**).
2. **Auto-Launch:** Phone Manager / Settings → **Apps** → **App Management** → **VISION** → enable **Allow Auto-launch**.
3. **Lock App in Recents:** Open Android Recent Apps switcher, tap the `⋮` menu on VISION's card, and select **Lock**.
4. **Default Digital Assistant:** Settings → **Apps** → **Default apps** → **Digital assistant app** → select **VISION** (or use Settings → **Default Digital Assistant (ROLE_ASSISTANT)**).
5. **Notification Permission (Android 13+):** Allow notifications for VISION so the mandatory foreground microphone standby notification can be shown.
