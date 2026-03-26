#!/bin/bash
# ═══════════════════════════════════════════════════════
# Animight — iOS Release Build → TestFlight
# ═══════════════════════════════════════════════════════
set -e
cd "$(dirname "$0")"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

echo -e "${CYAN}🍎 Animight — iOS Build + TestFlight Upload${NC}"
echo ""

# Ensure Bundler deps are installed
if [ ! -d ".bundle" ] && [ ! -f "Gemfile.lock" ]; then
  echo -e "${YELLOW}Installing Fastlane deps...${NC}"
  bundle install
fi

# Run Fastlane iOS upload lane
if [ "${1}" == "--upload-only" ]; then
  echo -e "${YELLOW}Uploading existing IPA to TestFlight...${NC}"
  cd fastlane && bundle exec fastlane ios upload_only
else
  echo -e "${YELLOW}Building Flutter + archiving + uploading to TestFlight...${NC}"
  cd fastlane && bundle exec fastlane ios upload
fi

echo -e "${GREEN}✅ Done! Check TestFlight in 5–15 min.${NC}"
