#!/bin/bash

# ==========================================
# Restore USER App Bundle ID
# ==========================================
# Run this after building ADMIN app to restore
# the bundle ID back to the USER app
# ==========================================

set -e

echo "🔄 Restoring USER app Bundle ID..."

BUNDLE_ID="com.playmaker.start"
DISPLAY_NAME="Playmaker"
INFO_PLIST="ios/Runner/Info.plist"
PBXPROJ="ios/Runner.xcodeproj/project.pbxproj"

# Update Info.plist
plutil -replace CFBundleDisplayName -string "$DISPLAY_NAME" "$INFO_PLIST"
plutil -replace CFBundleName -string "$DISPLAY_NAME" "$INFO_PLIST"

# Update Bundle ID in project.pbxproj (restore from admin to user)
sed -i '' "s/PRODUCT_BUNDLE_IDENTIFIER = com\.playmaker\.admin/PRODUCT_BUNDLE_IDENTIFIER = $BUNDLE_ID/g" "$PBXPROJ"

# Regenerate user app icons
flutter pub run flutter_launcher_icons:main -f flutter_launcher_icons_user.yaml

echo "✅ Restored to USER app configuration"
echo "   Bundle ID: $BUNDLE_ID"
echo "   Display Name: $DISPLAY_NAME"
echo ""
echo "You can now run the USER app normally."

