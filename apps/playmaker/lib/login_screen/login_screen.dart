import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:playmakerappstart/login_screen/login_screen_bloc.dart';
import 'package:playmakerappstart/privacy_policy_modal.dart';
import 'package:playmakerappstart/register_screen.dart';
import 'package:playmakerappstart/terms_conditions_modal.dart';
import 'package:playmakerappstart/main_screen.dart';
import 'package:playmakerappstart/models/user_model.dart';
import 'package:playmakerappstart/utils/validators.dart';
import 'package:playmakerappstart/widgets/custom_snackbar.dart';
import 'package:playmakerappstart/localization/app_localizations.dart';
import 'package:playmakerappstart/localization/locale_provider.dart';
import 'package:provider/provider.dart';

class LoginWithPasswordScreen extends StatefulWidget {
  const LoginWithPasswordScreen({Key? key}) : super(key: key);

  @override
  _LoginWithPasswordScreenState createState() => _LoginWithPasswordScreenState();
}

class _LoginWithPasswordScreenState extends State<LoginWithPasswordScreen> with TickerProviderStateMixin {
  final AuthenticationBloc _bloc = AuthenticationBloc();
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  String? _emailError;
  String? _passwordError;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    // Logo slide-in animation
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
      } else if (_passwordController.text.length < 6) {
        _passwordError = 'Password must be at least 6 characters';
      } else {
        _passwordError = null;
      }
    });
  }

  Future<void> _handleLogin() async {
    // Validate form
    final emailError = Validators.validateEmail(_emailController.text);
    if (emailError != null) {
      CustomSnackbar.showError(context, emailError);
      setState(() => _emailError = emailError);
      return;
    }

    if (_passwordController.text.isEmpty) {
      CustomSnackbar.showError(context, 'Please enter your password');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _bloc.handleEmailSignIn(
        context,
        _emailController.text.trim(),
        _passwordController.text,
      );
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

  Widget _socialLoginButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required String label,
    required bool isSmallScreen,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: isSmallScreen ? 4 : 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 16 : 24,
              vertical: isSmallScreen ? 12 : 15,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: isSmallScreen ? 16 : 20, color: color),
                SizedBox(width: isSmallScreen ? 10 : 12),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    color: Colors.grey.shade800,
                    fontWeight: FontWeight.w600,
                    fontSize: isSmallScreen ? 13 : 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
      labelStyle: GoogleFonts.inter(
        color: Colors.white.withOpacity(0.8),
        fontWeight: FontWeight.w500,
      ),
      floatingLabelStyle: GoogleFonts.inter(
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenHeight < 700;
    
    return GestureDetector(
      onTap: () {
        // Dismiss keyboard when tapping outside
        FocusScope.of(context).unfocus();
      },
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
          child: Column(
            children: [
              // Custom App Bar
              Padding(
                padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Language Button
                    Container(
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
                            padding: EdgeInsets.symmetric(
                              horizontal: isSmallScreen ? 12 : 16,
                              vertical: isSmallScreen ? 8 : 12,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.language,
                                  color: Colors.white,
                                  size: isSmallScreen ? 16 : 18,
                                ),
                                SizedBox(width: isSmallScreen ? 6 : 8),
                                Text(
                                  'EN',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: isSmallScreen ? 12 : 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Explore App Button
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (context) => MainScreen(
                                  userModel: PlayerProfile(
                                    id: 'guest',
                                    email: '',
                                    name: 'Guest',
                                    isGuest: true,
                                    nationality: '',
                                    age: '',
                                    preferredPosition: '',
                                  ),
                                ),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(25),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isSmallScreen ? 16 : 20,
                              vertical: isSmallScreen ? 8 : 12,
                            ),
                            child: Text(
                              'Explore App',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF00BF63),
                                fontWeight: FontWeight.w700,
                                fontSize: isSmallScreen ? 12 : 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Main Content (Non-scrollable)
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.08),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(height: isSmallScreen ? 10 : 20),
                          
                          // Logo Section with Animation
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
                                          fontSize: isSmallScreen ? 32 : 42,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                          letterSpacing: 1.5,
                                          height: 1.2,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: isSmallScreen ? 12 : 16),
                                Text(
                                  'Welcome back! Sign in to continue',
                                  style: GoogleFonts.inter(
                                    fontSize: isSmallScreen ? 13 : 16,
                                    color: Colors.white.withOpacity(0.9),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                          
                          SizedBox(height: screenHeight * (isSmallScreen ? 0.03 : 0.04)),
                            
                          // Input Fields
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
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autocorrect: false,
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                                fontSize: isSmallScreen ? 14 : 15,
                              ),
                              decoration: _inputDecoration('Email Address', Icons.email_outlined).copyWith(
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: isSmallScreen ? 14 : 18,
                                ),
                                errorText: _emailError,
                                errorStyle: GoogleFonts.inter(
                                  color: Colors.red.shade300,
                                  fontSize: isSmallScreen ? 10 : 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              onChanged: (value) => _validateEmailRealtime(),
                            ),
                          ),
                          
                          SizedBox(height: isSmallScreen ? 12 : 16),
                            
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
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _handleLogin(),
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                                fontSize: isSmallScreen ? 14 : 15,
                              ),
                              obscureText: !_isPasswordVisible,
                              decoration: _inputDecoration('Password', Icons.lock_outline).copyWith(
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: isSmallScreen ? 14 : 18,
                                ),
                                errorText: _passwordError,
                                errorStyle: GoogleFonts.inter(
                                  color: Colors.red.shade300,
                                  fontSize: isSmallScreen ? 10 : 12,
                                  fontWeight: FontWeight.w500,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isPasswordVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                    color: Colors.white.withOpacity(0.8),
                                    size: isSmallScreen ? 20 : 22,
                                  ),
                                  onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                                ),
                              ),
                              onChanged: (value) => _validatePasswordRealtime(),
                            ),
                          ),

                          SizedBox(height: isSmallScreen ? 8 : 12),
                            
                          // Forgot Password
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => _bloc.resetPassword(context),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: isSmallScreen ? 2 : 4,
                                ),
                              ),
                              child: Text(
                                'Forgot Password?',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                  fontSize: isSmallScreen ? 12 : 14,
                                ),
                              ),
                            ),
                          ),
                          
                          SizedBox(height: screenHeight * (isSmallScreen ? 0.02 : 0.03)),
                            
                          // Sign In Button
                          Container(
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
                              onPressed: _isLoading ? null : _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF00BF63),
                                disabledBackgroundColor: Colors.white.withOpacity(0.5),
                                padding: EdgeInsets.symmetric(
                                  vertical: isSmallScreen ? 14 : 18,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                              child: _isLoading
                                  ? SizedBox(
                                      height: isSmallScreen ? 18 : 20,
                                      width: isSmallScreen ? 18 : 20,
                                      child: const CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00BF63)),
                                      ),
                                    )
                                  : Text(
                                      'Sign In',
                                      style: GoogleFonts.inter(
                                        fontSize: isSmallScreen ? 14 : 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),
                          
                          SizedBox(height: screenHeight * (isSmallScreen ? 0.02 : 0.025)),
                            
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
                                padding: EdgeInsets.symmetric(
                                  horizontal: isSmallScreen ? 12 : 16,
                                ),
                                child: Text(
                                  'or continue with',
                                  style: GoogleFonts.inter(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: isSmallScreen ? 11 : 13,
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
                          
                          SizedBox(height: screenHeight * (isSmallScreen ? 0.015 : 0.02)),
                            
                          // Social Login Buttons
                          _socialLoginButton(
                            icon: FontAwesomeIcons.google,
                            color: Colors.red.shade600,
                            label: 'Continue with Google',
                            onTap: () => _bloc.handleSignInWithGoogle(context),
                            isSmallScreen: isSmallScreen,
                          ),
                          
                          if (Platform.isIOS)
                            _socialLoginButton(
                              icon: FontAwesomeIcons.apple,
                              color: Colors.black,
                              label: 'Continue with Apple',
                              onTap: () => _bloc.handleSignInWithApple(context),
                              isSmallScreen: isSmallScreen,
                            ),
                          
                          // DEMO ACCOUNT BUTTON
                          _socialLoginButton(
                            icon: FontAwesomeIcons.play,
                            color: Colors.orange.shade600,
                            label: 'Demo Account (Showcase)',
                            onTap: () {
                              _emailController.text = 'demo@playmaker.com';
                              _passwordController.text = 'demo_password123';
                              _handleLogin();
                            },
                            isSmallScreen: isSmallScreen,
                          ),
                          
                          const Spacer(),
                            
                          // Sign Up Link
                          Center(
                            child: RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                style: GoogleFonts.inter(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: isSmallScreen ? 13 : 15,
                                  fontWeight: FontWeight.w500,
                                ),
                                children: [
                                  const TextSpan(text: "Don't have an account? "),
                                  TextSpan(
                                    text: 'Sign Up',
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
                                            builder: (context) => const RegistrationScreen(),
                                          ),
                                        );
                                      },
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
                          SizedBox(height: isSmallScreen ? 10 : 16),
                            
                          // Terms and Privacy
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: isSmallScreen ? 8 : 12,
                            ),
                            child: Center(
                              child: RichText(
                                textAlign: TextAlign.center,
                                text: TextSpan(
                                  style: GoogleFonts.inter(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: isSmallScreen ? 10 : 12,
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
                          ),
                          
                          // Version number
                          Padding(
                            padding: EdgeInsets.only(bottom: isSmallScreen ? 8 : 12),
                            child: Text(
                              'v1.0.8',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: Colors.white.withOpacity(0.3),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
