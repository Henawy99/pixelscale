#!/bin/bash

# Restaurant Admin - Android Build Script
# This script builds an APK for testing on Android devices

set -e

echo "🔧 Building Restaurant Admin for Android..."
echo ""

# Navigate to project directory
cd "$(dirname "$0")"

# Clean previous builds
echo "🧹 Cleaning previous builds..."
flutter clean

# Get dependencies
echo "📦 Getting dependencies..."
flutter pub get

# Build APK (debug for testing)
echo "🏗️ Building debug APK..."
flutter build apk --debug

echo ""
echo "✅ Build complete!"
echo ""
echo "📱 APK location:"
echo "   build/app/outputs/flutter-apk/app-debug.apk"
echo ""
echo "📲 To install on connected device, run:"
echo "   flutter install"
echo ""
echo "Or manually copy the APK to your device and install it."





