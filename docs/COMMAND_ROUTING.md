# VISION AI — Local-First Command Routing Strategy

---

## 1. Local-First Execution Rule

Whenever `settings.deviceActionsEnabled` is enabled, every text or voice utterance passes through `DeviceIntentParser.analyzeIntent(input, context: ...)` **before** any network check, key lookup, or cloud LLM call is invoked.

### Decision Flow
1. **Receive (`CommandLifecycleStatus.received`)** — Utterance arrives from `ChatController` or `VoiceController`.
2. **Understand (`CommandLifecycleStatus.understood`)** — `IntentEngine.analyze` normalizes scripts/typos and extracts entities.
   - If essential parameters are missing (`res.needsClarification == true`), VISION responds immediately offline with the clarification prompt and updates `ConversationIntelligenceContext`.
3. **Validate (`CommandLifecycleStatus.validated`)** — `CommandRegistry.descriptorFor(type).validate(request)` checks bounds (`hour in 0..23`, `durationSeconds in 1..86400`, non-empty targets).
4. **Execute / Guard (`permissionRequired` / `confirmationRequired` / `executing`)**:
   - **Voice Control Meta-Commands:** `stopSpeaking`, `repeatLast`, and `cancelAction` run purely in memory without touching Android intents or external APIs.
   - **Device & System Commands:** `callPhone`, `lookupContacts`, `launchApp`, `setAlarm`, `dismissAlarm`, `setTimer`, `dismissTimer`, `openSettings`, `deviceStatus`, `sendSms`, `sendWhatsapp`, `readNotifications`, `openUrl`, `toggleFlashlight`, `setRingerMode`, `adjustVolume`, `webSearch`, and `navigateTo` dispatch directly via `AutomationController`.
   - **AI Escalation (`ConfidenceDisposition.delegateToAi`):** Only conversational, analytical, creative, or low-confidence queries are sent over HTTPS to the active AI provider.

---

## 2. Offline & Consent Guarantees

- **Zero API Cost for Device Control:** Commands matched cleanly by `IntentEngine` bypass external AI endpoints and offline checks, allowing alarms, timers, flashlight, app launch, calls, settings, and status checks to function fully offline.
- **Explicit Consent Enforced Locally:**
  - `directPhoneCallsEnabled`: Defaults to dialer pre-fill (`ACTION_DIAL`); direct `ACTION_CALL` requires explicit confirmation unless already confirmed in context.
  - `notificationListenerConsent`: Required before `readNotifications` accesses `VisionNotificationListenerService`.
  - `personalMemoryEnabled`: Defaults to `false`; explicit user preferences are injected into AI prompts only when toggled on.
