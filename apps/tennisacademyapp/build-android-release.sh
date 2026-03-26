#!/usr/bin/env bash
# ============================================
# Tennis Academy – Android release APK build
# ============================================
# Produces an installable release APK. Safe to share; recipients can install and open the app.
# For Play Store, use: flutter build appbundle --release
# ============================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

APP_NAME="Tennis Academy"
APK_OUTPUT_NAME="TennisAcademy-release.apk"
FLUTTER_APK_PATH="build/app/outputs/flutter-apk/app-release.apk"

echo "Building Android release APK for $APP_NAME..."
flutter clean
flutter pub get
flutter build apk --release

if [[ -f "$FLUTTER_APK_PATH" ]]; then
  cp "$FLUTTER_APK_PATH" "$SCRIPT_DIR/$APK_OUTPUT_NAME"
  echo ""
  echo "Release APK ready: $SCRIPT_DIR/$APK_OUTPUT_NAME"
  echo "You can send this file; recipients can install and open the app."
else
  echo "Build failed: $FLUTTER_APK_PATH not found."
  exit 1
fi
