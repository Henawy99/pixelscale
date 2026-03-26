import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
// import 'package:cloud_firestore/cloud_firestore.dart'; // Not needed - using Supabase
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' hide User;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:playmakerappstart/color_class.dart'; // Removed 'as colors'
import 'package:playmakerappstart/config/app_config.dart';
import 'package:playmakerappstart/config/supabase_config.dart';
import 'package:playmakerappstart/l10n/app_localizations.dart';
import 'package:playmakerappstart/landing_screen.dart';
import 'package:playmakerappstart/localization/app_localizations.dart';
import 'package:playmakerappstart/login_screen/login_screen.dart';
import 'package:playmakerappstart/main_screen.dart';
import 'package:playmakerappstart/models/user_model.dart';
import 'package:playmakerappstart/screens/admin/admin_login_screen.dart';
import 'package:playmakerappstart/screens/admin/admin_main_screen.dart';
import 'package:playmakerappstart/screens/partner/partner_login_screen.dart';
import 'package:playmakerappstart/services/admin_notification_service.dart';
import 'package:playmakerappstart/services/supabase_service.dart';
import 'package:playmakerappstart/splash_screen.dart';
import 'package:playmakerappstart/first_time_language_screen.dart';
import 'package:provider/provider.dart';
import 'package:playmakerappstart/localization/locale_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
// flutter_paymob removed — using native Paymob SDK via paymob_native_sdk_service.dart

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Only set orientations on mobile platforms (not desktop)
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    
    // Ensure status bar is visible and set its style
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
    );
    
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );
  }
  
  // Initialize Firebase (for Auth, Storage, Messaging)
  if (kIsWeb) {
    // Web requires explicit Firebase configuration
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyAXs-QIdgrFn-Pqqtr39pt1ZYq8zhza2bY",
        authDomain: "playmaker-4af3d.firebaseapp.com",
        projectId: "playmaker-4af3d",
        storageBucket: "playmaker-4af3d.appspot.com",
        messagingSenderId: "116429864847",
        appId: "1:116429864847:web:9731439067a434e207d5fa",
      ),
    );
  } else {
    // Mobile/Desktop uses google-services.json / GoogleService-Info.plist
    await Firebase.initializeApp();
    
    // Firebase App Check (mobile only, not desktop)
    if (Platform.isAndroid || Platform.isIOS) {
      await FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.debug,
        appleProvider: AppleProvider.deviceCheck,
      );
    }
  }
  
  // Initialize Supabase (for Database)
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );
  
  // Paymob Native SDK is initialized per-payment via paymob_native_sdk_service.dart
  // No global init needed — MethodChannel calls happen at payment time
  
  // Initialize localization
  await LocalizationManager.init();
  
  // Background message handler (mobile only, not desktop)
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }
  // FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true); // Not needed - using Supabase
  runApp(
    ChangeNotifierProvider(
      create: (_) => LocaleProvider(),
      child: const MyApp(),
    ),
  );
}

// Update this function too
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await FirebaseAppCheck.instance.activate(  // Add this
    androidProvider: AndroidProvider.debug,
    appleProvider: AppleProvider.deviceCheck,
  );
  print("Handling a background message: ${message.messageId}");
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _setupFirebaseMessaging();
    _initializeAdminNotifications();
  }

  Future<void> _initializeAdminNotifications() async {
    // Admin notifications only work on mobile (not web)
    if (AppConfig.isAdmin && !kIsWeb) {
      try {
        await AdminNotificationService().initializeAdminNotifications(AppConfig.adminEmail);
      } catch (e) {
        print('⚠️ Failed to initialize admin notifications: $e');
      }
    }
  }

  void _setupFirebaseMessaging() async {
    // Skip messaging setup on web
    if (kIsWeb) {
      print('Firebase Messaging not supported on web');
      return;
    }
    
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    NotificationSettings settings = await messaging.requestPermission();

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      print('User granted provisional permission');
    } else {
      print('User declined or has not accepted permission');
      return;
    }

    if (!kIsWeb && Platform.isIOS) {
      String? apnsToken = await messaging.getAPNSToken();
      print("APNS Token: $apnsToken");
    }

    messaging.getToken().then((String? token) {
      assert(token != null);
      print("FCM Token: $token");
      _saveTokenToDatabase(token!);
    });

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      print("FCM Token Refreshed: $newToken");
      _saveTokenToDatabase(newToken);
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');

      if (message.notification != null) {
        print('Message also contained a notification: ${message.notification}');
        
        // Customize dialog based on notification type
        final notificationType = message.data['type'] ?? '';
        IconData icon = Icons.notifications;
        Color iconColor = Colors.blue;
        
        // USER APP notifications
        if (notificationType == 'booking_rejected') {
          icon = Icons.cancel;
          iconColor = Colors.red;
        } else if (notificationType == 'booking_reminder') {
          icon = Icons.alarm;
          iconColor = Colors.orange;
        } else if (notificationType == 'friend_request') {
          icon = Icons.person_add;
          iconColor = const Color(0xFF00BF63);
        } else if (notificationType == 'friend_request_declined') {
          icon = Icons.person_remove;
          iconColor = Colors.grey;
        } else if (notificationType == 'squad_join_request') {
          icon = Icons.group_add;
          iconColor = Colors.purple;
        } else if (notificationType == 'player_joined_game') {
          icon = Icons.sports_soccer;
          iconColor = const Color(0xFF00BF63);
        } else if (notificationType == 'match_cancelled') {
          icon = Icons.event_busy;
          iconColor = Colors.red;
        }
        // PARTNER/ADMIN APP notifications
        else if (notificationType == 'new_booking') {
          icon = Icons.calendar_today;
          iconColor = Colors.green;
        } else if (notificationType == 'booking_cancelled') {
          icon = Icons.event_busy;
          iconColor = Colors.orange;
        } else if (notificationType == 'new_user') {
          icon = Icons.person_add;
          iconColor = Colors.blue;
        }
        
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message.notification!.title ?? 'Notification',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
            content: Text(message.notification!.body ?? 'You have a new message'),
            actions: [
              TextButton(
                child: const Text('OK'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('A new onMessageOpenedApp event was published!');
    });

    messaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        print("App opened from terminated state: ${message.messageId}");
        // Handle the message
      }
    });
  }

  void _saveTokenToDatabase(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await SupabaseService().updateUserFcmToken(user.uid, token);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppConfig.appName,
      
      // Configure localization
      locale: context.watch<LocaleProvider>().locale, // Use LocaleProvider
      supportedLocales: LocalizationManager.supportedLocales,
      localizationsDelegates: [ // Removed const
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      
      // Enable RTL support based on locale
      builder: (context, child) {
        // Set text direction based on current locale
        final isRtl = LocalizationManager.isRtl;
        return Directionality(
          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: child!,
        );
      },
      
      theme: AppTheme.theme,
      home: const SplashScreenWrapper(),
    );
  }
}

class SplashScreenWrapper extends StatefulWidget {
  const SplashScreenWrapper({Key? key}) : super(key: key);

  @override
  State<SplashScreenWrapper> createState() => _SplashScreenWrapperState();
}

class _SplashScreenWrapperState extends State<SplashScreenWrapper> {
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    // Show splash screen for 2.5 seconds
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        setState(() {
          _showSplash = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return _showSplash ? const SplashScreen() : const InitialCheck();
  }
}

class InitialCheck extends StatefulWidget {
  const InitialCheck({super.key});

  @override
  State<InitialCheck> createState() => _InitialCheckState();
}

class _InitialCheckState extends State<InitialCheck> {
  bool? _hasSelectedLanguage;

  @override
  void initState() {
    super.initState();
    _checkLanguageSelection();
  }

  Future<void> _checkLanguageSelection() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hasSelectedLanguage = prefs.getBool('has_selected_language') ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Check if running partner app
    if (AppConfig.isPartner) {
      // Partner app checks for a saved session and auto-logs in if found
      return const PartnerAutoLoginWrapper();
    }
    
    // Check if running admin app
    if (AppConfig.isAdmin) {
      return StreamBuilder(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != null) {
            final firebaseUser = snapshot.data as dynamic;
            
            // Check if user is admin
            if (firebaseUser.email == AppConfig.adminEmail) {
              return const AdminMainScreen();
            } else {
              // Not admin - sign out and show login
              FirebaseAuth.instance.signOut();
              return const AdminLoginScreen();
            }
          } else {
            return const AdminLoginScreen();
          }
        },
      );
    }

    // Loading state while checking language preference
    if (_hasSelectedLanguage == null) {
      return Scaffold(
        backgroundColor: AppColors.backgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // If user hasn't selected language, show first-time language screen
    if (!_hasSelectedLanguage!) {
      return const FirstTimeLanguageScreen();
    }

    // User app flow
    return StreamBuilder(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          final firebaseUser = snapshot.data as dynamic;
          return FutureBuilder<PlayerProfile?>(
            future: SupabaseService().getUserModel(firebaseUser.uid),
            builder: (context, AsyncSnapshot<PlayerProfile?> userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.done) {
                if (userSnapshot.hasData && userSnapshot.data != null) {
                  // Track this user's visit today (silent — never interrupts login)
                  SupabaseService().trackAppOpen(firebaseUser.uid);
                  return MainScreen(userModel: userSnapshot.data!);
                } else {
                  return const LoginWithPasswordScreen();
                }
              } else {
                return Scaffold(
                  backgroundColor: AppColors.backgroundColor, // Changed to AppColors.backgroundColor
                  body: const Center(child: CircularProgressIndicator()),
                );
              }
            },
          );
        } else {
          return const LandingPage();
        }
      },
    );
  }
}
