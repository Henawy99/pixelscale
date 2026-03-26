#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════════
# PLAYMAKER AUTO-UPLOAD SETUP
# Sets up automated uploads to App Store (TestFlight) and Play Store
# ═══════════════════════════════════════════════════════════════════════════════

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color
BOLD='\033[1m'

cd "$(dirname "$0")" || exit 1

echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${GREEN}  🚀 PLAYMAKER AUTO-UPLOAD SETUP${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# PREREQUISITES CHECK
# ═══════════════════════════════════════════════════════════════════════════════

echo -e "${BOLD}📋 Checking Prerequisites...${NC}"
echo ""

# Check Ruby
if command -v ruby &> /dev/null; then
    echo -e "  ${GREEN}✅${NC} Ruby: $(ruby -v | cut -d' ' -f2)"
else
    echo -e "  ${RED}❌${NC} Ruby not found"
    echo -e "     ${YELLOW}Install with: brew install ruby${NC}"
    exit 1
fi

# Check Bundler
if command -v bundle &> /dev/null; then
    echo -e "  ${GREEN}✅${NC} Bundler installed"
else
    echo -e "  ${YELLOW}⚠️${NC}  Bundler not found, installing..."
    gem install bundler
fi

# Install Fastlane
echo -e "  ${BLUE}📦${NC} Installing Fastlane dependencies..."
bundle install --quiet 2>/dev/null

if [ $? -eq 0 ]; then
    echo -e "  ${GREEN}✅${NC} Fastlane installed"
else
    echo -e "  ${RED}❌${NC} Fastlane installation failed"
    exit 1
fi

echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# ANDROID SETUP CHECK
# ═══════════════════════════════════════════════════════════════════════════════

echo -e "${CYAN}───────────────────────────────────────────────────────────────${NC}"
echo -e "${BOLD}🤖 Android Play Store Setup${NC}"
echo -e "${CYAN}───────────────────────────────────────────────────────────────${NC}"
echo ""

ANDROID_JSON="android/playmaker-play-console-service-account.json"

if [ -f "$ANDROID_JSON" ]; then
    echo -e "  ${GREEN}✅${NC} Service account JSON found"
    echo -e "     ${CYAN}$ANDROID_JSON${NC}"
    ANDROID_READY=true
else
    echo -e "  ${RED}❌${NC} Service account JSON NOT found"
    echo ""
    echo -e "  ${YELLOW}To set up Android auto-upload:${NC}"
    echo ""
    echo -e "  ${BOLD}Step 1:${NC} Go to Google Play Console"
    echo -e "         ${BLUE}https://play.google.com/console${NC}"
    echo ""
    echo -e "  ${BOLD}Step 2:${NC} Navigate to Setup > API access"
    echo ""
    echo -e "  ${BOLD}Step 3:${NC} Click 'Create new service account'"
    echo -e "         - Follow link to Google Cloud Console"
    echo -e "         - Name: ${CYAN}playmaker-upload${NC}"
    echo -e "         - Role: ${CYAN}Service Account User${NC}"
    echo -e "         - Create JSON key and download"
    echo ""
    echo -e "  ${BOLD}Step 4:${NC} Back in Play Console, grant access:"
    echo -e "         - App access: Add your apps"
    echo -e "         - Permissions: Release to production, Manage testing"
    echo ""
    echo -e "  ${BOLD}Step 5:${NC} Place the JSON file at:"
    echo -e "         ${CYAN}$ANDROID_JSON${NC}"
    echo ""
    ANDROID_READY=false
fi

echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# iOS SETUP CHECK
# ═══════════════════════════════════════════════════════════════════════════════

echo -e "${CYAN}───────────────────────────────────────────────────────────────${NC}"
echo -e "${BOLD}🍎 iOS App Store Connect Setup${NC}"
echo -e "${CYAN}───────────────────────────────────────────────────────────────${NC}"
echo ""

# Check for API key in common locations
API_KEY_DIR="$HOME/.appstoreconnect/private_keys"
API_KEY_FOUND=false

if [ -d "$API_KEY_DIR" ]; then
    KEY_FILE=$(ls "$API_KEY_DIR"/AuthKey_*.p8 2>/dev/null | head -1)
    if [ -n "$KEY_FILE" ]; then
        echo -e "  ${GREEN}✅${NC} API Key found: $(basename "$KEY_FILE")"
        API_KEY_FOUND=true
        
        # Extract Key ID from filename
        KEY_ID=$(basename "$KEY_FILE" | sed 's/AuthKey_//' | sed 's/.p8//')
        echo -e "     Key ID: ${CYAN}$KEY_ID${NC}"
    fi
fi

# Also check local fastlane directory
if [ -d "fastlane/private_keys" ]; then
    KEY_FILE=$(ls fastlane/private_keys/AuthKey_*.p8 2>/dev/null | head -1)
    if [ -n "$KEY_FILE" ]; then
        echo -e "  ${GREEN}✅${NC} API Key found: $(basename "$KEY_FILE")"
        API_KEY_FOUND=true
    fi
fi

if [ "$API_KEY_FOUND" = false ]; then
    echo -e "  ${RED}❌${NC} App Store Connect API Key NOT found"
    echo ""
    echo -e "  ${YELLOW}To set up iOS auto-upload:${NC}"
    echo ""
    echo -e "  ${BOLD}Step 1:${NC} Go to App Store Connect"
    echo -e "         ${BLUE}https://appstoreconnect.apple.com${NC}"
    echo ""
    echo -e "  ${BOLD}Step 2:${NC} Navigate to Users and Access > Integrations > App Store Connect API"
    echo ""
    echo -e "  ${BOLD}Step 3:${NC} Click 'Generate API Key'"
    echo -e "         - Name: ${CYAN}Playmaker CI${NC}"
    echo -e "         - Access: ${CYAN}App Manager${NC}"
    echo ""
    echo -e "  ${BOLD}Step 4:${NC} Download the .p8 file ${RED}(only one chance!)${NC}"
    echo -e "         Note your ${CYAN}Issuer ID${NC} and ${CYAN}Key ID${NC}"
    echo ""
    echo -e "  ${BOLD}Step 5:${NC} Run these commands:"
    echo -e "         ${CYAN}mkdir -p ~/.appstoreconnect/private_keys${NC}"
    echo -e "         ${CYAN}mv ~/Downloads/AuthKey_XXXXX.p8 ~/.appstoreconnect/private_keys/${NC}"
    echo ""
    echo -e "  ${BOLD}Step 6:${NC} Get your Team ID from Apple Developer Portal:"
    echo -e "         ${BLUE}https://developer.apple.com/account${NC}"
    echo -e "         Look for 'Team ID' in Membership section"
    echo ""
    IOS_READY=false
else
    # Check if Appfile has been configured
    if grep -q "YOUR_KEY_ID\|YOUR_ISSUER_ID\|YOUR_TEAM_ID" fastlane/Appfile 2>/dev/null; then
        echo -e "  ${YELLOW}⚠️${NC}  Appfile needs configuration"
        echo ""
        echo -e "  ${BOLD}Please provide your credentials:${NC}"
        echo ""
        
        # Prompt for credentials
        read -p "  Enter your Key ID (from App Store Connect): " INPUT_KEY_ID
        read -p "  Enter your Issuer ID (from App Store Connect): " INPUT_ISSUER_ID
        read -p "  Enter your Team ID (from Apple Developer Portal): " INPUT_TEAM_ID
        
        if [ -n "$INPUT_KEY_ID" ] && [ -n "$INPUT_ISSUER_ID" ] && [ -n "$INPUT_TEAM_ID" ]; then
            # Find the actual key file
            ACTUAL_KEY_FILE=$(ls "$API_KEY_DIR"/AuthKey_*.p8 2>/dev/null | head -1)
            if [ -z "$ACTUAL_KEY_FILE" ]; then
                ACTUAL_KEY_FILE=$(ls fastlane/private_keys/AuthKey_*.p8 2>/dev/null | head -1)
            fi
            
            echo ""
            echo -e "  ${BLUE}Updating Appfile...${NC}"
            
            # Update Appfile with provided values
            cat > fastlane/Appfile << EOF
# Playmaker - App Store Connect Configuration
# Auto-generated by setup_auto_upload.sh

# App Store Connect API Key
app_store_connect_api_key(
  key_id: "$INPUT_KEY_ID",
  issuer_id: "$INPUT_ISSUER_ID",
  key_filepath: "$ACTUAL_KEY_FILE",
  in_house: false
)

# Apple Developer Team
team_id("$INPUT_TEAM_ID")
itc_team_id("$INPUT_TEAM_ID")

# Bundle IDs (specified in each lane)
# USER: com.playmaker.start
# MANAGEMENT: com.playmaker.admin  
# PROMO: com.playmaker.promo
EOF
            echo -e "  ${GREEN}✅${NC} Appfile configured!"
            IOS_READY=true
        else
            echo -e "  ${RED}❌${NC} Missing credentials. Please run setup again."
            IOS_READY=false
        fi
    else
        echo -e "  ${GREEN}✅${NC} Appfile configured"
        IOS_READY=true
    fi
fi

echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# SUMMARY
# ═══════════════════════════════════════════════════════════════════════════════

echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}📊 Setup Summary${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""

if [ "$ANDROID_READY" = true ]; then
    echo -e "  ${GREEN}✅${NC} Android Play Store:  ${GREEN}Ready${NC}"
else
    echo -e "  ${RED}❌${NC} Android Play Store:  ${YELLOW}Needs service account JSON${NC}"
fi

if [ "$IOS_READY" = true ]; then
    echo -e "  ${GREEN}✅${NC} iOS App Store:       ${GREEN}Ready${NC}"
else
    echo -e "  ${RED}❌${NC} iOS App Store:       ${YELLOW}Needs API key setup${NC}"
fi

echo ""

if [ "$ANDROID_READY" = true ] && [ "$IOS_READY" = true ]; then
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}  ${BOLD}🎉 AUTO-UPLOAD IS READY!${NC}                                    ${GREEN}║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${BOLD}Usage:${NC}"
    echo ""
    echo -e "  ${CYAN}./build_ios_user_release.sh${NC}"
    echo -e "     → Builds iOS + uploads to TestFlight automatically"
    echo ""
    echo -e "  ${CYAN}./build_android_user_release.sh${NC}"
    echo -e "     → Builds Android + uploads to Play Console automatically"
    echo ""
    echo -e "  ${CYAN}./pm build${NC}"
    echo -e "     → Interactive menu with auto-upload"
    echo ""
else
    echo -e "${YELLOW}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║${NC}  ${BOLD}⚠️  SETUP INCOMPLETE${NC}                                        ${YELLOW}║${NC}"
    echo -e "${YELLOW}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  Please follow the instructions above to complete setup."
    echo -e "  Then run ${CYAN}./setup_auto_upload.sh${NC} again."
    echo ""
fi

echo -e "${CYAN}───────────────────────────────────────────────────────────────${NC}"
echo -e "  📚 Full documentation: ${BLUE}AUTO_UPLOAD_GUIDE.md${NC}"
echo -e "${CYAN}───────────────────────────────────────────────────────────────${NC}"
echo ""
