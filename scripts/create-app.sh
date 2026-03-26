#!/bin/bash
# ============================================
# PixelScale - Create New App
# Usage: ./scripts/create-app.sh my-app "My App" com.pixelscale.myapp
# ============================================
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TEMPLATE_DIR="$ROOT_DIR/apps/_template"
APPS_DIR="$ROOT_DIR/apps"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

# Parse arguments
APP_SLUG="${1:-}"
APP_NAME="${2:-}"
BUNDLE_ID="${3:-}"

if [[ -z "$APP_SLUG" ]]; then
  echo -e "${YELLOW}Usage:${NC} ./scripts/create-app.sh <slug> <name> <bundle-id>"
  echo ""
  echo "  slug       : folder name, e.g. my-fitness-app"
  echo "  name       : display name, e.g. \"My Fitness App\""
  echo "  bundle-id  : e.g. com.pixelscale.fitness"
  echo ""
  
  read -p "App slug (folder name): " APP_SLUG
  read -p "App display name: " APP_NAME
  read -p "Bundle ID (e.g. com.pixelscale.myapp): " BUNDLE_ID
fi

APP_NAME="${APP_NAME:-$APP_SLUG}"
BUNDLE_ID="${BUNDLE_ID:-com.pixelscale.$APP_SLUG}"
APP_DIR="$APPS_DIR/$APP_SLUG"

# Validate
if [[ -d "$APP_DIR" ]]; then
  echo -e "${RED}Error: $APP_DIR already exists${NC}"
  exit 1
fi

if [[ ! -d "$TEMPLATE_DIR" ]]; then
  echo -e "${RED}Error: Template not found at $TEMPLATE_DIR${NC}"
  exit 1
fi

echo ""
echo -e "${GREEN}${BOLD}Creating new app:${NC}"
echo "  Slug:      $APP_SLUG"
echo "  Name:      $APP_NAME"
echo "  Bundle ID: $BUNDLE_ID"
echo "  Path:      apps/$APP_SLUG/"
echo ""

# Copy template
cp -r "$TEMPLATE_DIR" "$APP_DIR"

# Replace placeholders in all files
find "$APP_DIR" -type f \( -name "*.json" -o -name "*.ts" -o -name "*.tsx" -o -name "*.sh" \) | while read -r file; do
  if [[ "$(uname)" == "Darwin" ]]; then
    sed -i '' "s/TEMPLATE_NAME/$APP_NAME/g" "$file"
    sed -i '' "s/TEMPLATE_SLUG/$APP_SLUG/g" "$file"
    sed -i '' "s/TEMPLATE_BUNDLE_ID/$BUNDLE_ID/g" "$file"
  else
    sed -i "s/TEMPLATE_NAME/$APP_NAME/g" "$file"
    sed -i "s/TEMPLATE_SLUG/$APP_SLUG/g" "$file"
    sed -i "s/TEMPLATE_BUNDLE_ID/$BUNDLE_ID/g" "$file"
  fi
done

# Make scripts executable
chmod +x "$APP_DIR/run.sh" "$APP_DIR/build_ios.sh" "$APP_DIR/build_android.sh"

# Install dependencies
echo "Installing dependencies..."
cd "$APP_DIR" && npm install --legacy-peer-deps 2>/dev/null || echo "(run 'npm install' manually if this failed)"

echo ""
echo -e "${GREEN}${BOLD}App created successfully!${NC}"
echo ""
echo "  Next steps:"
echo "    cd apps/$APP_SLUG"
echo "    ./run.sh                  # Start dev server"
echo "    ./build_ios.sh            # Build for TestFlight"
echo "    ./build_android.sh        # Build for Play Console"
echo ""
echo "  Or use the project manager:"
echo "    ./pm run                  # Select $APP_SLUG from the menu"
echo ""
