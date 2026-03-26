#!/bin/bash

# Run Admin App on Chrome Web
# Runs the ADMIN app in Chrome browser

echo "🎯 Running ADMIN App (Playmaker Admin) on Chrome Web..."
echo ""
echo "🌐 Platform: Chrome Browser"
echo "📱 App Name: PM Admin"
echo "🎨 Theme: Light with green accent"
echo "🚀 Mode: Release (no auto-close on errors)"
echo ""

# Run the admin app on Chrome in RELEASE mode
# Release mode prevents the app from auto-closing on errors
flutter run -d chrome --release -t lib/main_admin.dart



