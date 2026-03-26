import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:playmakerappstart/login_screen/login_screen.dart';
import 'package:playmakerappstart/login_screen/login_screen_bloc.dart';
import 'package:playmakerappstart/models/user_model.dart';
import 'package:playmakerappstart/playerprofile_form.dart';
import 'package:playmakerappstart/privacy_policy_modal.dart';
import 'package:playmakerappstart/terms_conditions_modal.dart';
import 'package:flutter/foundation.dart';
import 'package:playmakerappstart/utils/validators.dart';
import 'package:playmakerappstart/widgets/custom_snackbar.dart';
import 'package:playmakerappstart/services/supabase_auth_service.dart';
import 'package:playmakerappstart/localization/app_localizations.dart';
import 'package:playmakerappstart/localization/locale_provider.dart';
import 'package:provider/provider.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({Key? key}) : super(key: key);

  @override
  _RegistrationScreenState createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> with TickerProviderStateMixin {
  final AuthenticationBloc _bloc = AuthenticationBloc();
  final SupabaseAuthService _authService = SupabaseAuthService();
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    // Logo slides in from right (like splash screen)
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.5, 0.0), // Start from right
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic, // Smooth deceleration curve
      ),
    );
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _validateEmailRealtime() {
    setState(() {
      _emailError = Validators.validateEmail(_emailController.text);
    });
  }

  void _validatePasswordRealtime() {
    setState(() {
      if (_passwordController.text.isEmpty) {
        _passwordError = null;
      } else {
        _passwordError = Validators.validatePassword(_passwordController.text);
      }
      _validateConfirmPasswordRealtime();
    });
  }

  void _validateConfirmPasswordRealtime() {
    setState(() {
      if (_confirmPasswordController.text.isEmpty) {
        _confirmPasswordError = null;
      } else if (_passwordController.text != _confirmPasswordController.text) {
        _confirmPasswordError = 'Passwords do not match';
      } else {
        _confirmPasswordError = null;
      }
    });
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white.withOpacity(0.9), size: 20),
      ),
      filled: true,
      fillColor: Colors.white.withOpacity(0.15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.3), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.white, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 2),
      ),
      labelStyle: GoogleFonts.inter(
        color: Colors.white.withOpacity(0.8),
        fontWeight: FontWeight.w500,
      ),
      floatingLabelStyle: GoogleFonts.inter(
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
      errorStyle: GoogleFonts.inter(
        color: Colors.redAccent,
        fontWeight: FontWeight.w500,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
    );
  }

  Widget _socialLoginButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required String label,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    color: Colors.grey.shade800,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleRegistration(BuildContext context) async {
    // Validate email
    final emailError = Validators.validateEmail(_emailController.text);
    if (emailError != null) {
      CustomSnackbar.showError(context, emailError);
      setState(() => _emailError = emailError);
      return;
    }

    // Validate password
    final passwordError = Validators.validatePassword(_passwordController.text);
    if (passwordError != null) {
      CustomSnackbar.showError(context, passwordError);
      setState(() => _passwordError = passwordError);
      return;
    }

    // Check password match
    if (_passwordController.text != _confirmPasswordController.text) {
      CustomSnackbar.showError(context, 'Passwords do not match');
      setState(() => _confirmPasswordError = 'Passwords do not match');
      return;
    }

    try {
      setState(() => _isLoading = true);

      // Create user account with Supabase
      final response = await _authService.signUpWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;
      
      final user = response.user;
      if (user == null) {
        throw Exception('Failed to create user account');
      }

      // Check if email confirmation is required
      final session = response.session;
      
      print('🔍 Registration: Checking email confirmation requirement...');
      print('   Session exists: ${session != null}');
      print('   User email: ${user.email}');
      
      if (session == null) {
        print('📧 Email confirmation REQUIRED - creating basic profile now...');
        // Email confirmation required - create profile anyway so trigger fires
        try {
          // Create basic profile for unverified user
          await _authService.getOrCreateUserProfile();
          print('✅ Profile created for unverified user: ${user.email}');
          print('   This profile should now be in player_profiles table!');
          print('   Admin notification trigger should have fired!');
        } catch (e) {
          print('⚠️ Failed to create profile for unverified user: $e');
          // Continue anyway - user can complete profile after verification
        }
        
        setState(() => _isLoading = false);
        
        CustomSnackbar.showSuccess(
          context,
          'Registration successful! Please check your email to verify your account.',
        );
        
        // Navigate back to login after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const LoginWithPasswordScreen(),
              ),
            );
          }
        });
        return;
      }

      // User is logged in (email confirmation disabled)
      print('✅ Email confirmation DISABLED - user is logged in!');
      print('   Creating basic profile now...');
      
      // Create user profile from Supabase user
      PlayerProfile? userModel = await _authService.getOrCreateUserProfile();
      
      if (userModel == null) {
        throw Exception('Failed to create user profile');
      }

      print('✅ Basic profile created for ${userModel.email}');
      print('   This profile should now be in player_profiles table!');
      print('   Admin notification trigger should have fired!');
      print('   Now navigating to profile wizard to complete details...');

      setState(() => _isLoading = false);

      // Show success message
      CustomSnackbar.showSuccess(
        context,
        'Account created successfully!',
      );

      // Navigate to profile form
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => PlayerProfileFormScreen(userModel: userModel),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      
      setState(() => _isLoading = false);

      // Check if email already exists
      if (_authService.isEmailAlreadyExists(e)) {
        CustomSnackbar.showError(
          context,
          'This email is already registered. Please login instead.',
        );
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const LoginWithPasswordScreen(),
              ),
            );
          }
        });
        return;
      }

      // Show error message
      final errorMessage = _authService.getErrorMessage(e);
      CustomSnackbar.showError(context, errorMessage);
    }
  }

  void _showLanguageSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00BF63).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.language,
                          color: Color(0xFF00BF63),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Select Language / اختر اللغة',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildLanguageOption('English', 'en', '🇬🇧'),
                  const SizedBox(height: 12),
                  _buildLanguageOption('العربية', 'ar', '🇪🇬'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption(String name, String code, String flag) {
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    final isSelected = LocalizationManager.currentLocale.languageCode == code;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          // Change language
          final newLocale = code == 'en' 
              ? LocalizationManager.enLocale 
              : LocalizationManager.arLocale;
          
          await LocalizationManager.changeLocale(context, newLocale);
          localeProvider.setLocale(newLocale);
          
          // Close modal
          Navigator.pop(context);
          
          // Show success message
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white),
                    const SizedBox(width: 12),
                    Text(
                      code == 'en' 
                          ? 'Language changed to English' 
                          : 'تم تغيير اللغة إلى العربية',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                backgroundColor: const Color(0xFF00BF63),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected 
                ? const Color(0xFF00BF63).withOpacity(0.1)
                : Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected 
                  ? const Color(0xFF00BF63)
                  : Colors.grey[300]!,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Text(
                flag,
                style: const TextStyle(fontSize: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  name,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? const Color(0xFF00BF63) : Colors.black87,
                  ),
                ),
              ),
              if (isSelected)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color(0xFF00BF63),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
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
          child: ClipRect(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Language Button
                      Align(
                        alignment: Alignment.topRight,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _showLanguageSelector(context),
                                borderRadius: BorderRadius.circular(25),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.language,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'EN',
                                        style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Logo Section
                      Center(
                        child: Column(
                          children: [
                            SlideTransition(
                              position: _slideAnimation,
                              child: FadeTransition(
                                opacity: _fadeAnimation,
                                child: Hero(
                                  tag: 'logo',
                                  child: Text(
                                    'playmaker',
                                    style: GoogleFonts.leagueSpartan(
                                      fontSize: 42,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Create your account to get started',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                color: Colors.white.withOpacity(0.9),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      SizedBox(height: MediaQuery.of(context).size.height * 0.05),
                      
                      // Input Fields
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autocorrect: false,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: _inputDecoration('Email Address', Icons.email_outlined).copyWith(
                            errorText: _emailError,
                          ),
                          onChanged: (value) => _validateEmailRealtime(),
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextFormField(
                          controller: _passwordController,
                          textInputAction: TextInputAction.next,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                          obscureText: !_isPasswordVisible,
                          decoration: _inputDecoration('Password', Icons.lock_outline).copyWith(
                            errorText: _passwordError,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isPasswordVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                color: Colors.white.withOpacity(0.8),
                                size: 22,
                              ),
                              onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                            ),
                          ),
                          onChanged: (value) => _validatePasswordRealtime(),
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextFormField(
                          controller: _confirmPasswordController,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _handleRegistration(context),
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                          obscureText: !_isConfirmPasswordVisible,
                          decoration: _inputDecoration('Confirm Password', Icons.lock_outline).copyWith(
                            errorText: _confirmPasswordError,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isConfirmPasswordVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                color: Colors.white.withOpacity(0.8),
                                size: 22,
                              ),
                              onPressed: () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
                            ),
                          ),
                          onChanged: (value) => _validateConfirmPasswordRealtime(),
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Register Button
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : () => _handleRegistration(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF00BF63),
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                            disabledBackgroundColor: Colors.white.withOpacity(0.5),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20.0,
                                  width: 20.0,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.0,
                                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00BF63)),
                                  ),
                                )
                              : Text(
                                  'Create Account',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                      
                      const SizedBox(height: 30),
                      
                      // Divider
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 1,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    Colors.white.withOpacity(0.4),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Text(
                              'or continue with',
                              style: GoogleFonts.inter(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              height: 1,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    Colors.white.withOpacity(0.4),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Social Login Buttons
                      _socialLoginButton(
                        icon: FontAwesomeIcons.google,
                        color: Colors.red.shade600,
                        label: 'Continue with Google',
                        onTap: () => _bloc.handleSignInWithGoogle(context),
                      ),
                      
                      if (Platform.isIOS)
                        _socialLoginButton(
                          icon: FontAwesomeIcons.apple,
                          color: Colors.black,
                          label: 'Continue with Apple',
                          onTap: () => _bloc.handleSignInWithApple(context),
                        ),
                      
                      const SizedBox(height: 40),
                      
                      // Sign In Link
                      Center(
                        child: RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: GoogleFonts.inter(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                            children: [
                              const TextSpan(text: "Already have an account? "),
                              TextSpan(
                                text: 'Sign In',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  decoration: TextDecoration.underline,
                                  decorationColor: Colors.white,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () {
                                    Navigator.of(context).pushReplacement(
                                      MaterialPageRoute(
                                        builder: (context) => const LoginWithPasswordScreen(),
                                      ),
                                    );
                                  },
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Terms and Privacy
                      Center(
                        child: RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: GoogleFonts.inter(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 12,
                              height: 1.4,
                            ),
                            children: [
                              const TextSpan(text: 'By continuing, you agree to our '),
                              TextSpan(
                                text: 'Terms & Conditions',
                                style: GoogleFonts.inter(
                                  color: Colors.white.withOpacity(0.9),
                                  decoration: TextDecoration.underline,
                                  decorationColor: Colors.white.withOpacity(0.9),
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () {
                                    TermsAndConditionsModal.show(context);
                                  }
                              ),
                              const TextSpan(text: ' and '),
                              TextSpan(
                                text: 'Privacy Policy',
                                style: GoogleFonts.inter(
                                  color: Colors.white.withOpacity(0.9),
                                  decoration: TextDecoration.underline,
                                  decorationColor: Colors.white.withOpacity(0.9),
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () {
                                    PrivacyPolicyModal.show(context);
                                  }
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                    ],
                  ),
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
