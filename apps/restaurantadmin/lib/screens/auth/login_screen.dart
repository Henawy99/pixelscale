import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:restaurantadmin/models/profile.dart' as app_profile;
import 'package:restaurantadmin/providers/user_profile_provider.dart';
import 'package:restaurantadmin/screens/driver/driver_home_screen.dart';
import 'package:restaurantadmin/screens/main_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends StatefulWidget {
  static const String routeName = '/login'; // Added routeName
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController(text: 'youssef@gmail.com');
  final _passwordController = TextEditingController(text: '0000');
  bool _isLoading = false;
  final _supabase = Supabase.instance.client;

  // Admin email - only this email goes to admin panel
  static const String _adminEmail = 'youssef@gmail.com';

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim().toLowerCase();

      final AuthResponse res = await _supabase.auth.signInWithPassword(
        email: email,
        password: _passwordController.text.trim(),
      );

      if (res.user != null && mounted) {
        // Try to fetch profile, but don't fail if it doesn't exist
        try {
          final profileResponse = await _supabase
              .from('profiles')
              .select()
              .eq('id', res.user!.id)
              .maybeSingle();

          if (profileResponse != null && mounted) {
            final userProfileProvider = Provider.of<UserProfileProvider>(
              context,
              listen: false,
            );
            final app_profile.Profile userProfile =
                app_profile.Profile.fromJson(profileResponse);
            userProfileProvider.setProfile(userProfile);
          }
        } catch (e) {
          // Profile fetch failed - continue anyway
          debugPrint('Profile fetch error (non-critical): $e');
        }

        if (!mounted) return;

        // Simple email-based routing:
        // - youssef@gmail.com → Admin MainScreen
        // - Any other email → Driver HomeScreen
        // SECURITY: Use pushAndRemoveUntil to clear ALL back stack
        // This prevents drivers from navigating back to admin screens
        if (email == _adminEmail) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const MainScreen()),
            (route) => false, // Remove ALL previous routes
          );
        } else {
          // All other users go to Driver Home Screen
          // CRITICAL: Clear entire stack so back button can't reach admin
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const DriverHomeScreen()),
            (route) => false, // Remove ALL previous routes
          );
        }
      } else if (mounted) {
        _showErrorSnackBar('Login failed. Please check your credentials.');
      }
    } on AuthException catch (e) {
      if (mounted) {
        _showErrorSnackBar(e.message);
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('An unexpected error occurred: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Restaurant Admin'), centerTitle: true),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'Welcome Back!',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please sign in to continue.',
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null ||
                          value.isEmpty ||
                          !value.contains('@')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _handleLogin,
                          child: const Text(
                            'Login',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                  // Optional: Add Sign Up navigation later
                  // const SizedBox(height: 20),
                  // TextButton(
                  //   onPressed: () {
                  //     // Navigate to Sign Up Screen
                  //   },
                  //   child: const Text("Don't have an account? Sign Up"),
                  // ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
