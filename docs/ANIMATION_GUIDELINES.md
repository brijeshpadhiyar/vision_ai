# VISION AI — Animation & Motion Guidelines

Centralized in `lib/core/theme/vision_motion.dart` and `lib/core/widgets/vision_orb.dart`.

## Duration Tokens

| Token | Duration | Usage |
|---|---|---|
| `VisionMotion.micro` | `150 ms` | Button feedback, chip toggles, icon switches |
| `VisionMotion.standard` | `240 ms` | Card state changes, theme transitions (`AnimatedTheme`), accordions |
| `VisionMotion.screen` | `300 ms` | Route transitions, modal sheets, dialogs |
| `VisionMotion.decorative` | `2200 ms` | Orb idle breathing, loading shimmer pulse |

## Curves
- `VisionMotion.standardCurve` (`Curves.easeOutCubic`) — default UI transitions.
- `VisionMotion.emphasizedCurve` (`Curves.easeInOutCubic`) — modals & layout shifts.
- `VisionMotion.springCurve` (`Curves.easeOutBack`) — subtle badge/orb emphasis.

## VisionOrb 6 Operational States
All orb states map to real application state (never simulated fake listening or processing):
1. **`idle`**: Gentle floating motion, subtle violet-rose glow, slow breathing.
2. **`listening`**: Reactive mint-violet pulse rings driven by real microphone amplitude.
3. **`thinking`**: Accelerated orbital rotation during active AI/tool inference.
4. **`speaking`**: Harmonic waveform ring synchronized with active TTS playback.
5. **`error`**: High-clarity rose/amber ring feedback.
6. **`offline`**: Calm muted neutral state when disconnected.

## Reduced Motion & Performance
- Every animated component checks `VisionMotion.reduceMotion(context)` (`MediaQuery.disableAnimations` / `accessibleNavigation`) and snaps cleanly without continuous loops when enabled.
- Custom painters (`VisionAiOrb`, `VisionScaffold` backdrop) are wrapped in `RepaintBoundary` and avoid GPU-heavy blur filters over large scrolling surfaces.
