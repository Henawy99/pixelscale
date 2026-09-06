import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:restaurantadmin/services/lieferando_service.dart';
import 'package:url_launcher/url_launcher.dart';

class PlatformLoginWebView extends StatefulWidget {
  final PlatformSession session;

  const PlatformLoginWebView({
    Key? key,
    required this.session,
  }) : super(key: key);

  @override
  State<PlatformLoginWebView> createState() => _PlatformLoginWebViewState();
}

class _PlatformLoginWebViewState extends State<PlatformLoginWebView> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoggingIn = false;
  bool _obscurePassword = true;
  String? _statusMessage;
  bool? _statusSuccess;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _statusMessage = 'Please enter both email and password.';
        _statusSuccess = false;
      });
      return;
    }

    setState(() {
      _isLoggingIn = true;
      _statusMessage = '🔐 Logging in to Foodora...\nThis may take up to 30 seconds.';
      _statusSuccess = null;
    });

    try {
      final service = PlatformSessionService();
      final baseUrl = service.monitorBaseUrl.value.trim().replaceAll(RegExp(r'/$'), '');
      final parsedUri = Uri.parse(baseUrl);
      final foodoraBase = '${parsedUri.scheme}://${parsedUri.host}:3002';

      final loginUri = Uri.parse(
          '$foodoraBase/api/foodora/sessions/${widget.session.accountId}/login');
      final response = await http
          .post(
            loginUri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 60));

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      if (mounted) {
        if (response.statusCode == 200 && json['success'] == true) {
          setState(() {
            _isLoggingIn = false;
            _statusMessage = '✅ ${json['message'] ?? 'Login successful!'}';
            _statusSuccess = true;
          });
          // Wait a moment so user sees the success message
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) {
            Navigator.of(context).pop(true);
          }
        } else {
          setState(() {
            _isLoggingIn = false;
            _statusMessage = '❌ ${json['error'] ?? json['message'] ?? 'Login failed.'}';
            _statusSuccess = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoggingIn = false;
          _statusMessage = '❌ Connection error: $e';
          _statusSuccess = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(
          'Login: ${widget.session.label}',
          style: const TextStyle(fontSize: 16),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              // Foodora branding
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFD70F64), Color(0xFFE91E8C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.restaurant_menu, color: Colors.white, size: 36),
                    SizedBox(height: 8),
                    Text(
                      'Foodora Partner Login',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Enter your Foodora portal credentials.\nThe server will log in and start fetching orders.',
                      style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Email
              const Text('Email', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                enabled: !_isLoggingIn,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'your@email.com',
                  hintStyle: const TextStyle(color: Colors.white30),
                  prefixIcon: const Icon(Icons.email_outlined, color: Colors.white38, size: 20),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white10),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFD70F64)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Password
              const Text('Password', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                enabled: !_isLoggingIn,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: '••••••••',
                  hintStyle: const TextStyle(color: Colors.white30),
                  prefixIcon: const Icon(Icons.lock_outline, color: Colors.white38, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: Colors.white38,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white10),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFD70F64)),
                  ),
                ),
                onSubmitted: (_) => _login(),
              ),
              const SizedBox(height: 24),
              // Login button
              ElevatedButton(
                onPressed: _isLoggingIn ? null : _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD70F64),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFD70F64).withOpacity(0.5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoggingIn
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          ),
                          SizedBox(width: 12),
                          Text('Logging in...', style: TextStyle(fontSize: 16)),
                        ],
                      )
                    : const Text('Log In via Credentials', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () async {
                  final uri = Uri.parse('http://46.225.213.75:6080/vnc.html?autoconnect=true&password=pixelscale');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                icon: const Icon(Icons.open_in_browser, color: Color(0xFF38BDF8)),
                label: const Text(
                  'Open Live Portal Screen (Verify / Captcha)',
                  style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              // Status message
              if (_statusMessage != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _statusSuccess == true
                        ? const Color(0xFF10B981).withOpacity(0.15)
                        : _statusSuccess == false
                            ? const Color(0xFFEF4444).withOpacity(0.15)
                            : const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _statusSuccess == true
                          ? const Color(0xFF10B981).withOpacity(0.3)
                          : _statusSuccess == false
                              ? const Color(0xFFEF4444).withOpacity(0.3)
                              : Colors.white10,
                    ),
                  ),
                  child: Text(
                    _statusMessage!,
                    style: TextStyle(
                      color: _statusSuccess == true
                          ? const Color(0xFF10B981)
                          : _statusSuccess == false
                              ? const Color(0xFFEF4444)
                              : Colors.white70,
                      fontSize: 14,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              // Info box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B).withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.security, color: Colors.white38, size: 18),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your credentials are sent directly to the order monitoring server and used only to log into the Foodora partner portal. They are not stored.',
                        style: TextStyle(color: Colors.white38, fontSize: 12, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
