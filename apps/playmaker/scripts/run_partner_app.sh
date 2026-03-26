#!/bin/bash

# Run Partner App Script
# Automatically sets bundle ID and icons for PARTNER app, then runs it

echo "🎯 Preparing PARTNER App (Playmaker Field Owner)..."
echo ""

# Step 1: Set Bundle ID to com.example.playmakeradmin (for existing app store app)
echo "📦 Setting Bundle ID to: com.example.playmakeradmin"
sed -i '' 's/PRODUCT_BUNDLE_IDENTIFIER = com\.playmaker\.[^;]*;/PRODUCT_BUNDLE_IDENTIFIER = com.example.playmakeradmin;/g' ios/Runner.xcodeproj/project.pbxproj

# Step 2: Set Display Name to "Playmaker Partner"
echo "📱 Setting Display Name to: Playmaker Partner"
# Replace all possible previous names
sed -i '' 's/<string>Playmaker<\/string>/<string>Playmaker Partner<\/string>/g' ios/Runner/Info.plist
sed -i '' 's/<string>PM Admin<\/string>/<string>Playmaker Partner<\/string>/g' ios/Runner/Info.plist
sed -i '' 's/<string>Playmaker Admin<\/string>/<string>Playmaker Partner<\/string>/g' ios/Runner/Info.plist
sed -i '' 's/<string>Playmaker Field Owner<\/string>/<string>Playmaker Partner<\/string>/g' ios/Runner/Info.plist
sed -i '' 's/<string>PM Partner<\/string>/<string>Playmaker Partner<\/string>/g' ios/Runner/Info.plist
sed -i '' 's/<string>PM Partners<\/string>/<string>Playmaker Partner<\/string>/g' ios/Runner/Info.plist

# Step 3: Generate Partner App Icons (Blue)
echo "🎨 Generating Partner App icons (Blue)..."
flutter pub run flutter_launcher_icons:main -f flutter_launcher_icons_partner.yaml

# Step 4: Generate Partner Splash Screen (Blue)
echo "💦 Generating Partner splash screen (Blue)..."
dart run flutter_native_splash:create --path=flutter_native_splash_partner.yaml 2>/dev/null || echo "⚠️  Splash generation skipped"

echo ""
echo "✅ Setup complete! Running PARTNER app..."
echo ""

# Step 5: Run the partner app
flutter run -t lib/main_partner.dart



