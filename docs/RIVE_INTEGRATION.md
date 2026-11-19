# VISION AI — Rive Integration (`VisionOrb`)

## Overview

VISION AI integrates the official Rive Flutter runtime (`rive: ^0.14.11` / `rive_native: 0.1.11`) in `lib/features/assistant/presentation/widgets/vision_orb.dart`, with backward-compatible delegation from `lib/core/widgets/vision_orb.dart` and `lib/features/assistant/presentation/widgets/assistant_orb.dart`.

## Startup Initialization

In `lib/main.dart`, `RiveNative.init()` is invoked inside a guarded `try/catch` block so production Android devices initialize the hardware-accelerated C++ runtime while unit/widget tests without native `.so` binaries gracefully fall back to the Flutter-native orb.

## Six Operational States

`VisionOrbState` (and `VisionOrbStateResolver.resolve(...)`) maps strictly to real assistant/voice/chat/connectivity state:

| Index | State | Trigger Condition |
| :---: | :--- | :--- |
| `0` | `idle` | Default standby when no audio, AI request, error, or offline condition is active |
| `1` | `listening` | Microphone is genuinely active (`voice.isMicActuallyActive == true`) |
| `2` | `thinking` | AI request/processing is genuinely in flight (`chat.isLoading == true`) |
| `3` | `speaking` | TTS playback is genuinely active (`voice.isSpeaking == true`) |
| `4` | `error` | Active voice/assistant error present |
| `5` | `offline` | Device or AI provider offline; pauses continuous animation loops to save battery |

> **Strict rule**: `VisionOrb` never simulates a fake `speaking` animation while idle and never displays `listening` unless the microphone is actually active.

## Current Fallback Architecture

No `.riv` asset is currently bundled in the repository (no placeholder/fake `.riv` file was invented). When `riveConfig` is `null` (default) or if loading a `.riv` file fails, `VisionOrb` renders the theme-aware, `RepaintBoundary`-isolated Flutter-native `VisionAiOrb` with full Midnight Violet / Pearl Lavender support, `WidgetsBindingObserver` pause-on-background, `TickerMode` pause-on-hidden-route, and reduced-motion support.

## How to Drop In a Real `.riv` Asset

1. Export a Rive file (e.g., `assets/animations/vision_orb.riv`) with:
   - State machine named `VisionOrbStateMachine` (or your custom name).
   - Number input `orbState` (`0`..`5` matching `VisionOrbState.index`).
   - Number input `audioLevel` (`0.0`..`1.0`).
2. Add `assets/animations/` to `flutter.assets` in `pubspec.yaml`.
3. Pass `VisionOrbRiveConfig` to `VisionOrb` or `ConnectedVisionOrb`:

```dart
const orbConfig = VisionOrbRiveConfig(
  assetPath: 'assets/animations/vision_orb.riv',
  stateMachineName: 'VisionOrbStateMachine',
  stateNumberInputName: 'orbState',
  audioLevelInputName: 'audioLevel',
);

VisionOrb(
  size: 176,
  state: currentState,
  audioLevel: normalizedLevel,
  riveConfig: orbConfig,
);
```
