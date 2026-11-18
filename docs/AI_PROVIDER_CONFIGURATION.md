# VISION AI — Multi-Provider AI Configuration Guide

## 1. Architecture Overview

VISION AI uses a provider-independent orchestration layer under `lib/features/chat/`:

- **`AIProvider`** (`lib/features/chat/domain/repositories/ai_provider.dart`): Common contract for `generate()`, `stream()`, `testConnection()`, and `listAvailableModels()`.
- **`AIModelRegistry`** (`lib/features/chat/domain/entities/ai_model_config.dart`): Centralized catalog of active models, capabilities, endpoints, and retired-model migration rules.
- **`AIProviderRegistry`**: Holds live `GeminiProvider`, `OpenAIProvider`, and `ClaudeProvider` instances.
- **`AIRouter`** (`lib/features/chat/domain/services/ai_router.dart`): Handles manual provider/model selection, automatic task-based routing, and transparent fallback with explicit `routingNotice` alerts.
- **`AIConversationManager`** (`lib/features/chat/domain/services/ai_conversation_manager.dart`): Preserves multi-turn conversation history when switching between Gemini, OpenAI, and Claude.

---

## 2. Configured Providers, Endpoints & Current Models

### A. Google Gemini (`GeminiProvider`)
- **Base Endpoint:** `https://generativelanguage.googleapis.com/v1beta`
- **Generation / Streaming:** `POST /v1beta/models/{modelId}:generateContent` and `:streamGenerateContent?alt=sse`
- **Model Discovery:** `GET /v1beta/models` (Header: `x-goog-api-key`)
- **Active Catalog Models:**
  - `gemini-3.5-flash-lite` (Recommended Default — successor to retired `gemini-2.5-flash`)
  - `gemini-3.8-flash` (Balanced Flash / agentic tool use)
  - `gemini-4-argon` (Frontier reasoning & coding)
  - `gemini-4-carbon` (Flagship reasoning)
- **Evaluation of Interactions API (`/v1beta/interactions`):**
  Google's newer Interactions API stores conversation state server-side via `previous_interaction_id`. Because VISION AI preserves a single shared client-side conversation history across Gemini, OpenAI, and Claude (`AIConversationManager`), `generateContent` / `streamGenerateContent?alt=sse` remains the most compatible and portable REST choice for multi-provider switching.
- **Required Key:** Google AI Studio API key (`AIza...`)

### B. OpenAI (`OpenAIProvider`)
- **Primary Endpoint:** `POST https://api.openai.com/v1/responses` (Responses API)
- **Model Discovery:** `GET https://api.openai.com/v1/models`
- **Active Catalog Models:**
  - `gpt-5.4-mini` (Default)
  - `gpt-5.4` (Flagship)
  - `gpt-5.4-nano` (Ultra-low latency)
- **Capabilities:** Text, SSE streaming (`response.output_text.delta`, `response.completed`), top-level function tools (`type: "function"`), and token usage (`input_tokens`, `output_tokens`, `total_tokens`). Reasoning models omit legacy `temperature` automatically.
- **Required Key:** OpenAI API key (`sk-...`)

### C. Anthropic Claude (`ClaudeProvider`)
- **Primary Endpoint:** `POST https://api.anthropic.com/v1/messages` (`anthropic-version: 2023-06-01`)
- **Model Discovery:** `GET https://api.anthropic.com/v1/models`
- **Active Catalog Models:**
  - `claude-haiku-5-5` (Default — successor to retired `claude-3-5-haiku-latest`)
  - `claude-sonnet-5-5` (Balanced reasoning & coding)
  - `claude-opus-5-5` (Complex agentic workflows)
- **Capabilities:** Text, SSE streaming (`content_block_delta`, `input_json_delta`), tool use (`input_schema`), token usage, and automatic user/assistant role normalization when switching providers mid-thread.
- **Required Key:** Anthropic API key (`sk-ant-...`)

---

## 3. Setup & Connection Verification

1. Open **Settings → Multi-Provider AI Orchestration**.
2. Tap **Add Key** on Gemini, OpenAI, or Claude and paste your personal API key.
   - Keys are encrypted using `FlutterSecureStorage` backed by Android Keystore (`AES_GCM_NoPadding` + `RSA_ECB_OAEPwithSHA_256andMGF1Padding`).
   - Existing keys are preserved across upgrades (`resetOnError: false`, `migrateOnAlgorithmChange: true`, `migrateWithBackup: true`).
3. Tap **Model** to pick from the built-in catalog, live-discovered models, or enter any custom model ID.
4. Tap **Test Connection** — VISION only displays **Connected** after a real authenticated `GET /models` + completion probe succeeds.

---

## 4. API Key Security & Production Proxy Recommendation

- **Client-Side Limitation:** Even with Android Keystore encryption at rest and `SecretRedactor` scrubbing logs/errors, any API key decrypted inside a mobile client app's process memory could theoretically be inspected on a rooted/compromised device.
- **Commercial Production Recommendation:** For any commercial or public release, do **not** ship or store personal/shared provider keys on client devices. Instead, deploy a lightweight backend proxy (e.g., Cloud Run / Firebase Functions) with user authentication (Firebase Auth / OAuth), per-user rate limits, quota enforcement, and server-side secret management (Google Secret Manager).

---

## 5. Troubleshooting

- **`models/gemini-2.5-flash is no longer available`:** Automatically migrated to `gemini-3.5-flash-lite` on settings load, or select `gemini-3.8-flash` in Settings → Model.
- **Invalid API key (401/403):** Re-enter the key in Settings and tap **Test Connection**.
- **Rate limit / Quota exceeded (429):** Enable **Provider Fallback** in Settings so VISION can route to another configured provider and notify you transparently.
- **Offline:** VISION detects offline status before sending cloud requests, preserves your unsent draft, and continues executing supported local Android commands.
