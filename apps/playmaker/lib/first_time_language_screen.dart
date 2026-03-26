import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:playmakerappstart/login_screen/login_screen.dart';
import 'package:playmakerappstart/localization/app_localizations.dart';
import 'package:playmakerappstart/localization/locale_provider.dart';
import 'package:provider/provider.dart';

class FirstTimeLanguageScreen extends StatefulWidget {
  const FirstTimeLanguageScreen({Key? key}) : super(key: key);

  @override
  State<FirstTimeLanguageScreen> createState() => _FirstTimeLanguageScreenState();
}

class _FirstTimeLanguageScreenState extends State<FirstTimeLanguageScreen> with TickerProviderStateMixin {
  String? _selectedLanguage;
  bool _isAnimating = false;
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
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _selectLanguage(String languageCode) async {
    setState(() {
      _selectedLanguage = languageCode;
      _isAnimating = true;
    });

    // Get the locale based on language code
    final newLocale = languageCode == 'ar' 
        ? LocalizationManager.arLocale 
        : LocalizationManager.enLocale;

    // Save language preference using LocalizationManager (correct key)
    await LocalizationManager.changeLocale(context, newLocale);
    
    // Update the LocaleProvider to trigger UI rebuild
    if (mounted) {
      Provider.of<LocaleProvider>(context, listen: false).setLocale(newLocale);
    }

    // Also save the flag that user has selected a language
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_selected_language', true);

    // Wait for animation
    await Future.delayed(const Duration(milliseconds: 800));

    if (mounted) {
      // Navigate to login screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const LoginWithPasswordScreen(),
        ),
      );
    }
  }

  Widget _buildLanguageCard({
    required String language,
    required String nativeText,
    required String languageCode,
    required IconData icon,
  }) {
    final isSelected = _selectedLanguage == languageCode;
    
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isSelected ? 0.2 : 0.1),
              blurRadius: isSelected ? 20 : 10,
              offset: Offset(0, isSelected ? 8 : 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: _isAnimating ? null : () => _selectLanguage(languageCode),
            borderRadius: BorderRadius.circular(20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? const Color(0xFF00BF63) : Colors.transparent,
                  width: 3,
                ),
              ),
              child: Row(
                children: [
                  // Language Icon/Flag
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? const Color(0xFF00BF63) 
                          : const Color(0xFF00BF63).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      icon,
                      size: 32,
                      color: isSelected ? Colors.white : const Color(0xFF00BF63),
                    ),
                  ),
                  const SizedBox(width: 20),
                  
                  // Language Text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          language,
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isSelected 
                                ? const Color(0xFF00BF63) 
                                : Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          nativeText,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Selection Indicator
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? const Color(0xFF00BF63) : Colors.transparent,
                      border: Border.all(
                        color: isSelected ? const Color(0xFF00BF63) : Colors.grey.shade400,
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(
                            Icons.check,
                            size: 16,
                            color: Colors.white,
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 60),
                    
                    // Logo
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
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
                    ),
                    
                    const SizedBox(height: 60),
                    
                    // Welcome Text
                    Text(
                      'Welcome!',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    Text(
                      'Choose your language to get started',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    
                    const SizedBox(height: 60),
                    
                    // Language Cards
                    _buildLanguageCard(
                      language: 'English',
                      nativeText: 'English',
                      languageCode: 'en',
                      icon: Icons.language,
                    ),
                    
                    _buildLanguageCard(
                      language: 'Arabic',
                      nativeText: 'العربية',
                      languageCode: 'ar',
                      icon: Icons.language,
                    ),
                    
                    const Spacer(),
                    
                    // Info Text
                    if (!_isAnimating)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.white.withOpacity(0.9),
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'You can change this anytime in settings',
                                style: GoogleFonts.inter(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    const SizedBox(height: 40),
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

