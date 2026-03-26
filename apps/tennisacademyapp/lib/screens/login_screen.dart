import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'register_screen.dart';

/// Hardcoded demo credentials (already in Supabase). Update if your user email differs.
const _adminEmail = 'albasset@tennis.com';
const _adminPassword = '12345';
const _userEmail = 'player@tennis.com';
const _userPassword = 'password123';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await _signIn(_emailController.text.trim(), _passwordController.text);
  }

  Future<void> _signIn(String email, String password) async {
    try {
      await context.read<AuthProvider>().signIn(email, password);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.read<AuthProvider>().error ?? 'Login failed')),
        );
      }
    }
  }

  Future<void> _loginAsAdmin() async {
    _emailController.text = _adminEmail;
    _passwordController.text = _adminPassword;
    await _signIn(_adminEmail, _adminPassword);
  }

  Future<void> _loginAsUser() async {
    _emailController.text = _userEmail;
    _passwordController.text = _userPassword;
    await _signIn(_userEmail, _userPassword);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    // Tennis Yellow background to confirm updates
    const bgColor = Color(0xFFFFDE21); 

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card( // Wrap form in Card for contrast
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.sports_tennis, size: 80, color: Color(0xFFFFDE21)),
                      const SizedBox(height: 24),
                      Text(
                        'Tennis Academy',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                      ),
                      const SizedBox(height: 32),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (v) => v == null || v.isEmpty ? 'Enter email' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        validator: (v) => v == null || v.isEmpty ? 'Enter password' : null,
                      ),
                      if (auth.error != null) ...[
                        const SizedBox(height: 12),
                        Text(auth.error!, style: const TextStyle(color: Colors.red)),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: auth.loading ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                        ),
                        child: auth.loading
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Sign in'),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen()));
                        },
                        child: const Text('Don\'t have an account? Register', style: TextStyle(color: Colors.black87)),
                      ),
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text(
                        'Quick login (Supabase demo)',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: auth.loading ? null : _loginAsAdmin,
                              icon: const Icon(Icons.admin_panel_settings, size: 20),
                              label: const Text('Admin'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: auth.loading ? null : _loginAsUser,
                              icon: const Icon(Icons.person, size: 20),
                              label: const Text('User'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
