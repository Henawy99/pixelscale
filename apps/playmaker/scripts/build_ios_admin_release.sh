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
CURRENT_VERSION="1.0.38"
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

# Step 2.5: Swap Firebase Config for ADMIN app
echo -e "${BLUE}🔥 Setting Firebase config for ADMIN app...${NC}"
if [ -f "ios/Runner/GoogleService-Info-Admin.plist" ]; then
    cp ios/Runner/GoogleService-Info-Admin.plist ios/Runner/GoogleService-Info.plist
    echo -e "${GREEN}✅ Using GoogleService-Info-Admin.plist${NC}"
else
    echo -e "${YELLOW}⚠️  GoogleService-Info-Admin.plist not found. Using default.${NC}"
    echo -e "${YELLOW}💡 Create this file to enable push notifications for ADMIN app.${NC}"
fi

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
    
    echo -e "${GREEN}📊 Version Info:${NC}"
    echo "   Old Version: $CURRENT_VERSION (Build $CURRENT_BUILD)"
    echo "   New Version: $NEW_VERSION (Build $NEW_BUILD)"
    echo "   Bundle ID: com.playmaker.admin"
    echo ""
    
    # Check if Fastlane is configured for auto-upload
    FASTLANE_CONFIGURED=false
    if command -v bundle &> /dev/null && [ -f "fastlane/Fastfile" ]; then
        if [ -f "fastlane/Appfile" ] && ! grep -q "YOUR_KEY_ID\|YOUR_ISSUER_ID\|YOUR_TEAM_ID" fastlane/Appfile 2>/dev/null; then
            if grep -q "app_store_connect_api_key\|team_id" fastlane/Appfile 2>/dev/null; then
                FASTLANE_CONFIGURED=true
            fi
        fi
    fi
    
    if [ "$FASTLANE_CONFIGURED" = true ]; then
        echo -e "${BLUE}🚀 Auto-uploading to TestFlight via Fastlane...${NC}"
        echo ""
        
        bundle exec fastlane ios upload_management
        UPLOAD_STATUS=$?
        
        if [ $UPLOAD_STATUS -eq 0 ]; then
            echo ""
            echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${GREEN}║  ✅ UPLOAD COMPLETE!                                          ║${NC}"
            echo -e "${GREEN}║  Check TestFlight in 5-10 minutes.                           ║${NC}"
            echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
        else
            echo -e "${YELLOW}⚠️  Auto-upload failed. Falling back to manual upload...${NC}"
            open ios/Runner.xcworkspace
        fi
    else
        echo -e "${YELLOW}💡 Auto-upload not configured. Run ./setup_auto_upload.sh to enable.${NC}"
        echo ""
        echo -e "${BLUE}📦 Opening Xcode Organizer for upload to TestFlight...${NC}"
        echo ""
        echo -e "${YELLOW}Next steps in Xcode:${NC}"
        echo "   1. Window → Organizer (or press ⌘⇧O)"
        echo "   2. Select 'Playmaker Admin' archive"
        echo "   3. Click 'Distribute App'"
        echo "   4. Choose 'App Store Connect' → Upload"
        echo "   5. Done! Check TestFlight in 5-10 minutes"
        echo ""
        
        open ios/Runner.xcworkspace
        sleep 2
        osascript -e 'tell application "Xcode" to activate' 2>/dev/null
        osascript -e 'tell application "System Events" to keystroke "o" using {command down, shift down}' 2>/dev/null
    fi
    
    echo ""
    echo -e "${CYAN}💡 TIP: Consider using ./build_ios_management_release.sh instead.${NC}"
    echo -e "${CYAN}   The Management app combines Admin + Partner into one app!${NC}"
else
    echo -e "${RED}❌ iOS Admin build failed!${NC}"
fi

echo ""

