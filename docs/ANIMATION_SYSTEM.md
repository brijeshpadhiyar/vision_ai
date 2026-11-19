# VISION AI — Animation System (`flutter_animate`)

## Overview

VISION AI centralizes motion durations, curves, reduced-motion accessibility checks, off-screen ticker guards, and `flutter_animate` presets inside `lib/core/theme/vision_animations.dart` (preserving `lib/core/theme/vision_motion.dart` for backward compatibility).

## Package & Version

- **Package**: `flutter_animate: ^4.5.2` (resolved `4.5.2`)
- **Transitive**: `flutter_shaders 0.1.5`

## Standard Timings & Curves

| Token | Duration / Curve | Usage |
| :--- | :--- | :--- |
| `microFast` / `micro` | `120 ms` / `160 ms` | Button press scale, icon switches |
| `standardFast` / `standard` | `220 ms` / `280 ms` | Card entrances, chat bubbles, sheets |
| `large` / `entrance` | `400 ms` / `460 ms` | Structural screen/modal entrances |
| `shimmerCycle` | `1400 ms` | Skeleton & subtle shimmer |
| `orbBreath` | `3400 ms` | Ambient orb breathing |
| `standardCurve` | `Curves.easeOutCubic` | Default UI motion |
| `emphasizedCurve` | `Curves.easeOutQuart` | Dialog scale-in & emphasis |
| `breathCurve` | `Curves.easeInOutSine` | Ambient breathing |

## Centralized Presets (`VisionAnimatePresets` & `VisionWidgetAnimations`)

1. `fadeIn` — Clean opacity entrance.
2. `slideUp` — Vertical rise (`beginY: 0.06` → `0`).
3. `scaleIn` — Dialog/modal scale (`0.96` → `1.0`) + fade.
4. `fadeAndSlide` — Combined fade + subtle upward slide (chat bubbles, empty/error views).
5. `cardEntrance(index: ...)` — Staggered card entrance (capped at index `5` so long lists never feel sluggish).
6. `buttonPress(isPressed: ...)` / `VisionPressable` — Lightweight `AnimatedScale` micro-feedback (`0.97` scale on press).
7. `iconTransition` — `AnimatedSwitcher` fade + scale for icon/selection state changes.
8. `shimmer` — Theme-tinted repeating shimmer (auto-disabled under reduced motion or hidden tickers).
9. `subtleBreathing` — Gentle ambient scale pulse (auto-disabled under reduced motion or hidden tickers).

## Reduced Motion & Hidden-Screen Lifecycle

Every preset checks `VisionAnimations.shouldAnimate(context)`:

```dart
static bool shouldAnimate(BuildContext context) {
  return !isReducedMotion(context) && TickerMode.valuesOf(context).enabled;
}
```

- When Android **Remove animations** / **Reduce motion** is enabled, presets return the raw child immediately (zero animation overhead).
- When a route or shell tab is hidden (`TickerMode` disabled), continuous animations (`shimmer`, `subtleBreathing`) do not run.
