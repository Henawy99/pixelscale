# 🚀 QUICK START - Get Push Notifications Working

## The Problem Was Found! ✅

Your `RunnerRelease.entitlements` file had `aps-environment` set to `development` but you're running in **release mode** (`--release` flag).

I've fixed it to `production`. Now you just need to:

## Step 1: Delete the App from Your iPhone

**On your iPhone:**
1. Find the app
2. Long-press the icon
3. Tap "Remove App"
4. Choose **"Delete App"**

This clears the cached "denied permission" that iOS stored.

## Step 2: Run These Commands

```bash
cd /Users/youssefelhenawy/Desktop/restaurantadmin
flutter run --release -d 00008110-000E75111E10401E
```

(flutter clean and pub get are already done)

## Step 3: Accept Notification Permission

When the app launches and asks for notification permission:
- **TAP "ALLOW"** ✅

## Step 4: Watch Console Logs

You should see:
```
✅ [PushNotification] APNS Token received: FEFB64B1C9...
✅ [PushNotification] FCM Token: c4KW-ltZOE...
✅ [PushNotification] Token registered successfully
✅ [PushNotification] Initialized successfully
✅ INFO: Push notification service initialized for admin.
```

## Step 5: Test Notification

1. Open **Test Receipt Scanner**
2. Upload any receipt image
3. Wait for AI processing
4. Press **"Save to Receipt Watcher"**
5. **CHECK YOUR IPHONE - YOU SHOULD GET A NOTIFICATION! 🔔**

Console should show:
```
✅ [PushNotification] Sending notification: order, Amount: €XX.XX
✅ [PushNotification] Response: {ok: true, success: 1, failed: 0}
```

**Before it showed:** `success: 0, failed: 4` ❌
**Now it should show:** `success: 1, failed: 0` ✅

---

## What Was Fixed

| Before | After |
|--------|-------|
| `aps-environment: development` | `aps-environment: production` |
| Permission denied & cached | Fresh install = new permission prompt |
| `success: 0, failed: 4` | `success: 1, failed: 0` |
| No notifications | **Notifications work!** 🎉 |

---

## If You Still Have Issues

Check `FIX_NOTIFICATION_PERMISSIONS.md` for detailed troubleshooting.

