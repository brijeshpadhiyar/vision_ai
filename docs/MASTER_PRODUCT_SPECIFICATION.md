# VISION AI — MASTER PRODUCT SPECIFICATION

**Product:** VISION AI  
**Version:** 1.0  
**Planning date:** 18 November 2026  
**Discussion date:** 19 November 2026  
**Platform:** Android  
**Primary device:** OPPO Reno 16  
**Application ID:** `com.brijesh.vision`

---

## 1. Product Vision

VISION is a personal Android AI assistant designed to provide hands-free voice interaction, multi-provider AI intelligence, Android device automation, and context-aware assistance.

The goal is to provide a Gemini-like assistant experience with a customizable identity, voice, AI engine and Android integrations.

**Tagline:** *Your Intelligence. Your Assistant.*

---

## 2. Confirmed Product Decisions

| Requirement | Decision |
|---|---|
| Assistant name | VISION |
| Activation | Hey VISION + Android default assistant activation |
| Response style | Voice first |
| AI provider selection | Manual |
| Memory | Current session only |
| Permissions | Trusted commands |
| Connectivity | Hybrid online + offline |
| Languages | English, Hindi, Gujarati |
| Frontend | Flutter |
| Native Android | Kotlin |
| State management | Riverpod |

### Confirmed v1.0 Design Resolutions (19 November 2026)

| Area | Locked Decision |
|---|---|
| **Engagement Scope** | Full v1.0 alignment across **Modules 01–18**. Modules 19–26 remain deferred pending separate approval. |
| **AI Providers & Routing (06–08)** | **Strictly manual by default**: remove auto-routing from v1.0 UI/logic; set automatic provider fallback to **OFF** by default; retain opt-in provider fallback in Settings with an explicit notice whenever fallback triggers. |
| **Memory & History (09, 16)** | Default to **in-memory current-session-only chat**, with an opt-in **"Save conversation history"** toggle in Settings. Keep long-term personal memory **OFF by default** as an explicit opt-in feature. |
| **Identity & Voice (01, 02)** | **Native Android TTS** (voices filtered by language/accent) with speech rate, pitch, and interrupt/resume controls + structured **Assistant Identity** settings (personality preset, communication style, custom greeting, custom instructions) injected into the system prompt. |
| **Activation & Wake-Word (04)** | Keep the offline DSP wake-word engine for v1.0 (tuned sensitivity & false-trigger guards), add an **Android Home-Screen Widget** (tap-to-talk / status), and add a **`BOOT_COMPLETED` recovery notification** + OPPO ColorOS battery/auto-launch setup guide. |
| **Trusted Commands (10–15, Sec. 6)** | **Tiered trust model**: safe commands (alarms, timers, app launch, settings, device status, flashlight, volume) are trusted by default; sensitive actions (calls, SMS, WhatsApp, notifications, multi-step routines) require confirmation unless explicitly trusted by the user, with a Settings screen to view and revoke trusted commands. |
| **Automation & Offline (17, 18)** | Practical v1.0 automation: chained multi-step voice commands (split & execute sequentially), user-defined **Trusted Routines** (local JSON), local **Execution History** log, and basic time-scheduled routines via Android `AlarmManager`/`WorkManager` (with confirmation for sensitive steps). |
| **Multilingual (05)** | Add an **Auto** language mode alongside `en-IN`, `hi-IN`, and `gu-IN`: preferred STT locale + script/lexical detection on transcript/text, instruct AI to reply in the detected language, and automatically switch Android TTS voice to match the reply's language/script. |
| **Usage & DoD (07, Sec. 8)** | Track local per-provider/model usage counters (requests + input/output tokens) in Settings/Diagnostics. Gate every roadmap item with a two-stage status: **`Code & Tests Verified`** → **`Device Verified (OPPO Reno 16)`** via an explicit ADB/APK test checklist. |

---

## 3. Core Product Modules

### Module 01 — Assistant Identity
- Personality
- Greeting
- Communication style
- Assistant name and branding
- User-customizable behaviour

### Module 02 — Voice Identity
- Voice selection
- Speech rate
- Voice pitch
- Accent
- Language preferences
- Interrupt and resume

### Module 03 — Assistant Interface
- Home screen
- Animated AI orb
- Idle state
- Listening state
- Thinking state
- Speaking state
- Error state
- Conversation screen
- Settings

### Module 04 — Activation
- Wake-word detection
- Android assistant role
- Power/default assistant integration
- Home-screen widget
- Background operation
- Lock-screen behaviour
- Boot and service recovery

### Module 05 — Language
- English
- Hindi
- Gujarati
- Automatic language detection
- Multilingual conversations
- Language-specific TTS

### Module 06 — AI Providers
- Google Gemini
- OpenAI
- Anthropic Claude
- Provider configuration
- API key management
- Model management
- Connection testing
- Provider-specific errors

### Module 07 — Model Management
- Manual provider selection
- Model selection
- Default model
- Model capabilities
- Model availability
- Manual switching
- Usage information

### Module 08 — AI Routing
- User intent detection
- Request classification
- AI request handling
- Tool calling
- Context handling
- Provider-independent responses

### Module 09 — Conversation
- Voice conversation
- Text conversation
- Streaming responses
- Conversation context
- Stop response
- Repeat response
- Session clearing
- Optional conversation history

### Module 10 — Android Tool Execution
- Command parser
- Intent execution
- Permission checks
- Confirmation flow
- Execution results
- Error handling

### Module 11 — Phone and Contacts
- Contact lookup
- Multiple contact resolution
- Phone number selection
- Dialer integration
- Calling with appropriate confirmation

### Module 12 — Messaging
- SMS
- WhatsApp sharing and supported integrations
- Message composition
- Recipient selection
- User-confirmed sending

### Module 13 — Device Control
- Wi-Fi settings
- Bluetooth settings
- Location settings
- Display settings
- Battery information
- Supported device information

### Module 14 — Application Control
- Installed app discovery
- App launching
- Supported deep links
- App visibility restrictions
- Launch failure handling

### Module 15 — Notifications
- Notification listener
- User consent
- Notification summaries
- Notification privacy
- Supported notification actions

### Module 16 — Memory
- Current-session context
- Session reset
- Optional saved conversation history
- No long-term personal memory by default

### Module 17 — Automation
- Multi-step commands
- Trusted routines
- Scheduled actions
- Execution history
- Confirmation for sensitive actions

### Module 18 — Offline Engine
- Local command recognition
- Offline alarms
- Offline timers
- App launching
- System settings shortcuts
- Connectivity detection
- Online request recovery

---

## 4. Additional Planned Modules

19. Daily planner  
20. Camera and visual intelligence  
21. Internet research  
22. External app integrations  
23. Smart home integration  
24. Proactive intelligence  
25. Privacy and security dashboard  
26. Developer assistant  

These modules are proposed and require separate approval before implementation.

---

## 5. Technical Architecture

- Flutter application.
- Kotlin native Android integration.
- Riverpod state management.
- GoRouter navigation.
- Common AI provider interface.
- AI model registry.
- Command execution engine.
- Android MethodChannel integration.
- Local database/storage where required.
- Secure credential management.
- On-device wake-word processing.

---

## 6. Security Requirements

- Never hardcode API keys.
- Never log API secrets.
- Request minimum required permissions.
- Require confirmation for sensitive actions.
- Allow the user to revoke trusted commands.
- Provide microphone and notification privacy controls.
- Do not upload private device data without consent.
- Document Android platform restrictions.

---

## 7. Development Principles

1. Audit existing project before implementation.
2. Read current official documentation.
3. Avoid duplicate implementations.
4. Implement reusable services.
5. Separate UI, business logic and native integrations.
6. Test each feature independently.
7. Verify features on physical Android hardware.
8. Maintain documentation.
9. Never mark unverified features as completed.
10. Preserve existing user configuration.

---

## 8. Definition of Done

A feature is completed only when:

- Implementation exists.
- Required permissions work.
- Success and failure states are handled.
- Unit tests pass where applicable.
- Integration tests pass where applicable.
- Physical device testing is completed where required.
- Documentation is updated.
- Roadmap status is verified.

---

## 9. Planning Status

This document represents product requirements and planning decisions, not proof of implementation.

All proposed features require technical review, feasibility assessment, prioritization and approval before development.
