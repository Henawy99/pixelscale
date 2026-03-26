import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final SupabaseClient _supabase = Supabase.instance.client;
  
  bool _initialized = false;

  /// Initialize push notifications and register device token
  Future<void> initialize() async {
    if (_initialized) {
      debugPrint('[PushNotification] Already initialized, skipping...');
      return;
    }

    try {
      debugPrint('[PushNotification] Starting initialization...');
      
      // Request permission for iOS
      if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
        debugPrint('[PushNotification] Requesting notification permissions...');
        NotificationSettings settings = await _messaging.requestPermission(
          alert: true,
          announcement: false,
          badge: true,
          carPlay: false,
          criticalAlert: false,
          provisional: false,
          sound: true,
        );

        debugPrint('[PushNotification] Permission status: ${settings.authorizationStatus}');
        
        if (settings.authorizationStatus != AuthorizationStatus.authorized &&
            settings.authorizationStatus != AuthorizationStatus.provisional) {
          debugPrint('[PushNotification] Notifications not authorized: ${settings.authorizationStatus}');
          
          // Don't return - try to proceed anyway in case permissions change
          // return;
        } else {
          debugPrint('[PushNotification] Notifications authorized successfully!');
        }
      }

      // Get FCM token
      String? token;
      if (kIsWeb) {
        // For web, use VAPID key if you have one configured
        token = await _messaging.getToken(
          vapidKey: 'YOUR_VAPID_KEY_HERE', // Replace with your actual VAPID key
        );
      } else {
        // For iOS/macOS, wait for APNS token to be available
        if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
          try {
            // Try to get APNS token with retries
            String? apnsToken;
            for (int i = 0; i < 5; i++) {
              apnsToken = await _messaging.getAPNSToken();
              if (apnsToken != null) {
                debugPrint('[PushNotification] APNS Token received: ${apnsToken.substring(0, 10)}...');
                break;
              }
              debugPrint('[PushNotification] Waiting for APNS token (attempt ${i + 1}/5)...');
              await Future.delayed(Duration(seconds: i + 1));
            }
            
            if (apnsToken == null) {
              debugPrint('[PushNotification] WARNING: APNS token not available after retries');
            }
          } catch (e) {
            debugPrint('[PushNotification] Error getting APNS token: $e');
          }
        }
        
        // Get FCM token (may work even without APNS token in some cases)
        try {
          token = await _messaging.getToken();
        } catch (e) {
          debugPrint('[PushNotification] Error getting FCM token: $e');
          // Retry once after a delay
          await Future.delayed(const Duration(seconds: 3));
          token = await _messaging.getToken();
        }
      }

      if (token != null) {
        debugPrint('[PushNotification] FCM Token: $token');
        await _registerToken(token);
      } else {
        debugPrint('[PushNotification] Failed to get FCM token');
      }

      // Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        debugPrint('[PushNotification] Token refreshed: $newToken');
        _registerToken(newToken);
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('[PushNotification] Foreground message received: ${message.notification?.title}');
        // You can show a local notification here if needed
      });

      // Handle background messages (when app is in background but not terminated)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('[PushNotification] Background message opened: ${message.notification?.title}');
        // Handle navigation based on message data
      });

      _initialized = true;
      debugPrint('[PushNotification] Initialized successfully');
    } catch (e) {
      debugPrint('[PushNotification] Initialization error: $e');
    }
  }

  /// Register device token with Supabase
  Future<void> _registerToken(String token) async {
    try {
      String platform = 'unknown';
      if (!kIsWeb) {
        if (Platform.isIOS) {
          platform = 'ios';
        } else if (Platform.isAndroid) {
          platform = 'android';
        } else if (Platform.isMacOS) {
          platform = 'macos';
        }
      } else {
        platform = 'web';
      }

      // Upsert token (insert or update if exists)
      await _supabase.from('device_tokens').upsert({
        'token': token,
        'platform': platform,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'token');

      debugPrint('[PushNotification] Token registered successfully');
    } catch (e) {
      debugPrint('[PushNotification] Failed to register token: $e');
    }
  }

  /// Unregister the current device token (call on logout)
  Future<void> unregisterToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _supabase.from('device_tokens').delete().eq('token', token);
        debugPrint('[PushNotification] Token unregistered');
      }
    } catch (e) {
      debugPrint('[PushNotification] Failed to unregister token: $e');
    }
  }
}

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[PushNotification] Background message received: ${message.notification?.title}');
  // Handle background message
}

