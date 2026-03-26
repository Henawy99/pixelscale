#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  🔍 ADMIN App Setup Verification${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check 1: Active Firebase Config Bundle ID
echo -e "${YELLOW}1️⃣  Checking Active Firebase Config...${NC}"
ACTIVE_BUNDLE_ID=$(grep -A1 "BUNDLE_ID" ios/Runner/GoogleService-Info.plist | tail -1 | sed 's/.*<string>\(.*\)<\/string>.*/\1/')
if [ "$ACTIVE_BUNDLE_ID" == "com.playmaker.admin" ]; then
    echo -e "${GREEN}   ✅ Correct: $ACTIVE_BUNDLE_ID${NC}"
else
    echo -e "${RED}   ❌ Wrong: $ACTIVE_BUNDLE_ID${NC}"
    echo -e "${YELLOW}   💡 Fix: cp ios/Runner/GoogleService-Info-Admin.plist ios/Runner/GoogleService-Info.plist${NC}"
fi
echo ""

# Check 2: Firebase Project ID
echo -e "${YELLOW}2️⃣  Checking Firebase Project ID...${NC}"
PROJECT_ID=$(grep -A1 "PROJECT_ID" ios/Runner/GoogleService-Info.plist | tail -1 | sed 's/.*<string>\(.*\)<\/string>.*/\1/')
if [ "$PROJECT_ID" == "playmaker-4af3d" ]; then
    echo -e "${GREEN}   ✅ Correct: $PROJECT_ID${NC}"
else
    echo -e "${RED}   ❌ Wrong: $PROJECT_ID${NC}"
fi
echo ""

# Check 3: All Firebase Configs Exist
echo -e "${YELLOW}3️⃣  Checking All Firebase Configs...${NC}"
if [ -f "ios/Runner/GoogleService-Info-User.plist" ]; then
    echo -e "${GREEN}   ✅ USER config exists${NC}"
else
    echo -e "${RED}   ❌ USER config missing${NC}"
fi
if [ -f "ios/Runner/GoogleService-Info-Admin.plist" ]; then
    echo -e "${GREEN}   ✅ ADMIN config exists${NC}"
else
    echo -e "${RED}   ❌ ADMIN config missing${NC}"
fi
if [ -f "ios/Runner/GoogleService-Info-Partner.plist" ]; then
    echo -e "${GREEN}   ✅ PARTNER config exists${NC}"
else
    echo -e "${RED}   ❌ PARTNER config missing${NC}"
fi
echo ""

# Check 4: Xcode Bundle ID
echo -e "${YELLOW}4️⃣  Checking Xcode Bundle Identifier...${NC}"
XCODE_BUNDLE_ID=$(grep "PRODUCT_BUNDLE_IDENTIFIER" ios/Runner.xcodeproj/project.pbxproj | head -1 | sed 's/.*= \(.*\);/\1/')
if [ "$XCODE_BUNDLE_ID" == "com.playmaker.admin" ]; then
    echo -e "${GREEN}   ✅ Correct: $XCODE_BUNDLE_ID${NC}"
else
    echo -e "${RED}   ❌ Wrong: $XCODE_BUNDLE_ID${NC}"
    echo -e "${YELLOW}   💡 Fix: Run ./build_ios_admin_release.sh (it will auto-fix)${NC}"
fi
echo ""

# Check 5: Display Name
echo -e "${YELLOW}5️⃣  Checking Display Name...${NC}"
DISPLAY_NAME=$(grep -A1 "CFBundleDisplayName" ios/Runner/Info.plist | tail -1 | sed 's/.*<string>\(.*\)<\/string>.*/\1/')
if [ "$DISPLAY_NAME" == "Playmaker Admin" ]; then
    echo -e "${GREEN}   ✅ Correct: $DISPLAY_NAME${NC}"
else
    echo -e "${RED}   ❌ Wrong: $DISPLAY_NAME${NC}"
    echo -e "${YELLOW}   💡 Fix: Run ./build_ios_admin_release.sh (it will auto-fix)${NC}"
fi
echo ""

# Check 6: Admin Login Screen Exists
echo -e "${YELLOW}6️⃣  Checking Admin Login Screen...${NC}"
if [ -f "lib/screens/admin/admin_login_screen.dart" ]; then
    echo -e "${GREEN}   ✅ Admin login screen exists${NC}"
else
    echo -e "${RED}   ❌ Admin login screen missing${NC}"
fi
echo ""

# Summary
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  📊 VERIFICATION SUMMARY${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Count checks
TOTAL_CHECKS=6
PASSED_CHECKS=0

if [ "$ACTIVE_BUNDLE_ID" == "com.playmaker.admin" ]; then ((PASSED_CHECKS++)); fi
if [ "$PROJECT_ID" == "playmaker-4af3d" ]; then ((PASSED_CHECKS++)); fi
if [ -f "ios/Runner/GoogleService-Info-User.plist" ] && [ -f "ios/Runner/GoogleService-Info-Admin.plist" ] && [ -f "ios/Runner/GoogleService-Info-Partner.plist" ]; then ((PASSED_CHECKS++)); fi
if [ "$XCODE_BUNDLE_ID" == "com.playmaker.admin" ]; then ((PASSED_CHECKS++)); fi
if [ "$DISPLAY_NAME" == "Playmaker Admin" ]; then ((PASSED_CHECKS++)); fi
if [ -f "lib/screens/admin/admin_login_screen.dart" ]; then ((PASSED_CHECKS++)); fi

if [ $PASSED_CHECKS -eq $TOTAL_CHECKS ]; then
    echo -e "${GREEN}✅ All checks passed! ($PASSED_CHECKS/$TOTAL_CHECKS)${NC}"
    echo ""
    echo -e "${GREEN}🎉 Your ADMIN app is correctly configured!${NC}"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo -e "  1. Build: ${YELLOW}./build_ios_admin_release.sh${NC}"
    echo -e "  2. Upload to TestFlight via Xcode Organizer"
    echo -e "  3. Install on real iPhone"
    echo -e "  4. Check Push Debug screen"
else
    echo -e "${RED}❌ Some checks failed ($PASSED_CHECKS/$TOTAL_CHECKS passed)${NC}"
    echo ""
    echo -e "${YELLOW}💡 Quick fixes:${NC}"
    if [ "$ACTIVE_BUNDLE_ID" != "com.playmaker.admin" ]; then
        echo -e "  ${YELLOW}• cp ios/Runner/GoogleService-Info-Admin.plist ios/Runner/GoogleService-Info.plist${NC}"
    fi
    if [ "$XCODE_BUNDLE_ID" != "com.playmaker.admin" ] || [ "$DISPLAY_NAME" != "Playmaker Admin" ]; then
        echo -e "  ${YELLOW}• ./build_ios_admin_release.sh${NC}"
    fi
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

