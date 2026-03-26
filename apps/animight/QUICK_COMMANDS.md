# QUICK COMMANDS - Animight

**Automated build and upload to App Store (TestFlight) and Google Play Console.**

| Platform | Action | Command |
|----------|--------|---------|
| **Android** (Play Console) | Build + Upload to Internal Testing | `cd android && bundle exec fastlane upload` |
| **iOS** (TestFlight) | Build + Upload to TestFlight | `cd fastlane && bundle exec fastlane ios upload` |

---

## Interactive Menu

```bash
./pm
```

Or use direct shortcuts:

```bash
./pm run        # Run on device/simulator
./pm build      # Build menu with all options
./pm ios        # Build + Upload to TestFlight
./pm android    # Build + Upload to Play Console
./pm help       # Show help
```

---

## One-Time Setup

### 1. Install Fastlane

```bash
gem install bundler
bundle install
```

### 2. iOS — App Store Connect API Key

1. Go to [App Store Connect → Users and Access → Keys](https://appstoreconnect.apple.com/access/api)
2. Create an API key (App Manager role)
3. Download the `.p8` file → save to `~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8`
4. Update `fastlane/Fastfile` with your `API_KEY_ID`, `API_KEY_ISSUER_ID`
5. Update `fastlane/Appfile` with your `team_id`

### 3. Android — Google Play Service Account

1. Go to [Google Play Console → Setup → API access](https://play.google.com/console/developers/api-access)
2. Link to a Google Cloud project and create a service account
3. Grant the service account **Release manager** permissions
4. Download the JSON key → save to `android/animight-play-console-service-account.json`

---

## iOS Commands

### Build + Upload to TestFlight

```bash
cd fastlane
bundle exec fastlane ios upload
```

### Upload Existing IPA (Skip Build)

```bash
cd fastlane
bundle exec fastlane ios upload_only
```

### Manual Flutter Build Only

```bash
flutter build ios --release --no-codesign
```

---

## Android Commands

### Build + Upload to Play Console (Internal Testing)

```bash
cd android
bundle exec fastlane upload
```

### Build AAB Only (No Upload)

```bash
cd android
bundle exec fastlane build
```

### Upload Existing AAB (Skip Build)

```bash
cd android
bundle exec fastlane upload_only
```

### Manual Flutter Build Only

```bash
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

---

## Development Run Commands

### Run on Connected Device (Auto-detect)

```bash
flutter run
```

### Run on Specific Platform

```bash
flutter run -d ios        # iOS simulator/device
flutter run -d android    # Android emulator/device
```

### List Available Devices

```bash
flutter devices
```

---

## Version Management

Version is defined in `pubspec.yaml`:

```yaml
version: 1.0.0+2
#        ^ ^  ^ build number (versionCode)
#        | version name (versionName)
```

To release a new version, increment manually before building:

```yaml
version: 1.0.1+3
```

---

## File Locations

| File | Purpose |
|------|---------|
| `fastlane/Fastfile` | iOS Fastlane lanes |
| `fastlane/Appfile` | iOS App Store credentials |
| `android/fastlane/Fastfile` | Android Fastlane lanes |
| `android/fastlane/Appfile` | Android Play Console credentials |
| `android/animight-play-console-service-account.json` | Google Play service account (add manually) |
| `Gemfile` | Ruby gem dependencies for Fastlane |
| `pubspec.yaml` | Flutter version / dependencies |

---

## Troubleshooting

### iOS: API key not found

```
Check fastlane/Fastfile — update API_KEY_ID and API_KEY_ISSUER_ID
Ensure ~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8 exists
```

### iOS: Signing issue

```
Open ios/Runner.xcworkspace in Xcode
Runner target → Signing & Capabilities
Enable "Automatically manage signing"
Select your Team
```

### Android: Service account JSON not found

```
Place your JSON at: android/animight-play-console-service-account.json
```

### Android: Version code already exists

```
Increment the version in pubspec.yaml and rebuild
```
