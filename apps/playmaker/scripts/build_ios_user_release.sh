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

# ════════════════════════════════════════════════════════════════════════════════
# VERSION TRACKING FILE - Prevents version regression
# ════════════════════════════════════════════════════════════════════════════════
VERSION_TRACK_FILE=".version_history_user"

# Read current version from pubspec.yaml
CURRENT_VERSION=$(grep "version:" pubspec.yaml | sed 's/version: //' | sed 's/ .*//' | sed 's/+.*//')
CURRENT_BUILD=$(grep "version:" pubspec.yaml | sed 's/.*+//' | sed 's/ .*//')

# Read last known good version from tracking file
if [ -f "$VERSION_TRACK_FILE" ]; then
    LAST_KNOWN_VERSION=$(cat "$VERSION_TRACK_FILE" | head -1)
    IFS='.' read -r LAST_MAJOR LAST_MINOR LAST_PATCH <<< "$LAST_KNOWN_VERSION"
else
    # Initialize with current pubspec version if no tracking file exists
    LAST_MAJOR=0
    LAST_MINOR=0
    LAST_PATCH=0
fi

# Split current version into parts
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"

# ════════════════════════════════════════════════════════════════════════════════
# VERSION REGRESSION PROTECTION
# ════════════════════════════════════════════════════════════════════════════════
# Compare versions: use the HIGHER of pubspec.yaml or version tracking file
CURRENT_NUMERIC=$((MAJOR * 10000 + MINOR * 100 + PATCH))
LAST_KNOWN_NUMERIC=$((LAST_MAJOR * 10000 + LAST_MINOR * 100 + LAST_PATCH))

if [ "$LAST_KNOWN_NUMERIC" -gt "$CURRENT_NUMERIC" ]; then
    echo -e "${RED}⚠️  VERSION REGRESSION DETECTED!${NC}"
    echo -e "${RED}   pubspec.yaml has:    $CURRENT_VERSION${NC}"
    echo -e "${RED}   Last known version:  $LAST_KNOWN_VERSION${NC}"
    echo -e "${YELLOW}   Using last known version to prevent regression.${NC}"
    echo ""
    MAJOR=$LAST_MAJOR
    MINOR=$LAST_MINOR
    PATCH=$LAST_PATCH
    CURRENT_VERSION="$LAST_KNOWN_VERSION"
fi

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
sed -i '' "s/version: .*/version: $NEW_VERSION_STRING  # USER APP - DO NOT manually change! Use build scripts./" pubspec.yaml

# Save new version to tracking file (prevents future regressions)
echo "$NEW_VERSION" > "$VERSION_TRACK_FILE"
echo "# Last successful build version - DO NOT DELETE" >> "$VERSION_TRACK_FILE"
echo "# This file prevents version regression in builds" >> "$VERSION_TRACK_FILE"

echo -e "${BLUE}✅ Version updated in pubspec.yaml${NC}"
echo -e "${BLUE}✅ Version saved to $VERSION_TRACK_FILE (regression protection)${NC}"
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

# Step 2.5: Swap Firebase Config for USER app
echo -e "${BLUE}🔥 Setting Firebase config for USER app...${NC}"
if [ -f "ios/Runner/GoogleService-Info-User.plist" ]; then
    cp ios/Runner/GoogleService-Info-User.plist ios/Runner/GoogleService-Info.plist
    echo -e "${GREEN}✅ Using GoogleService-Info-User.plist${NC}"
else
    echo -e "${YELLOW}⚠️  GoogleService-Info-User.plist not found. Using default.${NC}"
    echo -e "${YELLOW}💡 Rename your current plist to GoogleService-Info-User.plist${NC}"
fi

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
    echo -e "${GREEN}📊 Version Info:${NC}"
    echo "   Old Version: $CURRENT_VERSION (Build $CURRENT_BUILD)"
    echo "   New Version: $NEW_VERSION (Build $NEW_BUILD)"
    echo "   Bundle ID: com.playmaker.start"
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
        
        # Run Fastlane upload
        bundle exec fastlane ios upload_user
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
            echo -e "${YELLOW}Next steps in Xcode:${NC}"
            echo "   1. Window → Organizer (or press ⌘⇧O)"
            echo "   2. Select 'Playmaker' archive"
            echo "   3. Click 'Distribute App'"
            echo "   4. Choose 'App Store Connect' → Upload"
            echo ""
            open ios/Runner.xcworkspace
        fi
    else
        echo -e "${YELLOW}💡 Auto-upload not configured. Opening Xcode for manual upload...${NC}"
        echo -e "${CYAN}   Run ./setup_auto_upload.sh to enable auto-upload${NC}"
        echo ""
        echo -e "${YELLOW}Next steps in Xcode:${NC}"
        echo "   1. Window → Organizer (or press ⌘⇧O)"
        echo "   2. Select 'Playmaker' archive"
        echo "   3. Click 'Distribute App'"
        echo "   4. Choose 'App Store Connect' → Upload"
        echo "   5. Done! Check TestFlight in 5-10 minutes"
        echo ""
        
        # Open Xcode with the workspace
        open ios/Runner.xcworkspace
        
        # Give Xcode a moment to open, then open Organizer
        sleep 2
        osascript -e 'tell application "Xcode" to activate' 2>/dev/null
        osascript -e 'tell application "System Events" to keystroke "o" using {command down, shift down}' 2>/dev/null
    fi
else
    echo -e "${RED}❌ iOS build failed!${NC}"
    echo "Reverting version change..."
    sed -i '' "s/version: .*/version: $CURRENT_VERSION+$CURRENT_BUILD  # USER APP - Update this manually if needed/" pubspec.yaml
fi

echo ""
