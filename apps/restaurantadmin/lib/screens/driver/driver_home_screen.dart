import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:restaurantadmin/services/location_foreground_service.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final SupabaseClient _supabase = Supabase.instance.client;
  final LocationForegroundService _foregroundService = LocationForegroundService();
  late TabController _tabController;
  
  bool _isDriverOnline = false;
  String? _driverRecordId;
  String? _employeeId;
  String _driverName = 'Driver';
  bool _isLoading = true;
  bool _isTogglingStatus = false;
  Position? _lastPosition;
  DateTime? _lastUpdateTime;
  int _updateCount = 0;

  Timer? _locationUpdateTimer;
  StreamSubscription<Position>? _positionStream;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 2, vsync: this);
    _initializeForegroundService();
    _initializeDriver();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    _stopLocationTracking();
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // When app returns to foreground, sync status
    if (state == AppLifecycleState.resumed && _isDriverOnline && _driverRecordId != null) {
      debugPrint('[DriverHomeScreen] App resumed, syncing location...');
      _fetchAndSaveLocationNow();
    }
  }
  
  Future<void> _initializeForegroundService() async {
    await _foregroundService.init();
    // Listen for location updates from foreground service
    _foregroundService.onLocationUpdate = (lat, lng) {
      if (mounted) {
        setState(() {
          _lastPosition = Position(
            latitude: lat,
            longitude: lng,
            timestamp: DateTime.now(),
            accuracy: 0,
            altitude: 0,
            altitudeAccuracy: 0,
            heading: 0,
            headingAccuracy: 0,
            speed: 0,
            speedAccuracy: 0,
          );
          _lastUpdateTime = DateTime.now();
          _updateCount++;
        });
        debugPrint('[DriverHomeScreen] 📍 Foreground service update #$_updateCount: $lat, $lng');
      }
    };
  }

  Future<void> _initializeDriver() async {
    await _fetchDriverRecord();
    if (_driverRecordId != null && _isDriverOnline) {
      _startLocationTracking();
    }
    if (mounted) setState(() => _isLoading = false);
  }

  /// Start continuous location streaming with foreground service for Android
  void _startLocationTracking() async {
    _stopLocationTracking();
    if (!mounted || !_isDriverOnline || _driverRecordId == null) return;

    debugPrint('[DriverHomeScreen] 🚀 Starting continuous location tracking...');
    
    // Reset update counter
    setState(() {
      _updateCount = 0;
      _lastUpdateTime = DateTime.now();
    });

    // On Android, use the foreground service for reliable background tracking
    if (Platform.isAndroid) {
      debugPrint('[DriverHomeScreen] 🤖 Starting Android foreground service...');
      final started = await _foregroundService.startService(_driverRecordId!);
      debugPrint('[DriverHomeScreen] Foreground service started: $started');
      
      if (!started && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not start background tracking. Location may not update when app is minimized.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }

    // Use location stream for real-time updates (works alongside foreground service)
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 3, // Update every 3 meters moved for precise tracking
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) {
      if (!mounted || !_isDriverOnline || _driverRecordId == null) return;
      
      final now = DateTime.now();
      debugPrint('[DriverHomeScreen] 📍 Stream update #${_updateCount + 1}: ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}');
      
      setState(() {
        _lastPosition = position;
        _lastUpdateTime = now;
        _updateCount++;
      });
      
      _saveLocationToDatabase(position);
    }, onError: (error) {
      debugPrint('[DriverHomeScreen] ❌ Location stream error: $error');
    });

    // Backup timer every 10 seconds for stationary positions
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (!_isDriverOnline || !mounted) {
        timer.cancel();
        return;
      }
      debugPrint('[DriverHomeScreen] ⏰ Backup timer tick - fetching location...');
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 5),
        );
        debugPrint('[DriverHomeScreen] ⏰ Backup timer got position: ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}');
        _saveLocationToDatabase(position);
        
        if (mounted) {
          setState(() {
            _lastPosition = position;
            _lastUpdateTime = DateTime.now();
            _updateCount++;
          });
        }
      } catch (e) {
        debugPrint('[DriverHomeScreen] ❌ Backup location fetch failed: $e');
      }
    });
    
    // Immediately fetch and save location
    _fetchAndSaveLocationNow();
  }
  
  Future<void> _fetchAndSaveLocationNow() async {
    try {
      debugPrint('[DriverHomeScreen] 🔄 Fetching immediate location...');
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      debugPrint('[DriverHomeScreen] ✅ Immediate location: ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}');
      _saveLocationToDatabase(position);
    } catch (e) {
      debugPrint('[DriverHomeScreen] ❌ Immediate location fetch failed: $e');
    }
  }

  void _stopLocationTracking() async {
    _positionStream?.cancel();
    _positionStream = null;
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = null;
    
    // Stop foreground service on Android
    if (Platform.isAndroid) {
      await _foregroundService.stopService();
    }
    
    debugPrint('[DriverHomeScreen] Location tracking stopped');
  }

  /// Request background location permission (Android 10+)
  /// This enables "Allow all the time" location access
  Future<void> _requestBackgroundLocationPermission() async {
    if (!mounted) return;
    
    // Check current background location status
    final bgStatus = await ph.Permission.locationAlways.status;
    debugPrint('[DriverHomeScreen] Background location status: $bgStatus');
    
    if (bgStatus.isGranted) {
      debugPrint('[DriverHomeScreen] Background location already granted');
      return;
    }
    
    // Show explanation dialog
    final shouldRequest = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.location_on, color: Colors.blue[600]),
            const SizedBox(width: 8),
            const Text('Background Location'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'To track your location while delivering, we need "Allow all the time" permission.',
              style: TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📍 On the next screen:',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[800]),
                  ),
                  const SizedBox(height: 8),
                  Text('1. Tap "Permissions"', style: TextStyle(color: Colors.blue[700])),
                  Text('2. Tap "Location"', style: TextStyle(color: Colors.blue[700])),
                  Text('3. Select "Allow all the time"', style: TextStyle(color: Colors.blue[700], fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Skip for now'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.settings),
            label: const Text('Open Settings'),
          ),
        ],
      ),
    );

    if (shouldRequest == true) {
      // Request the permission - this will open app settings on Android 11+
      final result = await ph.Permission.locationAlways.request();
      debugPrint('[DriverHomeScreen] Background location request result: $result');
      
      if (result.isDenied || result.isPermanentlyDenied) {
        // Open app settings manually
        await ph.openAppSettings();
      }
      
      // Wait a moment for user to return from settings
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Check the result
      final finalStatus = await ph.Permission.locationAlways.status;
      if (mounted) {
        if (finalStatus.isGranted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Background location enabled! ✓'),
                ],
              ),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Background location not granted. Your location may not update when the app is minimized.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  Future<void> _saveLocationToDatabase(Position position) async {
    if (_driverRecordId == null) return;
    
    try {
      // Use the position's own timestamp if available, otherwise use current UTC time.
      // This ensures the time reflects when the GPS fix was actually taken.
      final positionTime = position.timestamp.toUtc();
      final nowUtc = DateTime.now().toUtc();
      
      // Use whichever is more recent to avoid stale timestamps
      final saveTime = positionTime.isAfter(nowUtc) ? nowUtc : nowUtc;
      
      await _supabase
          .from('drivers')
          .update({
            'current_latitude': position.latitude,
            'current_longitude': position.longitude,
            'last_seen_at': saveTime.toIso8601String(),
          })
          .eq('id', _driverRecordId!);
          
      debugPrint('[DriverHomeScreen] 📍 Location saved: ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)} at ${saveTime.toIso8601String()}');
      
      if (mounted) {
        setState(() {
          _lastPosition = position;
          _lastUpdateTime = DateTime.now(); // local time for UI display
        });
      }
    } catch (e) {
      debugPrint('[DriverHomeScreen] Error saving location: $e');
    }
  }

  Future<void> _fetchDriverRecord() async {
    if (!mounted) return;
    
    // ALWAYS get the current user directly from Supabase Auth - most reliable
    final currentUser = _supabase.auth.currentUser;
    debugPrint('[DriverHomeScreen] ========== FETCHING DRIVER ==========');
    debugPrint('[DriverHomeScreen] Current Auth User ID: ${currentUser?.id}');
    debugPrint('[DriverHomeScreen] Current Auth User Email: ${currentUser?.email}');
    
    if (currentUser == null) {
      debugPrint("[DriverHomeScreen] ❌ No authenticated user found!");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Not logged in. Please login again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    
    // Use the auth user ID directly
    await _fetchDriverByUserId(currentUser.id);
  }

  Future<void> _fetchDriverByUserId(String userId) async {
    try {
      debugPrint('[DriverHomeScreen] ========================================');
      debugPrint('[DriverHomeScreen] Searching for user_id: $userId');
      debugPrint('[DriverHomeScreen] ========================================');
      
      // DIRECT QUERY - Just get the driver by user_id, nothing fancy
      final driverResponse = await _supabase
          .from('drivers')
          .select('*')
          .eq('user_id', userId)
          .maybeSingle();

      debugPrint('[DriverHomeScreen] Driver query result: $driverResponse');

      if (driverResponse != null) {
        // SUCCESS! Driver found
        if (mounted) {
          setState(() {
            _driverRecordId = driverResponse['id'] as String?;
            _driverName = driverResponse['name'] as String? ?? 'Driver';
            _isDriverOnline = driverResponse['is_online'] as bool? ?? false;
          });
        }
        debugPrint('[DriverHomeScreen] ✅ Driver found! ID: $_driverRecordId, Name: $_driverName, Online: $_isDriverOnline');
        
        // Also get employee ID for shifts
        final empResponse = await _supabase
            .from('employees')
            .select('id')
            .eq('auth_user_id', userId)
            .maybeSingle();
        if (empResponse != null && mounted) {
          setState(() => _employeeId = empResponse['id'] as String?);
        }
        return;
      }
      
      // Driver not found - try by name as last resort
      debugPrint('[DriverHomeScreen] ❌ No driver found by user_id, checking all drivers...');
      final allDrivers = await _supabase.from('drivers').select('id, name, user_id');
      debugPrint('[DriverHomeScreen] All drivers: $allDrivers');
      
      // Check if any driver has matching user_id (case-insensitive check)
      for (var d in allDrivers) {
        final driverId = d['user_id']?.toString().toLowerCase();
        if (driverId == userId.toLowerCase()) {
          debugPrint('[DriverHomeScreen] Found driver with case mismatch!');
        }
      }
      
      // Last attempt - check employee and create driver if needed
      final empResponse = await _supabase
          .from('employees')
          .select('id, name, is_driver')
          .eq('auth_user_id', userId)
          .maybeSingle();
      
      debugPrint('[DriverHomeScreen] Employee check: $empResponse');
      
      if (empResponse != null && empResponse['is_driver'] == true) {
        // Create driver record automatically
        debugPrint('[DriverHomeScreen] Creating driver record for employee...');
        final newDriver = await _supabase
            .from('drivers')
            .insert({
              'user_id': userId,
              'name': empResponse['name'] ?? 'Driver',
              'is_online': false,
            })
            .select()
            .single();
        
        if (mounted) {
          setState(() {
            _driverRecordId = newDriver['id'] as String?;
            _driverName = newDriver['name'] as String? ?? 'Driver';
            _employeeId = empResponse['id'] as String?;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Driver record created!'), backgroundColor: Colors.green),
          );
        }
        return;
      }
      
      // Really couldn't find anything
      debugPrint('[DriverHomeScreen] ❌ Could not find or create driver record');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Driver not found. User ID: ${userId.substring(0, 8)}...'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 10),
          ),
        );
      }
    } catch (e, stack) {
      debugPrint('[DriverHomeScreen] ERROR: $e');
      debugPrint('[DriverHomeScreen] Stack: $stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _toggleOnlineStatus(bool newStatus) async {
    if (!mounted) return;
    
    if (_driverRecordId == null) {
      debugPrint('[DriverHomeScreen] Cannot toggle: _driverRecordId is null');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Driver record not found. Please contact your manager.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    if (_isTogglingStatus) {
      debugPrint('[DriverHomeScreen] Cannot toggle: already toggling');
      return;
    }

    setState(() => _isTogglingStatus = true);
    debugPrint('[DriverHomeScreen] Toggling status to: $newStatus');

    final nowUtc = DateTime.now().toUtc();
    Map<String, dynamic> updateData = {
      'is_online': newStatus,
      'last_seen_at': nowUtc.toIso8601String(),
    };

    if (newStatus) {
      try {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please enable location services to go online'),
                backgroundColor: Colors.orange,
              ),
            );
            setState(() => _isTogglingStatus = false);
          }
          return;
        }

        // Step 1: Request foreground location permission first
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Location permission is required to go online'),
                  backgroundColor: Colors.orange,
                ),
              );
              setState(() => _isTogglingStatus = false);
            }
            return;
          }
        }
        
        if (permission == LocationPermission.deniedForever) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location permissions are permanently denied. Please enable in settings.'),
                backgroundColor: Colors.orange,
              ),
            );
            setState(() => _isTogglingStatus = false);
          }
          return;
        }

        // Step 2: Request background location permission (Android 10+)
        // This is required for "Allow all the time" location access
        if (Platform.isAndroid && permission == LocationPermission.whileInUse) {
          await _requestBackgroundLocationPermission();
        }

        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high
        );
        updateData['current_latitude'] = position.latitude;
        updateData['current_longitude'] = position.longitude;
        _lastPosition = position;
      } catch (e) {
        debugPrint("[DriverHomeScreen] Error getting location: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not get location: $e'), backgroundColor: Colors.red),
          );
          setState(() => _isTogglingStatus = false);
        }
        return;
      }
    } else {
      // Going offline
      _stopLocationTracking();
    }

    try {
      await _supabase.from('drivers').update(updateData).eq('id', _driverRecordId!);
      if (mounted) {
        setState(() {
          _isDriverOnline = newStatus;
          _isTogglingStatus = false;
        });
        
        // Start or stop location tracking based on new status
        if (newStatus) {
          _startLocationTracking();
        }
      }
    } catch (e) {
      debugPrint('[DriverHomeScreen] Error updating driver status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isTogglingStatus = false);
      }
    }
  }

  Future<void> _logout() async {
    if (_isDriverOnline && _driverRecordId != null) {
      await _toggleOnlineStatus(false);
    }
    await _supabase.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/login',
        (Route<dynamic> route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F5F5),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // PopScope prevents back navigation to admin app - CRITICAL SECURITY
    return PopScope(
      canPop: false, // Prevent back button from going to admin app
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          // Show logout confirmation instead of going back
          _showExitConfirmation();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          automaticallyImplyLeading: false, // Remove back arrow - drivers can't access admin
          title: Text(
            _driverName,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: _isDriverOnline ? Colors.green[600] : const Color(0xFF2D3748),
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Logout',
              onPressed: _logout,
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            tabs: const [
              Tab(icon: Icon(Icons.power_settings_new), text: 'Status'),
              Tab(icon: Icon(Icons.calendar_today), text: 'My Shifts'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildStatusTab(),
            _DriverShiftsTab(employeeId: _employeeId, driverName: _driverName),
          ],
        ),
      ),
    );
  }
  
  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.exit_to_app, color: Colors.orange),
            SizedBox(width: 12),
            Text('Exit App?'),
          ],
        ),
        content: const Text('Do you want to logout or exit the app?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () {
              Navigator.pop(ctx);
              _logout();
            },
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTab() {
    // Show error state if driver record not found
    if (_driverRecordId == null) {
      return Container(
        color: Colors.grey[100],
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.warning_amber_rounded, size: 64, color: Colors.orange[700]),
                ),
                const SizedBox(height: 24),
                Text(
                  'Driver Not Set Up',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Your account is not linked to a driver record.\nPlease contact your manager.',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() => _isLoading = true);
                    _initializeDriver();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      color: _isDriverOnline ? Colors.green[50] : Colors.grey[100],
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Status Icon
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: _isDriverOnline ? Colors.green[100] : Colors.grey[200],
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (_isDriverOnline ? Colors.green : Colors.grey).withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Icon(
                  _isDriverOnline ? Icons.delivery_dining : Icons.delivery_dining_outlined,
                  size: 80,
                  color: _isDriverOnline ? Colors.green[700] : Colors.grey[500],
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Status Text
              Text(
                _isDriverOnline ? 'You are ONLINE' : 'You are OFFLINE',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: _isDriverOnline ? Colors.green[700] : Colors.grey[600],
                ),
              ),
              
              const SizedBox(height: 12),
              
              Text(
                _isDriverOnline 
                    ? 'Your location is being shared in real-time'
                    : 'Tap the switch to start your shift',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 60),
              
              // Big Switch
              Transform.scale(
                scale: 2.0,
                child: Switch(
                  value: _isDriverOnline,
                  onChanged: _isTogglingStatus ? null : _toggleOnlineStatus,
                  activeColor: Colors.green[600],
                  activeTrackColor: Colors.green[200],
                  inactiveThumbColor: Colors.grey[400],
                  inactiveTrackColor: Colors.grey[300],
                ),
              ),
              
              const SizedBox(height: 20),
              
              if (_isTogglingStatus)
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Text('Updating status...'),
                  ],
                ),
              
              const SizedBox(height: 40),
              
              // Location info when online
              if (_isDriverOnline)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Status row
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.green[100],
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.gps_fixed, color: Colors.green[700], size: 16),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'Live Tracking Active',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Pulse animation indicator
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.green.withOpacity(0.5),
                                          blurRadius: 4,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                Platform.isAndroid ? 'Background service enabled' : 'Updates every 5-10 seconds',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      // Stats row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStatChip('Updates', '$_updateCount', Colors.blue),
                          if (_lastUpdateTime != null)
                            _buildStatChip(
                              'Last',
                              _formatLocalTime(_lastUpdateTime!),
                              Colors.green,
                            ),
                        ],
                      ),
                      
                      if (_lastPosition != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '📍 ${_lastPosition!.latitude.toStringAsFixed(5)}, ${_lastPosition!.longitude.toStringAsFixed(5)}',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// Format a DateTime to local HH:MM:SS string for display.
  String _formatLocalTime(DateTime dt) {
    final local = dt.isUtc ? dt.toLocal() : dt;
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}:'
        '${local.second.toString().padLeft(2, '0')}';
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color.withOpacity(0.8),
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

// ============ DRIVER SHIFTS TAB ============

class _DriverShiftsTab extends StatefulWidget {
  final String? employeeId;
  final String driverName;

  const _DriverShiftsTab({required this.employeeId, required this.driverName});

  @override
  State<_DriverShiftsTab> createState() => _DriverShiftsTabState();
}

class _DriverShiftsTabState extends State<_DriverShiftsTab> {
  final _supabase = Supabase.instance.client;
  
  bool _isWeeklyView = false;
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _shifts = [];
  double _hourlyWage = 0.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(covariant _DriverShiftsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.employeeId != widget.employeeId) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    await _loadEmployeeWage();
    await _loadShifts();
  }

  Future<void> _loadEmployeeWage() async {
    if (widget.employeeId == null) return;

    try {
      final response = await _supabase
          .from('employees')
          .select('hourly_wage')
          .eq('id', widget.employeeId!)
          .maybeSingle();

      if (response != null && mounted) {
        setState(() {
          _hourlyWage = (response['hourly_wage'] as num?)?.toDouble() ?? 0.0;
        });
      }
    } catch (e) {
      debugPrint('[DriverShiftsTab] Error loading wage: $e');
    }
  }

  Future<void> _loadShifts() async {
    if (widget.employeeId == null) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final List<String> dates = _isWeeklyView ? _getWeekDates() : [_formatDate(_selectedDate)];
      
      final response = await _supabase
          .from('employee_shifts')
          .select('id, date, start_time, end_time')
          .eq('employee_id', widget.employeeId!)
          .inFilter('date', dates)
          .order('date')
          .order('start_time');

      if (mounted) {
        setState(() {
          _shifts = List<Map<String, dynamic>>.from(response as List);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[DriverShiftsTab] Error loading shifts: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int _calculateShiftMinutes(Map<String, dynamic> shift) {
    final startTime = shift['start_time'] as String?;
    final endTime = shift['end_time'] as String?;
    if (startTime == null || endTime == null) return 0;
    
    final startParts = startTime.split(':');
    final endParts = endTime.split(':');
    if (startParts.length < 2 || endParts.length < 2) return 0;
    
    final startMinutes = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
    final endMinutes = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
    return endMinutes >= startMinutes 
        ? endMinutes - startMinutes 
        : (1440 - startMinutes) + endMinutes;
  }

  double _calculateShiftWage(Map<String, dynamic> shift) {
    return (_calculateShiftMinutes(shift) / 60.0) * _hourlyWage;
  }

  double _calculateTotalWage() {
    double total = 0;
    for (var shift in _shifts) {
      total += _calculateShiftWage(shift);
    }
    return total;
  }

  int _calculateTotalMinutes() {
    int total = 0;
    for (var shift in _shifts) {
      total += _calculateShiftMinutes(shift);
    }
    return total;
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  List<String> _getWeekDates() {
    // Week starts on Tuesday, ends on Monday
    final tuesday = _selectedDate.subtract(Duration(days: (_selectedDate.weekday - 2 + 7) % 7));
    return List.generate(7, (i) => _formatDate(tuesday.add(Duration(days: i))));
  }

  String _formatDisplayDate(DateTime date) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${days[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  }

  void _previousPeriod() {
    setState(() {
      _selectedDate = _selectedDate.subtract(Duration(days: _isWeeklyView ? 7 : 1));
    });
    _loadShifts();
  }

  void _nextPeriod() {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: _isWeeklyView ? 7 : 1));
    });
    _loadShifts();
  }

  void _goToToday() {
    setState(() {
      _selectedDate = DateTime.now();
    });
    _loadShifts();
  }

  bool get _isToday => _selectedDate.year == DateTime.now().year &&
      _selectedDate.month == DateTime.now().month &&
      _selectedDate.day == DateTime.now().day;

  @override
  Widget build(BuildContext context) {
    final totalWage = _calculateTotalWage();
    final totalMinutes = _calculateTotalMinutes();
    final totalHours = totalMinutes ~/ 60;
    final totalMins = totalMinutes % 60;

    return Container(
      color: const Color(0xFFF5F5F5),
      child: Column(
        children: [
          // Clean earnings summary
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isWeeklyView ? 'This Week' : (_isToday ? 'Today' : _formatDisplayDate(_selectedDate)),
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '€${totalWage.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF2D3748)),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${totalHours}h ${totalMins}m',
                    style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700], fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

          // Simple navigation bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Day/Week toggle
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      _buildViewToggle('Day', !_isWeeklyView, () {
                        setState(() => _isWeeklyView = false);
                        _loadShifts();
                      }),
                      _buildViewToggle('Week', _isWeeklyView, () {
                        setState(() => _isWeeklyView = true);
                        _loadShifts();
                      }),
                    ],
                  ),
                ),
                const Spacer(),
                // Date nav
                IconButton(
                  icon: const Icon(Icons.chevron_left, size: 24),
                  onPressed: _previousPeriod,
                  color: Colors.grey[700],
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
                GestureDetector(
                  onTap: _goToToday,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _isToday && !_isWeeklyView ? const Color(0xFF4CAF50) : Colors.grey[200],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _isWeeklyView ? _getWeekRangeText() : (_isToday ? 'Today' : '${_selectedDate.day}/${_selectedDate.month}'),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _isToday && !_isWeeklyView ? Colors.white : Colors.grey[800],
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, size: 24),
                  onPressed: _nextPeriod,
                  color: Colors.grey[700],
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Shifts List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : widget.employeeId == null
                    ? _buildNoEmployeeState()
                    : _shifts.isEmpty
                        ? _buildEmptyState()
                        : _isWeeklyView
                            ? _buildWeeklyView()
                            : _buildDayView(),
          ),
        ],
      ),
    );
  }

  String _getWeekRangeText() {
    // Week starts on Tuesday, ends on Monday
    final tuesday = _selectedDate.subtract(Duration(days: (_selectedDate.weekday - 2 + 7) % 7));
    final monday = tuesday.add(const Duration(days: 6));
    return '${tuesday.day}/${tuesday.month} - ${monday.day}/${monday.month}';
  }

  Widget _buildViewToggle(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.grey[600],
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildNoEmployeeState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_off_outlined, size: 40, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text('Not set up', style: TextStyle(fontSize: 15, color: Colors.grey[600])),
          const SizedBox(height: 4),
          Text('Contact your manager', style: TextStyle(fontSize: 13, color: Colors.grey[400])),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_available_outlined, size: 40, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            _isWeeklyView ? 'No shifts this week' : 'No shifts today',
            style: TextStyle(fontSize: 15, color: Colors.grey[600]),
          ),
          const SizedBox(height: 4),
          Text('Enjoy your time off!', style: TextStyle(fontSize: 13, color: Colors.grey[400])),
        ],
      ),
    );
  }

  Widget _buildDayView() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: _shifts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _buildShiftCard(_shifts[index]),
    );
  }

  Widget _buildWeeklyView() {
    final Map<String, List<Map<String, dynamic>>> shiftsByDate = {};
    for (final shift in _shifts) {
      final date = shift['date'] as String;
      shiftsByDate.putIfAbsent(date, () => []).add(shift);
    }
    final weekDates = _getWeekDates();

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: weekDates.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final dateStr = weekDates[index];
        final date = DateTime.parse(dateStr);
        final dayShifts = shiftsByDate[dateStr] ?? [];
        final isTodayDate = dateStr == _formatDate(DateTime.now());
        final dayWage = dayShifts.fold(0.0, (sum, s) => sum + _calculateShiftWage(s));

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isTodayDate ? const Color(0xFF4CAF50) : Colors.grey.shade200),
          ),
          child: Column(
            children: [
              // Day header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isTodayDate ? const Color(0xFFE8F5E9) : Colors.grey[50],
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
                ),
                child: Row(
                  children: [
                    Text(
                      _formatDisplayDate(date),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: isTodayDate ? const Color(0xFF2E7D32) : Colors.grey[800],
                      ),
                    ),
                    if (isTodayDate) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text('TODAY', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    ],
                    const Spacer(),
                    if (dayShifts.isNotEmpty)
                      Text('€${dayWage.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700], fontSize: 13)),
                    if (dayShifts.isEmpty)
                      Text('Off', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                  ],
                ),
              ),
              // Shifts
              if (dayShifts.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text('No shifts', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                )
              else
                ...dayShifts.map((shift) => _buildMiniShiftCard(shift)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShiftCard(Map<String, dynamic> shift) {
    final startTime = (shift['start_time'] as String?)?.substring(0, 5) ?? '--:--';
    final endTime = (shift['end_time'] as String?)?.substring(0, 5) ?? '--:--';
    final duration = _calculateDuration(shift['start_time'], shift['end_time']);
    final wage = _calculateShiftWage(shift);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$startTime - $endTime',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D3748)),
              ),
              const SizedBox(height: 2),
              Text(duration, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            ],
          ),
          const Spacer(),
          Text(
            '€${wage.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4CAF50)),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniShiftCard(Map<String, dynamic> shift) {
    final startTime = (shift['start_time'] as String?)?.substring(0, 5) ?? '--:--';
    final endTime = (shift['end_time'] as String?)?.substring(0, 5) ?? '--:--';
    final wage = _calculateShiftWage(shift);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        children: [
          Text(
            '$startTime - $endTime',
            style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[700], fontSize: 13),
          ),
          const Spacer(),
          Text(
            '€${wage.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF4CAF50), fontSize: 13),
          ),
        ],
      ),
    );
  }

  String _calculateDuration(String? startTime, String? endTime) {
    if (startTime == null || endTime == null) return '--';
    
    final startParts = startTime.split(':');
    final endParts = endTime.split(':');
    if (startParts.length < 2 || endParts.length < 2) return '--';
    
    final startMinutes = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
    final endMinutes = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
    final duration = endMinutes >= startMinutes 
        ? endMinutes - startMinutes 
        : (1440 - startMinutes) + endMinutes;
    
    final hours = duration ~/ 60;
    final mins = duration % 60;
    
    if (hours > 0 && mins > 0) return '${hours}h ${mins}m';
    if (hours > 0) return '${hours}h';
    return '${mins}m';
  }
}
