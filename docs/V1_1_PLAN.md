# VISION AI — v1.1 Implementation Plan

**Plan date:** 19 November 2026  
**Target release:** VISION AI v1.1 (`com.brijesh.vision`)  
**Prerequisite:** VISION AI v1.0 (Modules 01–18 — Completed & Verified)

---

## 1. Approved v1.1 Scope

1. **Wave 1 — Dynamic Device & OEM Auto-Detection (Universal Android Support)**
   - Eliminate all hardcoded `"OPPO Reno 16"` and `"OPPO ColorOS"` UI labels and setup instructions.
   - Dynamically identify the installed Android device's `manufacturer`, `brand`, `model`, `androidVersion`, and OEM skin (`ColorOS`, `OxygenOS`, `One UI`, `HyperOS / MIUI`, `Funtouch OS`, `Nothing OS`, or `Stock Android`) at runtime.
2. **Wave 2 — Module 25: Privacy & Security Dashboard**
   - Provide a unified Privacy & Security control center covering permissions, trusted commands, microphone/notification privacy, encrypted API keys, and local data footprint controls.

---

## 2. Wave 1 — Dynamic Device & OEM Auto-Detection

### Audited Hardcoded Files to Refactor
- `android/app/src/main/kotlin/com/brijesh/vision/VisionAutomationChannel.kt`
- `lib/features/automation/domain/entities/device_action.dart`
- `lib/core/constants/app_constants.dart`
- `lib/features/onboarding/presentation/screens/onboarding_screen.dart`
- `lib/features/automation/presentation/screens/automation_screen.dart`
- `lib/features/settings/presentation/screens/settings_screen.dart`
- `lib/features/settings/presentation/widgets/coloros_setup_guide_sheet.dart` → generalized `device_setup_guide_sheet.dart`

### Technical Design
1. **Native OEM & Device Detection (`VisionAutomationChannel.kt`):**
   - Inspect `Build.MANUFACTURER`, `Build.BRAND`, `Build.MODEL`, and `Build.DISPLAY` (plus system properties/brand cues) to classify `oemSkin`:
     - `OPPO` / `Realme` → `ColorOS` / `Realme UI`
     - `OnePlus` → `OxygenOS`
     - `Samsung` → `One UI`
     - `Xiaomi` / `Redmi` / `POCO` → `HyperOS / MIUI`
     - `Vivo` / `iQOO` → `Funtouch OS`
     - `Nothing` → `Nothing OS`
     - `Google` → `Pixel Android`
     - Fallback → `Android`
   - Return `deviceDisplayName` (cleanly formatted `Manufacturer Model` without duplicate manufacturer prefix, e.g., `"OPPO Reno 16"`, `"Samsung SM-S938B"`, `"Google Pixel 9"`) and `oemSkin` alongside `isColorOs` (preserved for backward compatibility).
2. **Domain Model (`DeviceStatusSnapshot`):**
   - Add `oemSkin` and `deviceDisplayName` getters/fields.
   - Update `osTag` to format `'$oemSkin / Android $androidVersion'` when an OEM skin is detected, or `'Android $androidVersion'` on stock Android.
3. **Adaptive UI & Setup Guide (`DeviceSetupGuideSheet`):**
   - Replace `ColorOsSetupGuideSheet` with `DeviceSetupGuideSheet` that reads the live `DeviceStatusSnapshot` and renders:
     - Installed device title: `"<Device Name> • <OEM Skin> Setup Guide"`
     - Tailored background-activity & auto-launch instructions per detected OEM skin (`ColorOS/Realme UI`, `One UI`, `HyperOS/MIUI`, `OxygenOS`, `Funtouch OS`, or generic `Android`).
   - Replace hardcoded `"OPPO Reno 16"` strings in `settings_screen.dart`, `automation_screen.dart`, `onboarding_screen.dart`, and `app_constants.dart` with dynamic device name or generic Android copy.
4. **Tests:** Unit tests verifying `DeviceStatusSnapshot` OEM classification & `deviceDisplayName` deduplication across OPPO, Samsung, Xiaomi, OnePlus, Vivo, Pixel, and generic Android devices.

---

## 3. Wave 2 — Module 25: Privacy & Security Dashboard

### Capabilities & Route
- New route: `/privacy-dashboard` (`AppRoutes.privacyDashboardPath`) reachable from `SettingsScreen` (Privacy section) and `DiagnosticsScreen`.
- New screen: `lib/features/privacy/presentation/screens/privacy_dashboard_screen.dart`

### Dashboard Sections
1. **Security Posture Overview:**
   - Live status badges for:
     - **Android Keystore AES-GCM** (`X / 3` provider API keys encrypted; `allowBackup=false`)
     - **Secret Redaction** (Active across logs & diagnostics)
     - **Session-Only Memory Default** (Shows whether Chat History & Personal Memory are OFF or opted-in)
     - **Manual Provider Control** (Shows active provider + whether opt-in Fallback is OFF/ON)
2. **Runtime & Special Permissions Audit:**
   - Live status + one-tap action for Microphone (`RECORD_AUDIO`), Contacts (`READ_CONTACTS`), Phone Calls (`CALL_PHONE`), Default Digital Assistant (`ROLE_ASSISTANT`), and Notification Access.
3. **Trusted Commands & Execution Safety:**
   - Live count of trusted sensitive commands (`callPhone`, `sendSms`, `sendWhatsapp`, `readNotifications`, `openUrl`) with inline toggles and one-tap **Revoke All**.
4. **Microphone & Notification Privacy Controls:**
   - Quick toggles for Wake-Word Standby, Background Wake-Word Service, Notification Reader Consent, and inline Notification Privacy Blocklist management.
5. **Local Data & Footprint Controls:**
   - Shows live counts for: current session messages, saved routines, persisted execution history entries, personalization memories, and local usage records.
   - Individual clear actions + confirmed **"Clear All Local Activity Data"** button (clears chat history, execution history, and usage counters without deleting encrypted API keys unless explicitly requested).

### Tests
- Widget & controller tests verifying Privacy Dashboard rendering, live permission/trust badges, revoke-all action, and clear-local-data flow.

---

## 4. Definition of Done (v1.1)

- [x] `flutter analyze --no-pub` passes with 0 issues.
- [x] All existing + new v1.1 unit/widget tests pass (`62/62`).
- [x] Android Kotlin & XML compilation + Release APK built via `scripts/build_apk.ps1` (`version 1.1.0+2`).
- [x] Physical device verification completed on Android hardware (Verified 19 Nov 2026 on `vision-release-20261119-120237.apk`).
