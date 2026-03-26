#!/bin/bash

# Playmaker Partner App Build Script
# This script builds the Playmaker Partner app for iOS and Android

echo "🏗️  Building Playmaker Partner App..."
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Navigate to project directory
cd "$(dirname "$0")"

echo "${BLUE}📦 Cleaning previous builds...${NC}"
flutter clean
flutter pub get

echo ""
echo "${BLUE}🍎 Building iOS Partner App...${NC}"
flutter build ios --release -t lib/main_partner.dart

if [ $? -eq 0 ]; then
    echo "${GREEN}✅ iOS Partner build completed!${NC}"
else
    echo "${YELLOW}⚠️  iOS build failed or skipped${NC}"
fi

echo ""
echo "${BLUE}🤖 Building Android Partner App (AAB)...${NC}"
flutter build appbundle --release -t lib/main_partner.dart

if [ $? -eq 0 ]; then
    echo "${GREEN}✅ Android Partner build completed!${NC}"
    echo ""
    echo "${GREEN}📍 Android AAB location:${NC}"
    echo "   build/app/outputs/bundle/release/app-release.aab"
else
    echo "${YELLOW}⚠️  Android build failed${NC}"
fi

echo ""
echo "${GREEN}🎉 Partner App Build Complete!${NC}"
echo ""
echo "Next steps:"
echo "1. iOS: Open ios/Runner.xcworkspace in Xcode"
echo "   - Select 'Any iOS Device'"
echo "   - Product → Archive"
echo "   - Upload to App Store Connect"
echo ""
echo "2. Android: Upload AAB to Play Console"
echo "   - Go to play.google.com/console"
echo "   - Create new release"
echo "   - Upload: build/app/outputs/bundle/release/app-release.aab"
echo ""

