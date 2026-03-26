#!/bin/bash

# ===========================================
# Restaurant Admin - Run Web App (Chrome)
# ===========================================

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

cd "$(dirname "$0")"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}🌐 Restaurant Admin - Web App${NC}"
echo -e "${BLUE}========================================${NC}"

# Get dependencies
echo -e "${YELLOW}📦 Getting dependencies...${NC}"
flutter pub get

# Run on Chrome
echo -e "${GREEN}🌐 Running on Chrome...${NC}"
flutter run -d chrome

echo -e "${GREEN}✅ Done!${NC}"

