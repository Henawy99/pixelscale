#!/bin/bash

# ============================================
# Playmaker Management App - Android Release Build
# ============================================
# Unified Admin + Partner app
# For Play Store distribution
# ============================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Version tracking
CURRENT_VERSION="1.0.3"
CURRENT_BUILD="1"

echo -e "${BLUE}"
echo "🚀 Building Android MANAGEMENT App for Play Store..."
echo "====================================================="
echo -e "${NC}"

# Calculate new version
IFS='.' read -r major minor patch <<< "$CURRENT_VERSION"
NEW_PATCH=$((patch + 1))
NEW_VERSION="${major}.${minor}.${NEW_PATCH}"
NEW_BUILD="1"

echo -e "${CYAN}📊 Current Version: ${CURRENT_VERSION} (Build ${CURRENT_BUILD})${NC}"
echo -e "${CYAN}📊 New Version:     ${NEW_VERSION} (Build ${NEW_BUILD})${NC}"
echo ""

# Update version in pubspec.yaml
echo -e "${YELLOW}📝 Updating version in pubspec.yaml...${NC}"
sed -i '' "s/version: .*/version: ${NEW_VERSION}+${NEW_BUILD}/" pubspec.yaml

# Generate app icons (using admin icons for now)
echo -e "${YELLOW}🎨 Generating app icons...${NC}"
flutter pub run flutter_launcher_icons:main -f flutter_launcher_icons_admin.yaml 2>/dev/null || true

# Clean build
echo -e "${YELLOW}🧹 Cleaning...${NC}"
flutter clean
flutter pub get

# Build Android AAB with management flavor (uses com.playmaker.admin package)
echo -e "${YELLOW}🤖 Building Android AAB (Management App)...${NC}"
flutter build appbundle --release --flavor management -t lib/main_management.dart --build-name=$NEW_VERSION --build-number=$NEW_BUILD

echo -e "${GREEN}"
echo "✅ Android build complete!"
echo ""
echo "📊 Version Info:"
echo "   Old Version: ${CURRENT_VERSION} (Build ${CURRENT_BUILD})"
echo "   New Version: ${NEW_VERSION} (Build ${NEW_BUILD})"
echo "   Package: com.playmaker.admin"
echo "   Replaces: Playmaker Admin app in Play Console"
echo ""
echo "📦 AAB Location:"
echo "   build/app/outputs/bundle/managementRelease/app-management-release.aab"
echo -e "${NC}"

# Update script with new version for next run
sed -i '' "s/CURRENT_VERSION=\".*\"/CURRENT_VERSION=\"${NEW_VERSION}\"/" "$0"
sed -i '' "s/CURRENT_BUILD=\".*\"/CURRENT_BUILD=\"${NEW_BUILD}\"/" "$0"

echo -e "${YELLOW}📋 Next Steps:${NC}"
echo "   1. Go to Play Console → Playmaker Admin"
echo "   2. Upload AAB to Internal Testing"
echo "   3. Review and publish"
echo ""
echo -e "${CYAN}ℹ️  This will update your existing 'Playmaker Admin' app${NC}"
echo -e "${CYAN}   Partners can now also use this app to login!${NC}"
echo ""
echo -e "${GREEN}🎉 Done!${NC}"
