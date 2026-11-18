# VISION AI — Performance & Latency Optimization Report

Date: 2026-11-18

---

## 1. Speed Optimizations Implemented

1. **Local-First Deterministic Intent Resolution (`lib/core/intelligence/`):**
   - Known Android commands, assistant voice controls (`stop_speaking`, `repeat_last`, `cancel_action`), contact lookups, and clarification prompts resolve completely on-device without waiting for DNS/TLS/cloud LLM inference (`< 5 ms` budget enforced by benchmark suite).
   - Previously unhandled Hinglish/Gujlish utterances (`"WhatsApp khol."`, `"Tisha ne call kar."`, `"Kal savare saat vage alarm muk."`) and word-number times (`"Set an alarm for seven tomorrow."`) now execute locally in sub-millisecond parse time instead of consuming remote API round-trips.
2. **Elimination of Duplicate Secure Storage Reads (`lib/features/chat/data/repositories/chat_repository_impl.dart`):**
   - Removed redundant second `AIRouter.resolveCandidates(...)` lookup inside `routeAndGenerate` / `routeAndStream` by passing `preResolvedCandidates` directly from `ChatRepositoryImpl.streamUserMessage`.
3. **Health-Aware Circuit Breaker (`ProviderHealthManager`):**
   - Providers returning `401 invalidApiKey` enter a 5-minute cooldown and `429`/`quotaExceeded` enter a 60-second cooldown, preventing repeated timeout/retry loops on unhealthy endpoints.
4. **Character- & Turn-Bounded AI Context (`AIConversationManager`):**
   - `buildContextWindow()` limits cloud payloads to `AppConstants.maxContextMessages = 16` AND `16,000` characters while filtering out error banners and system markers.
5. **Voice Audio Contention Removal (`VisionVoiceChannel.kt`):**
   - `speakText(...)` explicitly pauses background `VisionWakeWordService` `AudioRecord` capture before speaking and tunes `RecognizerIntent` silence thresholds (`1800 ms` complete / `1400 ms` possibly complete / `1200 ms` minimum) to reduce clipped utterances and microphone contention.

---

## 2. Privacy-Safe Telemetry (`lib/core/telemetry/performance_telemetry.dart`)

`TelemetryNotifier` tracks rolling metrics cleanly inside memory with all errors scrubbed via `SecretRedactor.redact`:
- Intent parse count & average latency (`avgIntentParseMicros`).
- Local command handled & success counts.
- Native automation count, success rate, & average execution latency (`avgAutomationMs`).
- AI request count, success rate, average first-token latency (`avgAiFirstTokenMs`), and total completion latency (`avgAiTotalMs`).
- Voice STT finalization, TTS startup, and end-to-end latencies.
- Sanitized diagnostic JSON export on `/diagnostics` (`DiagnosticsScreen`).

---

## 3. Verified Benchmark Summary (`flutter test`)

- Total automated test groups passed: **39 / 39** (`0` failures).
- Multilingual Intent Benchmark Suite (`test/intelligence_benchmark_test.dart`):
  - **English:** 36 utterances verified (calls, contact ordinals, tomorrow/word-number alarms, fractional timers, apps, settings, media controls, stop/repeat/cancel, multi-step sequential, clarification prompts, and informational query guard -> 0 false device executions).
  - **Hindi:** 30 Devanagari utterances verified.
  - **Gujarati:** 30 Gujarati script utterances verified.
  - **Hinglish / Gujlish & Typos:** 32 mixed/typo utterances verified.
  - Average deterministic parse latency verified `< 5 ms` (`5,000 µs`).
