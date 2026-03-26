#!/bin/bash

# ===========================================
# Restaurant Admin - Release Build Script
# ===========================================
# Usage:
#   ./build_release.sh ios      - Build for iOS (TestFlight)
#   ./build_release.sh android  - Build for Android (Google Play)
#   ./build_release.sh both     - Build for both platforms
#   ./build_release.sh xcode    - Open Xcode
#   ./build_release.sh version  - Just increment version
# ===========================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get current directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Function to get current version from pubspec.yaml
get_current_version() {
    grep "^version:" pubspec.yaml | sed 's/version: //'
}

# Function to increment build number
increment_version() {
    current=$(get_current_version)
    
    # Parse version (e.g., 1.0.1+2)
    version_name=$(echo $current | cut -d'+' -f1)
    build_number=$(echo $current | cut -d'+' -f2)
    
    # Increment build number
    new_build=$((build_number + 1))
    new_version="${version_name}+${new_build}"
    
    echo -e "${YELLOW}Incrementing version: ${current} → ${new_version}${NC}"
    
    # Update pubspec.yaml
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s/^version: .*/version: ${new_version}/" pubspec.yaml
    else
        # Linux
        sed -i "s/^version: .*/version: ${new_version}/" pubspec.yaml
    fi
    
    echo -e "${GREEN}✓ Version updated to ${new_version}${NC}"
}

# Function to increment minor version (e.g., 1.0.1 → 1.0.2)
increment_minor_version() {
    current=$(get_current_version)
    
    # Parse version
    version_name=$(echo $current | cut -d'+' -f1)
    build_number=$(echo $current | cut -d'+' -f2)
    
    # Parse version parts
    major=$(echo $version_name | cut -d'.' -f1)
    minor=$(echo $version_name | cut -d'.' -f2)
    patch=$(echo $version_name | cut -d'.' -f3)
    
    # Increment patch and build
    new_patch=$((patch + 1))
    new_build=$((build_number + 1))
    new_version="${major}.${minor}.${new_patch}+${new_build}"
    
    echo -e "${YELLOW}Incrementing minor version: ${current} → ${new_version}${NC}"
    
    # Update pubspec.yaml
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s/^version: .*/version: ${new_version}/" pubspec.yaml
    else
        sed -i "s/^version: .*/version: ${new_version}/" pubspec.yaml
    fi
    
    echo -e "${GREEN}✓ Version updated to ${new_version}${NC}"
}

# Function to build iOS
build_ios() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Building iOS Release for TestFlight${NC}"
    echo -e "${BLUE}========================================${NC}"
    
    # Clean and get dependencies
    echo -e "${YELLOW}Cleaning...${NC}"
    flutter clean
    
    echo -e "${YELLOW}Getting dependencies...${NC}"
    flutter pub get
    
    # Build iOS
    echo -e "${YELLOW}Building iOS Archive...${NC}"
    flutter build ipa --release
    
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}✓ iOS Build Complete!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo -e "${YELLOW}IPA Location: build/ios/ipa/*.ipa${NC}"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo "1. Open Xcode: ./build_release.sh xcode"
    echo "2. Or upload directly using Transporter app"
    echo "3. Or use: xcrun altool --upload-app -f build/ios/ipa/*.ipa -t ios -u YOUR_APPLE_ID -p YOUR_APP_SPECIFIC_PASSWORD"
    echo ""
}

# Function to build Android
build_android() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Building Android Release for Google Play${NC}"
    echo -e "${BLUE}========================================${NC}"
    
    # Clean and get dependencies
    echo -e "${YELLOW}Cleaning...${NC}"
    flutter clean
    
    echo -e "${YELLOW}Getting dependencies...${NC}"
    flutter pub get
    
    # Build Android App Bundle
    echo -e "${YELLOW}Building Android App Bundle (AAB)...${NC}"
    flutter build appbundle --release
    
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}✓ Android Build Complete!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo -e "${YELLOW}AAB Location: build/app/outputs/bundle/release/app-release.aab${NC}"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo "1. Go to Google Play Console: https://play.google.com/console"
    echo "2. Upload the AAB file to your app's release track"
    echo ""
}

# Function to open Xcode
open_xcode() {
    echo -e "${BLUE}Opening Xcode...${NC}"
    open ios/Runner.xcworkspace
}

# Function to show current version
show_version() {
    current=$(get_current_version)
    echo -e "${GREEN}Current version: ${current}${NC}"
}

# Main script
case "$1" in
    ios)
        show_version
        increment_version
        build_ios
        ;;
    android)
        show_version
        increment_version
        build_android
        ;;
    both)
        show_version
        increment_version
        build_ios
        build_android
        ;;
    xcode)
        open_xcode
        ;;
    version)
        show_version
        increment_version
        ;;
    minor)
        show_version
        increment_minor_version
        ;;
    status)
        show_version
        ;;
    *)
        echo -e "${GREEN}========================================${NC}"
        echo -e "${GREEN}Restaurant Admin - Build Script${NC}"
        echo -e "${GREEN}========================================${NC}"
        show_version
        echo ""
        echo -e "${YELLOW}Usage:${NC}"
        echo "  ./build_release.sh ios      - Build for iOS (TestFlight)"
        echo "  ./build_release.sh android  - Build for Android (Google Play)"
        echo "  ./build_release.sh both     - Build for both platforms"
        echo "  ./build_release.sh xcode    - Open Xcode workspace"
        echo "  ./build_release.sh version  - Increment build number only"
        echo "  ./build_release.sh minor    - Increment minor version (1.0.1 → 1.0.2)"
        echo "  ./build_release.sh status   - Show current version"
        echo ""
        echo -e "${BLUE}Quick Commands:${NC}"
        echo "  flutter build ipa --release           # Build iOS IPA"
        echo "  flutter build appbundle --release     # Build Android AAB"
        echo "  open ios/Runner.xcworkspace           # Open Xcode"
        echo ""
        ;;
esac





