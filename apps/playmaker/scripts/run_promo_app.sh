#!/bin/bash

# ============================================
# 🎬 PROMO APP - Run for Development
# ============================================
# This app streams match recordings on big screens
# with Playmaker ads displayed every 30 seconds
#
# Usage:
#   ./run_promo_app.sh          # Auto-detect device
#   ./run_promo_app.sh ios      # Run on iOS simulator
#   ./run_promo_app.sh android  # Run on Android device
#   ./run_promo_app.sh <id>     # Run on specific device

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  🎬 PLAYMAKER PROMO APP - Development Mode"
echo "════════════════════════════════════════════════════════════"
echo ""

cd promoapp

# Check if flutter packages are installed
if [ ! -d ".dart_tool" ]; then
    echo "📦 Installing dependencies..."
    flutter pub get
fi

# Determine target device
TARGET=$1

if [ -z "$TARGET" ]; then
    echo "📱 Available devices:"
    flutter devices
    echo ""
    
    # Try iOS first, then Android
    if flutter devices | grep -q "iPhone\|iPad"; then
        TARGET=$(flutter devices | grep -E "iPhone|iPad" | head -1 | awk -F '•' '{print $2}' | xargs)
        echo "🍎 Running on iOS: $TARGET"
    elif flutter devices | grep -q "android"; then
        TARGET=$(flutter devices | grep android | head -1 | awk -F '•' '{print $2}' | xargs)
        echo "🤖 Running on Android: $TARGET"
    elif flutter devices | grep -q "emulator"; then
        TARGET=$(flutter devices | grep emulator | head -1 | awk -F '•' '{print $2}' | xargs)
        echo "📱 Running on Emulator: $TARGET"
    else
        echo "❌ No device found. Connect a device or start an emulator."
        exit 1
    fi
fi

echo ""
echo "🚀 Launching Promo App..."
flutter run -d "$TARGET"

cd ..
