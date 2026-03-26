import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service to handle admin push notifications
/// Registers admin device FCM token with Supabase
class AdminNotificationService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  /// Initialize admin notifications
  /// Call this when admin logs in to the admin app
  Future<void> initializeAdminNotifications(String adminEmail) async {
    try {
      print('🔔 Initializing admin notifications for: $adminEmail');

      // Request notification permissions
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('✅ User granted notification permission');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        print('✅ User granted provisional notification permission');
      } else {
        print('❌ User declined notification permission');
        return;
      }

      // Get FCM token
      final fcmToken = await _firebaseMessaging.getToken();
      if (fcmToken == null) {
        print('❌ Failed to get FCM token');
        return;
      }

      print('📱 FCM Token: $fcmToken');

      // Register or update admin device in Supabase
      await _registerAdminDevice(adminEmail, fcmToken);

      // Set up foreground notification handler
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('🔔 Foreground notification received:');
        print('   Title: ${message.notification?.title}');
        print('   Body: ${message.notification?.body}');
        print('   Data: ${message.data}');
        
        // You can show a local notification here if needed
      });

      // Handle notification tap when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print('🔔 Notification opened from background:');
        print('   Data: ${message.data}');
        
        // Navigate to user details screen if needed
        // You can add navigation logic here based on message.data['user_id']
      });

      // Handle notification when app was terminated
      RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        print('🔔 App opened from terminated state via notification:');
        print('   Data: ${initialMessage.data}');
      }

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        print('🔄 FCM Token refreshed: $newToken');
        _registerAdminDevice(adminEmail, newToken);
      });

      print('✅ Admin notifications initialized successfully');
    } catch (e) {
      print('❌ Error initializing admin notifications: $e');
    }
  }

  /// Register or update admin device FCM token in Supabase
  Future<void> _registerAdminDevice(String adminEmail, String fcmToken) async {
    try {
      // Check if device already exists
      final existing = await _supabase
          .from('admin_devices')
          .select()
          .eq('fcm_token', fcmToken)
          .maybeSingle();

      if (existing != null) {
        // Update existing device
        await _supabase
            .from('admin_devices')
            .update({
              'last_active': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('fcm_token', fcmToken);
        print('✅ Updated existing admin device registration');
      } else {
        // Insert new device
        await _supabase.from('admin_devices').insert({
          'admin_email': adminEmail,
          'fcm_token': fcmToken,
          'device_name': 'iOS Device', // You can get actual device name if needed
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
        print('✅ Registered new admin device');
      }
    } catch (e) {
      print('❌ Error registering admin device: $e');
      rethrow;
    }
  }

  /// Unregister admin device (call on logout)
  Future<void> unregisterAdminDevice() async {
    try {
      final fcmToken = await _firebaseMessaging.getToken();
      if (fcmToken != null) {
        await _supabase
            .from('admin_devices')
            .delete()
            .eq('fcm_token', fcmToken);
        print('✅ Unregistered admin device');
      }
    } catch (e) {
      print('❌ Error unregistering admin device: $e');
    }
  }

  /// Test notification (for debugging)
  Future<void> sendTestNotification() async {
    try {
      final fcmToken = await _firebaseMessaging.getToken();
      print('🧪 Sending test notification to: $fcmToken');
      
      // You can manually call the Edge Function here for testing
      final response = await _supabase.functions.invoke(
        'send-admin-notification',
        body: {
          'fcm_token': fcmToken,
          'user_name': 'Test User',
          'user_email': 'test@example.com',
          'user_id': 'test-id-123',
        },
      );

      print('✅ Test notification response: ${response.data}');
    } catch (e) {
      print('❌ Error sending test notification: $e');
    }
  }
}
