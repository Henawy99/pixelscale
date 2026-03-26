#!/bin/bash
# ============================================
# PixelScale - Setup Publishing Pipeline
# One-time setup for App Store + Play Console
# ============================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo ""
echo -e "${GREEN}${BOLD}╔══════════════════════════════════════╗${NC}"
echo -e "${GREEN}${BOLD}║   PixelScale Publishing Setup        ║${NC}"
echo -e "${GREEN}${BOLD}╚══════════════════════════════════════╝${NC}"
echo ""

echo -e "${CYAN}This script helps you configure automated uploads to:${NC}"
echo "  - Apple App Store (TestFlight)"
echo "  - Google Play Console (Internal Testing)"
echo ""

# --- EAS Setup (for React Native / Expo apps) ---
echo -e "${YELLOW}${BOLD}1. Expo Application Services (EAS)${NC}"
echo "   For React Native (Expo) apps"
echo ""

if command -v eas &> /dev/null || npx eas-cli --version &> /dev/null 2>&1; then
  echo "   EAS CLI: installed"
else
  echo "   EAS CLI: not installed"
  echo "   Installing..."
  npm install -g eas-cli
fi

echo ""
echo "   To configure EAS for a new app:"
echo "     cd apps/<your-app>"
echo "     eas login"
echo "     eas build:configure"
echo "     eas credentials"
echo ""

# --- Fastlane Setup (for Flutter apps) ---
echo -e "${YELLOW}${BOLD}2. Fastlane (for Flutter apps)${NC}"
echo ""

if command -v fastlane &> /dev/null; then
  echo "   Fastlane: installed ($(fastlane --version 2>/dev/null | head -1))"
else
  echo "   Fastlane: not installed"
  echo "   Install with: brew install fastlane"
fi

echo ""
echo "   To configure Fastlane for a Flutter app:"
echo "     cd apps/<your-app>/ios"
echo "     fastlane init"
echo "     # Choose 'Automate beta distribution to TestFlight'"
echo ""
echo "     cd apps/<your-app>/android"
echo "     fastlane init"
echo "     # Add your Play Console service account JSON"
echo ""

# --- Google Play Service Account ---
echo -e "${YELLOW}${BOLD}3. Google Play Console Service Account${NC}"
echo ""
echo "   For automated Android uploads, you need a service account:"
echo "   1. Go to Play Console > Settings > Developer account > API access"
echo "   2. Create a service account or link existing one"
echo "   3. Download the JSON key file"
echo "   4. Place it at: shared/play-store-key.json"
echo "   5. Add to .gitignore (already done)"
echo ""

# --- Apple App Store Connect API Key ---
echo -e "${YELLOW}${BOLD}4. Apple App Store Connect API Key${NC}"
echo ""
echo "   For automated iOS uploads via Fastlane/EAS:"
echo "   1. Go to App Store Connect > Users & Access > Keys"
echo "   2. Create a new API key (Admin role)"
echo "   3. Download the .p8 key file"
echo "   4. Note the Key ID and Issuer ID"
echo "   5. For EAS: eas credentials"
echo "   6. For Fastlane: set FASTLANE_APPLE_ID and ASC_KEY_ID"
echo ""

# --- Global Aliases ---
echo -e "${YELLOW}${BOLD}5. Setting up global aliases...${NC}"
echo ""

SHELL_RC="$HOME/.zshrc"
ALIAS_BLOCK="# PixelScale Project Manager
alias pm='$(cd "$(dirname "$0")/.." && pwd)/pm'
alias pmrun='$(cd "$(dirname "$0")/.." && pwd)/pm run'
alias pmbuild='$(cd "$(dirname "$0")/.." && pwd)/pm build'
alias pmbuildall='$(cd "$(dirname "$0")/.." && pwd)/pm build-all'"

if grep -q "PixelScale Project Manager" "$SHELL_RC" 2>/dev/null; then
  echo "   Aliases already configured in $SHELL_RC"
else
  echo "" >> "$SHELL_RC"
  echo "$ALIAS_BLOCK" >> "$SHELL_RC"
  echo "   Added aliases to $SHELL_RC"
  echo "   Run: source ~/.zshrc"
fi

echo ""
echo -e "${GREEN}${BOLD}Setup complete!${NC}"
echo ""
echo "  Quick commands available:"
echo "    pm         - Interactive project manager"
echo "    pmrun      - Quick run an app"
echo "    pmbuild    - Quick build an app"
echo "    pmbuildall - Build all apps"
echo ""
echo "  After sourcing your shell: source ~/.zshrc"
echo ""
