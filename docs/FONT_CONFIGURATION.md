# VISION AI — Font Configuration (`google_fonts` + Offline Manrope)

## Overview

VISION AI uses **Manrope** as its primary global typeface across both **Midnight Violet (Dark)** and **Pearl Lavender (Light)** themes. Because VISION AI is an offline-capable Android assistant, all required font weights are bundled locally inside `assets/fonts/` and runtime network font fetching is explicitly disabled.

## Package & Compatibility

| Property | Value |
| :--- | :--- |
| Package | `google_fonts` |
| Constraint / Resolved | `^8.2.1` → `8.2.1` |
| Compatibility Note | `google_fonts 9.0.0` is available on pub.dev, but `flutter_ai_toolkit 1.1.0` constrains `google_fonts ^8.1.0`. Using `^8.2.1` keeps all AI packages intact. Because `google_fonts 8.2.1`'s `TextTheme` helper returns `flutter/material.dart`'s `TextTheme` while VISION uses `material_ui`, `VisionTypography` applies `GoogleFonts.manrope(...)` per `TextStyle` inside `material_ui`'s `TextTheme`. |

## Bundled Font Assets

Only the four weights required by the typography scale are bundled to minimize APK size:

- `assets/fonts/Manrope-Regular.ttf` (weight `400`, ~96 KB)
- `assets/fonts/Manrope-Medium.ttf` (weight `500`, ~96 KB)
- `assets/fonts/Manrope-SemiBold.ttf` (weight `600`, ~96 KB)
- `assets/fonts/Manrope-Bold.ttf` (weight `700`, ~96 KB)

Registered in `pubspec.yaml` under both `flutter.assets` (`assets/fonts/`) and `flutter.fonts` (`family: Manrope`).

## Offline Enforcement

In `lib/main.dart`, immediately after `WidgetsFlutterBinding.ensureInitialized()`:

```dart
GoogleFonts.config.allowRuntimeFetching = false;
```

This guarantees zero HTTP requests to `fonts.gstatic.com` at runtime and deterministic offline rendering on Android devices.

## Material 3 `TextTheme` Scale

Configured centrally in `lib/core/theme/vision_typography.dart` (`VisionTypography.buildTextTheme(Brightness)`):

- **Display**: `displayLarge` (44/w700), `displayMedium` (38/w700), `displaySmall` (32/w700)
- **Headlines**: `headlineLarge` (28/w700), `headlineMedium` (25/w700), `headlineSmall` (20/w600)
- **Titles**: `titleLarge` (18/w600), `titleMedium` (16/w600), `titleSmall` (14/w600)
- **Body**: `bodyLarge` (16/w400), `bodyMedium` (14/w400), `bodySmall` (12/w400)
- **Labels / Buttons / Captions**: `labelLarge` (14/w600), `labelMedium` (12/w600), `labelSmall` (11/w500)

Widgets should always read `Theme.of(context).textTheme.*` rather than hardcoding font families or custom styles.
