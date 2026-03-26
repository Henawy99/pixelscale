#!/bin/bash

echo "🚀 Setting up Automated Android Uploads for Playmaker"
echo "======================================================"
echo ""

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

cd "$(dirname "$0")"

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

echo -e "${GREEN}✅ Bundler installed${NC}"
echo ""

# Install Fastlane
echo -e "${BLUE}📦 Installing Fastlane and dependencies...${NC}"
bundle install

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅ Fastlane installed successfully!${NC}"
    echo ""
else
    echo -e "${RED}❌ Fastlane installation failed!${NC}"
    exit 1
fi

# Verify service account JSON exists
if [ ! -f "android/playmaker-play-console-service-account.json" ]; then
    echo -e "${YELLOW}⚠️  Service account JSON not found!${NC}"
    echo "Place your Google Play service account JSON at:"
    echo "  android/playmaker-play-console-service-account.json"
    echo ""
    exit 1
fi

echo -e "${GREEN}✅ Service account JSON found${NC}"
echo ""

# Verify Fastfile exists
if [ ! -f "android/fastlane/Fastfile" ]; then
    echo -e "${RED}❌ Fastfile not found!${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Fastlane configuration complete${NC}"
echo ""

echo -e "${GREEN}🎉 Setup Complete!${NC}"
echo ""
echo -e "${YELLOW}📝 Usage:${NC}"
echo ""
echo "  ${BLUE}./build_android_user_release.sh${NC}"
echo "    → Builds AAB + Auto-uploads to Play Console Internal Testing"
echo ""
echo "  Or use Fastlane directly:"
echo ""
echo "  ${BLUE}cd android && bundle exec fastlane user${NC}"
echo "    → Build & upload USER app"
echo ""
echo "  ${BLUE}cd android && bundle exec fastlane upload_user${NC}"
echo "    → Upload existing AAB (skip build)"
echo ""
echo -e "${GREEN}✅ You're ready to automate uploads!${NC}"
echo ""





