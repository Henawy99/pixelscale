import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/user_shell.dart';
import 'screens/admin_shell.dart';
import 'screens/create_profile_screen.dart';
import 'constants/levels.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: SupabaseConfig.url, anonKey: SupabaseConfig.anonKey);
  await loadAcademyClasses();
  runApp(const AcademyApp());
}

class AcademyApp extends StatelessWidget {
  const AcademyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const tennisYellow = Color(0xFFFFDE21); // Specific yellow requested

    return ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: MaterialApp(
        title: 'Tennis Academy',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: tennisYellow, primary: tennisYellow),
          useMaterial3: true,
          scaffoldBackgroundColor: Colors.white,
          appBarTheme: const AppBarTheme(
            backgroundColor: tennisYellow,
            foregroundColor: Colors.black,
            centerTitle: true,
            scrolledUnderElevation: 0,
            toolbarHeight: 44,
            iconTheme: IconThemeData(color: Colors.black),
            titleTextStyle: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          bottomNavigationBarTheme: const BottomNavigationBarThemeData(
            backgroundColor: tennisYellow,
            selectedItemColor: Colors.black,
            unselectedItemColor: Colors.black87,
            elevation: 0,
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: tennisYellow,
            foregroundColor: Colors.white,
          ),
        ),
        home: const _Root(),
      ),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!auth.isLoggedIn) {
      return const LoginScreen();
    }
    if (auth.profile != null && auth.profile!.startedPlayingYear == null && !auth.isAdmin) {
      return const CreateProfileScreen();
    }
    if (auth.isAdmin) {
      return const AdminShell();
    }
    return const UserShell();
  }
}
