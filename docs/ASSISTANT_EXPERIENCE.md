# VISION AI — Dedicated Direct Assistant Experience

**Primary Screen:** `lib/features/assistant/presentation/screens/assistant_experience_screen.dart`  
**System Overlay Entry:** `lib/features/assistant/presentation/screens/assistant_overlay_screen.dart`  
**Orb Widget:** `lib/features/assistant/presentation/widgets/vision_ai_orb.dart`

---

## 1. Entry Points Connected to Dedicated Assistant Experience

1. **Floating Bottom Navigation Center Action:** Prominent glowing Assistant orb button in `VisionGlassNavigationBar` pushes `/assistant`.
2. **Home Screen Orb & Microphone Button:** Tapping the hero `VisionAiOrb` opens `/assistant`; tapping the quick mic control (`Ask VISION`) toggles live voice capture and opens `/assistant`.
3. **In-App `"Hey VISION"` Wake Word Trigger:** `VisionShellScaffold` listens to `VoiceSessionState.wakeTriggerSequence` and opens `/assistant` automatically when wake-word detection triggers while the app is open.
4. **Background Wake Word & Android `ROLE_ASSISTANT`:** `VisionWakeWordService.kt` and `VisionVoiceInteractionSession.kt` launch `AssistantOverlayActivity` (`/assistant-overlay`), which renders `AssistantExperienceScreen(isSystemOverlay: true, autoListenOnOpen: true)` with `TransparencyMode.transparent` and `showWhenLocked="true"`.

---

## 2. Screen Layout & Real State Bindings

- **Animated Atmospheric Backdrop:** Deep `#050812` / `#0A1220` gradient shifting gently toward the active state accent (`idle` cyan, `listening` emerald, `thinking` azure-indigo, `speaking` cyan-ice, `error` coral).
- **Top Section:** `VisionBrandLogo`, active provider & locale subtitle (`Google Gemini • en-IN`), wake-standby indicator pill when active, Open Chat shortcut, and Dismiss button.
- **Center Stage:** Large responsive `VisionAiOrb` (up to `214px`, scaled down on short/landscape screens) + animated state label (`Listening...`, `Understanding...`, `Thinking...`, `Speaking...`, `Ready.`).
- **Live Transcription & AI Preview:** Displays real `VoiceSessionState.liveTranscript`, `VoiceSessionState.errorMessage`, `VoiceSessionState.lastReplyText` (or live streaming `ChatController` reply), and `AutomationActionPromptCard` when a device command requires confirmation, contact disambiguation, or runtime permission.
- **Bottom Controls:** Keyboard toggle (`VisionGlassInput` for quiet typing), Stop button (cancels STT, TTS, or in-flight AI stream), primary Microphone button (interrupts TTS or toggles STT), Chat shortcut, and Dismiss (`SystemNavigator.pop()` on overlay, `context.pop()` in-app).
