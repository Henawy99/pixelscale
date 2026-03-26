#!/bin/bash
# ═══════════════════════════════════════════════════════
# Playmaker — Android Release Build → Play Console
# ═══════════════════════════════════════════════════════
set -e
cd "$(dirname "$0")"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

echo -e "${CYAN}🤖 Playmaker — Android Build + Play Console Upload${NC}"
echo ""

# Ensure Bundler deps in android/
if [ ! -f "android/Gemfile.lock" ]; then
  echo -e "${YELLOW}Installing Fastlane deps (android/)...${NC}"
  cd android && bundle install && cd ..
fi

case "${1}" in
  --build-only)
    echo -e "${YELLOW}Building AAB only...${NC}"
    cd android && bundle exec fastlane build
    ;;
  --upload-only)
    echo -e "${YELLOW}Uploading existing AAB to Play Console...${NC}"
    cd android && bundle exec fastlane upload_only
    ;;
  *)
    echo -e "${YELLOW}Building AAB + uploading to Play Console...${NC}"
    cd android && bundle exec fastlane upload
    ;;
esac

echo -e "${GREEN}✅ Done! Check Google Play Console.${NC}"
