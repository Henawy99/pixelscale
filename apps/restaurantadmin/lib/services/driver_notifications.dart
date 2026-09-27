import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// "New tour" alerts for drivers.
///
/// * Registers the phone's FCM token on the driver row, so plan-routes can push a
///   notification when a tour is assigned or changed (works with the app closed).
/// * Shows the same alert locally when the app itself sees the new tour first.
///   Both use the Android tag [_tag] with id 0, so they collapse into one notification.
class DriverNotifications {
  DriverNotifications._();

  static const String channelId = 'driver_routes';
  static const String _tag = 'driver_route';

  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized || kIsWeb) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(const AndroidNotificationChannel(
            channelId,
            'New tours',
            description: 'Alerts when a delivery tour is assigned to you',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
          ));
    }
    _initialized = true;
  }

  /// Ask for notification permission and store this phone's push token on the driver row.
  static Future<void> registerPushToken(String driverId) async {
    if (kIsWeb) return;
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, sound: true, badge: true);
      final token = await messaging.getToken();
      if (token != null) await _saveToken(driverId, token);
      messaging.onTokenRefresh.listen((t) => _saveToken(driverId, t));
    } catch (e) {
      // No Google Play services (or Firebase unavailable): in-app alerts still work.
      debugPrint('[DriverNotifications] push registration failed: $e');
    }
  }

  static Future<void> _saveToken(String driverId, String token) async {
    await Supabase.instance.client.from('drivers').update({
      'fcm_token': token,
      'fcm_token_updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', driverId);
  }

  /// Remove the token on logout so the next person on this phone does not get the alerts.
  static Future<void> clearPushToken(String driverId) async {
    try {
      await Supabase.instance.client.from('drivers').update({'fcm_token': null}).eq('id', driverId);
    } catch (_) {}
  }

  static Future<void> showNewTour({required String title, required String body}) async {
    if (!_initialized) await init();
    if (kIsWeb) return;
    await _plugin.show(
      id: 0,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          'New tours',
          channelDescription: 'Alerts when a delivery tour is assigned to you',
          importance: Importance.max,
          priority: Priority.high,
          tag: _tag,
          category: AndroidNotificationCategory.message,
        ),
        iOS: DarwinNotificationDetails(presentSound: true),
      ),
    );
  }
}
