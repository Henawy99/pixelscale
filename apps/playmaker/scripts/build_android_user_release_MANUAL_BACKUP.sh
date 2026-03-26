#!/bin/bash

echo "🚀 Building Android USER App for Play Store..."
echo "==============================================="
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

# Split version into parts
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

# Generate icons
echo -e "${BLUE}🎨 Generating app icons...${NC}"
flutter pub run flutter_launcher_icons:main -f flutter_launcher_icons_user.yaml

# Clean
echo -e "${BLUE}🧹 Cleaning...${NC}"
flutter clean
flutter pub get

# Build Android
echo ""
echo -e "${BLUE}🤖 Building Android AAB...${NC}"
flutter build appbundle --release --flavor user

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅ Android build complete!${NC}"
    echo ""
    echo -e "${YELLOW}📦 AAB Location:${NC}"
    echo "   build/app/outputs/bundle/userRelease/app-user-release.aab"
    echo ""
    echo -e "${YELLOW}📝 NEXT STEPS:${NC}"
    echo "1. Go to: https://play.google.com/console"
    echo "2. Select 'Playmaker' app"
    echo "3. Production → Create new release"
    echo "4. Upload AAB file from location above"
    echo "5. Add release notes and submit"
    echo ""
    echo -e "${GREEN}📊 Version Info:${NC}"
    echo "   Old Version: $CURRENT_VERSION (Build $CURRENT_BUILD)"
    echo "   New Version: $NEW_VERSION (Build $NEW_BUILD)"
    echo "   Package: com.playmaker.app"
    echo ""
else
    echo -e "${RED}❌ Android build failed!${NC}"
    echo "Reverting version change..."
    sed -i '' "s/version: .*/version: $CURRENT_VERSION+$CURRENT_BUILD  # USER APP - Update this manually if needed/" pubspec.yaml
fi

echo ""

