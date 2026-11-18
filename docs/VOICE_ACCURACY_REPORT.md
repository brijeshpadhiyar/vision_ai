# VISION AI — Voice Accuracy, STT/TTS Pipeline & Wake-Word Report

---

## 1. Voice Pipeline Improvements

### A. Speech-to-Text Stability (`android/.../VisionVoiceChannel.kt`)
- Configured Android `RecognizerIntent` silence-detection tuning:
  - `EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS = 1800L`
  - `EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS = 1400L`
  - `EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS = 1200L`
- Prevents short natural breathing pauses in English (`en-IN`), Hindi (`hi-IN`), and Gujarati (`gu-IN`) queries from prematurely cutting off user commands.

### B. Audio Contention Elimination Between Wake-Word Service & TTS/STT
- Previously, `SpeechRecognizer.onResults` resumed `VisionWakeWordService`'s `AudioRecord` immediately before AI dispatch or TTS playback began.
- Now `speakText(...)` explicitly pauses `VisionWakeWordService` prior to TTS playback, while `resumeWakeServiceIfRunning()` remains gated on `!isListening && !isSpeaking`, preventing audio-focus glitches and microphone contention on OPPO ColorOS.

### C. Natural TTS Output Cleanup (`lib/features/voice/presentation/controllers/voice_controller.dart`)
- Added `VoiceController._sanitizeForSpeech` to strip Markdown symbols (`*`, `_`, `~`, `#`, `>`), extract link labels, replace triple-backtick code fences with spoken `"Code snippet provided on screen."`, and remove any residual `[[VISION_ACTION:...]]` tags before calling native TTS.
- Intercepts local voice interruption commands (`"stop speaking"`, `"chup ho jao"`, `"શાંત થા"`) cleanly inside `_dispatchVoiceCommandToAi` before AI/chat round-trips.
- Prevents manual-tap microphone sessions containing the word `"vision"` from falsely triggering `WakeWordDetector` stripping.

### D. Expanded Assistant Visual & Voice Lifecycle States (`VoiceListeningPhase`)
- Added `understanding`, `executing`, and `confirmationRequired` alongside `idle`, `requestingPermission`, `listeningCommand`, `listeningWakeWord`, `processingAi`, `speaking`, and `error`.
- Latency across STT finalization (`sttFinalMs`), TTS startup (`ttsStartupMs`), and full end-to-end voice turn (`endToEndMs`) is recorded in `TelemetryNotifier`.
