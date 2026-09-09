import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:url_launcher/url_launcher.dart';
import 'package:restaurantadmin/services/location_foreground_service.dart';
import 'package:restaurantadmin/services/demo_order_service.dart';

// ─────────────────────────────────────────────────────────────────────
// Design tokens
// ─────────────────────────────────────────────────────────────────────
class _DriverTheme {
  static const Color bg = Color(0xFFF8F9FA);
  static const Color surface = Colors.white;
  static const Color surfaceLight = Color(0xFFF3F4F6);
  static const Color accent = Color(0xFF4F46E5);
  static const Color accentLight = Color(0xFFEEF2FF);
  static const Color success = Color(0xFF10B981);
  static const Color successDark = Color(0xFF059669);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF4B5563);
  static const Color textMuted = Color(0xFF9CA3AF);
  static const Color cash = Color(0xFF059669);
  static const Color card = Color(0xFF4F46E5);
  static const Color divider = Color(0xFFE5E7EB);

  static const borderRadius = 16.0;
  static const borderRadiusSmall = 10.0;
  static const borderRadiusTiny = 6.0;

  static BoxShadow glow(Color color, {double blur = 12, double spread = 0}) =>
      BoxShadow(color: color.withOpacity(0.12), blurRadius: blur, spreadRadius: spread);
}

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  final SupabaseClient _supabase = Supabase.instance.client;
  final LocationForegroundService _foregroundService = LocationForegroundService();

  // Nav
  int _currentTab = 0; // 0=route, 1=status, 2=shifts
  final GlobalKey<_DriverRouteTabState> _routeTabKey = GlobalKey<_DriverRouteTabState>();

  bool _isDriverOnline = false;
  String? _driverRecordId;
  String? _employeeId;
  String _driverName = 'Driver';
  bool _isLoading = true;
  bool _isTogglingStatus = false;
  bool _isDemoDriver = false;
  bool _isGeneratingDemoOrder = false;
  Position? _lastPosition;
  DateTime? _lastUpdateTime;
  int _updateCount = 0;

  Timer? _locationUpdateTimer;
  StreamSubscription<Position>? _positionStream;

  // Pulse animation for online status
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _initializeForegroundService();
    _initializeDriver();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();
    _stopLocationTracking();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      if (_isDriverOnline && _driverRecordId != null) {
        debugPrint('[DriverHomeScreen] App resumed, syncing location...');
        _fetchAndSaveLocationNow();
      }
      _routeTabKey.currentState?.reload();
    }
  }

  Future<void> _initializeForegroundService() async {
    await _foregroundService.init();
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

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 1,
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

    // Backup timer every 5 seconds for stationary positions
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
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

    if (Platform.isAndroid) {
      await _foregroundService.stopService();
    }

    debugPrint('[DriverHomeScreen] Location tracking stopped');
  }

  /// Request background location permission (Android 10+)
  Future<void> _requestBackgroundLocationPermission() async {
    if (!mounted) return;

    final bgStatus = await ph.Permission.locationAlways.status;
    debugPrint('[DriverHomeScreen] Background location status: $bgStatus');

    if (bgStatus.isGranted) {
      debugPrint('[DriverHomeScreen] Background location already granted');
      return;
    }

    final shouldRequest = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: _DriverTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _DriverTheme.accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.location_on, color: _DriverTheme.accent, size: 22),
            ),
            const SizedBox(width: 12),
            const Text('Background Location', style: TextStyle(color: _DriverTheme.textPrimary, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'To track your location while delivering, we need "Allow all the time" permission.',
              style: TextStyle(fontSize: 14, color: _DriverTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _DriverTheme.accent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _DriverTheme.accent.withOpacity(0.2)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('📍 On the next screen:', style: TextStyle(fontWeight: FontWeight.bold, color: _DriverTheme.accentLight, fontSize: 13)),
                  SizedBox(height: 8),
                  Text('1. Tap "Permissions"', style: TextStyle(color: _DriverTheme.textSecondary, fontSize: 13)),
                  Text('2. Tap "Location"', style: TextStyle(color: _DriverTheme.textSecondary, fontSize: 13)),
                  Text('3. Select "Allow all the time"', style: TextStyle(color: _DriverTheme.accentLight, fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Skip', style: TextStyle(color: _DriverTheme.textMuted)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _DriverTheme.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.settings, size: 18),
            label: const Text('Open Settings'),
          ),
        ],
      ),
    );

    if (shouldRequest == true) {
      final result = await ph.Permission.locationAlways.request();
      debugPrint('[DriverHomeScreen] Background location request result: $result');

      if (result.isDenied || result.isPermanentlyDenied) {
        await ph.openAppSettings();
      }

      await Future.delayed(const Duration(milliseconds: 500));

      final finalStatus = await ph.Permission.locationAlways.status;
      if (mounted) {
        if (finalStatus.isGranted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(children: [Icon(Icons.check_circle, color: Colors.white), SizedBox(width: 8), Text('Background location enabled!')]),
              backgroundColor: _DriverTheme.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Background location not granted. Your location may not update when minimized.'),
              backgroundColor: _DriverTheme.warning,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    }
  }

  Future<void> _saveLocationToDatabase(Position position) async {
    if (_driverRecordId == null) return;

    try {
      final nowUtc = DateTime.now().toUtc();

      final Map<String, dynamic> updateData = {
        'current_latitude': position.latitude,
        'current_longitude': position.longitude,
        'last_seen_at': nowUtc.toIso8601String(),
      };

      if (position.heading >= 0 && position.heading <= 360) {
        updateData['current_heading'] = position.heading;
      }
      if (position.speed >= 0) {
        updateData['current_speed'] = position.speed;
      }

      await _supabase.from('drivers').update(updateData).eq('id', _driverRecordId!);

      debugPrint('[DriverHomeScreen] 📍 Location saved: ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)} heading=${position.heading.toStringAsFixed(0)}° speed=${position.speed.toStringAsFixed(1)}m/s');

      if (mounted) {
        setState(() {
          _lastPosition = position;
          _lastUpdateTime = DateTime.now();
        });
      }
    } catch (e) {
      debugPrint('[DriverHomeScreen] Error saving location: $e');
    }
  }

  Future<void> _fetchDriverRecord() async {
    if (!mounted) return;

    final currentUser = _supabase.auth.currentUser;
    debugPrint('[DriverHomeScreen] ========== FETCHING DRIVER ==========');
    debugPrint('[DriverHomeScreen] Current Auth User ID: ${currentUser?.id}');
    debugPrint('[DriverHomeScreen] Current Auth User Email: ${currentUser?.email}');

    if (currentUser == null) {
      debugPrint("[DriverHomeScreen] ❌ No authenticated user found!");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Not logged in. Please login again.'),
            backgroundColor: _DriverTheme.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
      return;
    }

    await _fetchDriverByUserId(currentUser.id);
  }

  Future<void> _fetchDriverByUserId(String userId) async {
    try {
      debugPrint('[DriverHomeScreen] Searching for user_id: $userId');

      final driverResponse = await _supabase
          .from('drivers')
          .select('*')
          .eq('user_id', userId)
          .maybeSingle();

      debugPrint('[DriverHomeScreen] Driver query result: $driverResponse');

      if (driverResponse != null) {
        if (mounted) {
          setState(() {
            _driverRecordId = driverResponse['id'] as String?;
            _driverName = driverResponse['name'] as String? ?? 'Driver';
            _isDriverOnline = driverResponse['is_online'] as bool? ?? false;
            _isDemoDriver = (driverResponse['is_demo'] as bool? ?? false) ||
                _driverName.toLowerCase().contains('demo') ||
                _driverName.toLowerCase().contains('abunageb');
          });
        }
        debugPrint('[DriverHomeScreen] ✅ Driver found! ID: $_driverRecordId, Name: $_driverName, Online: $_isDriverOnline');

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

      debugPrint('[DriverHomeScreen] ❌ No driver found by user_id, checking all drivers...');
      final allDrivers = await _supabase.from('drivers').select('id, name, user_id');
      debugPrint('[DriverHomeScreen] All drivers: $allDrivers');

      for (var d in allDrivers) {
        final driverId = d['user_id']?.toString().toLowerCase();
        if (driverId == userId.toLowerCase()) {
          debugPrint('[DriverHomeScreen] Found driver with case mismatch!');
        }
      }

      final empResponse = await _supabase
          .from('employees')
          .select('id, name, is_driver')
          .eq('auth_user_id', userId)
          .maybeSingle();

      debugPrint('[DriverHomeScreen] Employee check: $empResponse');

      if (empResponse != null && empResponse['is_driver'] == true) {
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
            SnackBar(
              content: const Text('Driver record created!'),
              backgroundColor: _DriverTheme.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
        return;
      }

      debugPrint('[DriverHomeScreen] ❌ Could not find or create driver record');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Driver not found. User ID: ${userId.substring(0, 8)}...'),
            backgroundColor: _DriverTheme.warning,
            duration: const Duration(seconds: 10),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e, stack) {
      debugPrint('[DriverHomeScreen] ERROR: $e');
      debugPrint('[DriverHomeScreen] Stack: $stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: _DriverTheme.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _toggleOnlineStatus(bool newStatus) async {
    if (!mounted) return;

    if (_driverRecordId == null) {
      debugPrint('[DriverHomeScreen] Cannot toggle: _driverRecordId is null');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Driver record not found. Please contact your manager.'),
          backgroundColor: _DriverTheme.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
              SnackBar(
                content: const Text('Please enable location services to go online'),
                backgroundColor: _DriverTheme.warning,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
            setState(() => _isTogglingStatus = false);
          }
          return;
        }

        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Location permission is required to go online'),
                  backgroundColor: _DriverTheme.warning,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
              SnackBar(
                content: const Text('Location permissions permanently denied. Please enable in settings.'),
                backgroundColor: _DriverTheme.warning,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
            setState(() => _isTogglingStatus = false);
          }
          return;
        }

        if (Platform.isAndroid && permission == LocationPermission.whileInUse) {
          await _requestBackgroundLocationPermission();
        }

        Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        updateData['current_latitude'] = position.latitude;
        updateData['current_longitude'] = position.longitude;
        _lastPosition = position;
      } catch (e) {
        debugPrint("[DriverHomeScreen] Error getting location: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not get location: $e'),
              backgroundColor: _DriverTheme.danger,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
          setState(() => _isTogglingStatus = false);
        }
        return;
      }
    } else {
      _stopLocationTracking();
    }

    try {
      await _supabase.from('drivers').update(updateData).eq('id', _driverRecordId!);
      if (mounted) {
        setState(() {
          _isDriverOnline = newStatus;
          _isTogglingStatus = false;
        });
        HapticFeedback.mediumImpact();
        if (newStatus) {
          _startLocationTracking();
        }
      }
    } catch (e) {
      debugPrint('[DriverHomeScreen] Error updating driver status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            backgroundColor: _DriverTheme.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
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
        backgroundColor: _DriverTheme.bg,
        body: Center(child: CircularProgressIndicator(color: _DriverTheme.accent)),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _showExitConfirmation();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: _DriverTheme.bg,
          body: SafeArea(
            child: Column(
              children: [
                // Top header
                _buildHeader(),
                // Content
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _currentTab == 0
                        ? _DriverRouteTab(
                            key: _routeTabKey,
                            driverRecordId: _driverRecordId,
                            isOnline: _isDriverOnline,
                            isDemoDriver: _isDemoDriver,
                          )
                        : _currentTab == 1
                            ? _DriverTodaysRoutesTab(
                                key: const ValueKey('todays_routes'),
                                driverRecordId: _driverRecordId,
                                isDemoDriver: _isDemoDriver,
                              )
                            : _DriverShiftsTab(
                                key: const ValueKey('shifts'),
                                employeeId: _employeeId,
                                driverName: _driverName,
                              ),
                  ),
                ),
                // Bottom nav
                _buildBottomNav(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
      decoration: const BoxDecoration(
        color: _DriverTheme.surface,
        border: Border(bottom: BorderSide(color: _DriverTheme.divider, width: 1)),
      ),
      child: Row(
        children: [
          // Driver avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _isDriverOnline
                    ? [_DriverTheme.success, _DriverTheme.successDark]
                    : [_DriverTheme.textMuted, const Color(0xFFCBD5E1)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                _driverName.isNotEmpty ? _driverName[0].toUpperCase() : 'D',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _driverName,
                        style: const TextStyle(
                          color: _DriverTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_isDemoDriver) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.amber.withOpacity(0.6), width: 0.8),
                        ),
                        child: const Text(
                          'DEMO',
                          style: TextStyle(
                            color: Colors.amber,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Row(
                  children: [
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _isDriverOnline
                                ? _DriverTheme.success.withOpacity(_pulseAnimation.value)
                                : _DriverTheme.textMuted,
                            shape: BoxShape.circle,
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isDriverOnline ? 'Online' : 'Offline',
                      style: TextStyle(
                        color: _isDriverOnline ? _DriverTheme.success : _DriverTheme.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Demo Actions Button
          if (_isDemoDriver) ...[
            InkWell(
              onTap: _isGeneratingDemoOrder ? null : _handleAddDemoOrder,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _isGeneratingDemoOrder
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber),
                          )
                        : const Icon(Icons.flash_on, size: 14, color: Colors.amber),
                    const SizedBox(width: 4),
                    const Text(
                      '+Order',
                      style: TextStyle(
                        color: Colors.amber,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              icon: const Icon(Icons.cleaning_services_outlined, size: 18),
              color: _DriverTheme.textSecondary,
              onPressed: _handleResetDemo,
              tooltip: 'Reset Demo',
            ),
            const SizedBox(width: 2),
          ],
          // Online/Offline toggle
          GestureDetector(
            onTap: _isTogglingStatus ? null : () => _toggleOnlineStatus(!_isDriverOnline),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 56,
              height: 32,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: _isDriverOnline ? _DriverTheme.success.withOpacity(0.2) : _DriverTheme.surfaceLight,
                border: Border.all(
                  color: _isDriverOnline ? _DriverTheme.success : _DriverTheme.divider,
                  width: 1.5,
                ),
              ),
              child: Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    left: _isDriverOnline ? 26 : 2,
                    top: 2,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isDriverOnline ? _DriverTheme.success : _DriverTheme.textMuted,
                        boxShadow: _isDriverOnline
                            ? [BoxShadow(color: _DriverTheme.success.withOpacity(0.4), blurRadius: 8)]
                            : null,
                      ),
                      child: _isTogglingStatus
                          ? const Padding(
                              padding: EdgeInsets.all(5),
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Icon(
                              _isDriverOnline ? Icons.power_settings_new : Icons.power_settings_new,
                              size: 14,
                              color: Colors.white,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.logout_rounded, size: 20),
            color: _DriverTheme.textMuted,
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
    );
  }

  Future<void> _handleAddDemoOrder() async {
    setState(() => _isGeneratingDemoOrder = true);
    try {
      final res = await DemoOrderService.createDemoOrder();
      if (mounted) {
        final order = res['order'];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚡ Demo Order Added: ${order?['customer_name'] ?? 'Order'} (60m ETA)'),
            backgroundColor: _DriverTheme.accent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      await _routeTabKey.currentState?.reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding demo order: $e'),
            backgroundColor: _DriverTheme.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingDemoOrder = false);
    }
  }

  Future<void> _handleResetDemo() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _DriverTheme.surface,
        title: const Text('Reset Demo Data?', style: TextStyle(color: _DriverTheme.textPrimary)),
        content: const Text(
          'Delete all demo orders and routes for this driver?',
          style: TextStyle(color: _DriverTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: _DriverTheme.textMuted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _DriverTheme.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await DemoOrderService.resetDemoOrders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🧹 Demo data reset successfully.'),
            backgroundColor: Colors.blueGrey,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      await _routeTabKey.currentState?.reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error resetting demo: $e'),
            backgroundColor: _DriverTheme.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildBottomNav() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      decoration: const BoxDecoration(
        color: _DriverTheme.surface,
        border: Border(top: BorderSide(color: _DriverTheme.divider, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(0, Icons.route_rounded, 'Route'),
          _buildNavItem(1, Icons.alt_route_rounded, "Today's Routes"),
          _buildNavItem(2, Icons.calendar_today_rounded, 'Shifts'),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isActive = _currentTab == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _currentTab = index);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? _DriverTheme.accent.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isActive ? _DriverTheme.accent : _DriverTheme.textMuted, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? _DriverTheme.accent : _DriverTheme.textMuted,
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _DriverTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.exit_to_app, color: _DriverTheme.warning),
            SizedBox(width: 12),
            Text('Exit App?', style: TextStyle(color: _DriverTheme.textPrimary)),
          ],
        ),
        content: const Text('Do you want to logout or exit the app?', style: TextStyle(color: _DriverTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: _DriverTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _DriverTheme.warning,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
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

}

// ╔══════════════════════════════════════════════════════════════════╗
// ║  DRIVER TODAY'S ROUTES TAB                                    ║
// ╚══════════════════════════════════════════════════════════════════╝

class _DriverTodaysRoutesTab extends StatefulWidget {
  final String? driverRecordId;
  final bool isDemoDriver;

  const _DriverTodaysRoutesTab({
    super.key,
    required this.driverRecordId,
    this.isDemoDriver = false,
  });

  @override
  State<_DriverTodaysRoutesTab> createState() => _DriverTodaysRoutesTabState();
}

class _DriverTodaysRoutesTabState extends State<_DriverTodaysRoutesTab> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _routes = [];
  bool _isLoading = true;
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _loadRoutes();
    _setupRealtime();
  }

  @override
  void didUpdateWidget(covariant _DriverTodaysRoutesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.driverRecordId != widget.driverRecordId ||
        oldWidget.isDemoDriver != widget.isDemoDriver) {
      _loadRoutes();
    }
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  void _setupRealtime() {
    _realtimeChannel = _supabase
        .channel('driver-todays-routes-rt')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'delivery_routes',
          callback: (_) {
            if (mounted) _loadRoutes();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'route_stops',
          callback: (_) {
            if (mounted) _loadRoutes();
          },
        )
        .subscribe();
  }

  Future<void> _loadRoutes() async {
    if (widget.driverRecordId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day).toUtc().toIso8601String();
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59).toUtc().toIso8601String();

      var routesQuery = _supabase
          .from('delivery_routes')
          .select('''
            *,
            route_stops(
              id, sequence_number, status, type, actual_arrival_time,
              orders(id, customer_name, customer_street, customer_city, total_price, payment_method, order_type_name, public_reference)
            )
          ''')
          .eq('assigned_driver_id', widget.driverRecordId!)
          .gte('created_at', startOfDay)
          .lte('created_at', endOfDay);

      if (widget.isDemoDriver) {
        routesQuery = routesQuery.eq('is_demo', true);
      } else {
        routesQuery = routesQuery.eq('is_demo', false);
      }

      final response = await routesQuery.order('created_at', ascending: false);

      final allRoutes = List<Map<String, dynamic>>.from(response as List);
      // Only show valid routes with customer stops (exclude cancelled ghost routes)
      final validRoutes = allRoutes.where((r) {
        final stops = (r['route_stops'] as List?) ?? [];
        return stops.any((s) => s['type'] == 'customer_delivery');
      }).toList();

      if (mounted) {
        setState(() {
          _routes = validRoutes;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[DriverTodaysRoutesTab] Error loading routes: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '--:--';
    final local = dt.isUtc ? dt.toLocal() : dt;
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: _DriverTheme.accent));
    }

    // Analytics summary
    int totalDeliveredStops = 0;
    int totalActualMinutes = 0;

    for (final r in _routes) {
      final stops = (r['route_stops'] as List?) ?? [];
      totalDeliveredStops += stops.where((s) => s['status'] == 'completed' || s['status'] == 'delivered').length;

      final startedAt = DateTime.tryParse(r['started_at'] as String? ?? '');
      final completedAt = DateTime.tryParse(r['completed_at'] as String? ?? '') ??
          DateTime.tryParse(r['actual_return_at'] as String? ?? '');
      if (startedAt != null && completedAt != null) {
        totalActualMinutes += completedAt.difference(startedAt).inMinutes;
      }
    }

    return RefreshIndicator(
      onRefresh: _loadRoutes,
      color: _DriverTheme.accent,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Header Stats
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _DriverTheme.divider),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _buildSummaryItem(
                    icon: Icons.alt_route_rounded,
                    label: 'Tours Today',
                    value: '${_routes.length}',
                    color: _DriverTheme.accent,
                  ),
                  Container(width: 1, height: 36, color: _DriverTheme.divider),
                  _buildSummaryItem(
                    icon: Icons.check_circle_outline_rounded,
                    label: 'Delivered',
                    value: '$totalDeliveredStops',
                    color: _DriverTheme.success,
                  ),
                  Container(width: 1, height: 36, color: _DriverTheme.divider),
                  _buildSummaryItem(
                    icon: Icons.timer_outlined,
                    label: 'Time on Road',
                    value: totalActualMinutes >= 60
                        ? '${totalActualMinutes ~/ 60}h ${totalActualMinutes % 60}m'
                        : '${totalActualMinutes}m',
                    color: const Color(0xFF8B5CF6),
                  ),
                ],
              ),
            ),
          ),

          if (_routes.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF3F4F6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.alt_route_rounded, size: 48, color: _DriverTheme.textMuted),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No Tours Yet Today',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _DriverTheme.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Routes you complete today will appear here\nwith planned vs. actual time analytics.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: _DriverTheme.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final route = _routes[index];
                    return _buildRouteSummaryCard(route, _routes.length - index);
                  },
                  childCount: _routes.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(
                value,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _DriverTheme.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: _DriverTheme.textMuted, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildRouteSummaryCard(Map<String, dynamic> route, int tourNumber) {
    final status = route['status'] as String? ?? 'assigned';
    final isCompleted = status == 'completed';
    final isInProgress = status == 'in_progress';

    final distMeters = (route['total_estimated_distance_meters'] as num?)?.toDouble() ?? 0.0;
    final durSecs = (route['total_estimated_duration_seconds'] as num?)?.toDouble() ?? 0.0;
    final estMinutes = (durSecs / 60).round();
    final distKmStr = (distMeters / 1000).toStringAsFixed(1);

    final startedAt = DateTime.tryParse(route['started_at'] as String? ?? '');
    final completedAt = DateTime.tryParse(route['completed_at'] as String? ?? '') ??
        DateTime.tryParse(route['actual_return_at'] as String? ?? '');

    int? actualMinutes;
    String actualTimeDisplay = 'Not started';
    Color actualTimeColor = _DriverTheme.textMuted;
    String? diffText;
    Color? diffColor;

    if (startedAt != null) {
      if (completedAt != null) {
        actualMinutes = completedAt.difference(startedAt).inMinutes;
        actualTimeDisplay = '$actualMinutes Min';
        actualTimeColor = _DriverTheme.textPrimary;

        if (estMinutes > 0) {
          final diff = actualMinutes - estMinutes;
          if (diff <= 0) {
            diffText = '${-diff}m faster';
            diffColor = _DriverTheme.success;
          } else {
            diffText = '+$diff m slower';
            diffColor = _DriverTheme.danger;
          }
        }
      } else if (isInProgress) {
        final elapsed = DateTime.now().difference(startedAt).inMinutes;
        actualTimeDisplay = '$elapsed Min (active)';
        actualTimeColor = _DriverTheme.accent;
      }
    }

    final stops = (route['route_stops'] as List?)
            ?.map((s) => Map<String, dynamic>.from(s as Map))
            .where((s) => s['type'] == 'customer_delivery')
            .toList() ??
        [];

    final deliveredStopsCount = stops.where((s) => s['status'] == 'completed' || s['status'] == 'delivered').length;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isInProgress ? _DriverTheme.accent.withOpacity(0.5) : _DriverTheme.divider,
          width: isInProgress ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: isInProgress,
          tilePadding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Tour #$tourNumber',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _DriverTheme.textPrimary),
                ),
              ),
              if (startedAt != null) ...[
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '${_formatTime(startedAt)} – ${_formatTime(completedAt)}',
                    style: const TextStyle(fontSize: 11, color: _DriverTheme.textMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              const Spacer(),
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: isCompleted
                      ? const Color(0xFFECFDF5)
                      : isInProgress
                          ? const Color(0xFFEEF2FF)
                          : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isCompleted
                        ? const Color(0xFFA7F3D0)
                        : isInProgress
                            ? const Color(0xFFC7D2FE)
                            : const Color(0xFFFDE68A),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isCompleted
                          ? Icons.check_circle_rounded
                          : isInProgress
                              ? Icons.navigation_rounded
                              : Icons.schedule_rounded,
                      size: 12,
                      color: isCompleted
                          ? const Color(0xFF059669)
                          : isInProgress
                              ? const Color(0xFF4F46E5)
                              : const Color(0xFFD97706),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isCompleted
                          ? 'Completed'
                          : isInProgress
                              ? 'In Progress'
                              : 'Assigned',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isCompleted
                            ? const Color(0xFF059669)
                            : isInProgress
                                ? const Color(0xFF4F46E5)
                                : const Color(0xFFD97706),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Column(
              children: [
                // Prominent Time vs Actual Needed Comparison
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _DriverTheme.divider),
                  ),
                  child: Row(
                    children: [
                      // Estimated Time
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.schedule_rounded, size: 14, color: _DriverTheme.textMuted),
                                SizedBox(width: 4),
                                Text(
                                  'ESTIMATED',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _DriverTheme.textMuted, letterSpacing: 0.5),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              estMinutes > 0 ? '$estMinutes Min' : '-- Min',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _DriverTheme.textPrimary),
                            ),
                            if (distMeters > 0)
                              Text('$distKmStr km round trip', style: const TextStyle(fontSize: 11, color: _DriverTheme.textMuted)),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 42, color: _DriverTheme.divider),
                      const SizedBox(width: 12),
                      // Actual Time Needed
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.timer_rounded, size: 14, color: Color(0xFF4F46E5)),
                                SizedBox(width: 4),
                                Text(
                                  'ACTUAL NEEDED',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF4F46E5), letterSpacing: 0.5),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  actualTimeDisplay,
                                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: actualTimeColor),
                                ),
                                if (diffText != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: diffColor!.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      diffText,
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: diffColor),
                                    ),
                                  ),
                              ],
                            ),
                            Text(
                              '$deliveredStopsCount of ${stops.length} orders delivered',
                              style: const TextStyle(fontSize: 11, color: _DriverTheme.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          children: [
            const Divider(height: 16, color: _DriverTheme.divider),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Orders in this tour (${stops.length})',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _DriverTheme.textSecondary),
              ),
            ),
            const SizedBox(height: 8),
            ...stops.map((stop) {
              final o = stop['orders'] as Map<String, dynamic>?;
              final name = o?['customer_name'] as String? ?? 'Customer';
              final street = o?['customer_street'] as String? ?? '';
              final city = o?['customer_city'] as String? ?? '';
              final price = (o?['total_price'] as num?)?.toDouble();
              final payMethod = (o?['payment_method'] as String?)?.toLowerCase() ?? '';
              final isCash = payMethod.contains('cash');
              final isStopDelivered = stop['status'] == 'completed' || stop['status'] == 'delivered';

              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isStopDelivered ? const Color(0xFFF9FAFB) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: isStopDelivered ? const Color(0xFFECFDF5) : const Color(0xFFF3F4F6),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: isStopDelivered
                            ? const Icon(Icons.check, size: 14, color: Color(0xFF059669))
                            : Text('${stop['sequence_number'] ?? ''}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _DriverTheme.textSecondary)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isStopDelivered ? Colors.grey[500] : _DriverTheme.textPrimary,
                              decoration: isStopDelivered ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          if (street.isNotEmpty)
                            Text(
                              '$street${city.isNotEmpty ? ', $city' : ''}',
                              style: const TextStyle(fontSize: 11, color: _DriverTheme.textMuted),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    if (price != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isCash ? const Color(0xFFECFDF5) : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${isCash ? 'Cash ' : ''}€${price.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isCash ? const Color(0xFF059669) : _DriverTheme.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ╔══════════════════════════════════════════════════════════════════╗
// ║  DRIVER ROUTE TAB — Premium redesign                          ║
// ╚══════════════════════════════════════════════════════════════════╝

class _DriverRouteTab extends StatefulWidget {
  final String? driverRecordId;
  final bool isOnline;
  final bool isDemoDriver;

  const _DriverRouteTab({
    super.key,
    required this.driverRecordId,
    required this.isOnline,
    this.isDemoDriver = false,
  });

  @override
  State<_DriverRouteTab> createState() => _DriverRouteTabState();
}

class _DriverRouteTabState extends State<_DriverRouteTab> with TickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _stops = [];
  Map<String, dynamic>? _activeRoute;
  bool _isLoading = true;
  bool _isMarkingDelivered = false;
  bool _isStartingRoute = false;
  bool _isCompletingRoute = false;
  RealtimeChannel? _routeChannel;
  Timer? _pollTimer;
  bool _isFetchingRoute = false;

  // Order items cache: orderId -> list of items
  Map<String, List<Map<String, dynamic>>> _orderItems = {};

  Future<void> reload() => _loadRoute(silent: false);

  @override
  void initState() {
    super.initState();
    _loadRoute();
    _setupRealtime();
    _startPolling();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      // When no active route, actively check every 2 seconds for newly assigned route!
      // When active route exists, check every 8 seconds to stay synchronized.
      if (_activeRoute == null) {
        _loadRoute(silent: true);
      } else if (timer.tick % 4 == 0) {
        _loadRoute(silent: true);
      }
    });
  }

  @override
  void didUpdateWidget(covariant _DriverRouteTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.driverRecordId != widget.driverRecordId ||
        oldWidget.isOnline != widget.isOnline) {
      _loadRoute();
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _pollTimer = null;
    if (_routeChannel != null) {
      _supabase.removeChannel(_routeChannel!);
      _routeChannel = null;
    }
    super.dispose();
  }

  void _setupRealtime() {
    if (_routeChannel != null) {
      _supabase.removeChannel(_routeChannel!);
    }
    final channelName = 'driver-route-${widget.driverRecordId ?? "all"}-${DateTime.now().millisecondsSinceEpoch}';
    _routeChannel = _supabase
        .channel(channelName)
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'delivery_routes',
          callback: (_) {
            if (mounted) _loadRoute(silent: true);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'route_stops',
          callback: (_) {
            if (mounted) _loadRoute(silent: true);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          callback: (_) {
            if (mounted) _loadRoute(silent: true);
          },
        )
        .subscribe();
  }

  Future<void> _loadRoute({bool silent = false}) async {
    if (widget.driverRecordId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    if (_isFetchingRoute) return;
    _isFetchingRoute = true;

    if (!silent && mounted) {
      setState(() => _isLoading = true);
    }

    try {
      var routeQuery = _supabase
          .from('delivery_routes')
          .select('*')
          .eq('assigned_driver_id', widget.driverRecordId!)
          .inFilter('status', ['assigned', 'in_progress']);

      if (widget.isDemoDriver) {
        routeQuery = routeQuery.eq('is_demo', true);
      } else {
        routeQuery = routeQuery.eq('is_demo', false);
      }

      final routeResponse = await routeQuery
          .order('status', ascending: false) // 'in_progress' comes before 'assigned'
          .order('created_at', ascending: false)
          .limit(1);

      final routeList = routeResponse as List;
      if (routeList.isEmpty) {
        if (mounted) {
          if (_activeRoute != null || !silent || _isLoading) {
            setState(() {
              _activeRoute = null;
              _stops = [];
              _orderItems = {};
              _isLoading = false;
            });
          }
        }
        return;
      }

      final route = Map<String, dynamic>.from(routeList.first as Map);
      final routeId = route['id'] as String;

      // Fetch stops with full order data
      final stopsResponse = await _supabase
          .from('route_stops')
          .select('*, orders(id, created_at, customer_name, customer_street, customer_postcode, customer_city, customer_phone, delivery_notes, estimated_delivery_time, requested_delivery_time, planned_arrival_at, delivery_latitude, delivery_longitude, order_type_name, payment_method, total_price, public_reference, verification_code, note)')
          .eq('delivery_route_id', routeId)
          .order('sequence_number', ascending: true);

      final stops = (stopsResponse as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      // Fetch order items for all orders in this route
      final orderIds = stops
          .where((s) => s['order_id'] != null)
          .map((s) => s['order_id'] as String)
          .toList();

      Map<String, List<Map<String, dynamic>>> items = {};
      if (orderIds.isNotEmpty) {
        try {
          final itemsResponse = await _supabase
              .from('order_items')
              .select('*')
              .inFilter('order_id', orderIds)
              .order('id');

          for (final item in (itemsResponse as List)) {
            final oid = item['order_id'] as String;
            items.putIfAbsent(oid, () => []);
            items[oid]!.add(Map<String, dynamic>.from(item as Map));
          }
        } catch (e) {
          debugPrint('[DriverRouteTab] Failed to load order items: $e');
        }
      }

      if (mounted) {
        setState(() {
          _activeRoute = route;
          _stops = stops;
          _orderItems = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[DriverRouteTab] Error loading route: $e');
      // Fallback without joins
      try {
        final routeResponse = await _supabase
            .from('delivery_routes')
            .select('*')
            .eq('assigned_driver_id', widget.driverRecordId!)
            .inFilter('status', ['assigned', 'in_progress'])
            .order('created_at', ascending: false)
            .limit(1);

        final routeList = routeResponse as List;
        if (routeList.isEmpty) {
          if (mounted) setState(() { _activeRoute = null; _stops = []; _isLoading = false; });
          return;
        }

        final route = Map<String, dynamic>.from(routeList.first as Map);
        final routeId = route['id'] as String;

        final stopsResponse = await _supabase
            .from('route_stops')
            .select('*')
            .eq('delivery_route_id', routeId)
            .order('sequence_number', ascending: true);

        if (mounted) {
          setState(() {
            _activeRoute = route;
            _stops = (stopsResponse as List)
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
            _isLoading = false;
          });
        }
      } catch (e2) {
        debugPrint('[DriverRouteTab] Fallback also failed: $e2');
        if (mounted) setState(() => _isLoading = false);
      }
    } finally {
      _isFetchingRoute = false;
    }
  }

  Future<void> _startRoute() async {
    if (_activeRoute == null || _isStartingRoute) return;
    setState(() => _isStartingRoute = true);

    try {
      await _supabase
          .from('delivery_routes')
          .update({
            'status': 'in_progress',
            'started_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', _activeRoute!['id'] as String);

      // Update customer orders in this route to out_for_delivery & delivering
      final orderIds = _stops
          .map((s) => s['order_id'] as String?)
          .where((id) => id != null && id.isNotEmpty)
          .cast<String>()
          .toList();

      if (orderIds.isNotEmpty) {
        await _supabase
            .from('orders')
            .update({
              'delivery_status': 'out_for_delivery',
              'status': 'delivering',
            })
            .inFilter('id', orderIds);
      }

      HapticFeedback.heavyImpact();

      if (mounted) {
        setState(() {
          if (_activeRoute != null) {
            _activeRoute!['status'] = 'in_progress';
          }
          _isStartingRoute = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(children: [
              Icon(Icons.rocket_launch, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Route started! Let\'s go! 🚀'),
            ]),
            backgroundColor: _DriverTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }

      // Auto-navigate to first stop
      final customerStops = _stops.where((s) => s['type'] == 'customer_delivery').toList();
      if (customerStops.isNotEmpty) {
        final firstStop = customerStops.first;
        final order = firstStop['orders'] as Map<String, dynamic>?;
        final lat = (firstStop['latitude'] as num?)?.toDouble() ??
            (order?['delivery_latitude'] as num?)?.toDouble();
        final lng = (firstStop['longitude'] as num?)?.toDouble() ??
            (order?['delivery_longitude'] as num?)?.toDouble();
        if (lat != null && lng != null) {
          _openNavigation(lat, lng);
        }
      }

      await _loadRoute();
    } catch (e) {
      debugPrint('[DriverRouteTab] Error starting route: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start route: $e'), backgroundColor: _DriverTheme.danger, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        );
      }
    } finally {
      if (mounted) setState(() => _isStartingRoute = false);
    }
  }

  Future<void> _markDelivered(Map<String, dynamic> stop) async {
    if (_isMarkingDelivered) return;

    // Show confirmation dialog for cash orders
    final order = stop['orders'] as Map<String, dynamic>?;
    final paymentMethod = order?['payment_method'] as String?;
    final isCash = paymentMethod?.toLowerCase().contains('cash') ?? false;
    final totalPrice = (order?['total_price'] as num?)?.toDouble();

    if (isCash && totalPrice != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: _DriverTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.payments, color: _DriverTheme.cash, size: 24),
              SizedBox(width: 10),
              Text('Cash Payment', style: TextStyle(color: _DriverTheme.textPrimary, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Did you collect the cash payment?',
                style: TextStyle(color: _DriverTheme.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _DriverTheme.cash.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _DriverTheme.cash.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.euro, color: _DriverTheme.cash, size: 28),
                    const SizedBox(width: 4),
                    Text(
                      totalPrice.toStringAsFixed(2),
                      style: const TextStyle(
                        color: _DriverTheme.cash,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: _DriverTheme.textMuted)),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Cash Collected'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _DriverTheme.success,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    final stopId = stop['id'] as String;
    final orderId = stop['order_id'] as String?;

    // Optimistically update local UI immediately so the user sees instant feedback
    setState(() {
      _isMarkingDelivered = true;
      final idx = _stops.indexWhere((s) => s['id'] == stopId);
      if (idx != -1) {
        _stops[idx] = Map<String, dynamic>.from(_stops[idx])
          ..['status'] = 'completed';
      }
      if (_activeRoute != null && _activeRoute!['status'] == 'assigned') {
        _activeRoute!['status'] = 'in_progress';
      }
    });
    HapticFeedback.heavyImpact();

    try {
      Position? currentPos;
      try {
        currentPos = await Geolocator.getLastKnownPosition();
      } catch (_) {}

      try {
        await _supabase.functions.invoke(
          'mark-delivered',
          body: {
            'route_stop_id': stopId,
            'order_id': orderId,
            if (currentPos != null) ...{
              'driver_latitude': currentPos.latitude,
              'driver_longitude': currentPos.longitude,
            },
          },
        );
      } catch (edgeFnError) {
        debugPrint('[DriverRouteTab] Edge function failed, using direct DB update: $edgeFnError');

        await _supabase
            .from('route_stops')
            .update({
              'status': 'completed',
              'actual_arrival_time': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', stopId);

        if (orderId != null) {
          await _supabase
              .from('orders')
              .update({
                'delivery_status': 'delivered',
                'status': 'delivered',
                'actual_delivery_time': DateTime.now().toUtc().toIso8601String(),
              })
              .eq('id', orderId);
        }

        final remaining = _stops.where((s) =>
            s['type'] == 'customer_delivery' &&
            s['status'] != 'delivered' &&
            s['status'] != 'completed' &&
            s['id'] != stopId).toList();

        if (remaining.isEmpty && _activeRoute != null) {
          await _supabase
              .from('delivery_routes')
              .update({
                'actual_return_at': DateTime.now().toUtc().toIso8601String(),
              })
              .eq('id', _activeRoute!['id'] as String);
        }
      }

      // Calculate remaining stops after marking this one delivered
      final remaining = _stops.where((s) =>
          s['type'] == 'customer_delivery' &&
          s['status'] != 'delivered' &&
          s['status'] != 'completed' &&
          s['id'] != stopId).toList();

      if (mounted) {
        if (remaining.isEmpty) {
          // All done! Show celebration and automatically route back to restaurant
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(children: [
                Text('🎉', style: TextStyle(fontSize: 20)),
                SizedBox(width: 8),
                Expanded(
                  child: Text('All deliveries complete! Navigating back to restaurant...'),
                ),
              ]),
              backgroundColor: _DriverTheme.success,
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );

          // Find store / restaurant depot coordinates
          double? storeLat = (_activeRoute?['store_latitude'] as num?)?.toDouble();
          double? storeLng = (_activeRoute?['store_longitude'] as num?)?.toDouble();

          if (storeLat == null || storeLng == null) {
            final storeStop = _stops.firstWhere(
              (s) => s['type'] == 'store',
              orElse: () => <String, dynamic>{},
            );
            storeLat = (storeStop['latitude'] as num?)?.toDouble();
            storeLng = (storeStop['longitude'] as num?)?.toDouble();
          }

          // Fallback to default restaurant coordinates if not specified
          storeLat ??= 47.81328;
          storeLng ??= 13.06882;

          await Future.delayed(const Duration(seconds: 1));
          _openNavigation(storeLat, storeLng);
        } else {
          // Navigate to next stop
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text('Delivered! ${remaining.length} stop${remaining.length == 1 ? '' : 's'} left'),
              ]),
              backgroundColor: _DriverTheme.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );

          // Auto-navigate to next undelivered stop
          final nextStop = remaining.first;
          final nextOrder = nextStop['orders'] as Map<String, dynamic>?;
          final lat = (nextStop['latitude'] as num?)?.toDouble() ??
              (nextOrder?['delivery_latitude'] as num?)?.toDouble();
          final lng = (nextStop['longitude'] as num?)?.toDouble() ??
              (nextOrder?['delivery_longitude'] as num?)?.toDouble();
          if (lat != null && lng != null) {
            await Future.delayed(const Duration(seconds: 1));
            _openNavigation(lat, lng);
          }
        }
      }

      await _loadRoute();
    } catch (e) {
      debugPrint('[DriverRouteTab] Error marking delivered: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to mark delivered: $e'), backgroundColor: _DriverTheme.danger, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        );
      }
    } finally {
      if (mounted) setState(() => _isMarkingDelivered = false);
    }
  }

  Future<void> _markBackAtRestaurant() async {
    if (_activeRoute == null || _isCompletingRoute) return;
    setState(() => _isCompletingRoute = true);

    try {
      final routeId = _activeRoute!['id'] as String;

      HapticFeedback.heavyImpact();

      // Immediately clear local active route state so driver sees instant transition
      if (mounted) {
        setState(() {
          _activeRoute = null;
          _stops = [];
          _isCompletingRoute = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(children: [
              Text('🏠', style: TextStyle(fontSize: 20)),
              SizedBox(width: 8),
              Text('Welcome back! Route completed. 🎉'),
            ]),
            backgroundColor: _DriverTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }

      // Trigger plan-routes and let the Edge Function handle the route completion
      // to bypass RLS issues securely.
      try {
        await _supabase.functions.invoke('plan-routes', body: {
          'trigger_reason': 'driver_back_at_restaurant',
          'complete_route_id': routeId,
          'complete_driver_id': widget.driverRecordId,
        });
      } catch (e) {
        debugPrint('[DriverRouteTab] Error invoking plan-routes on return: $e');
      }

      // Reload route in case a new tour was auto-planned
      await _loadRoute();
    } catch (e) {
      debugPrint('[DriverRouteTab] Error marking back: $e');
      if (mounted) {
        setState(() => _isCompletingRoute = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: _DriverTheme.danger, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        );
      }
    }
  }

  void _openNavigation(double lat, double lng) async {
    final googleMapsAppUrl = Uri.parse('comgooglemaps://?daddr=$lat,$lng&directionsmode=driving');
    final googleNavUrl = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
    final googleWebUrl = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');

    try {
      if (Platform.isIOS) {
        // Try opening native Google Maps iOS app first
        if (await canLaunchUrl(googleMapsAppUrl)) {
          await launchUrl(googleMapsAppUrl, mode: LaunchMode.externalApplication);
          return;
        }
      } else if (Platform.isAndroid) {
        if (await canLaunchUrl(googleNavUrl)) {
          await launchUrl(googleNavUrl, mode: LaunchMode.externalApplication);
          return;
        }
      }

      // Always open Google Maps (opens Google Maps App or browser fallback)
      await launchUrl(googleWebUrl, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('[DriverRouteTab] Error opening navigation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open navigation: $e'), backgroundColor: _DriverTheme.warning, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isOnline) {
      return _buildOfflineState();
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: _DriverTheme.accent));
    }

    if (_activeRoute == null || _stops.isEmpty) {
      return _buildEmptyState();
    }

    final customerStops = _stops.where((s) => s['type'] == 'customer_delivery').toList();
    final deliveredCount = customerStops.where((s) => s['status'] == 'delivered' || s['status'] == 'completed').length;
    final totalStops = customerStops.length;
    final routeStatus = _activeRoute!['status'] as String? ?? 'assigned';
    final allDelivered = deliveredCount >= totalStops;

    return RefreshIndicator(
      onRefresh: _loadRoute,
      color: _DriverTheme.accent,
      backgroundColor: _DriverTheme.surface,
      child: CustomScrollView(
        slivers: [
          // Route progress header
          SliverToBoxAdapter(
            child: _buildRouteHeader(routeStatus, deliveredCount, totalStops, allDelivered),
          ),

          // Start Route / Back at Restaurant button
          if (routeStatus == 'assigned')
            SliverToBoxAdapter(child: _buildStartRouteButton())
          else if (allDelivered)
            SliverToBoxAdapter(child: _buildBackAtRestaurantButton()),

          // Stops list
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final stop = customerStops[index];
                  return _buildTimelineStopRow(stop, index, customerStops);
                },
                childCount: customerStops.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  (double distanceMeters, double durationSecs) _getRouteDistanceAndDuration() {
    double dist = (_activeRoute?['total_estimated_distance_meters'] as num?)?.toDouble() ?? 0.0;
    double dur = (_activeRoute?['total_estimated_duration_seconds'] as num?)?.toDouble() ?? 0.0;

    final customerStops = _stops.where((s) => s['type'] == 'customer_delivery').toList();
    if (dist <= 0 && customerStops.isNotEmpty) {
      final storeLat = (_activeRoute?['store_latitude'] as num?)?.toDouble() ?? 47.81328;
      final storeLng = (_activeRoute?['store_longitude'] as num?)?.toDouble() ?? 13.06882;
      double calcDist = 0.0;
      double prevLat = storeLat;
      double prevLng = storeLng;

      for (final s in customerStops) {
        final o = s['orders'] as Map<String, dynamic>?;
        final sLat = (s['latitude'] as num?)?.toDouble() ?? (o?['delivery_latitude'] as num?)?.toDouble();
        final sLng = (s['longitude'] as num?)?.toDouble() ?? (o?['delivery_longitude'] as num?)?.toDouble();
        if (sLat != null && sLng != null) {
          calcDist += _haversineDistanceMeters(prevLat, prevLng, sLat, sLng);
          prevLat = sLat;
          prevLng = sLng;
        }
      }
      // Return leg back to restaurant depot
      calcDist += _haversineDistanceMeters(prevLat, prevLng, storeLat, storeLng);
      dist = calcDist * 1.35; // City driving factor
      if (dur <= 0) {
        dur = (dist / 1000 / 25 * 3600) + (customerStops.length * 300);
      }
    }

    return (dist, dur);
  }

  double _haversineDistanceMeters(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final dLat = (lat2 - lat1) * (math.pi / 180.0);
    final dLon = (lon2 - lon1) * (math.pi / 180.0);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * (math.pi / 180.0)) * math.cos(lat2 * (math.pi / 180.0)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  Widget _buildRouteHeader(String status, int delivered, int total, bool allDone) {
    final progress = total > 0 ? delivered / total : 0.0;
    final (distMeters, totalDurSecs) = _getRouteDistanceAndDuration();
    
    double durSecs = totalDurSecs;
    if (status == 'in_progress' || allDone) {
      durSecs = 0;
      for (final s in _stops) {
        if (s['status'] == 'pending') {
          durSecs += (s['estimated_travel_time_to_next_stop_seconds'] as num?)?.toDouble() ?? 0.0;
          if (s['type'] == 'customer_delivery') {
            durSecs += (s['estimated_service_time_seconds'] as num?)?.toDouble() ?? 0.0;
          }
        }
      }
    }
    
    final distKmStr = (distMeters / 1000).toStringAsFixed(1);
    final durMin = (durSecs / 60).round();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _DriverTheme.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  allDone
                      ? 'All Delivered! 🎉'
                      : status == 'in_progress'
                          ? 'Active Tour • $delivered of $total'
                          : 'Tour Ready • $total Orders',
                  style: const TextStyle(
                    color: _DriverTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                status == 'in_progress' || allDone
                    ? 'ca. $durMin Min left'
                    : '$distKmStr km • ca. $durMin Min',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _DriverTheme.textMuted,
                ),
              ),
            ],
          ),
          if (status == 'in_progress' || allDone) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: const Color(0xFFF3F4F6),
                valueColor: AlwaysStoppedAnimation(allDone ? _DriverTheme.success : _DriverTheme.accent),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStartRouteButton() {
    final (distMeters, durSecs) = _getRouteDistanceAndDuration();
    final distKmStr = (distMeters / 1000).toStringAsFixed(1);
    final durMin = (durSecs / 60).round();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: SizedBox(
        width: double.infinity,
        height: 46,
        child: ElevatedButton.icon(
          onPressed: _isStartingRoute ? null : _startRoute,
          icon: _isStartingRoute
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.navigation_rounded, size: 20),
          label: Text(
            distMeters > 0 ? 'Start Tour • $distKmStr km (ca. $durMin Min)' : 'Start Tour',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _DriverTheme.accent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
        ),
      ),
    );
  }

  Widget _buildBackAtRestaurantButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          onPressed: _isCompletingRoute ? null : _markBackAtRestaurant,
          icon: _isCompletingRoute
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.storefront_rounded, size: 20),
          label: Text(
            _isCompletingRoute ? 'Completing Tour...' : 'Back at Restaurant (Complete Tour)',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _DriverTheme.success,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
        ),
      ),
    );
  }

  (DateTime, int, DateTime) _getStopTimeline(
    Map<String, dynamic> stop,
    int index,
    List<Map<String, dynamic>> allCustomerStops,
  ) {
    final routeDepStr = _activeRoute?['actual_departure_at'] as String? ??
        _activeRoute?['planned_departure_at'] as String?;
    final routeDepTime = DateTime.tryParse(routeDepStr ?? '')?.toLocal() ?? DateTime.now();

    final arrivalStr = stop['planned_arrival_at'] as String? ??
        stop['estimated_arrival_time'] as String?;
    DateTime arrival = DateTime.tryParse(arrivalStr ?? '')?.toLocal() ??
        routeDepTime.add(Duration(minutes: (index + 1) * 12));

    DateTime start;
    if (index == 0) {
      start = routeDepTime;
    } else {
      final prevStop = allCustomerStops[index - 1];
      final prevArrivalStr = prevStop['planned_arrival_at'] as String? ??
          prevStop['estimated_arrival_time'] as String?;
      final prevArrival = DateTime.tryParse(prevArrivalStr ?? '')?.toLocal() ??
          routeDepTime.add(Duration(minutes: index * 12));
      start = prevArrival.add(const Duration(minutes: 5));
    }

    if (arrival.isBefore(start) || arrival.isAtSameMomentAs(start)) {
      arrival = start.add(const Duration(minutes: 10));
    }

    int durationMin = arrival.difference(start).inMinutes;
    if (durationMin <= 0) durationMin = 5;

    return (start, durationMin, arrival);
  }

  Widget _buildTimelineStopRow(
    Map<String, dynamic> stop,
    int index,
    List<Map<String, dynamic>> allCustomerStops,
  ) {
    final (startTime, durationMin, arrivalTime) = _getStopTimeline(stop, index, allCustomerStops);
    final isDelivered = stop['status'] == 'delivered' || stop['status'] == 'completed';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Timeline: Start time, Duration of trip, Estimated arrival time
          SizedBox(
            width: 52,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 12),
                Text(
                  _formatTime(startTime),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDelivered ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563),
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  width: 1.5,
                  height: 12,
                  color: isDelivered ? const Color(0xFFE5E7EB) : const Color(0xFFD1D5DB),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: isDelivered ? const Color(0xFFF3F4F6) : const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '$durationMin min',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: isDelivered ? const Color(0xFF9CA3AF) : const Color(0xFF4F46E5),
                    ),
                  ),
                ),
                Container(
                  width: 1.5,
                  height: 12,
                  color: isDelivered ? const Color(0xFFE5E7EB) : const Color(0xFFD1D5DB),
                ),
                const SizedBox(height: 3),
                Text(
                  _formatTime(arrivalTime),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isDelivered ? const Color(0xFF9CA3AF) : const Color(0xFF1E3A8A),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // The Order Card
          Expanded(
            child: _buildStopCard(stop, index, allCustomerStops, arrivalTime),
          ),
        ],
      ),
    );
  }

  Widget _buildStopCard(
    Map<String, dynamic> stop,
    int index,
    List<Map<String, dynamic>> allStops,
    DateTime calculatedArrival,
  ) {
    final isDelivered = stop['status'] == 'delivered' || stop['status'] == 'completed';
    final order = stop['orders'] as Map<String, dynamic>?;
    final customerName = order?['customer_name'] as String? ??
        stop['customer_name'] as String? ?? 'Customer';
    final customerAddress = order?['customer_address'] as String? ??
        order?['customer_street'] as String? ??
        stop['customer_address'] as String? ?? '';
    final customerCity = order?['customer_city'] as String? ?? '';
    final customerPhone = order?['customer_phone'] as String?;
    final orderType = order?['order_type_name'] as String?;

    final lat = (stop['latitude'] as num?)?.toDouble() ??
        (order?['delivery_latitude'] as num?)?.toDouble();
    final lng = (stop['longitude'] as num?)?.toDouble() ??
        (order?['delivery_longitude'] as num?)?.toDouble();

    // 1. When order was received time
    final orderCreatedAt = DateTime.tryParse(order?['created_at'] as String? ?? '');
    final receivedStr = orderCreatedAt != null ? _formatTime(orderCreatedAt.toLocal()) : '--:--';

    // 2. Estimated delivery time given by us (customer promise)
    final promisedDelivery = DateTime.tryParse(order?['estimated_delivery_time'] as String? ??
        order?['requested_delivery_time'] as String? ?? '');
    final promisedStr = promisedDelivery != null ? _formatTime(promisedDelivery.toLocal()) : '--:--';

    // 3. Target time by delivery route manager
    final routeTarget = DateTime.tryParse(stop['planned_arrival_at'] as String? ??
        stop['estimated_arrival_time'] as String? ??
        order?['planned_arrival_at'] as String? ?? '')?.toLocal() ?? calculatedArrival;
    final routeTargetStr = _formatTime(routeTarget);

    final firstUndeliveredIdx = allStops.indexWhere((s) =>
        s['status'] != 'delivered' && s['status'] != 'completed');
    final isCurrentStop = index == firstUndeliveredIdx;

    return Container(
      decoration: BoxDecoration(
        color: isDelivered ? const Color(0xFFF9FAFB) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDelivered
              ? const Color(0xFFE5E7EB)
              : (isCurrentStop ? _DriverTheme.accent : const Color(0xFFE5E7EB)),
          width: isCurrentStop && !isDelivered ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Row: Stop Number, Customer Name, Platform Tag, Delivered status
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: isDelivered
                      ? const Color(0xFFECFDF5)
                      : (isCurrentStop ? _DriverTheme.accent : const Color(0xFFF3F4F6)),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isDelivered
                      ? const Icon(Icons.check, size: 13, color: Color(0xFF059669))
                      : Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: isCurrentStop ? Colors.white : _DriverTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  customerName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDelivered ? Colors.grey[400] : const Color(0xFF111827),
                    decoration: isDelivered ? TextDecoration.lineThrough : null,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (orderType != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _platformColor(orderType).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    orderType,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _platformColor(orderType),
                    ),
                  ),
                ),
              ],
              if (isDelivered) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Delivered',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),

          // Address Row: Clean, readable, with one-tap copy
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: '$customerAddress${customerCity.isNotEmpty ? ', $customerCity' : ''}'));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Address copied!'), duration: Duration(seconds: 1)),
              );
            },
            borderRadius: BorderRadius.circular(6),
            child: Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 15, color: _DriverTheme.textMuted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '$customerAddress${customerCity.isNotEmpty ? ', $customerCity' : ''}',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDelivered ? Colors.grey[400] : const Color(0xFF374151),
                      decoration: isDelivered ? TextDecoration.lineThrough : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.copy, size: 13, color: Colors.grey),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // 3 Key Times: Received, Target (Us), Route ETA
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFF3F4F6)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTimeItem('Received', receivedStr),
                Container(width: 1, height: 22, color: const Color(0xFFE5E7EB)),
                _buildTimeItem('Target (Us)', promisedStr),
                Container(width: 1, height: 22, color: const Color(0xFFE5E7EB)),
                _buildTimeItem('Route ETA', routeTargetStr),
              ],
            ),
          ),

          // Action buttons: Navigate, Call, Delivered
          if (!isDelivered) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: ElevatedButton.icon(
                      onPressed: (lat != null && lng != null) ? () => _openNavigation(lat, lng) : null,
                      icon: const Icon(Icons.navigation_rounded, size: 14),
                      label: const Text('Navigate', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ),
                if (customerPhone != null && customerPhone.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  SizedBox(
                    height: 36,
                    child: OutlinedButton.icon(
                      onPressed: () => launchUrl(Uri.parse('tel:$customerPhone')),
                      icon: const Icon(Icons.phone, size: 14),
                      label: const Text('Call', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF059669),
                        side: const BorderSide(color: Color(0xFFA7F3D0)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 6),
                SizedBox(
                  height: 36,
                  child: ElevatedButton.icon(
                    onPressed: _isMarkingDelivered ? null : () => _markDelivered(stop),
                    icon: _isMarkingDelivered
                        ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_circle_rounded, size: 14),
                    label: const Text('Delivered', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimeItem(String label, String time) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 1),
        Text(
          time,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1F2937),
          ),
        ),
      ],
    );
  }

  Widget _buildOfflineState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _DriverTheme.surfaceLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.wifi_off_rounded, size: 48, color: _DriverTheme.textMuted),
            ),
            const SizedBox(height: 24),
            const Text(
              'You\'re Offline',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _DriverTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Toggle online to see your route',
              style: TextStyle(fontSize: 14, color: _DriverTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [_DriverTheme.accent.withOpacity(0.15), _DriverTheme.accent.withOpacity(0.03)],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delivery_dining_rounded, size: 56, color: _DriverTheme.accentLight),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Active Route',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _DriverTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Waiting for new deliveries...\nRoutes are assigned automatically.',
              style: TextStyle(fontSize: 14, color: _DriverTheme.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => _loadRoute(silent: false),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Refresh'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _DriverTheme.accent,
                side: BorderSide(color: _DriverTheme.accent.withOpacity(0.3)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
            if (widget.isDemoDriver) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () async {
                  setState(() => _isLoading = true);
                  try {
                    final res = await DemoOrderService.createDemoOrder();
                    if (mounted) {
                      final order = res['order'];
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('⚡ Demo Order Added: ${order?['customer_name'] ?? 'Order'} (60m ETA)'),
                          backgroundColor: _DriverTheme.accent,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                    await _loadRoute();
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e'), backgroundColor: _DriverTheme.danger),
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _isLoading = false);
                  }
                },
                icon: const Icon(Icons.flash_on, color: Colors.amber, size: 18),
                label: const Text(
                  'Add Demo Order (60 Min ETA)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.withOpacity(0.18),
                  foregroundColor: Colors.amber,
                  side: const BorderSide(color: Colors.amber, width: 1.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _platformColor(String platform) {
    switch (platform.toLowerCase()) {
      case 'lieferando':
        return const Color(0xFFFF8000);
      case 'foodora':
        return const Color(0xFFD70F64);
      default:
        return _DriverTheme.accent;
    }
  }

  String _formatTime(DateTime dt) {
    final local = dt.isUtc ? dt.toLocal() : dt;
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

// ╔══════════════════════════════════════════════════════════════════╗
// ║  DRIVER SHIFTS TAB                                            ║
// ╚══════════════════════════════════════════════════════════════════╝

class _DriverShiftsTab extends StatefulWidget {
  final String? employeeId;
  final String driverName;

  const _DriverShiftsTab({super.key, required this.employeeId, required this.driverName});

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

    return Column(
      children: [
        // Earnings card
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _DriverTheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _DriverTheme.divider),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isWeeklyView ? 'This Week' : (_isToday ? 'Today' : _formatDisplayDate(_selectedDate)),
                      style: const TextStyle(color: _DriverTheme.textMuted, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '€${totalWage.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: _DriverTheme.success),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _DriverTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${totalHours}h ${totalMins}m',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: _DriverTheme.textSecondary, fontSize: 14),
                ),
              ),
            ],
          ),
        ),

        // Navigation
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // Toggle
              Container(
                decoration: BoxDecoration(
                  color: _DriverTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(10),
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
              // Date navigation
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 24),
                onPressed: _previousPeriod,
                color: _DriverTheme.textSecondary,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              GestureDetector(
                onTap: _goToToday,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _isToday && !_isWeeklyView ? _DriverTheme.accent : _DriverTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _isWeeklyView ? _getWeekRangeText() : (_isToday ? 'Today' : '${_selectedDate.day}/${_selectedDate.month}'),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _isToday && !_isWeeklyView ? Colors.white : _DriverTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 24),
                onPressed: _nextPeriod,
                color: _DriverTheme.textSecondary,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Shifts list
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: _DriverTheme.accent, strokeWidth: 2))
              : widget.employeeId == null
                  ? _buildNoEmployeeState()
                  : _shifts.isEmpty
                      ? _buildEmptyState()
                      : _isWeeklyView
                          ? _buildWeeklyView()
                          : _buildDayView(),
        ),
      ],
    );
  }

  String _getWeekRangeText() {
    final tuesday = _selectedDate.subtract(Duration(days: (_selectedDate.weekday - 2 + 7) % 7));
    final monday = tuesday.add(const Duration(days: 6));
    return '${tuesday.day}/${tuesday.month} - ${monday.day}/${monday.month}';
  }

  Widget _buildViewToggle(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _DriverTheme.accent.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? _DriverTheme.accent : _DriverTheme.textMuted,
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
          Icon(Icons.person_off_outlined, size: 40, color: _DriverTheme.textMuted),
          const SizedBox(height: 12),
          const Text('Not set up', style: TextStyle(fontSize: 15, color: _DriverTheme.textSecondary)),
          const SizedBox(height: 4),
          const Text('Contact your manager', style: TextStyle(fontSize: 13, color: _DriverTheme.textMuted)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_available_outlined, size: 40, color: _DriverTheme.textMuted),
          const SizedBox(height: 12),
          Text(
            _isWeeklyView ? 'No shifts this week' : 'No shifts today',
            style: const TextStyle(fontSize: 15, color: _DriverTheme.textSecondary),
          ),
          const SizedBox(height: 4),
          const Text('Enjoy your time off!', style: TextStyle(fontSize: 13, color: _DriverTheme.textMuted)),
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
            color: _DriverTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isTodayDate ? _DriverTheme.accent.withOpacity(0.3) : _DriverTheme.divider),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isTodayDate ? _DriverTheme.accent.withOpacity(0.08) : _DriverTheme.surfaceLight,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                ),
                child: Row(
                  children: [
                    Text(
                      _formatDisplayDate(date),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: isTodayDate ? _DriverTheme.accent : _DriverTheme.textSecondary,
                      ),
                    ),
                    if (isTodayDate) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: _DriverTheme.accent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('TODAY', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    ],
                    const Spacer(),
                    if (dayShifts.isNotEmpty)
                      Text('€${dayWage.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, color: _DriverTheme.success, fontSize: 13)),
                    if (dayShifts.isEmpty)
                      const Text('Off', style: TextStyle(color: _DriverTheme.textMuted, fontSize: 12)),
                  ],
                ),
              ),
              if (dayShifts.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: const Text('No shifts', style: TextStyle(color: _DriverTheme.textMuted, fontSize: 12)),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _DriverTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _DriverTheme.divider),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$startTime - $endTime',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _DriverTheme.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(duration, style: const TextStyle(fontSize: 12, color: _DriverTheme.textMuted)),
            ],
          ),
          const Spacer(),
          Text(
            '€${wage.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _DriverTheme.success),
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
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _DriverTheme.divider, width: 0.5)),
      ),
      child: Row(
        children: [
          Text(
            '$startTime - $endTime',
            style: const TextStyle(fontWeight: FontWeight.w500, color: _DriverTheme.textSecondary, fontSize: 13),
          ),
          const Spacer(),
          Text(
            '€${wage.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.w600, color: _DriverTheme.success, fontSize: 13),
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
