# Fix Xcode Push Notifications Configuration

## The Problem:
iOS is not providing an APNS token, which means the Push Notifications capability is not properly configured in Xcode.

## Solution - Configure Xcode:

### Step 1: Open Xcode
```bash
open /Users/youssefelhenawy/Desktop/restaurantadmin/ios/Runner.xcworkspace
```

**IMPORTANT:** Open `Runner.xcworkspace`, NOT `Runner.xcodeproj`!

### Step 2: Select the Runner Target
1. In the left sidebar, click on **Runner** (the blue icon at the top)
2. Make sure **Runner** target is selected (not the project)

### Step 3: Go to Signing & Capabilities Tab
1. Click on the **"Signing & Capabilities"** tab at the top
2. You should see your Team: **Youssef Elhenawy (G67XQ5S4QU)**

### Step 4: Add Push Notifications Capability
1. Click the **"+ Capability"** button (top left of the capabilities section)
2. Search for **"Push Notifications"**
3. Double-click to add it
4. You should now see "Push Notifications" in the list of capabilities

### Step 5: Verify Entitlements
After adding Push Notifications, Xcode should automatically update the entitlements file.

Check that `ios/Runner/RunnerRelease.entitlements` contains:
```xml
<key>aps-environment</key>
<string>production</string>
```

### Step 6: Clean and Rebuild
In Xcode:
1. **Product** → **Clean Build Folder** (Shift + Cmd + K)
2. Close Xcode

Then in terminal:
```bash
cd /Users/youssefelhenawy/Desktop/restaurantadmin
flutter clean
flutter pub get
flutter run --release -d 00008110-000E75111E10401E
```

### Step 7: Verify
After the app launches, you should see:
```
[PushNotification] APNS Token received: ...
[PushNotification] FCM Token: ...
[PushNotification] Token registered successfully
```

**NOT:**
```
[PushNotification] WARNING: APNS token not available after retries
```

## If Still Not Working:

### Check 1: Verify Provisioning Profile
In Xcode, under Signing & Capabilities:
- Make sure "Automatically manage signing" is checked
- Verify a provisioning profile is selected
- The profile should include Push Notifications

### Check 2: Check Apple Developer Account
Go to: https://developer.apple.com/account/resources/identifiers/list
1. Find your app ID: `com.mycoolrestaurant.adminapp`
2. Click on it
3. Make sure **"Push Notifications"** is checked in the capabilities list
4. If not, check it and click "Save"
5. Then regenerate your provisioning profile in Xcode

### Check 3: Try Debug Mode
Instead of `--release`, try debug mode:
```bash
flutter run -d 00008110-000E75111E10401E
```

Debug mode uses Development APNs, which might work better during testing.

## Expected Result:
After properly configuring Xcode, iOS will provide an APNS token, which Firebase will convert to an FCM token, and notifications will work!

