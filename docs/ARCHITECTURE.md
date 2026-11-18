# VISION AI — Application Architecture

## 1. Architectural Philosophy

VISION AI uses a **Feature-First Modular Clean Architecture** combined with **Riverpod** (`flutter_riverpod`) for reactive state management and dependency injection.

Key principles:
- **Feature Modularity**: Every product domain (`assistant`, `chat`, `settings`, `onboarding`) is self-contained under `lib/features/<feature>/`.
- **Clear Layer Separation**:
  - **Domain Layer (`domain/`)**: Pure Dart entities and repository interfaces (`AppSettings`, `AiProviderType`, `VoiceLanguage`, `AssistantReadiness`, `ChatMessage`). Independent of UI widgets and storage plugins.
  - **Data Layer (`data/`)**: Concrete repository implementations and local/secure data sources (`SettingsLocalDataSource`, `SettingsRepositoryImpl`, `AssistantSessionRepositoryImpl`, `ChatRepositoryImpl`).
  - **Presentation Layer (`presentation/`)**: Riverpod `Notifier` controllers (`SettingsController`, `AssistantController`), screens, and focused, reusable UI widgets.
- **Pragmatic Simplicity**: Phase 1 avoids unnecessary code generation (`build_runner`, `freezed`, `json_serializable`) while domain models remain concise and no remote REST schemas are active yet.

---

## 2. Directory Structure

```text
lib/
├── main.dart                                      # Application bootstrap, error boundary & ProviderScope
├── app/
│   ├── app.dart                                   # Root VisionApp widget (MaterialApp.router + ThemeMode)
│   ├── router/
│   │   ├── app_router.dart                        # GoRouter configuration & error route builder
│   │   └── app_routes.dart                        # Centralized route path and name constants
│   └── theme/
│       ├── app_colors.dart                        # Obsidian dark & clean light semantic color tokens
│       ├── app_theme.dart                         # Material 3 Dark and Light ThemeData definitions
│       └── app_typography.dart                    # High-contrast typography scale
├── core/
│   ├── constants/
│   │   ├── app_constants.dart                     # Application metadata, greetings, layout breakpoints
│   │   └── storage_keys.dart                      # SharedPreferences and SecureStorage key constants
│   ├── errors/
│   │   ├── app_exception.dart                     # Sealed AppException hierarchy
│   │   └── error_handler.dart                     # Global FlutterError & PlatformDispatcher hooks
│   ├── utils/
│   │   ├── app_logger.dart                        # Structured Logger wrapper & provider
│   │   ├── secure_storage_provider.dart           # Android Keystore credential store wrapper
│   │   └── shared_preferences_provider.dart       # Synchronous SharedPreferences provider
│   └── widgets/
│       ├── vision_app_bar.dart                    # Reusable top bar with title/subtitle support
│       ├── vision_card.dart                       # Reusable bordered surface container
│       ├── vision_scaffold.dart                   # Responsive scaffold with dark ambient radial glow
│       └── vision_status_badge.dart               # Pill badge for phase and readiness indicators
└── features/
    ├── assistant/
    │   ├── data/repositories/
    │   │   └── assistant_session_repository_impl.dart
    │   ├── domain/
    │   │   ├── entities/assistant_readiness.dart
    │   │   └── repositories/assistant_session_repository.dart
    │   └── presentation/
    │       ├── controllers/assistant_controller.dart
    │       ├── screens/assistant_home_screen.dart
    │       └── widgets/
    │           ├── assistant_greeting_header.dart
    │           ├── assistant_mic_button.dart
    │           ├── assistant_orb.dart
    │           └── assistant_status_panel.dart
    ├── chat/
    │   ├── data/repositories/
    │   │   └── chat_repository_impl.dart
    │   ├── domain/
    │   │   ├── entities/chat_message.dart
    │   │   └── repositories/chat_repository.dart
    │   └── presentation/screens/
    │       └── chat_placeholder_screen.dart
    ├── onboarding/
    │   └── presentation/screens/
    │       └── onboarding_screen.dart
    └── settings/
        ├── data/
        │   ├── datasources/settings_local_datasource.dart
        │   └── repositories/settings_repository_impl.dart
        ├── domain/
        │   ├── entities/
        │   │   ├── ai_provider_type.dart
        │   │   ├── app_settings.dart
        │   │   └── voice_language.dart
        │   └── repositories/settings_repository.dart
        └── presentation/
            ├── controllers/settings_controller.dart
            ├── screens/settings_screen.dart
            └── widgets/
                ├── settings_section_card.dart
                └── settings_tile.dart
```

---

## 3. Data & State Flow

```text
[ User Interaction (UI Widget) ]
              │
              ▼
[ Riverpod Notifier Controller ]  (e.g., SettingsController / AssistantController)
              │
              ▼
[ Domain Repository Interface ]   (e.g., SettingsRepository)
              │
              ▼
[ Data Source / Platform Plugin ] (e.g., SettingsLocalDataSource -> SharedPreferences)
```

1. **Initialization**: `main()` initializes `WidgetsFlutterBinding`, registers `AppErrorHandler`, resolves `SharedPreferences.getInstance()`, and injects overrides into the root `ProviderScope`.
2. **Reactive UI Updates**: Widgets watch narrow slices of state (for example, `VisionApp` uses `ref.watch(settingsControllerProvider.select((s) => s.themeMode))` to avoid unnecessary rebuilds).
3. **Error Handling**: Repository and data source failures throw typed `AppException` subclasses (`StorageException`, `ConfigurationException`, `NavigationException`), which controllers catch, roll back optimistic state if needed, and log via `AppLogger`.

---

## 4. Security & Privacy Architecture

- **Zero Hardcoded Secrets**: No API keys or tokens exist in source code or assets.
- **Hardware-Backed Keystore Foundation**: `SecureCredentialStore` (`lib/core/utils/secure_storage_provider.dart`) wraps `FlutterSecureStorage` so Phase 2 AI provider keys (Gemini, OpenAI, Claude) are stored encrypted in the Android Keystore.
- **Honest Capability Boundaries**: Phase 1 UI components (such as `AssistantMicButton` and `ChatPlaceholderScreen`) explicitly report Phase 1 standby status and never fabricate AI responses or simulate voice recording.
