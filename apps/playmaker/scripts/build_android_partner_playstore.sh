#!/bin/bash
# ==========================================
# Build PARTNER App for Google Play Store (Android)
# ==========================================
set -e

echo "🤖 Building Android PARTNER App for Google Play Store..."
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# ==========================================
# Step 1: Verify keystore exists
# ==========================================
if [ ! -f "android/app/playmaker-release-key.keystore" ]; then
    echo "${RED}❌ Error: Keystore file not found!${NC}"
    echo ""
    echo "You need to create a signing keystore first."
    echo "Run: ${BLUE}./setup_android_signing.sh${NC}"
    echo ""
    echo "See: ${BLUE}ANDROID_SIGNING_SETUP.md${NC} for detailed instructions"
    exit 1
fi

if [ ! -f "android/key.properties" ]; then
    echo "${RED}❌ Error: key.properties file not found!${NC}"
    echo ""
    echo "You need to create key.properties first."
    echo "Run: ${BLUE}./setup_android_signing.sh${NC}"
    exit 1
fi

echo "${GREEN}✅ Signing configuration found${NC}"
echo ""

# ==========================================
# Step 2: Clean previous builds
# ==========================================
echo "${BLUE}🧹 Cleaning previous builds...${NC}"
flutter clean
flutter pub get
echo "${GREEN}✅ Clean complete${NC}"
echo ""

# ==========================================
# Step 3: Generate Android icons
# ==========================================
echo "${BLUE}🎨 Generating PARTNER app icons...${NC}"
flutter pub run flutter_launcher_icons:main -f flutter_launcher_icons_partner.yaml
echo "${GREEN}✅ Icons generated${NC}"
echo ""

# ==========================================
# Step 4: Build App Bundle (AAB)
# ==========================================
echo "${BLUE}📦 Building Android App Bundle (AAB) for PARTNER app...${NC}"
echo ""
echo "Flavor: ${YELLOW}partner${NC}"
echo "Application ID: ${YELLOW}com.playmakercairo.partner${NC}"
echo "Version: ${YELLOW}1.0.1 (2)${NC}"
echo ""

flutter build appbundle --release --flavor partner -t lib/main_partner.dart

if [ $? -eq 0 ]; then
    echo ""
    echo "${GREEN}🎉 SUCCESS! Android App Bundle built successfully!${NC}"
    echo ""
    echo "📦 AAB Location:"
    echo "   ${GREEN}build/app/outputs/bundle/partnerRelease/app-partner-release.aab${NC}"
    echo ""
    echo "📊 File Size:"
    ls -lh build/app/outputs/bundle/partnerRelease/app-partner-release.aab | awk '{print "   " $5}'
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "${GREEN}✅ Ready for Google Play Console Upload!${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Next steps:"
    echo "  1. Go to: ${BLUE}https://play.google.com/console${NC}"
    echo "  2. Select your app: ${YELLOW}Playmaker Field Owner${NC}"
    echo "  3. Go to: ${YELLOW}Production → Create new release${NC}"
    echo "  4. Upload: ${GREEN}app-partner-release.aab${NC}"
    echo "  5. Fill in release notes"
    echo "  6. Submit for review"
    echo ""
    echo "📖 For detailed guide, see: ${BLUE}ANDROID_PLAYSTORE_GUIDE.md${NC}"
else
    echo ""
    echo "${RED}❌ Build failed!${NC}"
    echo ""
    echo "Common issues:"
    echo "  • Check keystore password in key.properties"
    echo "  • Ensure all dependencies are installed"
    echo "  • Check build.gradle configuration"
    exit 1
fi

