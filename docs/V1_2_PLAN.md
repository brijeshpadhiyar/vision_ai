# VISION AI — v1.2 Implementation Plan

**Plan date:** 19 November 2026  
**Target release:** VISION AI v1.2 (`1.2.0+3`, `com.brijesh.vision`)  
**Prerequisite:** VISION AI v1.1 (Dynamic Device/OEM Detection + Module 25 Privacy & Security Dashboard — Verified)

---

## 1. Approved v1.2 Scope

1. **Wave 1 — Module 20: Camera & Visual Intelligence**
   - Native Android camera capture & gallery photo picker with automatic downscaling (max 1024px JPEG) and base64 encoding.
   - Multimodal image understanding across **Google Gemini**, **OpenAI**, and **Anthropic Claude**.
   - Inline image preview & attachment controls in Chat, with session-only privacy (image bytes stay in memory and are never written to `SharedPreferences`).
2. **Wave 2 — Module 21: Internet Research**
   - Live on-device web research service (no extra API key required) returning structured multi-source snippets and URLs.
   - Grounded AI synthesis across all 3 providers with inline numbered citations and clickable source chips in Chat.
   - Voice & text triggers (`"research ..."`, `"latest news about ..."`, or one-tap **Web** toggle in Chat).

---

## 2. Wave 1 — Module 20: Camera & Visual Intelligence

### Architecture
1. **Native Android Image Capture & Picker (`VisionMediaChannel.kt` + `MainActivity.kt`):**
   - MethodChannel: `com.brijesh.vision/media`
   - `capturePhoto()`: Launches system camera (`MediaStore.ACTION_IMAGE_CAPTURE`) using an app-private cache URI via `FileProvider` (no `CAMERA` runtime permission required when delegating to the system camera), scales the captured JPEG to max `1024px` on the longest edge (82% quality), encodes to base64, and deletes the temp cache file immediately.
   - `pickImage()`: Launches Android Photo Picker (`MediaStore.ACTION_PICK_IMAGES` on Android 13+ / `ACTION_GET_CONTENT` fallback — zero storage permissions required), scales to max `1024px` JPEG, and returns `{ base64, mimeType, width, height, byteLength, label }`.
2. **Domain & Multi-Provider Multimodal Support:**
   - Add `ImageAttachment` (`base64Data`, `mimeType`, `width`, `height`, `label`) to `ChatMessage`, `AiCompletionRequest`, and `AIRequest`.
   - Update all 3 provider adapters:
     - **Gemini (`gemini_remote_datasource.dart`):** Attach `inlineData: { mimeType, data }` part on the user turn.
     - **OpenAI (`openai_remote_datasource.dart`):** Attach `{ type: 'input_image', image_url: 'data:<mime>;base64,<data>' }` on the user turn.
     - **Claude (`claude_remote_datasource.dart`):** Attach `{ type: 'image', source: { type: 'base64', media_type: <mime>, data: <data> } }` on the user turn.
3. **Chat UI (`ChatInputBar`, `ChatScreen`, `ChatMessageBubble`):**
   - Add Camera and Gallery buttons next to the chat input field.
   - Show a removable thumbnail preview strip before sending; render the attached photo thumbnail inside sent user bubbles.
4. **Privacy Safeguard:**
   - `ChatMessage.toJson()` omits raw base64 image payloads (storing only a lightweight `[Image attached]` marker if history saving is opted in) so photos are never silently persisted in `SharedPreferences`.

---

## 3. Wave 2 — Module 21: Internet Research

### Architecture
1. **Live Research Service (`lib/features/research/domain/services/internet_research_service.dart`):**
   - `ResearchSource` (`title`, `url`, `snippet`, `domain`) and `ResearchBundle` (`query`, `sources`, `fetchedAt`).
   - Queries DuckDuckGo Instant Answer API + Wikipedia OpenSearch/Summary API + DuckDuckGo Lite HTML results via the existing `http.Client` (no paid search API key needed, strict 10s timeout, deduplicated top 5 sources).
   - Builds a compact grounded context block (`LIVE WEB RESEARCH SOURCES [1..N]`) injected into `AiCompletionRequest`.
2. **Grounded AI Synthesis & Citations:**
   - Add `List<ResearchSource> citations` to `ChatMessage` (serialized cleanly if history saving is enabled).
   - Add a **Web Research** toggle chip in `ChatInputBar` + automatic intent detection for explicit research phrases (`"research ..."`, `"search the web for ..."`, `"latest news on ..."`).
   - Render clickable **Source Citation Chips** below assistant replies in `ChatMessageBubble` (tapping opens the URL cleanly).
3. **Offline & Error Handling:**
   - Checks `NetworkStatusService.isOnline()` before searching; if offline, informs the user cleanly without crashing.
   - If web search returns zero results or times out, transparently notifies the user and falls back to the AI model's response without fabricating citations.

---

## 4. Definition of Done (v1.2)

- [x] `flutter analyze --no-pub` passes with 0 issues.
- [x] All existing + new v1.2 unit/widget tests pass (`66/66` tests including multimodal serialization, `InternetResearchService`, `AiProviderType.edgeAi`, and `VisionLlmProvider`).
- [x] Android Kotlin, XML, ML Kit R8 rules, and Release APK built via `scripts/build_apk.ps1` (`version 1.2.0+3` → `vision-release-20261119-125125.apk`).
- [ ] Physical device verification completed on Android hardware.
