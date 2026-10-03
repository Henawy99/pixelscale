import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:restaurantadmin/main.dart' show appNavigatorKey;
import 'package:restaurantadmin/screens/expenses/expense_review_screen.dart';
import 'package:restaurantadmin/services/app_nav_service.dart';

class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Android does not show a push while the app is open; this plugin does, on this channel.
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  static const String _channelId = 'admin_updates';
  static const String _channelName = 'Orders, invoices and payouts';

  bool _initialized = false;

  /// Initialize push notifications and register device token
  Future<void> initialize() async {
    if (_initialized) {
      debugPrint('[PushNotification] Already initialized, skipping...');
      return;
    }

    try {
      debugPrint('[PushNotification] Starting initialization...');
      
      // Android 13+ needs the notification permission too.
      if (!kIsWeb && Platform.isAndroid) {
        await _messaging.requestPermission(alert: true, badge: true, sound: true);
        await _initLocalNotifications();
      }

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

        // Allow notifications to show alerts, sound, and badge while app is in foreground
        await _messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );

        // Check if app was opened from a terminated notification
        final initialMessage = await _messaging.getInitialMessage();
        if (initialMessage != null) _openFrom(initialMessage.data);

        // Foreground: iOS shows the banner itself (see above); Android needs a local notification.
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          debugPrint('[PushNotification] Foreground message received: ${message.notification?.title}');
          final n = message.notification;
          if (!kIsWeb && Platform.isAndroid && n != null) {
            _local.show(
              id: message.messageId.hashCode,
              title: n.title,
              body: n.body,
              notificationDetails: const NotificationDetails(
                android: AndroidNotificationDetails(
                  _channelId,
                  _channelName,
                  importance: Importance.high,
                  priority: Priority.high,
                  styleInformation: BigTextStyleInformation(''),
                ),
              ),
              payload: jsonEncode(message.data),
            );
          }
        });

        // Handle background messages (when app is in background but not terminated)
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          debugPrint('[PushNotification] Background message opened: ${message.notification?.title}');
          _openFrom(message.data);
        });

        _initialized = true;
        debugPrint('[PushNotification] Initialized successfully');
      } catch (e) {
        debugPrint('[PushNotification] Initialization error: $e');
      }
    }

  Future<void> _initLocalNotifications() async {
    await _local.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          _openFrom(Map<String, dynamic>.from(jsonDecode(payload) as Map));
        } catch (_) {}
      },
    );
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: 'New orders, scanned invoices and Lieferando/Foodora payouts',
            importance: Importance.high,
          ),
        );
  }

  /// Where a tapped notification leads: orders to the Orders tab, a scanned invoice to its review.
  void _openFrom(Map<String, dynamic> data) {
    switch (data['type']) {
      case 'order':
        AppNavService().goToOrdersTab();
      case 'expense':
        AppNavService().goToExpensesTab();
        final id = data['expense_id'] as String?;
        if (id != null && id.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            appNavigatorKey.currentState?.push(
              MaterialPageRoute(builder: (_) => ExpenseReviewScreen(expenseId: id)),
            );
          });
        }
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
  // Firebase must be initialized in the background isolate
  // Without this, release builds crash immediately on startup
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Already initialized or not available — ignore
  }
  debugPrint('[PushNotification] Background message received: ${message.notification?.title}');
}

