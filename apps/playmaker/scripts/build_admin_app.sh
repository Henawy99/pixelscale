#!/bin/bash

echo "🚀 Building Playmaker ADMIN App..."
echo "===================================="
echo ""

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Clean
echo -e "${BLUE}🧹 Cleaning...${NC}"
flutter clean
flutter pub get

# iOS
echo ""
echo -e "${BLUE}🍎 Building iOS (Admin App)...${NC}"
flutter build ios --release -t lib/main_admin.dart
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ iOS build complete!${NC}"
    echo ""
    echo -e "${YELLOW}📝 NEXT STEPS FOR iOS:${NC}"
    echo "1. Open: ios/Runner.xcworkspace in Xcode"
    echo -e "${RED}2. IMPORTANT: Change Bundle ID to: com.playmakercairo.admin${NC}"
    echo -e "${RED}3. IMPORTANT: Change Display Name to: Playmaker Admin${NC}"
    echo "4. Select admin app icon set (if you've created one)"
    echo "5. Select 'Any iOS Device (arm64)'"
    echo "6. Product → Archive"
    echo "7. Window → Organizer → Distribute App"
    echo ""
    echo -e "${RED}⚠️  REMINDER: You must register Bundle ID 'com.playmakercairo.admin' in Apple Developer Portal first!${NC}"
else
    echo -e "❌ iOS build failed!"
fi

# Android
echo ""
echo -e "${BLUE}🤖 Building Android (Admin App)...${NC}"
flutter build appbundle --release --flavor admin -t lib/main_admin.dart
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Android build complete!${NC}"
    echo ""
    echo -e "${YELLOW}📦 AAB Location:${NC}"
    echo "build/app/outputs/bundle/adminRelease/app-admin-release.aab"
    echo ""
    echo -e "${YELLOW}📝 NEXT STEPS FOR ANDROID:${NC}"
    echo "1. Go to: https://play.google.com/console"
    echo "2. Create NEW app or select 'Playmaker Admin'"
    echo "3. Production → Create new release"
    echo "4. Upload: app-admin-release.aab"
    echo "5. Add release notes:"
    echo "   - Clearly state this is for administrators"
    echo "   - Provide admin test account credentials"
    echo "6. Submit for review"
else
    echo -e "❌ Android build failed!"
fi

echo ""
echo -e "${GREEN}🎉 Admin app builds complete!${NC}"
echo ""
echo -e "${YELLOW}📊 Version Info:${NC}"
echo "  Version: 1.0.0 (First Release)"
echo "  Build: 1"
echo "  Package: com.playmakercairo.admin"
echo ""
echo -e "${YELLOW}⚠️  Important Notes:${NC}"
echo "  - Admin app requires admin email login (youssef@gmail.com)"
echo "  - Provide test account credentials in review notes"
echo "  - Consider making it 'Unlisted' on app stores"
echo ""

