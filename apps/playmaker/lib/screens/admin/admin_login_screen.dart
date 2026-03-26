import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:playmakerappstart/config/app_config.dart';
import 'package:playmakerappstart/screens/admin/admin_main_screen.dart';
import 'package:playmakerappstart/services/supabase_auth_service.dart';
import 'package:playmakerappstart/widgets/custom_snackbar.dart';

/// Dedicated login screen for ADMIN app only
class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({Key? key}) : super(key: key);

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _emailController = TextEditingController(text: AppConfig.adminEmail);
  final _passwordController = TextEditingController(text: kIsWeb ? '123456' : '');
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleAdminLogin() async {
    // Validate admin email
    if (_emailController.text.trim() != AppConfig.adminEmail) {
      CustomSnackbar.showError(
        context,
        'Only authorized administrators can access this app.',
      );
      return;
    }

    if (_passwordController.text.isEmpty) {
      CustomSnackbar.showError(context, 'Please enter your password');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = SupabaseAuthService();
      final response = await authService.signInWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (response.user != null && mounted) {
        // Navigate to admin main screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const AdminMainScreen(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        CustomSnackbar.showError(
          context,
          'Login failed. Please check your credentials.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF00BF63),
                Color(0xFF00A854),
                Color(0xFF009148),
              ],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.1),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00BF63),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Text(
                        'playmaker',
                        style: GoogleFonts.leagueSpartan(
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1.5,
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // ADMIN badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.admin_panel_settings,
                            color: Color(0xFF00BF63),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'ADMIN ACCESS',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF00BF63),
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    Text(
                      'Sign in to continue',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    SizedBox(height: screenHeight * 0.05),
                    
                    // Email Field (Read-only)
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextFormField(
                        controller: _emailController,
                        readOnly: true,
                        style: GoogleFonts.inter(
                          color: Colors.white.withOpacity(0.7),
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Admin Email',
                          prefixIcon: Container(
                            margin: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.email_outlined,
                              color: Colors.white.withOpacity(0.9),
                              size: 20,
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.15),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Colors.white.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          labelStyle: GoogleFonts.inter(
                            color: Colors.white.withOpacity(0.8),
                            fontWeight: FontWeight.w500,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 18,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Password Field
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextFormField(
                        controller: _passwordController,
                        onFieldSubmitted: (_) => _handleAdminLogin(),
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                        obscureText: !_isPasswordVisible,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Container(
                            margin: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.lock_outline,
                              color: Colors.white.withOpacity(0.9),
                              size: 20,
                            ),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              color: Colors.white.withOpacity(0.8),
                              size: 22,
                            ),
                            onPressed: () => setState(
                              () => _isPasswordVisible = !_isPasswordVisible,
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.15),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Colors.white.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Colors.white,
                              width: 2,
                            ),
                          ),
                          labelStyle: GoogleFonts.inter(
                            color: Colors.white.withOpacity(0.8),
                            fontWeight: FontWeight.w500,
                          ),
                          floatingLabelStyle: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 18,
                          ),
                        ),
                      ),
                    ),
                    
                    SizedBox(height: screenHeight * 0.04),
                    
                    // Sign In Button
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleAdminLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF00BF63),
                          disabledBackgroundColor:
                              Colors.white.withOpacity(0.5),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFF00BF63),
                                  ),
                                ),
                              )
                            : Text(
                                'Sign In',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Info box
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.white.withOpacity(0.9),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'This is an internal management app. Only authorized administrators can access it.',
                              style: GoogleFonts.inter(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Version number
                    Text(
                      'v1.0.4',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
