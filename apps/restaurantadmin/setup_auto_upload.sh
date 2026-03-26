#!/bin/bash

# ============================================================
# 🍔 Restaurant Admin - Fastlane Auto-Upload Setup
# ============================================================
# This script sets up Fastlane for automated uploads to:
#   - Apple TestFlight (iOS)
#   - Google Play Store Internal Testing (Android)
#   - Netlify (Web)
# ============================================================

set -e

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

echo -e "${BLUE}============================================================${NC}"
echo -e "${BLUE}🍔 Restaurant Admin - Auto-Upload Setup${NC}"
echo -e "${BLUE}============================================================${NC}"
echo ""

ERRORS=0
WARNINGS=0

# ─────────────────────────────────────────
# Check Prerequisites
# ─────────────────────────────────────────
echo -e "${CYAN}📋 Checking Prerequisites...${NC}"
echo ""

# Check Ruby
if command -v ruby &> /dev/null; then
    RUBY_VERSION=$(ruby --version | head -1)
    echo -e "${GREEN}  ✅ Ruby: ${RUBY_VERSION}${NC}"
else
    echo -e "${RED}  ❌ Ruby not found!${NC}"
    echo -e "${YELLOW}     Install: brew install ruby${NC}"
    ERRORS=$((ERRORS + 1))
fi

# Check Bundler
if command -v bundle &> /dev/null; then
    BUNDLER_VERSION=$(bundle --version | head -1)
    echo -e "${GREEN}  ✅ Bundler: ${BUNDLER_VERSION}${NC}"
else
    echo -e "${YELLOW}  ⚠️  Bundler not found. Installing...${NC}"
    gem install bundler
    if command -v bundle &> /dev/null; then
        echo -e "${GREEN}  ✅ Bundler installed successfully${NC}"
    else
        echo -e "${RED}  ❌ Failed to install Bundler${NC}"
        ERRORS=$((ERRORS + 1))
    fi
fi

# Check Flutter
if command -v flutter &> /dev/null; then
    FLUTTER_VER=$(flutter --version 2>/dev/null | head -1)
    echo -e "${GREEN}  ✅ Flutter: ${FLUTTER_VER}${NC}"
else
    echo -e "${RED}  ❌ Flutter not found!${NC}"
    echo -e "${YELLOW}     Install: https://flutter.dev/docs/get-started/install${NC}"
    ERRORS=$((ERRORS + 1))
fi

# Check Xcode (macOS only)
if [[ "$OSTYPE" == "darwin"* ]]; then
    if command -v xcodebuild &> /dev/null; then
        XCODE_VER=$(xcodebuild -version 2>/dev/null | head -1)
        echo -e "${GREEN}  ✅ Xcode: ${XCODE_VER}${NC}"
    else
        echo -e "${RED}  ❌ Xcode not found!${NC}"
        echo -e "${YELLOW}     Install from Mac App Store${NC}"
        ERRORS=$((ERRORS + 1))
    fi
fi

echo ""

# ─────────────────────────────────────────
# Install Fastlane (iOS)
# ─────────────────────────────────────────
echo -e "${CYAN}📦 Installing Fastlane for iOS...${NC}"
if [ -f "Gemfile" ]; then
    bundle install
    echo -e "${GREEN}  ✅ Fastlane installed for iOS${NC}"
else
    echo -e "${RED}  ❌ Gemfile not found in project root!${NC}"
    ERRORS=$((ERRORS + 1))
fi

echo ""

# ─────────────────────────────────────────
# Install Fastlane (Android)
# ─────────────────────────────────────────
echo -e "${CYAN}📦 Installing Fastlane for Android...${NC}"
if [ -f "android/Gemfile" ]; then
    cd android
    bundle install
    cd ..
    echo -e "${GREEN}  ✅ Fastlane installed for Android${NC}"
else
    echo -e "${RED}  ❌ Gemfile not found in android/ directory!${NC}"
    ERRORS=$((ERRORS + 1))
fi

echo ""

# ─────────────────────────────────────────
# Check iOS Credentials
# ─────────────────────────────────────────
echo -e "${CYAN}🍎 Checking iOS Credentials (App Store Connect API Key)...${NC}"
echo ""

API_KEY_DIR="$HOME/.appstoreconnect/private_keys"
API_KEY_FILES=$(ls "$API_KEY_DIR"/AuthKey_*.p8 2>/dev/null || true)

if [ -n "$API_KEY_FILES" ]; then
    echo -e "${GREEN}  ✅ API Key (.p8) found:${NC}"
    for f in $API_KEY_FILES; do
        echo -e "${GREEN}     → $(basename "$f")${NC}"
    done
else
    echo -e "${YELLOW}  ⚠️  No API Key (.p8) found!${NC}"
    echo ""
    echo -e "${MAGENTA}  📝 How to set up App Store Connect API Key:${NC}"
    echo -e "     1. Go to: ${BLUE}https://appstoreconnect.apple.com/access/integrations/api${NC}"
    echo -e "     2. Click '${BOLD}Generate API Key${NC}'"
    echo -e "     3. Name it 'Fastlane' and give it '${BOLD}App Manager${NC}' or '${BOLD}Developer${NC}' access"
    echo -e "     4. Download the .p8 file"
    echo -e "     5. Note the '${BOLD}Key ID${NC}' and '${BOLD}Issuer ID${NC}' shown on the page"
    echo -e "     6. Create directory and move the key file:"
    echo -e "        ${CYAN}mkdir -p ~/.appstoreconnect/private_keys${NC}"
    echo -e "        ${CYAN}mv ~/Downloads/AuthKey_XXXXXX.p8 ~/.appstoreconnect/private_keys/${NC}"
    echo -e "     7. Update ${CYAN}fastlane/Fastfile${NC} with your Key ID and Issuer ID"
    echo -e "     8. Update ${CYAN}fastlane/Appfile${NC} with your Team ID"
    echo ""
    WARNINGS=$((WARNINGS + 1))
fi

# Check if Fastfile has placeholder values (only check non-comment lines)
if grep -v "^#" fastlane/Fastfile 2>/dev/null | grep -q "YOUR_KEY_ID"; then
    echo -e "${YELLOW}  ⚠️  fastlane/Fastfile still has placeholder values!${NC}"
    echo -e "     Update YOUR_KEY_ID and YOUR_ISSUER_ID with your actual values"
    WARNINGS=$((WARNINGS + 1))
fi

if grep -v "^#" fastlane/Appfile 2>/dev/null | grep -q "YOUR_TEAM_ID"; then
    echo -e "${YELLOW}  ⚠️  fastlane/Appfile still has placeholder Team ID!${NC}"
    echo -e "     Find your Team ID at: https://developer.apple.com/account → Membership"
    WARNINGS=$((WARNINGS + 1))
fi

echo ""

# ─────────────────────────────────────────
# Check Android Credentials
# ─────────────────────────────────────────
echo -e "${CYAN}🤖 Checking Android Credentials (Play Store Service Account)...${NC}"
echo ""

PLAY_STORE_JSON="$HOME/.play-store/play-store-credentials.json"

if [ -f "$PLAY_STORE_JSON" ]; then
    echo -e "${GREEN}  ✅ Play Store service account JSON found${NC}"
    echo -e "${GREEN}     → $PLAY_STORE_JSON${NC}"
else
    echo -e "${YELLOW}  ⚠️  Play Store service account JSON not found!${NC}"
    echo ""
    echo -e "${MAGENTA}  📝 How to set up Google Play Service Account:${NC}"
    echo -e "     1. Go to: ${BLUE}https://play.google.com/console${NC}"
    echo -e "     2. Navigate to: ${BOLD}Setup → API access${NC}"
    echo -e "     3. Click '${BOLD}Create new service account${NC}'"
    echo -e "     4. Follow the link to Google Cloud Console"
    echo -e "     5. Create a service account with a JSON key"
    echo -e "     6. Download the JSON key file"
    echo -e "     7. Place it at the expected location:"
    echo -e "        ${CYAN}mkdir -p ~/.play-store${NC}"
    echo -e "        ${CYAN}mv ~/Downloads/your-service-account.json ~/.play-store/play-store-credentials.json${NC}"
    echo -e "     8. Back in Play Console, grant the service account these permissions:"
    echo -e "        - ${BOLD}Release to production${NC}"
    echo -e "        - ${BOLD}Manage testing tracks and edit tester lists${NC}"
    echo ""
    WARNINGS=$((WARNINGS + 1))
fi

echo ""

# ─────────────────────────────────────────
# Check Web Deployment (Netlify)
# ─────────────────────────────────────────
echo -e "${CYAN}🌐 Checking Web Deployment (Netlify)...${NC}"
echo ""

if command -v netlify &> /dev/null; then
    echo -e "${GREEN}  ✅ Netlify CLI found${NC}"
else
    echo -e "${YELLOW}  ⚠️  Netlify CLI not found${NC}"
    echo -e "     Install: ${CYAN}npm install -g netlify-cli${NC}"
    echo -e "     Then login: ${CYAN}netlify login${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

if [ -f "netlify.toml" ]; then
    echo -e "${GREEN}  ✅ netlify.toml found${NC}"
else
    echo -e "${YELLOW}  ⚠️  netlify.toml not found${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

echo ""

# ─────────────────────────────────────────
# Make scripts executable
# ─────────────────────────────────────────
echo -e "${CYAN}🔧 Making scripts executable...${NC}"
chmod +x build_ios_release.sh 2>/dev/null || true
chmod +x build_android_release.sh 2>/dev/null || true
chmod +x build_web_release.sh 2>/dev/null || true
chmod +x setup_auto_upload.sh 2>/dev/null || true
echo -e "${GREEN}  ✅ Scripts are now executable${NC}"

echo ""

# ─────────────────────────────────────────
# Summary
# ─────────────────────────────────────────
echo -e "${BLUE}============================================================${NC}"
echo -e "${BLUE}📋 Setup Summary${NC}"
echo -e "${BLUE}============================================================${NC}"
echo ""

if [ $ERRORS -gt 0 ]; then
    echo -e "${RED}  ❌ ${ERRORS} error(s) found - fix these before continuing${NC}"
fi

if [ $WARNINGS -gt 0 ]; then
    echo -e "${YELLOW}  ⚠️  ${WARNINGS} warning(s) - configure credentials before uploading${NC}"
fi

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}  ✅ Everything is set up! You're ready to auto-upload!${NC}"
fi

echo ""
echo -e "${CYAN}📋 Quick Reference:${NC}"
echo ""
echo -e "  ${BOLD}Build & Upload iOS to TestFlight:${NC}"
echo -e "    ${CYAN}./build_ios_release.sh${NC}"
echo ""
echo -e "  ${BOLD}Build & Upload Android to Play Store:${NC}"
echo -e "    ${CYAN}./build_android_release.sh${NC}"
echo ""
echo -e "  ${BOLD}Build & Deploy Web to Netlify:${NC}"
echo -e "    ${CYAN}./build_web_release.sh${NC}"
echo ""
echo -e "  ${BOLD}Or use Fastlane directly:${NC}"
echo -e "    ${CYAN}cd fastlane && bundle exec fastlane ios upload_app${NC}"
echo -e "    ${CYAN}cd android && bundle exec fastlane upload_app${NC}"
echo ""
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}🎉 Setup complete! Happy releasing! 🚀${NC}"
echo -e "${GREEN}============================================================${NC}"
