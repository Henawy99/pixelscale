#!/bin/bash

# ===========================================
# Restaurant Admin - Run Desktop App (macOS)
# ===========================================
# ⭐ BEST FOR VIDEO UPLOADS - No CORS errors!
# ===========================================

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

cd "$(dirname "$0")"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}🖥️  Restaurant Admin - Desktop App${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${CYAN}✅ Benefits of Desktop:${NC}"
echo "   • No CORS errors (reliable uploads)"
echo "   • Better video handling"
echo "   • Native performance"
echo ""

# Get dependencies
echo -e "${YELLOW}📦 Getting dependencies...${NC}"
flutter pub get

# Run on macOS
echo -e "${GREEN}🖥️  Running on macOS Desktop...${NC}"
flutter run -d macos

echo -e "${GREEN}✅ Done!${NC}"

