#!/bin/bash

echo "🚀 Setting up Fastlane for Playmaker Apps..."
echo "=============================================="
echo ""

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Check if Ruby is installed
if ! command -v ruby &> /dev/null; then
    echo -e "${RED}❌ Ruby not found!${NC}"
    echo "Install Ruby with: brew install ruby"
    exit 1
fi

echo -e "${GREEN}✅ Ruby found: $(ruby -v)${NC}"
echo ""

# Check if Bundler is installed
if ! command -v bundle &> /dev/null; then
    echo -e "${YELLOW}📦 Installing Bundler...${NC}"
    gem install bundler
fi

echo -e "${GREEN}✅ Bundler found${NC}"
echo ""

# Install Fastlane and dependencies
echo -e "${BLUE}📦 Installing Fastlane...${NC}"
bundle install

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅ Fastlane installed successfully!${NC}"
    echo ""
else
    echo -e "${RED}❌ Fastlane installation failed!${NC}"
    exit 1
fi

# Create fastlane directory if it doesn't exist
if [ ! -d "fastlane" ]; then
    mkdir fastlane
fi

echo -e "${YELLOW}⚙️  Configuration needed:${NC}"
echo ""
echo "Please edit these files:"
echo "1. ${BLUE}fastlane/Appfile${NC}"
echo "   - Replace 'your-apple-id@gmail.com' with your Apple ID"
echo "   - Replace 'YOUR_TEAM_ID' with your Team ID"
echo "   (Find Team ID at: https://developer.apple.com/account)"
echo ""
echo "2. For Android uploads, you need a service account JSON:"
echo "   - Go to: https://console.cloud.google.com"
echo "   - Create service account for Play Console"
echo "   - Download JSON and save as: fastlane/play-store-credentials.json"
echo ""
echo -e "${GREEN}✅ Setup complete!${NC}"
echo ""
echo -e "${YELLOW}📝 Usage:${NC}"
echo ""
echo "iOS (TestFlight):"
echo "  ${BLUE}fastlane ios user${NC}      # Build + Upload USER app"
echo "  ${BLUE}fastlane ios admin${NC}     # Build + Upload ADMIN app"
echo "  ${BLUE}fastlane ios partner${NC}   # Build + Upload PARTNER app"
echo ""
echo "Android (Play Console):"
echo "  ${BLUE}fastlane android user${NC}    # Build + Upload USER app"
echo "  ${BLUE}fastlane android admin${NC}   # Build + Upload ADMIN app"
echo "  ${BLUE}fastlane android partner${NC} # Build + Upload PARTNER app"
echo ""
echo "🎉 You're ready to go!"
echo ""

