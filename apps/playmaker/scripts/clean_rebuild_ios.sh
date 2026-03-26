#!/bin/bash

# Complete Clean and Rebuild for iOS
# Use this after any bundle ID or capability changes

echo "🧹 Starting complete iOS clean and rebuild..."
echo ""

# Step 1: Flutter clean
echo "1️⃣ Running flutter clean..."
flutter clean

# Step 2: Remove iOS build artifacts
echo "2️⃣ Removing iOS build artifacts..."
rm -rf ios/Pods
rm -rf ios/.symlinks
rm -rf ios/Flutter/Flutter.framework
rm -rf ios/Flutter/Flutter.podspec
rm -rf ios/.generated/
rm -f ios/Podfile.lock

# Step 3: Clean derived data
echo "3️⃣ Cleaning Xcode derived data..."
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# Step 4: Reinstall pods
echo "4️⃣ Reinstalling CocoaPods..."
cd ios
pod deintegrate
pod install
cd ..

# Step 5: Get Flutter packages
echo "5️⃣ Getting Flutter packages..."
flutter pub get

echo ""
echo "✅ Clean complete!"
echo ""
echo "Now run: ./run_user_app.sh"
echo ""



