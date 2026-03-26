#!/bin/bash

# ===========================================
# Restaurant Admin - Run App (Development)
# ===========================================
# NO version increment - just runs for testing
# ===========================================

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

cd "$(dirname "$0")"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}🍔 Restaurant Admin - Development${NC}"
echo -e "${BLUE}========================================${NC}"

# Get dependencies
echo -e "${YELLOW}📦 Getting dependencies...${NC}"
flutter pub get

# Run on iOS device/simulator
echo -e "${GREEN}📱 Running on iOS...${NC}"
flutter run

echo -e "${GREEN}✅ Done!${NC}"

