import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'screens/albaseet_home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Keep screen on for display mode
  await WakelockPlus.enable();
  
  // Allow all orientations for flexibility
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  
  // Hide system UI for fullscreen experience
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  
  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://upooyypqhftzzwjrfyra.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVwb295eXBxaGZ0enp3anJmeXJhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjEyNTM3ODIsImV4cCI6MjA3NjgyOTc4Mn0.5I1xvhg0o4DeUd7uvSsCNmwzBB7FkBAy7lrnEDBncpE',
  );
  
  runApp(const AlBaseetApp());
}

class AlBaseetApp extends StatelessWidget {
  const AlBaseetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Al Baseet Sports',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.light(
          primary: const Color(0xFFFFCD3A),
          secondary: const Color(0xFFFFD700),
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFFFCD3A),
      ),
      home: const AlBaseetHomeScreen(),
    );
  }
}
