# SIMPLE TEST - Debug Mode

## What I Just Did:
1. Created `RunnerDebug.entitlements` with `development` environment
2. Running app in **DEBUG mode** (not release)
3. This uses Development APNs keys which are simpler

## What to Do NOW:

### Step 1: Wait for App to Launch
The app is currently building and will install on your iPhone.

### Step 2: Watch Terminal Logs
Look for:
```
[PushNotification] APNS Token received: ...
[PushNotification] FCM Token: ...
[PushNotification] Token registered successfully
```

### Step 3: Test Notification
1. **IMPORTANT: Close the app on iPhone** (swipe up, kill it)
2. **Lock your iPhone**
3. **On Chrome**, go to: http://localhost:3000 (or your web app URL)
4. Login as youssef@gmail.com
5. Go to "Test Receipt Scanner"
6. Upload ANY receipt image
7. Wait for AI to process
8. Click "Save to Receipt Watcher"
9. **CHECK YOUR LOCKED IPHONE** - notification should appear!

### Step 4: Check Edge Function Logs
Go to: https://supabase.com/dashboard/project/iluhlynzkgubtaswvgwt/functions/send-push-notification/logs

Look for:
- ✅ `[FCM] Notification sent. Success: 1, Failed: 0`
- ❌ If still errors, copy and paste them

## Why Debug Mode Might Work:

- **Release mode** = Production APNs keys = More strict
- **Debug mode** = Development APNs keys = More lenient
- Easier to test during development

## If This Works:

Then the issue is specifically with Production APNs configuration. We can fix that after we confirm debug mode works.

## If This Still Doesn't Work:

Then we need to check:
1. iPhone notification settings
2. Do Not Disturb mode
3. Firebase project configuration
4. Or there's a deeper iOS issue

## Current Status:
App is building in debug mode...
Wait for it to launch on your iPhone, then follow Step 3 above!

