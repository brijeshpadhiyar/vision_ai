# VISION AI — Brand Guidelines

**Application Name**: VISION  
**Package ID**: `com.brijesh.vision`  
**Tagline**: *"Your Intelligence. Your Assistant."*

---

## 1. Brand Personality

VISION is engineered to feel:
- **Intelligent** — sharp optical geometry, focused awareness, zero visual clutter.
- **Futuristic** — luminous cyan-to-electric-blue gradients over deep obsidian surfaces.
- **Premium** — precision proportions, generous negative space, crisp typographic hierarchy.
- **Minimal** — bold vector forms that remain instantly recognizable at `24dp` and `1024px`.
- **Trustworthy** — calm, high-contrast dark and light variants with balanced symmetry.
- **Friendly** — subtle specular iris highlight bringing warmth and life to the geometric core.

---

## 2. Brand Color Palette

| Token | Hex | Usage |
| :--- | :--- | :--- |
| **Primary Background** | `#080D18` | Obsidian canvas, splash backdrop, Android adaptive icon background |
| **Secondary Background** | `#101A2B` | Elevated surfaces, optical aperture backing, dark cards |
| **Primary Accent** | `#00D4FF` | Luminous cyan highlights, active iris ring, primary glow |
| **Secondary Accent** | `#397BFF` | Electric blue depth gradient, secondary focal accents |
| **Primary Text** | `#FFFFFF` | Dark-theme headings, wordmark, primary labels |
| **Secondary Text** | `#AAB8CC` | Subtitles, tagline, metadata, supporting copy |

### Light-Background Adaptation
For high-contrast rendering on white (`#FFFFFF`) or slate (`#F8FAFC`) surfaces:
- Wordmark shifts from `#FFFFFF` to `#080D18`.
- Symbol gradient shifts to `#0095D9` → `#2958E8` while retaining the `#080D18` optical cradle so the iris remains crisp without washing out.

---

## 3. Logo System & Asset Inventory

| Asset | Format | Dimensions | Background | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| `assets/branding/vision_icon.svg` | SVG | `512 × 512` | Transparent | Master vector symbol (stylized geometric **V** + integrated AI iris) without text |
| `assets/branding/vision_wordmark.svg` | SVG | `640 × 160` | Transparent | Pure geometric vector **VISION** wordmark |
| `assets/branding/vision_logo.svg` | SVG | `1280 × 360` | Transparent | Primary horizontal logo lockup (symbol + divider + wordmark) |
| `assets/branding/vision_logo.png` | PNG | `1920 × 540` | Transparent | High-resolution transparent horizontal logo (dark UI / general overlay) |
| `assets/branding/vision_logo_dark.png` | PNG | `1920 × 540` | `#080D18` / `#101A2B` | Dark-background horizontal brand lockup |
| `assets/branding/vision_logo_light.png` | PNG | `1920 × 540` | Transparent | Light-background horizontal lockup (`#080D18` wordmark) |
| `assets/branding/vision_icon.png` | PNG | `1024 × 1024` | Transparent | High-res standalone symbol for legacy launcher icons & UI |
| `assets/branding/vision_icon_foreground.png` | PNG | `1024 × 1024` | Transparent | Android Adaptive Icon foreground (62% safe-zone centered) |
| `assets/branding/vision_splash_icon.png` | PNG | `1024 × 1024` | Transparent | Android 12+ SplashScreen icon (56% circular safe-zone centered) |

---

## 4. Logo Construction & Clear Space

1. **Geometric V-Iris Symbol**:
   - Constructed on a `512 × 512` square grid.
   - Two symmetrical crystalline wings converge to a rounded precision apex, cradling an almond-shaped optical aperture (`#080D18` / `#101A2B`) with a concentric cyan telemetry ring, radial iris, obsidian pupil, and white specular highlight.
2. **Minimum Clear Space**:
   - Maintain clear space around the symbol equal to at least **20%** of the symbol width (`~100px` on a `512px` grid).
   - For Android Adaptive Icons, keep all critical geometry inside the center **66%** safe circle (`72dp` of `108dp`).
3. **Minimum Sizes**:
   - Standalone symbol: minimum `24dp` (in-app) / `48px` (`mdpi` launcher).
   - Horizontal lockup: minimum `140dp` width so the `VISION` wordmark remains crisp.

---

## 5. Misuse Guidelines

- Do **not** stretch, skew, or rotate the V-iris symbol or wordmark independently.
- Do **not** place the white-wordmark horizontal logo (`vision_logo.png`) on light backgrounds; use `vision_logo_light.png`.
- Do **not** add drop shadows, unapproved neon outlines, or third-party badges inside the clear space.
- Do **not** embed small text inside the Android launcher icon.
