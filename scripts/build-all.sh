#!/bin/bash
# ============================================
# PixelScale - Build All Apps
# Builds every app for both iOS and Android
# ============================================
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
APPS_DIR="$ROOT_DIR/apps"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

echo ""
echo -e "${GREEN}${BOLD}╔══════════════════════════════════════╗${NC}"
echo -e "${GREEN}${BOLD}║     PixelScale - Build All Apps      ║${NC}"
echo -e "${GREEN}${BOLD}╚══════════════════════════════════════╝${NC}"
echo ""

PLATFORM="${1:-both}"  # ios, android, or both

FAILED=()
SUCCESS=()

for app_dir in "$APPS_DIR"/*/; do
  app_name=$(basename "$app_dir")
  [[ "$app_name" == _* ]] && continue
  [[ ! -f "$app_dir/run.sh" && ! -f "$app_dir/package.json" && ! -f "$app_dir/pubspec.yaml" ]] && continue

  echo -e "${YELLOW}=== Building: $app_name ===${NC}"

  if [[ "$PLATFORM" != "android" ]] && [[ -f "$app_dir/build_ios.sh" ]]; then
    echo -e "  iOS..."
    if (cd "$app_dir" && bash build_ios.sh); then
      SUCCESS+=("$app_name (iOS)")
    else
      FAILED+=("$app_name (iOS)")
    fi
  fi

  if [[ "$PLATFORM" != "ios" ]] && [[ -f "$app_dir/build_android.sh" ]]; then
    echo -e "  Android..."
    if (cd "$app_dir" && bash build_android.sh); then
      SUCCESS+=("$app_name (Android)")
    else
      FAILED+=("$app_name (Android)")
    fi
  fi

  echo ""
done

echo -e "${GREEN}${BOLD}Build Summary${NC}"
echo "─────────────────────────────"

if [[ ${#SUCCESS[@]} -gt 0 ]]; then
  echo -e "${GREEN}Succeeded:${NC}"
  for s in "${SUCCESS[@]}"; do echo "  + $s"; done
fi

if [[ ${#FAILED[@]} -gt 0 ]]; then
  echo -e "${RED}Failed:${NC}"
  for f in "${FAILED[@]}"; do echo "  x $f"; done
fi

echo ""
