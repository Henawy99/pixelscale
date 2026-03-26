# How to upload Animight to your App Store Connect account

Follow these steps to build and upload this app under **your** Apple Developer account.

## What you need

- **Mac** with Xcode installed (Xcode 26 or later recommended for App Store compliance)
- **Flutter** installed ([flutter.dev](https://flutter.dev))
- **Apple Developer account** ($99/year) and access to [App Store Connect](https://appstoreconnect.apple.com)

---

## 1. Open the project and install dependencies

```bash
cd animight
flutter pub get
cd ios && pod install && cd ..
```

---

## 2. Set your Bundle ID and Team in Xcode

1. Open the iOS project in Xcode:
   ```bash
   open ios/Runner.xcworkspace
   ```
   (Use `.xcworkspace`, not `.xcodeproj`.)

2. In the left sidebar, select the **Runner** project (blue icon), then select the **Runner** target.

3. Open the **Signing & Capabilities** tab.

4. **Team**: Choose your Apple Developer team from the "Team" dropdown.  
   If you don’t see it, add your Apple ID in Xcode → Settings → Accounts.

5. **Bundle Identifier**: Change `com.example.animight` to your own (e.g. `com.yourcompany.animight`).  
   This must match an App ID you create (or will create) in your Apple Developer account.

6. If you use a **different** bundle ID, also update it for the **RunnerTests** target (e.g. `com.yourcompany.animight.RunnerTests`).

---

## 3. Create the app in App Store Connect (if needed)

1. Go to [App Store Connect](https://appstoreconnect.apple.com) → **My Apps** → **+** → **New App**.

2. Choose **iOS**, enter app name (e.g. **Animight**), language, and **Bundle ID** — use the same one you set in Xcode (e.g. `com.yourcompany.animight`).

3. Create the app. You can fill in description, screenshots, and pricing later.

---

## 4. Build and archive for release

1. In Xcode, set the run destination to **Any iOS Device (arm64)** (not a simulator).

2. Menu: **Product** → **Archive**.

3. When the archive is done, the **Organizer** window opens. Select the new archive and click **Distribute App**.

4. Choose **App Store Connect** → **Upload** → follow the prompts (keep defaults like “Upload your app’s symbols” and “Manage Version and Build Number”).

5. After the upload finishes, go to App Store Connect → your app → **TestFlight** or **App Store** tab. The new build will appear after processing (often 5–15 minutes).

---

## 5. Optional: build from command line

```bash
flutter build ipa
```

The `.ipa` will be under `build/ios/ipa/`. You can upload it with **Transporter** (Mac App Store) or via Xcode Organizer (Window → Organizer → Distribute App and choose the built IPA).

---

## Troubleshooting

- **“No valid code signing identity”**  
  In Xcode → Signing & Capabilities, make sure **Team** is set and **Automatically manage signing** is on. Xcode will create/use the right provisioning profile.

- **“Bundle ID already in use”**  
  That ID is tied to another account. Use a different bundle ID (e.g. `com.yourcompany.animight`) and create a matching App ID in [developer.apple.com](https://developer.apple.com) → Certificates, Identifiers & Profiles → Identifiers.

- **SDK / ITMS-90725**  
  Build with **Xcode 26** (or the latest Xcode that includes the required iOS SDK) so the build meets App Store requirements.

---

## Summary checklist

- [ ] `flutter pub get` and `pod install` done  
- [ ] Opened `ios/Runner.xcworkspace` in Xcode  
- [ ] Selected your **Team** in Signing & Capabilities  
- [ ] Set **Bundle ID** to your own (e.g. `com.yourcompany.animight`)  
- [ ] Created the app in App Store Connect with the same Bundle ID  
- [ ] Archived with **Product → Archive** and uploaded via **Distribute App**
