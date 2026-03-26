#!/bin/bash

# ==========================================
# Build iOS PARTNER App for App Store
# ==========================================
# This script prepares the partner app for App Store submission:
# 1. Generates partner icons (blue)
# 2. Updates Bundle ID to com.example.playmakeradmin (for existing app)
# 3. Sets display name to "Playmaker Field Owner"
# 4. Builds release version
# 5. Opens Xcode for archiving
# ==========================================

set -e  # Exit on error

echo "🚀 Building iOS PARTNER App for App Store..."
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
BUNDLE_ID="com.example.playmakeradmin"  # OLD Bundle ID for existing app
# BUNDLE_ID="com.playmaker.partner"     # NEW Bundle ID (commented out)
DISPLAY_NAME="Playmaker Field Owner"
VERSION="1.0.2"
BUILD_NUMBER="3"
ENTRY_POINT="lib/main_partner.dart"

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

# Step 2: Generate partner icons (blue)
echo "${BLUE}🎨 Step 2/6: Generating partner app icons (blue)...${NC}"
flutter pub run flutter_launcher_icons:main -f flutter_launcher_icons_partner.yaml
echo "${GREEN}✅ Icons generated${NC}"
echo ""

# Step 3: Update Info.plist
echo "${BLUE}📝 Step 3/6: Updating Info.plist...${NC}"
INFO_PLIST="ios/Runner/Info.plist"

# Backup original
cp "$INFO_PLIST" "$INFO_PLIST.backup"

# Update CFBundleDisplayName
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $DISPLAY_NAME" "$INFO_PLIST"
# Update CFBundleName
plutil -replace CFBundleName -string "$DISPLAY_NAME" "$INFO_PLIST"

echo "${GREEN}✅ Info.plist updated${NC}"
echo ""

# Step 4: Update Bundle ID and Version in project.pbxproj
echo "${BLUE}📝 Step 4/6: Updating Bundle ID and Version...${NC}"
PBXPROJ="ios/Runner.xcodeproj/project.pbxproj"

# Backup original
cp "$PBXPROJ" "$PBXPROJ.backup"

# Replace bundle identifier (from all possible current values)
sed -i '' "s/PRODUCT_BUNDLE_IDENTIFIER = com\.playmaker\.start/PRODUCT_BUNDLE_IDENTIFIER = $BUNDLE_ID/g" "$PBXPROJ"
sed -i '' "s/PRODUCT_BUNDLE_IDENTIFIER = com\.playmaker\.app/PRODUCT_BUNDLE_IDENTIFIER = $BUNDLE_ID/g" "$PBXPROJ"
sed -i '' "s/PRODUCT_BUNDLE_IDENTIFIER = com\.playmaker\.admin/PRODUCT_BUNDLE_IDENTIFIER = $BUNDLE_ID/g" "$PBXPROJ"
sed -i '' "s/PRODUCT_BUNDLE_IDENTIFIER = com\.playmaker\.partner/PRODUCT_BUNDLE_IDENTIFIER = $BUNDLE_ID/g" "$PBXPROJ"

# Update version and build number
sed -i '' "s/MARKETING_VERSION = [^;]*;/MARKETING_VERSION = $VERSION;/g" "$PBXPROJ"
sed -i '' "s/CURRENT_PROJECT_VERSION = [^;]*;/CURRENT_PROJECT_VERSION = $BUILD_NUMBER;/g" "$PBXPROJ"

echo "${GREEN}✅ Bundle ID updated to: $BUNDLE_ID${NC}"
echo "${GREEN}✅ Version updated to: $VERSION ($BUILD_NUMBER)${NC}"
echo ""

# Step 5: Build iOS release
echo "${BLUE}🔨 Step 5/6: Building iOS release...${NC}"
flutter build ios --release -t "$ENTRY_POINT" --build-name="$VERSION" --build-number="$BUILD_NUMBER"
echo "${GREEN}✅ Build complete${NC}"
echo ""

# Step 6: Open Xcode
echo "${BLUE}🚀 Step 6/6: Opening Xcode workspace...${NC}"
open ios/Runner.xcworkspace

echo ""
echo "${GREEN}════════════════════════════════════════════════════════${NC}"
echo "${GREEN}✅ PARTNER App Ready for App Store!${NC}"
echo "${GREEN}════════════════════════════════════════════════════════${NC}"
echo ""
echo "${YELLOW}📋 Next Steps in Xcode:${NC}"
echo "   1. Select device: ${YELLOW}'Any iOS Device (arm64)'${NC}"
echo "   2. Go to: ${YELLOW}Product → Archive${NC}"
echo "   3. Once archived, click ${YELLOW}'Distribute App'${NC}"
echo "   4. Choose: ${YELLOW}'App Store Connect'${NC}"
echo "   5. Upload to App Store"
echo ""
echo "${YELLOW}⚠️  IMPORTANT:${NC}"
echo "   • Verify Bundle ID is: ${YELLOW}$BUNDLE_ID${NC}"
echo "   • Verify Display Name is: ${YELLOW}$DISPLAY_NAME${NC}"
echo "   • Verify Version is: ${YELLOW}$VERSION ($BUILD_NUMBER)${NC}"
echo ""
echo "${BLUE}📱 App Details:${NC}"
echo "   Bundle ID: $BUNDLE_ID"
echo "   App Name: $DISPLAY_NAME"
echo "   Version: $VERSION"
echo "   Build: $BUILD_NUMBER"
echo "   Theme: Blue (#2563EB)"
echo ""
echo "${GREEN}🎉 Good luck with your submission!${NC}"
echo ""

