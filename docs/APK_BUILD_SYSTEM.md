# VISION AI — Automated APK Build System

VISION includes an automated Android APK build, timestamped archiving, and build metadata pipeline tailored for Windows 11 (PowerShell) and Linux/macOS (Bash).

---

## 1. Naming Convention & Directory Structure

Every successful build is archived into its mode-specific directory under `dist/apk/` using the **Asia/Kolkata (IST)** timezone:

```text
dist/
  apk/
    debug/
      vision-debug-YYYYMMDD-HHmmss.apk
      vision-debug-YYYYMMDD-HHmmss.json
    profile/
      vision-profile-YYYYMMDD-HHmmss.apk
      vision-profile-YYYYMMDD-HHmmss.json
    release/
      vision-release-YYYYMMDD-HHmmss.apk
      vision-release-YYYYMMDD-HHmmss.json
```

Example:

```text
dist/apk/release/vision-release-20261117-143025.apk
dist/apk/release/vision-release-20261117-143025.json
```

### Key Guarantees
- **No Overwrites**: Each build receives an exact `Asia/Kolkata` timestamp (`YYYYMMDD-HHmmss`). If a file with the exact same second already exists, the script waits 1 second and regenerates a fresh timestamp rather than overwriting.
- **Flutter Output Preserved**: Flutter's standard output in `build/app/outputs/flutter-apk/app-<mode>.apk` is copied—never moved or deleted.
- **Fail-Fast Execution**: Stops immediately with a nonzero exit code if `flutter pub get`, `flutter analyze`, `flutter build apk`, or file verification fails.

---

## 2. Build Commands & Scripts

### Direct `flutter build apk` (Gradle Hook)
Running `flutter build apk` (or `--debug`, `--profile`, `--release`) directly triggers a Gradle post-assemble hook in `android/app/build.gradle.kts` that preserves `build/app/outputs/flutter-apk/app-<mode>.apk` and automatically creates:
- `dist/apk/<mode>/vision-<mode>-YYYYMMDD-HHmmss.apk`
- `dist/apk/<mode>/vision-<mode>-YYYYMMDD-HHmmss.json`
- `build/app/outputs/flutter-apk/vision-<mode>-YYYYMMDD-HHmmss.apk`

```powershell
flutter build apk
flutter build apk --debug
flutter build apk --profile
```

### Windows (PowerShell) — `scripts/build_apk.ps1`

```powershell
# Default (release mode)
.\scripts\build_apk.ps1

# Explicit build modes
.\scripts\build_apk.ps1 -Mode debug
.\scripts\build_apk.ps1 -Mode profile
.\scripts\build_apk.ps1 -Mode release
```

### Linux / macOS (Bash) — `scripts/build_apk.sh`

```bash
# Make executable once if needed
chmod +x scripts/build_apk.sh

# Default (release mode)
./scripts/build_apk.sh

# Explicit build modes
./scripts/build_apk.sh debug
./scripts/build_apk.sh profile
./scripts/build_apk.sh release
```

---

## 3. Pipeline Stages

1. Verify `flutter` CLI availability.
2. Run `flutter pub get`.
3. Run `flutter analyze`.
4. Run `flutter build apk --<mode>`.
5. Verify `build/app/outputs/flutter-apk/app-<mode>.apk` exists.
6. Generate `Asia/Kolkata` build timestamp (`yyyyMMdd-HHmmss`).
7. Copy APK to `dist/apk/<mode>/vision-<mode>-<timestamp>.apk`.
8. Write companion JSON metadata to `dist/apk/<mode>/vision-<mode>-<timestamp>.json`.
9. Print build mode, IST timestamp, file size, absolute APK path, metadata path, and preserved Flutter APK path.

---

## 4. Build Metadata Schema

Each `.json` metadata file records non-sensitive build telemetry:

```json
{
  "applicationName": "VISION",
  "packageId": "com.brijesh.vision",
  "buildMode": "release",
  "buildDate": "2026-11-17",
  "buildTime": "14:30:25",
  "buildTimestamp": "20261117-143025",
  "timezone": "Asia/Kolkata",
  "flutterVersion": "3.50.0",
  "dartVersion": "3.14.0",
  "gitCommitHash": null,
  "apkFilename": "vision-release-20261117-143025.apk",
  "apkSizeBytes": 54321098,
  "apkSizeFormatted": "51.80 MB (54321098 bytes)",
  "versionName": "1.0.0",
  "versionCode": 1
}
```

- **Secrets Policy**: API keys, keystores, and credentials are never read or written into build metadata.
- **Release Signing Note**: `android/app/build.gradle.kts` currently uses the default `debug` signing config for release builds (`signingConfig = signingConfigs.getByName("debug")`) so local release APKs compile cleanly until a production release keystore (`key.properties` + upload key) is configured.
