#!/bin/bash

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║                    AL BASEET ANDROID BUILD SCRIPT                        ║
# ╠═══════════════════════════════════════════════════════════════════════════╣
# ║  This script builds the Al Baseet Sports Android app                     ║
# ║  Entry point: lib/main_albaseet.dart                                     ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

set -e

echo ""
echo "╔═══════════════════════════════════════════════════════════════════════════╗"
echo "║                    🏀 AL BASEET SPORTS - ANDROID BUILD 🏀                 ║"
echo "╚═══════════════════════════════════════════════════════════════════════════╝"
echo ""

# Navigate to promoapp directory
cd "$(dirname "$0")"

echo "📁 Working directory: $(pwd)"
echo ""

# Step 1: Clean previous build
echo "🧹 Cleaning previous build..."
flutter clean
echo "✅ Clean complete"
echo ""

# Step 2: Get dependencies
echo "📦 Getting dependencies..."
flutter pub get
echo "✅ Dependencies installed"
echo ""

# Step 3: Build APK (Debug for testing)
echo "🔨 Building Debug APK..."
flutter build apk --debug -t lib/main_albaseet.dart
echo "✅ Debug APK built"
echo ""

# Step 4: Build Release APK
echo "🚀 Building Release APK..."
flutter build apk --release -t lib/main_albaseet.dart
echo "✅ Release APK built"
echo ""

# Step 5: Build App Bundle (for Play Store)
echo "📱 Building App Bundle (AAB) for Play Store..."
flutter build appbundle --release -t lib/main_albaseet.dart
echo "✅ App Bundle built"
echo ""

# Output locations
echo "╔═══════════════════════════════════════════════════════════════════════════╗"
echo "║                         📦 BUILD OUTPUT LOCATIONS                         ║"
echo "╠═══════════════════════════════════════════════════════════════════════════╣"
echo "║                                                                           ║"
echo "║  Debug APK:                                                               ║"
echo "║    build/app/outputs/flutter-apk/app-debug.apk                            ║"
echo "║                                                                           ║"
echo "║  Release APK:                                                             ║"
echo "║    build/app/outputs/flutter-apk/app-release.apk                          ║"
echo "║                                                                           ║"
echo "║  App Bundle (AAB):                                                        ║"
echo "║    build/app/outputs/bundle/release/app-release.aab                       ║"
echo "║                                                                           ║"
echo "╚═══════════════════════════════════════════════════════════════════════════╝"
echo ""

# Check if APK exists and show size
if [ -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
    APK_SIZE=$(du -h "build/app/outputs/flutter-apk/app-release.apk" | cut -f1)
    echo "✅ Release APK size: $APK_SIZE"
fi

echo ""
echo "🎉 AL BASEET BUILD COMPLETE!"
echo ""
echo "📱 To install on connected device:"
echo "   flutter install -t lib/main_albaseet.dart"
echo ""
echo "🔌 To run on connected device:"
echo "   flutter run -t lib/main_albaseet.dart"
echo ""
