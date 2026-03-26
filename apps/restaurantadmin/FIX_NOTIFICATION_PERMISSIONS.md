# Fix Notification Permissions Issue

## Problem
The app shows "User declined notifications permission" even though you pressed "Accept". This means iOS thinks notifications are disabled for the app.

## Solution - Reset Notification Permissions on iPhone

### Step 1: Delete the App from iPhone
1. On your iPhone, long-press the app icon
2. Select "Remove App"
3. Choose "Delete App" (this removes all data including permission settings)

### Step 2: Reset All Settings (Optional but Recommended)
If deleting doesn't work, reset location & privacy:
1. Go to **Settings** → **General** → **Transfer or Reset iPhone**
2. Tap **Reset**
3. Tap **Reset Location & Privacy**
4. Enter your passcode
5. Confirm reset

### Step 3: Reinstall the App
Run the app again from Xcode:
```bash
flutter run --release -d 00008110-000E75111E10401E
```

### Step 4: Accept Notification Permission
When the permission dialog appears:
1. **Make sure you tap "Allow"**
2. Watch the console logs for:
   ```
   [PushNotification] APNS Token received: ...
   [PushNotification] FCM Token: ...
   [PushNotification] Token registered successfully
   ```

### Step 5: Verify Permissions in Settings
After accepting:
1. Go to **Settings** → **Notifications**
2. Find your app in the list
3. Make sure:
   - ✅ Allow Notifications is ON
   - ✅ Lock Screen is checked
   - ✅ Notification Center is checked
   - ✅ Banners is checked
   - ✅ Sounds is ON

## Why This Happened

iOS caches notification permission decisions. Once denied (even accidentally), the permission prompt won't show again unless you:
- Delete and reinstall the app
- Or reset privacy settings

The permission dialog only shows **once** per app installation.

## Verification Steps

After reinstalling and accepting permissions:

### 1. Check Console Logs
You should see:
```
[PushNotification] APNS Token received: FEFB64B1C9...
[PushNotification] FCM Token: c4KW-ltZOE...
[PushNotification] Token registered successfully
[PushNotification] Initialized successfully
```

### 2. Check Supabase Database
```sql
SELECT * FROM device_tokens WHERE platform = 'ios';
```
You should see a row with your FCM token.

### 3. Test Notification
1. Go to Test Receipt Scanner
2. Upload a receipt
3. Wait for AI processing
4. Press "Save to Receipt Watcher"
5. **You should get a notification on your iPhone!**

## Expected Success Response

When notifications work, you'll see:
```
[PushNotification] Sending notification: order, Amount: €37.91
[PushNotification] Response: {ok: true, success: 1, failed: 0}
```

Currently you're seeing `success: 0, failed: 4` because:
- iOS rejected the permission
- No valid FCM tokens in the database
- All 4 notification attempts failed

## Troubleshooting

### If you still see "User declined notifications permission":
1. Make sure you deleted the app completely (not just force quit)
2. Try the "Reset Location & Privacy" option
3. Reinstall from scratch

### If APNS token still not available:
1. Make sure you're logged in as `youssef@gmail.com`
2. Check Xcode: Runner target → Signing & Capabilities
3. Verify "Push Notifications" capability is added
4. Check that you have a valid provisioning profile

### If notifications still don't arrive:
1. Verify the APNs key in Firebase is uploaded to **Production** (not Development)
2. Check that the service account JSON is correctly set in Supabase secrets
3. Verify your iPhone is not in Do Not Disturb mode

