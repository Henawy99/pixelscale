#!/bin/bash

# ============================================
# Playmaker Management App - iOS Release Build
# ============================================
# Unified Admin + Partner app
# For TestFlight distribution
#
# Uses the same proven flow as build_ios_user_release.sh:
#   1. Set bundle ID -> com.playmaker.admin
#   2. flutter build ios --release
#   3. bundle exec fastlane ios upload_management (gym archives + uploads)
# ============================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ════════════════════════════════════════════════════════════════════════════════
# VERSION TRACKING FILE - Prevents version regression
# ════════════════════════════════════════════════════════════════════════════════
VERSION_TRACK_FILE=".version_history_management"

# Read current version from pubspec.yaml
CURRENT_VERSION=$(grep "version:" pubspec.yaml | sed 's/version: //' | sed 's/ .*//' | sed 's/+.*//')
CURRENT_BUILD=$(grep "version:" pubspec.yaml | sed 's/.*+//' | sed 's/ .*//')

# Read last known good version from tracking file
if [ -f "$VERSION_TRACK_FILE" ]; then
    LAST_KNOWN_VERSION=$(cat "$VERSION_TRACK_FILE" | head -1)
    IFS='.' read -r LAST_MAJOR LAST_MINOR LAST_PATCH <<< "$LAST_KNOWN_VERSION"
else
    LAST_MAJOR=0
    LAST_MINOR=0
    LAST_PATCH=0
fi

# Split current version
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"

CURRENT_NUMERIC=$((MAJOR * 10000 + MINOR * 100 + PATCH))
LAST_KNOWN_NUMERIC=$((LAST_MAJOR * 10000 + LAST_MINOR * 100 + LAST_PATCH))

if [ "$LAST_KNOWN_NUMERIC" -gt "$CURRENT_NUMERIC" ]; then
    MAJOR=$LAST_MAJOR
    MINOR=$LAST_MINOR
    PATCH=$LAST_PATCH
    CURRENT_VERSION="$LAST_KNOWN_VERSION"
fi

NEW_PATCH=$((PATCH + 1))
NEW_VERSION="$MAJOR.$MINOR.$NEW_PATCH"
NEW_BUILD=1
NEW_VERSION_STRING="$NEW_VERSION+$NEW_BUILD"

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  🚀 Building iOS MANAGEMENT App for TestFlight...${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${CYAN}📊 Current Version: $CURRENT_VERSION (Build $CURRENT_BUILD)${NC}"
echo -e "${GREEN}📊 New Version:     $NEW_VERSION (Build $NEW_BUILD)${NC}"
echo ""

# Update pubspec.yaml
sed -i '' "s/version: .*/version: $NEW_VERSION_STRING/" pubspec.yaml

# Save version to tracking file
echo "$NEW_VERSION" > "$VERSION_TRACK_FILE"
echo "# Last successful build version - DO NOT DELETE" >> "$VERSION_TRACK_FILE"

echo -e "${BLUE}✅ Version updated in pubspec.yaml${NC}"
echo ""

# Step 1: Set Bundle ID to com.playmaker.admin
echo -e "${BLUE}📦 Setting Bundle ID to: com.playmaker.admin${NC}"
sed -i '' 's/PRODUCT_BUNDLE_IDENTIFIER = com\.playmaker\.[^;]*;/PRODUCT_BUNDLE_IDENTIFIER = com.playmaker.admin;/g' ios/Runner.xcodeproj/project.pbxproj
sed -i '' 's/PRODUCT_BUNDLE_IDENTIFIER = com\.example\.[^;]*;/PRODUCT_BUNDLE_IDENTIFIER = com.playmaker.admin;/g' ios/Runner.xcodeproj/project.pbxproj
echo -e "${GREEN}✅ Bundle ID set to com.playmaker.admin${NC}"

# Step 2: Set Display Name to "PM Management"
echo -e "${BLUE}📱 Setting Display Name to: PM Management${NC}"
sed -i '' 's/<string>Playmaker<\/string>/<string>PM Management<\/string>/g' ios/Runner/Info.plist
sed -i '' 's/<string>PM Admin<\/string>/<string>PM Management<\/string>/g' ios/Runner/Info.plist
sed -i '' 's/<string>Playmaker Admin<\/string>/<string>PM Management<\/string>/g' ios/Runner/Info.plist
sed -i '' 's/<string>Playmaker Partner<\/string>/<string>PM Management<\/string>/g' ios/Runner/Info.plist

# Step 3: Swap Firebase config for MANAGEMENT app
echo -e "${BLUE}🔥 Setting Firebase config for Management app...${NC}"
if [ -f "ios/Runner/GoogleService-Info-Admin.plist" ]; then
    cp ios/Runner/GoogleService-Info-Admin.plist ios/Runner/GoogleService-Info.plist
    echo -e "${GREEN}✅ Using GoogleService-Info-Admin.plist${NC}"
elif [ -f "ios/Runner/GoogleService-Info-Management.plist" ]; then
    cp ios/Runner/GoogleService-Info-Management.plist ios/Runner/GoogleService-Info.plist
    echo -e "${GREEN}✅ Using GoogleService-Info-Management.plist${NC}"
else
    echo -e "${YELLOW}⚠️  No admin/management GoogleService plist found. Using default.${NC}"
fi

# Step 4: Generate icons
echo -e "${BLUE}🎨 Generating app icons...${NC}"
flutter pub run flutter_launcher_icons:main -f flutter_launcher_icons_admin.yaml 2>/dev/null || true

# Step 5: Clean
echo -e "${BLUE}🧹 Cleaning...${NC}"
flutter clean
flutter pub get

# Step 6: Build iOS
echo ""
echo -e "${BLUE}🍎 Building iOS (Management App)...${NC}"
flutter build ios --release -t lib/main_management.dart

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅ iOS build complete!${NC}"
    echo ""
    echo -e "${GREEN}📊 Version Info:${NC}"
    echo "   Old Version: $CURRENT_VERSION (Build $CURRENT_BUILD)"
    echo "   New Version: $NEW_VERSION (Build $NEW_BUILD)"
    echo "   Bundle ID: com.playmaker.admin"
    echo "   Target: Playmaker Admin app in App Store Connect"
    echo ""

    # Check if Fastlane is configured for auto-upload
    # The API key is in Fastfile (not Appfile), so check for the .p8 key file + team_id in Appfile
    FASTLANE_CONFIGURED=false
    if command -v bundle &> /dev/null && [ -f "fastlane/Fastfile" ]; then
        API_KEY_FILE="$HOME/.appstoreconnect/private_keys/AuthKey_2GTNSM4DX2.p8"
        if [ -f "$API_KEY_FILE" ] && grep -q "team_id" fastlane/Appfile 2>/dev/null; then
            FASTLANE_CONFIGURED=true
        fi
    fi

    if [ "$FASTLANE_CONFIGURED" = true ]; then
        echo -e "${BLUE}🚀 Auto-uploading to TestFlight via Fastlane...${NC}"
        echo ""

        # Run Fastlane upload (no archive_path — gym does full archive+export with cloud signing)
        bundle exec fastlane ios upload_management
        UPLOAD_STATUS=$?

        if [ $UPLOAD_STATUS -eq 0 ]; then
            echo ""
            echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${GREEN}║  ✅ UPLOAD COMPLETE!                                          ║${NC}"
            echo -e "${GREEN}║                                                               ║${NC}"
            echo -e "${GREEN}║  Your app is now processing on App Store Connect.            ║${NC}"
            echo -e "${GREEN}║  Check TestFlight in 5-10 minutes.                           ║${NC}"
            echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
        else
            echo ""
            echo -e "${YELLOW}⚠️  Auto-upload failed. Falling back to manual upload...${NC}"
            echo ""
            open ios/Runner.xcworkspace
        fi
    else
        echo -e "${YELLOW}💡 Auto-upload not configured. Opening Xcode for manual upload...${NC}"
        echo ""
        echo -e "${YELLOW}📋 Next Steps in Xcode:${NC}"
        echo "   1. Select 'Runner' target"
        echo "   2. Verify Bundle ID is: com.playmaker.admin"
        echo "   3. Product → Archive"
        echo "   4. Distribute App → App Store Connect"
        echo ""
        echo -e "${CYAN}ℹ️  This will update the Playmaker Admin app in App Store Connect${NC}"
        echo ""

        open ios/Runner.xcworkspace
    fi
else
    echo -e "${RED}❌ iOS build failed!${NC}"
    echo "Reverting version change..."
    sed -i '' "s/version: .*/version: $CURRENT_VERSION+$CURRENT_BUILD/" pubspec.yaml
fi

echo ""
echo -e "${GREEN}🎉 Done!${NC}"
