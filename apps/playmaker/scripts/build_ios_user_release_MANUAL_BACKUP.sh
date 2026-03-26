#!/bin/bash

echo "🚀 Building iOS USER App for App Store..."
echo "=========================================="
echo ""

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Read current version from pubspec.yaml
CURRENT_VERSION=$(grep "version:" pubspec.yaml | sed 's/version: //' | sed 's/ .*//' | sed 's/+.*//')
CURRENT_BUILD=$(grep "version:" pubspec.yaml | sed 's/.*+//' | sed 's/ .*//')

# Split version into parts (e.g., 1.0.10 -> major=1, minor=0, patch=10)
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"

# Increment patch version
NEW_PATCH=$((PATCH + 1))
NEW_VERSION="$MAJOR.$MINOR.$NEW_PATCH"

# Reset build number to 1 for new version
NEW_BUILD=1

NEW_VERSION_STRING="$NEW_VERSION+$NEW_BUILD"

echo -e "${CYAN}📊 Current Version: $CURRENT_VERSION (Build $CURRENT_BUILD)${NC}"
echo -e "${GREEN}📊 New Version:     $NEW_VERSION (Build $NEW_BUILD)${NC}"
echo ""

# Update pubspec.yaml
sed -i '' "s/version: .*/version: $NEW_VERSION_STRING  # USER APP - Update this manually if needed/" pubspec.yaml

echo -e "${BLUE}✅ Version updated in pubspec.yaml${NC}"
echo ""

# Step 1: Set Bundle ID to com.playmaker.start
echo -e "${BLUE}📦 Setting Bundle ID to: com.playmaker.start${NC}"
sed -i '' 's/PRODUCT_BUNDLE_IDENTIFIER = com\.playmaker\.[^;]*;/PRODUCT_BUNDLE_IDENTIFIER = com.playmaker.start;/g' ios/Runner.xcodeproj/project.pbxproj
sed -i '' 's/PRODUCT_BUNDLE_IDENTIFIER = com\.example\.[^;]*;/PRODUCT_BUNDLE_IDENTIFIER = com.playmaker.start;/g' ios/Runner.xcodeproj/project.pbxproj

# Step 2: Set Display Name to "Playmaker"
echo -e "${BLUE}📱 Setting Display Name to: Playmaker${NC}"
sed -i '' 's/<string>PM Partners<\/string>/<string>Playmaker<\/string>/g' ios/Runner/Info.plist
sed -i '' 's/<string>PM Admin<\/string>/<string>Playmaker<\/string>/g' ios/Runner/Info.plist
sed -i '' 's/<string>Playmaker Admin<\/string>/<string>Playmaker<\/string>/g' ios/Runner/Info.plist
sed -i '' 's/<string>Playmaker Field Owner<\/string>/<string>Playmaker<\/string>/g' ios/Runner/Info.plist
sed -i '' 's/<string>PM Partner<\/string>/<string>Playmaker<\/string>/g' ios/Runner/Info.plist
sed -i '' 's/<string>Playmaker Partner<\/string>/<string>Playmaker<\/string>/g' ios/Runner/Info.plist

# Step 3: Generate icons
echo -e "${BLUE}🎨 Generating app icons...${NC}"
flutter pub run flutter_launcher_icons:main -f flutter_launcher_icons_user.yaml

# Step 4: Clean
echo -e "${BLUE}🧹 Cleaning...${NC}"
flutter clean
flutter pub get

# Step 5: Build iOS
echo ""
echo -e "${BLUE}🍎 Building iOS...${NC}"
flutter build ios --release

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅ iOS build complete!${NC}"
    echo ""
    echo -e "${YELLOW}📝 NEXT STEPS:${NC}"
    echo "1. Open Xcode:"
    echo -e "   ${BLUE}open ios/Runner.xcworkspace${NC}"
    echo ""
    echo "2. In Xcode:"
    echo "   • Select 'Any iOS Device (arm64)'"
    echo "   • Product → Archive"
    echo "   • Window → Organizer"
    echo "   • Distribute App → App Store Connect"
    echo ""
    echo -e "${GREEN}📊 Version Info:${NC}"
    echo "   Old Version: $CURRENT_VERSION (Build $CURRENT_BUILD)"
    echo "   New Version: $NEW_VERSION (Build $NEW_BUILD)"
    echo "   Bundle ID: com.playmaker.start"
    echo ""
    
    # Auto-open Xcode
    echo -e "${BLUE}🔄 Opening Xcode...${NC}"
    open ios/Runner.xcworkspace
else
    echo -e "${RED}❌ iOS build failed!${NC}"
    echo "Reverting version change..."
    sed -i '' "s/version: .*/version: $CURRENT_VERSION+$CURRENT_BUILD  # USER APP - Update this manually if needed/" pubspec.yaml
fi

echo ""
