# 🎾 Academy App (Flutter) – Quick Commands

## ⚡ Interactive menu
Run `./pm` for options.

## 🚀 Common commands

### Run
- `flutter run` – Android / iOS (default device)
- `flutter run -d chrome` – Web
- `flutter run -d <device_id>` – Specific device (`flutter devices`)

### Build
- `./build-android-release.sh` – **Release APK (shareable)** – Output: `TennisAcademy-release.apk`; safe to send; recipients can install and open.
- `flutter build apk --debug` – Debug APK
- `flutter build apk --release` – Release APK (raw)
- `flutter build appbundle --release` – Play Store bundle

### Utils
- `flutter pub get` – Install dependencies
- `flutter analyze` – Lint

## 📁 Layout
- **User**: after login (non-admin) → Schedule (view by day/court, join, cancel).
- **Admin**: after login (admin role) → Admin Schedule (CRUD sessions, add/remove players, approve requests).

## 📦 Release signing (optional)
- Without `android/key.properties`, the release APK is signed with the debug key and is **still installable** when you send it.
- For production (e.g. Play Store), copy `android/key.properties.example` to `android/key.properties`, create a keystore, and fill in the values. See the example file for the `keytool` command.

## 🔧 Supabase
- Config: `lib/config/supabase_config.dart` (shared PixelScale project).
- Tables: `sessions`, `session_registrations`, `profiles`, `players`, `session_assignments`.
- Run migration `005_players_and_session_assignments.sql` in Supabase SQL Editor for Schedule + Players (roster and slot assignments).
