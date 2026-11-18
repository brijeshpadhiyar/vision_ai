# VISION AI — Intent Recognition & Multilingual Intelligence Engine

Location: `lib/core/intelligence/`

---

## 1. Architecture Overview

VISION AI replaces brittle regex-only matching (`DeviceIntentParser`) with a 7-stage deterministic, multilingual intent recognition pipeline that resolves English, Hindi, Gujarati, Hinglish, and Gujlish commands locally in microseconds before escalating open-ended or low-confidence prompts to cloud AI models.

| Module | File | Responsibility |
| :--- | :--- | :--- |
| Normalizer | `lib/core/intelligence/command_normalizer.dart` | Indic digit conversion (`०-९`, `૦-૯`), spelling typo normalization (`wattsapp`, `alram`, `timmer`, `blutooth`), spoken number dictionaries (EN/HI/GU/Hinglish/Gujlish), script/language detection, and safe sequential clause splitting. |
| Context Tracker | `lib/core/intelligence/conversation_context.dart` | Carries recent `lastContactName`, `lastPhoneNumber`, `lastAppName`, `lastSpokenReply`, active task, and `pendingAction` for confirmation, repeat, cancel, and pronoun follow-ups (`"message her hello"`). |
| Entity Extractor | `lib/core/intelligence/entity_extractor.dart` | Extracts contacts + ordinals (`"first number"`, `"2nd"`), phone numbers, alarm times (relative `in N min`, `tomorrow`/`kal`, `savare`/`subah`/`shaam`/`ratre`, `half past`, spoken words), timer durations, app aliases, settings sections, SMS/WhatsApp message payloads, URLs, and navigation destinations. |
| Classifier | `lib/core/intelligence/intent_classifier.dart` | Scores normalized clauses across 21 `DeviceActionType` intents, applies informational question guards (`"why is my battery draining"`), and emits clarification prompts when required entities are absent (`"Set an alarm"`, `"Call"`). |
| Confidence Manager | `lib/core/intelligence/confidence_manager.dart` | Applies confidence thresholds (`localExecuteThreshold = 0.72`, `clarifyThreshold = 0.55`) and validates parameter completeness before local execution vs AI delegation. |
| Command Registry | `lib/core/intelligence/command_registry.dart` | Declares per-command `intentId`, required parameters, `AutomationPermission` requirements, timeouts, confirmation flags, and `CommandLifecycleStatus` (`received` -> `understood` -> `validated` -> `permissionRequired` -> `confirmationRequired` -> `executing` -> `success`/`failed`/`cancelled`). |
| Engine Orchestrator | `lib/core/intelligence/intent_engine.dart` | Coordinates normalization, confirmation replies, multi-step sequential chains (`followUpActions`), single-clause classification, validation, and sub-millisecond timing measurement. |

---

## 2. Multilingual Resolution Examples

| Input Utterance | Language | Resolved Intent | Entities / Behavior |
| :--- | :--- | :--- | :--- |
| `"Call Tisha."` | English | `call_phone` | `target: "Tisha"`, `requiresConfirmation: true` |
| `"Tisha ne call kar."` | Gujlish | `call_phone` | `target: "Tisha"`, `requiresConfirmation: true` |
| `"Tisha ko phone lagao."` | Hinglish | `call_phone` | `target: "Tisha"`, `requiresConfirmation: true` |
| `"Call the second number of Tisha"` | English | `call_phone` | `target: "Tisha"`, `contactOrdinalIndex: 1` |
| `"Set an alarm for seven tomorrow."` | English | `set_alarm` | `hour: 7, minute: 0, isTomorrow: true` |
| `"Kal savare saat vage alarm muk."` | Gujlish | `set_alarm` | `hour: 7, minute: 0, isTomorrow: true` |
| `"WhatsApp khol."` | Hinglish | `launch_app` | `target: "WhatsApp"` |
| `"Open my WhatsApp."` | English | `launch_app` | `target: "WhatsApp"` |
| `"Open WhatsApp and find Tisha"` | English | `multi_step` | Step 1: `launchApp("WhatsApp")` -> Step 2: `lookupContacts("Tisha")` |
| `"Set an alarm"` | English | Clarification | `"What time would you like me to set the alarm for?"` (no AI call) |
| `"Why is my phone battery draining fast?"` | English | `general_query` | `ConfidenceDisposition.delegateToAi` (0% false execution) |
