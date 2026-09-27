import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Minimum spacing between heartbeats sent from the background service.
const Duration _minHeartbeatGap = Duration(seconds: 15);
const Duration _idleHeartbeat = Duration(seconds: 30);
const double _moveThresholdMeters = 75;

/// This callback is called when the foreground task starts
/// It runs in an isolate, so we need to reinitialize Supabase
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(LocationTaskHandler());
}

/// Runs in the background service isolate. Keeps the driver's position and "last seen"
/// fresh even when the app UI is closed, using the driver_heartbeat RPC with a per-device
/// key (the isolate has no user session).
class LocationTaskHandler extends TaskHandler {
  StreamSubscription<Position>? _positionStream;
  Timer? _backupTimer;
  SupabaseClient? _client;
  String? _driverId;
  String? _deviceKey;
  DateTime? _lastSentAt;
  Position? _lastSentPos;
  bool _sending = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    final url = await FlutterForegroundTask.getData<String>(key: 'supabaseUrl');
    final anonKey = await FlutterForegroundTask.getData<String>(key: 'supabaseAnonKey');
    _driverId = await FlutterForegroundTask.getData<String>(key: 'driverRecordId');
    _deviceKey = await FlutterForegroundTask.getData<String>(key: 'deviceKey');

    if (url == null || anonKey == null || _driverId == null || _deviceKey == null) {
      debugPrint('[LocationTaskHandler] Missing config, not tracking');
      return;
    }
    _client = SupabaseClient(url, anonKey);

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 25),
    ).listen((p) => _maybeSend(p));

    _backupTimer = Timer.periodic(_idleHeartbeat, (_) async {
      try {
        final p = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
        await _maybeSend(p, force: true);
      } catch (e) {
        debugPrint('[LocationTaskHandler] Location fetch failed: $e');
      }
    });
  }

  Future<void> _maybeSend(Position p, {bool force = false}) async {
    if (_client == null || _sending) return;
    final now = DateTime.now();
    final last = _lastSentAt;
    if (last != null && now.difference(last) < _minHeartbeatGap) return;
    final moved = _lastSentPos == null
        ? double.infinity
        : Geolocator.distanceBetween(_lastSentPos!.latitude, _lastSentPos!.longitude, p.latitude, p.longitude);
    if (!force && moved < _moveThresholdMeters && last != null && now.difference(last) < _idleHeartbeat) return;

    _sending = true;
    try {
      await _client!.rpc('driver_heartbeat', params: {
        'p_driver_id': _driverId,
        'p_device_key': _deviceKey,
        'p_lat': p.latitude,
        'p_lng': p.longitude,
        'p_heading': p.heading,
        'p_speed': p.speed,
      });
      _lastSentAt = now;
      _lastSentPos = p;
      FlutterForegroundTask.sendDataToMain({
        'latitude': p.latitude,
        'longitude': p.longitude,
        'heading': p.heading,
        'speed': p.speed,
        'timestamp': now.toIso8601String(),
      });
    } catch (e) {
      debugPrint('[LocationTaskHandler] Heartbeat failed: $e');
    } finally {
      _sending = false;
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // This is called based on eventAction - we use our own timers instead
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _positionStream?.cancel();
    _backupTimer?.cancel();
  }

  @override
  void onReceiveData(Object data) {}

  @override
  void onNotificationButtonPressed(String id) async {
    if (id == 'stop_button') {
      // "Go offline" from the notification: tell the planner, then stop.
      try {
        await _client?.rpc('driver_heartbeat', params: {
          'p_driver_id': _driverId,
          'p_device_key': _deviceKey,
          'p_lat': null,
          'p_lng': null,
          'p_go_offline': true,
        });
      } catch (_) {}
      FlutterForegroundTask.stopService();
    }
  }

  @override
  void onNotificationPressed() {
    // When user taps notification, bring app to foreground
    FlutterForegroundTask.launchApp('/driver-home');
  }

  @override
  void onNotificationDismissed() {}
}

/// Service to manage the foreground task from the main app
class LocationForegroundService {
  static final LocationForegroundService _instance = LocationForegroundService._internal();
  factory LocationForegroundService() => _instance;
  LocationForegroundService._internal();

  /// Set by the app entrypoint after Supabase.initialize (the isolate needs them).
  static String? supabaseUrl;
  static String? supabaseAnonKey;

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

    // The isolate authenticates heartbeats with a per-device key instead of the user session.
    try {
      final res = await Supabase.instance.client.rpc('driver_get_device_key');
      await FlutterForegroundTask.saveData(key: 'deviceKey', value: (res as Map)['device_key'] as String);
    } catch (e) {
      debugPrint('[LocationForegroundService] Could not get device key: $e');
    }
    await FlutterForegroundTask.saveData(key: 'driverRecordId', value: driverRecordId);
    if (supabaseUrl != null) await FlutterForegroundTask.saveData(key: 'supabaseUrl', value: supabaseUrl!);
    if (supabaseAnonKey != null) await FlutterForegroundTask.saveData(key: 'supabaseAnonKey', value: supabaseAnonKey!);

    // Request notification permission on Android 13+
    final notificationPermission = await FlutterForegroundTask.checkNotificationPermission();
    if (notificationPermission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    // Set up listener to receive location updates from task handler
    FlutterForegroundTask.addTaskDataCallback(_onTaskData);

    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.restartService();
      return true;
    }

    // Start the service
    final result = await FlutterForegroundTask.startService(
      notificationTitle: '🚗 You are Online',
      notificationText: 'Receiving delivery tours',
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

    final result = await FlutterForegroundTask.stopService();
    debugPrint('[LocationForegroundService] Service stopped: $result');
    return result is ServiceRequestSuccess;
  }

  void _onTaskData(Object data) {
    if (data is Map && data['latitude'] is double && data['longitude'] is double) {
      onLocationUpdate?.call(data['latitude'] as double, data['longitude'] as double);
    }
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
