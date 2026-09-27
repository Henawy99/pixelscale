import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:restaurantadmin/screens/driver/driver_home_screen.dart';
import 'package:restaurantadmin/screens/driver/driver_login_screen.dart';
import 'package:restaurantadmin/services/location_foreground_service.dart';

/// The stand-alone driver app (see lib/main_driver.dart).
class DriverApp extends StatelessWidget {
  const DriverApp({super.key});

  static const Color accent = Color(0xFF4F46E5);

  @override
  Widget build(BuildContext context) {
    return LocationForegroundService.wrapWithForegroundTask(
      child: MaterialApp(
        title: 'Devils Driver',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: accent,
          scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        ),
        home: const DriverAuthGate(),
        routes: {
          '/login': (_) => const DriverAuthGate(),
          '/driver-home': (_) => const DriverAuthGate(),
        },
      ),
    );
  }
}

/// Signed out → login. Signed in with a driver account → driver home.
/// Any other account is signed out again: this app is for drivers only.
class DriverAuthGate extends StatefulWidget {
  const DriverAuthGate({super.key});

  @override
  State<DriverAuthGate> createState() => _DriverAuthGateState();
}

class _DriverAuthGateState extends State<DriverAuthGate> {
  final _auth = Supabase.instance.client.auth;
  // Cached per user so token refreshes do not rebuild (and reset) the home screen.
  String? _checkedUserId;
  Future<bool>? _isDriver;

  Future<bool> _driverCheck(String userId) {
    if (_checkedUserId != userId || _isDriver == null) {
      _checkedUserId = userId;
      _isDriver = Supabase.instance.client
          .from('drivers')
          .select('id')
          .eq('user_id', userId)
          .limit(1)
          .then((row) => (row as List).isNotEmpty);
    }
    return _isDriver!;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: _auth.onAuthStateChange,
      builder: (context, snapshot) {
        final user = _auth.currentSession?.user;
        if (user == null) return const DriverLoginScreen();
        return FutureBuilder<bool>(
          future: _driverCheck(user.id),
          builder: (context, isDriver) {
            if (isDriver.hasError) {
              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('No connection to the server.'),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => setState(() => _isDriver = null),
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              );
            }
            if (!isDriver.hasData) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            if (isDriver.data != true) return const _NotADriver();
            return const DriverHomeScreen();
          },
        );
      },
    );
  }
}

class _NotADriver extends StatelessWidget {
  const _NotADriver();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_accounts_rounded, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'This account is not set up as a driver.\nAsk your manager for a driver login.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Supabase.instance.client.auth.signOut(),
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
