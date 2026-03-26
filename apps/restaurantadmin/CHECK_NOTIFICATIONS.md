# Check Why Notifications Aren't Arriving

## Step 1: Check iPhone Settings

**On your iPhone:**
1. Go to **Settings** → **Notifications**
2. Scroll down and find **"Restaurantadmin"** (or your app name)
3. Check:
   - ✅ **Allow Notifications** should be ON (green)
   - ✅ **Lock Screen** should be checked
   - ✅ **Notification Center** should be checked
   - ✅ **Banners** should be checked
   - ✅ **Sounds** should be ON
   - ✅ **Badges** should be ON

**Take a screenshot and send it if possible**

## Step 2: Check Do Not Disturb / Focus Mode

1. Swipe down from top-right (Control Center)
2. Make sure **Focus** (moon icon) is OFF
3. Or if Focus is ON, make sure your app is allowed

## Step 3: Test the Notification Right Now

Let's test together:

1. **On Chrome or iPhone**, go to "Test Receipt Scanner"
2. Upload this test receipt: any receipt image
3. **Immediately after pressing "Save to Receipt Watcher":**
   - Check your iPhone screen
   - Pull down from the top to see Notification Center
   - Check the lock screen

## Step 4: Check Supabase Edge Function Logs

Go to:
https://supabase.com/dashboard/project/iluhlynzkgubtaswvgwt/functions/send-push-notification/logs

Look for:
- Recent invocations
- Any error messages
- Response codes

**Copy and paste any errors you see**

## Step 5: Check the Terminal/Console

When you save a receipt, look for these lines:

**Expected (SUCCESS):**
```
[PushNotification] Sending notification: order, Amount: €XX.XX
[PushNotification] Response: {ok: true, success: 1, failed: 0}
```

**If you see:**
```
success: 0, failed: 1
```
This means the notification failed to send.

## Step 6: Verify the Token is Valid

Run this SQL in Supabase:
```sql
SELECT 
  token,
  platform,
  created_at,
  updated_at,
  (updated_at > NOW() - INTERVAL '1 hour') as is_recent
FROM device_tokens 
WHERE platform = 'ios'
ORDER BY updated_at DESC 
LIMIT 1;
```

The token should be:
- `platform`: ios
- `is_recent`: true (updated within last hour)

## Common Issues:

### Issue 1: Notifications Disabled in iPhone Settings
**Fix:** Go to Settings → Notifications → Your App → Turn ON

### Issue 2: Focus/Do Not Disturb is ON
**Fix:** Disable Focus mode or add your app to allowed apps

### Issue 3: App is in Foreground
**Note:** Some notifications don't show when the app is open. Try:
- Close the app (swipe up to kill it)
- Lock your iPhone
- Then save a receipt from Chrome
- You should see notification on lock screen

### Issue 4: Firebase Service Account Not Configured
**Check:** Supabase secrets have `FIREBASE_SERVICE_ACCOUNT_JSON`

### Issue 5: SenderId Mismatch
**Check:** `GoogleService-Info.plist` matches your Firebase project

## Next Steps:

Please check **Step 1** and **Step 3** first, then let me know:
1. Are notifications enabled in iPhone Settings?
2. Do you see any notification when you test?
3. What do the Supabase edge function logs show?

