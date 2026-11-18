# VISION AI — AI Model Registry & Multi-Provider Routing Strategy

---

## 1. Capability-Aware Registry (`lib/features/chat/domain/entities/ai_model_config.dart`)

`AIModelRegistry` maintains structured metadata for every active Gemini, OpenAI, and Claude model:
- **Google Gemini:** `gemini-3.5-flash-lite` (fast default), `gemini-3.8-flash` (balanced reasoning + tools + 1M context), `gemini-4-argon` / `gemini-4-carbon` (flagship).
- **OpenAI (Responses API):** `gpt-5.4-mini` (fast default), `gpt-5.4` (flagship reasoning/tools), `gpt-5.4-nano` (ultra-fast).
- **Anthropic Claude (Messages API):** `claude-haiku-5-5` (fast default), `claude-sonnet-5-5` (balanced reasoning), `claude-opus-5-5` (flagship).
- Obsolete/retired model IDs (e.g., `gemini-2.5-flash`, `gpt-4o`, `claude-3-5-haiku-latest`) are excluded from defaults and automatically mapped forward via `deprecatedModelReplacements`.

Each `AiModelConfig` tracks `capabilities` (`text`, `streaming`, `toolCalling`, `multimodalVision`, `reasoning`), `reasoningScore`, `multilingualScore`, `costTier`, `contextWindowTokens`, and `tier` (`fast`, `balanced`, `flagship`).

---

## 2. Task Complexity Classification (`TaskComplexityClassifier`)

`TaskComplexityClassifier.classify(prompt)` categorizes prompts across English, Hindi, Gujarati, and Hinglish into:
1. `TaskComplexityTier.simpleFast`: Short Q&A, greetings, brief lookups.
2. `TaskComplexityTier.balancedMultilingual`: Multilingual/long conversational questions (`> 90` chars or Indic script / Hinglish markers).
3. `TaskComplexityTier.deepReasoningCoding`: Long analytical prompts (`> 260` chars), code fences, stack traces, debugging, architecture, comparisons, or multilingual analysis cues (`समझाओ`, `વિશ્લેષણ`, `tulna`, `farak`).

When `autoRoutingEnabled` is active, `AIModelRegistry.recommendModelFor(...)` upgrades a lightweight default tier (e.g., `claude-haiku-5-5` -> `claude-sonnet-5-5`) for `deepReasoningCoding` queries **while honoring the user's preferred provider whenever that provider is healthy and enabled**.

---

## 3. Health Circuit Breaker & Fallback (`ProviderHealthManager` + `ProviderFallbackManager`)

- **Respects User Choice:** `ProviderFallbackManager.orderCandidates(...)` places `settings.selectedAiProvider` first whenever healthy and configured, avoiding erratic switching on manual setups.
- **Circuit Breaker Cooldowns:**
  - `AIErrorKind.invalidApiKey` -> 5-minute cooldown so broken credentials aren't retried endlessly.
  - `AIErrorKind.rateLimited` / `quotaExceeded` -> 60-second cooldown before retry.
  - `>= 2` consecutive retryable failures -> adaptive cooldown (`20s`–`120s`).
- **Pre-Token Fallback Only:** In `AIRouter.routeAndStream`, provider failover is attempted only if an error occurs *before* any text/tool delta has been streamed to the user, and every fallback emits a visible `routingNotice` explaining why failover happened.
- **Single Credential Resolution:** `ChatRepositoryImpl.streamUserMessage` resolves and passes `preResolvedCandidates` once per turn, eliminating duplicate `FlutterSecureStorage` queries.

---

## 4. Prompt Grounding & Conversation Context

- `AiCompletionRequest.systemInstruction` enforces: concise 1–3 sentence answers for simple questions, structured depth for complex queries, explicit uncertainty admission, clarifying questions for ambiguous asks, and **strict prohibition against claiming a call/alarm/action completed without real confirmation**.
- `AIConversationManager.buildContextWindow()` caps at `maxMessages = 16` AND `maxApproxChars = 16000` while excluding system/error artifacts.
