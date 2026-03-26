import 'package:flutter/material.dart';
import 'package:restaurantadmin/screens/orders_screen.dart';
import 'package:restaurantadmin/screens/inventory_screen.dart';
import 'package:restaurantadmin/screens/menus_screen.dart';
import 'package:restaurantadmin/screens/payments_screen.dart';
import 'package:restaurantadmin/screens/receipt_watcher_screen.dart';
import 'package:restaurantadmin/screens/employees/schedule_tab.dart';
import 'package:restaurantadmin/services/employee_assignments_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:restaurantadmin/models/employee.dart';
import 'package:restaurantadmin/services/app_nav_service.dart';
import 'package:restaurantadmin/services/push_notification_service.dart';

class MainScreen extends StatefulWidget {
  static const String routeName = '/';
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final AppNavService _nav = AppNavService();
  VoidCallback? _navListener;
  int _selectedIndex = 0;

  static final List<Widget> _widgetOptions = <Widget>[
    const OrdersScreen(),
    const InventoryScreen(),
    const MenusScreen(),
    const PaymentsScreen(),
    const ReceiptWatcherScreen(),
    _EmployeesRoot(),
  ];

  static const List<String> _appBarTitles = <String>[
    'Orders',
    'Inventory',
    'Menus',
    'Payments',
    'Receipts',
    'Employees',
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    _navListener = () {
      if (mounted) setState(() => _selectedIndex = _nav.selectedTab.value);
    };
    _nav.selectedTab.addListener(_navListener!);
    
    // Initialize push notifications for admin (youssef@gmail.com)
    _initializePushNotifications();
  }
  
  Future<void> _initializePushNotifications() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final email = user?.email?.toLowerCase() ?? '';
      
      print('========================================');
      print('[MainScreen] Checking push notification eligibility');
      print('[MainScreen] Current user email: $email');
      print('========================================');
      
      if (email == 'youssef@gmail.com') {
        print('[MainScreen] ✅ User is youssef@gmail.com - initializing push notifications...');
        await PushNotificationService().initialize();
        print('[MainScreen] ✅ Push notification initialization complete!');
      } else {
        print('[MainScreen] ❌ User is not youssef@gmail.com - skipping push notifications');
      }
    } catch (e, stackTrace) {
      print('[MainScreen] ❌ Error initializing push notifications: $e');
      print('[MainScreen] Stack trace: $stackTrace');
    }
  }

  @override
  void dispose() {
    if (_navListener != null) {
      _nav.selectedTab.removeListener(_navListener!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Employees tab (index 5) has its own Scaffold with AppBar
    final bool showAppBar = _selectedIndex != 5;
    
    return Scaffold(
      appBar: showAppBar ? AppBar(
        title: Text(_appBarTitles[_selectedIndex]),
      ) : null,
      body: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2),
            label: 'Inventory',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.restaurant_menu),
            label: 'Menus',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.payment),
            label: 'Payments',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.image_search),
            label: 'Receipts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.group),
            label: 'Employees',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}

// Lightweight Employees root that only shows the Schedule tab
class _EmployeesRoot extends StatefulWidget {
  @override
  State<_EmployeesRoot> createState() => _EmployeesRootState();
}

class _EmployeesRootState extends State<_EmployeesRoot> {
  List<Employee> _employees = const [];
  bool _loading = true;
  late final EmployeeAssignmentsRepository _repo;

  @override
  void initState() {
    super.initState();
    _repo = EmployeeAssignmentsRepository(client: Supabase.instance.client);
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    setState(() => _loading = true);
    try {
      final data = await Supabase.instance.client
          .from('employees')
          .select('id, created_at, updated_at, name, active, hourly_wage, weekly_schedule, color_index')
          .order('name');
      _employees = (data as List).map((e) => Employee.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return ScheduleTab(employees: _employees, repo: _repo);
  }
}
