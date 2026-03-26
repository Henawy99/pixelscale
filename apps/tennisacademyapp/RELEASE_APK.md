# Building a release APK (Academy App)

The release APK is a **standalone** build: when you install and open it on a device, the app runs without a computer or Metro. All JavaScript is bundled inside the APK.

## Quick build (local)

1. **Prerequisites**
   - Node.js and npm installed
   - Android SDK (e.g. via Android Studio). Set `ANDROID_HOME` if needed:
     ```bash
     export ANDROID_HOME=$HOME/Library/Android/sdk   # macOS
     ```

2. **Run the build**
   ```bash
   cd apps/academy-app
   chmod +x build-release-apk.sh
   ./build-release-apk.sh
   ```
   Or: `npm run build:apk`

3. **Output**
   - APK path: `android/app/build/outputs/apk/release/app-release.apk`
   - Install on a connected device: `adb install -r android/app/build/outputs/apk/release/app-release.apk`
   - Or copy the APK to your phone and open it to install.

The first build can take **5–10 minutes**. Later builds are faster.

## Alternative: EAS Build (cloud)

If you use [Expo Application Services](https://expo.dev):

```bash
npx eas build --platform android --profile preview --non-interactive
```

This produces an APK (or download link) that you can install the same way. Requires an Expo account and `eas login`.

## Making sure the app “opens and works”

- The app uses **Supabase** with a fixed URL and anon key in code; no dev server is needed in release.
- The entry point is `expo-router/entry`; the release build embeds the JS bundle, so the app loads normally when opened.
- If you see a white screen or crash on open, check device logs: `adb logcat *:E` or run the app in debug first to confirm behavior.
