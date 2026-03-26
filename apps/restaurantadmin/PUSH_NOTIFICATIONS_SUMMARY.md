# Push Notifications Implementation Summary

## ✅ What Has Been Implemented

### 1. Database
- Created `device_tokens` table to store FCM tokens from all devices
- Added RLS policies to allow token registration and updates
- SQL file created: `supabase/sql/create_device_tokens_table.sql`

### 2. Edge Function Updates
- Updated `scan-receipt` function to send push notifications after processing
- Created shared FCM helper: `supabase/functions/_shared/fcm.ts`
- Notifications sent for both orders and purchases with format:
  - Orders: "New Order, Total €XX.XX"
  - Purchases: "New Purchase, Total €XX.XX"
- Function deployed successfully ✅

### 3. Flutter App Updates
- Added `firebase_messaging` dependency to `pubspec.yaml`
- Created `PushNotificationService` class: `lib/services/push_notification_service.dart`
- Integrated push notification initialization in `main.dart`
- Dependencies installed successfully ✅

### 4. Documentation
- Created comprehensive setup guide: `PUSH_NOTIFICATIONS_SETUP.md`
- Includes troubleshooting tips and maintenance instructions

## 🔧 What You Need to Do

### Required Steps (in order):

1. **Get FCM Server Key from Firebase**
   - Go to Firebase Console → Project Settings → Cloud Messaging
   - Copy the "Server key" (under legacy Cloud Messaging API)

2. **Add FCM Server Key to Supabase**
   - Supabase Dashboard → Settings → Edge Functions → Secrets
   - Add secret: `FCM_SERVER_KEY` = (your server key)

3. **Create Database Table**
   - Run the SQL in `supabase/sql/create_device_tokens_table.sql` in your Supabase SQL Editor

4. **iOS Setup** (if targeting iOS)
   - Open `ios/Runner.xcworkspace` in Xcode
   - Enable "Push Notifications" capability
   - Enable "Background Modes" → "Remote notifications"
   - Upload APNs certificate to Firebase Console

5. **Test**
   - Run the app on a physical device
   - Look for log: `[PushNotification] Token registered successfully`
   - Scan a receipt and verify push notification arrives

### Optional Steps:

- **Web Push**: Add VAPID key for web notifications (see setup guide)
- **Customize**: Modify notification text in edge function if needed

## 📱 How It Works

```
Receipt Scanned
    ↓
Edge Function Processes Receipt
    ↓
Extracts Order/Purchase Data
    ↓
Sends Geocoding Request (for orders)
    ↓
Saves to scanned_receipts Table
    ↓
Sends FCM Push Notification
    ↓
All Registered Devices Receive Notification
```

## 📊 Monitoring

- **Edge Function Logs**: Supabase Dashboard → Edge Functions → scan-receipt → Logs
- Look for `[FCM]` entries showing success/failure counts
- **Device Tokens**: Check `device_tokens` table to see registered devices

## 🐛 Troubleshooting Quick Reference

| Issue | Solution |
|-------|----------|
| No FCM token | Check Firebase initialization in console logs |
| Token not registered | Verify Supabase RLS policies and network connectivity |
| No notifications | Check FCM_SERVER_KEY is set in Supabase Secrets |
| iOS permissions | Enable Push Notifications in Xcode capabilities |
| Android not working | Verify `google-services.json` is in correct location |

## 📝 Files Changed/Created

### Created:
- `supabase/sql/create_device_tokens_table.sql`
- `supabase/functions/_shared/fcm.ts`
- `lib/services/push_notification_service.dart`
- `PUSH_NOTIFICATIONS_SETUP.md`
- `PUSH_NOTIFICATIONS_SUMMARY.md` (this file)

### Modified:
- `supabase/functions/scan-receipt/index.ts` (added push notification logic)
- `lib/main.dart` (added push notification initialization)
- `pubspec.yaml` (added firebase_messaging dependency)

## 🎯 Next Steps

1. Complete the required setup steps above
2. Test on a physical device
3. Monitor edge function logs to verify notifications are being sent
4. Optional: Customize notification appearance and behavior

For detailed instructions, see `PUSH_NOTIFICATIONS_SETUP.md`.

