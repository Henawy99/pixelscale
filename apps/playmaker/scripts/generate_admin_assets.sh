#!/bin/bash

# ==========================================
# Generate ADMIN App Assets (Icons + Splash)
# ==========================================

set -e

echo "🎨 Generating ADMIN App Assets..."
echo ""

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if splash logo exists
if [ ! -f "assets/splash_admin.png" ]; then
    echo "${YELLOW}⚠️  Warning: assets/splash_admin.png not found!${NC}"
    echo "${YELLOW}   Splash will use solid black background only.${NC}"
    echo ""
    echo "   To add 'PM ADMIN' logo:"
    echo "   1. Create a 1024x1024px PNG with black background and white 'PM ADMIN' text"
    echo "   2. Save as: assets/splash_admin.png"
    echo "   3. Run this script again"
    echo ""
    echo "${BLUE}📖 See: CREATE_SPLASH_LOGOS.md for detailed instructions${NC}"
    echo ""
fi

# Generate Icons
echo "${BLUE}📱 Generating app icons...${NC}"
flutter pub run flutter_launcher_icons:main -f flutter_launcher_icons_admin.yaml
echo "${GREEN}✅ Icons generated${NC}"
echo ""

# Generate Splash Screen
echo "${BLUE}💦 Generating splash screen...${NC}"
dart run flutter_native_splash:create --path=flutter_native_splash_admin.yaml 2>&1 | grep -v "Warning" || true
echo "${GREEN}✅ Splash screen generated${NC}"
echo ""

if [ -f "assets/splash_admin.png" ]; then
    echo "${GREEN}✅ Using custom PM ADMIN logo on black background${NC}"
else
    echo "${YELLOW}💡 Using solid black background (add logo for best results)${NC}"
fi
echo ""

echo "${GREEN}🎉 ADMIN app assets generated successfully!${NC}"
echo ""
echo "Next steps:"
echo "  Run app: ./run_admin_app.sh"
echo "  Build: ./build_admin_app.sh"

