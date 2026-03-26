import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:playmakerappstart/config/app_config.dart';
import 'package:playmakerappstart/config/supabase_config.dart';
import 'package:playmakerappstart/l10n/app_localizations.dart';
import 'package:playmakerappstart/localization/app_localizations.dart';
import 'package:playmakerappstart/localization/locale_provider.dart';
import 'package:playmakerappstart/screens/management/management_login_screen.dart';
import 'package:playmakerappstart/services/management_service.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Unified entry point for Playmaker Management app
/// Combines Admin and Partner functionality into a single app
/// Role is determined at login based on credentials
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyAXs-QIdgrFn-Pqqtr39pt1ZYq8zhza2bY",
        authDomain: "playmaker-4af3d.firebaseapp.com",
        projectId: "playmaker-4af3d",
        storageBucket: "playmaker-4af3d.appspot.com",
        messagingSenderId: "696556220633",
        appId: "1:696556220633:web:7ba6f02b53a3e32da5c1fc",
      ),
    );
  } else {
    await Firebase.initializeApp();
  }
  
  // Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );
  
  // Initialize localization
  await LocalizationManager.init();
  
  // Set management flavor (will be updated to admin or partner after login)
  AppConfig.setFlavor(AppFlavor.admin); // Default, will be updated after login
  
  // Set unified mode flag
  ManagementService.setUnifiedMode(true);
  
  runApp(
    ChangeNotifierProvider(
      create: (_) => LocaleProvider(),
      child: const ManagementApp(),
    ),
  );
}

class ManagementApp extends StatelessWidget {
  const ManagementApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LocaleProvider>(
      builder: (context, localeProvider, child) {
        return MaterialApp(
          title: 'Playmaker Management',
          debugShowCheckedModeBanner: false,
          locale: localeProvider.locale,
          supportedLocales: LocalizationManager.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF00BF63),
              brightness: Brightness.light,
            ),
            textTheme: GoogleFonts.interTextTheme(),
            appBarTheme: const AppBarTheme(
              centerTitle: true,
              elevation: 0,
            ),
          ),
          home: const ManagementLoginScreen(),
        );
      },
    );
  }
}
