#!/bin/bash
# Builds the full restaurant admin app (lib/main.dart) as an APK to install directly on an
# Android phone/tablet (e.g. the kitchen phone). For the Play Store use build_android_release.sh.
#
#   ./build_admin_apk.sh
#
# Output: build/admin/restaurant-admin-<version>.apk
set -euo pipefail
cd "$(dirname "$0")"

if ! grep -q '^SUPABASE_URL=' .env || ! grep -q '^SUPABASE_ANON_KEY=' .env; then
  echo "ERROR: SUPABASE_URL / SUPABASE_ANON_KEY missing in .env" >&2
  exit 1
fi

# pubspec.yaml bundles .env as an asset. Keep what the app reads (Supabase URL + anon key,
# Gemini key, listener flags) but never ship the service-role key.
BACKUP="admin-build-backup.env"
cp .env "$BACKUP"
trap 'mv "$BACKUP" .env' EXIT
grep -E '^(SUPABASE_URL|SUPABASE_ANON_KEY|GEMINI_API_KEY|ENABLE_GLOBAL_ORDER_LISTENER|ENABLE_GLOBAL_PURCHASE_LISTENER)=' "$BACKUP" > .env

VERSION=$(grep '^version:' pubspec.yaml | sed -E 's/version: *([0-9.]+).*/\1/')
BUILD_NUMBER=$(date +%y%j%H%M) # yyDDDHHMM: always increasing, fits Android's versionCode

flutter build apk --release \
  -t lib/main.dart \
  --build-name="$VERSION" \
  --build-number="$BUILD_NUMBER" \
  --target-platform android-arm,android-arm64

mkdir -p build/admin
OUT="build/admin/restaurant-admin-$VERSION-$BUILD_NUMBER.apk"
cp build/app/outputs/flutter-apk/app-release.apk "$OUT"
echo "Admin APK: $OUT"
