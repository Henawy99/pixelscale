# Final Test Steps - Push Notifications

## Current Status:
✅ APNs keys uploaded to Firebase (both Dev & Prod)
✅ Bundle ID matches: `com.mycoolrestaurant.adminapp`
✅ GoogleService-Info.plist is correct
✅ FCM token is being registered in Supabase

## The Problem:
Firebase is rejecting notifications with "BadEnvironmentKeyInToken"

## Solution - Complete Clean Test:

### Step 1: Clean Database
Run in Supabase SQL Editor:
```sql
DELETE FROM device_tokens;
```

### Step 2: Delete App from iPhone
1. On iPhone, long-press the app
2. Remove App → Delete App
3. This clears all cached data

### Step 3: Wait for Firebase
**IMPORTANT:** After uploading APNs keys, Firebase needs 2-5 minutes to process them.
- Check the time you uploaded the keys
- If it was less than 5 minutes ago, **WAIT**

### Step 4: Reinstall App
```bash
cd /Users/youssefelhenawy/Desktop/restaurantadmin
flutter clean
flutter pub get
flutter run --release -d 00008110-000E75111E10401E
```

### Step 5: Login
- Login as `youssef@gmail.com`
- Watch for:
  ```
  [PushNotification] Permission status: AuthorizationStatus.authorized
  [PushNotification] Token registered successfully
  ```

### Step 6: Verify Token in Database
Run in Supabase:
```sql
SELECT * FROM device_tokens ORDER BY created_at DESC LIMIT 1;
```

Should show ONE new token with platform='ios'

### Step 7: Test Notification
1. **Close the app on iPhone** (swipe up, kill it)
2. **Lock your iPhone**
3. **On Chrome**, go to Test Receipt Scanner
4. Upload a receipt
5. Save to Receipt Watcher
6. **Check your locked iPhone screen** - notification should appear!

### Step 8: Check Logs
After saving receipt, check Supabase edge function logs:
https://supabase.com/dashboard/project/iluhlynzkgubtaswvgwt/functions/send-push-notification/logs

Look for:
- ✅ `[FCM] Notification sent. Success: 1, Failed: 0`
- ❌ If still "BadEnvironmentKeyInToken", the keys need more time to propagate

## If Still Not Working:

### Check 1: Verify Keys are for the CORRECT app
In Firebase Console, make sure you're looking at:
- **Restaurant Admin** (com.mycoolrestaurant.adminapp)
- NOT the first app (com.example.restaurantadmin)

### Check 2: Verify Key Details Match
- Key ID: `FZJM33T3Z4`
- Team ID: `G67XQ5S4QU`
- These should match what's in Apple Developer

### Check 3: Try Debug Mode
Instead of `--release`, try:
```bash
flutter run -d 00008110-000E75111E10401E
```
This uses Development APNs keys instead of Production

## Expected Timeline:
- APNs key upload: 0 minutes
- Firebase processing: 2-5 minutes ⏰
- Token registration: immediate after app launch
- Notification test: immediate after save

**If you just uploaded the keys, WAIT 5 minutes before testing!**

