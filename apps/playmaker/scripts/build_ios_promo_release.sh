#!/bin/bash

# ══════════════════════════════════════════════════════════════════════════════
# 🎬 PROMO APP - iOS Release Build Script
# ══════════════════════════════════════════════════════════════════════════════
# This builds the Promo Display App for iOS devices (iPad, Apple TV, etc.)
# For football field displays showing match recordings and advertisements
# ══════════════════════════════════════════════════════════════════════════════

set -e

echo ""
echo "══════════════════════════════════════════════════════════════════"
echo "  🎬 PLAYMAKER PROMO APP - iOS Release Build"
echo "══════════════════════════════════════════════════════════════════"
echo ""

# Navigate to promo app directory
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

echo "🧹 Cleaning..."
flutter clean > /dev/null 2>&1

echo "📦 Getting dependencies..."
flutter pub get > /dev/null 2>&1

echo "🔨 Building iOS release..."
flutter build ios --release

echo ""
echo "✅ BUILD COMPLETE!"
echo ""

cd ..

# Check if Fastlane is configured for auto-upload
FASTLANE_CONFIGURED=false
if command -v bundle &> /dev/null && [ -f "fastlane/Fastfile" ]; then
    # Check if Appfile has real credentials (not placeholders)
    if [ -f "fastlane/Appfile" ] && ! grep -q "YOUR_KEY_ID\|YOUR_ISSUER_ID\|YOUR_TEAM_ID" fastlane/Appfile 2>/dev/null; then
        # Check if the Appfile has actual configuration (not just comments)
        if grep -q "app_store_connect_api_key\|team_id" fastlane/Appfile 2>/dev/null; then
            FASTLANE_CONFIGURED=true
        fi
    fi
fi

if [ "$FASTLANE_CONFIGURED" = true ]; then
    echo "🚀 Auto-uploading to TestFlight via Fastlane..."
    echo ""
    
    # Run Fastlane upload
    bundle exec fastlane ios promo
    UPLOAD_STATUS=$?
    
    if [ $UPLOAD_STATUS -eq 0 ]; then
        echo ""
        echo "══════════════════════════════════════════════════════════════════"
        echo "  ✅ UPLOAD COMPLETE!"
        echo "  Check TestFlight in 5-10 minutes."
        echo "══════════════════════════════════════════════════════════════════"
    else
        echo ""
        echo "⚠️  Auto-upload failed. Opening Xcode for manual upload..."
        echo ""
        open promoapp/ios/Runner.xcworkspace
    fi
else
    echo "══════════════════════════════════════════════════════════════════"
    echo "  📱 Next Steps:"
    echo "══════════════════════════════════════════════════════════════════"
    echo ""
    echo "  💡 Auto-upload not configured."
    echo "     Run ./setup_auto_upload.sh to enable auto-upload"
    echo ""
    echo "  Manual upload:"
    echo "  1. Open Xcode: promoapp/ios/Runner.xcworkspace"
    echo "  2. Select 'Any iOS Device (arm64)' as build target"
    echo "  3. Product → Archive"
    echo "  4. Distribute to TestFlight"
    echo ""
    echo "  Or for Ad-Hoc distribution:"
    echo "  - Export as Ad-Hoc IPA for direct installation"
    echo ""

    # Try to open Xcode
    if command -v open &> /dev/null; then
        echo "🚀 Opening Xcode..."
        open promoapp/ios/Runner.xcworkspace
    fi
fi

echo ""
echo "══════════════════════════════════════════════════════════════════"
echo "  🎬 Promo App v$NEW_VERSION_NAME ready for distribution!"
echo "══════════════════════════════════════════════════════════════════"
echo ""
