import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:playmakerappstart/config/app_config.dart';
import 'package:playmakerappstart/localization/app_localizations.dart';
import 'package:playmakerappstart/localization/locale_provider.dart';
import 'package:playmakerappstart/screens/admin/admin_main_screen.dart';
import 'package:playmakerappstart/screens/partner/partner_main_screen.dart';
import 'package:playmakerappstart/services/supabase_auth_service.dart';
import 'package:playmakerappstart/services/partner_service.dart';
import 'package:playmakerappstart/services/notification_service.dart';
import 'package:playmakerappstart/services/admin_notification_service.dart';
import 'package:provider/provider.dart';

/// Unified login screen for Management app
/// Automatically detects role based on credentials:
/// - Admin email (youssef@gmail.com) → Admin interface
/// - Partner credentials → Partner interface (field owner portal)
class ManagementLoginScreen extends StatefulWidget {
  const ManagementLoginScreen({Key? key}) : super(key: key);

  @override
  State<ManagementLoginScreen> createState() => _ManagementLoginScreenState();
}

class _ManagementLoginScreenState extends State<ManagementLoginScreen> {
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
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showError('Please enter email and password');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Check if admin email
      if (email.toLowerCase() == AppConfig.adminEmail.toLowerCase()) {
        await _handleAdminLogin(email, password);
      } else {
        await _handlePartnerLogin(email, password);
      }
    } catch (e) {
      _showError('Login failed: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleAdminLogin(String email, String password) async {
    try {
      final authService = SupabaseAuthService();
      final response = await authService.signInWithEmail(
        email: email,
        password: password,
      );

      if (response.user != null && mounted) {
        // Set admin flavor
        AppConfig.setFlavor(AppFlavor.admin);
        
        // Initialize admin notifications
        await AdminNotificationService().initializeAdminNotifications(email);
        
        // Navigate to admin screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const AdminMainScreen(),
          ),
        );
      } else {
        _showError('Invalid admin credentials');
      }
    } catch (e) {
      _showError('Admin login failed. Please check your credentials.');
    }
  }

  Future<void> _handlePartnerLogin(String email, String password) async {
    try {
      final field = await _partnerService.authenticateOwner(email, password);

      if (field != null && mounted) {
        // Set partner flavor
        AppConfig.setFlavor(AppFlavor.partner);
        
        // Initialize partner notifications
        await NotificationService().initializePartnerNotifications(field.id);
        
        // Navigate to partner screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => PartnerMainScreen(field: field),
          ),
        );
      } else {
        _showError('Invalid email or password');
      }
    } catch (e) {
      _showError('Login failed. Please check your credentials.');
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
                Icon(Icons.language, color: Colors.green.shade600),
                const SizedBox(width: 12),
                Text(
                  'Select Language',
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
    final size = MediaQuery.of(context).size;
    final isWideScreen = size.width > 900;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
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
                padding: EdgeInsets.all(isWideScreen ? 48.0 : 32.0),
                child: Container(
                  constraints: BoxConstraints(maxWidth: isWideScreen ? 500 : double.infinity),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Language Selector
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          onPressed: _showLanguageSelector,
                          icon: const Icon(Icons.language, size: 18, color: Colors.white),
                          label: Text(
                            'Language',
                            style: GoogleFonts.inter(fontSize: 14, color: Colors.white),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.white.withOpacity(0.5)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Logo Card
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Logo
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00BF63),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'playmaker',
                                style: GoogleFonts.leagueSpartan(
                                  fontSize: isWideScreen ? 48 : 36,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Management badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.admin_panel_settings, 
                                    color: Colors.grey.shade700, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'MANAGEMENT PORTAL',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.grey.shade700,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 24),
                            
                            Text(
                              'Sign in as Admin or Field Owner',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            
                            const SizedBox(height: 32),

                            // Email Field
                            TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              style: GoogleFonts.inter(),
                              decoration: InputDecoration(
                                labelText: 'Email',
                                hintText: 'Enter your email',
                                prefixIcon: const Icon(Icons.email_outlined),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFF00BF63), width: 2),
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Password Field
                            TextField(
                              controller: _passwordController,
                              obscureText: !_isPasswordVisible,
                              style: GoogleFonts.inter(),
                              decoration: InputDecoration(
                                labelText: 'Password',
                                hintText: 'Enter your password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                                  ),
                                  onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFF00BF63), width: 2),
                                ),
                              ),
                              onSubmitted: (_) => _handleLogin(),
                            ),

                            const SizedBox(height: 24),

                            // Login Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _handleLogin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00BF63),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
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
                                        'Sign In',
                                        style: GoogleFonts.inter(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Info Cards
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoCard(
                              icon: Icons.admin_panel_settings,
                              title: 'Admin',
                              subtitle: 'Platform management',
                              color: const Color(0xFF00BF63),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildInfoCard(
                              icon: Icons.business,
                              title: 'Partner',
                              subtitle: 'Field owner portal',
                              color: Colors.blue.shade600,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // Version
                      Text(
                        'v1.0.0',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.6),
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
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: Colors.white.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
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
          color: isSelected ? Colors.green.shade50 : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.green.shade600 : Colors.grey.shade200,
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
                  color: isSelected ? Colors.green.shade700 : Colors.black87,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: Colors.green.shade600, size: 20),
          ],
        ),
      ),
    );
  }
}
