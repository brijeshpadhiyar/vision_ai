# VISION AI — Theme Architecture

## Flutter SDK & Package Assessment
- **SDK:** Flutter `3.50.0` / Dart `3.14.0` using standalone `material_ui: ^1.1.0` (`package:flutter/material.dart` is deprecated in Flutter 3.47+).
- **Why `ThemeData` + `ThemeExtension` (and NOT `flex_color_scheme`, `rive`, or `lottie`):**
  - `flex_color_scheme` conflicts with standalone `material_ui` migration and is unnecessary when Material 3 `ColorScheme` + `VisionThemeExtension` directly model every semantic token.
  - `VisionOrb` (`CustomPainter` + `RepaintBoundary`) delivers 60/120Hz multi-state animations with zero external `.riv`/`.json` asset failure risk and minimal APK footprint.

## Runtime Theme Switching & Persistence
1. **Persistence:** `SettingsController` persists `ThemeMode` (`system`, `light`, `dark`) via `SharedPreferences` (`StorageKeys.themeMode`).
2. **Immediate Application:** `VisionApp` (`lib/app/app.dart`) watches `settingsControllerProvider.select((s) => s.themeMode)` and passes:
   - `theme: AppTheme.lightTheme` (`VisionLightTheme.build()`)
   - `darkTheme: AppTheme.darkTheme` (`VisionDarkTheme.build()`)
   - `themeMode: themeMode`
   - `themeAnimationDuration: VisionMotion.standard` (`240 ms`)
   - `themeAnimationCurve: VisionMotion.standardCurve`
3. **Visual Theme Selector:** Settings → Appearance displays live color-swatch preview cards for **Dark (Midnight Violet)**, **Light (Pearl Lavender)**, and **System (Auto Android)** with instant animated transitions and zero app restart.
