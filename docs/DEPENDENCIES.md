# VISION AI — Dependencies & Rationale

## Environment Compatibility
- **Flutter SDK**: `3.50.0` (Channel `stable`)
- **Dart SDK**: `3.14.0` (`^3.14.0`)
- **Android Gradle Plugin (AGP)**: `9.3.1`
- **Kotlin Version**: `2.4.20` (JVM target `17`)

---

## Installed Runtime Dependencies

| Package | Version Constraint | Resolved Version | Purpose in VISION AI |
| :--- | :--- | :--- | :--- |
| `flutter` | `sdk: flutter` | SDK (`3.50.0`) | Core Flutter framework runtime. |
| `material_ui` | `^1.1.0` | `1.11.1` | Official Material Design widget library in Flutter 3.47+ / 3.50 (`package:material_ui/material_ui.dart`). |
| `cupertino_icons` | `^1.0.8` | `1.0.9` | iOS/adaptive iconography support where needed. |
| `flutter_riverpod` | `^3.5.0` | `3.5.0` | Reactive state management and dependency injection (`ProviderScope`, `Notifier`, `NotifierProvider`, `Provider`). |
| `go_router` | `^18.1.4` | `18.1.4` | Declarative navigation and deep-link-ready routing across Home, Settings, Chat, and Onboarding screens. |
| `shared_preferences` | `^2.5.6` | `2.5.6` | Local persistence for non-sensitive user preferences (theme mode, selected AI provider, preferred voice language, haptics, onboarding flag). |
| `flutter_secure_storage` | `^11.2.0` | `11.2.0` | Hardware-backed encrypted key-value storage (Android Keystore) for AI provider API keys. |
| `http` | `^1.6.0` | `1.6.0` | Composable, Future-based HTTP client for executing live REST requests to Google Gemini, OpenAI, and Anthropic Claude. |
| `logger` | `^2.8.0` | `2.8.0` | Structured, leveled console logging wrapped by `AppLogger`. |

---

## Installed Development Dependencies

| Package | Version Constraint | Resolved Version | Purpose in VISION AI |
| :--- | :--- | :--- | :--- |
| `flutter_test` | `sdk: flutter` | SDK | Widget and unit testing framework. |
| `flutter_lints` | `^6.0.0` | `6.0.0` | Strict static analysis rules enforced via `analysis_options.yaml`. |

---

## Evaluated Candidates Intentionally Deferred in Phase 1

| Candidate Package | Decision | Architectural Justification |
| :--- | :--- | :--- |
| `riverpod_annotation` & `riverpod_generator` | **Deferred** | `flutter_riverpod: ^3.5.0` provides clean, strongly-typed `Notifier` and `NotifierProvider` classes natively without requiring `build_runner` code generation overhead in Phase 1. |
| `freezed` & `freezed_annotation` | **Deferred** | Phase 1 domain entities (`AppSettings`, `AssistantReadiness`, `ChatMessage`) are small, immutable Dart 3 value classes with explicit `copyWith` and value equality. Avoiding `freezed` in Phase 1 prevents unnecessary codegen complexity. |
| `json_serializable` | **Deferred** | Phase 1 does not parse complex external REST API payloads. Can be introduced in Phase 2 when OpenAI, Gemini, and Claude JSON schemas are implemented. |
| `build_runner` | **Deferred** | Not required while zero code-generation annotations are used, keeping builds and CI checks fast. |
