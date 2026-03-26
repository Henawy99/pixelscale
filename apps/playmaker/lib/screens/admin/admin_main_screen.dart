import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:playmakerappstart/screens/admin/admin_login_screen.dart';
import 'package:playmakerappstart/screens/admin/admin_users_screen.dart';
import 'package:playmakerappstart/screens/admin/admin_bookings_screen.dart';
import 'package:playmakerappstart/screens/admin/admin_fields_screen.dart';
import 'package:playmakerappstart/screens/admin/admin_ball_tracking_screen.dart';
import 'package:playmakerappstart/screens/admin/admin_notifications_dashboard.dart';
import 'package:playmakerappstart/screens/admin/admin_camera_monitoring_screen.dart';
import 'package:playmakerappstart/screens/management/management_login_screen.dart';
import 'package:playmakerappstart/services/admin_notification_service.dart';
import 'package:playmakerappstart/services/supabase_auth_service.dart';
import 'package:playmakerappstart/services/management_service.dart';

class AdminMainScreen extends StatefulWidget {
  const AdminMainScreen({Key? key}) : super(key: key);

  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const AdminUsersScreen(),
    const AdminBookingsScreen(),
    const AdminFieldsScreen(),
    const AdminBallTrackingScreen(),
    const AdminCameraMonitoringScreen(),
    const AdminNotificationsDashboard(),
  ];

  Future<void> _handleSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Unregister admin device before signing out
      if (!kIsWeb) {
        try {
          await AdminNotificationService().unregisterAdminDevice();
          print('✅ Admin device unregistered');
        } catch (e) {
          print('⚠️ Failed to unregister admin device: $e');
        }
      }
      
      await SupabaseAuthService().signOut();
      if (mounted) {
        // Navigate to appropriate login screen
        final Widget loginScreen = ManagementService.isUnifiedMode
            ? const ManagementLoginScreen()
            : const AdminLoginScreen();
        
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => loginScreen),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
              'ADMIN',
              style: GoogleFonts.inter(
                color: const Color(0xFF00BF63),
                fontWeight: FontWeight.w600,
                fontSize: 16,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleSignOut,
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Users',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today),
            label: 'Bookings',
          ),
          NavigationDestination(
            icon: Icon(Icons.sports_soccer_outlined),
            selectedIcon: Icon(Icons.sports_soccer),
            label: 'Fields',
          ),
          NavigationDestination(
            icon: Icon(Icons.sports_outlined),
            selectedIcon: Icon(Icons.sports),
            label: 'Tracking',
          ),
          NavigationDestination(
            icon: Icon(Icons.videocam_outlined),
            selectedIcon: Icon(Icons.videocam),
            label: 'Cameras',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: 'Alerts',
          ),
        ],
      ),
    );
  }
}
