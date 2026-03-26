#!/bin/bash
# ═══════════════════════════════════════════════════════
# Playmaker — iOS Release Build → TestFlight
# ═══════════════════════════════════════════════════════
set -e
cd "$(dirname "$0")"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; RED='\033[0;31m'; NC='\033[0m'

echo -e "${CYAN}🍎 Playmaker — iOS Build + TestFlight Upload${NC}"
echo ""

# Ensure Bundler deps
if [ ! -f "Gemfile.lock" ]; then
  echo -e "${YELLOW}Installing Fastlane deps...${NC}"
  bundle install
fi

echo -e "${YELLOW}Select which app to upload:${NC}"
echo "  1) User App     (com.playmaker.start)"
echo "  2) Management   (com.playmaker.admin)"
echo "  3) Both"
echo ""
read -p "Choice [1-3]: " choice

case $choice in
  1)
    echo -e "${GREEN}▶ Uploading USER app to TestFlight...${NC}"
    cd fastlane && bundle exec fastlane ios upload_user
    ;;
  2)
    echo -e "${GREEN}▶ Uploading MANAGEMENT app to TestFlight...${NC}"
    cd fastlane && bundle exec fastlane ios upload_management
    ;;
  3)
    echo -e "${GREEN}▶ Uploading USER app to TestFlight...${NC}"
    cd fastlane && bundle exec fastlane ios upload_user
    cd ..
    echo -e "${GREEN}▶ Uploading MANAGEMENT app to TestFlight...${NC}"
    cd fastlane && bundle exec fastlane ios upload_management
    ;;
  *)
    echo -e "${RED}Invalid choice. Defaulting to USER app.${NC}"
    cd fastlane && bundle exec fastlane ios upload_user
    ;;
esac

echo -e "${GREEN}✅ Done! Check TestFlight in 5–15 min.${NC}"
