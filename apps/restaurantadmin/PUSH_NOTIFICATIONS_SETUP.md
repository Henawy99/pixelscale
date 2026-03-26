# Push Notifications Setup Guide

This guide explains how to set up push notifications for receipt scanning in your restaurant admin app.

## Overview

When a receipt is scanned and processed (order or purchase), a push notification is automatically sent to all registered devices with the following format:
- **Orders**: "New Order, Total €XX.XX"
- **Purchases**: "New Purchase, Total €XX.XX"

## Prerequisites

1. Firebase project already set up (you have `firebase_options.dart` and `GoogleService-Info.plist`)
2. Access to Firebase Console
3. Access to Supabase Dashboard

## Step 1: Get Your FCM Server Key

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: `restaurantmanager-d9520`
3. Click the gear icon ⚙️ next to "Project Overview" → **Project settings**
4. Go to the **Cloud Messaging** tab
5. Under "Cloud Messaging API (Legacy)", copy the **Server key**
   - If you don't see it, you may need to enable the legacy API
   - Click "Manage API in Google Cloud Console" and enable "Firebase Cloud Messaging API"

## Step 2: Add FCM Server Key to Supabase

1. Go to your [Supabase Dashboard](https://supabase.com/dashboard)
2. Select your project
3. Go to **Settings** → **Edge Functions** → **Secrets**
4. Add a new secret:
   - **Name**: `FCM_SERVER_KEY`
   - **Value**: (paste the server key from Step 1)
5. Click **Save**

## Step 3: Create the Database Table

Run this SQL in your Supabase SQL Editor:

```sql
-- Create table to store FCM device tokens for push notifications
CREATE TABLE IF NOT EXISTS public.device_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  token TEXT NOT NULL UNIQUE,
  device_id TEXT,
  platform TEXT, -- 'ios', 'android', 'web'
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;

-- Policy: Allow anyone to insert their own token
CREATE POLICY "Allow token registration" ON public.device_tokens
  FOR INSERT
  WITH CHECK (true);

-- Policy: Allow updating tokens
CREATE POLICY "Allow token updates" ON public.device_tokens
  FOR UPDATE
  USING (true);

-- Create index on token for faster lookups
CREATE INDEX IF NOT EXISTS idx_device_tokens_token ON public.device_tokens(token);

-- Create index on updated_at for cleanup queries
CREATE INDEX IF NOT EXISTS idx_device_tokens_updated_at ON public.device_tokens(updated_at);
```

## Step 4: Deploy the Updated Edge Function

The `scan-receipt` edge function has been updated to send push notifications. Deploy it:

```bash
npx supabase functions deploy scan-receipt
```

## Step 5: Install Flutter Dependencies

Run the following command to install the new dependencies:

```bash
flutter pub get
```

## Step 6: Configure iOS (if targeting iOS)

1. **Enable Push Notifications capability** in Xcode:
   - Open `ios/Runner.xcworkspace` in Xcode
   - Select the **Runner** target
   - Go to **Signing & Capabilities**
   - Click **+ Capability**
   - Add **Push Notifications**
   - Add **Background Modes** and enable "Remote notifications"

2. **Upload APNs certificate** to Firebase:
   - In Firebase Console → **Project Settings** → **Cloud Messaging**
   - Under "Apple app configuration", upload your APNs Authentication Key or certificate

## Step 7: Configure Android (if targeting Android)

The `google-services.json` file should already be in place. Verify it's located at:
```
android/app/google-services.json
```

If not, download it from Firebase Console → Project Settings → Your apps → Android app.

## Step 8: Test the Setup

1. **Run the app** on a physical device (push notifications don't work well on simulators)
   ```bash
   flutter run
   ```

2. **Check the console** for this log message:
   ```
   INFO: Push notification service initialized.
   [PushNotification] FCM Token: <your-device-token>
   [PushNotification] Token registered successfully
   ```

3. **Scan a receipt** using the Test Receipt Scanner screen
   - The receipt should be processed
   - A push notification should appear on your device
   - Check the edge function logs in Supabase if you don't receive the notification

## Troubleshooting

### No FCM Token Generated

- **iOS**: Make sure you've uploaded APNs certificate to Firebase and enabled Push Notifications capability
- **Android**: Ensure `google-services.json` is in the correct location
- **All platforms**: Check that Firebase is initialized successfully in the console logs

### No Push Notification Received

1. **Check device_tokens table**: Verify your device token is registered
   ```sql
   SELECT * FROM device_tokens ORDER BY created_at DESC LIMIT 5;
   ```

2. **Check edge function logs** in Supabase Dashboard:
   - Go to **Edge Functions** → **scan-receipt** → **Logs**
   - Look for `[FCM]` log entries
   - Check for any error messages

3. **Verify FCM_SERVER_KEY** is set correctly in Supabase Secrets

4. **Test manually** by calling the edge function directly and checking logs

### Background Notifications Not Working

- **iOS**: Ensure "Background Modes" → "Remote notifications" is enabled in Xcode
- **Android**: Check that the app has notification permissions granted

### Token Not Registering

- Check your Supabase RLS policies allow inserting into `device_tokens`
- Verify the app has network connectivity
- Check console logs for any error messages from `[PushNotification]`

## Optional: Web Push Notifications (VAPID)

For web push notifications, you'll need to:

1. Generate a VAPID key pair in Firebase Console
2. Update the `PushNotificationService` in `lib/services/push_notification_service.dart`:
   ```dart
   token = await _messaging.getToken(
     vapidKey: 'YOUR_ACTUAL_VAPID_KEY_HERE',
   );
   ```

## Maintenance

### Cleanup Old Tokens

The system automatically removes invalid tokens when notifications fail. To manually clean up tokens older than 60 days:

```sql
DELETE FROM device_tokens 
WHERE updated_at < NOW() - INTERVAL '60 days';
```

### Monitor Notification Delivery

Check the edge function logs regularly to monitor notification delivery rates:
```
[FCM] Notification sent. Success: X, Failed: Y
```

## Next Steps

- Customize notification titles and bodies in `supabase/functions/scan-receipt/index.ts`
- Add custom sounds or notification channels (Android)
- Implement notification tap handlers to navigate to specific screens
- Add user preferences for notification types

## Support

If you encounter issues, check:
1. Firebase Console logs
2. Supabase Edge Function logs
3. Flutter app console output
4. Device system logs (adb logcat for Android, Console.app for iOS)

