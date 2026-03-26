import 'package:flutter/material.dart';
import 'package:restaurantadmin/screens/driver/driver_home_screen.dart';

class DriverAppShell extends StatelessWidget {
  static const String routeName = '/driver';
  const DriverAppShell({super.key});

  @override
  Widget build(BuildContext context) {
    return const DriverHomeScreen();
  }
}
