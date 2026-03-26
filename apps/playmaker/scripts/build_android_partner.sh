#!/bin/bash
# ==========================================
# Build PARTNER App for Android (Google Play)
# ==========================================
set -e

echo "🤖 Building PARTNER App for Android (Playmaker Field Owner)..."
echo ""

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Step 1: Clean previous builds
echo "${BLUE}🧹 Cleaning previous builds...${NC}"
flutter clean
flutter pub get
echo "${GREEN}✅ Clean complete${NC}"
echo ""

# Step 2: Generate app icons for PARTNER app
echo "${BLUE}🎨 Generating PARTNER app icons...${NC}"
flutter pub run flutter_launcher_icons:main -f flutter_launcher_icons_partner.yaml
echo "${GREEN}✅ Icons generated${NC}"
echo ""

# Step 3: Generate splash screen for PARTNER app
echo "${BLUE}💦 Generating PARTNER splash screen...${NC}"
dart run flutter_native_splash:create --path=flutter_native_splash_partner.yaml 2>&1 | grep -v "Warning" || true
echo "${GREEN}✅ Splash screen generated${NC}"
echo ""

# Step 4: Check for signing key
if [ ! -f "android/key.properties" ]; then
    echo "${RED}❌ ERROR: Signing key not found!${NC}"
    echo ""
    echo "You need to create a signing key first."
    echo "Please run: ${YELLOW}./setup_android_signing.sh${NC}"
    echo ""
    echo "Or follow the guide: ${YELLOW}ANDROID_SIGNING_SETUP.md${NC}"
    exit 1
fi

echo "${GREEN}✅ Signing key found${NC}"
echo ""

# Step 5: Build APK (for testing)
echo "${BLUE}📦 Building APK (for testing)...${NC}"
flutter build apk --release --flavor partner -t lib/main_partner.dart
echo "${GREEN}✅ APK built successfully!${NC}"
echo ""

# Step 6: Build App Bundle (for Google Play)
echo "${BLUE}📦 Building App Bundle (for Google Play)...${NC}"
flutter build appbundle --release --flavor partner -t lib/main_partner.dart
echo "${GREEN}✅ App Bundle built successfully!${NC}"
echo ""

echo "${GREEN}🎉 PARTNER App Android build complete!${NC}"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "${BLUE}📱 App Details:${NC}"
echo "   Name: PM Partner"
echo "   Bundle ID: com.playmakercairo.partner"
echo "   Version: 1.0.2 (3)"
echo ""
echo "${BLUE}📦 Build Outputs:${NC}"
echo "   APK (Testing):     ${YELLOW}build/app/outputs/flutter-apk/app-partner-release.apk${NC}"
echo "   Bundle (Play):     ${YELLOW}build/app/outputs/bundle/partnerRelease/app-partner-release.aab${NC}"
echo ""
echo "${BLUE}📤 Next Steps:${NC}"
echo "   1. Test APK on device:   adb install build/app/outputs/flutter-apk/app-partner-release.apk"
echo "   2. Upload to Google Play: Go to https://play.google.com/console"
echo "   3. Upload the .aab file from: build/app/outputs/bundle/partnerRelease/"
echo ""
echo "📖 Full guide: ${YELLOW}PUBLISH_PARTNER_APP_ANDROID.md${NC}"
echo ""
