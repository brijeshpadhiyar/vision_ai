# VISION AI — Animation & Motion System

**Core Tokens:** `lib/core/theme/vision_animations.dart`  
**Orb Engine:** `lib/features/assistant/presentation/widgets/vision_ai_orb.dart`

---

## 1. Motion Scale & Timing Guidelines

| Tier | Duration | Curve | Usage |
| :--- | :--- | :--- | :--- |
| **Micro** | `120–160 ms` | `Curves.easeOutCubic` | Card press scale (`0.982`), button press (`0.97` / `0.92`), chip & tab selection, Send/Stop morph |
| **Standard** | `220–280 ms` | `Curves.easeOutCubic` | Tab transitions, message bubble entrance, dialog scale/fade, `AnimatedSwitcher` status updates |
| **Large** | `350–460 ms` | `Curves.easeOutQuart` | Assistant modal launch, splash reveal, greeting entrance |
| **Ambient** | `1300–5400 ms` | `Curves.easeInOutSine` | `VisionAiOrb` breathing, orbital rotation, waveform rings, `VisionShimmer` |

---

## 2. `VisionAiOrb` 5-State Architecture

`VisionAiOrb` is rendered via a single `CustomPaint` (`_VisionOrbPainter`) driven by three coordinated `AnimationController`s (`_breathController`, `_orbitController`, `_waveController`) inside a `RepaintBoundary` so frame ticks never rebuild parent layouts.

1. **Idle (`VisionOrbState.idle`):** Slow sinusoidal breathing (`3400ms`), gentle vertical float, rotating inner specular gradient, and subtle cyan/azure aura.
2. **Listening (`VisionOrbState.listening`):** Emerald-cyan palette, two expanding ripple rings, 36-bar harmonic radial waveform modulated by live `VoiceSessionState.normalizedAmplitude`, and faster orbital rotation (`2800ms`).
3. **Thinking (`VisionOrbState.thinking`):** Deep indigo/azure sweep arc and 6 lightweight orbiting light particles (`1900ms` cycle) with zero `MaskFilter.blur` overhead.
4. **Speaking (`VisionOrbState.speaking`):** Luminous cyan-ice palette with rhythmic waveform bars and synchronized pulse intensity.
5. **Error (`VisionOrbState.error`):** Coral/amber warning rim pulse for clear non-intrusive feedback before returning to idle.

---

## 3. Navigation & Reduced-Motion Support

- **Route Transitions (`app_router.dart`):**
  - Shell routes (`Home`, `Chat`, `Automation`, `Settings`) use `_fadeSlidePage` (`280ms` fade + subtle `2.5%` vertical slide).
  - Dedicated Assistant routes (`/assistant`, `/assistant-overlay`) use `_assistantModalPage` (`400ms` fade + `0.94 -> 1.0` scale).
- **Accessibility (`VisionAnimations.isReducedMotion`):**
  - Checks `MediaQuery.maybeDisableAnimationsOf(context)` across `VisionAiOrb`, `VisionSplashScreen`, `AssistantGreetingHeader`, `ChatMessageBubble`, `VisionShimmer`, `VisionGlassCard`, `VisionGlassButton`, and `GoRouter` page transitions.
  - When reduced motion is enabled, continuous animations stop cleanly at balanced static frames and transitions resolve instantaneously (`Duration.zero`).
