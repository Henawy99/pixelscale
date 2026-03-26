#!/bin/bash

# ==========================================
# Build iOS ADMIN App for App Store
# ==========================================
# This script prepares the admin app for App Store submission:
# 1. Generates admin icons
# 2. Updates Bundle ID to com.playmaker.admin
# 3. Sets display name to "Playmaker Admin"
# 4. Builds release version
# 5. Opens Xcode for archiving
# ==========================================

set -e  # Exit on error

echo "🚀 Building iOS ADMIN App for App Store..."
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
BUNDLE_ID="com.playmaker.admin"
DISPLAY_NAME="Playmaker Admin"
VERSION="1.0.3"
BUILD_NUMBER="4"
ENTRY_POINT="lib/main_admin.dart"

echo "${BLUE}📋 Configuration:${NC}"
echo "   Bundle ID: $BUNDLE_ID"
echo "   Display Name: $DISPLAY_NAME"
echo "   Version: $VERSION"
echo "   Build: $BUILD_NUMBER"
echo ""

# Step 1: Clean previous builds
echo "${BLUE}🧹 Step 1/6: Cleaning previous builds...${NC}"
flutter clean
flutter pub get
echo "${GREEN}✅ Clean complete${NC}"
echo ""

# Step 2: Generate admin icons
echo "${BLUE}🎨 Step 2/6: Generating admin app icons...${NC}"
flutter pub run flutter_launcher_icons:main -f flutter_launcher_icons_admin.yaml
echo "${GREEN}✅ Icons generated${NC}"
echo ""

# Step 3: Update Info.plist
echo "${BLUE}📝 Step 3/6: Updating Info.plist...${NC}"
INFO_PLIST="ios/Runner/Info.plist"

# Backup original
cp "$INFO_PLIST" "$INFO_PLIST.backup"

# Update display name
plutil -replace CFBundleDisplayName -string "$DISPLAY_NAME" "$INFO_PLIST"
plutil -replace CFBundleName -string "$DISPLAY_NAME" "$INFO_PLIST"

echo "${GREEN}✅ Info.plist updated${NC}"
echo ""

# Step 4: Update Bundle ID in project.pbxproj
echo "${BLUE}📝 Step 4/6: Updating Bundle ID...${NC}"
PBXPROJ="ios/Runner.xcodeproj/project.pbxproj"

# Backup original
cp "$PBXPROJ" "$PBXPROJ.backup"

# Replace bundle identifier (from all possible current values)
sed -i '' "s/PRODUCT_BUNDLE_IDENTIFIER = com\.playmaker\.start/PRODUCT_BUNDLE_IDENTIFIER = $BUNDLE_ID/g" "$PBXPROJ"
sed -i '' "s/PRODUCT_BUNDLE_IDENTIFIER = com\.playmaker\.app/PRODUCT_BUNDLE_IDENTIFIER = $BUNDLE_ID/g" "$PBXPROJ"
sed -i '' "s/PRODUCT_BUNDLE_IDENTIFIER = com\.example\.playmaker/PRODUCT_BUNDLE_IDENTIFIER = $BUNDLE_ID/g" "$PBXPROJ"

echo "${GREEN}✅ Bundle ID updated to: $BUNDLE_ID${NC}"
echo ""

# Step 5: Build iOS release
echo "${BLUE}🔨 Step 5/6: Building iOS release...${NC}"
flutter build ios --release -t "$ENTRY_POINT" --build-name="$VERSION" --build-number="$BUILD_NUMBER"
echo "${GREEN}✅ Build complete${NC}"
echo ""

# Step 6: Open Xcode for archiving
echo "${BLUE}📱 Step 6/6: Opening Xcode...${NC}"
open ios/Runner.xcworkspace
echo ""

# Instructions
echo "${GREEN}✅ BUILD READY FOR APP STORE!${NC}"
echo ""
echo "${YELLOW}📋 NEXT STEPS IN XCODE:${NC}"
echo ""
echo "1️⃣  ${BLUE}Select 'Any iOS Device (arm64)'${NC} in the device dropdown"
echo ""
echo "2️⃣  ${BLUE}Menu: Product → Archive${NC}"
echo "    (or press ${YELLOW}⌘+Shift+B${NC})"
echo ""
echo "3️⃣  ${BLUE}Wait for archive to complete${NC} (~5-10 minutes)"
echo ""
echo "4️⃣  ${BLUE}In Organizer window:${NC}"
echo "    • Click '${YELLOW}Distribute App${NC}'"
echo "    • Choose '${YELLOW}App Store Connect${NC}'"
echo "    • Follow the wizard"
echo ""
echo "5️⃣  ${BLUE}Upload to App Store Connect${NC}"
echo "    • Wait for processing (~10-30 minutes)"
echo "    • Submit for review"
echo ""
echo "${YELLOW}⚠️  IMPORTANT VERIFICATIONS:${NC}"
echo "    • Bundle ID: ${GREEN}$BUNDLE_ID${NC}"
echo "    • Display Name: ${GREEN}$DISPLAY_NAME${NC}"
echo "    • Version: ${GREEN}$VERSION${NC}"
echo "    • Build: ${GREEN}$BUILD_NUMBER${NC}"
echo ""
echo "${YELLOW}📱 Test Account for App Review:${NC}"
echo "    Email: ${GREEN}youssef@gmail.com${NC}"
echo "    Password: ${YELLOW}[Provide in App Store Connect review notes]${NC}"
echo ""
echo "${BLUE}🔄 To restore original Bundle ID after archiving:${NC}"
echo "    Run: ${YELLOW}./restore_user_bundle_id.sh${NC}"
echo ""
echo "${GREEN}Good luck! 🚀${NC}"

