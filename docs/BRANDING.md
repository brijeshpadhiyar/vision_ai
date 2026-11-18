# VISION AI — Brand Identity, Icons & Splash Architecture

This document describes the visual branding system, generated logo assets, Android launcher icon configuration, and coordinated splash screen implementation for **VISION** (`com.brijesh.vision`).

---

## 1. Brand Identity & Color System

- **Application Display Name**: `VISION`
- **Package ID**: `com.brijesh.vision`
- **Tagline**: `Your Intelligence. Your Assistant.`

| Token | Hex | Flutter Constant (`AppColors`) | Usage |
| :--- | :--- | :--- | :--- |
| Primary Background | `#080D18` | `AppColors.brandBackgroundPrimary` | Obsidian canvas, splash background, adaptive icon background |
| Secondary Background | `#101A2B` | `AppColors.brandBackgroundSecondary` | Elevated surfaces, optical aperture fill, loader track |
| Primary Accent | `#00D4FF` | `AppColors.brandAccentPrimary` | Cyan highlights, iris ring, loader gradient start |
| Secondary Accent | `#397BFF` | `AppColors.brandAccentSecondary` | Electric blue depth gradient, loader gradient end |
| Primary Text | `#FFFFFF` | `AppColors.brandTextPrimary` | Primary display wordmark and dark-theme headings |
| Secondary Text | `#AAB8CC` | `AppColors.brandTextSecondary` | Brand tagline and supporting text |

### How to Change Brand Colors

1. **Flutter UI & Splash Screen**: Update the `brand*` constants in `lib/app/theme/app_colors.dart`.
2. **Android Launcher & Native Splash**: Update `flutter_launcher_icons.adaptive_icon_background` and `flutter_native_splash` (`color` / `android_12.color` / `android_12.icon_background_color`) in `pubspec.yaml`, then regenerate native Android resources:
   ```powershell
   flutter pub get
   dart run flutter_launcher_icons
   dart run flutter_native_splash:create
   ```
3. **Vector & Raster Brand Assets**: Update the SVG color stops in `assets/branding/vision_icon.svg`, `assets/branding/vision_wordmark.svg`, and `assets/branding/vision_logo.svg`, and re-export the PNG derivatives (`vision_logo.png`, `vision_logo_dark.png`, `vision_logo_light.png`, `vision_icon.png`, `vision_icon_foreground.png`, `vision_splash_icon.png`, `vision_launcher_legacy.png`).

---

## 2. Logo Assets (`assets/branding/`)

| File | Description |
| :--- | :--- |
| `assets/branding/vision_icon.svg` | Master vector symbol (geometric **V** + integrated AI iris), `512 × 512`, transparent |
| `assets/branding/vision_wordmark.svg` | Custom geometric vector **VISION** wordmark, `640 × 160`, transparent |
| `assets/branding/vision_logo.svg` | Primary horizontal lockup (symbol + divider + wordmark), `1280 × 360`, transparent |
| `assets/branding/vision_logo.png` | Transparent high-res horizontal logo (`1920 × 540`) |
| `assets/branding/vision_logo_dark.png` | Dark-background horizontal logo (`1920 × 540`, `#080D18` / `#101A2B` backdrop) |
| `assets/branding/vision_logo_light.png` | Light-background transparent horizontal logo (`1920 × 540`, `#080D18` wordmark) |
| `assets/branding/vision_icon.png` | Standalone high-res symbol (`1024 × 1024`, transparent) |
| `assets/branding/vision_icon_foreground.png` | Adaptive launcher foreground artwork (`1024 × 1024`, transparent, safe-area scaled) |
| `assets/branding/vision_splash_icon.png` | Android 12+ SplashScreen centered icon (`1024 × 1024`, circular safe-zone scaled) |
| `assets/branding/vision_launcher_legacy.png` | Legacy Android launcher icon (`1024 × 1024`, `#080D18` obsidian backdrop) |
| `assets/branding/vision_brand_guidelines.md` | Full brand guidelines, clear space rules, and misuse checklist |

---

## 3. Android Launcher Icon Configuration

Configured in `pubspec.yaml` via `flutter_launcher_icons`:

- **Adaptive Icon**:
  - Background: `@color/ic_launcher_background` (`#080D18` in `android/app/src/main/res/values/colors.xml`)
  - Foreground: `@drawable/ic_launcher_foreground` (`vision_icon_foreground.png` with 16% XML inset inside `mipmap-anydpi-v26/ic_launcher.xml`)
- **Legacy Icons**: Generated across `mipmap-mdpi`, `mipmap-hdpi`, `mipmap-xhdpi`, `mipmap-xxhdpi`, and `mipmap-xxxhdpi` as `ic_launcher.png`.
- **Manifest Verification**: `android/app/src/main/AndroidManifest.xml` uses `android:label="VISION"` and `android:icon="@mipmap/ic_launcher"`.

To regenerate launcher icons after updating icon artwork:

```powershell
dart run flutter_launcher_icons
```

---

## 4. Coordinated Native & Flutter Splash Screen

VISION coordinates Android's native splash screen with Flutter's branded startup screen to prevent blank flashes or duplicate splash screens:

1. **Native Android Splash (`flutter_native_splash`)**:
   - Configured in `pubspec.yaml` with `#080D18` background and `vision_splash_icon.png`.
   - Generates `values-v31/styles.xml` and `values-night-v31/styles.xml` for Android 12+ `SplashScreen` API (`windowSplashScreenBackground`, `windowSplashScreenAnimatedIcon`, `windowSplashScreenIconBackgroundColor`) alongside `launch_background.xml` for Android 7–11.
2. **Startup Hold & Seamless Handoff**:
   - `lib/main.dart` calls `FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding)` while initializing logging, edge-to-edge UI, and `SharedPreferences`.
   - `VisionSplashScreen` (`lib/features/splash/presentation/screens/splash_screen.dart`) calls `FlutterNativeSplash.remove()` in `initState()` so the first Flutter frame (`#080D18` + `VisionBrandLogo`) replaces the native splash cleanly with no duplicate jump.
   - Displays `VisionBrandLogo`, `VISION`, `"Your Intelligence. Your Assistant."`, and a minimal `#00D4FF → #397BFF` progress indicator, then fades (`350ms`) into `AssistantHomeScreen` after `AppConstants.splashMinimumDuration` (`700ms`).

To regenerate native splash resources after config changes:

```powershell
dart run flutter_native_splash:create
```
