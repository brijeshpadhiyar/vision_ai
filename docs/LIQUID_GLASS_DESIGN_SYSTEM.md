# VISION AI — Liquid Glass Design System

**File Root:** `lib/core/theme/` & `lib/core/widgets/glass/`

---

## 1. Color System (`vision_colors.dart`)

| Token | Hex / Value | Usage |
| :--- | :--- | :--- |
| `backgroundPrimary` | `#050812` | Primary dark atmospheric canvas |
| `backgroundSecondary` | `#0A1220` | Secondary dark surface & gradient mid-stop |
| `backgroundElevated` | `#0F192D` | Elevated dark surfaces & menus |
| `lightBackgroundPrimary` | `#F3F7FC` | Light theme atmospheric canvas |
| `lightBackgroundSecondary` | `#E6EEF9` | Light theme secondary surface |
| `accentPrimary` | `#00D4FF` | Primary electric cyan highlight & glow |
| `accentSecondary` | `#3985FF` | Secondary azure accent |
| `success` | `#12C991` | Listening state, connected providers, granted permissions |
| `warning` | `#FFB547` | Confirmations, fallback routing, missing/untested states |
| `error` | `#FF5A6A` | API errors, voice errors, destructive actions |
| `textPrimaryDark` | `#FFFFFF` | Primary text on dark glass |
| `textSecondaryDark` | `#A7B2C5` | Secondary metadata and body copy on dark glass |

Glass surfaces use white at `5%–12%` opacity in dark mode (`VisionColors.glassSurface`) and crisp frosted white (`55%–92%`) in light mode, paired with `12%–20%` translucent borders (`VisionColors.glassBorder`).

---

## 2. Design Token Files (`lib/core/theme/`)

- **`vision_colors.dart`** — Dark & light color palette, adaptive getters, and brand/backdrop gradients.
- **`vision_typography.dart`** — High-legibility `TextTheme` calibrated for translucent glass backgrounds.
- **`vision_spacing.dart`** — Layout gutters (`18px`), card padding (`16px`), bottom floating nav bar clearance (`104px`), and minimum `48px` touch targets.
- **`vision_radii.dart`** — Consistent corner radii (`8`, `12`, `16`, `22`, `28`, `999` pill).
- **`vision_shadows.dart`** — Soft elevation shadows and radial orb glows.
- **`vision_glass.dart`** — `VisionGlassVariant` (`subtle`, `standard`, `elevated`, `accent`) and `VisionGlass.decoration(...)`.
- **`vision_animations.dart`** — Standard durations (`120–160ms` micro, `220–280ms` standard, `400–460ms` large), curves, and `MediaQuery.maybeDisableAnimationsOf` reduced-motion helpers.
- **`vision_theme.dart`** — Material 3 `darkTheme` and `lightTheme` wired to `VisionApp`.

---

## 3. Reusable Glass Components (`lib/core/widgets/glass/`)

| Component | Purpose | Blur Strategy |
| :--- | :--- | :--- |
| `VisionGlassContainer` | Configurable glass surface (blur, opacity, border, gradient, glow) | Opt-in (`blurSigma = 0` default) |
| `VisionGlassCard` | Interactive card with `0.982` tactile press feedback | Opt-in (`blurSigma = 0` default) |
| `VisionGlassButton` | Primary gradient, tonal glass, subtle glass, & danger buttons | Gradient / border layers |
| `VisionGlassIconButton` | Circular/squircle accessible icon action with optional active glow | Border + glow |
| `VisionGlassNavigationBar` | Floating bottom bar with active pill glow & raised Assistant orb | Single `BackdropFilter` (`18σ`) |
| `VisionGlassAppBar` | Translucent top bar with optional subtitle & actions | Single `BackdropFilter` (`12σ`) |
| `VisionGlassBottomSheet` | Modal sheet frame with drag handle & `showVisionGlassBottomSheet` | Single `BackdropFilter` (`26σ`) |
| `VisionGlassDialog` | Frosted modal dialog with `showVisionGlassDialog` scale+fade transition | Single `BackdropFilter` (`26σ`) |
| `VisionGlassInput` | Translucent text input matching glass theme | Surface fill + focus border |
| `VisionGlassChip` | Selectable / actionable glass pill chip | Surface + glow when selected |
| `VisionGlassTabBar` | Segmented glass tab selector (e.g. Dark / Light / System) | Surface + active accent pill |
| `VisionGlassPopup` | Frosted `PopupMenuButton` wrapper for provider switching | Elevated tinted menu surface |
| `VisionShimmer` | Lightweight gradient shimmer for AI thinking & loading skeletons | `RepaintBoundary` |
| `VisionStaggeredReveal` | Smooth fade + slide entrance respecting reduced motion | `FadeTransition` + `SlideTransition` |

---

## 4. Performance Rules

1. **Selective `BackdropFilter`:** Only chrome (`VisionGlassAppBar`, `VisionGlassNavigationBar`), modals (`VisionGlassDialog`, `VisionGlassBottomSheet`), and `ChatInputBar` invoke `ImageFilter.blur`.
2. **Zero Blur Inside Scrolling Lists:** `ChatMessageBubble`, `SettingsScreen` cards, `AutomationScreen` chips, and `OnboardingScreen` timeline cards use lightweight gradient + translucent border layers (`blurSigma: 0`) so scrolling remains smooth at 60 FPS on OPPO Reno 16.
3. **Repaint Isolation:** Ambient scaffold gradients, the floating nav bar, `VisionShimmer`, and `VisionAiOrb` are wrapped in `RepaintBoundary`.
