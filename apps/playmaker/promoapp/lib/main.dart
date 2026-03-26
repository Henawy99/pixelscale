import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'screens/promo_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Keep screen on for display mode
  await WakelockPlus.enable();
  
  // Force landscape mode for big screen
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  
  // Hide system UI for fullscreen experience
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  
  // Initialize Supabase - SAME credentials as main app
  await Supabase.initialize(
    url: 'https://upooyypqhftzzwjrfyra.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVwb295eXBxaGZ0enp3anJmeXJhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjEyNTM3ODIsImV4cCI6MjA3NjgyOTc4Mn0.5I1xvhg0o4DeUd7uvSsCNmwzBB7FkBAy7lrnEDBncpE',
  );
  
  runApp(const PromoApp());
}

class PromoApp extends StatelessWidget {
  const PromoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Playmaker Promo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF00BF63),
          secondary: const Color(0xFF00BF63),
          background: Colors.black,
          surface: Colors.black,
        ),
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const PromoScreen(),
    );
  }
}
