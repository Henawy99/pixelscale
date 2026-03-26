import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:playmakerappstart/l10n/app_localizations.dart';
import 'package:playmakerappstart/localization/app_localizations.dart';
import 'package:playmakerappstart/localization/locale_provider.dart';
import 'package:playmakerappstart/screens/partner/partner_main_screen.dart';
import 'package:playmakerappstart/services/partner_service.dart';
import 'package:playmakerappstart/services/notification_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// SharedPreferences keys for partner session persistence
const _kPartnerFieldId = 'partner_field_id';
const _kPartnerEmail = 'partner_email';

/// Clears the saved partner session so next launch shows login screen
Future<void> clearPartnerSession() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_kPartnerFieldId);
  await prefs.remove(_kPartnerEmail);
}

/// Auto-login wrapper shown on app start for the partner flavor.
/// Reads saved session and skips login if a valid field exists.
class PartnerAutoLoginWrapper extends StatefulWidget {
  const PartnerAutoLoginWrapper({Key? key}) : super(key: key);

  @override
  State<PartnerAutoLoginWrapper> createState() => _PartnerAutoLoginWrapperState();
}

class _PartnerAutoLoginWrapperState extends State<PartnerAutoLoginWrapper> {
  @override
  void initState() {
    super.initState();
    _tryAutoLogin();
  }

  Future<void> _tryAutoLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedFieldId = prefs.getString(_kPartnerFieldId);

      if (savedFieldId == null || savedFieldId.isEmpty) {
        // No saved session → go to login
        _goToLogin();
        return;
      }

      // Re-fetch the field to ensure it still exists
      final partnerService = PartnerService();
      final field = await partnerService.getFieldById(savedFieldId);

      if (field != null && mounted) {
        // Silently re-init notifications (non-blocking)
        NotificationService().initializePartnerNotifications(field.id).catchError((_) {});
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => PartnerMainScreen(field: field)),
        );
      } else {
        // Field no longer exists or error → clear stale session and show login
        await prefs.remove(_kPartnerFieldId);
        await prefs.remove(_kPartnerEmail);
        _goToLogin();
      }
    } catch (e) {
      print('PartnerAutoLogin error: $e');
      _goToLogin();
    }
  }

  void _goToLogin() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const PartnerLoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show a branded splash while auto-login is in progress
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade600, Colors.blue.shade400],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.business, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 24),
            Text(
              'playmaker',
              style: GoogleFonts.leagueSpartan(
                fontSize: 40,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF00BF63),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'PARTNER PORTAL',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.blue.shade700,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade400),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PartnerLoginScreen extends StatefulWidget {
  const PartnerLoginScreen({Key? key}) : super(key: key);

  @override
  State<PartnerLoginScreen> createState() => _PartnerLoginScreenState();
}

class _PartnerLoginScreenState extends State<PartnerLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _partnerService = PartnerService();
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      _showError('Please enter email and password');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final field = await _partnerService.authenticateOwner(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (field != null) {
        // Persist session so the partner stays logged in on restart
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_kPartnerFieldId, field.id);
        await prefs.setString(_kPartnerEmail, _emailController.text.trim());

        // Initialize partner notifications
        await NotificationService().initializePartnerNotifications(field.id);
        
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => PartnerMainScreen(field: field),
            ),
          );
        }
      } else {
        _showError('Invalid email or password');
      }
    } catch (e) {
      _showError('Login failed: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showLanguageSelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.language, color: Colors.blue.shade600),
                const SizedBox(width: 12),
                Text(
                  AppLocalizations.of(context)!.partner_selectLanguage,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _LanguageOption(
              label: 'English',
              icon: '🇬🇧',
              isSelected: LocalizationManager.currentLocale.languageCode == 'en',
              onTap: () async {
                await LocalizationManager.changeLocale(context, LocalizationManager.enLocale);
                Provider.of<LocaleProvider>(context, listen: false).setLocale(LocalizationManager.enLocale);
                if (mounted) Navigator.pop(context);
              },
            ),
            const SizedBox(height: 8),
            _LanguageOption(
              label: 'العربية',
              icon: '🇪🇬',
              isSelected: LocalizationManager.currentLocale.languageCode == 'ar',
              onTap: () async {
                await LocalizationManager.changeLocale(context, LocalizationManager.arLocale);
                Provider.of<LocaleProvider>(context, listen: false).setLocale(LocalizationManager.arLocale);
                if (mounted) Navigator.pop(context);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final size = MediaQuery.of(context).size;
    final isWideScreen = size.width > 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isWideScreen ? 48.0 : 32.0),
            child: Center(
              child: Container(
                constraints: BoxConstraints(maxWidth: isWideScreen ? 500 : double.infinity),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Language Selector Button
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: _showLanguageSelector,
                        icon: const Icon(Icons.language, size: 18),
                        label: Text(
                          l10n.partner_selectLanguage,
                          style: GoogleFonts.inter(fontSize: 14),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue.shade600,
                          side: BorderSide(color: Colors.blue.shade200),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Logo
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.blue.shade600,
                                  Colors.blue.shade400,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.business,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'playmaker',
                            style: GoogleFonts.leagueSpartan(
                              fontSize: isWideScreen ? 56 : 48,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF00BF63),
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'PARTNER PORTAL',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.blue.shade700,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            l10n.partner_loginSubtitle,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 48),

                    // Email Field
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: l10n.partner_emailLabel,
                        hintText: l10n.partner_emailHint,
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Password Field
                    TextField(
                      controller: _passwordController,
                      obscureText: !_isPasswordVisible,
                      decoration: InputDecoration(
                        labelText: l10n.partner_passwordLabel,
                        hintText: l10n.partner_passwordHint,
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                          ),
                          onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onSubmitted: (_) => _handleLogin(),
                    ),

                    const SizedBox(height: 32),

                    // Login Button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              l10n.partner_signInButton,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Version number
                    Text(
                      'v1.0.2',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.grey.shade400,
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

class _LanguageOption extends StatelessWidget {
  final String label;
  final String icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageOption({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade50 : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blue.shade600 : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? Colors.blue.shade700 : Colors.black87,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: Colors.blue.shade600, size: 20),
          ],
        ),
      ),
    );
  }
}
