# 🚀 Restaurant Admin - Build & Release Guide

## Quick Commands

### 📱 Build for iOS (TestFlight)
```bash
./build_release.sh ios
```

### 🤖 Build for Android (Google Play)
```bash
./build_release.sh android
```

### 🔄 Build Both Platforms
```bash
./build_release.sh both
```

### 🛠️ Open Xcode
```bash
./build_release.sh xcode
# OR
open ios/Runner.xcworkspace
```

### 📊 Check Current Version
```bash
./build_release.sh status
```

### ⬆️ Increment Version Only
```bash
./build_release.sh version   # Increment build number (1.0.1+2 → 1.0.1+3)
./build_release.sh minor     # Increment patch version (1.0.1+2 → 1.0.2+3)
```

---

## 📋 Manual Commands

### iOS Build (for TestFlight)
```bash
# 1. Increment version in pubspec.yaml
# 2. Clean and build
flutter clean
flutter pub get
flutter build ipa --release

# Output: build/ios/ipa/restaurantadmin.ipa
```

### Android Build (for Google Play)
```bash
# 1. Increment version in pubspec.yaml
# 2. Clean and build
flutter clean
flutter pub get
flutter build appbundle --release

# Output: build/app/outputs/bundle/release/app-release.aab
```

---

## 📤 Upload Instructions

### TestFlight (iOS)

**Option 1: Using Transporter App (Easiest)**
1. Download "Transporter" from Mac App Store
2. Open Transporter and sign in with your Apple ID
3. Drag and drop the `.ipa` file from `build/ios/ipa/`
4. Click "Deliver"

**Option 2: Using Xcode**
1. Run `./build_release.sh xcode`
2. In Xcode: Product → Archive
3. Window → Organizer
4. Select your archive → Distribute App → App Store Connect

**Option 3: Command Line**
```bash
xcrun altool --upload-app \
  -f build/ios/ipa/restaurantadmin.ipa \
  -t ios \
  -u YOUR_APPLE_ID \
  -p YOUR_APP_SPECIFIC_PASSWORD
```

### Google Play (Android)

1. Go to [Google Play Console](https://play.google.com/console)
2. Select your app
3. Go to "Release" → "Production" (or Testing track)
4. Click "Create new release"
5. Upload the `.aab` file from `build/app/outputs/bundle/release/`
6. Add release notes
7. Review and roll out

---

## 🔢 Version Numbers

The version format is: `MAJOR.MINOR.PATCH+BUILD`

Example: `1.0.1+2`
- `1` = Major version (breaking changes)
- `0` = Minor version (new features)
- `1` = Patch version (bug fixes)
- `2` = Build number (must increment for each upload)

**Important:** 
- iOS: Build number must be unique for each TestFlight upload
- Android: Build number (versionCode) must be higher than previous upload

---

## 🔑 Prerequisites

### iOS
- Xcode installed
- Apple Developer account
- App registered in App Store Connect
- Signing certificates and provisioning profiles configured

### Android
- Android Studio installed (for keystore)
- Google Play Developer account
- App created in Google Play Console
- Keystore file configured in `android/key.properties`:

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=YOUR_KEY_ALIAS
storeFile=/path/to/your/keystore.jks
```

---

## 🐛 Troubleshooting

### iOS Build Fails
```bash
# Clean iOS build
cd ios
rm -rf Pods Podfile.lock
pod install
cd ..
flutter clean
flutter pub get
flutter build ipa --release
```

### Android Build Fails
```bash
# Clean Android build
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
flutter build appbundle --release
```

### Version Conflict
Make sure to increment version number in `pubspec.yaml`:
```yaml
version: 1.0.2+3  # Change this before each release
```

---

## 📁 Output Files Location

| Platform | File Type | Location |
|----------|-----------|----------|
| iOS | IPA | `build/ios/ipa/restaurantadmin.ipa` |
| Android | AAB | `build/app/outputs/bundle/release/app-release.aab` |
| Android | APK | `build/app/outputs/flutter-apk/app-release.apk` |

---

## ⚡ Super Quick Reference

```bash
# iOS to TestFlight
./build_release.sh ios

# Android to Play Store  
./build_release.sh android

# Check version
./build_release.sh status

# Open Xcode
./build_release.sh xcode
```





