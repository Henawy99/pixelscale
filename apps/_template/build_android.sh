#!/bin/bash
set -e
cd "$(dirname "$0")"

APP_NAME="TEMPLATE_NAME"
APP_JSON="app.json"
VERSION_HISTORY=".version_history"

echo "=========================================="
echo "  $APP_NAME - Android Release Build"
echo "=========================================="

OLD_VERSION=$(node -e "console.log(require('./$APP_JSON').expo.version)")
IFS='.' read -r MAJOR MINOR PATCH <<< "$OLD_VERSION"
PATCH=$((PATCH + 1))
NEW_VERSION="$MAJOR.$MINOR.$PATCH"

if [[ -f "$VERSION_HISTORY" ]]; then
  LAST=$(cat "$VERSION_HISTORY")
  if [[ "$(printf '%s\n' "$LAST" "$NEW_VERSION" | sort -V | tail -1)" != "$NEW_VERSION" ]]; then
    IFS='.' read -r MAJOR MINOR PATCH <<< "$LAST"
    PATCH=$((PATCH + 1))
    NEW_VERSION="$MAJOR.$MINOR.$PATCH"
  fi
fi

node -e "const f=require('fs');const c=JSON.parse(f.readFileSync('$APP_JSON','utf8'));c.expo.version='$NEW_VERSION';f.writeFileSync('$APP_JSON',JSON.stringify(c,null,2)+'\n')"
echo "$NEW_VERSION" > "$VERSION_HISTORY"
echo "  Version: $OLD_VERSION -> $NEW_VERSION"

npx eas-cli build --platform android --profile production --non-interactive
npx eas-cli submit --platform android --profile production --non-interactive || echo "Submit skipped"

echo "  $APP_NAME Android build complete! Version: $NEW_VERSION"
