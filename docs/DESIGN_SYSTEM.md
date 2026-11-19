# VISION AI — Design System

**Application:** VISION AI  
**Tagline:** *Your Intelligence. Your Assistant.*  
**Design Identity:** Midnight Violet (Dark) + Pearl Lavender (Light)  
**Foundation:** Flutter 3.50.0 Material 3 (`material_ui`) + `VisionThemeExtension`

---

## 1. Design Philosophy

VISION AI uses a calm, futuristic, high-contrast visual language centered around **Midnight Violet** in dark mode and **Pearl Lavender** in light mode. The old cyan/blue palette has been completely retired.

Core principles:
- **Clarity first:** Semantic surfaces (`background` → `secondaryBackground` → `surface` → `elevatedSurface`) establish clear hierarchy without relying on heavy blur or noisy borders.
- **Selective translucency:** Glass panels (`VisionGlassPanel`) are reserved for floating bars, overlays, and featured banners—standard cards use crisp solid surfaces with subtle borders.
- **Zero hardcoded feature colors:** Every screen consumes `Theme.of(context)` and `context.visionColors` (`VisionThemeExtension`).
- **Accessibility & reduced motion:** All interactive targets meet `44×44` minimum touch area, color pairs satisfy WCAG contrast targets, and every animation honors Android Reduce Motion (`VisionMotion.reduceMotion`).

---

## 2. Token Architecture (`lib/core/theme/`)

| File | Responsibility |
|---|---|
| `vision_colors.dart` | Exact Midnight Violet & Pearl Lavender hex palettes + `VisionColorTokens` |
| `vision_theme_extension.dart` | `ThemeExtension<VisionThemeExtension>` + `context.visionColors` helper |
| `vision_dark_theme.dart` | Material 3 Dark `ThemeData` (Midnight Violet) |
| `vision_light_theme.dart` | Material 3 Light `ThemeData` (Pearl Lavender) |
| `vision_theme.dart` | Unified `VisionTheme.darkTheme` & `VisionTheme.lightTheme` entry point |
| `vision_typography.dart` | Unified Material 3 `TextTheme` scale for headings, body, chat & labels |
| `vision_spacing.dart` | 4px-based layout rhythm (`xs`..`xxl`, `navBarClearance`) |
| `vision_radius.dart` | Corner radius tokens (`xs: 8`, `sm: 12`, `md: 16`, `lg: 20`, `xl: 28`, `pill: 999`) |
| `vision_elevation.dart` | Subtle dark/light elevation shadows and primary glow |
| `vision_motion.dart` | Motion durations (`micro`, `standard`, `screen`, `decorative`), curves & reduced-motion resolver |
