#!/bin/bash

# Run User App Script
# Automatically sets bundle ID and icons for USER app, then runs it

echo "🎯 Preparing USER App (Playmaker)..."
echo ""

# Step 1: Set Bundle ID to com.playmaker.start
echo "📦 Setting Bundle ID to: com.playmaker.start"
sed -i '' 's/PRODUCT_BUNDLE_IDENTIFIER = com\.playmaker\.[^;]*;/PRODUCT_BUNDLE_IDENTIFIER = com.playmaker.start;/g' ios/Runner.xcodeproj/project.pbxproj
sed -i '' 's/PRODUCT_BUNDLE_IDENTIFIER = com\.example\.[^;]*;/PRODUCT_BUNDLE_IDENTIFIER = com.playmaker.start;/g' ios/Runner.xcodeproj/project.pbxproj

# Step 2: Set Display Name to "Playmaker"
echo "📱 Setting Display Name to: Playmaker"
# Replace all possible previous names
sed -i '' 's/<string>PM Partners<\/string>/<string>Playmaker<\/string>/g' ios/Runner/Info.plist
sed -i '' 's/<string>PM Admin<\/string>/<string>Playmaker<\/string>/g' ios/Runner/Info.plist
sed -i '' 's/<string>Playmaker Admin<\/string>/<string>Playmaker<\/string>/g' ios/Runner/Info.plist
sed -i '' 's/<string>Playmaker Field Owner<\/string>/<string>Playmaker<\/string>/g' ios/Runner/Info.plist
sed -i '' 's/<string>PM Partner<\/string>/<string>Playmaker<\/string>/g' ios/Runner/Info.plist
sed -i '' 's/<string>Playmaker Partner<\/string>/<string>Playmaker<\/string>/g' ios/Runner/Info.plist

# Step 3: Generate User App Icons (Green)
echo "🎨 Generating User App icons (Green)..."
flutter pub run flutter_launcher_icons:main -f flutter_launcher_icons_user.yaml

# Step 4: Generate User Splash Screen (Green)
echo "💦 Generating User splash screen (Green)..."
dart run flutter_native_splash:create --path=flutter_native_splash_user.yaml 2>/dev/null || echo "⚠️  Splash generation skipped"

echo ""
echo "✅ Setup complete! Running USER app..."
echo ""

# Step 5: Run the app
flutter run "$@"

