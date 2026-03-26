# PixelScale - Multi-App Workspace

All apps. One workspace. Ship fast.

**Cursor / VS Code:** Open the **`pixelscale`** folder (File → Open Folder) so the file view shows both **academy-app** and **amazon-manager**. Say which app you're working on at the start of a chat; the AI will stay in that app until you say to switch.

---

## Quick Commands - Copy & Paste Ready

**All build scripts auto-increment version & build numbers!**

**Automated uploads to both stores!**

| Platform | Status | Setup |
|----------|--------|-------|
| **Android** (Play Console) | Auto-upload to Internal Testing | `./scripts/setup-publishing.sh` |
| **iOS** (TestFlight) | Auto-upload to TestFlight | `./scripts/setup-publishing.sh` |

**One-time setup:**
```bash
./scripts/setup-publishing.sh
source ~/.zshrc
```

---

## Interactive Command Menu

**Just type `pm` and select from a menu!**

```bash
# Main menu
./pm

# Or use direct commands:
./pm run        # Interactive menu to run an app
./pm build      # Interactive menu to build an app
./pm build-all  # Build ALL apps (iOS + Android)
./pm create     # Create a new app from template
./pm list       # List all installed apps
./pm help       # Show help
```

### Global Aliases (after running setup)
- `pm` - Main menu
- `pmrun` - Quick run menu
- `pmbuild` - Quick build menu
- `pmbuildall` - Build everything

---

## Apps

| App | Framework | Dev | iOS Build | Android Build |
|-----|-----------|-----|-----------|---------------|
| **Academy App** | Expo (RN) | `cd apps/academy-app && ./run.sh` | `cd apps/academy-app && ./build_ios.sh` | `cd apps/academy-app && ./build_android.sh` |
| **Amazon Manager** | Flutter | `cd apps/amazon-manager && ./run.sh` | `cd apps/amazon-manager && ./build_ios.sh` | `cd apps/amazon-manager && ./build_android.sh` |

### Academy App
Tennis Academy. Players choose level, book weekly slots; admins manage court schedules and approve registrations.
- **Framework:** React Native (Expo)
- **Bundle ID:** `com.academy.app`
- **Supabase tables:** no prefix (legacy)

### Amazon Manager
Amazon profile and order management.
- **Framework:** Flutter
- **Bundle ID:** `com.amazonmanager.app`
- **Supabase tables:** `amazon_` prefix

---

## Create a New App

```bash
./scripts/create-app.sh my-app "My App Name" com.pixelscale.myapp
```

**What it does:**
1. Copies the `_template` scaffold (React Native/Expo)
2. Replaces all placeholders (name, slug, bundle ID)
3. Sets up Supabase connection (shared project)
4. Creates run.sh, build_ios.sh, build_android.sh
5. Installs npm dependencies
6. Ready to code!

---

## Build All Apps

```bash
# Both platforms
./scripts/build-all.sh

# iOS only
./scripts/build-all.sh ios

# Android only
./scripts/build-all.sh android
```

---

## Architecture

```
pixelscale/
├── README.md                    # This file
├── pm                           # Interactive project manager
├── .gitignore
├── shared/
│   ├── supabase.config.ts       # Shared Supabase credentials (TypeScript)
│   ├── supabase.config.dart     # Shared Supabase credentials (Dart)
│   ├── eas.base.json            # Base EAS build config
│   └── fastlane/
│       └── common.rb            # Shared Fastlane helpers
├── apps/
│   ├── academy-app/             # Padel & Football training
│   ├── amazon-manager/          # Amazon order management
│   └── _template/               # Template for new Expo apps
└── scripts/
    ├── create-app.sh            # Scaffold new app
    ├── build-all.sh             # Build everything
    └── setup-publishing.sh      # Configure store uploads + aliases
```

## Supabase

All apps share one Supabase project. Data isolation via table prefixes:

| App | Prefix | Example Tables |
|-----|--------|----------------|
| academy-app | *(none - legacy)* | `profiles`, `bookings`, `training_sessions` |
| amazon-manager | `amazon_` | `amazon_profiles`, `amazon_orders` |
| *new apps* | `appslug_` | Auto-configured by create-app.sh |

**Supabase Dashboard:** https://supabase.com/dashboard/project/hdmycuncdlbefiiwlrca

---

## Publishing Pipeline

Each build script:
- Auto-increments version number (e.g., 1.0.44 -> 1.0.45)
- Version regression protection (prevents going backwards)
- Builds the release binary
- Uploads to the store automatically (if configured)

| Step | Expo (RN) Apps | Flutter Apps |
|------|----------------|--------------|
| Version bump | Updates `app.json` | Updates `pubspec.yaml` |
| iOS build | `eas build --platform ios` | `flutter build ios` |
| iOS upload | `eas submit --ios` | Fastlane / Xcode Organizer |
| Android build | `eas build --platform android` | `flutter build appbundle` |
| Android upload | `eas submit --android` | Fastlane supply |
