#!/bin/bash

# ===========================================
# 🍔 Restaurant Admin - iOS Release Build
# ===========================================
# ✅ Auto-increments version
# ✅ Builds for iOS
# ✅ Auto-uploads to TestFlight via Fastlane
# ✅ Falls back to Xcode if Fastlane not set up
# ===========================================

set -e

# Track current version (auto-updated by script)
CURRENT_VERSION="1.0.6"
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
echo -e "${BLUE}🍔 Restaurant Admin - iOS Release${NC}"
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
            echo "Usage: ./build_ios_release.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --upload    Build and auto-upload to TestFlight via Fastlane"
            echo "  --manual    Build only, open Xcode for manual upload"
            echo "  (default)   Build and ask whether to upload or open Xcode"
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

# Build iOS
echo -e "${YELLOW}🍎 Building iOS...${NC}"
flutter build ios --release

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✅ iOS Build Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${CYAN}📊 Version Info:${NC}"
echo -e "   Old Version: ${OLD_VERSION} (Build ${OLD_BUILD})"
echo -e "   New Version: ${NEW_VERSION} (Build ${NEW_BUILD})"
echo -e "   Bundle ID: com.mycoolrestaurant.adminapp"
echo ""

# ─────────────────────────────────────────
# Auto-Upload or Manual
# ─────────────────────────────────────────

# Check if Fastlane is available
FASTLANE_AVAILABLE=false
if [ -f "Gemfile" ] && [ -f "Gemfile.lock" ] && [ -d "fastlane" ]; then
    if command -v bundle &> /dev/null; then
        FASTLANE_AVAILABLE=true
    fi
fi

# Check if credentials are configured (only check non-comment lines)
CREDENTIALS_CONFIGURED=false
if [ "$FASTLANE_AVAILABLE" = true ]; then
    if ! grep -v "^#" fastlane/Fastfile 2>/dev/null | grep -q "YOUR_KEY_ID" && \
       ! grep -v "^#" fastlane/Appfile 2>/dev/null | grep -q "YOUR_TEAM_ID"; then
        CREDENTIALS_CONFIGURED=true
    fi
fi

if [ "$MANUAL_ONLY" = true ]; then
    # User explicitly wants manual upload
    echo -e "${YELLOW}🔄 Opening Xcode for manual upload...${NC}"
    open ios/Runner.xcworkspace
    echo ""
    echo -e "${BLUE}📱 Next Steps in Xcode:${NC}"
    echo "   1. Select 'Any iOS Device' (top left)"
    echo "   2. Product → Archive"
    echo "   3. Click 'Distribute App'"
    echo "   4. Choose 'App Store Connect' → Upload"
    echo "   5. Check TestFlight in 5-10 minutes!"

elif [ "$AUTO_UPLOAD" = true ]; then
    # User wants auto-upload
    if [ "$FASTLANE_AVAILABLE" = true ] && [ "$CREDENTIALS_CONFIGURED" = true ]; then
        echo -e "${MAGENTA}🚀 Auto-uploading to TestFlight via Fastlane...${NC}"
        echo ""
        cd fastlane
        bundle exec fastlane ios upload_app
        cd ..
        echo ""
        echo -e "${GREEN}✅ Upload complete! Check TestFlight in 5-15 minutes.${NC}"
    else
        echo -e "${RED}❌ Cannot auto-upload: Fastlane not set up or credentials not configured${NC}"
        echo -e "${YELLOW}   Run: ./setup_auto_upload.sh${NC}"
        echo ""
        echo -e "${YELLOW}🔄 Falling back to Xcode...${NC}"
        open ios/Runner.xcworkspace
        echo ""
        echo -e "${BLUE}📱 Next Steps in Xcode:${NC}"
        echo "   1. Select 'Any iOS Device' (top left)"
        echo "   2. Product → Archive"
        echo "   3. Click 'Distribute App'"
        echo "   4. Choose 'App Store Connect' → Upload"
    fi

else
    # Default: Ask user what to do
    if [ "$FASTLANE_AVAILABLE" = true ] && [ "$CREDENTIALS_CONFIGURED" = true ]; then
        echo -e "${CYAN}How would you like to upload?${NC}"
        echo "  1) 🚀 Auto-upload to TestFlight (Fastlane)"
        echo "  2) 🔧 Open Xcode for manual upload"
        echo "  3) ⏭️  Skip upload (build only)"
        echo ""
        read -p "Choose (1/2/3): " choice

        case $choice in
            1)
                echo ""
                echo -e "${MAGENTA}🚀 Auto-uploading to TestFlight via Fastlane...${NC}"
                cd fastlane
                bundle exec fastlane ios upload_app
                cd ..
                echo ""
                echo -e "${GREEN}✅ Upload complete! Check TestFlight in 5-15 minutes.${NC}"
                ;;
            2)
                echo ""
                echo -e "${YELLOW}🔄 Opening Xcode...${NC}"
                open ios/Runner.xcworkspace
                echo ""
                echo -e "${BLUE}📱 Next Steps in Xcode:${NC}"
                echo "   1. Select 'Any iOS Device' (top left)"
                echo "   2. Product → Archive"
                echo "   3. Click 'Distribute App'"
                echo "   4. Choose 'App Store Connect' → Upload"
                ;;
            3)
                echo -e "${GREEN}✅ Build complete! Skipping upload.${NC}"
                ;;
            *)
                echo -e "${YELLOW}🔄 Opening Xcode (default)...${NC}"
                open ios/Runner.xcworkspace
                ;;
        esac
    else
        # Fastlane not available, use Xcode
        echo -e "${YELLOW}🔄 Opening Xcode...${NC}"
        open ios/Runner.xcworkspace
        echo ""
        echo -e "${BLUE}📱 Next Steps in Xcode:${NC}"
        echo "   1. Select 'Any iOS Device' (top left)"
        echo "   2. Product → Archive"
        echo "   3. Click 'Distribute App'"
        echo "   4. Choose 'App Store Connect' → Upload"
        echo "   5. Check TestFlight in 5-10 minutes!"
        echo ""
        echo -e "${CYAN}💡 Tip: Run ./setup_auto_upload.sh to enable auto-upload to TestFlight${NC}"
    fi
fi

echo ""
echo -e "${GREEN}🎉 Done! Happy releasing! 🚀${NC}"
