#!/bin/bash
# ============================================
# Tennis Academy App — Flutter Dev Runner
# ============================================
set -e
cd "$(dirname "$0")"

GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'

echo -e "${CYAN}🎾 Tennis Academy App — Flutter${NC}"
echo ""

case "${1:-}" in
  android)
    echo -e "${GREEN}Running on Android...${NC}"
    flutter run -d android
    ;;
  ios)
    echo -e "${GREEN}Running on iOS...${NC}"
    flutter run -d iPhone
    ;;
  web)
    echo -e "${GREEN}Running on Chrome...${NC}"
    flutter run -d chrome
    ;;
  *)
    echo -e "${GREEN}Running on connected device...${NC}"
    flutter run
    ;;
esac
