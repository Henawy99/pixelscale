import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:playmakerappstart/l10n/app_localizations.dart';
import 'package:playmakerappstart/tabs/bookings_tab.dart';
import 'package:playmakerappstart/color_class.dart';
import 'package:playmakerappstart/tabs/matches_tab.dart';
import 'package:playmakerappstart/models/user_model.dart';
import 'package:playmakerappstart/tabs/profile_tab.dart';
import 'package:playmakerappstart/tabs/squads_tab.dart';

class MainScreen extends StatefulWidget {
  final PlayerProfile userModel;
  final int initialTabIndex;

  const MainScreen({
    Key? key,
    required this.userModel,
    this.initialTabIndex = 1, // Default to Bookings tab (Play tab)
  }) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _selectedIndex;
  late List<Widget> _widgetOptions;
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTabIndex;
    _widgetOptions = _buildWidgetOptions();
    _getCurrentLocation();
  }

  List<Widget> _buildWidgetOptions() {
    return [
      MatchesScreen(userModel: widget.userModel),
      BookingsScreen(
        currentPosition: _currentPosition,
        playerProfile: widget.userModel,
      ),
      SquadsScreen(playerProfile: widget.userModel),
      ProfileScreen(playerProfile: widget.userModel),
    ];
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.deniedForever) return;

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );
      
      if (mounted) {
        setState(() {
          _currentPosition = position;
          _widgetOptions = _buildWidgetOptions();
        });
      }
    } catch (e) {
      print(AppLocalizations.of(context)!.mainScreen_errorGettingLocation(e.toString()));
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  index: 0,
                  icon: Icons.sports_soccer,
                  activeIcon: Icons.sports_soccer,
                  label: AppLocalizations.of(context)!.mainScreen_navMatches,
                ),
                _buildNavItem(
                  index: 1,
                  icon: FontAwesomeIcons.futbol,
                  activeIcon: FontAwesomeIcons.futbol,
                  label: AppLocalizations.of(context)!.mainScreen_navBook,
                ),
                _buildNavItem(
                  index: 2,
                  icon: Icons.groups_outlined,
                  activeIcon: Icons.groups_rounded,
                  label: AppLocalizations.of(context)!.mainScreen_navSquads,
                ),
                _buildNavItem(
                  index: 3,
                  icon: Icons.person_outline,
                  activeIcon: Icons.person,
                  label: AppLocalizations.of(context)!.mainScreen_navProfile,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final bool isSelected = _selectedIndex == index;
    final Color activeColor = AppColors.backgroundColor;
    final Color inactiveColor = Colors.grey.shade400;

    return Expanded(
      child: InkWell(
        onTap: () => _onItemTapped(index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: isSelected 
                ? activeColor.withOpacity(0.1)
                : Colors.transparent,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSelected ? activeIcon : icon,
                color: isSelected ? activeColor : inactiveColor,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? activeColor : inactiveColor,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontFamily: 'Inter',
                  letterSpacing: 0.3,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
