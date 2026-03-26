# PixelScale — Apps Overview & Rules

> **Monorepo structure**: All apps live in `apps/`. Use the root `pm` script to run or build any app interactively from the `pixelscale/` root.

---

## 📁 Repository Layout

```
pixelscale/
├── pm                    ← Root CLI: run/build any app
├── APPS.md               ← This file — app overview & rules
├── apps/
│   ├── animight/         ← Anime streaming + community app (Flutter)
│   ├── playmaker/        ← Sports-facility booking platform (Flutter)
│   ├── restaurantadmin/  ← Restaurant back-office & order manager (Flutter)
│   └── tennisacademyapp/ ← Tennis-academy management app (Flutter)
└── shared/               ← Shared resources / scripts
```

---

## 🚀 Quick Start (from `pixelscale/` root)

```bash
./pm run        # Interactive: pick an app → run in dev mode
./pm build      # Interactive: pick an app → build for iOS or Android
./pm build-all  # Build all apps for both platforms
./pm list       # Show all registered apps
```

---

## 📱 App Catalogue

---

### 1. Animight
| Field         | Value |
|---------------|-------|
| **Path**      | `apps/animight/` |
| **Type**      | Flutter |
| **Version**   | `1.0.0+2` |
| **Bundle ID** | `com.example.animight` |
| **Apple ID**  | `6749167305` |
| **Team ID**   | `G67XQ5S4QU` |
| **Backend**   | Supabase |
| **Platforms** | iOS · Android |

**Description**  
Animight is an anime-focused mobile app featuring anime streaming, a social community, Bluetooth-enabled features (via `flutter_blue_plus`), AI-assisted content, and a custom splash screen experience with video playback. It targets anime enthusiasts with rich media and interactive content.

**Key Dependencies**: `video_player`, `flutter_blue_plus`, `supabase_flutter`, `cached_network_image`, `image_picker`

**Run & Build Commands**
```bash
# From apps/animight/
./pm                                               # Interactive menu
./pm run                                           # Run in dev mode
./pm ios                                           # Build + Upload to TestFlight
./pm android                                       # Build + Upload to Play Console
./build_ios.sh                                     # Build iOS release (wrapper)
./build_android.sh                                 # Build Android release (wrapper)

# iOS Pipeline (Fastlane)
cd fastlane && bundle exec fastlane ios upload      # Build + upload to TestFlight
cd fastlane && bundle exec fastlane ios upload_only # Upload existing IPA only
cd fastlane && bundle exec fastlane ios tf          # Alias for upload

# Android Pipeline (Fastlane)
cd android && bundle exec fastlane upload           # Build + upload to Play Console
cd android && bundle exec fastlane build            # Build AAB only
cd android && bundle exec fastlane upload_only      # Upload existing AAB only
```

---

### 2. Playmaker
| Field         | Value |
|---------------|-------|
| **Path**      | `apps/playmaker/` |
| **Type**      | Flutter |
| **Version**   | `1.0.7+1` |
| **Bundle ID (User)**  | `com.playmaker.start` |
| **Bundle ID (Mgmt)**  | `com.playmaker.admin` |
| **Team ID**   | `G67XQ5S4QU` |
| **Backend**   | Firebase + Supabase |
| **Platforms** | iOS · Android |

**Description**  
Playmaker is a feature-rich sports-facility booking platform. It ships **two iOS targets** from a single Flutter codebase: a **User App** (players book pitches, pay, and watch recordings) and a **Management App** (admins/partners manage facilities, schedule, and live camera feeds). Integrations include Firebase Auth, Google/Apple Sign-In, Paymob Native SDK, Google Maps, FCM notifications, Cloudinary video, and localization.

**Key Dependencies**: `firebase_core`, `firebase_auth`, `google_sign_in`, `sign_in_with_apple`, `supabase_flutter`, `google_maps_flutter`, `firebase_messaging`, `flutter_vlc_player`, `pay` (Apple/Google Pay), `bloc`, `intl`

**Run & Build Commands**
```bash
# From apps/playmaker/
./pm                                                       # Interactive menu (if pm present)
./build_ios.sh                                             # Build + upload USER app to TestFlight
./build_android.sh                                         # Build + upload to Play Console

# iOS Pipeline (Fastlane)
cd fastlane && bundle exec fastlane ios upload_user        # Upload USER app to TestFlight
cd fastlane && bundle exec fastlane ios upload_management  # Upload MANAGEMENT app to TestFlight
cd fastlane && bundle exec fastlane ios user               # Alias
cd fastlane && bundle exec fastlane ios management         # Alias

# Android Pipeline (Fastlane)
cd android && bundle exec fastlane upload                  # Build + upload to Play Console (User)
cd android && bundle exec fastlane build                   # Build AAB only
```

> ⚠️ **Two App Store entries**: The USER app targets `com.playmaker.start` and the MANAGEMENT app targets `com.playmaker.admin`. Always use the correct Fastlane lane per target.

---

### 3. Restaurant Admin
| Field         | Value |
|---------------|-------|
| **Path**      | `apps/restaurantadmin/` |
| **Type**      | Flutter |
| **Version**   | `1.0.6+1` |
| **Bundle ID** | `com.mycoolrestaurant.adminapp` |
| **Team ID**   | `G67XQ5S4QU` |
| **API Key ID**| `6RM87HWDZY` |
| **Backend**   | Supabase + Firebase |
| **Platforms** | iOS · Android · Web (Netlify) |

**Description**  
A comprehensive restaurant back-office and order-management app. Features include QR-code scanning (Google ML Kit), AI-powered menu suggestions (Google Generative AI), live order tracking with maps, PDF printing, push notifications, and a multi-format file manager. Supports mobile, desktop, and web.

**Key Dependencies**: `supabase_flutter`, `firebase_messaging`, `google_mlkit_text_recognition`, `google_generative_ai`, `google_maps_flutter`, `printing`, `hive`, `geolocator`, `flutter_foreground_task`, `file_picker`

**Run & Build Commands**
```bash
# From apps/restaurantadmin/
./build_ios_release.sh                                    # Build iOS + prompt to upload to TestFlight
./build_ios_release.sh --upload                           # Build iOS + auto-upload to TestFlight
./build_android_release.sh                                # Build Android + prompt to upload to Play Store
./build_android_release.sh --upload                       # Build Android + auto-upload to Play Store

# iOS Pipeline (Fastlane)
cd fastlane && bundle exec fastlane ios upload_app        # Build + upload to TestFlight
cd fastlane && bundle exec fastlane ios build_only        # Build IPA without uploading

# Android Pipeline (Fastlane — android/fastlane/)
cd android && bundle exec fastlane upload                 # Upload AAB to Play Store (Internal)
```

**Run in dev**
```bash
./run_app.sh           # iOS dev
./run_app_android.sh   # Android dev
./run_app_web.sh       # Web dev
```

---

### 4. Tennis Academy App
| Field         | Value |
|---------------|-------|
| **Path**      | `apps/tennisacademyapp/` |
| **Type**      | Flutter |
| **Version**   | `1.0.0+1` |
| **Bundle ID** | `com.pixelscale.tennisacademy` |
| **Team ID**   | `G67XQ5S4QU` |
| **Backend**   | Supabase |
| **Platforms** | iOS · Android |

**Description**  
A tennis-academy management app for coaches and students. Tracks sessions, player progress, booking, and academy administration. Lightweight and focused, with Supabase as the sole backend service.

**Key Dependencies**: `supabase_flutter`, `provider`, `image_picker`, `intl`, `uuid`

**Run & Build Commands**
```bash
# From apps/tennisacademyapp/
./pm                                                      # Interactive menu
./run.sh                                                  # Run on connected device
./build-android-release.sh                                # Build release APK
./build_ios.sh                                            # Build iOS + upload to TestFlight
./build_android.sh                                        # Build Android + upload to Play Console

# iOS Pipeline (Fastlane)
cd fastlane && bundle exec fastlane ios upload            # Build + upload to TestFlight

# Android Pipeline (Fastlane — android/fastlane/)
cd android && bundle exec fastlane upload                 # Build + upload to Play Console
```

---

## 🔧 Global `pm` Commands (from `pixelscale/` root)

```bash
./pm                   # Interactive menu
./pm run               # Pick any app to run in dev mode
./pm build             # Pick any app + platform to build for release
./pm build-all         # Build all apps (iOS + Android)
./pm list              # List all registered apps
./pm help              # Show all commands
```

Build commands per platform:
```bash
./pm ios       # Build all iOS apps → TestFlight
./pm android   # Build all Android apps → Play Console
```

---

## ⚙️ Release Pipeline Architecture

```
pixelscale/
└── apps/<app>/
    ├── build_ios.sh           ← Wrapper: flutter build ios + Fastlane to TestFlight
    ├── build_android.sh       ← Wrapper: flutter build appbundle + Fastlane to Play Console
    ├── fastlane/
    │   ├── Appfile            ← Bundle ID, Team ID
    │   └── Fastfile           ← iOS lanes: upload, upload_only, build_only
    └── android/fastlane/
        ├── Appfile            ← Play Store package name, credentials path
        └── Fastfile           ← Android lanes: upload, build, upload_only
```

### iOS → TestFlight
1. `flutter build ios --release --no-codesign`
2. `gym` archives + exports IPA (automatic signing, Team ID `G67XQ5S4QU`)
3. `upload_to_testflight` sends to App Store Connect
4. Build appears in TestFlight within 5–15 min

### Android → Play Console
1. `flutter build appbundle --release`
2. `supply` uploads `.aab` to **Internal Testing** track
3. Promote to Alpha/Beta/Production in Play Console

---

## 🔑 Credentials Reference

| Secret | Location | Used By |
|--------|----------|---------|
| App Store Connect API Key `.p8` | `~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8` | All iOS Fastlane |
| Play Store JSON credentials | `~/.play-store/play-store-credentials.json` | All Android Fastlane |
| Supabase URL + Anon Key | `.env` / `pubspec.yaml` env loading | animight, restaurantadmin, tennisacademy |
| Firebase `google-services.json` | `android/app/` per app | playmaker, restaurantadmin |
| Firebase `GoogleService-Info.plist` | `ios/Runner/` per app | playmaker, restaurantadmin |

> 🔒 **Never commit credentials.** All secrets must be in `.gitignore`-protected files or environment variables.

---

## 📋 Rules & Conventions

1. **One app per subfolder** under `apps/`. No cross-app imports.
2. **Always run from the app's own directory** when using `flutter` directly (e.g., `cd apps/animight && flutter run`).
3. **Use the root `./pm`** for interactive build/run from the monorepo root.
4. **Version bump**: Update `version: X.Y.Z+N` in `pubspec.yaml` before every release build. Android release scripts auto-increment.
5. **iOS builds require macOS + Xcode** with valid Apple Developer account.
6. **Android builds** need a valid `upload-keystore.jks` and `key.properties` in `android/`.
7. **Fastlane must be installed**: Run `bundle install` inside the app dir (or `android/` for Android lanes) before first use.
8. **Play Store first upload must be manual** — `supply` requires at least one version already in the console.
9. **TestFlight builds** are processed by Apple (5–15 min delay) — `skip_waiting_for_build_processing: true` is set by default to avoid timeouts.
10. **Do not mix Flutter SDK versions** across apps without updating `.flutter-version` per app.

---

## 🛠 Setup Checklist (New Machine)

```bash
# 1. Install Flutter (via FVM or directly)
# 2. Install Ruby + Bundler
gem install bundler

# 3. For each app, install Fastlane deps
cd apps/<app> && bundle install
cd apps/<app>/android && bundle install   # for Android lane

# 4. Place credentials
mkdir -p ~/.appstoreconnect/private_keys
cp AuthKey_<KEY_ID>.p8 ~/.appstoreconnect/private_keys/
mkdir -p ~/.play-store
cp play-store-credentials.json ~/.play-store/

# 5. Make scripts executable
chmod +x pm apps/*/pm apps/*/build_ios.sh apps/*/build_android.sh
```
