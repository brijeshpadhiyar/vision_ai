# VISION AI

**VISION** (`com.brijesh.vision`) is a personal Android AI assistant built with Flutter, Dart, and Kotlin, engineered with a modular feature-first architecture and calibrated for the **OPPO Reno 16**.

> **Current Milestone**: `Phase 4 • Android Device Automation`

---

## 1. Project Overview

VISION AI is designed as a multi-provider, multilingual personal assistant for Android:
- **Application Name**: VISION
- **Flutter Project**: `vision_ai`
- **Android Application ID**: `com.brijesh.vision`
- **Target Device Profile**: OPPO Reno 16
- **State Management**: Riverpod (`flutter_riverpod`)
- **Navigation**: Declarative routing via `go_router`
- **Planned AI Providers**: Google Gemini, OpenAI, Anthropic Claude
- **Planned Voice Languages**: English (`en-IN`), Hindi (`hi-IN`), Gujarati (`gu-IN`)

---

## 2. Requirements

- **Flutter SDK**: `3.50.0` (Channel `stable`) or compatible `>=3.47.0`
- **Dart SDK**: `^3.14.0`
- **Java / JDK**: JDK 17 or JDK 21 (configured for Gradle JVM target 17)
- **Android SDK**: Compile SDK 36/37, Build Tools 37.0.0, Minimum SDK 24
- **Kotlin**: `2.4.20`
- **Android Gradle Plugin**: `9.3.1`

---

## 3. Setup Instructions

1. **Verify Flutter & Android Toolchain**:
   ```bash
   flutter doctor -v
   ```
2. **Install Dependencies**:
   ```bash
   flutter pub get
   ```
3. **Run Static Analysis**:
   ```bash
   flutter analyze
   ```
4. **Run Automated Tests**:
   ```bash
   flutter test
   ```

---

## 4. Run & Build Instructions

### Run on a Connected Android Device or Emulator
```bash
flutter run
```

### Build Android APK (Automated Naming & Archiving)

Both direct `flutter build apk` commands (via [android/app/build.gradle.kts](android/app/build.gradle.kts)) and the automated build scripts automatically archive every APK with an **Asia/Kolkata (IST)** timestamp without overwriting prior builds:

**Direct Flutter CLI**:
```powershell
flutter build apk
flutter build apk --debug
flutter build apk --profile
flutter build apk --release
```

**Windows (PowerShell)**:
```powershell
.\scripts\build_apk.ps1
.\scripts\build_apk.ps1 -Mode debug
.\scripts\build_apk.ps1 -Mode profile
.\scripts\build_apk.ps1 -Mode release
```

**Linux / macOS (Bash)**:
```bash
./scripts/build_apk.sh
./scripts/build_apk.sh debug
./scripts/build_apk.sh profile
./scripts/build_apk.sh release
```

- **Naming Convention**: `vision-<mode>-YYYYMMDD-HHmmss.apk` (e.g., `vision-release-20261117-143025.apk`) plus companion JSON metadata (`vision-<mode>-YYYYMMDD-HHmmss.json`).
- **Archive Output Directory**: `dist/apk/debug/`, `dist/apk/profile/`, and `dist/apk/release/`.
- **Flutter Build Output Preserved**: `build/app/outputs/flutter-apk/app-<mode>.apk` remains intact.

See [docs/APK_BUILD_SYSTEM.md](docs/APK_BUILD_SYSTEM.md) for full details and metadata schema.

---

## 5. Branding, Launcher Icons & Splash Screen

- **Application Name**: `VISION` (`com.brijesh.vision`)
- **Tagline**: *"Your Intelligence. Your Assistant."*
- **Brand Palette**:
  - Primary Background: `#080D18`
  - Secondary Background: `#101A2B`
  - Primary Accent: `#00D4FF`
  - Secondary Accent: `#397BFF`
  - Primary Text: `#FFFFFF`
  - Secondary Text: `#AAB8CC`
- **Logo Assets (`assets/branding/`)**:
  - `vision_icon.svg` / `vision_icon.png` (standalone geometric V + AI iris symbol)
  - `vision_wordmark.svg` (geometric `VISION` wordmark)
  - `vision_logo.svg` / `vision_logo.png` (horizontal lockup)
  - `vision_logo_dark.png` & `vision_logo_light.png` (dark and light background lockups)
  - `vision_brand_guidelines.md` (clear space, proportions, and usage rules)
- **Launcher Icons (`flutter_launcher_icons`)**:
  ```powershell
  dart run flutter_launcher_icons
  ```
- **Native + Flutter Splash Screen (`flutter_native_splash`)**:
  - Native Android 12+ (`values-v31/styles.xml`) and legacy (`launch_background.xml`) splash screens share the `#080D18` obsidian canvas and hand off cleanly via `FlutterNativeSplash.preserve` / `FlutterNativeSplash.remove` to `VisionSplashScreen`.
  ```powershell
  dart run flutter_native_splash:create
  ```
- **Changing Brand Colors**: Update `AppColors.brand*` in `lib/app/theme/app_colors.dart`, update `flutter_launcher_icons` / `flutter_native_splash` hex values in `pubspec.yaml` and regenerate native resources, and update SVG color stops in `assets/branding/`. See [docs/BRANDING.md](docs/BRANDING.md) for the complete guide.

---

## 6. Architecture Overview

VISION AI follows a **Feature-First Modular Clean Architecture**:

```text
lib/
  main.dart                 # Bootstrap, global error boundary, ProviderScope
  app/
    app.dart                # Root MaterialApp.router & theme wiring
    router/                 # GoRouter paths and route builders
    theme/                  # Obsidian/Cyan dark theme, light theme, typography
  core/
    constants/              # AppConstants and StorageKeys
    errors/                 # Sealed AppException hierarchy & AppErrorHandler
    utils/                  # AppLogger, SharedPreferences & SecureStorage providers
    widgets/                # VisionScaffold, VisionAppBar, VisionCard, VisionStatusBadge
  features/
    assistant/              # Assistant Home UI, animated Orb, status panel, readiness state
    automation/             # Phase 4 Android device control, intent parser, telemetry & permissions
    chat/                   # Conversation domain models, multi-provider REST clients & ChatScreen
    settings/               # Persistent user settings (Theme, AI provider, Voice language, Automation, Haptics)
    voice/                  # Multilingual STT, TTS & "Hey VISION" wake-word orchestration
    onboarding/             # Interactive Architecture & Phase Roadmap overview
```

Detailed documentation is available in the `docs/` directory:
- [docs/BRANDING.md](docs/BRANDING.md) — Brand palette, logo asset inventory, launcher icons, and splash coordination.
- [docs/APK_BUILD_SYSTEM.md](docs/APK_BUILD_SYSTEM.md) — Automated APK build pipeline, naming convention, and metadata schema.
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — Layer responsibilities, state flow, and security boundaries.
- [docs/DEPENDENCIES.md](docs/DEPENDENCIES.md) — Installed packages, versions, and rationale.
- [docs/IMPLEMENTATION_PLAN.md](docs/IMPLEMENTATION_PLAN.md) — Phased delivery roadmap.

---

## 7. Current Implemented Features (Phases 1, 2, 3 & 4)

- **Application Entry Point & Error Boundary**: Global `FlutterError` and `PlatformDispatcher` handlers with structured logging via `AppLogger`.
- **Riverpod State Management**: Synchronous local preference hydration and reactive controllers (`SettingsController`, `ApiKeyStatusController`, `AssistantController`, `ChatController`, `VoiceController`, `AutomationController`).
- **Dual Theme System**: Signature obsidian & cyan **Dark Theme** (default) plus full **Light Theme** and **System** mode support.
- **Multi-Provider AI Orchestration (Phase 2)**:
  - Unified `AiProviderClient` interface with live REST adapters for **Google Gemini** (`gemini-2.5-flash`), **OpenAI** (`gpt-4o-mini`), and **Anthropic Claude** (`claude-3-5-haiku-latest`).
  - Full **VISION Chat Screen** (`ChatScreen`) with starter prompts, voice dictation, TTS reply playback, copy-to-clipboard, error banners, and local transcript persistence.
- **Encrypted API Key Management (Android Keystore)**:
  - Personal API keys for Gemini, OpenAI, and Claude are encrypted on-device via `FlutterSecureStorage` (`SecureCredentialStore`) and managed through `ApiKeyConfigDialog`.
- **Multilingual Voice & Wake-Word Engine (Phase 3)**:
  - Native Kotlin `VisionVoiceChannel` (`SpeechRecognizer` + `TextToSpeech` + runtime `RECORD_AUDIO` permission handling) supporting **English (`en-IN`)**, **Hindi (`hi-IN`)**, and **Gujarati (`gu-IN`)**.
  - Multilingual `WakeWordDetector` recognizing `"Hey VISION"` in English, Hindi (`हे विज़न`), and Gujarati (`હે વિઝન`) and automatically dispatching spoken commands to the active AI provider or device automation.
  - Real-time microphone RMS amplitude reactive animations on `AssistantOrb` and automatic TTS voice playback of assistant replies.
- **Android System Automation & Device Control (Phase 4)**:
  - Native Kotlin `VisionAutomationChannel` (`com.brijesh.vision/automation`) supporting permission-guarded phone calls (`ACTION_CALL` / `ACTION_DIAL`), `ContactsContract` lookup, `AlarmClock` alarms & timers, launcher app discovery & launching, system settings intents, SMS composition, URL launching, rear torch control, and live ColorOS / OPPO Reno 16 device telemetry.
  - `DeviceIntentParser` supporting instant local voice/text device commands plus `[[VISION_ACTION:...]]` tool directives from Gemini, OpenAI, and Claude across English, Hindi, and Gujarati.
  - Dedicated **Device Control Hub** (`AutomationScreen`) with runtime permission guards, contact disambiguation, call confirmation prompts, quick action chips, and recent execution logs.
