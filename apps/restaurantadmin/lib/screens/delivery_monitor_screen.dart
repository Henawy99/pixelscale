import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Clipboard
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:flutter_map/flutter_map.dart' as fmap;
import 'package:latlong2/latlong.dart' as latlong;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui' as ui;
import 'package:restaurantadmin/models/driver.dart' as app_driver_model;
import 'package:restaurantadmin/models/order.dart' as app_order;

/// Check if running on desktop platform
bool get isDesktopPlatform {
  if (kIsWeb) return false;
  return Platform.isMacOS || Platform.isWindows || Platform.isLinux;
}

/// Employee colors for driver markers
const List<Color> driverColors = [
  Color(0xFFE53935), // Red
  Color(0xFF8E24AA), // Purple
  Color(0xFF3949AB), // Indigo
  Color(0xFF1E88E5), // Blue
  Color(0xFF00ACC1), // Cyan
  Color(0xFF43A047), // Green
  Color(0xFFFB8C00), // Orange
  Color(0xFF6D4C41), // Brown
];

class DeliveryMonitorScreen extends StatefulWidget {
  final SupabaseClient supabaseClient;

  const DeliveryMonitorScreen({super.key, required this.supabaseClient});

  @override
  State<DeliveryMonitorScreen> createState() => _DeliveryMonitorScreenState();
}

class _DeliveryMonitorScreenState extends State<DeliveryMonitorScreen> {
  List<app_driver_model.Driver> _onlineDrivers = [];
  List<app_driver_model.Driver> _allDrivers = [];
  List<app_order.Order> _deliveryOrders = [];
  bool _isLoading = true;
  bool _showDriversPanel = false;

  // Track previous driver online states for notifications
  final Map<String, bool> _previousDriverOnlineStates = {};
  bool _initialLoadComplete = false;

  // Google Maps controller (mobile only)
  gmaps.GoogleMapController? _mapController;
  Set<gmaps.Marker> _mapMarkers = {};

  // Flutter Map controller (desktop only)
  final fmap.MapController _flutterMapController = fmap.MapController();

  // Restaurant Address: Minnesheimstraße 5, 5023 Salzburg
  static const double _restaurantLat = 47.81328;
  static const double _restaurantLng = 13.06882;
  static final gmaps.LatLng _restaurantLocation = gmaps.LatLng(
    _restaurantLat,
    _restaurantLng,
  );
  static final latlong.LatLng _restaurantLocationDesktop = latlong.LatLng(
    _restaurantLat,
    _restaurantLng,
  );
  static const String _restaurantAddress = 'Minnesheimstraße 5, 5023 Salzburg';

  RealtimeChannel? _driversSubscription;
  RealtimeChannel? _ordersSubscription;
  Timer? _pollingTimer;
  Timer? _driverPollingTimer;
  int _lastOrderCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchAllDrivers();
    _fetchOnlineDrivers();
    _fetchDeliveryOrders();
    _setupRealtimeSubscription();
    _startPolling();
    _startDriverPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _driverPollingTimer?.cancel();
    _driversSubscription?.unsubscribe();
    _ordersSubscription?.unsubscribe();
    _mapController?.dispose();
    super.dispose();
  }

  /// Backup polling for driver locations every 15 seconds for near real-time updates.
  /// Realtime subscription handles instant updates; this is a safety net.
  void _startDriverPolling() {
    _driverPollingTimer = Timer.periodic(const Duration(seconds: 15), (
      _,
    ) async {
      if (!mounted) return;

      try {
        await _fetchOnlineDrivers();
        await _fetchAllDrivers();
      } catch (e) {
        print('[DeliveryMonitorScreen] Driver polling error: $e');
      }
    });
  }

  /// Backup polling for orders every 30 seconds (realtime handles instant updates)
  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (!mounted) return;

      try {
        // Quick count check to see if there are new orders
        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day);

        final countResponse = await widget.supabaseClient
            .from('orders')
            .select('id')
            .not('delivery_latitude', 'is', null)
            .not('delivery_longitude', 'is', null)
            .gte('created_at', todayStart.toIso8601String());

        final newCount = (countResponse as List).length;

        // If count changed, refresh the orders
        if (newCount != _lastOrderCount) {
          final isNewOrder = newCount > _lastOrderCount;
          _lastOrderCount = newCount;
          await _fetchDeliveryOrders();

          // Show notification for new orders
          if (isNewOrder && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.notifications_active, color: Colors.white),
                    const SizedBox(width: 12),
                    Text(
                      'New delivery order received! (${_deliveryOrders.length} active)',
                    ),
                  ],
                ),
                backgroundColor: Colors.orange[700],
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 3),
                margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
              ),
            );
          }
        }
      } catch (e) {
        // Ignore polling errors
      }
    });
  }

  void _setupRealtimeSubscription() {
    _driversSubscription = widget.supabaseClient
        .channel('public:drivers')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'drivers',
          callback: (payload) {
            if (mounted) {
              _fetchOnlineDrivers();
              _fetchAllDrivers();
            }
          },
        )
        .subscribe();

    _ordersSubscription = widget.supabaseClient
        .channel('public:orders')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          callback: (payload) {
            if (mounted) _fetchDeliveryOrders();
          },
        )
        .subscribe();
  }

  Future<void> _fetchAllDrivers() async {
    if (!mounted) return;

    try {
      final response = await widget.supabaseClient
          .from('drivers')
          .select(
            'id, user_id, name, is_online, current_latitude, current_longitude, last_seen_at, created_at',
          )
          .order('name', ascending: true);

      if (!mounted) return;

      final List<app_driver_model.Driver> loadedDrivers = (response as List)
          .map(
            (data) =>
                app_driver_model.Driver.fromJson(data as Map<String, dynamic>),
          )
          .toList();

      if (mounted) {
        // Detect online/offline status changes and notify
        _detectAndNotifyStatusChanges(loadedDrivers);
        
        setState(() {
          _allDrivers = loadedDrivers;
        });
      }
    } catch (e) {
      print('[DeliveryMonitorScreen] Error fetching all drivers: $e');
    }
  }

  /// Detect driver online/offline status changes and show notifications.
  void _detectAndNotifyStatusChanges(List<app_driver_model.Driver> newDrivers) {
    if (!_initialLoadComplete) {
      // On first load, just record the states — don't fire notifications
      for (var driver in newDrivers) {
        _previousDriverOnlineStates[driver.id] = driver.isOnline;
      }
      _initialLoadComplete = true;
      return;
    }

    for (var driver in newDrivers) {
      final previousOnline = _previousDriverOnlineStates[driver.id];
      
      if (previousOnline != null && previousOnline != driver.isOnline) {
        // Status changed!
        _showDriverStatusNotification(driver.name, driver.isOnline);
      }
      
      _previousDriverOnlineStates[driver.id] = driver.isOnline;
    }
  }

  /// Show a prominent in-app notification when a driver goes online/offline.
  void _showDriverStatusNotification(String driverName, bool isNowOnline) {
    if (!mounted) return;

    // Clear any existing snackbars to avoid stacking
    ScaffoldMessenger.of(context).clearSnackBars();

    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isNowOnline ? Icons.login : Icons.logout,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isNowOnline
                        ? '$driverName is now ONLINE'
                        : '$driverName went OFFLINE',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'At $timeStr',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: isNowOnline ? Colors.green[700] : Colors.red[700],
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _addDriver(String name, String email, String password) async {
    if (!mounted) return;

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 16),
                  Text('Creating driver account...'),
                ],
              ),
            ),
          ),
        ),
      );

      // 1. Create auth user using Supabase Auth Admin API (via Edge Function)
      // Since we can't use admin.createUser from client, we'll use signUp
      // Note: This will send a confirmation email. For production, you may want
      // to use an Edge Function with service role key.

      final authResponse = await widget.supabaseClient.auth.signUp(
        email: email,
        password: password,
        data: {'name': name, 'role': 'driver'},
      );

      if (authResponse.user == null) {
        throw Exception('Failed to create user account');
      }

      final userId = authResponse.user!.id;

      // 2. Create worker profile
      await widget.supabaseClient.from('worker_profiles').upsert({
        'id': userId,
        'email': email,
        'role': 'driver',
        'display_name': name,
      });

      // 3. Create driver record
      await widget.supabaseClient.from('drivers').insert({
        'user_id': userId,
        'name': name,
        'is_online': false,
      });

      if (mounted) {
        Navigator.pop(context); // Close loading dialog

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Driver "$name" created successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        _fetchAllDrivers();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog

        String errorMessage = e.toString();
        if (errorMessage.contains('User already registered')) {
          errorMessage = 'A user with this email already exists';
        }

        _showCopyableError('Error creating driver: $errorMessage');
      }
      print('[DeliveryMonitorScreen] Error adding driver: $e');
    }
  }

  Future<void> _deleteDriver(app_driver_model.Driver driver) async {
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Driver'),
        content: Text(
          'Are you sure you want to delete driver "${driver.name}"?\n\nThis will remove the driver record but keep their user account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      print(
        '[DeliveryMonitorScreen] Attempting to delete driver: ${driver.id} (${driver.name})',
      );

      // First verify the driver exists
      final existsCheck = await widget.supabaseClient
          .from('drivers')
          .select('id')
          .eq('id', driver.id)
          .maybeSingle();

      if (existsCheck == null) {
        print(
          '[DeliveryMonitorScreen] Driver not found in database: ${driver.id}',
        );
        if (mounted) {
          _showCopyableError(
            'Driver not found in database. It may have already been deleted.',
          );
          await _fetchAllDrivers();
        }
        return;
      }

      // Delete driver record using select to get affected rows
      final deleteResponse = await widget.supabaseClient
          .from('drivers')
          .delete()
          .eq('id', driver.id)
          .select();

      print('[DeliveryMonitorScreen] Delete response: $deleteResponse');

      // Check if deletion was successful
      if (deleteResponse.isEmpty) {
        // Deletion might have failed due to RLS policies
        // Try to verify if driver still exists
        final stillExists = await widget.supabaseClient
            .from('drivers')
            .select('id')
            .eq('id', driver.id)
            .maybeSingle();

        if (stillExists != null) {
          throw Exception(
            'Failed to delete driver. Check database permissions (RLS policies).',
          );
        }
      }

      // Optionally update worker profile role
      if (driver.userId != null) {
        try {
          await widget.supabaseClient
              .from('worker_profiles')
              .update({'role': 'none'})
              .eq('id', driver.userId!);
        } catch (e) {
          print('[DeliveryMonitorScreen] Worker profile update skipped: $e');
          // Worker profile may not exist - not critical
        }
      }

      if (mounted) {
        // Immediately remove from local list for instant UI feedback
        setState(() {
          _allDrivers.removeWhere((d) => d.id == driver.id);
          _onlineDrivers.removeWhere((d) => d.id == driver.id);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Driver "${driver.name}" deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Also refresh from database to ensure consistency
        await _fetchAllDrivers();
        await _fetchOnlineDrivers();
      }
    } catch (e) {
      print('[DeliveryMonitorScreen] Error deleting driver: $e');
      if (mounted) {
        _showCopyableError('Error deleting driver: $e');
        // Refresh to restore the list if delete failed
        await _fetchAllDrivers();
      }
    }
  }

  void _showAddDriverDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    bool obscurePassword = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.person_add, color: Colors.blue[600]),
              const SizedBox(width: 8),
              const Text('Add New Driver'),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Create a new driver account. The driver will use these credentials to log in to the Driver App.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 20),

                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Driver Name',
                    hintText: 'Enter driver\'s full name',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: emailController,
                  decoration: InputDecoration(
                    labelText: 'Email (Username)',
                    hintText: 'driver@example.com',
                    prefixIcon: const Icon(Icons.email),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: 'Minimum 6 characters',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () => setDialogState(
                        () => obscurePassword = !obscurePassword,
                      ),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue[700],
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'The driver will use this email and password to log in.',
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final name = nameController.text.trim();
                final email = emailController.text.trim();
                final password = passwordController.text;

                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a name'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                if (email.isEmpty || !email.contains('@')) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid email'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                if (password.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Password must be at least 6 characters'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                Navigator.pop(ctx);
                _addDriver(name, email, password);
              },
              icon: const Icon(Icons.add),
              label: const Text('Create Driver'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriversPanel() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: _showDriversPanel ? 320 : 0,
      child: _showDriversPanel
          ? Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(-2, 0),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      border: Border(
                        bottom: BorderSide(color: Colors.grey[200]!),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.people, color: Colors.blue[600]),
                        const SizedBox(width: 8),
                        const Text(
                          'Manage Drivers',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () =>
                              setState(() => _showDriversPanel = false),
                          tooltip: 'Close',
                        ),
                      ],
                    ),
                  ),

                  // Add Driver Button
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _showAddDriverDialog,
                      icon: const Icon(Icons.person_add, size: 20),
                      label: const Text('Add New Driver'),
                    ),
                  ),

                  // Drivers List
                  Expanded(
                    child: _allDrivers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.no_accounts,
                                  size: 48,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'No drivers yet',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: _allDrivers.length,
                            itemBuilder: (context, index) {
                              final driver = _allDrivers[index];
                              final Color driverColor = driverColors[driver.colorIndex % driverColors.length];
                              final bool isStale = _isLocationStale(driver.lastSeenAt);
                              final bool isActive = driver.isOnline && !isStale;
                              
                              // Determine status color and text
                              Color statusColor;
                              String statusText;
                              if (!driver.isOnline) {
                                statusColor = Colors.grey;
                                statusText = 'Offline';
                              } else if (isStale) {
                                statusColor = Colors.orange;
                                statusText = 'Online • No signal';
                              } else {
                                statusColor = Colors.green;
                                statusText = 'Active';
                              }
                              
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                elevation: isActive ? 2 : 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: BorderSide(
                                    color: isActive ? driverColor.withOpacity(0.3) : Colors.grey[200]!,
                                    width: isActive ? 2 : 1,
                                  ),
                                ),
                                child: InkWell(
                                  onTap: () => _showDriverInfoDialog(driver),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        // Avatar with status ring
                                        Stack(
                                          children: [
                                            CircleAvatar(
                                              radius: 22,
                                              backgroundColor: isStale && driver.isOnline
                                                  ? Colors.grey
                                                  : driverColor,
                                              child: Text(
                                                driver.name.isNotEmpty
                                                    ? driver.name[0].toUpperCase()
                                                    : 'D',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                            // Status indicator dot
                                            Positioned(
                                              right: 0,
                                              bottom: 0,
                                              child: Container(
                                                width: 14,
                                                height: 14,
                                                decoration: BoxDecoration(
                                                  color: statusColor,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(color: Colors.white, width: 2),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(width: 12),
                                        // Name and status
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                driver.name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 15,
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: statusColor.withOpacity(0.1),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      statusText,
                                                      style: TextStyle(
                                                        color: statusColor,
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                  if (driver.isOnline && driver.lastSeenAt != null) ...[
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      _formatLastSeen(driver.lastSeenAt),
                                                      style: TextStyle(
                                                        color: Colors.grey[500],
                                                        fontSize: 10,
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Actions
                                        PopupMenuButton<String>(
                                          icon: Icon(Icons.more_vert, color: Colors.grey[400]),
                                          onSelected: (value) {
                                            if (value == 'delete') {
                                              _deleteDriver(driver);
                                            } else if (value == 'view') {
                                              _showDriverInfoDialog(driver);
                                            }
                                          },
                                          itemBuilder: (context) => [
                                            const PopupMenuItem(
                                              value: 'view',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.visibility, color: Colors.blue, size: 20),
                                                  SizedBox(width: 8),
                                                  Text('View Details'),
                                                ],
                                              ),
                                            ),
                                            const PopupMenuItem(
                                              value: 'delete',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.delete, color: Colors.red, size: 20),
                                                  SizedBox(width: 8),
                                                  Text('Delete Driver', style: TextStyle(color: Colors.red)),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),

                  // Summary
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      border: Border(top: BorderSide(color: Colors.grey[200]!)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildSummaryItem(
                          '${_allDrivers.length}',
                          'Total Drivers',
                          Colors.blue[700]!,
                        ),
                        Container(width: 1, height: 30, color: Colors.grey[300]),
                        _buildSummaryItem(
                          '${_onlineDrivers.where((d) => !_isLocationStale(d.lastSeenAt)).length}',
                          'Active',
                          Colors.green[700]!,
                        ),
                        Container(width: 1, height: 30, color: Colors.grey[300]),
                        _buildSummaryItem(
                          '${_onlineDrivers.where((d) => _isLocationStale(d.lastSeenAt)).length}',
                          'No Signal',
                          Colors.orange[700]!,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  Future<void> _fetchOnlineDrivers() async {
    if (!mounted) return;

    // Don't set loading on refresh polls, only on initial load
    if (_onlineDrivers.isEmpty) {
      setState(() => _isLoading = true);
    }

    try {
      final response = await widget.supabaseClient
          .from('drivers')
          .select(
            'id, user_id, name, is_online, current_latitude, current_longitude, last_seen_at',
          )
          .eq('is_online', true);

      if (!mounted) return;

      final List<app_driver_model.Driver> loadedDrivers = (response as List)
          .map(
            (data) =>
                app_driver_model.Driver.fromJson(data as Map<String, dynamic>),
          )
          .toList();

      if (mounted) {
        setState(() {
          _onlineDrivers = loadedDrivers;
          _isLoading = false;
        });
        await _updateMapMarkers();
      }
    } catch (e) {
      print('[DeliveryMonitorScreen] Error fetching drivers: $e');
      if (mounted) {
        _showCopyableError('Error fetching driver data: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchDeliveryOrders() async {
    if (!mounted) return;

    try {
      // Get today's date range (00:00:00 to 23:59:59)
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = todayStart.add(const Duration(days: 1));

      // Fetch ALL delivery orders with coordinates (not just specific statuses)
      // This ensures new orders show up immediately
      final response = await widget.supabaseClient
          .from('orders')
          .select(
            'id, order_number, daily_order_number, customer_name, customer_street, customer_postcode, customer_city, delivery_latitude, delivery_longitude, status, total_price, created_at, fulfillment_type, payment_method',
          )
          .not('delivery_latitude', 'is', null)
          .not('delivery_longitude', 'is', null)
          .gte('created_at', todayStart.toIso8601String())
          .lt('created_at', todayEnd.toIso8601String())
          .order('created_at', ascending: false)
          .limit(100);

      if (!mounted) return;

      final List<app_order.Order> loadedOrders = (response as List)
          .map((data) => app_order.Order.fromJson(data as Map<String, dynamic>))
          .toList();

      // Filter out delivered/cancelled orders for map display
      final activeOrders = loadedOrders.where((order) {
        final status = order.status.toLowerCase();
        return !status.contains('delivered') &&
            !status.contains('cancelled') &&
            !status.contains('completed');
      }).toList();

      if (mounted) {
        setState(() {
          _deliveryOrders = activeOrders;
        });
        await _updateMapMarkers();
      }
    } catch (e) {
      print('[DeliveryMonitorScreen] Error fetching delivery orders: $e');
      if (mounted) {
        _showCopyableError('Error fetching order data: $e');
      }
    }
  }

  Future<gmaps.BitmapDescriptor> _createCustomDriverMarker(
    String driverName,
    int colorIndex,
  ) async {
    final String initial = driverName.isNotEmpty
        ? driverName[0].toUpperCase()
        : 'D';
    final Color driverColor = driverColors[colorIndex % driverColors.length];

    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double size = 100;
    const double centerX = size / 2;
    const double centerY = size / 2;

    // Car dimensions - top-down view of a car
    const double carLength = 70;
    const double carWidth = 36;

    // Shadow
    final Paint shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(centerX + 2, centerY + 3),
          width: carWidth,
          height: carLength,
        ),
        const Radius.circular(12),
      ),
      shadowPaint,
    );

    // Main car body (employee color)
    final Paint bodyPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = driverColor;

    // Car body - elongated rounded rectangle (top-down view)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(centerX, centerY),
          width: carWidth,
          height: carLength,
        ),
        const Radius.circular(10),
      ),
      bodyPaint,
    );

    // Front of car (hood) - slightly rounded
    final Paint hoodPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Color.lerp(driverColor, Colors.black, 0.15)!;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          centerX - carWidth / 2 + 3,
          centerY - carLength / 2 + 2,
          carWidth - 6,
          18,
        ),
        const Radius.circular(8),
      ),
      hoodPaint,
    );

    // Windshield (dark)
    final Paint windshieldPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF2D3748);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          centerX - carWidth / 2 + 5,
          centerY - carLength / 2 + 18,
          carWidth - 10,
          12,
        ),
        const Radius.circular(3),
      ),
      windshieldPaint,
    );

    // Roof / cabin area (slightly darker)
    final Paint roofPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Color.lerp(driverColor, Colors.black, 0.1)!;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(centerX, centerY + 2),
          width: carWidth - 8,
          height: 20,
        ),
        const Radius.circular(4),
      ),
      roofPaint,
    );

    // Rear windshield
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          centerX - carWidth / 2 + 5,
          centerY + carLength / 2 - 26,
          carWidth - 10,
          10,
        ),
        const Radius.circular(3),
      ),
      windshieldPaint,
    );

    // Trunk
    final Paint trunkPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Color.lerp(driverColor, Colors.black, 0.12)!;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          centerX - carWidth / 2 + 3,
          centerY + carLength / 2 - 16,
          carWidth - 6,
          14,
        ),
        const Radius.circular(6),
      ),
      trunkPaint,
    );

    // Headlights (front)
    final Paint lightPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFFFF9C4); // Light yellow
    canvas.drawCircle(
      Offset(centerX - carWidth / 2 + 8, centerY - carLength / 2 + 8),
      4,
      lightPaint,
    );
    canvas.drawCircle(
      Offset(centerX + carWidth / 2 - 8, centerY - carLength / 2 + 8),
      4,
      lightPaint,
    );

    // Taillights (rear) - red
    final Paint tailLightPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFEF5350);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          centerX - carWidth / 2 + 4,
          centerY + carLength / 2 - 6,
          6,
          4,
        ),
        const Radius.circular(2),
      ),
      tailLightPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          centerX + carWidth / 2 - 10,
          centerY + carLength / 2 - 6,
          6,
          4,
        ),
        const Radius.circular(2),
      ),
      tailLightPaint,
    );

    // Side mirrors
    final Paint mirrorPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = driverColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(centerX - carWidth / 2 - 5, centerY - 8, 6, 8),
        const Radius.circular(2),
      ),
      mirrorPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(centerX + carWidth / 2 - 1, centerY - 8, 6, 8),
        const Radius.circular(2),
      ),
      mirrorPaint,
    );

    // White border around entire car
    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(centerX, centerY),
          width: carWidth,
          height: carLength,
        ),
        const Radius.circular(10),
      ),
      borderPaint,
    );

    // Driver initial badge (circle on roof)
    final Paint badgePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white;
    canvas.drawCircle(Offset(centerX, centerY + 2), 12, badgePaint);

    // Initial letter
    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: initial,
        style: TextStyle(
          color: driverColor,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        centerX - textPainter.width / 2,
        centerY + 2 - textPainter.height / 2,
      ),
    );

    final ui.Image image = await pictureRecorder.endRecording().toImage(
      size.toInt(),
      size.toInt(),
    );
    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    return gmaps.BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }

  Future<gmaps.BitmapDescriptor> _createCustomOrderMarker(
    int dailyOrderNumber,
  ) async {
    final String orderText = dailyOrderNumber.toString();
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double size = 52;
    const double centerX = size / 2;
    const double bagTop = 14.0;
    const double bagHeight = size - bagTop - 4;
    const double bagWidth = size - 8;

    // Draw bag body (coral/red color like the icon)
    final Paint bagPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFE57373); // Coral red

    // Bag body - rounded rectangle
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(4, bagTop, bagWidth, bagHeight),
        const Radius.circular(8),
      ),
      bagPaint,
    );

    // Draw bag handle (dark gray arc on top)
    final Paint handlePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color =
          const Color(0xFF4A4A4A) // Dark gray
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    // Draw handle as an arc
    final Path handlePath = Path();
    handlePath.moveTo(centerX - 10, bagTop + 2);
    handlePath.quadraticBezierTo(centerX - 10, 4, centerX, 4);
    handlePath.quadraticBezierTo(centerX + 10, 4, centerX + 10, bagTop + 2);
    canvas.drawPath(handlePath, handlePaint);

    // Draw the daily order number in the center of the bag
    final double fontSize = orderText.length > 2
        ? 14.0
        : (orderText.length > 1 ? 18.0 : 22.0);
    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: orderText,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    );
    textPainter.layout();

    // Center the text in the bag body
    final double bagCenterY = bagTop + bagHeight / 2;
    textPainter.paint(
      canvas,
      Offset(
        centerX - textPainter.width / 2,
        bagCenterY - textPainter.height / 2,
      ),
    );

    final ui.Image image = await pictureRecorder.endRecording().toImage(
      size.toInt(),
      size.toInt(),
    );
    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    return gmaps.BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }

  Future<gmaps.BitmapDescriptor> _createRestaurantMarker() async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double size = 70;
    const double circleRadius = 25;

    // Draw drop shadow
    final Paint shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(
      const Offset(size / 2 + 1, size / 2 + 2),
      circleRadius,
      shadowPaint,
    );

    // Draw white background circle
    final Paint whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      circleRadius,
      whitePaint,
    );

    // Draw green inner circle
    final Paint greenPaint = Paint()
      ..color = const Color(0xFF4CAF50)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      circleRadius - 3,
      greenPaint,
    );

    // Draw house icon - BIGGER
    final double centerX = size / 2;
    final double centerY = size / 2;

    // House body (white rectangle)
    final Paint housePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(centerX, centerY + 4),
          width: 22,
          height: 16,
        ),
        const Radius.circular(2),
      ),
      housePaint,
    );

    // Roof (white triangle)
    final Path roofPath = Path();
    roofPath.moveTo(centerX - 14, centerY - 4);
    roofPath.lineTo(centerX + 14, centerY - 4);
    roofPath.lineTo(centerX, centerY - 14);
    roofPath.close();
    canvas.drawPath(roofPath, housePaint);

    // Door (green rectangle)
    final Paint doorPaint = Paint()
      ..color = const Color(0xFF4CAF50)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(centerX, centerY + 6),
          width: 6,
          height: 10,
        ),
        const Radius.circular(1),
      ),
      doorPaint,
    );

    final ui.Image image = await pictureRecorder.endRecording().toImage(
      size.toInt(),
      size.toInt(),
    );
    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    return gmaps.BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }

  Future<void> _updateMapMarkers() async {
    if (!mounted) return;

    // Skip marker generation on desktop (uses _buildDesktopMarkers instead)
    if (isDesktopPlatform) {
      if (mounted) setState(() {});
      return;
    }

    final Set<gmaps.Marker> newMarkers = {};

    // Add restaurant marker (green store icon)
    final gmaps.BitmapDescriptor restaurantIcon =
        await _createRestaurantMarker();
    newMarkers.add(
      gmaps.Marker(
        markerId: const gmaps.MarkerId('restaurant'),
        position: _restaurantLocation,
        icon: restaurantIcon,
        infoWindow: gmaps.InfoWindow(
          title: '🏪 Restaurant',
          snippet: _restaurantAddress,
        ),
        zIndex: 1, // Keep restaurant on top
      ),
    );

    // Add driver markers (with employee color)
    for (var driver in _onlineDrivers) {
      if (driver.currentLocation != null) {
        final gmaps.BitmapDescriptor driverIcon =
            await _createCustomDriverMarker(driver.name, driver.colorIndex);

        newMarkers.add(
          gmaps.Marker(
            markerId: gmaps.MarkerId('driver_${driver.id}'),
            position: driver.currentLocation!,
            icon: driverIcon,
            onTap: () => _showDriverInfoDialog(driver),
          ),
        );
      }
    }

    // Add order markers (orange with daily order number)
    for (var order in _deliveryOrders) {
      if (order.deliveryLatitude != null && order.deliveryLongitude != null) {
        final int dailyNumber = order.dailyOrderNumber ?? 0;
        final gmaps.BitmapDescriptor orderIcon = await _createCustomOrderMarker(
          dailyNumber > 0 ? dailyNumber : (_deliveryOrders.indexOf(order) + 1),
        );

        // Build comprehensive info for the marker
        final String customerName = order.customerName ?? 'Unknown Customer';
        final String street = order.customerStreet ?? '';
        final String postcode = order.customerPostcode ?? '';
        final String city = order.customerCity ?? '';

        // Build full address
        String fullAddress = street;
        if (postcode.isNotEmpty || city.isNotEmpty) {
          fullAddress += fullAddress.isNotEmpty ? ', ' : '';
          fullAddress += '$postcode $city'.trim();
        }
        if (fullAddress.isEmpty) {
          fullAddress = 'Address not available';
        }

        // Build status and payment info
        final String statusText = order.status
            .replaceAll('_', ' ')
            .toUpperCase();
        final String paymentText = order.paymentMethod.toUpperCase();

        newMarkers.add(
          gmaps.Marker(
            markerId: gmaps.MarkerId('order_${order.id}'),
            position: gmaps.LatLng(
              order.deliveryLatitude!,
              order.deliveryLongitude!,
            ),
            icon: orderIcon,
            infoWindow: gmaps.InfoWindow(
              title:
                  '🛵 $customerName • €${order.totalPrice.toStringAsFixed(2)}',
              snippet: '$fullAddress\n[$statusText] - $paymentText',
            ),
            onTap: () => _showOrderDetailsBottomSheet(order),
          ),
        );
      }
    }

    if (mounted) setState(() => _mapMarkers = newMarkers);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Delivery Monitor',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Coordinate Updates Button
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: IconButton(
              icon: const Icon(
                Icons.gps_fixed,
                color: Colors.white,
                shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
              ),
              onPressed: _showAllDriversCoordinateLogsDialog,
              tooltip: 'Coordinate Updates',
            ),
          ),
          // Manage Drivers Button
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Icon(
                Icons.people,
                color: _showDriversPanel ? Colors.amber : Colors.white,
                shadows: const [Shadow(color: Colors.black45, blurRadius: 4)],
              ),
              onPressed: () =>
                  setState(() => _showDriversPanel = !_showDriversPanel),
              tooltip: 'Manage Drivers',
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue[600]!.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.drive_eta, color: Colors.white, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      '${_onlineDrivers.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange[600]!.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.shopping_bag,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${_deliveryOrders.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.refresh,
              shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
            ),
            onPressed: () {
              _fetchAllDrivers();
              _fetchOnlineDrivers();
              _fetchDeliveryOrders();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Refreshed: ${_onlineDrivers.length} drivers online, ${_deliveryOrders.length} orders',
                  ),
                  backgroundColor: Colors.blue,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                // Map - Full screen behind AppBar
                Expanded(
                  child: isDesktopPlatform
                      ? _buildDesktopMap()
                      : _buildMobileMap(),
                ),

                // Drivers Panel (slides in from right)
                _buildDriversPanel(),
              ],
            ),
    );
  }

  /// Build Google Maps for mobile (Android/iOS)
  Widget _buildMobileMap() {
    return gmaps.GoogleMap(
      onMapCreated: (gmaps.GoogleMapController controller) =>
          _mapController = controller,
      initialCameraPosition: gmaps.CameraPosition(
        target: _restaurantLocation,
        zoom: 13,
      ),
      markers: _mapMarkers,
      zoomControlsEnabled: true,
      mapToolbarEnabled: true,
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
    );
  }

  /// Build Flutter Map for desktop (macOS/Windows/Linux) using OpenStreetMap
  Widget _buildDesktopMap() {
    return fmap.FlutterMap(
      mapController: _flutterMapController,
      options: fmap.MapOptions(
        initialCenter: _restaurantLocationDesktop,
        initialZoom: 13,
      ),
      children: [
        // OpenStreetMap tile layer
        fmap.TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.restaurantadmin.app',
        ),
        // Markers layer
        fmap.MarkerLayer(markers: _buildDesktopMarkers()),
      ],
    );
  }

  /// Build markers for desktop flutter_map
  List<fmap.Marker> _buildDesktopMarkers() {
    final List<fmap.Marker> markers = [];

    // Restaurant marker
    markers.add(
      fmap.Marker(
        point: _restaurantLocationDesktop,
        width: 50,
        height: 50,
        child: GestureDetector(
          onTap: () => _showInfoDialog('🏪 Restaurant', _restaurantAddress),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.store, color: Colors.white, size: 28),
          ),
        ),
      ),
    );

    // Driver markers (with employee color - car shape)
    for (var driver in _onlineDrivers) {
      if (driver.currentLocation != null) {
        final Color driverColor =
            driverColors[driver.colorIndex % driverColors.length];
        markers.add(
          fmap.Marker(
            point: latlong.LatLng(
              driver.currentLocation!.latitude,
              driver.currentLocation!.longitude,
            ),
            width: 50,
            height: 80,
            child: GestureDetector(
              onTap: () => _showDriverInfoDialog(driver),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Car body (top-down view)
                  Container(
                    width: 36,
                    height: 60,
                    decoration: BoxDecoration(
                      color: driverColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Windshield
                        Positioned(
                          top: 10,
                          left: 4,
                          right: 4,
                          child: Container(
                            height: 10,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2D3748),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                        // Rear windshield
                        Positioned(
                          bottom: 12,
                          left: 4,
                          right: 4,
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2D3748),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                        // Initial badge
                        Positioned.fill(
                          child: Center(
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  driver.name.isNotEmpty
                                      ? driver.name[0].toUpperCase()
                                      : 'D',
                                  style: TextStyle(
                                    color: driverColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Headlights
                        Positioned(
                          top: 3,
                          left: 5,
                          child: Container(
                            width: 6,
                            height: 4,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF9C4),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 3,
                          right: 5,
                          child: Container(
                            width: 6,
                            height: 4,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF9C4),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        // Taillights
                        Positioned(
                          bottom: 3,
                          left: 5,
                          child: Container(
                            width: 5,
                            height: 3,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF5350),
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 3,
                          right: 5,
                          child: Container(
                            width: 5,
                            height: 3,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF5350),
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    // Order markers
    for (var order in _deliveryOrders) {
      if (order.deliveryLatitude != null && order.deliveryLongitude != null) {
        final int dailyNumber =
            order.dailyOrderNumber ?? (_deliveryOrders.indexOf(order) + 1);
        markers.add(
          fmap.Marker(
            point: latlong.LatLng(
              order.deliveryLatitude!,
              order.deliveryLongitude!,
            ),
            width: 45,
            height: 55,
            child: GestureDetector(
              onTap: () => _showOrderDetailsBottomSheet(order),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE57373),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        '$dailyNumber',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 2,
                    height: 10,
                    color: const Color(0xFFE57373),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    return markers;
  }

  /// Check if driver location is stale (more than 2 minutes old).
  /// Uses a 2-minute window to account for network delays and timer intervals.
  bool _isLocationStale(DateTime? lastSeenAt) {
    if (lastSeenAt == null) return true;
    
    // Ensure consistent UTC comparison
    final now = DateTime.now().toUtc();
    final lastSeen = lastSeenAt.isUtc ? lastSeenAt : lastSeenAt.toUtc();
    final difference = now.difference(lastSeen);
    
    return difference.inSeconds > 120; // Stale if > 2 minutes
  }
  
  Widget _buildSummaryItem(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  /// Format last seen time for display
  String _formatLastSeen(DateTime? lastSeenAt) {
    if (lastSeenAt == null) return 'Never updated';
    
    // Ensure consistent UTC comparison
    final now = DateTime.now().toUtc();
    final lastSeen = lastSeenAt.isUtc ? lastSeenAt : lastSeenAt.toUtc();
    final difference = now.difference(lastSeen);
    
    // Handle negative values (clock skew)
    final seconds = difference.inSeconds.abs();
    
    if (seconds < 15) {
      return 'Just now';
    } else if (seconds < 60) {
      return '${seconds}s ago';
    } else if (difference.inMinutes.abs() < 60) {
      return '${difference.inMinutes.abs()}m ago';
    } else if (difference.inHours.abs() < 24) {
      return '${difference.inHours.abs()}h ago';
    } else {
      return '${difference.inDays.abs()}d ago';
    }
  }

  /// Show clean driver info dialog
  void _showDriverInfoDialog(app_driver_model.Driver driver) {
    if (!mounted) return;
    
    final Color driverColor = driverColors[driver.colorIndex % driverColors.length];
    final bool isStale = _isLocationStale(driver.lastSeenAt);
    final String lastSeenText = _formatLastSeen(driver.lastSeenAt);
    
    // Format last seen timestamp
    String lastUpdateTime = 'Never';
    if (driver.lastSeenAt != null) {
      final local = driver.lastSeenAt!.toLocal();
      lastUpdateTime = '${local.hour.toString().padLeft(2, '0')}:'
                       '${local.minute.toString().padLeft(2, '0')}:'
                       '${local.second.toString().padLeft(2, '0')}';
    }
    
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Driver avatar with color
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: isStale ? Colors.grey : driverColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (isStale ? Colors.grey : driverColor).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.directions_car,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),
              
              // Driver name
              Text(
                driver.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              
              // Online/Offline Status indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: driver.isOnline ? Colors.green[50] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: driver.isOnline ? Colors.green[300]! : Colors.grey[300]!,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: driver.isOnline ? Colors.green : Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      driver.isOnline ? 'Online' : 'Offline',
                      style: TextStyle(
                        color: driver.isOnline ? Colors.green[700] : Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Info section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  children: [
                    // Last Updated
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 18,
                          color: isStale ? Colors.orange[700] : Colors.grey[600],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Last Updated:',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isStale ? Colors.orange[100] : Colors.green[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            lastSeenText,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isStale ? Colors.orange[800] : Colors.green[800],
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 10),
                    
                    // Update Time
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 18, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text(
                          'Update Time:',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                        const Spacer(),
                        Text(
                          lastUpdateTime,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'monospace',
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                    
                    if (driver.currentLocation != null) ...[
                      const SizedBox(height: 10),
                      const Divider(height: 1),
                      const SizedBox(height: 10),
                      
                      // Current Coordinates
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 18, color: Colors.blue[600]),
                          const SizedBox(width: 8),
                          Text(
                            'Coordinates:',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${driver.currentLocation!.latitude.toStringAsFixed(6)}, '
                          '${driver.currentLocation!.longitude.toStringAsFixed(6)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[800],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              if (isStale) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Location may be outdated',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 20),
              
              // View Coordinates button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: driverColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showCoordinateHistoryDialog(driver);
                  },
                  icon: const Icon(Icons.history, size: 18),
                  label: const Text('View Live Updates'),
                ),
              ),
              
              const SizedBox(height: 10),
              
              // Close button
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.grey[100],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show real-time coordinate history for a driver
  void _showCoordinateHistoryDialog(app_driver_model.Driver driver) {
    if (!mounted) return;
    
    final Color driverColor = driverColors[driver.colorIndex % driverColors.length];
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _CoordinateHistoryDialog(
        driver: driver,
        driverColor: driverColor,
        supabaseClient: widget.supabaseClient,
      ),
    );
  }

  /// Show all drivers' coordinate logs dialog
  void _showAllDriversCoordinateLogsDialog() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _AllDriversCoordinateLogsDialog(
        allDrivers: _allDrivers,
        onlineDrivers: _onlineDrivers,
        supabaseClient: widget.supabaseClient,
      ),
    );
  }

  /// Show info dialog for restaurant marker
  void _showInfoDialog(String title, String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.store, color: Colors.white, size: 26),
              ),
              const SizedBox(height: 16),
              Text(
                title.replaceAll('🏪 ', '').replaceAll('🚗 ', ''),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: TextStyle(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.grey[100],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOrderDetailsBottomSheet(app_order.Order order) {
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.orange[600]!, Colors.orange[400]!],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.delivery_dining,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order #${order.dailyOrderNumber ?? order.id?.substring(0, 8) ?? "N/A"}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(order.status),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            order.status.replaceAll('_', ' ').toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '€${order.totalPrice.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                ],
              ),

              const Divider(height: 32),

              // Customer Info
              Row(
                children: [
                  Icon(Icons.person, color: Colors.blue[600], size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Customer',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        Text(
                          order.customerName ?? 'Unknown',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Address
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.location_on, color: Colors.red[600], size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Delivery Address',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        Text(
                          order.customerStreet ?? 'No street',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (order.customerPostcode != null ||
                            order.customerCity != null)
                          Text(
                            '${order.customerPostcode ?? ''} ${order.customerCity ?? ''}'
                                .trim(),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Payment Method
              Row(
                children: [
                  Icon(Icons.payment, color: Colors.purple[600], size: 20),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Payment Method',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        order.paymentMethod.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Close button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[200],
                    foregroundColor: Colors.grey[800],
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange[600]!;
      case 'confirmed':
        return Colors.blue[600]!;
      case 'preparing':
        return Colors.purple[600]!;
      case 'ready':
      case 'ready_to_deliver':
        return Colors.teal[600]!;
      case 'out_for_delivery':
        return Colors.indigo[600]!;
      case 'delivered':
        return Colors.green[700]!;
      default:
        return Colors.grey[600]!;
    }
  }

  void _showCopyableError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: '📋 COPY',
          textColor: Colors.white,
          onPressed: () {
            Clipboard.setData(ClipboardData(text: message));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✓ Error copied to clipboard'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Parse a timestamp string from Supabase, ensuring it's treated as UTC.
/// Supabase often returns UTC timestamps without the 'Z' suffix, causing
/// Dart's DateTime.tryParse to treat them as local time.
DateTime? _parseUtcTimestamp(String? s) {
  if (s == null || s.isEmpty) return null;
  final dt = DateTime.tryParse(s);
  if (dt == null) return null;
  return dt.isUtc
      ? dt
      : DateTime.utc(dt.year, dt.month, dt.day, dt.hour, dt.minute,
          dt.second, dt.millisecond, dt.microsecond);
}

/// Model for coordinate update entry
class _CoordinateUpdate {
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  
  _CoordinateUpdate({
    required this.timestamp,
    required this.latitude,
    required this.longitude,
  });
}

/// Dialog showing real-time coordinate updates for a driver
class _CoordinateHistoryDialog extends StatefulWidget {
  final app_driver_model.Driver driver;
  final Color driverColor;
  final SupabaseClient supabaseClient;
  
  const _CoordinateHistoryDialog({
    required this.driver,
    required this.driverColor,
    required this.supabaseClient,
  });
  
  @override
  State<_CoordinateHistoryDialog> createState() => _CoordinateHistoryDialogState();
}

class _CoordinateHistoryDialogState extends State<_CoordinateHistoryDialog> {
  final List<_CoordinateUpdate> _updates = [];
  final ScrollController _scrollController = ScrollController();
  RealtimeChannel? _subscription;
  Timer? _pollingTimer;
  bool _isListening = true;
  
  @override
  void initState() {
    super.initState();
    _addInitialUpdate();
    _setupRealtimeSubscription();
    _startPolling();
  }
  
  @override
  void dispose() {
    _subscription?.unsubscribe();
    _pollingTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }
  
  void _addInitialUpdate() {
    // Add current location as first entry
    if (widget.driver.currentLocation != null) {
      _updates.add(_CoordinateUpdate(
        timestamp: widget.driver.lastSeenAt ?? DateTime.now(),
        latitude: widget.driver.currentLocation!.latitude,
        longitude: widget.driver.currentLocation!.longitude,
      ));
    }
  }
  
  void _setupRealtimeSubscription() {
    _subscription = widget.supabaseClient
        .channel('driver_location_${widget.driver.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'drivers',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.driver.id,
          ),
          callback: (payload) {
            if (!mounted || !_isListening) return;
            
            final newData = payload.newRecord;
            final lat = newData['current_latitude'];
            final lng = newData['current_longitude'];
            final lastSeen = newData['last_seen_at'];
            
            if (lat != null && lng != null) {
              _addUpdate(
                _parseUtcTimestamp(lastSeen?.toString()) ?? DateTime.now().toUtc(),
                (lat as num).toDouble(),
                (lng as num).toDouble(),
              );
            }
          },
        )
        .subscribe();
  }
  
  void _startPolling() {
    // Poll every 5 seconds as backup
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted || !_isListening) return;
      
      try {
        final response = await widget.supabaseClient
            .from('drivers')
            .select('current_latitude, current_longitude, last_seen_at')
            .eq('id', widget.driver.id)
            .single();
        
        final lat = response['current_latitude'];
        final lng = response['current_longitude'];
        final lastSeen = response['last_seen_at'];
        
        if (lat != null && lng != null && mounted) {
          final timestamp = _parseUtcTimestamp(lastSeen?.toString()) ?? DateTime.now().toUtc();
          
          // Only add if coordinates changed
          if (_updates.isEmpty || 
              _updates.last.latitude != lat || 
              _updates.last.longitude != lng) {
            _addUpdate(timestamp, (lat as num).toDouble(), (lng as num).toDouble());
          }
        }
      } catch (e) {
        debugPrint('[CoordinateHistory] Polling error: $e');
      }
    });
  }
  
  void _addUpdate(DateTime timestamp, double lat, double lng) {
    // Check if this is a duplicate (same coordinates within 1 second)
    if (_updates.isNotEmpty) {
      final last = _updates.last;
      if (last.latitude == lat && 
          last.longitude == lng &&
          timestamp.difference(last.timestamp).inSeconds.abs() < 2) {
        return; // Skip duplicate
      }
    }
    
    setState(() {
      _updates.add(_CoordinateUpdate(
        timestamp: timestamp,
        latitude: lat,
        longitude: lng,
      ));
      
      // Keep only last 50 updates
      if (_updates.length > 50) {
        _updates.removeAt(0);
      }
    });
    
    // Auto-scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
  
  String _formatTime(DateTime time) {
    final local = time.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:'
           '${local.minute.toString().padLeft(2, '0')}:'
           '${local.second.toString().padLeft(2, '0')}';
  }
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 380,
        height: 500,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: widget.driverColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.directions_car, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.driver.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Live Coordinate Updates',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                // Live indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isListening ? Colors.green[50] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isListening ? Colors.green[300]! : Colors.grey[300]!,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _isListening ? Colors.green : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isListening ? 'LIVE' : 'PAUSED',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _isListening ? Colors.green[700] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Column headers
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 80,
                    child: Text(
                      'TIME',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'COORDINATES (LAT, LNG)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Updates list
            Expanded(
              child: _updates.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.hourglass_empty, size: 40, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Text(
                            'Waiting for location updates...',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount: _updates.length,
                      itemBuilder: (context, index) {
                        final update = _updates[index];
                        final isLatest = index == _updates.length - 1;
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isLatest ? widget.driverColor.withOpacity(0.1) : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isLatest ? widget.driverColor.withOpacity(0.3) : Colors.grey[200]!,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Time
                              SizedBox(
                                width: 70,
                                child: Text(
                                  _formatTime(update.timestamp),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isLatest ? FontWeight.bold : FontWeight.normal,
                                    fontFamily: 'monospace',
                                    color: isLatest ? widget.driverColor : Colors.grey[800],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Coordinates
                              Expanded(
                                child: Text(
                                  '${update.latitude.toStringAsFixed(6)}, ${update.longitude.toStringAsFixed(6)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                    color: isLatest ? Colors.black : Colors.grey[700],
                                  ),
                                ),
                              ),
                              // Latest badge
                              if (isLatest)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: widget.driverColor,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'NEW',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            
            const SizedBox(height: 12),
            
            // Footer with count and controls
            Row(
              children: [
                Text(
                  '${_updates.length} updates',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const Spacer(),
                // Pause/Resume button
                TextButton.icon(
                  onPressed: () {
                    setState(() => _isListening = !_isListening);
                  },
                  icon: Icon(
                    _isListening ? Icons.pause : Icons.play_arrow,
                    size: 18,
                  ),
                  label: Text(_isListening ? 'Pause' : 'Resume'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                  ),
                ),
                const SizedBox(width: 8),
                // Close button
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[200],
                    foregroundColor: Colors.grey[800],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog showing coordinate logs for ALL drivers
class _AllDriversCoordinateLogsDialog extends StatefulWidget {
  final List<app_driver_model.Driver> allDrivers;
  final List<app_driver_model.Driver> onlineDrivers;
  final SupabaseClient supabaseClient;
  
  const _AllDriversCoordinateLogsDialog({
    required this.allDrivers,
    required this.onlineDrivers,
    required this.supabaseClient,
  });
  
  @override
  State<_AllDriversCoordinateLogsDialog> createState() => _AllDriversCoordinateLogsDialogState();
}

class _AllDriversCoordinateLogsDialogState extends State<_AllDriversCoordinateLogsDialog> {
  // Map of driver ID to list of coordinate updates
  final Map<String, List<_CoordinateUpdate>> _driverUpdates = {};
  final Map<String, ScrollController> _scrollControllers = {};
  RealtimeChannel? _subscription;
  Timer? _pollingTimer;
  bool _isListening = true;
  String? _selectedDriverId;
  
  @override
  void initState() {
    super.initState();
    _initializeDrivers();
    _setupRealtimeSubscription();
    _startPolling();
  }
  
  @override
  void dispose() {
    _subscription?.unsubscribe();
    _pollingTimer?.cancel();
    for (var controller in _scrollControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
  
  void _initializeDrivers() {
    // Initialize with current positions for all drivers
    for (var driver in widget.allDrivers) {
      _driverUpdates[driver.id] = [];
      _scrollControllers[driver.id] = ScrollController();
      
      if (driver.currentLocation != null) {
        _driverUpdates[driver.id]!.add(_CoordinateUpdate(
          timestamp: driver.lastSeenAt ?? DateTime.now(),
          latitude: driver.currentLocation!.latitude,
          longitude: driver.currentLocation!.longitude,
        ));
      }
    }
    
    // Select first online driver by default, or first driver
    if (widget.onlineDrivers.isNotEmpty) {
      _selectedDriverId = widget.onlineDrivers.first.id;
    } else if (widget.allDrivers.isNotEmpty) {
      _selectedDriverId = widget.allDrivers.first.id;
    }
  }
  
  void _setupRealtimeSubscription() {
    _subscription = widget.supabaseClient
        .channel('all_drivers_location')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'drivers',
          callback: (payload) {
            if (!mounted || !_isListening) return;
            
            final newData = payload.newRecord;
            final driverId = newData['id']?.toString();
            final lat = newData['current_latitude'];
            final lng = newData['current_longitude'];
            final lastSeen = newData['last_seen_at'];
            
            if (driverId != null && lat != null && lng != null) {
              _addUpdateForDriver(
                driverId,
                _parseUtcTimestamp(lastSeen?.toString()) ?? DateTime.now().toUtc(),
                (lat as num).toDouble(),
                (lng as num).toDouble(),
              );
            }
          },
        )
        .subscribe();
  }
  
  void _startPolling() {
    // Poll every 5 seconds as backup
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted || !_isListening) return;
      
      try {
        final response = await widget.supabaseClient
            .from('drivers')
            .select('id, current_latitude, current_longitude, last_seen_at');
        
        for (var driverData in (response as List)) {
          final driverId = driverData['id']?.toString();
          final lat = driverData['current_latitude'];
          final lng = driverData['current_longitude'];
          final lastSeen = driverData['last_seen_at'];
          
          if (driverId != null && lat != null && lng != null && mounted) {
            final timestamp = _parseUtcTimestamp(lastSeen?.toString()) ?? DateTime.now().toUtc();
            final updates = _driverUpdates[driverId];
            
            // Only add if coordinates changed
            if (updates == null || 
                updates.isEmpty || 
                updates.last.latitude != lat || 
                updates.last.longitude != lng) {
              _addUpdateForDriver(driverId, timestamp, (lat as num).toDouble(), (lng as num).toDouble());
            }
          }
        }
      } catch (e) {
        debugPrint('[AllDriversCoordinateLogs] Polling error: $e');
      }
    });
  }
  
  void _addUpdateForDriver(String driverId, DateTime timestamp, double lat, double lng) {
    if (!_driverUpdates.containsKey(driverId)) {
      _driverUpdates[driverId] = [];
      _scrollControllers[driverId] = ScrollController();
    }
    
    final updates = _driverUpdates[driverId]!;
    
    // Check if this is a duplicate
    if (updates.isNotEmpty) {
      final last = updates.last;
      if (last.latitude == lat && 
          last.longitude == lng &&
          timestamp.difference(last.timestamp).inSeconds.abs() < 2) {
        return;
      }
    }
    
    setState(() {
      updates.add(_CoordinateUpdate(
        timestamp: timestamp,
        latitude: lat,
        longitude: lng,
      ));
      
      // Keep only last 100 updates per driver
      if (updates.length > 100) {
        updates.removeAt(0);
      }
    });
    
    // Auto-scroll if this driver is selected
    if (_selectedDriverId == driverId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final controller = _scrollControllers[driverId];
        if (controller != null && controller.hasClients) {
          controller.animateTo(
            controller.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }
  
  String _formatTime(DateTime time) {
    final local = time.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:'
           '${local.minute.toString().padLeft(2, '0')}:'
           '${local.second.toString().padLeft(2, '0')}';
  }
  
  app_driver_model.Driver? _getDriverById(String? id) {
    if (id == null) return null;
    try {
      return widget.allDrivers.firstWhere((d) => d.id == id);
    } catch (_) {
      return null;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final selectedDriver = _getDriverById(_selectedDriverId);
    final selectedUpdates = _selectedDriverId != null 
        ? (_driverUpdates[_selectedDriverId] ?? []) 
        : <_CoordinateUpdate>[];
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        height: 600,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.blue[600],
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.gps_fixed, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Coordinate Updates',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Live location logs for all drivers',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                // Live indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isListening ? Colors.green[50] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isListening ? Colors.green[300]! : Colors.grey[300]!,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _isListening ? Colors.green : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isListening ? 'LIVE' : 'PAUSED',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _isListening ? Colors.green[700] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Driver selector
            Container(
              height: 50,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                itemCount: widget.allDrivers.length,
                itemBuilder: (context, index) {
                  final driver = widget.allDrivers[index];
                  final isSelected = driver.id == _selectedDriverId;
                  final isOnline = driver.isOnline;
                  final updateCount = _driverUpdates[driver.id]?.length ?? 0;
                  final driverColor = driverColors[driver.colorIndex % driverColors.length];
                  
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: () => setState(() => _selectedDriverId = driver.id),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? driverColor : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? driverColor : Colors.grey[300]!,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: isOnline 
                                    ? (isSelected ? Colors.white : Colors.green)
                                    : (isSelected ? Colors.white54 : Colors.grey),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              driver.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? Colors.white : Colors.grey[800],
                              ),
                            ),
                            if (updateCount > 0) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.white24 : Colors.grey[200],
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$updateCount',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? Colors.white : Colors.grey[600],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Column headers
            if (selectedDriver != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: Text(
                        'TIME',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'COORDINATES (LAT, LNG)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            
            const SizedBox(height: 8),
            
            // Updates list
            Expanded(
              child: selectedDriver == null
                  ? Center(
                      child: Text(
                        'No drivers available',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    )
                  : selectedUpdates.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.hourglass_empty, size: 40, color: Colors.grey[400]),
                              const SizedBox(height: 8),
                              Text(
                                'Waiting for location updates from ${selectedDriver.name}...',
                                style: TextStyle(color: Colors.grey[600]),
                                textAlign: TextAlign.center,
                              ),
                              if (!selectedDriver.isOnline) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.orange[50],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Driver is currently offline',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.orange[700],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollControllers[_selectedDriverId],
                          itemCount: selectedUpdates.length,
                          itemBuilder: (context, index) {
                            final update = selectedUpdates[index];
                            final isLatest = index == selectedUpdates.length - 1;
                            final driverColor = driverColors[selectedDriver.colorIndex % driverColors.length];
                            
                            return Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: isLatest ? driverColor.withOpacity(0.1) : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isLatest ? driverColor.withOpacity(0.3) : Colors.grey[200]!,
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Time
                                  SizedBox(
                                    width: 70,
                                    child: Text(
                                      _formatTime(update.timestamp),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isLatest ? FontWeight.bold : FontWeight.normal,
                                        fontFamily: 'monospace',
                                        color: isLatest ? driverColor : Colors.grey[800],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Coordinates
                                  Expanded(
                                    child: Text(
                                      '${update.latitude.toStringAsFixed(6)}, ${update.longitude.toStringAsFixed(6)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontFamily: 'monospace',
                                        color: isLatest ? Colors.black : Colors.grey[700],
                                      ),
                                    ),
                                  ),
                                  // Latest badge
                                  if (isLatest)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: driverColor,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'NEW',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
            
            const SizedBox(height: 12),
            
            // Footer with controls
            Row(
              children: [
                if (selectedDriver != null)
                  Text(
                    '${selectedUpdates.length} updates for ${selectedDriver.name}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                const Spacer(),
                // Pause/Resume button
                TextButton.icon(
                  onPressed: () {
                    setState(() => _isListening = !_isListening);
                  },
                  icon: Icon(
                    _isListening ? Icons.pause : Icons.play_arrow,
                    size: 18,
                  ),
                  label: Text(_isListening ? 'Pause' : 'Resume'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                  ),
                ),
                const SizedBox(width: 8),
                // Close button
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[200],
                    foregroundColor: Colors.grey[800],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
