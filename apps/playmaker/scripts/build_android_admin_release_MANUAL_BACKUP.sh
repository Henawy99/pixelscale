#!/bin/bash

echo "🚀 Building Android ADMIN App (Internal)..."
echo "==========================================="
echo ""

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Admin app version (separate tracking)
CURRENT_VERSION="1.0.9"
CURRENT_BUILD="14"

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

# Generate icons
echo -e "${BLUE}🎨 Generating app icons...${NC}"
flutter pub run flutter_launcher_icons:main -f flutter_launcher_icons_admin.yaml

# Clean
echo -e "${BLUE}🧹 Cleaning...${NC}"
flutter clean
flutter pub get

# Build Android with admin entry point
echo ""
echo -e "${BLUE}🤖 Building Android AAB...${NC}"
flutter build appbundle --release --flavor admin -t lib/main_admin.dart --build-name=$NEW_VERSION --build-number=$NEW_BUILD

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅ Android Admin build complete!${NC}"
    echo ""
    
    # Update this script with new version for next time
    sed -i '' "s/CURRENT_VERSION=\".*\"/CURRENT_VERSION=\"$NEW_VERSION\"/" "$0"
    sed -i '' "s/CURRENT_BUILD=\".*\"/CURRENT_BUILD=\"$NEW_BUILD\"/" "$0"
    
    echo -e "${YELLOW}📦 AAB Location:${NC}"
    echo "   build/app/outputs/bundle/adminRelease/app-admin-release.aab"
    echo ""
    echo -e "${YELLOW}📝 NEXT STEPS:${NC}"
    echo "   Admin app is internal only - distribute via Firebase App Distribution"
    echo "   or share APK directly with admin users."
    echo ""
    echo -e "${GREEN}📊 Version Info:${NC}"
    echo "   Old Version: $CURRENT_VERSION (Build $CURRENT_BUILD)"
    echo "   New Version: $NEW_VERSION (Build $NEW_BUILD)"
    echo "   Package: com.playmaker.admin"
    echo ""
else
    echo -e "${RED}❌ Android Admin build failed!${NC}"
fi

echo ""

