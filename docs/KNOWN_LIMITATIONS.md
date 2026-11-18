# VISION AI — Known Limitations & Platform Restrictions

## 1. AI Provider & Credential Limitations
- **Live Authenticated Tests Not Executed Here:** No `GEMINI_API_KEY`, `OPENAI_API_KEY`, or `ANTHROPIC_API_KEY` environment variables were present in this environment. All live REST/SSE formats were verified against current official documentation and exercised via mocked HTTP streaming tests (`test/ai_providers_test.dart`), while real account execution awaits user keys entered in Settings.
- **Client-Side Key Security:** API keys are encrypted at rest via Android Keystore (`flutter_secure_storage`), scrubbed from logs (`SecretRedactor`), and blocked from Android Auto Backup (`android:allowBackup="false"`). However, for commercial distribution, a backend proxy with user authentication and rate limiting is required.

---

## 2. Wake-Word & Background Restrictions (Android 14+ / OPPO ColorOS)
- **DSP Acoustic Detector vs. Neural Phoneme Model:** `VisionWakeWordService.kt` uses an offline, zero-cloud-streaming `AudioRecord` DSP cadence/energy/ZCR detector for `"Hey VISION"` without requiring a paid Picovoice license or bundling large native ML weights. In noisy speech environments, false triggers can occur depending on the sensitivity slider; for production-grade phonetic accuracy, a custom-trained openWakeWord `.onnx` or Sherpa-ONNX keyword-spotting model should be plugged into `VisionWakeWordService`.
- **Process Removal (Swipe-Kill):** On OPPO ColorOS, swiping VISION away from Recents terminates standard background services unless the user locks VISION in Recents, enables **Allow Auto-launch**, and sets Battery Management to **Allow background activity**.
- **Device Reboot:** Android 14+ restricts starting `FOREGROUND_SERVICE_MICROPHONE` directly from `BOOT_COMPLETED` receivers without user interaction. After rebooting, open VISION to re-arm background wake-word standby, or use the system Assistant gesture (`ROLE_ASSISTANT`).
- **Lock Screen:** `VoiceInteractionService` and `AssistantOverlayActivity` support keyguard invocation (`supportsLaunchVoiceAssistFromKeyguard="true"`, `showWhenLocked="true"`), but ColorOS/Android may require device unlock before opening third-party apps, placing calls, or accessing certain secure settings.

---

## 3. Android Automation Restrictions
- **WhatsApp:** Android does not provide a public API to silently send WhatsApp messages in the background. VISION opens the pre-filled WhatsApp composer (`wa.me` / `ACTION_SEND`) and requires the user to tap Send.
- **Silent Ringer Mode (DND):** Changing ringer mode to `silent` on Android 6+ requires explicit Do Not Disturb Policy Access (`Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS`).
- **Notification Reading:** Requires both explicit consent in VISION Settings AND manual activation in Android Notification Access (`Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS`).
- **Physical Device Verification Pending:** No OPPO Reno 16 device was attached over ADB in this environment; all native Kotlin intents, ColorOS battery settings, and `AudioRecord` mic sessions must be tested on the physical device using the built debug APK.
