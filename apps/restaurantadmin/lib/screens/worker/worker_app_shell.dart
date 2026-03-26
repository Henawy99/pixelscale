import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:restaurantadmin/screens/auth/login_screen.dart';
import 'package:restaurantadmin/services/worker_cache_service.dart';
import 'worker_menus_screen.dart';

class WorkerAppShell extends StatefulWidget {
  static const routeName = '/worker-app';
  const WorkerAppShell({super.key});

  @override
  State<WorkerAppShell> createState() => _WorkerAppShellState();
}

class _WorkerAppShellState extends State<WorkerAppShell> {
  final _supabase = Supabase.instance.client;
  bool _isInitialized = false;
  final GlobalKey<WorkerMenusScreenState> _menusKey = GlobalKey<WorkerMenusScreenState>();

  @override
  void initState() {
    super.initState();
    _initializeCache();
  }

  Future<void> _initializeCache() async {
    try {
      await WorkerCacheService.instance.initialize();
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      print('Error initializing worker cache: $e');
      if (mounted) {
        setState(() {
          _isInitialized = true; // Still show UI even if cache fails
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Initializing worker app...'),
            ],
          ),
        ),
      );
    }
    return WillPopScope(
      onWillPop: () async {
        // Map system back to change brand if a brand is selected
        final menusState = _menusKey.currentState;
        if (menusState != null && menusState.hasSelectedBrand) {
          menusState.clearBrandSelection();
          return false;
        }
        return false; // block leaving worker shell
      },
      child: Scaffold(
        appBar: AppBar(
          leading: _menusKey.currentState?.hasSelectedBrand ?? false
              ? IconButton(
                  onPressed: () {
                    _menusKey.currentState?.clearBrandSelection();
                  },
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Back to brand selection',
                )
              : null,
          automaticallyImplyLeading: false,
          title: const Text('Worker'),
          actions: _menusKey.currentState?.hasSelectedBrand ?? false
              ? null
              : [
                  IconButton(
                    tooltip: 'Logout',
                    icon: const Icon(Icons.logout),
                    onPressed: () async {
                      try {
                        await _supabase.auth.signOut();
                        if (mounted) {
                          Navigator.of(context).pushNamedAndRemoveUntil(
                              LoginScreen.routeName, (route) => false);
                        }
                      } catch (_) {}
                    },
                  ),
                ],
        ),
        body: WorkerMenusScreen(
          key: _menusKey,
          onBrandSelectionChanged: () {
            if (mounted) {
              setState(() {
                // Rebuild AppBar to show/hide logout button and back button
              });
            }
          },
        ),
      ),
    );
  }
}

