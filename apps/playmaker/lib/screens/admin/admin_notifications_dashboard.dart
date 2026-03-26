import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/admin_notification_service.dart';
import '../../services/notification_service.dart';

class AdminNotificationsDashboard extends StatefulWidget {
  const AdminNotificationsDashboard({Key? key}) : super(key: key);

  @override
  State<AdminNotificationsDashboard> createState() => _AdminNotificationsDashboardState();
}

class _AdminNotificationsDashboardState extends State<AdminNotificationsDashboard>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  // ignore: unused_field - kept for future admin-specific notification features
  final _adminNotificationService = AdminNotificationService();
  final _notificationService = NotificationService();
  
  late TabController _tabController;
  bool _isLoading = false;
  
  // Diagnostics
  String? _fcmToken;
  bool _permissionsGranted = false;
  int _totalUsers = 0;
  int _totalPartners = 0;
  int _totalAdminDevices = 0;
  
  // Notification logs
  List<Map<String, dynamic>> _notificationLogs = [];
  
  // Controllers for broadcast
  final _broadcastTitleController = TextEditingController();
  final _broadcastMessageController = TextEditingController();
  
  // Test notification controllers
  final _testUserIdController = TextEditingController();
  final _testFieldIdController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _broadcastTitleController.dispose();
    _broadcastMessageController.dispose();
    _testUserIdController.dispose();
    _testFieldIdController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      // Get FCM token
      _fcmToken = await FirebaseMessaging.instance.getToken();
      
      // Check permissions
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      _permissionsGranted = settings.authorizationStatus == AuthorizationStatus.authorized;
      
      // Get counts
      final usersResponse = await _supabase
          .from('player_profiles')
          .select('id')
          .not('fcm_token', 'is', null);
      _totalUsers = (usersResponse as List).length;
      
      try {
        final partnersResponse = await _supabase
            .from('partner_devices')
            .select('id');
        _totalPartners = (partnersResponse as List).length;
      } catch (e) {
        _totalPartners = 0;
      }
      
      final adminResponse = await _supabase
          .from('admin_devices')
          .select('id');
      _totalAdminDevices = (adminResponse as List).length;
      
      // Load notification logs
      await _loadNotificationLogs();
      
    } catch (e) {
      print('Error loading data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadNotificationLogs() async {
    try {
      final response = await _supabase
          .from('notification_logs')
          .select()
          .order('created_at', ascending: false)
          .limit(100);
      
      _notificationLogs = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      // Table might not exist yet
      print('Note: notification_logs table may not exist: $e');
      _notificationLogs = [];
    }
  }

  Future<void> _logNotification({
    required String type,
    required String targetApp,
    required String title,
    required String body,
    String? targetId,
    bool success = true,
    String? error,
  }) async {
    try {
      await _supabase.from('notification_logs').insert({
        'type': type,
        'target_app': targetApp,
        'title': title,
        'body': body,
        'target_id': targetId,
        'success': success,
        'error': error,
        'sent_by': _supabase.auth.currentUser?.email ?? 'admin',
        'created_at': DateTime.now().toIso8601String(),
      });
      
      await _loadNotificationLogs();
    } catch (e) {
      print('Error logging notification: $e');
    }
  }

  // ============================================================
  // BROADCAST TO ALL USERS
  // ============================================================
  
  Future<void> _sendBroadcastToAllUsers() async {
    if (_broadcastTitleController.text.isEmpty || _broadcastMessageController.text.isEmpty) {
      _showError('Please enter both title and message');
      return;
    }
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.campaign, color: Colors.orange),
            const SizedBox(width: 8),
            const Text('Confirm Broadcast'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This will send a notification to ALL $_totalUsers users with FCM tokens.'),
            const SizedBox(height: 16),
            Text('Title: ${_broadcastTitleController.text}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Message: ${_broadcastMessageController.text}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Send to All Users'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    setState(() => _isLoading = true);
    
    try {
      // Get all user IDs with FCM tokens
      final response = await _supabase
          .from('player_profiles')
          .select('id')
          .not('fcm_token', 'is', null);
      
      final userIds = (response as List).map((u) => u['id'] as String).toList();
      
      if (userIds.isEmpty) {
        _showError('No users with FCM tokens found');
        return;
      }
      
      // Send broadcast notification
      await _supabase.functions.invoke('send-user-notification', body: {
        'type': 'broadcast',
        'user_ids': userIds,
        'title': _broadcastTitleController.text,
        'body': _broadcastMessageController.text,
        'data': {
          'broadcast': 'true',
          'sent_at': DateTime.now().toIso8601String(),
        },
      });
      
      await _logNotification(
        type: 'broadcast',
        targetApp: 'USER',
        title: _broadcastTitleController.text,
        body: _broadcastMessageController.text,
        targetId: 'all_users (${userIds.length})',
        success: true,
      );
      
      _showSuccess('Broadcast sent to ${userIds.length} users!');
      _broadcastTitleController.clear();
      _broadcastMessageController.clear();
      
    } catch (e) {
      await _logNotification(
        type: 'broadcast',
        targetApp: 'USER',
        title: _broadcastTitleController.text,
        body: _broadcastMessageController.text,
        success: false,
        error: e.toString(),
      );
      _showError('Failed to send broadcast: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ============================================================
  // USER APP NOTIFICATIONS
  // ============================================================
  
  Future<void> _testFriendRequestNotification() async {
    final userId = _testUserIdController.text.trim();
    if (userId.isEmpty) {
      _showError('Please enter a User ID');
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      await _notificationService.sendFriendRequestNotification(
        toUserId: userId,
        fromUserName: 'Test Admin',
        fromUserId: 'admin-test-id',
      );
      
      await _logNotification(
        type: 'friend_request',
        targetApp: 'USER',
        title: '👋 New Friend Request',
        body: 'Test Admin wants to be your friend!',
        targetId: userId,
        success: true,
      );
      
      _showSuccess('Friend request notification sent!');
    } catch (e) {
      await _logNotification(
        type: 'friend_request',
        targetApp: 'USER',
        title: '👋 New Friend Request',
        body: 'Test Admin wants to be your friend!',
        targetId: userId,
        success: false,
        error: e.toString(),
      );
      _showError('Failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testBookingReminderNotification() async {
    final userId = _testUserIdController.text.trim();
    if (userId.isEmpty) {
      _showError('Please enter a User ID');
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      await _notificationService.sendBookingReminder(
        userId: userId,
        fieldName: 'Test Field',
        date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
        timeSlot: '18:00-19:00',
      );
      
      await _logNotification(
        type: 'booking_reminder',
        targetApp: 'USER',
        title: '⏰ Booking Reminder',
        body: 'Your game at Test Field starts in 1 hour!',
        targetId: userId,
        success: true,
      );
      
      _showSuccess('Booking reminder sent!');
    } catch (e) {
      await _logNotification(
        type: 'booking_reminder',
        targetApp: 'USER',
        title: '⏰ Booking Reminder',
        body: 'Your game at Test Field starts in 1 hour!',
        targetId: userId,
        success: false,
        error: e.toString(),
      );
      _showError('Failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testBookingRejectedNotification() async {
    final userId = _testUserIdController.text.trim();
    if (userId.isEmpty) {
      _showError('Please enter a User ID');
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      await _notificationService.sendBookingRejectedNotification(
        userId: userId,
        fieldName: 'Test Field',
        date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
        timeSlot: '18:00-19:00',
        rejectionReason: 'Test rejection from admin dashboard',
      );
      
      await _logNotification(
        type: 'booking_rejected',
        targetApp: 'USER',
        title: '❌ Booking Rejected',
        body: 'Your booking at Test Field was rejected',
        targetId: userId,
        success: true,
      );
      
      _showSuccess('Booking rejected notification sent!');
    } catch (e) {
      await _logNotification(
        type: 'booking_rejected',
        targetApp: 'USER',
        title: '❌ Booking Rejected',
        body: 'Your booking at Test Field was rejected',
        targetId: userId,
        success: false,
        error: e.toString(),
      );
      _showError('Failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testMatchCancelledNotification() async {
    final userId = _testUserIdController.text.trim();
    if (userId.isEmpty) {
      _showError('Please enter a User ID');
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      await _notificationService.sendMatchCancelledNotification(
        playerIds: [userId],
        fieldName: 'Test Field',
        date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
        timeSlot: '18:00-19:00',
        isHost: false,
        cancelledByName: 'Test Host',
      );
      
      await _logNotification(
        type: 'match_cancelled',
        targetApp: 'USER',
        title: '🚫 Match Cancelled',
        body: 'Test Host cancelled the match at Test Field',
        targetId: userId,
        success: true,
      );
      
      _showSuccess('Match cancelled notification sent!');
    } catch (e) {
      await _logNotification(
        type: 'match_cancelled',
        targetApp: 'USER',
        title: '🚫 Match Cancelled',
        body: 'Test Host cancelled the match at Test Field',
        targetId: userId,
        success: false,
        error: e.toString(),
      );
      _showError('Failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ============================================================
  // PARTNER APP NOTIFICATIONS
  // ============================================================
  
  Future<void> _testPartnerNewBookingNotification() async {
    final fieldId = _testFieldIdController.text.trim();
    if (fieldId.isEmpty) {
      _showError('Please enter a Field ID');
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      await _notificationService.sendPartnerNewBookingNotification(
        fieldId: fieldId,
        userName: 'Test User',
        date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
        timeSlot: '18:00-19:00',
        price: 200,
      );
      
      await _logNotification(
        type: 'new_booking',
        targetApp: 'PARTNER',
        title: '⚽ New Booking!',
        body: 'Test User booked for today at 18:00-19:00 - 200 EGP',
        targetId: fieldId,
        success: true,
      );
      
      _showSuccess('Partner new booking notification sent!');
    } catch (e) {
      await _logNotification(
        type: 'new_booking',
        targetApp: 'PARTNER',
        title: '⚽ New Booking!',
        body: 'Test User booked for today at 18:00-19:00 - 200 EGP',
        targetId: fieldId,
        success: false,
        error: e.toString(),
      );
      _showError('Failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testPartnerBookingCancelledNotification() async {
    final fieldId = _testFieldIdController.text.trim();
    if (fieldId.isEmpty) {
      _showError('Please enter a Field ID');
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      await _notificationService.sendPartnerBookingCancelledNotification(
        fieldId: fieldId,
        userName: 'Test User',
        date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
        timeSlot: '18:00-19:00',
      );
      
      await _logNotification(
        type: 'booking_cancelled',
        targetApp: 'PARTNER',
        title: '❌ Booking Cancelled',
        body: 'Test User cancelled their booking for today at 18:00-19:00',
        targetId: fieldId,
        success: true,
      );
      
      _showSuccess('Partner booking cancelled notification sent!');
    } catch (e) {
      await _logNotification(
        type: 'booking_cancelled',
        targetApp: 'PARTNER',
        title: '❌ Booking Cancelled',
        body: 'Test User cancelled their booking for today at 18:00-19:00',
        targetId: fieldId,
        success: false,
        error: e.toString(),
      );
      _showError('Failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ============================================================
  // ADMIN APP NOTIFICATIONS
  // ============================================================
  
  Future<void> _testAdminNewUserNotification() async {
    setState(() => _isLoading = true);
    
    try {
      await _supabase.functions.invoke('send-admin-notification', body: {
        'fcm_token': _fcmToken,
        'user_name': 'Test New User',
        'user_email': 'testuser@example.com',
        'user_id': 'test-user-id',
      });
      
      await _logNotification(
        type: 'new_user',
        targetApp: 'ADMIN',
        title: '👤 New User Registered',
        body: 'Test New User (testuser@example.com) just registered',
        success: true,
      );
      
      _showSuccess('Admin new user notification sent!');
    } catch (e) {
      await _logNotification(
        type: 'new_user',
        targetApp: 'ADMIN',
        title: '👤 New User Registered',
        body: 'Test New User (testuser@example.com) just registered',
        success: false,
        error: e.toString(),
      );
      _showError('Failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testAdminNewBookingNotification() async {
    setState(() => _isLoading = true);
    
    try {
      await _supabase.functions.invoke('send-booking-notification', body: {
        'booking_id': 'test-booking-id',
        'field_name': 'Test Field',
        'location': 'Test Location',
        'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'time_slot': '18:00-19:00',
        'price': 200,
        'user_id': 'test-user-id',
      });
      
      await _logNotification(
        type: 'new_booking',
        targetApp: 'ADMIN',
        title: '⚽ New Booking!',
        body: 'Test Field - Test Location - Today at 18:00-19:00 - 200 EGP',
        success: true,
      );
      
      _showSuccess('Admin new booking notification sent!');
    } catch (e) {
      await _logNotification(
        type: 'new_booking',
        targetApp: 'ADMIN',
        title: '⚽ New Booking!',
        body: 'Test Field - Test Location - Today at 18:00-19:00 - 200 EGP',
        success: false,
        error: e.toString(),
      );
      _showError('Failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.copy, color: Colors.white, size: 20),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: message));
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Error copied to clipboard'),
                    backgroundColor: Colors.grey,
                    duration: Duration(seconds: 1),
                  ),
                );
              },
              tooltip: 'Copy error',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: 'Details',
          textColor: Colors.white,
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Row(
                  children: [
                    Icon(Icons.error, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Error Details'),
                  ],
                ),
                content: SingleChildScrollView(
                  child: SelectableText(
                    message,
                    style: GoogleFonts.robotoMono(fontSize: 12),
                  ),
                ),
                actions: [
                  TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: message));
                      Navigator.pop(context);
                      _showSuccess('Error copied to clipboard');
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          'Notifications Dashboard',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black87),
            onPressed: _isLoading ? null : _loadData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF00BF63),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF00BF63),
          isScrollable: true,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
            Tab(icon: Icon(Icons.person), text: 'USER APP'),
            Tab(icon: Icon(Icons.business), text: 'PARTNER APP'),
            Tab(icon: Icon(Icons.admin_panel_settings), text: 'ADMIN APP'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildUserAppTab(),
                _buildPartnerAppTab(),
                _buildAdminAppTab(),
              ],
            ),
    );
  }

  // ============================================================
  // OVERVIEW TAB
  // ============================================================
  
  Widget _buildOverviewTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Cards
            _buildStatusCards(),
            const SizedBox(height: 24),
            
            // Broadcast Section
            _buildBroadcastSection(),
            const SizedBox(height: 24),
            
            // Recent Logs
            _buildRecentLogsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'System Status',
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildStatusCard(
              'FCM Status',
              _fcmToken != null ? 'Connected' : 'Not Connected',
              _fcmToken != null ? Icons.check_circle : Icons.error,
              _fcmToken != null ? Colors.green : Colors.red,
            )),
            const SizedBox(width: 12),
            Expanded(child: _buildStatusCard(
              'Permissions',
              _permissionsGranted ? 'Granted' : 'Denied',
              _permissionsGranted ? Icons.security : Icons.security,
              _permissionsGranted ? Colors.green : Colors.orange,
            )),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildStatusCard(
              'Users with FCM',
              '$_totalUsers users',
              Icons.people,
              Colors.blue,
            )),
            const SizedBox(width: 12),
            Expanded(child: _buildStatusCard(
              'Partner Devices',
              '$_totalPartners devices',
              Icons.business,
              Colors.purple,
            )),
            const SizedBox(width: 12),
            Expanded(child: _buildStatusCard(
              'Admin Devices',
              '$_totalAdminDevices devices',
              Icons.admin_panel_settings,
              Colors.orange,
            )),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusCard(String title, String value, IconData icon, Color color) {
    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBroadcastSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade400, Colors.deepOrange.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.campaign, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Text(
                'Broadcast to All Users',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Send a notification to all $_totalUsers users with FCM tokens',
            style: GoogleFonts.inter(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _broadcastTitleController,
            decoration: InputDecoration(
              hintText: 'Notification Title (e.g., "New Field Added!")',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              prefixIcon: const Icon(Icons.title),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _broadcastMessageController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Notification Message...',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              prefixIcon: const Padding(
                padding: EdgeInsets.only(bottom: 48),
                child: Icon(Icons.message),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _sendBroadcastToAllUsers,
              icon: const Icon(Icons.send),
              label: Text('Send Broadcast to $_totalUsers Users'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.deepOrange,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentLogsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Notification Logs',
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              onPressed: _loadNotificationLogs,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Refresh'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_notificationLogs.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.history, size: 48, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text(
                    'No notification logs yet',
                    style: GoogleFonts.inter(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Logs will appear here after sending notifications',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[400]),
                  ),
                ],
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _notificationLogs.length.clamp(0, 10),
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final log = _notificationLogs[index];
                final success = log['success'] ?? false;
                final createdAt = DateTime.tryParse(log['created_at'] ?? '');
                
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: success ? Colors.green[50] : Colors.red[50],
                    child: Icon(
                      success ? Icons.check : Icons.error,
                      color: success ? Colors.green : Colors.red,
                      size: 20,
                    ),
                  ),
                  title: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getAppColor(log['target_app']).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          log['target_app'] ?? 'UNKNOWN',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _getAppColor(log['target_app']),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          log['type'] ?? 'Unknown',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        log['title'] ?? '',
                        style: GoogleFonts.inter(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (createdAt != null)
                        Text(
                          DateFormat('MMM d, HH:mm:ss').format(createdAt),
                          style: GoogleFonts.inter(fontSize: 10, color: Colors.grey),
                        ),
                    ],
                  ),
                  trailing: log['error'] != null
                      ? IconButton(
                          icon: const Icon(Icons.info_outline, color: Colors.red),
                          onPressed: () => _showErrorDialog(log['error']),
                        )
                      : null,
                );
              },
            ),
          ),
      ],
    );
  }

  Color _getAppColor(String? app) {
    switch (app) {
      case 'USER':
        return const Color(0xFF00BF63);
      case 'PARTNER':
        return Colors.blue;
      case 'ADMIN':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 8),
            Text('Error Details'),
          ],
        ),
        content: SingleChildScrollView(
          child: SelectableText(error),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: error));
              Navigator.pop(context);
              _showSuccess('Error copied to clipboard');
            },
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // USER APP TAB
  // ============================================================
  
  Widget _buildUserAppTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAppHeader(
            'USER APP Notifications',
            'Test notifications for the Playmaker user app',
            const Color(0xFF00BF63),
            Icons.person,
          ),
          const SizedBox(height: 20),
          
          // User ID Input
          _buildInputCard(
            'Target User',
            'Enter the User ID to send test notifications',
            _testUserIdController,
            'User ID (UUID)',
            Icons.person_search,
          ),
          const SizedBox(height: 20),
          
          // Notification Types
          Text(
            'Available Notifications',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          
          _buildNotificationTestCard(
            title: 'Friend Request',
            description: 'Sent when a user receives a friend request',
            icon: Icons.person_add,
            color: Colors.green,
            onTest: _testFriendRequestNotification,
          ),
          _buildNotificationTestCard(
            title: 'Booking Reminder',
            description: 'Sent 1 hour before a booking starts',
            icon: Icons.alarm,
            color: Colors.orange,
            onTest: _testBookingReminderNotification,
          ),
          _buildNotificationTestCard(
            title: 'Booking Rejected',
            description: 'Sent when a partner rejects a booking',
            icon: Icons.cancel,
            color: Colors.red,
            onTest: _testBookingRejectedNotification,
          ),
          _buildNotificationTestCard(
            title: 'Match Cancelled',
            description: 'Sent when a match the user joined is cancelled',
            icon: Icons.event_busy,
            color: Colors.red,
            onTest: _testMatchCancelledNotification,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PARTNER APP TAB
  // ============================================================
  
  Widget _buildPartnerAppTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAppHeader(
            'PARTNER APP Notifications',
            'Test notifications for field owners',
            Colors.blue,
            Icons.business,
          ),
          const SizedBox(height: 20),
          
          // Field ID Input
          _buildInputCard(
            'Target Field',
            'Enter the Field ID to send test notifications',
            _testFieldIdController,
            'Field ID (UUID)',
            Icons.sports_soccer,
          ),
          const SizedBox(height: 20),
          
          // Notification Types
          Text(
            'Available Notifications',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          
          _buildNotificationTestCard(
            title: 'New Booking',
            description: 'Sent when a user books a timeslot',
            icon: Icons.calendar_today,
            color: Colors.green,
            onTest: _testPartnerNewBookingNotification,
          ),
          _buildNotificationTestCard(
            title: 'Booking Cancelled',
            description: 'Sent when a user cancels their booking',
            icon: Icons.event_busy,
            color: Colors.orange,
            onTest: _testPartnerBookingCancelledNotification,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ADMIN APP TAB
  // ============================================================
  
  Widget _buildAdminAppTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAppHeader(
            'ADMIN APP Notifications',
            'Test notifications for admin dashboard',
            Colors.orange,
            Icons.admin_panel_settings,
          ),
          const SizedBox(height: 20),
          
          // FCM Token Display
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.key, color: Colors.orange),
                    const SizedBox(width: 8),
                    Text(
                      'Your FCM Token',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_fcmToken != null)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${_fcmToken!.substring(0, 50)}...',
                            style: GoogleFonts.robotoMono(fontSize: 10),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 18),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _fcmToken!));
                            _showSuccess('FCM Token copied!');
                          },
                        ),
                      ],
                    ),
                  )
                else
                  Text(
                    'FCM Token not available',
                    style: GoogleFonts.inter(color: Colors.red),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          // Notification Types
          Text(
            'Available Notifications',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          
          _buildNotificationTestCard(
            title: 'New User Registered',
            description: 'Sent when a new user signs up',
            icon: Icons.person_add,
            color: Colors.blue,
            onTest: _testAdminNewUserNotification,
          ),
          _buildNotificationTestCard(
            title: 'New Booking',
            description: 'Sent when any user makes a booking',
            icon: Icons.calendar_today,
            color: Colors.green,
            onTest: _testAdminNewBookingNotification,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SHARED WIDGETS
  // ============================================================
  
  Widget _buildAppHeader(String title, String subtitle, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputCard(
    String title,
    String description,
    TextEditingController controller,
    String hint,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hint,
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            style: GoogleFonts.robotoMono(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationTestCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTest,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          description,
          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: ElevatedButton(
          onPressed: _isLoading ? null : onTest,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Test'),
        ),
      ),
    );
  }
}

