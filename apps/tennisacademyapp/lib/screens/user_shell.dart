import 'package:flutter/material.dart';
import 'user_schedule_screen.dart';
import 'profile_screen.dart';

class UserShell extends StatefulWidget {
  const UserShell({super.key});

  @override
  State<UserShell> createState() => _UserShellState();
}

class _UserShellState extends State<UserShell> {
  int _index = 0;
  static const _yellow = Color(0xFFFFDE21);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          UserScheduleScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        selectedItemColor: Colors.black,
        backgroundColor: _yellow,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: 'Schedule'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
