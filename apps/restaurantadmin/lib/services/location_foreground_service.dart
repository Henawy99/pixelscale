import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Supabase credentials - needed for background isolate
const String _supabaseUrl = 'https://bwuqjdkfvrbdrdhecbwk.supabase.co';
const String _supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ3dXFqZGtmdnJiZHJkaGVjYndrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzQ5NjcyMzcsImV4cCI6MjA1MDU0MzIzN30.hD_Mor7Z0NBXhSMBGT7vBhVd0aqN0-E0ewRjlKRoAxc';

/// This callback is called when the foreground task starts
/// It runs in an isolate, so we need to reinitialize Supabase
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(LocationTaskHandler());
}

/// The task handler that runs in the background
class LocationTaskHandler extends TaskHandler {
  StreamSubscription<Position>? _positionStream;
  Timer? _backupTimer;
  String? _driverRecordId;
  SupabaseClient? _supabaseClient;
  bool _isInitialized = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    debugPrint('[LocationTaskHandler] onStart called, starter: $starter');
    
    // Initialize Supabase in this isolate
    await _initSupabase();
    
    // Get driver record ID from storage
    _driverRecordId = await FlutterForegroundTask.getData(key: 'driverRecordId');
    debugPrint('[LocationTaskHandler] Driver ID: $_driverRecordId');
    
    if (_driverRecordId == null) {
      debugPrint('[LocationTaskHandler] No driver ID, cannot track');
      return;
    }

    // Start location stream
    _startLocationStream();
    
    // Backup timer for when device is stationary
    _backupTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      await _fetchAndSaveLocation();
    });
    
    // Also fetch immediately
    await _fetchAndSaveLocation();
  }
  
  Future<void> _initSupabase() async {
    if (_isInitialized) return;
    
    try {
      // Create a new Supabase client for this isolate
      _supabaseClient = SupabaseClient(_supabaseUrl, _supabaseAnonKey);
      _isInitialized = true;
      debugPrint('[LocationTaskHandler] ✅ Supabase client initialized in isolate');
    } catch (e) {
      debugPrint('[LocationTaskHandler] ❌ Error initializing Supabase: $e');
    }
  }

  void _startLocationStream() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 5, // Update every 5 meters for better tracking precision
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) async {
      await _saveLocationToSupabase(position);
    });
  }

  Future<void> _fetchAndSaveLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      await _saveLocationToSupabase(position);
    } catch (e) {
      debugPrint('[LocationTaskHandler] Error fetching location: $e');
    }
  }

  Future<void> _saveLocationToSupabase(Position position) async {
    if (_driverRecordId == null) {
      debugPrint('[LocationTaskHandler] ❌ No driver ID, skipping save');
      return;
    }
    
    if (_supabaseClient == null) {
      debugPrint('[LocationTaskHandler] ❌ Supabase not initialized, trying to init...');
      await _initSupabase();
      if (_supabaseClient == null) return;
    }

    try {
      await _supabaseClient!
          .from('drivers')
          .update({
            'current_latitude': position.latitude,
            'current_longitude': position.longitude,
            'last_seen_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', _driverRecordId!);

      debugPrint('[LocationTaskHandler] ✅ Location saved: ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}');
      
      // Send location back to main isolate for UI update
      FlutterForegroundTask.sendDataToMain({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': DateTime.now().toIso8601String(),
      });
      
      // Update notification with location
      FlutterForegroundTask.updateService(
        notificationTitle: '📍 Delivering...',
        notificationText: 'Updated: ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
      );
    } catch (e) {
      debugPrint('[LocationTaskHandler] ❌ Error saving to Supabase: $e');
      // Try to reinitialize if there was an error
      _isInitialized = false;
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // This is called based on eventAction - we use our own timers instead
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    debugPrint('[LocationTaskHandler] onDestroy called, isTimeout: $isTimeout');
    _positionStream?.cancel();
    _backupTimer?.cancel();
  }

  @override
  void onReceiveData(Object data) {
    debugPrint('[LocationTaskHandler] Received data: $data');
    // Handle commands from main isolate if needed
  }

  @override
  void onNotificationButtonPressed(String id) {
    debugPrint('[LocationTaskHandler] Notification button pressed: $id');
    if (id == 'stop_button') {
      FlutterForegroundTask.stopService();
    }
  }

  @override
  void onNotificationPressed() {
    // When user taps notification, bring app to foreground
    FlutterForegroundTask.launchApp('/driver-home');
  }

  @override
  void onNotificationDismissed() {
    debugPrint('[LocationTaskHandler] Notification dismissed');
  }
}

/// Service to manage the foreground task from the main app
class LocationForegroundService {
  static final LocationForegroundService _instance = LocationForegroundService._internal();
  factory LocationForegroundService() => _instance;
  LocationForegroundService._internal();

  Function(double lat, double lng)? onLocationUpdate;

  /// Initialize the foreground task options
  Future<void> init() async {
    // Initialize communication port for receiving data from task handler
    FlutterForegroundTask.initCommunicationPort();
    
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'driver_location_channel',
        channelName: 'Driver Location Tracking',
        channelDescription: 'Tracks your location while delivering orders',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true, // Don't repeatedly alert
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(30000), // 30 seconds
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  /// Start the foreground service
  Future<bool> startService(String driverRecordId) async {
    debugPrint('[LocationForegroundService] Starting service for driver: $driverRecordId');
    
    // Save driver ID for the isolate to use
    await FlutterForegroundTask.saveData(key: 'driverRecordId', value: driverRecordId);

    // Request notification permission on Android 13+
    final notificationPermission = await FlutterForegroundTask.checkNotificationPermission();
    if (notificationPermission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    // Set up listener to receive location updates from task handler
    FlutterForegroundTask.addTaskDataCallback((data) {
      if (data is Map && data.containsKey('latitude')) {
        onLocationUpdate?.call(
          data['latitude'] as double,
          data['longitude'] as double,
        );
      }
    });

    // Start the service
    final result = await FlutterForegroundTask.startService(
      notificationTitle: '🚗 You are Online',
      notificationText: 'Tracking your location for deliveries...',
      notificationButtons: [
        const NotificationButton(id: 'stop_button', text: 'Go Offline'),
      ],
      callback: startCallback,
    );

    debugPrint('[LocationForegroundService] Service started: $result');
    return result is ServiceRequestSuccess;
  }

  /// Stop the foreground service
  Future<bool> stopService() async {
    debugPrint('[LocationForegroundService] Stopping service');
    
    FlutterForegroundTask.removeTaskDataCallback(_onTaskData);
    onLocationUpdate = null;

    final result = await FlutterForegroundTask.stopService();
    debugPrint('[LocationForegroundService] Service stopped: $result');
    return result is ServiceRequestSuccess;
  }

  void _onTaskData(Object data) {
    // Placeholder callback
  }

  /// Check if service is running
  Future<bool> isRunning() async {
    return await FlutterForegroundTask.isRunningService;
  }

  /// Wrap your app widget to properly handle foreground task lifecycle
  static Widget wrapWithForegroundTask({required Widget child}) {
    return WithForegroundTask(child: child);
  }
}
