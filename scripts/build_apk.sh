#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-release}"
if [[ "$MODE" == "--mode" ]]; then
  MODE="${2:-}"
fi

case "$MODE" in
  debug|profile|release)
    ;;
  *)
    echo "Error: Invalid build mode '$MODE'. Allowed values: debug, profile, release." >&2
    echo "Usage: $0 [debug|profile|release]" >&2
    exit 1
    ;;
esac

if ! command -v flutter >/dev/null 2>&1; then
  echo "Error: flutter CLI not found on PATH." >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

echo "============================================================"
echo " VISION AI - Automated Android APK Build ($MODE)"
echo "============================================================"

echo "==> Fetching Flutter dependencies (flutter pub get)"
flutter pub get

echo "==> Running static analysis (flutter analyze)"
flutter analyze

echo "==> Building $MODE APK (flutter build apk --$MODE)"
VISION_SKIP_GRADLE_ARCHIVE=1 flutter build apk "--$MODE"

SOURCE_APK="$PROJECT_ROOT/build/app/outputs/flutter-apk/app-$MODE.apk"
if [[ ! -f "$SOURCE_APK" ]]; then
  echo "Error: Expected APK not found at $SOURCE_APK" >&2
  exit 1
fi

DIST_DIR="$PROJECT_ROOT/dist/apk/$MODE"
mkdir -p "$DIST_DIR"

while true; do
  DATE_COMPACT="$(TZ="Asia/Kolkata" date +"%Y%m%d")"
  TIME_COMPACT="$(TZ="Asia/Kolkata" date +"%H%M%S")"
  BUILD_DATE_ISO="$(TZ="Asia/Kolkata" date +"%Y-%m-%d")"
  BUILD_TIME_ISO="$(TZ="Asia/Kolkata" date +"%H:%M:%S")"
  BASE_NAME="vision-$MODE-$DATE_COMPACT-$TIME_COMPACT"
  DEST_APK="$DIST_DIR/$BASE_NAME.apk"
  DEST_META="$DIST_DIR/$BASE_NAME.json"
  if [[ -e "$DEST_APK" || -e "$DEST_META" ]]; then
    sleep 1
  else
    break
  fi
done

cp "$SOURCE_APK" "$DEST_APK"

APK_SIZE_BYTES="$(wc -c < "$DEST_APK" | tr -d ' ')"
APK_SIZE_MB="$(awk "BEGIN {printf \"%.2f\", $APK_SIZE_BYTES / 1048576}")"

VERSION_LINE="$(grep -E '^\s*version\s*:' "$PROJECT_ROOT/pubspec.yaml" | head -n 1 | sed -E 's/^\s*version\s*:\s*([^#[:space:]]+).*/\1/' || true)"
VERSION_NAME="${VERSION_LINE%%+*}"
VERSION_CODE="${VERSION_LINE#*+}"
if [[ -z "$VERSION_NAME" || "$VERSION_NAME" == "$VERSION_LINE" ]]; then
  VERSION_NAME="${VERSION_LINE:-1.0.0}"
  VERSION_CODE="1"
fi

PACKAGE_ID="$(grep -E 'applicationId\s*=' "$PROJECT_ROOT/android/app/build.gradle.kts" | head -n 1 | sed -E 's/.*"([^"]+)".*/\1/' || true)"
PACKAGE_ID="${PACKAGE_ID:-com.brijesh.vision}"

FLUTTER_VER="$(flutter --version 2>/dev/null | head -n 1 | awk '{print $2}' || echo 'unknown')"
DART_VER="$(dart --version 2>/dev/null | sed -E 's/.*version: ([^ ]+).*/\1/' || echo 'unknown')"

GIT_HASH_JSON="null"
if command -v git >/dev/null 2>&1 && git -C "$PROJECT_ROOT" rev-parse HEAD >/dev/null 2>&1; then
  GIT_HASH="$(git -C "$PROJECT_ROOT" rev-parse HEAD)"
  GIT_HASH_JSON="\"$GIT_HASH\""
fi

cat > "$DEST_META" <<EOF
{
  "applicationName": "VISION",
  "packageId": "$PACKAGE_ID",
  "buildMode": "$MODE",
  "buildDate": "$BUILD_DATE_ISO",
  "buildTime": "$BUILD_TIME_ISO",
  "buildTimestamp": "$DATE_COMPACT-$TIME_COMPACT",
  "timezone": "Asia/Kolkata",
  "flutterVersion": "$FLUTTER_VER",
  "dartVersion": "$DART_VER",
  "gitCommitHash": $GIT_HASH_JSON,
  "apkFilename": "$BASE_NAME.apk",
  "apkSizeBytes": $APK_SIZE_BYTES,
  "apkSizeFormatted": "$APK_SIZE_MB MB ($APK_SIZE_BYTES bytes)",
  "versionName": "$VERSION_NAME",
  "versionCode": $VERSION_CODE
}
EOF

echo ""
echo "BUILD SUCCESSFUL"
echo "  Application    : VISION ($PACKAGE_ID)"
echo "  Build Mode     : $MODE"
echo "  Timestamp      : $BUILD_DATE_ISO $BUILD_TIME_ISO (Asia/Kolkata)"
echo "  File Size      : $APK_SIZE_MB MB ($APK_SIZE_BYTES bytes)"
echo "  Output APK     : $DEST_APK"
echo "  Metadata JSON  : $DEST_META"
echo "  Flutter APK    : $SOURCE_APK (preserved)"
echo ""
