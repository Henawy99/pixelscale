#!/bin/bash

# ══════════════════════════════════════════════════════════════════════════════
# 🎬 PROMO APP - Build Android Release APK
# ══════════════════════════════════════════════════════════════════════════════
# Builds the promo app for installation on Android TV boxes / streaming sticks
# Supports: Xiaomi Mi Stick, Fire TV Stick, Android TV, etc.
# ══════════════════════════════════════════════════════════════════════════════

set -e

echo ""
echo "══════════════════════════════════════════════════════════════════"
echo "  🎬 PLAYMAKER PROMO APP - Android Release Build"
echo "══════════════════════════════════════════════════════════════════"
echo ""

cd promoapp

# Get current version from pubspec.yaml
CURRENT_VERSION=$(grep "^version:" pubspec.yaml | sed 's/version: //')
CURRENT_VERSION_NAME=$(echo $CURRENT_VERSION | cut -d'+' -f1)
CURRENT_BUILD=$(echo $CURRENT_VERSION | cut -d'+' -f2)

# Parse version components
MAJOR=$(echo $CURRENT_VERSION_NAME | cut -d'.' -f1)
MINOR=$(echo $CURRENT_VERSION_NAME | cut -d'.' -f2)
PATCH=$(echo $CURRENT_VERSION_NAME | cut -d'.' -f3)

# Increment patch version
NEW_PATCH=$((PATCH + 1))
NEW_VERSION_NAME="$MAJOR.$MINOR.$NEW_PATCH"
NEW_BUILD=1
NEW_VERSION="$NEW_VERSION_NAME+$NEW_BUILD"

echo "📊 Version: $CURRENT_VERSION_NAME → $NEW_VERSION_NAME"
echo ""

# Update pubspec.yaml
sed -i '' "s/^version: .*/version: $NEW_VERSION/" pubspec.yaml

# Clean previous builds
echo "🧹 Cleaning previous builds..."
flutter clean > /dev/null 2>&1

echo "📦 Installing dependencies..."
flutter pub get > /dev/null 2>&1

# Build release APK for BOTH arm32 and arm64 (for Xiaomi stick compatibility)
echo "🔨 Building release APK (arm32 + arm64)..."
flutter build apk --release --target-platform android-arm,android-arm64

# Check if build succeeded
if [ -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
    APK_SIZE=$(du -h build/app/outputs/flutter-apk/app-release.apk | cut -f1)
    
    echo ""
    echo "✅ BUILD SUCCESSFUL!"
    echo ""
    echo "══════════════════════════════════════════════════════════════════"
    echo "  📦 APK Details"
    echo "══════════════════════════════════════════════════════════════════"
    echo ""
    echo "  Version: $NEW_VERSION_NAME"
    echo "  Size: $APK_SIZE"
    echo "  Location: promoapp/build/app/outputs/flutter-apk/app-release.apk"
    echo ""
    
    # Copy APK to root for easy access
    cp build/app/outputs/flutter-apk/app-release.apk ../playmaker-promo.apk
    
    echo "══════════════════════════════════════════════════════════════════"
    echo "  📲 Install on Xiaomi Stick / Fire TV"
    echo "══════════════════════════════════════════════════════════════════"
    echo ""
    echo "  # 1. Connect to device (replace IP):"
    echo "  adb connect 192.168.8.170:5555"
    echo ""
    echo "  # 2. Install APK:"
    echo "  adb -s 192.168.8.170:5555 install -r playmaker-promo.apk"
    echo ""
    echo "  # 3. Launch app:"
    echo "  adb -s 192.168.8.170:5555 shell am start -n com.playmaker.promoapp/.MainActivity"
    echo ""
else
    echo "❌ Build failed!"
    exit 1
fi

cd ..
