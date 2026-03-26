#!/bin/bash

echo "🚀 Building Playmaker USER App..."
echo "=================================="
echo ""

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Clean
echo -e "${BLUE}🧹 Cleaning...${NC}"
flutter clean
flutter pub get

# iOS
echo ""
echo -e "${BLUE}🍎 Building iOS (User App)...${NC}"
flutter build ios --release
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ iOS build complete!${NC}"
    echo ""
    echo -e "${YELLOW}📝 NEXT STEPS FOR iOS:${NC}"
    echo "1. Open: ios/Runner.xcworkspace in Xcode"
    echo "2. Verify Bundle ID: com.playmakercairo.app"
    echo "3. Select 'Any iOS Device (arm64)'"
    echo "4. Product → Archive"
    echo "5. Window → Organizer → Distribute App"
else
    echo -e "❌ iOS build failed!"
fi

# Android
echo ""
echo -e "${BLUE}🤖 Building Android (User App)...${NC}"
flutter build appbundle --release --flavor user
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Android build complete!${NC}"
    echo ""
    echo -e "${YELLOW}📦 AAB Location:${NC}"
    echo "build/app/outputs/bundle/userRelease/app-user-release.aab"
    echo ""
    echo -e "${YELLOW}📝 NEXT STEPS FOR ANDROID:${NC}"
    echo "1. Go to: https://play.google.com/console"
    echo "2. Select 'Playmaker' app"
    echo "3. Production → Create new release"
    echo "4. Upload: app-user-release.aab"
    echo "5. Add release notes and submit"
else
    echo -e "❌ Android build failed!"
fi

echo ""
echo -e "${GREEN}🎉 User app builds complete!${NC}"
echo ""
echo -e "${YELLOW}📊 Version Info:${NC}"
echo "  Version: 1.0.6"
echo "  Build: 10"
echo "  Package: com.playmakercairo.app"
echo ""

