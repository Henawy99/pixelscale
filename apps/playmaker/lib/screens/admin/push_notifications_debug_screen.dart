import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/admin_notification_service.dart';

class PushNotificationsDebugScreen extends StatefulWidget {
  const PushNotificationsDebugScreen({Key? key}) : super(key: key);

  @override
  State<PushNotificationsDebugScreen> createState() =>
      _PushNotificationsDebugScreenState();
}

class _PushNotificationsDebugScreenState
    extends State<PushNotificationsDebugScreen> {
  final _supabase = Supabase.instance.client;
  final _adminNotificationService = AdminNotificationService();
  bool _isLoading = true;
  
  // Status checks
  Map<String, dynamic> _diagnostics = {};
  String? _fcmToken;
  String? _deviceId;
  NotificationSettings? _notificationSettings;
  List<Map<String, dynamic>> _registeredDevices = [];
  List<Map<String, dynamic>> _notificationQueue = [];
  int _totalNotificationsSent = 0;
  
  @override
  void initState() {
    super.initState();
    _runDiagnostics();
  }

  Future<void> _runDiagnostics() async {
    setState(() => _isLoading = true);
    
    try {
      // 1. Check Firebase Messaging initialization
      await _checkFirebaseMessaging();
      
      // 2. Check notification permissions
      await _checkNotificationPermissions();
      
      // 3. Check device registration in Supabase
      await _checkDeviceRegistration();
      
      // 4. Check notification queue
      await _checkNotificationQueue();
      
      // 5. Check total notifications sent
      await _checkTotalNotifications();
      
    } catch (e) {
      print('Error running diagnostics: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _checkFirebaseMessaging() async {
    try {
      _fcmToken = await FirebaseMessaging.instance.getToken();
      _diagnostics['firebase_initialized'] = _fcmToken != null;
      _diagnostics['fcm_token'] = _fcmToken ?? 'Not available';
    } catch (e) {
      _diagnostics['firebase_initialized'] = false;
      _diagnostics['firebase_error'] = e.toString();
    }
  }

  Future<void> _checkNotificationPermissions() async {
    try {
      _notificationSettings = await FirebaseMessaging.instance.getNotificationSettings();
      _diagnostics['permission_status'] = _notificationSettings?.authorizationStatus.toString() ?? 'Unknown';
      _diagnostics['permission_granted'] = 
        _notificationSettings?.authorizationStatus == AuthorizationStatus.authorized;
    } catch (e) {
      _diagnostics['permission_error'] = e.toString();
    }
  }

  Future<void> _checkDeviceRegistration() async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        _diagnostics['device_registered'] = false;
        _diagnostics['device_error'] = 'No user logged in';
        return;
      }

      final response = await _supabase
          .from('admin_devices')
          .select()
          .eq('admin_email', currentUser.email!)
          .order('last_active', ascending: false);

      _registeredDevices = List<Map<String, dynamic>>.from(response);
      _diagnostics['device_registered'] = _registeredDevices.isNotEmpty;
      _diagnostics['device_count'] = _registeredDevices.length;
      
      if (_registeredDevices.isNotEmpty) {
        _deviceId = _registeredDevices.first['id']; // Use 'id' not 'device_id'
        _diagnostics['device_name'] = _registeredDevices.first['device_name'];
        _diagnostics['last_active'] = _registeredDevices.first['last_active'];
        _diagnostics['fcm_token_from_db'] = _registeredDevices.first['fcm_token']; // Also store FCM token
      }
    } catch (e) {
      _diagnostics['device_registered'] = false;
      _diagnostics['device_error'] = e.toString();
    }
  }

  Future<void> _checkNotificationQueue() async {
    try {
      final response = await _supabase
          .from('admin_notification_queue')
          .select()
          .order('created_at', ascending: false)
          .limit(10);

      _notificationQueue = List<Map<String, dynamic>>.from(response);
      _diagnostics['queue_count'] = _notificationQueue.length;
      
      // Count pending vs processed
      final pending = _notificationQueue.where((n) => n['processed'] == false).length;
      final processed = _notificationQueue.where((n) => n['processed'] == true).length;
      
      _diagnostics['pending_notifications'] = pending;
      _diagnostics['processed_notifications'] = processed;
    } catch (e) {
      _diagnostics['queue_error'] = e.toString();
    }
  }

  Future<void> _checkTotalNotifications() async {
    try {
      final response = await _supabase
          .from('admin_notification_queue')
          .select('id')
          .count();

      _totalNotificationsSent = response.count;
      _diagnostics['total_notifications'] = _totalNotificationsSent;
    } catch (e) {
      _diagnostics['total_notifications_error'] = e.toString();
    }
  }

  Future<void> _registerDevice() async {
    try {
      setState(() => _isLoading = true);
      
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null || currentUser.email == null) {
        throw Exception('No user logged in');
      }
      
      await _adminNotificationService.initializeAdminNotifications(currentUser.email!);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Device registered successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Re-run diagnostics
      await _runDiagnostics();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to register device: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _requestPermissions() async {
    try {
      setState(() => _isLoading = true);
      
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permissions granted!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permissions denied. Please enable in Settings.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      
      // Re-run diagnostics
      await _runDiagnostics();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to request permissions: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendTestNotification() async {
    try {
      setState(() => _isLoading = true);
      
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('No user logged in');
      }

      // Insert a test notification directly into the queue
      await _supabase.from('admin_notification_queue').insert({
        'notification_type': 'test',
        'title': 'Test Notification',
        'body': 'This is a test notification sent at ${DateTime.now()}',
        'data': {'test': true, 'timestamp': DateTime.now().toIso8601String()},
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test notification queued! Check your device in ~1 minute.'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 5),
        ),
      );
      
      // Re-run diagnostics after a delay
      await Future.delayed(const Duration(seconds: 2));
      await _runDiagnostics();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send test notification: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Push Notifications Debug'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _runDiagnostics,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _runDiagnostics,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Overall Status
                    _buildOverallStatus(),
                    const SizedBox(height: 24),
                    
                    // Firebase Status
                    _buildSection(
                      'Firebase Messaging',
                      Icons.cloud_queue,
                      _buildFirebaseStatus(),
                    ),
                    const SizedBox(height: 16),
                    
                    // Permissions Status
                    _buildSection(
                      'iOS Permissions',
                      Icons.security,
                      _buildPermissionsStatus(),
                    ),
                    const SizedBox(height: 16),
                    
                    // Device Registration
                    _buildSection(
                      'Device Registration',
                      Icons.phone_iphone,
                      _buildDeviceRegistration(),
                    ),
                    const SizedBox(height: 16),
                    
                    // Notification Queue
                    _buildSection(
                      'Notification Queue',
                      Icons.queue,
                      _buildNotificationQueue(),
                    ),
                    const SizedBox(height: 16),
                    
                    // Actions
                    _buildSection(
                      'Actions',
                      Icons.build,
                      _buildActions(),
                    ),
                    const SizedBox(height: 16),
                    
                    // Recent Notifications
                    if (_notificationQueue.isNotEmpty) ...[
                      _buildSection(
                        'Recent Notifications (Last 10)',
                        Icons.history,
                        _buildRecentNotifications(),
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    // Registered Devices
                    if (_registeredDevices.isNotEmpty) ...[
                      _buildSection(
                        'Your Registered Devices',
                        Icons.devices,
                        _buildRegisteredDevices(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildOverallStatus() {
    final allGood = _diagnostics['firebase_initialized'] == true &&
        _diagnostics['permission_granted'] == true &&
        _diagnostics['device_registered'] == true;

    return Card(
      color: allGood ? Colors.green[50] : Colors.red[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              allGood ? Icons.check_circle : Icons.error,
              color: allGood ? Colors.green : Colors.red,
              size: 48,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    allGood ? 'All Systems Ready! ✅' : 'Issues Detected ⚠️',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: allGood ? Colors.green[800] : Colors.red[800],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    allGood
                        ? 'Push notifications are properly configured.'
                        : 'Some components need attention. Check details below.',
                    style: TextStyle(
                      color: allGood ? Colors.green[700] : Colors.red[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, Widget content) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(),
            content,
          ],
        ),
      ),
    );
  }

  Widget _buildFirebaseStatus() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStatusRow(
          'Firebase Initialized',
          _diagnostics['firebase_initialized'] == true,
        ),
        const SizedBox(height: 8),
        
        // ALWAYS show FCM token status (even if null)
        Text(
          'FCM Token:',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        
        if (_fcmToken != null) ...[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.green[300]!),
            ),
            child: SelectableText(
              _fcmToken!,
              style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
            ),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.red[300]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.error, color: Colors.red[700], size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'FCM Token: NULL ❌',
                      style: TextStyle(
                        color: Colors.red[700],
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Firebase Messaging cannot get a token. Possible causes:',
                  style: TextStyle(color: Colors.red[900], fontSize: 11),
                ),
                const SizedBox(height: 4),
                Text(
                  '• Wrong GoogleService-Info.plist (check Bundle ID match)',
                  style: TextStyle(color: Colors.red[900], fontSize: 10),
                ),
                Text(
                  '• APNs key not uploaded to Firebase',
                  style: TextStyle(color: Colors.red[900], fontSize: 10),
                ),
                Text(
                  '• App not signed for push notifications',
                  style: TextStyle(color: Colors.red[900], fontSize: 10),
                ),
                Text(
                  '• Running in simulator (APNs requires real device)',
                  style: TextStyle(color: Colors.red[900], fontSize: 10),
                ),
              ],
            ),
          ),
        ],
        
        if (_diagnostics['firebase_error'] != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.orange[300]!),
            ),
            child: Text(
              'Firebase Error: ${_diagnostics['firebase_error']}',
              style: TextStyle(color: Colors.orange[900], fontSize: 11),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPermissionsStatus() {
    final granted = _diagnostics['permission_granted'] == true;
    final status = _diagnostics['permission_status'] ?? 'Unknown';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStatusRow('Permissions Granted', granted),
        const SizedBox(height: 8),
        Text(
          'Status: $status',
          style: TextStyle(
            color: granted ? Colors.green[700] : Colors.orange[700],
            fontSize: 14,
          ),
        ),
        if (!granted) ...[
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _requestPermissions,
            icon: const Icon(Icons.security),
            label: const Text('Request Permissions'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDeviceRegistration() {
    final registered = _diagnostics['device_registered'] == true;
    final deviceCount = _diagnostics['device_count'] ?? 0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStatusRow('Device Registered', registered),
        const SizedBox(height: 8),
        Text('Total Devices: $deviceCount'),
        const SizedBox(height: 12),
        
        // ALWAYS show device ID status
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _deviceId != null ? Colors.green[50] : Colors.red[50],
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: _deviceId != null ? Colors.green[300]! : Colors.red[300]!,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _deviceId != null ? Icons.check_circle : Icons.error,
                    color: _deviceId != null ? Colors.green[700] : Colors.red[700],
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _deviceId != null ? 'Device ID: $_deviceId' : 'Device ID: NULL ❌',
                    style: TextStyle(
                      color: _deviceId != null ? Colors.green[900] : Colors.red[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              if (_deviceId != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Device Name: ${_diagnostics['device_name'] ?? 'Unknown'}',
                  style: TextStyle(color: Colors.green[900], fontSize: 11),
                ),
                Text(
                  'Last Active: ${_diagnostics['last_active'] ?? 'Unknown'}',
                  style: TextStyle(color: Colors.green[900], fontSize: 11),
                ),
              ] else ...[
                const SizedBox(height: 8),
                Text(
                  'Device not registered in Supabase!',
                  style: TextStyle(color: Colors.red[900], fontSize: 11),
                ),
                Text(
                  'Without a device ID, notifications cannot be sent.',
                  style: TextStyle(color: Colors.red[900], fontSize: 10),
                ),
              ],
            ],
          ),
        ),
        
        if (!registered || _diagnostics['device_error'] != null) ...[
          const SizedBox(height: 12),
          if (_diagnostics['device_error'] != null)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.orange[300]!),
              ),
              child: Text(
                'Error: ${_diagnostics['device_error']}',
                style: TextStyle(color: Colors.orange[900], fontSize: 11),
              ),
            ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _registerDevice,
            icon: const Icon(Icons.app_registration),
            label: const Text('Register Device Now'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNotificationQueue() {
    final pending = _diagnostics['pending_notifications'] ?? 0;
    final processed = _diagnostics['processed_notifications'] ?? 0;
    final total = _diagnostics['total_notifications'] ?? 0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Total Notifications Sent: $total'),
        const SizedBox(height: 8),
        Text('Pending: $pending', style: TextStyle(color: Colors.orange[700])),
        Text('Processed: $processed', style: TextStyle(color: Colors.green[700])),
        if (_diagnostics['queue_error'] != null) ...[
          const SizedBox(height: 8),
          Text(
            'Error: ${_diagnostics['queue_error']}',
            style: const TextStyle(color: Colors.red, fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _buildActions() {
    final canSendTest = _diagnostics['firebase_initialized'] == true &&
        _diagnostics['permission_granted'] == true &&
        _diagnostics['device_registered'] == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: canSendTest ? _sendTestNotification : null,
          icon: const Icon(Icons.send),
          label: const Text('Send Test Notification'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: _runDiagnostics,
          icon: const Icon(Icons.refresh),
          label: const Text('Re-run Diagnostics'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
        if (!canSendTest) ...[
          const SizedBox(height: 12),
          Text(
            'Fix all issues above to enable test notifications.',
            style: TextStyle(color: Colors.orange[700], fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildRecentNotifications() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _notificationQueue.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, index) {
        final notification = _notificationQueue[index];
        final processed = notification['processed'] ?? false;
        final createdAt = DateTime.parse(notification['created_at']);
        
        return ListTile(
          leading: Icon(
            processed ? Icons.check_circle : Icons.pending,
            color: processed ? Colors.green : Colors.orange,
          ),
          title: Text(
            notification['notification_type'] ?? 'Unknown',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${notification['title']}'),
              const SizedBox(height: 4),
              Text(
                '${createdAt.toString().split('.')[0]}',
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              ),
            ],
          ),
          trailing: processed
              ? const Icon(Icons.done, color: Colors.green)
              : const Icon(Icons.hourglass_empty, color: Colors.orange),
        );
      },
    );
  }

  Widget _buildRegisteredDevices() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _registeredDevices.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, index) {
        final device = _registeredDevices[index];
        final createdAt = DateTime.parse(device['created_at']);
        final lastActive = DateTime.parse(device['last_active']);
        
        return ListTile(
          leading: const Icon(Icons.phone_iphone, color: Colors.blue),
          title: Text(
            device['device_name'] ?? 'Unknown Device',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Device ID: ${device['id'] ?? 'Unknown'}', style: const TextStyle(fontSize: 10)),
              if (device['fcm_token'] != null) ...[
                const SizedBox(height: 4),
                Text(
                  'FCM Token: ${device['fcm_token'].toString().substring(0, 30)}...',
                  style: const TextStyle(fontSize: 9, fontFamily: 'monospace'),
                ),
              ],
              const SizedBox(height: 4),
              Text('Created: ${createdAt.toString().split('.')[0]}', style: const TextStyle(fontSize: 10)),
              Text('Last Active: ${lastActive.toString().split('.')[0]}', style: const TextStyle(fontSize: 10)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusRow(String label, bool status) {
    return Row(
      children: [
        Icon(
          status ? Icons.check_circle : Icons.cancel,
          color: status ? Colors.green : Colors.red,
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }
}

