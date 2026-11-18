# VISION AI — Multilingual Voice Architecture

## 1. Supported Languages

| Language | Display Name | BCP-47 Locale | STT / TTS Support |
| :--- | :--- | :--- | :--- |
| **English (India)** | English | `en-IN` | Android `SpeechRecognizer` + `TextToSpeech` |
| **Hindi** | हिन्दी | `hi-IN` | Android `SpeechRecognizer` + `TextToSpeech` |
| **Gujarati** | ગુજરાતી | `gu-IN` | Android `SpeechRecognizer` + `TextToSpeech` |

---

## 2. Voice Conversation Pipeline

```text
[Tap Mic / "Hey VISION" Trigger / Assist Gesture]
        │
        ▼ (Pause AudioRecord Wake Service if running)
[VisionVoiceChannel.kt -> SpeechRecognizer (en-IN / hi-IN / gu-IN)]
        │  Streams partial transcripts + RMS dB amplitude
        ▼
[VoiceController -> Local DeviceIntentParser OR Online AIRouter]
        │
        ├── Offline Command? -> AutomationController -> Immediate Execution
        └── Online AI?       -> Connectivity Check -> Streamed AI Response
        │
        ▼
[TextToSpeech (speakReply) -> VoiceListeningPhase.speaking]
        │  Supports Stop Speaking & Interrupt-and-Listen
        ▼
[Resume Wake-Word Foreground Standby if armed]
```

---

## 3. State Guarantees

- **Truthful Microphone Indicator:** `VoiceSessionState.isMicActuallyActive` is `true` **only** when `SpeechRecognizer` is actively listening OR `VisionWakeWordService.isMicActive` confirms `AudioRecord` is in `RECORDSTATE_RECORDING`.
- **Voice States:** `idle`, `requestingPermission`, `listeningCommand`, `listeningWakeWord`, `processingAi`, `speaking`, `error`.
- **Interruptibility:** Tapping the mic or **Interrupt & Speak** while TTS is speaking stops TTS immediately and begins listening for the next user prompt.
- **Language Switching:** Selecting English, Hindi, or Gujarati in Settings updates both `SpeechRecognizer` (`EXTRA_LANGUAGE` / `EXTRA_LANGUAGE_PREFERENCE`) and `TextToSpeech.setLanguage(...)` plus AI system prompt language guidance.
