#!/bin/bash

# Run Admin App Script
# Automatically sets bundle ID and icons for ADMIN app, then runs it

echo "🎯 Preparing ADMIN App (Playmaker Admin)..."
echo ""

# Step 1: Set Bundle ID to com.playmaker.admin
echo "📦 Setting Bundle ID to: com.playmaker.admin"
sed -i '' 's/PRODUCT_BUNDLE_IDENTIFIER = com\.playmaker\.[^;]*;/PRODUCT_BUNDLE_IDENTIFIER = com.playmaker.admin;/g' ios/Runner.xcodeproj/project.pbxproj
sed -i '' 's/PRODUCT_BUNDLE_IDENTIFIER = com\.example\.playmakeradmin;/PRODUCT_BUNDLE_IDENTIFIER = com.playmaker.admin;/g' ios/Runner.xcodeproj/project.pbxproj

# Step 2: Set Display Name to "Playmaker Admin"
echo "📱 Setting Display Name to: Playmaker Admin"
# Replace all possible previous names with CFBundleDisplayName
sed -i '' 's/<string>Playmaker<\/string>/<string>Playmaker Admin<\/string>/g' ios/Runner/Info.plist
sed -i '' 's/<string>PM Admin<\/string>/<string>Playmaker Admin<\/string>/g' ios/Runner/Info.plist
sed -i '' 's/<string>PM Partners<\/string>/<string>Playmaker Admin<\/string>/g' ios/Runner/Info.plist
sed -i '' 's/<string>Playmaker Field Owner<\/string>/<string>Playmaker Admin<\/string>/g' ios/Runner/Info.plist
sed -i '' 's/<string>PM Partner<\/string>/<string>Playmaker Admin<\/string>/g' ios/Runner/Info.plist
sed -i '' 's/<string>Playmaker Partner<\/string>/<string>Playmaker Admin<\/string>/g' ios/Runner/Info.plist

# Step 2.5: Swap Firebase Config for ADMIN app
echo "🔥 Setting Firebase config for ADMIN app..."
if [ -f "ios/Runner/GoogleService-Info-Admin.plist" ]; then
    cp ios/Runner/GoogleService-Info-Admin.plist ios/Runner/GoogleService-Info.plist
    echo "✅ Using GoogleService-Info-Admin.plist"
else
    echo "⚠️  GoogleService-Info-Admin.plist not found. Using default."
fi

# Step 3: Generate Admin App Icons (Green)
echo "🎨 Generating Admin App icons (Green)..."
flutter pub run flutter_launcher_icons:main -f flutter_launcher_icons_admin.yaml

# Step 4: Generate Admin Splash Screen (Black)
echo "💦 Generating Admin splash screen (Black)..."
dart run flutter_native_splash:create --path=flutter_native_splash_admin.yaml 2>/dev/null || echo "⚠️  Splash generation skipped"

echo ""
echo "✅ Setup complete! Running ADMIN app..."
echo ""

# Step 5: Run the admin app
flutter run -t lib/main_admin.dart



