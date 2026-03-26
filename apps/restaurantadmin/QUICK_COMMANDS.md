# QUICK COMMANDS - Restaurant Admin

**ALL BUILD SCRIPTS AUTO-INCREMENT VERSION & BUILD NUMBERS!**

---

## Quick Reference Table

| Platform | Development | Production Build | Auto-Upload |
|----------|-------------|------------------|-------------|
| **iOS** | `./run_app.sh` | `./build_ios_release.sh` | `./build_ios_release.sh --upload` |
| **Android** | `./run_app_android.sh` | `./build_android_release.sh` | `./build_android_release.sh --upload` |
| **Desktop** | `./run_app_desktop.sh` | N/A | N/A |
| **Web** | `r` | `./build_web_release.sh` | `./build_web_release.sh --prod` |

---

## DESKTOP APP (Best for Large Files!)

```bash
./run_app_desktop.sh
```

**Why use Desktop?**
- No CORS errors (reliable uploads)
- Handles large files (no browser limits)
- Native performance (faster)
- Better video processing

---

## What Each Script Does

**Tip:** 
- **Run commands** = Testing, no version change
- **Build commands** = Production build, auto-increments version
- **--upload / --prod** = Build AND auto-upload to store

---

## iOS - BUILD & UPLOAD TO TESTFLIGHT

### Option 1: Build + Auto-Upload (Fastlane)
```bash
./build_ios_release.sh --upload
```

**What happens:**
```
Auto-increments version (1.0.1 -> 1.0.2)
Cleans & builds
Creates IPA via Fastlane
Uploads directly to TestFlight
Check TestFlight in 5-15 minutes!
```

### Option 2: Build + Manual Upload (Xcode)
```bash
./build_ios_release.sh --manual
```

**Then in Xcode:**
1. Select **"Any iOS Device"** (top left)
2. **Product -> Archive**
3. Click **"Distribute App"**
4. Choose **"App Store Connect"** -> Upload
5. Check TestFlight in 5-10 minutes!

### Option 3: Interactive (default)
```bash
./build_ios_release.sh
```
Builds and then asks you: auto-upload or open Xcode.

---

## ANDROID - BUILD & UPLOAD TO PLAY STORE

### Option 1: Build + Auto-Upload (Fastlane)
```bash
./build_android_release.sh --upload
```

**What happens:**
```
Auto-increments version (1.0.1 -> 1.0.2)
Cleans & builds AAB + APK
Uploads AAB to Play Store Internal Testing
Check Play Console to review and promote!
```

### Option 2: Build Only (Manual Upload)
```bash
./build_android_release.sh --manual
```

**Then:**
1. Go to [Google Play Console](https://play.google.com/console)
2. Select your app
3. Create new release in Internal Testing
4. Upload `build/app/outputs/bundle/release/app-release.aab`

### Option 3: Interactive (default)
```bash
./build_android_release.sh
```
Builds and then asks you: auto-upload or manual.

---

## WEB - BUILD & DEPLOY TO NETLIFY

### Option 1: Build + Deploy Production
```bash
./build_web_release.sh --prod
```

### Option 2: Build + Deploy Preview (staging URL)
```bash
./build_web_release.sh --preview
```

### Option 3: Build Only
```bash
./build_web_release.sh --build-only
```

### Option 4: Interactive (default)
```bash
./build_web_release.sh
```

---

## DEVELOPMENT / TESTING

### iOS (Device or Simulator)
```bash
./run_app.sh
```

### Android (Device or Emulator)
```bash
./run_app_android.sh
```

### Desktop (macOS) - RECOMMENDED
```bash
./run_app_desktop.sh
```

### Web (Chrome)
```bash
./run_app_web.sh
```

---

## FIRST-TIME SETUP (Auto-Upload)

```bash
./setup_auto_upload.sh
```

This will:
- Install Fastlane via Bundler
- Check for iOS API Key (.p8 file)
- Check for Android service account JSON
- Check for Netlify CLI
- Provide setup instructions for any missing items

### What You Need:

**For iOS (App Store Connect):**
1. Go to: https://appstoreconnect.apple.com/access/integrations/api
2. Generate an API Key (App Manager or Developer access)
3. Download the `.p8` file
4. Note the **Key ID** and **Issuer ID**
5. Place the key:
```bash
mkdir -p ~/.appstoreconnect/private_keys
mv ~/Downloads/AuthKey_XXXXX.p8 ~/.appstoreconnect/private_keys/
```
6. Update `fastlane/Fastfile` with your Key ID and Issuer ID
7. Update `fastlane/Appfile` with your Team ID

**For Android (Google Play Console):**
1. Go to: Play Console -> Setup -> API access
2. Create a service account
3. Download the JSON key
4. Place it:
```bash
mkdir -p ~/.play-store
mv ~/Downloads/your-key.json ~/.play-store/play-store-credentials.json
```
5. Grant permissions: "Release to production" + "Manage testing"

**For Web (Netlify):**
```bash
npm install -g netlify-cli
netlify login
netlify link    # Link to your Netlify site
```

---

## Current Version

| Platform | Version | Build |
|----------|---------|-------|
| Current | 1.0.8 | 1 |
| Next Build | 1.0.9 | 1 |

---

## Bundle IDs

| Platform | Bundle ID |
|----------|-----------|
| **iOS** | `com.mycoolrestaurant.adminapp` |
| **Android** | `com.example.restaurantadmin` |

---

## Common Workflows

### Release to ALL platforms:

```bash
# First time only
./setup_auto_upload.sh

# iOS -> TestFlight (auto-upload)
./build_ios_release.sh --upload

# Android -> Play Store (auto-upload)
./build_android_release.sh --upload

# Web -> Netlify (production)
./build_web_release.sh --prod
```

### Quick Test on Device:

```bash
# iOS
./run_app.sh

# Android
./run_app_android.sh

# Desktop (recommended)
./run_app_desktop.sh
```

### Using Fastlane Directly:

```bash
# iOS - Upload to TestFlight
cd fastlane && bundle exec fastlane ios upload_app

# iOS - Build only (no upload)
cd fastlane && bundle exec fastlane ios build_only

# Android - Build & Upload to Play Store
cd android && bundle exec fastlane upload_app

# Android - Build only
cd android && bundle exec fastlane build_only

# Android - Upload existing AAB (no build)
cd android && bundle exec fastlane upload_only
```

---

## Script Benefits

### NO MORE:
- "Version already used" errors
- "Bundle version must be higher" errors
- Manual version updates
- Forgetting to increment
- Manual uploads through Xcode or Play Console
- Drag-and-drop to Netlify

### YES TO:
- **Automatic version management**
- **One command = built AND uploaded**
- **Clear version tracking**
- **Never worry about versions again!**
- **Auto-upload to TestFlight, Play Store, and Netlify**

---

## Troubleshooting

**"Permission denied"?**
```bash
chmod +x *.sh
```

**"Check current version"?**
```bash
grep "^version:" pubspec.yaml
```

**"Want to open Xcode manually"?**
```bash
open ios/Runner.xcworkspace
```

**"Build failed - pods issue"?**
```bash
cd ios && pod install --repo-update && cd ..
```

**"Fastlane not found"?**
```bash
./setup_auto_upload.sh
```

**"API Key / credentials issue"?**
```bash
# iOS - Check if key exists
ls ~/.appstoreconnect/private_keys/

# Android - Check if JSON exists
ls ~/.play-store/play-store-credentials.json

# Run setup to see what's missing
./setup_auto_upload.sh
```

---

## All Commands at a Glance

### Development (No Version Change)
```bash
./run_app.sh              # iOS device/simulator
./run_app_android.sh      # Android device/emulator
./run_app_desktop.sh      # macOS desktop (recommended)
./run_app_web.sh          # Chrome browser
```

### Production (Auto-Increments Version)
```bash
./build_ios_release.sh              # iOS -> Interactive
./build_ios_release.sh --upload     # iOS -> Auto-upload TestFlight
./build_ios_release.sh --manual     # iOS -> Open Xcode

./build_android_release.sh          # Android -> Interactive
./build_android_release.sh --upload # Android -> Auto-upload Play Store
./build_android_release.sh --manual # Android -> Manual instructions

./build_web_release.sh              # Web -> Interactive
./build_web_release.sh --prod       # Web -> Deploy to Netlify production
./build_web_release.sh --preview    # Web -> Deploy preview
./build_web_release.sh --build-only # Web -> Build only
```

### Setup & Fastlane
```bash
./setup_auto_upload.sh                            # First-time setup
cd fastlane && bundle exec fastlane ios upload_app # Direct iOS upload
cd android && bundle exec fastlane upload_app      # Direct Android upload
```

---

## App Accounts

| Role | How to Login |
|------|--------------|
| **Admin** | Login with admin email/password |
| **Driver** | Login with driver email/password |
| **Worker** | Login with worker email/password |

**All roles use the same app - routing is automatic based on user type!**

---

## Build Outputs

| Type | Location |
|------|----------|
| iOS IPA | `build/ios/ipa/RestaurantAdmin.ipa` (via Fastlane) |
| iOS Archive | Via Xcode Organizer (manual) |
| Android AAB | `build/app/outputs/bundle/release/app-release.aab` |
| Android APK | `~/Desktop/restaurant-admin-X.X.X.apk` |
| Web | `build/web/` |

---

## File Structure

```
restaurantadmin/
├── Gemfile                          # Ruby deps for iOS Fastlane
├── fastlane/
│   ├── Appfile                      # iOS app config (Bundle ID, Team ID)
│   └── Fastfile                     # iOS lanes (upload_app, build_only)
├── android/
│   ├── Gemfile                      # Ruby deps for Android Fastlane
│   └── fastlane/
│       ├── Appfile                  # Android app config (Package name)
│       └── Fastfile                 # Android lanes (upload_app, build_only, upload_only)
├── setup_auto_upload.sh             # First-time setup script
├── build_ios_release.sh             # Build iOS + optional TestFlight upload
├── build_android_release.sh         # Build Android + optional Play Store upload
├── build_web_release.sh             # Build Web + optional Netlify deploy
├── run_app.sh                       # Run iOS (dev)
├── run_app_android.sh               # Run Android (dev)
├── run_app_desktop.sh               # Run Desktop (dev)
└── run_app_web.sh                   # Run Web (dev)
```

---

**That's it! Just run the script and it builds AND uploads!**

