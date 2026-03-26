#!/bin/bash

# ==========================================
# Generate USER App Assets (Icons + Splash)
# ==========================================

set -e

echo "🎨 Generating USER App Assets..."
echo ""

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Generate Icons
echo "${BLUE}📱 Generating app icons...${NC}"
flutter pub run flutter_launcher_icons:main -f flutter_launcher_icons_user.yaml
echo "${GREEN}✅ Icons generated${NC}"
echo ""

# Generate Splash Screen
echo "${BLUE}💦 Generating splash screen...${NC}"
dart run flutter_native_splash:create --path=flutter_native_splash_user.yaml
echo "${GREEN}✅ Splash screen generated${NC}"
echo ""

echo "${GREEN}🎉 USER app assets generated successfully!${NC}"
echo ""
echo "Next steps:"
echo "  Run app: ./run_user_app.sh"
echo "  Build: ./build_user_app.sh"

