#!/bin/bash

# ===========================================
# ⭐ PixelReview - React Native iOS Release
# ===========================================
# ✅ Validates TypeScript
# ✅ Builds native iOS IPA with Fastlane
# ✅ Auto-uploads to TestFlight
# ===========================================

set -e

CURRENT_VERSION="1.0.0"
CURRENT_BUILD="12"

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
echo -e "${BLUE}⭐ PixelReview - React Native iOS Release${NC}"
echo -e "${BLUE}========================================${NC}"

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
            echo "  --manual    Build only without uploading"
            echo "  (default)   Build and prompt"
            echo ""
            exit 0
            ;;
    esac
done

echo -e "${CYAN}📦 Step 1: Validating TypeScript...${NC}"
npx tsc --noEmit
echo -e "${GREEN}✅ TypeScript validated successfully${NC}"

if [ "$AUTO_UPLOAD" = true ]; then
    echo -e "${MAGENTA}🚀 Step 2: Fastlane building & uploading to TestFlight...${NC}"
    bundle exec fastlane ios upload_app
elif [ "$MANUAL_ONLY" = true ]; then
    echo -e "${MAGENTA}🔨 Step 2: Fastlane building IPA (no upload)...${NC}"
    bundle exec fastlane ios build_only
else
    echo ""
    echo -e "${YELLOW}Choose next step:${NC}"
    echo "  1) Build & Upload to TestFlight (Fastlane)"
    echo "  2) Build IPA only (Fastlane)"
    echo "  3) Open in Xcode"
    echo "  4) Exit"
    read -p "Select option [1-4]: " choice
    case $choice in
        1)
            bundle exec fastlane ios upload_app
            ;;
        2)
            bundle exec fastlane ios build_only
            ;;
        3)
            open ios/PixelReview.xcworkspace
            ;;
        *)
            echo "Done."
            ;;
    esac
fi
