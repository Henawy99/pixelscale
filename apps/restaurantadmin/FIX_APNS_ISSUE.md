# Fix APNS Token Issue - Step by Step

## Problem
The app cannot get an APNS token, which is required for iOS push notifications. This happens because:
1. The app needs proper entitlements configured in Xcode
2. Push notification capability must be enabled
3. The app must be properly signed with a valid provisioning profile

## Solution Steps

### Step 1: Open Xcode Project
1. Navigate to: `/Users/youssefelhenawy/Desktop/restaurantadmin/ios/`
2. Open `Runner.xcworkspace` (NOT Runner.xcodeproj)

### Step 2: Enable Push Notifications Capability
1. In Xcode, select the **Runner** project in the left sidebar
2. Select the **Runner** target
3. Click on the **Signing & Capabilities** tab
4. Click the **+ Capability** button
5. Search for and add **Push Notifications**
6. This will automatically create/update your entitlements file

### Step 3: Verify Entitlements
1. In the project navigator, look for `Runner/RunnerRelease.entitlements`
2. It should contain:
   ```xml
   <?xml version="1.0" encoding="UTF-8"?>
   <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
   <plist version="1.0">
   <dict>
       <key>aps-environment</key>
       <string>production</string>
   </dict>
   </plist>
   ```

### Step 4: Verify Signing
1. Still in **Signing & Capabilities** tab
2. Make sure **Automatically manage signing** is checked
3. Select your Team (Youssef Elhenawy)
4. Make sure the Bundle Identifier matches: `com.example.restaurantadmin`
5. Verify that a valid provisioning profile is selected

### Step 5: Clean and Rebuild
1. In Xcode: **Product → Clean Build Folder** (Shift + Cmd + K)
2. Close Xcode
3. In terminal, from the project root:
   ```bash
   cd ios
   pod deintegrate
   pod install
   cd ..
   flutter clean
   flutter pub get
   ```

### Step 6: Build and Run
```bash
flutter run --release -d 00008110-000E75111E10401E
```

### Step 7: Verify in Firebase
1. After the app launches, check the logs for:
   ```
   [PushNotification] APNS Token received: ...
   [PushNotification] FCM Token: ...
   [PushNotification] Token registered successfully
   ```

2. Verify token is registered in Supabase:
   - Go to: https://supabase.com/dashboard/project/YOUR_PROJECT_ID/editor
   - Run: `SELECT * FROM device_tokens;`
   - You should see a row with platform='ios'

## Testing Push Notifications
1. Go to the admin app (must be logged in as youssef@gmail.com)
2. Open Test Receipt Scanner
3. Upload a receipt
4. Press "Save to Receipt Watcher"
5. You should receive a push notification on your iPhone

## Troubleshooting

### If you still get "APNS token not set":
1. Make sure you're signed in as youssef@gmail.com (notifications only work for admin)
2. Check that notifications are allowed in iPhone Settings → Your App → Notifications
3. Verify the APNs key in Firebase Console is uploaded to **Production** section
4. Try uninstalling and reinstalling the app

### If token is not registered in Supabase:
1. Check the edge function logs for errors
2. Verify the Firebase service account JSON is correctly set as a Supabase secret
3. Make sure RLS is disabled on the device_tokens table:
   ```sql
   ALTER TABLE device_tokens DISABLE ROW LEVEL SECURITY;
   ```

