import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:playmakerappstart/localization/app_localizations.dart';
import 'package:playmakerappstart/localization/locale_provider.dart';
import 'package:provider/provider.dart';

class LanguageSettingsScreen extends StatefulWidget {
  const LanguageSettingsScreen({Key? key}) : super(key: key);

  @override
  State<LanguageSettingsScreen> createState() => _LanguageSettingsScreenState();
}

class _LanguageSettingsScreenState extends State<LanguageSettingsScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String get _currentLanguage => LocalizationManager.currentLocale.languageCode;

  Future<void> _changeLanguage(String languageCode) async {
    if (_currentLanguage == languageCode) return;
    
    final newLocale = languageCode == 'en' 
        ? LocalizationManager.enLocale 
        : LocalizationManager.arLocale;
    
    await LocalizationManager.changeLocale(context, newLocale);
    Provider.of<LocaleProvider>(context, listen: false).setLocale(newLocale);

    if (mounted) {
      setState(() {}); // Trigger rebuild to update UI
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Text(
                languageCode == 'en' 
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
  }

  Widget _buildLanguageCard({
    required String language,
    required String nativeText,
    required String languageCode,
    required IconData icon,
    required int index,
  }) {
    final isSelected = _currentLanguage == languageCode;
    
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 400 + (index * 100)),
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
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isSelected ? 0.15 : 0.08),
              blurRadius: isSelected ? 16 : 8,
              offset: Offset(0, isSelected ? 6 : 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: () => _changeLanguage(languageCode),
            borderRadius: BorderRadius.circular(20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? const Color(0xFF00BF63) : Colors.grey.shade200,
                  width: isSelected ? 3 : 2,
                ),
                gradient: isSelected
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF00BF63).withOpacity(0.1),
                          const Color(0xFF00A854).withOpacity(0.05),
                        ],
                      )
                    : null,
              ),
              child: Row(
                children: [
                  // Language Icon
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF00BF63),
                                Color(0xFF00A854),
                              ],
                            )
                          : null,
                      color: isSelected ? null : const Color(0xFF00BF63).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      icon,
                      size: 28,
                      color: isSelected ? Colors.white : const Color(0xFF00BF63),
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Language Text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          language,
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isSelected 
                                ? const Color(0xFF00BF63) 
                                : Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          nativeText,
                          style: GoogleFonts.inter(
                            fontSize: 14,
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
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: isSelected
                          ? const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF00BF63),
                                Color(0xFF00A854),
                              ],
                            )
                          : null,
                      color: isSelected ? null : Colors.transparent,
                      border: Border.all(
                        color: isSelected ? const Color(0xFF00BF63) : Colors.grey.shade400,
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(
                            Icons.check,
                            size: 14,
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
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          _currentLanguage == 'en' ? 'Language Settings' : 'إعدادات اللغة',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Section
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF00BF63),
                      Color(0xFF00A854),
                      Color(0xFF009148),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00BF63).withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.language,
                        size: 32,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _currentLanguage == 'en' 
                                ? 'Select Your Language' 
                                : 'اختر لغتك',
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _currentLanguage == 'en'
                                ? 'Choose your preferred language'
                                : 'اختر لغتك المفضلة',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.9),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Language Options
              Text(
                _currentLanguage == 'en' ? 'Available Languages' : 'اللغات المتاحة',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
              
              const SizedBox(height: 16),
              
              _buildLanguageCard(
                language: 'English 🇬🇧',
                nativeText: 'English',
                languageCode: 'en',
                icon: Icons.language,
                index: 0,
              ),
              
              _buildLanguageCard(
                language: 'Arabic 🇪🇬',
                nativeText: 'العربية',
                languageCode: 'ar',
                icon: Icons.language,
                index: 1,
              ),
              
              const SizedBox(height: 24),
              
              // Info Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.blue.shade100,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: Colors.blue.shade700,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _currentLanguage == 'en'
                            ? 'The app will restart to apply the language change'
                            : 'سيتم إعادة تشغيل التطبيق لتطبيق تغيير اللغة',
                        style: GoogleFonts.inter(
                          color: Colors.blue.shade700,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
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
