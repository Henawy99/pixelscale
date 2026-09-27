#!/bin/bash
# Builds the stand-alone driver app (lib/main_driver.dart) as an APK you can send to drivers.
#
#   ./build_driver_apk.sh
#
# Output: build/driver/devils-driver-<version>.apk
# Each build gets a higher version code, so drivers can install new APKs over old ones.
set -euo pipefail
cd "$(dirname "$0")"

URL=$(grep '^SUPABASE_URL=' .env | cut -d= -f2-)
ANON=$(grep '^SUPABASE_ANON_KEY=' .env | cut -d= -f2-)
if [[ -z "$URL" || -z "$ANON" ]]; then
  echo "ERROR: SUPABASE_URL / SUPABASE_ANON_KEY missing in .env" >&2
  exit 1
fi

# pubspec.yaml bundles .env as an asset. The driver APK must not carry the service-role
# key, so build with an empty .env (values come from --dart-define) and restore it after.
BACKUP="driver-build-backup.env"
cp .env "$BACKUP"
trap 'mv "$BACKUP" .env' EXIT
echo "# driver build: configuration comes from --dart-define" > .env

VERSION=$(grep '^version:' pubspec.yaml | sed -E 's/version: *([0-9.]+).*/\1/')
BUILD_NUMBER=$(date +%y%j%H%M) # yyDDDHHMM: always increasing, fits Android's versionCode

ORG_GRADLE_PROJECT_appLabel="Devils Driver" flutter build apk --release \
  -t lib/main_driver.dart \
  --dart-define=SUPABASE_URL="$URL" \
  --dart-define=SUPABASE_ANON_KEY="$ANON" \
  --build-name="$VERSION" \
  --build-number="$BUILD_NUMBER" \
  --target-platform android-arm,android-arm64

mkdir -p build/driver
OUT="build/driver/devils-driver-$VERSION-$BUILD_NUMBER.apk"
cp build/app/outputs/flutter-apk/app-release.apk "$OUT"
echo "Driver APK: $OUT"
