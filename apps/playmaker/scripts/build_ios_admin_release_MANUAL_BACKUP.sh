#!/bin/bash

echo "🚀 Building iOS ADMIN App for App Store..."
echo "==========================================="
echo ""

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Admin app version (separate from main pubspec)
CURRENT_VERSION="1.0.12"
CURRENT_BUILD="1"

# Split version into parts
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"

# Increment patch version
NEW_PATCH=$((PATCH + 1))
NEW_VERSION="$MAJOR.$MINOR.$NEW_PATCH"

# Reset build number to 1 for new version
NEW_BUILD=1

echo -e "${CYAN}📊 Current Version: $CURRENT_VERSION (Build $CURRENT_BUILD)${NC}"
echo -e "${GREEN}📊 New Version:     $NEW_VERSION (Build $NEW_BUILD)${NC}"
echo ""

# Step 1: Set Bundle ID to com.playmaker.admin
echo -e "${BLUE}📦 Setting Bundle ID to: com.playmaker.admin${NC}"
sed -i '' 's/PRODUCT_BUNDLE_IDENTIFIER = com\.playmaker\.[^;]*;/PRODUCT_BUNDLE_IDENTIFIER = com.playmaker.admin;/g' ios/Runner.xcodeproj/project.pbxproj
sed -i '' 's/PRODUCT_BUNDLE_IDENTIFIER = com\.example\.[^;]*;/PRODUCT_BUNDLE_IDENTIFIER = com.playmaker.admin;/g' ios/Runner.xcodeproj/project.pbxproj

# Step 2: Set Display Name to "Playmaker Admin"
echo -e "${BLUE}📱 Setting Display Name to: Playmaker Admin${NC}"
sed -i '' 's/<string>Playmaker<\/string>/<string>Playmaker Admin<\/string>/g' ios/Runner/Info.plist
sed -i '' 's/<string>PM Admin<\/string>/<string>Playmaker Admin<\/string>/g' ios/Runner/Info.plist
sed -i '' 's/<string>PM Partners<\/string>/<string>Playmaker Admin<\/string>/g' ios/Runner/Info.plist
sed -i '' 's/<string>Playmaker Field Owner<\/string>/<string>Playmaker Admin<\/string>/g' ios/Runner/Info.plist
sed -i '' 's/<string>PM Partner<\/string>/<string>Playmaker Admin<\/string>/g' ios/Runner/Info.plist
sed -i '' 's/<string>Playmaker Partner<\/string>/<string>Playmaker Admin<\/string>/g' ios/Runner/Info.plist

# Step 3: Generate icons
echo -e "${BLUE}🎨 Generating app icons...${NC}"
flutter pub run flutter_launcher_icons:main -f flutter_launcher_icons_admin.yaml

# Step 4: Clean
echo -e "${BLUE}🧹 Cleaning...${NC}"
flutter clean
flutter pub get

# Step 5: Build iOS with admin entry point
echo ""
echo -e "${BLUE}🍎 Building iOS Admin App...${NC}"
flutter build ios --release -t lib/main_admin.dart --build-name=$NEW_VERSION --build-number=$NEW_BUILD

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅ iOS Admin build complete!${NC}"
    echo ""
    
    # Update this script with new version for next time
    sed -i '' "s/CURRENT_VERSION=\".*\"/CURRENT_VERSION=\"$NEW_VERSION\"/" "$0"
    sed -i '' "s/CURRENT_BUILD=\".*\"/CURRENT_BUILD=\"$NEW_BUILD\"/" "$0"
    
    echo -e "${YELLOW}📝 NEXT STEPS:${NC}"
    echo "1. Open Xcode:"
    echo -e "   ${BLUE}open ios/Runner.xcworkspace${NC}"
    echo ""
    echo "2. In Xcode:"
    echo "   • Verify Bundle ID: com.playmaker.admin"
    echo "   • Select 'Any iOS Device (arm64)'"
    echo "   • Product → Archive"
    echo "   • Window → Organizer"
    echo "   • Distribute App → TestFlight (Internal)"
    echo ""
    echo -e "${GREEN}📊 Version Info:${NC}"
    echo "   Old Version: $CURRENT_VERSION (Build $CURRENT_BUILD)"
    echo "   New Version: $NEW_VERSION (Build $NEW_BUILD)"
    echo "   Bundle ID: com.playmaker.admin"
    echo ""
    
    # Auto-open Xcode
    echo -e "${BLUE}🔄 Opening Xcode...${NC}"
    open ios/Runner.xcworkspace
else
    echo -e "${RED}❌ iOS Admin build failed!${NC}"
fi

echo ""

