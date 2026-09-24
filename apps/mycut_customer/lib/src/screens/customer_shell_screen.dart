import 'package:flutter/material.dart';
import 'package:mycut_customer/src/screens/barber_qr_tab_screen.dart';
import 'package:mycut_customer/src/screens/home_dashboard_screen.dart';
import 'package:mycut_customer/src/screens/my_looks_screen.dart';
import 'package:mycut_customer/src/screens/studio_tab_screen.dart';
import 'package:mycut_customer/src/widgets/mycut_app_header.dart';
import 'package:mycut_customer/src/widgets/mycut_bottom_nav_bar.dart';
import 'package:mycut_ui/mycut_ui.dart';

/// The main customer shell featuring the top luxury header and bottom nav bar.
class CustomerShellScreen extends StatefulWidget {
  const CustomerShellScreen({super.key, this.initialTabIndex = 0});

  final int initialTabIndex;

  @override
  State<CustomerShellScreen> createState() => _CustomerShellScreenState();
}

class _CustomerShellScreenState extends State<CustomerShellScreen> {
  late int _currentIndex;
  String? _selectedLookIdForQr;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex;
  }

  void _onTabSelected(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      // Tab 0: Home
      HomeDashboardScreen(
        onNavigateToStudio: () => _onTabSelected(1),
        onNavigateToGoLooks: () => _onTabSelected(2),
        onNavigateToBarberQr: (lookId) {
          setState(() {
            _selectedLookIdForQr = lookId;
            _currentIndex = 3;
          });
        },
      ),

      // Tab 1: Studio (Face calibration & capture)
      StudioTabScreen(isActive: _currentIndex == 1),

      // Tab 2: Looks (Saved look dossiers)
      const MyLooksScreen(isEmbedded: true),

      // Tab 3: Barber QR (Station handoff)
      BarberQrTabScreen(preferredLookId: _selectedLookIdForQr),
    ];

    return Scaffold(
      backgroundColor: MyCutColors.surface,
      appBar: const MyCutAppHeader(),
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: MyCutBottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onTabSelected,
      ),
    );
  }
}
