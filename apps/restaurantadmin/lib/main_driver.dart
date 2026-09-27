// Entry point of the stand-alone driver app (APK for delivery drivers).
//
// Build:  ./build_driver_apk.sh
// It contains only the driver screens — none of the admin/POS app is compiled in.

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'firebase_options.dart';
import 'screens/driver/driver_app.dart';
import 'services/driver_notifications.dart';
import 'services/location_foreground_service.dart';

const String _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const String _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

/// Tour notifications are "notification" messages that Android shows by itself;
/// the handler only has to exist.
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (_supabaseUrl.isEmpty || _supabaseAnonKey.isEmpty) {
    runApp(const MaterialApp(
      home: Scaffold(body: Center(child: Text('Build error: SUPABASE_URL / SUPABASE_ANON_KEY missing.'))),
    ));
    return;
  }

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
  } catch (e) {
    debugPrint('Firebase unavailable, push notifications disabled: $e');
  }

  await Supabase.initialize(url: _supabaseUrl, anonKey: _supabaseAnonKey);
  LocationForegroundService.supabaseUrl = _supabaseUrl;
  LocationForegroundService.supabaseAnonKey = _supabaseAnonKey;
  await DriverNotifications.init();

  runApp(const DriverApp());
}
