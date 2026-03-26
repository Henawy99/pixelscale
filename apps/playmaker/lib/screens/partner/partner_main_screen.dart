import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:playmakerappstart/l10n/app_localizations.dart';
import 'package:playmakerappstart/models/footballfield_model.dart';
import 'package:playmakerappstart/screens/partner/partner_bookings_screen.dart';
import 'package:playmakerappstart/screens/partner/partner_revenue_screen.dart';
import 'package:playmakerappstart/screens/partner/partner_login_screen.dart';
import 'package:playmakerappstart/screens/partner/blocked_users_screen.dart';
import 'package:playmakerappstart/screens/management/management_login_screen.dart';
import 'package:playmakerappstart/services/notification_service.dart';
import 'package:playmakerappstart/services/management_service.dart';
import 'package:playmakerappstart/screens/partner/partner_camera_screen.dart';

class PartnerMainScreen extends StatefulWidget {
  final FootballField field;

  const PartnerMainScreen({Key? key, required this.field}) : super(key: key);

  @override
  State<PartnerMainScreen> createState() => _PartnerMainScreenState();
}

class _PartnerMainScreenState extends State<PartnerMainScreen> {
  int _selectedIndex = 0;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      PartnerBookingsScreen(field: widget.field),
      PartnerCameraScreen(field: widget.field),
      PartnerRevenueScreen(field: widget.field),
      BlockedUsersScreen(field: widget.field),
    ];
  }

  Future<void> _handleSignOut() async {
    final l10n = AppLocalizations.of(context)!;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.partner_signOut),
        content: Text(l10n.partner_signOutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.partner_cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.partner_signOut),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // Unregister partner device FCM token before signing out
      if (!kIsWeb) {
        try {
          await NotificationService().unregisterPartnerDevice(widget.field.id);
          print('✅ Partner device unregistered');
        } catch (e) {
          print('⚠️ Failed to unregister partner device: $e');
        }
      }
      
      // Clear saved session so next launch shows login screen
      await clearPartnerSession();
      
      // Navigate to appropriate login screen
      final Widget loginScreen = ManagementService.isUnifiedMode
          ? const ManagementLoginScreen()
          : const PartnerLoginScreen();
      
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => loginScreen),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isWideScreen = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(
              'playmaker ',
              style: GoogleFonts.leagueSpartan(
                fontWeight: FontWeight.w900,
                fontSize: 24,
              ),
            ),
            Text(
              'PARTNER',
              style: GoogleFonts.inter(
                color: Colors.blue.shade700,
                fontWeight: FontWeight.w600,
                fontSize: 16,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          if (isWideScreen)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Chip(
                avatar: const Icon(Icons.sports_soccer, size: 18),
                label: Text(
                  widget.field.footballFieldName,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                backgroundColor: Colors.blue.shade50,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleSignOut,
            tooltip: l10n.partner_signOut,
          ),
        ],
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.calendar_today_outlined),
            selectedIcon: const Icon(Icons.calendar_today),
            label: l10n.partner_bookingsTab,
          ),
          const NavigationDestination(
            icon: Icon(Icons.videocam_outlined),
            selectedIcon: Icon(Icons.videocam),
            label: 'Camera',
          ),
          NavigationDestination(
            icon: const Icon(Icons.attach_money_outlined),
            selectedIcon: const Icon(Icons.attach_money),
            label: l10n.partner_revenueTab,
          ),
          const NavigationDestination(
            icon: Icon(Icons.block_outlined),
            selectedIcon: Icon(Icons.block),
            label: 'Blocked',
          ),
        ],
      ),
    );
  }
}
