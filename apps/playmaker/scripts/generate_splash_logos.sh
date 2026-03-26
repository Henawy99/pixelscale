#!/bin/bash

# ==========================================
# Generate Text-Based Splash Screen Logos
# ==========================================
# Uses ImageMagick to create simple text logos
# No Python dependencies needed!
# ==========================================

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "🎨 Generating splash screen logos..."
echo ""

# Check if ImageMagick is installed
if ! command -v convert &> /dev/null; then
    echo "${RED}❌ ImageMagick is not installed${NC}"
    echo ""
    echo "Install with: brew install imagemagick"
    echo ""
    echo "Or I can create placeholder files for you..."
    read -p "Create placeholder files? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Create simple colored squares as placeholders
        echo "${YELLOW}Creating placeholder images...${NC}"
        
        # For macOS, we can use sips to create basic images
        # Create black 1024x1024 for admin
        sips -z 1024 1024 -s format png --setProperty formatOptions normal /System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertNoteIcon.icns --out assets/splash_admin_temp.png 2>/dev/null || true
        
        # Create blue 1024x1024 for partner
        sips -z 1024 1024 -s format png --setProperty formatOptions normal /System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertNoteIcon.icns --out assets/splash_partner_temp.png 2>/dev/null || true
        
        echo "${YELLOW}⚠️  Created temporary placeholders${NC}"
        echo "${YELLOW}   Install ImageMagick for proper text logos${NC}"
    fi
    exit 1
fi

# Create assets directory if it doesn't exist
mkdir -p assets

# Generate ADMIN splash: Black background with "PM ADMIN" white text
echo "${BLUE}📱 Creating ADMIN splash logo (Black with 'PM ADMIN')...${NC}"
convert -size 1024x1024 xc:black \
    -gravity center \
    -pointsize 180 \
    -font "Arial-Bold" \
    -fill white \
    -annotate +0-100 "PM" \
    -pointsize 150 \
    -annotate +0+100 "ADMIN" \
    assets/splash_admin.png

echo "${GREEN}✅ Created: assets/splash_admin.png${NC}"

# Generate PARTNER splash: Blue background with "PM Partner" white text
echo "${BLUE}📱 Creating PARTNER splash logo (Blue with 'PM Partner')...${NC}"
convert -size 1024x1024 xc:"#2563EB" \
    -gravity center \
    -pointsize 180 \
    -font "Arial-Bold" \
    -fill white \
    -annotate +0-100 "PM" \
    -pointsize 150 \
    -annotate +0+100 "Partner" \
    assets/splash_partner.png

echo "${GREEN}✅ Created: assets/splash_partner.png${NC}"

echo ""
echo "${GREEN}🎉 Splash logos created successfully!${NC}"
echo ""
echo "Next steps:"
echo "  ${BLUE}1.${NC} Run: ${YELLOW}./generate_admin_assets.sh${NC}"
echo "  ${BLUE}2.${NC} Run: ${YELLOW}./generate_partner_assets.sh${NC}"
echo "  ${BLUE}3.${NC} Test: ${YELLOW}./run_admin_app.sh${NC}"
echo "  ${BLUE}4.${NC} Test: ${YELLOW}./run_partner_app.sh${NC}"
echo ""

