#!/bin/bash

# Run User App on Android
# Runs the USER app on Android device/emulator

echo "🎯 Running USER App (Playmaker) on Android..."
echo ""
echo "📱 App Name: Playmaker"
echo "📦 Package: com.playmakercairo.app"
echo "🎨 Icon: Green"
echo "🔧 Flavor: user"
echo ""

# Find the first Android device/emulator
ANDROID_DEVICE=$(flutter devices | grep -i "android" | head -1 | awk -F'•' '{print $2}' | xargs)

if [ -z "$ANDROID_DEVICE" ]; then
    echo "❌ No Android device found!"
    echo ""
    echo "Please start an Android emulator or connect a device."
    echo ""
    echo "Available devices:"
    flutter devices
    exit 1
fi

echo "📱 Found Android device: $ANDROID_DEVICE"
echo ""

# Run the USER flavor on the found Android device
flutter run -d "$ANDROID_DEVICE" --flavor user



