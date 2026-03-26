#!/bin/bash

# ===========================================
# 🍔 Restaurant Admin - Web Release Build
# ===========================================
# ✅ Builds Flutter web app
# ✅ Deploys to Netlify (production or preview)
# ✅ Can also deploy manually via drag-and-drop
# ===========================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'
BOLD='\033[1m'

cd "$(dirname "$0")"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}🍔 Restaurant Admin - Web Release${NC}"
echo -e "${BLUE}========================================${NC}"

# ─────────────────────────────────────────
# Parse arguments
# ─────────────────────────────────────────
DEPLOY_PROD=false
DEPLOY_PREVIEW=false
BUILD_ONLY=false

for arg in "$@"; do
    case $arg in
        --prod)      DEPLOY_PROD=true ;;
        --preview)   DEPLOY_PREVIEW=true ;;
        --build-only) BUILD_ONLY=true ;;
        --help|-h)
            echo ""
            echo "Usage: ./build_web_release.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --prod        Build and deploy to Netlify production"
            echo "  --preview     Build and deploy preview (staging URL)"
            echo "  --build-only  Build only, no deployment"
            echo "  (default)     Build and ask what to do"
            echo ""
            exit 0
            ;;
    esac
done

# ─────────────────────────────────────────
# Read version from pubspec.yaml
# ─────────────────────────────────────────
VERSION_LINE=$(grep "^version:" pubspec.yaml)
VERSION=$(echo "$VERSION_LINE" | sed 's/version: //' | sed 's/+.*//')
BUILD_NUM=$(echo "$VERSION_LINE" | sed 's/.*+//')

echo ""
echo -e "${CYAN}📊 Version: ${VERSION} (Build ${BUILD_NUM})${NC}"
echo ""

# ─────────────────────────────────────────
# Load environment variables
# ─────────────────────────────────────────
if [ -f ".env" ]; then
    echo -e "${GREEN}✅ Loading .env file${NC}"
    export $(grep -v '^#' .env | xargs) 2>/dev/null || true
else
    echo -e "${YELLOW}⚠️  No .env file found${NC}"
    echo -e "   Create one with: SUPABASE_URL, SUPABASE_ANON_KEY, GEMINI_API_KEY"
fi

# ─────────────────────────────────────────
# Clean & Build
# ─────────────────────────────────────────
echo -e "${YELLOW}🧹 Cleaning...${NC}"
flutter clean

echo -e "${YELLOW}📦 Getting dependencies...${NC}"
flutter pub get

echo -e "${YELLOW}🌐 Building web app...${NC}"
flutter build web \
    --release \
    --dart-define=SUPABASE_URL="${SUPABASE_URL:-}" \
    --dart-define=SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-}" \
    --dart-define=GEMINI_API_KEY="${GEMINI_API_KEY:-}"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✅ Web Build Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${CYAN}📦 Build Output: build/web/${NC}"
echo ""

# ─────────────────────────────────────────
# Deploy
# ─────────────────────────────────────────

if [ "$BUILD_ONLY" = true ]; then
    echo -e "${GREEN}✅ Build complete! Skipping deployment.${NC}"
    echo -e "${CYAN}   You can manually deploy build/web/ to any static hosting.${NC}"
    echo ""
    echo -e "${GREEN}🎉 Done! 🚀${NC}"
    exit 0
fi

# Check if Netlify CLI is available
NETLIFY_AVAILABLE=false
if command -v netlify &> /dev/null; then
    NETLIFY_AVAILABLE=true
fi

deploy_to_netlify_prod() {
    if [ "$NETLIFY_AVAILABLE" = true ]; then
        echo -e "${MAGENTA}🚀 Deploying to Netlify (Production)...${NC}"
        echo ""
        netlify deploy --prod --dir=build/web
        echo ""
        echo -e "${GREEN}✅ Production deployment complete!${NC}"
    else
        echo -e "${RED}❌ Netlify CLI not installed!${NC}"
        echo -e "${YELLOW}   Install: npm install -g netlify-cli${NC}"
        echo -e "${YELLOW}   Then:    netlify login${NC}"
        echo ""
        echo -e "${BLUE}📋 Manual Deployment Options:${NC}"
        echo "   1. Drag and drop build/web/ folder at: https://app.netlify.com/drop"
        echo "   2. Connect your Git repo in Netlify dashboard"
        echo "   3. Push to your deploy branch (auto-deploys via netlify.toml)"
    fi
}

deploy_to_netlify_preview() {
    if [ "$NETLIFY_AVAILABLE" = true ]; then
        echo -e "${MAGENTA}🔍 Deploying preview to Netlify...${NC}"
        echo ""
        netlify deploy --dir=build/web
        echo ""
        echo -e "${GREEN}✅ Preview deployment complete! Check the preview URL above.${NC}"
    else
        echo -e "${RED}❌ Netlify CLI not installed!${NC}"
        echo -e "${YELLOW}   Install: npm install -g netlify-cli${NC}"
    fi
}

if [ "$DEPLOY_PROD" = true ]; then
    deploy_to_netlify_prod

elif [ "$DEPLOY_PREVIEW" = true ]; then
    deploy_to_netlify_preview

else
    # Default: Ask user what to do
    echo -e "${CYAN}What would you like to do?${NC}"
    echo "  1) 🚀 Deploy to Netlify (Production)"
    echo "  2) 🔍 Deploy preview (staging URL)"
    echo "  3) 📋 Show manual deployment options"
    echo "  4) ⏭️  Skip deployment (build only)"
    echo ""
    read -p "Choose (1/2/3/4): " choice

    case $choice in
        1) deploy_to_netlify_prod ;;
        2) deploy_to_netlify_preview ;;
        3)
            echo ""
            echo -e "${BLUE}📋 Manual Deployment Options:${NC}"
            echo ""
            echo -e "  ${BOLD}Option 1: Netlify Drag & Drop${NC}"
            echo "    Go to: https://app.netlify.com/drop"
            echo "    Drag the build/web/ folder"
            echo ""
            echo -e "  ${BOLD}Option 2: Netlify CLI${NC}"
            echo "    npm install -g netlify-cli"
            echo "    netlify login"
            echo "    netlify deploy --prod --dir=build/web"
            echo ""
            echo -e "  ${BOLD}Option 3: Git Push (Auto-Deploy)${NC}"
            echo "    Push to your deploy branch"
            echo "    Netlify auto-builds via netlify.toml"
            echo ""
            echo -e "  ${BOLD}Option 4: Firebase Hosting${NC}"
            echo "    firebase deploy --only hosting"
            echo ""
            echo -e "  ${BOLD}Option 5: Any Static Host${NC}"
            echo "    Upload the build/web/ folder to:"
            echo "    Vercel, Cloudflare Pages, GitHub Pages, etc."
            ;;
        4)
            echo -e "${GREEN}✅ Build complete! Skipping deployment.${NC}"
            ;;
        *)
            echo -e "${GREEN}✅ Build complete at: build/web/${NC}"
            ;;
    esac
fi

echo ""
echo -e "${GREEN}🎉 Done! Happy releasing! 🚀${NC}"
