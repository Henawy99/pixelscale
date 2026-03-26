# Quick Test Guide - iPhone Push Notifications

## Before Testing: Complete Required Setup

### 1. Add FCM Server Key to Supabase (5 minutes)

1. Go to https://console.firebase.google.com/
2. Select project: `restaurantmanager-d9520`
3. Click ⚙️ → **Project Settings**
4. Go to **Cloud Messaging** tab
5. Scroll to "Cloud Messaging API (Legacy)"
6. Copy the **Server key**

7. Go to https://supabase.com/dashboard
8. Select your project
9. **Settings** → **Edge Functions** → **Secrets**
10. Click **Add secret**:
    - Name: `FCM_SERVER_KEY`
    - Value: (paste the key)
11. Click **Save**

### 2. Create Database Table (2 minutes)

1. Go to Supabase Dashboard → **SQL Editor**
2. Click **New query**
3. Copy and paste this SQL:

```sql
-- Create table to store FCM device tokens
CREATE TABLE IF NOT EXISTS public.device_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  token TEXT NOT NULL UNIQUE,
  device_id TEXT,
  platform TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow token registration" ON public.device_tokens
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Allow token updates" ON public.device_tokens
  FOR UPDATE USING (true);

CREATE INDEX IF NOT EXISTS idx_device_tokens_token ON public.device_tokens(token);
```

4. Click **Run** (or press Cmd+Enter)

### 3. Configure Xcode for Push Notifications (5 minutes)

1. Open your project in Xcode:
   ```bash
   open ios/Runner.xcworkspace
   ```

2. In Xcode:
   - Select **Runner** in the left sidebar
   - Go to **Signing & Capabilities** tab
   - Click **+ Capability** button
   - Add **Push Notifications**
   - Click **+ Capability** again
   - Add **Background Modes**
   - Check ✅ **Remote notifications**

3. **Upload APNs Key to Firebase** (Important!):
   - Go to Firebase Console → Project Settings → Cloud Messaging
   - Under "Apple app configuration"
   - Upload your APNs Authentication Key
   - (If you don't have one, you'll need to create it in Apple Developer Portal)

## Testing Steps

### Step 1: Build and Run on iPhone

```bash
# Make sure your iPhone is connected via USB
# and is unlocked

# Run the app on your iPhone
flutter run --release
```

**Why --release?** Push notifications work more reliably in release mode on iOS.

### Step 2: Check for Successful Initialization

Watch the console output for these messages:

```
INFO: Firebase initialized successfully.
INFO: Push notification service initialized.
[PushNotification] FCM Token: <a long token string>
[PushNotification] Token registered successfully
```

✅ If you see these messages, your device is ready to receive notifications!

### Step 3: Grant Notification Permissions

When the app launches, iOS will ask:
> "Restaurant Admin would like to send you notifications"

**Click "Allow"**

### Step 4: Scan a Test Receipt

1. In the app, go to **Test Receipt Scanner** screen
2. Drop or select a receipt image (preferably a Lieferando order receipt)
3. Click **Process Receipt**
4. Wait for processing to complete

### Step 5: Check for Push Notification

You should receive a notification on your iPhone:
- 📱 "New Order, Total €XX.XX" (for orders)
- 📱 "New Purchase, Total €XX.XX" (for purchases)

**Note**: The notification will appear:
- As a banner at the top (if app is in foreground)
- In Notification Center (if app is in background)
- On lock screen (if phone is locked)

## Troubleshooting

### No FCM Token Received

Check console logs for errors. Common issues:
- Firebase not initialized → Check GoogleService-Info.plist is present
- APNs certificate missing → Upload to Firebase Console

### Permission Denied

If you accidentally denied notifications:
1. Go to iPhone Settings
2. Scroll to your app
3. Tap **Notifications**
4. Enable **Allow Notifications**
5. Restart the app

### Token Registered But No Notification

1. **Check device_tokens table**:
   ```sql
   SELECT * FROM device_tokens ORDER BY created_at DESC;
   ```
   Your token should be there with platform='ios'

2. **Check Edge Function Logs**:
   - Supabase Dashboard → Edge Functions → scan-receipt → Logs
   - Look for `[FCM]` messages
   - Should show "Notification sent. Success: 1, Failed: 0"

3. **Verify FCM_SERVER_KEY**:
   - Supabase Dashboard → Settings → Edge Functions → Secrets
   - Make sure `FCM_SERVER_KEY` is set correctly

### Still Not Working?

**Test with a manual notification** to isolate the issue:

1. Get your device token from the console logs
2. Use this curl command (replace TOKEN and SERVER_KEY):

```bash
curl -X POST https://fcm.googleapis.com/fcm/send \
  -H "Authorization: key=YOUR_FCM_SERVER_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "to": "YOUR_DEVICE_TOKEN",
    "notification": {
      "title": "Test Notification",
      "body": "If you see this, FCM is working!"
    }
  }'
```

If this works, the issue is in the edge function. If it doesn't work, the issue is with FCM/APNs setup.

## Quick Verification Checklist

- [ ] FCM_SERVER_KEY added to Supabase Secrets
- [ ] device_tokens table created in Supabase
- [ ] Push Notifications capability enabled in Xcode
- [ ] Background Modes → Remote notifications enabled in Xcode
- [ ] APNs key uploaded to Firebase Console
- [ ] App running on physical iPhone (not simulator)
- [ ] Notification permission granted in iOS
- [ ] Console shows "Token registered successfully"

## Next Steps After Successful Test

- Test with different receipt types (orders vs purchases)
- Test receiving notifications when app is in background
- Test on multiple devices
- Monitor edge function logs to see notification delivery stats

## Common Questions

**Q: Do I need to rebuild after adding FCM_SERVER_KEY?**
A: No, the server key is used by the edge function, not the app.

**Q: Will this work on simulator?**
A: No, push notifications require a physical device.

**Q: What if I don't have an APNs certificate?**
A: You need to create one in Apple Developer Portal → Certificates → APNs Key.

**Q: Can I test without uploading APNs to Firebase?**
A: No, iOS requires APNs for push notifications.

