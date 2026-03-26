#!/bin/bash

# ===========================================
# 🍔 Restaurant Admin - Android Release Build
# ===========================================
# ✅ Auto-increments version
# ✅ Builds AAB for Google Play
# ✅ Also builds APK for direct install
# ✅ Auto-uploads to Play Store via Fastlane
# ===========================================

set -e

# Track current version (auto-updated by script)
CURRENT_VERSION="1.0.12"
CURRENT_BUILD="1"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'
BOLD='\033[1m'

cd "$(dirname "$0")"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}🍔 Restaurant Admin - Android Release${NC}"
echo -e "${BLUE}========================================${NC}"

# ─────────────────────────────────────────
# Parse arguments
# ─────────────────────────────────────────
AUTO_UPLOAD=false
MANUAL_ONLY=false

for arg in "$@"; do
    case $arg in
        --upload)    AUTO_UPLOAD=true ;;
        --manual)    MANUAL_ONLY=true ;;
        --help|-h)
            echo ""
            echo "Usage: ./build_android_release.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --upload    Build and auto-upload to Play Store via Fastlane"
            echo "  --manual    Build only, show manual upload instructions"
            echo "  (default)   Build and ask whether to upload automatically"
            echo ""
            exit 0
            ;;
    esac
done

# ─────────────────────────────────────────
# Calculate new version
# ─────────────────────────────────────────
OLD_VERSION="${CURRENT_VERSION}"
OLD_BUILD="${CURRENT_BUILD}"

# Increment patch version
IFS='.' read -r major minor patch <<< "$CURRENT_VERSION"
NEW_PATCH=$((patch + 1))
NEW_VERSION="${major}.${minor}.${NEW_PATCH}"
NEW_BUILD="1"

echo ""
echo -e "${CYAN}📊 Current Version: ${OLD_VERSION} (Build ${OLD_BUILD})${NC}"
echo -e "${CYAN}📊 New Version:     ${NEW_VERSION} (Build ${NEW_BUILD})${NC}"
echo ""

# ─────────────────────────────────────────
# Update version
# ─────────────────────────────────────────
sed -i '' "s/^version: .*/version: ${NEW_VERSION}+${NEW_BUILD}/" pubspec.yaml
echo -e "${GREEN}✅ Version updated in pubspec.yaml${NC}"

# Update this script with new version for next time
sed -i '' "s/^CURRENT_VERSION=\".*\"/CURRENT_VERSION=\"${NEW_VERSION}\"/" "$0"
sed -i '' "s/^CURRENT_BUILD=\".*\"/CURRENT_BUILD=\"${NEW_BUILD}\"/" "$0"

# ─────────────────────────────────────────
# Clean & Build
# ─────────────────────────────────────────
echo -e "${YELLOW}🧹 Cleaning...${NC}"
flutter clean

echo -e "${YELLOW}📦 Getting dependencies...${NC}"
flutter pub get

# Generate icons (if flutter_launcher_icons is configured)
if grep -q "flutter_launcher_icons" pubspec.yaml; then
    echo -e "${YELLOW}🎨 Generating app icons...${NC}"
    flutter pub run flutter_launcher_icons 2>/dev/null || true
fi

# Build Android App Bundle (for Play Store)
echo -e "${YELLOW}🤖 Building Android App Bundle (AAB)...${NC}"
flutter build appbundle --release

# Also build APK for direct testing
echo -e "${YELLOW}📦 Building APK for direct install...${NC}"
flutter build apk --release

# Copy APK to Desktop for easy access
cp build/app/outputs/flutter-apk/app-release.apk ~/Desktop/restaurant-admin-${NEW_VERSION}.apk 2>/dev/null || true

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✅ Android Build Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${CYAN}📊 Version Info:${NC}"
echo -e "   Old Version: ${OLD_VERSION} (Build ${OLD_BUILD})"
echo -e "   New Version: ${NEW_VERSION} (Build ${NEW_BUILD})"
echo -e "   Package: com.example.restaurantadmin"
echo ""
echo -e "${BLUE}📦 Build Outputs:${NC}"
echo "   AAB (Play Store): build/app/outputs/bundle/release/app-release.aab"
echo "   APK (Direct):     ~/Desktop/restaurant-admin-${NEW_VERSION}.apk"
echo ""

# ─────────────────────────────────────────
# Auto-Upload or Manual
# ─────────────────────────────────────────

# Check if Fastlane is available
FASTLANE_AVAILABLE=false
if [ -f "android/Gemfile" ] && [ -f "android/Gemfile.lock" ] && [ -d "android/fastlane" ]; then
    if command -v bundle &> /dev/null; then
        FASTLANE_AVAILABLE=true
    fi
fi

# Check if credentials exist
CREDENTIALS_CONFIGURED=false
if [ -f "$HOME/.play-store/play-store-credentials.json" ]; then
    CREDENTIALS_CONFIGURED=true
fi

if [ "$MANUAL_ONLY" = true ]; then
    # User explicitly wants manual upload
    echo -e "${BLUE}📱 Next Steps (Manual Upload):${NC}"
    echo "   1. Go to Google Play Console: https://play.google.com/console"
    echo "   2. Select your app"
    echo "   3. Go to 'Internal testing' or 'Production'"
    echo "   4. Create new release"
    echo "   5. Upload the AAB file from:"
    echo "      build/app/outputs/bundle/release/app-release.aab"

elif [ "$AUTO_UPLOAD" = true ]; then
    # User wants auto-upload
    if [ "$FASTLANE_AVAILABLE" = true ] && [ "$CREDENTIALS_CONFIGURED" = true ]; then
        echo -e "${MAGENTA}🚀 Auto-uploading to Play Store via Fastlane...${NC}"
        echo ""
        cd android
        bundle exec fastlane upload_only
        cd ..
        echo ""
        echo -e "${GREEN}✅ Upload complete! Check Google Play Console.${NC}"
    else
        echo -e "${RED}❌ Cannot auto-upload: Fastlane not set up or credentials not configured${NC}"
        echo -e "${YELLOW}   Run: ./setup_auto_upload.sh${NC}"
        echo ""
        echo -e "${BLUE}📱 Manual Upload Steps:${NC}"
        echo "   1. Go to Google Play Console: https://play.google.com/console"
        echo "   2. Select your app"
        echo "   3. Go to 'Internal testing'"
        echo "   4. Create new release"
        echo "   5. Upload: build/app/outputs/bundle/release/app-release.aab"
    fi

else
    # Default: Ask user what to do
    if [ "$FASTLANE_AVAILABLE" = true ] && [ "$CREDENTIALS_CONFIGURED" = true ]; then
        echo -e "${CYAN}How would you like to upload?${NC}"
        echo "  1) 🚀 Auto-upload to Play Store Internal Testing (Fastlane)"
        echo "  2) 📋 Show manual upload instructions"
        echo "  3) ⏭️  Skip upload (build only)"
        echo ""
        read -p "Choose (1/2/3): " choice

        case $choice in
            1)
                echo ""
                echo -e "${MAGENTA}🚀 Auto-uploading to Play Store via Fastlane...${NC}"
                cd android
                bundle exec fastlane upload_only
                cd ..
                echo ""
                echo -e "${GREEN}✅ Upload complete! Check Google Play Console.${NC}"
                ;;
            2)
                echo ""
                echo -e "${BLUE}📱 Manual Upload Steps:${NC}"
                echo "   1. Go to Google Play Console: https://play.google.com/console"
                echo "   2. Select your app → Internal testing"
                echo "   3. Create new release"
                echo "   4. Upload: build/app/outputs/bundle/release/app-release.aab"
                ;;
            3)
                echo -e "${GREEN}✅ Build complete! Skipping upload.${NC}"
                ;;
            *)
                echo -e "${BLUE}📱 Upload AAB to Play Console:${NC}"
                echo "   build/app/outputs/bundle/release/app-release.aab"
                ;;
        esac
    else
        # Fastlane not available, show manual instructions
        echo -e "${BLUE}📱 Next Steps:${NC}"
        echo "   1. Go to Google Play Console: https://play.google.com/console"
        echo "   2. Select your app"
        echo "   3. Go to 'Internal testing' or 'Production'"
        echo "   4. Create new release"
        echo "   5. Upload the AAB file"
        echo ""
        echo -e "${CYAN}💡 Tip: Run ./setup_auto_upload.sh to enable auto-upload to Play Store${NC}"
    fi
fi

echo ""
echo -e "${GREEN}🎉 Done! Happy releasing! 🚀${NC}"
