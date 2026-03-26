#!/bin/bash

echo "🚀 Building Android PARTNER App for Play Store..."
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

# ALWAYS Increment build number (Do not reset to 1)
# Google Play requires unique version code for every upload
NEW_BUILD=$((CURRENT_BUILD + 1))

NEW_VERSION_STRING="$NEW_VERSION+$NEW_BUILD"

echo -e "${CYAN}📊 Current Version: $CURRENT_VERSION (Build $CURRENT_BUILD)${NC}"
echo -e "${GREEN}📊 New Version:     $NEW_VERSION (Build $NEW_BUILD)${NC}"
echo ""

# Update pubspec.yaml
sed -i '' "s/version: .*/version: $NEW_VERSION_STRING  # PARTNER APP - Update this manually if needed/" pubspec.yaml

echo -e "${BLUE}✅ Version updated in pubspec.yaml${NC}"
echo ""

# Generate icons
echo -e "${BLUE}🎨 Generating app icons (Blue Theme)...${NC}"
flutter pub run flutter_launcher_icons:main -f flutter_launcher_icons_partner.yaml

# Clean
echo -e "${BLUE}🧹 Cleaning...${NC}"
flutter clean
flutter pub get

# Build Android
echo ""
echo -e "${BLUE}🤖 Building Android AAB (Partner Flavor)...${NC}"
flutter build appbundle --release --flavor partner -t lib/main_partner.dart

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅ Android build complete!${NC}"
    echo ""
    echo -e "${YELLOW}📦 AAB Location:${NC}"
    echo "   build/app/outputs/bundle/partnerRelease/app-partner-release.aab"
    echo ""
    echo -e "${GREEN}📊 Version Info:${NC}"
    echo "   Old Version: $CURRENT_VERSION (Build $CURRENT_BUILD)"
    echo "   New Version: $NEW_VERSION (Build $NEW_BUILD)"
    echo "   Package: com.playmakeradmincairo.app"
    echo ""
    
    # Check if Fastlane is installed
    if command -v bundle &> /dev/null && [ -f "android/fastlane/Fastfile" ]; then
        echo -e "${BLUE}🚀 Uploading to Play Console automatically...${NC}"
        echo ""
        
        # Upload to Play Console using Fastlane
        cd android
        bundle exec fastlane upload_partner
        UPLOAD_STATUS=$?
        cd ..
        
        if [ $UPLOAD_STATUS -eq 0 ]; then
            echo ""
            echo -e "${GREEN}✅ Successfully uploaded to Play Console (Internal Testing)!${NC}"
            echo -e "${GREEN}🎉 Partner App is now live in Internal Testing track${NC}"
            echo -e "${BLUE}🌐 View in Play Console: https://play.google.com/console${NC}"
        else
            echo ""
            echo -e "${YELLOW}⚠️  Upload failed. Possible reasons:${NC}"
            echo "   • Certificate reset waiting period (check Play Console)"
            echo "   • Service account permissions issue"
            echo "   • Network connection problem"
            echo ""
            echo -e "${BLUE}💡 Try uploading manually:${NC}"
            echo "   https://play.google.com/console"
        fi
    else
        echo -e "${YELLOW}⚠️  Fastlane not configured. Setting up now...${NC}"
        ./setup_fastlane.sh
        echo ""
        echo -e "${BLUE}💡 Please run the build script again to upload${NC}"
    fi
else
    echo -e "${RED}❌ Android build failed!${NC}"
    echo "Reverting version change..."
    sed -i '' "s/version: .*/version: $CURRENT_VERSION+$CURRENT_BUILD  # PARTNER APP - Reverted/" pubspec.yaml
fi

echo ""
