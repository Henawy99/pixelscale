import 'dart:async';
import 'package:restaurantadmin/screens/widgets/orders_settings_sheet.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:restaurantadmin/models/order.dart' as app_order;
import 'package:restaurantadmin/models/remote_scanner_status.dart';
import 'package:restaurantadmin/widgets/category_card.dart';
import 'package:restaurantadmin/screens/orderable_brand_menu_screen.dart';
import 'package:restaurantadmin/screens/order_detail_screen.dart';
import 'package:restaurantadmin/services/order_service.dart';
import 'package:restaurantadmin/services/daily_summary_service.dart';
import 'package:restaurantadmin/utils/pdf_generator.dart';
import 'package:restaurantadmin/models/driver.dart';
import 'package:restaurantadmin/screens/delivery_monitor_screen.dart';
import 'package:restaurantadmin/widgets/global_order_listener.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final SupabaseClient _supabase = Supabase.instance.client;
  final OrderService _orderService = OrderService();
  late Future<List<app_order.Order>> _ordersFuture;
  StreamSubscription<List<Map<String, dynamic>>>? _ordersSubscription;
  RealtimeChannel? _ordersChannel;
  Timer? _periodicRefreshTimer;
  // ignore: unused_field
  bool _isCancellingOrder = false; // Used for UI state tracking

  // Add notification service listener
  final OrderNotificationService _notificationService =
      OrderNotificationService();
  StreamSubscription<String>? _newOrderSubscription;

  // Robust backup using Supabase row stream (ignores initial snapshot)
  bool _ordersStreamPrimed = false;

  // Live polling fallback (Windows-friendly)
  Timer? _livePollTimer;
  DateTime? _latestKnownCreatedAt;
  final bool _livePollingEnabled = true;
  // Mobile-only: toggle for showing brand row when tapping "+"
  bool _showBrandPickerMobile = false;

  // Animation controllers
  late AnimationController _animationController;
  late AnimationController _refreshController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _refreshRotation;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedBrandFilter = 'all';
  String _selectedStatusFilter = 'all';
  String _selectedTab = 'Prepare';

  List<Driver> _activeDrivers = [];
  List<app_order.Order> _deliveryOrders = [];

  // Receipt scanner status
  List<RemoteScannerStatus> _remoteScanners = [];
  RealtimeChannel? _scannerStatusChannel;
  Timer? _scannerStatusTimer;
  bool _scannerStatusExpanded = false;

  // Date navigation
  late DateTime _selectedDate;

  int _todayOrderCount = 0;
  List<app_order.Order> _loadedOrders = [];

  double get _todayTotalRevenue {
    final filtered = _filterOrders(_loadedOrders);
    double revenue = 0.0;
    for (var order in filtered) {
      if (order.orderTypeName != _employeeOrderTypeName) {
        final bucket = _deriveStatusBucket(order);
        final statusLower = (order.status ?? '').toLowerCase();
        if (bucket != 'cancelled' && statusLower != 'cancelled' && statusLower != 'canceled') {
          revenue += order.totalPrice;
        }
      }
    }
    return revenue;
  }

  bool _isLoadingTodayStats = true;
  bool _isGeneratingSummary = false;
  static const String _employeeOrderTypeName = "Employee Meal";

  final List<Map<String, dynamic>> _brandCardData = [
    {
      'id': '4446a388-aaa7-402f-be4d-b82b23797415',
      'name': 'DEVILS SMASH BURGER',
      'imageUrl': 'assets/restaurantlogos/devilssmashburger.png',
    },
    {
      'id': 'f5116077-8de3-488b-bf9d-75295f791dce',
      'name': 'TACOTASTIC',
      'imageUrl': 'assets/restaurantlogos/tacotastic.jpeg',
    },
    {
      'id': '8ec82a94-89f5-4603-bb35-c47c78d66d2a',
      'name': 'CRISPY CHICKEN LAB',
      'imageUrl': 'assets/restaurantlogos/crispychickenlab.jpeg',
    },
    {
      'id': '59bf0f09-ab58-48a0-9b3f-13c7709c8600',
      'name': 'THE BOWL SPOT',
      'imageUrl': 'assets/restaurantlogos/thebowlspot.jpeg',
    },
  ];

  final List<Map<String, String>> _statusFilters = [
    {'value': 'all', 'label': 'All Status'},
    {'value': 'pending', 'label': 'Pending'},
    {'value': 'confirmed', 'label': 'Confirmed'},
    {'value': 'preparing', 'label': 'Preparing'},
    {'value': 'ready', 'label': 'Ready'},
    {'value': 'delivered', 'label': 'Delivered'},
    {'value': 'cancelled', 'label': 'Cancelled'},
  ];

  @override
  void initState() {
    super.initState();

    // Initialize selected date first
    _selectedDate = DateTime.now();

    // Initialize animations
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _refreshController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );
    _refreshRotation = Tween<double>(begin: 0, end: 6.28).animate(
      CurvedAnimation(parent: _refreshController, curve: Curves.easeInOut),
    );

    _loadAllData();
    if (_livePollingEnabled) {
      _startLivePolling();
    }

    _subscribeToOrderChanges();
    _subscribeToNewOrderNotifications();
    _subscribeToOrdersStreamBackup();
    _startPeriodicRefresh();
    _fetchScannerStatus();
    _subscribeToScannerStatus();
    _scannerStatusTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _fetchScannerStatus();
    });
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animationController.dispose();
    _refreshController.dispose();
    _searchController.dispose();
    _ordersSubscription?.cancel();
    _ordersChannel?.unsubscribe();
    _newOrderSubscription?.cancel();
    _periodicRefreshTimer?.cancel();
    _livePollTimer?.cancel();
    _scannerStatusTimer?.cancel();
    _scannerStatusChannel?.unsubscribe();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && mounted) {
      print('[OrdersScreen] App resumed, refreshing orders...');
      _loadAllData();
    }
  }

  void _subscribeToOrderChanges() {
    // Cancel any existing subscriptions
    _ordersSubscription?.cancel();
    _ordersChannel?.unsubscribe();

    // Listen for both inserts and updates via channel (fast path)
    _ordersChannel = _supabase
        .channel('public:orders:orders_screen_updates')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'orders',
          callback: (payload) {
            print('[OrdersScreen] Order insert detected');
            if (mounted) {
              _showSuccessSnackBar('New order received! Refreshing list...');
              _loadAllData();
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'orders',
          callback: (payload) {
            print('[OrdersScreen] Order update detected: ${payload.eventType}');
            if (mounted) {
              _showSuccessSnackBar('Order updated! Refreshing list...');
              _loadAllData();
            }
          },
        )
        .subscribe();

    print('[OrdersScreen] Subscribed to order updates via channel');
  }

  void _subscribeToOrdersStreamBackup() {
    // Cancels existing stream subscription to avoid duplicates
    _ordersSubscription?.cancel();
    _ordersSubscription = _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .listen(
          (rows) {
            // First snapshot is initial data - we ignore it
            if (!_ordersStreamPrimed) {
              _ordersStreamPrimed = true;
              return;
            }
            if (!mounted) return;
            // Silently refresh without snackbar
            _loadAllData();
          },
          onError: (err) {
            debugPrint('[OrdersScreen] Stream error: $err');
          },
        );
    print('[OrdersScreen] Subscribed to orders stream backup');
  }

  void _startLivePolling() {
    _livePollTimer?.cancel();
    _livePollTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (!mounted) return;
      try {
        final resp = await _supabase
            .from('orders')
            .select('created_at')
            .order('created_at', ascending: false)
            .limit(1);
        if (resp.isNotEmpty) {
          final createdAtStr = resp.first['created_at'] as String?;
          if (createdAtStr != null) {
            final createdAt = DateTime.tryParse(createdAtStr);
            if (createdAt != null) {
              // On first run, set baseline
              if (_latestKnownCreatedAt == null) {
                _latestKnownCreatedAt = createdAt;
              } else if (createdAt.isAfter(_latestKnownCreatedAt!)) {
                _latestKnownCreatedAt = createdAt;
                // New order detected via polling
                _loadAllData();
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[OrdersScreen] Live polling error: $e');
      }
    });
    print('[OrdersScreen] Live polling started');
  }

  void _subscribeToNewOrderNotifications() {
    _newOrderSubscription?.cancel();
    _newOrderSubscription = _notificationService.newOrderStream.listen((
      orderId,
    ) {
      print('[OrdersScreen] Received new order notification: $orderId');
      if (mounted) {
        // Show immediate feedback
        // Refresh the orders list immediately
        _loadAllData();
      }
    });
    print('[OrdersScreen] Subscribed to new order notifications');
  }

  void _startPeriodicRefresh() {
    // Set up a periodic timer as a backup to ensure orders are refreshed
    // This helps in case the real-time subscription fails
    _periodicRefreshTimer?.cancel();
    _periodicRefreshTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      if (mounted) {
        print('[OrdersScreen] Periodic refresh triggered (backup)');
        _loadAllData();
      }
    });
  }

  // ── Scanner Status ──────────────────────────────────────────────
  Future<void> _fetchScannerStatus() async {
    try {
      final response = await _supabase
          .from('scanner_heartbeats')
          .select()
          .order('last_heartbeat', ascending: false);
      if (mounted) {
        setState(() {
          _remoteScanners = (response as List)
              .map((data) => RemoteScannerStatus.fromJson(
                    data as Map<String, dynamic>,
                  ))
              .toList();
        });
      }
    } catch (e) {
      debugPrint('[OrdersScreen] Error fetching scanner status: $e');
    }
  }

  void _subscribeToScannerStatus() {
    _scannerStatusChannel = _supabase
        .channel('scanner_heartbeats_orders')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'scanner_heartbeats',
          callback: (payload) {
            _fetchScannerStatus();
          },
        )
        .subscribe();
  }

  Future<void> _loadAllData() async {
    setState(() {
      _isLoadingTodayStats = true;
    });
    _refreshController.forward().then((_) => _refreshController.reset());
    _ordersFuture = _fetchOrders();
    await _fetchTodayStats();
    await _fetchActiveDrivers();
    _ordersFuture.then((allOrders) {
      if (mounted) {
        setState(() {
          _loadedOrders = allOrders;
        });
        _filterAndSetDeliveryOrders(allOrders);
        _animationController.forward(from: 0.0);
      }
    });
  }

  Future<void> _fetchActiveDrivers() async {
    if (!mounted) return;
    try {
      final response = await _supabase
          .from('drivers')
          .select()
          .eq('is_online', true)
          .order('name', ascending: true);
      if (!mounted) return;
      final List<Driver> loadedDrivers = (response as List)
          .map((data) => Driver.fromJson(data as Map<String, dynamic>))
          .toList();
      setState(() => _activeDrivers = loadedDrivers);
    } catch (e) {
      print('Error fetching active drivers: $e');
      if (mounted) _showErrorSnackBar('Error fetching active drivers: $e');
    }
  }

  void _filterAndSetDeliveryOrders(List<app_order.Order> allOrders) {
    if (!mounted) return;
    final deliveryOrders = allOrders
        .where(
          (order) =>
              order.fulfillmentType == 'delivery' &&
              order.assignedDriverId == null,
        )
        .toList();
    setState(() => _deliveryOrders = deliveryOrders);
  }

  void _goToPreviousDay() {
    final currentDate = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    setState(() {
      _selectedDate = currentDate.subtract(const Duration(days: 1));
    });
    _loadAllData();
  }

  void _goToNextDay() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDateOnly = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );

    // Don't go beyond today
    if (selectedDateOnly.isBefore(today)) {
      setState(() {
        _selectedDate = selectedDateOnly.add(const Duration(days: 1));
      });
      _loadAllData();
    }
  }

  void _goToToday() {
    final now = DateTime.now();
    setState(() {
      _selectedDate = DateTime(now.year, now.month, now.day);
    });
    _loadAllData();
  }

  bool _isToday() {
    final now = DateTime.now();
    final selectedDateOnly = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final today = DateTime(now.year, now.month, now.day);
    return selectedDateOnly.isAtSameMomentAs(today);
  }

  String _getDateLabel() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final selectedDateOnly = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );

    if (selectedDateOnly.isAtSameMomentAs(today)) {
      return 'Today';
    } else if (selectedDateOnly.isAtSameMomentAs(yesterday)) {
      return 'Yesterday';
    } else {
      return DateFormat('EEEE, MMM d').format(_selectedDate);
    }
  }

  String _formatDateForQuery(DateTime date) {
    // Convert local time to UTC so Supabase timestamp comparisons are correct
    final utc = date.toUtc();
    return utc.toIso8601String();
  }

  Future<void> _fetchTodayStats() async {
    if (!mounted) return;
    try {
      // Use local midnight boundaries so "today" aligns with local clock
      final startOfDay = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      ); // local midnight
      final endOfDay = startOfDay.add(const Duration(days: 1)); // local next midnight

      final dayStart = _formatDateForQuery(startOfDay);
      final dayEnd = _formatDateForQuery(endOfDay);

      final todayOrdersResponse = await _supabase
          .from('orders')
          .select('total_price, order_type_name')
          .gte('created_at', dayStart)
          .lt('created_at', dayEnd);
      if (!mounted) return;
      int count = 0;
      double revenue = 0.0;
      final List<dynamic> ordersData =
          todayOrdersResponse as List<dynamic>? ?? [];
      for (var orderData in ordersData) {
        final orderMap = orderData as Map<String, dynamic>;
        if (orderMap['order_type_name'] != _employeeOrderTypeName) {
          count++;
        }
      }
      setState(() {
        _todayOrderCount = count;
        _isLoadingTodayStats = false;
      });
    } catch (e) {
      print('Error fetching stats: $e');
      if (mounted) {
        _showErrorSnackBar('Error fetching stats: $e');
        setState(() {
          _isLoadingTodayStats = false;
          _todayOrderCount = 0;
        });
      }
    }
  }

  Future<List<app_order.Order>> _fetchOrders() async {
    try {
      // Local midnight boundaries → converted to UTC in _formatDateForQuery
      final startOfDay = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      );
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final dayStart = _formatDateForQuery(startOfDay);
      final dayEnd = _formatDateForQuery(endOfDay);

      print('[OrdersScreen] Fetching orders from $dayStart to $dayEnd');

      final response = await _supabase
          .from('orders')
          .select('*, brands(name), profit')
          .gte('created_at', dayStart)
          .lt('created_at', dayEnd)
          .order('created_at', ascending: false);
      print('[OrdersScreen] Fetched ${(response as List).length} orders');
      return (response as List)
          .map((data) => app_order.Order.fromJson(data as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (mounted) _showErrorSnackBar('Error fetching orders: $e');
      print('[OrdersScreen] Error fetching orders: $e');
      return [];
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
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
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  String _deriveStatusBucket(app_order.Order o) {
    final s = o.status.toLowerCase();
    final ds = (o.deliveryStatus ?? '').toLowerCase();
    if (s.contains('cancelled')) return 'cancelled';
    if (s == 'delivered' || s == 'completed' || ds == 'delivered') {
      return 'delivered';
    }
    if (s == 'ready' || ds == 'ready_to_deliver' || ds == 'out_for_delivery') {
      return 'delivering';
    }
    // Pending/confirmed/preparing/unknown fall under preparing bucket
    return 'preparing';
  }

  List<app_order.Order> _filterOrders(List<app_order.Order> orders) {
    List<app_order.Order> filteredOrders = orders;

    // Search filter
    if (_searchQuery.isNotEmpty) {
      filteredOrders = filteredOrders.where((order) {
        final searchLower = _searchQuery.toLowerCase();
        return (order.id?.toLowerCase().contains(searchLower) ?? false) ||
            (order.brandName?.toLowerCase().contains(searchLower) ?? false) ||
            (order.orderTypeName?.toLowerCase().contains(searchLower) ?? false);
      }).toList();
    }

    // Brand filter
    if (_selectedBrandFilter != 'all') {
      filteredOrders = filteredOrders
          .where((order) => order.brandId == _selectedBrandFilter)
          .toList();
    }

    // Status filter
    if (_selectedStatusFilter != 'all') {
      filteredOrders = filteredOrders.where((order) {
        final bucket = _deriveStatusBucket(order);
        // Accept both explicit status and derived bucket match
        if (_selectedStatusFilter == 'cancelled') {
          return bucket == 'cancelled';
        }
        if (_selectedStatusFilter == 'delivering') {
          return bucket == 'delivering';
        }
        if (_selectedStatusFilter == 'delivered') {
          return bucket == 'delivered';
        }
        if (_selectedStatusFilter == 'preparing') {
          return bucket == 'preparing';
        }
        return true;
      }).toList();
    }

    return filteredOrders;
  }

  Color _getStatusColor(String? status) {
    if (status == null) return Colors.grey.shade400;
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange.shade600;
      case 'confirmed':
        return Colors.blue.shade600;
      case 'preparing':
        return Colors.purple.shade600;
      case 'ready':
        return Colors.teal.shade500;
      case 'delivered':
        return Colors.green.shade700;
      case 'cancelled':
      case 'cancelled_stock_returned':
      case 'cancelled_discarded':
        return Colors.red.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  Widget _buildStatusBadge(String? status) {
    final color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.8)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        status?.replaceAll('_', ' ').toUpperCase() ?? 'UNKNOWN',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildStatusBadgeCompact(String? status) {
    final color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        (status ?? 'unknown').split('_').first.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStatusDot(String? status) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: _getStatusColor(status),
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildBrandSidebar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Clean header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
            child: Row(
              children: [
                const Text(
                  'Orders',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                const Spacer(),
                AnimatedBuilder(
                  animation: _refreshController,
                  builder: (context, child) => Transform.rotate(
                    angle: _refreshRotation.value,
                    child: IconButton(
                      icon: Icon(
                        Icons.refresh_rounded,
                        color: Colors.grey[400],
                        size: 20,
                      ),
                      onPressed: _loadAllData,
                      tooltip: 'Refresh',
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Inline stats
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Row(
              children: [
                _buildStatChip(
                  icon: Icons.receipt_long_outlined,
                  label: _isLoadingTodayStats
                      ? '...'
                      : '$_todayOrderCount orders',
                  color: const Color(0xFF4F46E5),
                ),
                const SizedBox(width: 8),
                _buildStatChip(
                  icon: Icons.euro_rounded,
                  label: _isLoadingTodayStats
                      ? '...'
                      : '€${_todayTotalRevenue.toStringAsFixed(2)}',
                  color: const Color(0xFF059669),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFE5E7EB)),

          // Brand list
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _brandCardData.length,
              separatorBuilder: (_, __) => const SizedBox.shrink(),
              itemBuilder: (context, index) {
                final brand = _brandCardData[index];
                return InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => OrderableBrandMenuScreen(
                          brandId: brand['id'] as String,
                          brandName: brand['name'] as String,
                        ),
                      ),
                    ).then((value) {
                      if (mounted) _loadAllData();
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: const Color(0xFFF3F4F6),
                          ),
                          child: brand['imageUrl'] != null &&
                                  (brand['imageUrl'] as String).isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.asset(
                                    brand['imageUrl'] as String,
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Icon(
                                  Icons.storefront_outlined,
                                  size: 20,
                                  color: Colors.grey[400],
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            brand['name'] as String,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF374151),
                            ),
                          ),
                        ),
                        Icon(
                          Icons.add_rounded,
                          size: 18,
                          color: Colors.grey[400],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
            ).copyWith(bottom: 8),
            child: Text(
              'Create New Order',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          SizedBox(
            height: 110,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _brandCardData.length,
              itemBuilder: (context, index) {
                final brand = _brandCardData[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: SizedBox(
                    width: 100,
                    child: CategoryCard(
                      categoryName: brand['name'] as String,
                      imageUrl: brand['imageUrl'] as String,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => OrderableBrandMenuScreen(
                              brandId: brand['id'] as String,
                              brandName: brand['name'] as String,
                            ),
                          ),
                        ).then((value) {
                          if (mounted) _loadAllData();
                        });
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterBar() {
    final List<Map<String, dynamic>> brandFilters = [
      {'value': 'all', 'label': 'All Brands', 'id': 'all'},
      ..._brandCardData.map(
        (b) => {'value': b['id'], 'label': b['name'], 'id': b['id']},
      ),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.search, color: Colors.grey[700], size: 20),
              const SizedBox(width: 8),
              Text(
                'Search & Filter Orders',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                tooltip: 'Settings',
                onPressed: () async {
                  await showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => const OrdersSettingsSheet(),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by order ID, brand name, or order type...',
              hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
              prefixIcon: Icon(Icons.search, color: Colors.grey[600], size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.clear,
                        color: Colors.grey[600],
                        size: 20,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.indigo[400]!, width: 2),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 16,
                horizontal: 16,
              ),
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Filter by Brand',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 36,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: brandFilters.length,
                        itemBuilder: (context, index) {
                          final filter = brandFilters[index];
                          final isSelected =
                              _selectedBrandFilter == filter['id'];
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () => setState(
                                () => _selectedBrandFilter =
                                    filter['id'] as String,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  gradient: isSelected
                                      ? LinearGradient(
                                          colors: [
                                            Colors.indigo[600]!,
                                            Colors.indigo[400]!,
                                          ],
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                        )
                                      : null,
                                  color: isSelected ? null : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.indigo[400]!
                                        : Colors.grey[300]!,
                                  ),
                                ),
                                child: Text(
                                  filter['label'] as String,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.grey[700],
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Filter by Status',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 36,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _statusFilters.length,
                        itemBuilder: (context, index) {
                          final filter = _statusFilters[index];
                          final isSelected =
                              _selectedStatusFilter == filter['value'];
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () => setState(
                                () => _selectedStatusFilter = filter['value']!,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  gradient: isSelected
                                      ? LinearGradient(
                                          colors: [
                                            Colors.purple[600]!,
                                            Colors.purple[400]!,
                                          ],
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                        )
                                      : null,
                                  color: isSelected ? null : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.purple[400]!
                                        : Colors.grey[300]!,
                                  ),
                                ),
                                child: Text(
                                  filter['label']!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.grey[700],
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_searchQuery.isNotEmpty ||
              _selectedBrandFilter != 'all' ||
              _selectedStatusFilter != 'all') ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.grey[600]!, Colors.grey[400]!],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                          _selectedBrandFilter = 'all';
                          _selectedStatusFilter = 'all';
                        });
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.clear_all,
                              color: Colors.white,
                              size: 16,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Clear All',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
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

  Widget _getOrderTypeLogo(String? orderTypeName) {
    String? logoPath;
    if (orderTypeName == null) {
      return Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.receipt_long_outlined,
          size: 18,
          color: Colors.grey.shade600,
        ),
      );
    }
    final lowerOrderTypeName = orderTypeName.toLowerCase();
    if (lowerOrderTypeName.contains('lieferando')) {
      logoPath = 'assets/ordertypes/lieferando.png';
    } else if (lowerOrderTypeName.contains('foodora'))
      logoPath = 'assets/ordertypes/Foodora.png';
    else if (lowerOrderTypeName.contains('ninja'))
      logoPath = 'assets/ordertypes/ninjas.jpeg';
    else if (lowerOrderTypeName.contains('wolt'))
      logoPath = 'assets/ordertypes/wolt-logo.png';
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: logoPath != null
            ? Image.asset(logoPath, fit: BoxFit.contain)
            : Icon(
                Icons.delivery_dining_outlined,
                size: 18,
                color: Colors.blueGrey.shade400,
              ),
      ),
    );
  }

  Widget _getBrandLogo(String? brandId, String? brandName) {
    Map<String, dynamic>? brandData;
    for (var brand in _brandCardData) {
      if ((brandId != null && brand['id'] == brandId) ||
          (brandName != null && brand['name'] == brandName)) {
        brandData = brand;
        break;
      }
    }
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child:
            brandData != null &&
                brandData['imageUrl'] != null &&
                (brandData['imageUrl'] as String).isNotEmpty
            ? Image.asset(
                brandData['imageUrl'] as String,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Icon(
                  Icons.storefront,
                  size: 18,
                  color: Colors.grey.shade400,
                ),
              )
            : Icon(Icons.storefront, size: 18, color: Colors.grey.shade400),
      ),
    );
  }


  Widget _buildOrdersListWidget() {
    if (_isLoadingTodayStats) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadedOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No orders found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Apply search, brand, and status filters first
        final filteredOrders = _loadedOrders.where((order) {
          if (_selectedBrandFilter != 'all' &&
              order.brandId != _selectedBrandFilter) {
            return false;
          }
          if (_selectedStatusFilter != 'all' &&
              order.status != _selectedStatusFilter) {
            return false;
          }
          if (_searchQuery.isNotEmpty) {
            final query = _searchQuery.toLowerCase();
            final matchesRef = order.orderNumber?.toLowerCase().contains(query) ?? false;
            final matchesPubRef = order.publicReference?.toLowerCase().contains(query) ?? false;
            final matchesName = order.customerName?.toLowerCase().contains(query) ?? false;
            final matchesId = order.id?.toLowerCase().contains(query) ?? false;
            if (!matchesRef && !matchesPubRef && !matchesName && !matchesId) {
              return false;
            }
          }
          return true;
        }).toList();
        
        // Map states to tabs
        List<app_order.Order> prepare = [];
        List<app_order.Order> handover = [];
        List<app_order.Order> done = [];
        
        for (var o in filteredOrders) {
          final s = o.status;
          if (s == 'completed' || s == 'delivered' || s == 'paid' || s == 'completed_employee_meal' || s.startsWith('cancelled')) {
            done.add(o);
          } else if (s == 'delivering' || s == 'driver_assigned' || s == 'ready_for_pickup') {
            handover.add(o);
          } else {
            prepare.add(o);
          }
        }
        
        List<app_order.Order> currentTabOrders = [];
        if (_selectedTab == 'Prepare') {
          currentTabOrders = prepare;
        } else if (_selectedTab == 'Handover') {
          currentTabOrders = handover;
        } else if (_selectedTab == 'Done') {
          currentTabOrders = done;
        }

        int cols;
        final w = MediaQuery.of(context).size.width;
        if (w > 1600) {
          cols = 4;
        } else if (w > 1200)
          cols = 3;
        else if (w > 800)
          cols = 2;
        else
          cols = 1;

        final slivers = <Widget>[];

        // Custom iOS-style Segmented Control
        slivers.add(
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: ['Prepare', 'Handover', 'Done'].map((tab) {
                  final isSelected = _selectedTab == tab;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = tab),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  )
                                ]
                              : [],
                        ),
                        child: Center(
                          child: Text(
                            tab,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              color: isSelected ? Colors.black87 : Colors.grey.shade500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        );

        if (currentTabOrders.isEmpty) {
          slivers.add(
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text('No orders in this status', style: TextStyle(color: Colors.grey)),
              ),
            ),
          );
        } else {
          if (w <= 800) {
            // Mobile: single vertical list of full-width cards
            slivers.add(
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildOrderGridTile(currentTabOrders[index]),
                    childCount: currentTabOrders.length,
                  ),
                ),
              ),
            );
          } else {
            // Web/desktop: original grid layout
            slivers.add(
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: w > 1600 ? 2.0 : (w > 1200 ? 1.6 : (w > 800 ? 1.4 : 1.2)),
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildOrderGridTile(currentTabOrders[index]),
                    childCount: currentTabOrders.length,
                  ),
                ),
              ),
            );
          }
        }

        return CustomScrollView(slivers: slivers);
      },
    );
  }

  Widget _buildOrderGridTile(app_order.Order order) {
    int? minutesLeft;
    bool isOverdue = false;
    String etaText = '';

    final targetTime = order.estimatedDeliveryTime ?? order.estimatedPickupTime;
    if (targetTime != null) {
      final now = DateTime.now();
      minutesLeft = targetTime.difference(now).inMinutes;
      isOverdue = minutesLeft < 0;
      etaText = 'Est. ${DateFormat('HH:mm').format(targetTime.toLocal())}';
    }

    final bool isPickup = order.fulfillmentType == 'pickup';
    final bool isCash = (order.paymentMethod?.toLowerCase() ?? '') == 'cash';

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(color: Colors.grey[200]!, width: 1),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OrderDetailScreen(order: order),
                  ),
                ).then((result) {
                  if (result == true && mounted) {
                    _loadAllData();
                  }
                });
              },
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ROW 1: Customer Name & ETA
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                order.customerName ?? 'Unknown Customer',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (order.customerStreet != null && order.customerStreet!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${order.customerStreet}${order.customerCity != null ? ', ${order.customerCity}' : ''}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade600,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      InkWell(
                                        onTap: () async {
                                          final query = Uri.encodeComponent('${order.customerStreet}, ${order.customerCity ?? ''}');
                                          final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
                                          if (await canLaunchUrl(url)) {
                                            await launchUrl(url);
                                          } else {
                                            if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open Maps')));
                                            }
                                          }
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.all(4.0),
                                          child: Image.network(
                                            'https://upload.wikimedia.org/wikipedia/commons/thumb/a/aa/Google_Maps_icon_%282020%29.svg/512px-Google_Maps_icon_%282020%29.svg.png',
                                            width: 18,
                                            height: 18,
                                            errorBuilder: (c, e, s) => const Icon(Icons.map, size: 18, color: Colors.blue),
                                          ),
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () {
                                          Clipboard.setData(ClipboardData(text: '${order.customerStreet}, ${order.customerCity ?? ''}'));
                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Address copied!'), duration: Duration(seconds: 2)));
                                        },
                                        child: const Padding(
                                          padding: EdgeInsets.all(4.0),
                                          child: Icon(Icons.copy, size: 16, color: Colors.grey),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (targetTime != null) ...[
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                etaText,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isOverdue ? Colors.red.shade50 : Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isOverdue ? Colors.red.shade200 : Colors.green.shade200,
                                  ),
                                ),
                                child: Text(
                                  isOverdue ? '$minutesLeft min' : '$minutesLeft min left',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isOverdue ? Colors.red.shade700 : Colors.green.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // ROW 2: Platform, Reference, Total & Cash
                    Row(
                      children: [
                        _getOrderTypeLogo(order.orderTypeName),
                        const SizedBox(width: 8),
                        Text(
                          order.publicReference != null ? '#${order.publicReference}' : (order.id?.substring(0, 8) ?? ''),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        const Spacer(),
                        if (isCash) ...[
                          Icon(Icons.money, size: 18, color: Colors.red.shade600),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          '€${order.totalPrice.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderDetailCard(
    String label,
    String value,
    IconData icon,
    List<Color> gradientColors,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCompactHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // First row: Title, Stats, and Action buttons
          Row(
            children: [
              // Dashboard title and icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.indigo[600]!, Colors.indigo[400]!],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.dashboard,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),

              // Title
              const Text(
                'Orders Dashboard',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(width: 24),

              // Today's stats - compact
              if (!_isLoadingTodayStats) ...[
                _buildCompactStatCard(
                  Icons.receipt_long,
                  _todayOrderCount.toString(),
                  'Orders',
                  [Colors.blue[600]!, Colors.blue[400]!],
                ),
                const SizedBox(width: 12),
                _buildCompactStatCard(
                  Icons.euro,
                  '€${_todayTotalRevenue.toStringAsFixed(0)}',
                  'Revenue',
                  [Colors.green[600]!, Colors.green[400]!],
                ),
              ] else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text('Loading stats...', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),

              const Spacer(),

              // Action buttons - compact
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue[600]!, Colors.blue[400]!],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DeliveryMonitorScreen(
                          // activeDrivers: _activeDrivers, // Removed
                          supabaseClient: _supabase,
                        ),
                      ),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.delivery_dining,
                            color: Colors.white,
                            size: 16,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Delivery',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.indigo[600]!, Colors.indigo[400]!],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: _isGeneratingSummary
                        ? null
                        : _handleGenerateDailySummary,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedBuilder(
                            animation: _refreshRotation,
                            builder: (context, child) {
                              return Transform.rotate(
                                angle: _isGeneratingSummary
                                    ? _refreshRotation.value
                                    : 0,
                                child: Icon(
                                  _isGeneratingSummary
                                      ? Icons.hourglass_empty
                                      : Icons.picture_as_pdf,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isGeneratingSummary ? 'Generating...' : 'Summary',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Second row: Search and filters - more compact
          _buildCompactSearchAndFilters(),
        ],
      ),
    );
  }

  Widget _buildCompactStatCard(
    IconData icon,
    String value,
    String label,
    List<Color> gradientColors,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtonsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () async {
              await showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => const OrdersSettingsSheet(),
              );
            },
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue[600]!, Colors.blue[400]!],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () async {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          DeliveryMonitorScreen(supabaseClient: _supabase),
                    ),
                  );
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.delivery_dining,
                        color: Colors.white,
                        size: 18,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Delivery Monitor',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.indigo[600]!, Colors.indigo[400]!],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.indigo.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: _isGeneratingSummary
                    ? null
                    : _handleGenerateDailySummary,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedBuilder(
                        animation: _refreshRotation,
                        builder: (context, child) {
                          return Transform.rotate(
                            angle: _isGeneratingSummary
                                ? _refreshRotation.value
                                : 0,
                            child: Icon(
                              _isGeneratingSummary
                                  ? Icons.hourglass_empty
                                  : Icons.picture_as_pdf,
                              color: Colors.white,
                              size: 18,
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isGeneratingSummary
                            ? 'Generating...'
                            : 'Daily Summary',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16, right: 16, top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Search & Filters', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search orders, customers...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
              ),
              const SizedBox(height: 16),
              const Text('Brand', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedBrandFilter,
                    items: [
                      const DropdownMenuItem(value: 'all', child: Text('All Brands')),
                      ..._brandCardData.map((b) => DropdownMenuItem(value: b['id'] as String, child: Text(b['name'] as String))),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedBrandFilter = val);
                      Navigator.pop(context);
                      _showFilterSheet(); // reopen to reflect state, or just let it close
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Status', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedStatusFilter,
                    items: _statusFilters.map((s) => DropdownMenuItem(value: s['value'], child: Text(s['label']!))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedStatusFilter = val);
                      Navigator.pop(context);
                      _showFilterSheet();
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  backgroundColor: Colors.blue[700],
                ),
                child: const Text('Apply', style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      }
    );
  }


  Widget _buildDateNavigator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: _goToPreviousDay,
                  child: const Icon(Icons.chevron_left, color: Colors.black87, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  _getDateLabel(),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _isToday() ? null : _goToNextDay,
                  child: Icon(Icons.chevron_right, color: _isToday() ? Colors.grey.shade400 : Colors.black87, size: 20),
                ),
              ],
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterSheet,
            tooltip: 'Search & Filters',
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade300),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactSearchAndFilters() {
    final List<Map<String, dynamic>> brandFilters = [
      {'value': 'all', 'label': 'All Brands', 'id': 'all'},
      ..._brandCardData.map(
        (b) => {'value': b['id'], 'label': b['name'], 'id': b['id']},
      ),
    ];

    return Row(
      children: [
        // Search field - more compact
        Expanded(
          flex: 3,
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search orders...',
              hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
              prefixIcon: Icon(Icons.search, color: Colors.grey[600], size: 18),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.clear,
                        color: Colors.grey[600],
                        size: 18,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.indigo[400]!, width: 2),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 12,
                horizontal: 12,
              ),
              isDense: true,
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
        ),

        const SizedBox(width: 12),

        // Brand filter - compact
        Expanded(
          flex: 2,
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey.shade50,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedBrandFilter,
                isExpanded: true,
                icon: Icon(
                  Icons.arrow_drop_down,
                  color: Colors.grey[600],
                  size: 20,
                ),
                style: TextStyle(color: Colors.grey[700], fontSize: 14),
                onChanged: (String? newValue) {
                  setState(() => _selectedBrandFilter = newValue!);
                },
                items: brandFilters.map<DropdownMenuItem<String>>((filter) {
                  return DropdownMenuItem<String>(
                    value: filter['id'] as String,
                    child: Text(
                      filter['label'] as String,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),

        const SizedBox(width: 12),

        // Status filter - compact
        Expanded(
          flex: 2,
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey.shade50,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedStatusFilter,
                isExpanded: true,
                icon: Icon(
                  Icons.arrow_drop_down,
                  color: Colors.grey[600],
                  size: 20,
                ),
                style: TextStyle(color: Colors.grey[700], fontSize: 14),
                onChanged: (String? newValue) {
                  setState(() => _selectedStatusFilter = newValue!);
                },
                items: _statusFilters.map<DropdownMenuItem<String>>((filter) {
                  return DropdownMenuItem<String>(
                    value: filter['value']!,
                    child: Text(
                      filter['label']!,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),

        if (_searchQuery.isNotEmpty ||
            _selectedBrandFilter != 'all' ||
            _selectedStatusFilter != 'all') ...[
          const SizedBox(width: 12),
          Container(
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.grey[600]!, Colors.grey[400]!],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  setState(() {
                    _searchController.clear();
                    _searchQuery = '';
                    _selectedBrandFilter = 'all';
                    _selectedStatusFilter = 'all';
                  });
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.clear_all, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Clear',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ── Scanner Status Widgets ────────────────────────────────────
  Widget _buildSidebarScannerStatus() {
    final hasAnyScanners = _remoteScanners.isNotEmpty;
    final onlineScanners =
        _remoteScanners.where((s) => s.isOnline).toList();
    final allOnline = hasAnyScanners && onlineScanners.length == _remoteScanners.length;
    final someOnline = onlineScanners.isNotEmpty;

    final Color statusColor = allOnline
        ? Colors.green
        : someOnline
            ? Colors.orange
            : Colors.red;
    final String statusLabel = !hasAnyScanners
        ? 'No Scanners'
        : allOnline
            ? '${onlineScanners.length} Online'
            : someOnline
                ? '${onlineScanners.length}/${_remoteScanners.length} Online'
                : 'All Offline';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(
              () => _scannerStatusExpanded = !_scannerStatusExpanded,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  // Animated pulsing dot
                  _AnimatedStatusDot(color: statusColor, pulse: someOnline),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Receipt Scanner',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 11,
                            color: statusColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _scannerStatusExpanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    size: 20,
                    color: Colors.grey[500],
                  ),
                ],
              ),
            ),
          ),
          // Expanded detail section
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _scannerStatusExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Column(
              children: [
                Divider(height: 1, color: Colors.grey[200]),
                if (!hasAnyScanners)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'No scanners registered yet.',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  )
                else
                  ..._remoteScanners.map((s) => _buildScannerDetailRow(s)),
              ],
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerDetailRow(RemoteScannerStatus s) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: s.isOnline ? Colors.green : Colors.red.shade400,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.scannerName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${s.hostname} • ${s.isOnline ? 'Online' : 'Last seen ${timeago.format(s.lastHeartbeat)}'}',
                  style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileScannerPill() {
    final onlineScanners =
        _remoteScanners.where((s) => s.isOnline).toList();
    final hasAnyScanners = _remoteScanners.isNotEmpty;
    final allOnline = hasAnyScanners &&
        onlineScanners.length == _remoteScanners.length;
    final someOnline = onlineScanners.isNotEmpty;

    final Color statusColor = allOnline
        ? Colors.green
        : someOnline
            ? Colors.orange
            : Colors.red;
    final String label = !hasAnyScanners
        ? 'No Scanner'
        : allOnline
            ? 'Scanner Online'
            : someOnline
                ? 'Partial'
                : 'Scanner Offline';

    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) => _buildScannerBottomSheet(),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: statusColor.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _AnimatedStatusDot(color: statusColor, pulse: someOnline, size: 7),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color.lerp(statusColor, Colors.black, 0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScannerBottomSheet() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Receipt Scanner Status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (_remoteScanners.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(Icons.scanner, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text(
                        'No scanners registered.',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              )
            else
              ..._remoteScanners.map((s) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: s.isOnline
                          ? Colors.green.withOpacity(0.05)
                          : Colors.red.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: s.isOnline
                            ? Colors.green.withOpacity(0.2)
                            : Colors.red.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: s.isOnline ? Colors.green : Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.scannerName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Host: ${s.hostname}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                s.isOnline
                                    ? 'Online'
                                    : 'Last seen ${timeago.format(s.lastHeartbeat)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: s.isOnline
                                      ? Colors.green[700]
                                      : Colors.red[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (s.watchPath.isNotEmpty)
                                Text(
                                  'Path: ${s.watchPath}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[500],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      // appBar: AppBar(...), // AppBar removed
      body: LayoutBuilder(
        builder: (context, constraints) {
          const double webBreakpoint = 720.0;
          if (constraints.maxWidth > webBreakpoint) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: constraints.maxWidth * 0.25,
                  child: _buildBrandSidebar(),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildActionButtonsRow(), // Added action buttons
                      _buildDateNavigator(), // Date navigation

                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          20,
                          8,
                          20,
                          8,
                        ), // Adjusted top padding
                        child: Row(
                          children: [
                            Icon(
                              Icons.list_alt,
                              color: Colors.grey[700],
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Orders for ${_getDateLabel()}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                            const Spacer(),
                            if (!_isLoadingTodayStats) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.blue[200]!),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.receipt_long,
                                      size: 14,
                                      color: Colors.blue[700],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$_todayOrderCount orders',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.blue[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green[50],
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.green[200]!),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.euro,
                                      size: 14,
                                      color: Colors.green[700],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '€${_todayTotalRevenue.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.green[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Expanded(child: _buildOrdersListWidget()),
                    ],
                  ),
                ),
              ],
            );
          } else {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top bar with title, scanner pill, and action buttons (mobile)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                  child: Row(
                    children: [
                      const Text(
                        'Orders',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 10),
                      _buildMobileScannerPill(),
                      const Spacer(),
                      // Quick actions inline
                      IconButton(
                        icon: Icon(Icons.map_outlined,
                            size: 22, color: Colors.blue[600]),
                        tooltip: 'Delivery Monitor',
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DeliveryMonitorScreen(
                                supabaseClient: _supabase),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.picture_as_pdf,
                            size: 20, color: Colors.indigo[600]),
                        tooltip: 'Daily Summary',
                        onPressed: _isGeneratingSummary
                            ? null
                            : _handleGenerateDailySummary,
                      ),
                      IconButton(
                        icon: AnimatedBuilder(
                          animation: _refreshController,
                          builder: (context, child) => Transform.rotate(
                            angle: _refreshRotation.value,
                            child: Icon(Icons.refresh,
                                size: 20, color: Colors.grey[600]),
                          ),
                        ),
                        tooltip: 'Refresh',
                        onPressed: _loadAllData,
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        tooltip: 'Create Order',
                        onPressed: () => setState(
                          () =>
                              _showBrandPickerMobile = !_showBrandPickerMobile,
                        ),
                      ),
                    ],
                  ),
                ),

                // Dropdown brand row appears when + is pressed
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 200),
                  crossFadeState: _showBrandPickerMobile
                      ? CrossFadeState.showFirst
                      : CrossFadeState.showSecond,
                  firstChild: SizedBox(
                    height: 120,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _brandCardData.length,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemBuilder: (context, index) {
                        final brand = _brandCardData[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: SizedBox(
                            width: 140,
                            child: CategoryCard(
                              categoryName: brand['name'] as String,
                              imageUrl: brand['imageUrl'] as String,
                              onTap: () {
                                setState(() => _showBrandPickerMobile = false);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => OrderableBrandMenuScreen(
                                      brandId: brand['id'] as String,
                                      brandName: brand['name'] as String,
                                    ),
                                  ),
                                ).then((_) {
                                  if (mounted) _loadAllData();
                                });
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  secondChild: const SizedBox.shrink(),
                ),

                // Date navigation for mobile
                _buildDateNavigator(),

                // Search/filters and list header


                // Orders list
                Expanded(child: _buildOrdersListWidget()),
              ],
            );
          }
        },
      ),
    );
  }

  void _showCancelOrderDialog(app_order.Order order) {
    if (order.id == null) {
      _showErrorSnackBar('Cannot cancel order without an ID.');
      return;
    }
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange[600]),
              const SizedBox(width: 8),
              Text('Cancel Order ${order.id!.substring(0, 8)}...?'),
            ],
          ),
          content: const Text('How would you like to cancel this order?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Keep Order'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Cancel & Discard Items'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _handleCancelOrder(order, returnStock: false);
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Cancel & Return Stock'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _handleCancelOrder(order, returnStock: true);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleCancelOrder(
    app_order.Order order, {
    required bool returnStock,
  }) async {
    if (order.id == null) return;
    setState(() => _isCancellingOrder = true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Padding(
          padding: EdgeInsets.all(24.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text("Cancelling order..."),
            ],
          ),
        ),
      ),
    );
    try {
      await _orderService.cancelOrder(order.id!, returnStock);
      if (mounted) {
        Navigator.of(context).pop();
        _showSuccessSnackBar(
          'Order ${order.id!.substring(0, 8)} cancelled successfully.',
        );
        _loadAllData();
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        _showErrorSnackBar('Failed to cancel order: $e');
      }
    } finally {
      if (mounted) setState(() => _isCancellingOrder = false);
    }
  }

  Future<void> _handleGenerateDailySummary() async {
    if (!mounted) return;
    setState(() => _isGeneratingSummary = true);
    try {
      final summaryService = DailySummaryService();
      final pdfGenerator = PdfGenerator();
      final today = DateTime.now();
      final summaryData = await summaryService.generateDailySummary(today);
      final DateFormat docNameFormatter = DateFormat('yyyy-MM-dd');
      final String documentName =
          'Daily_Summary_${docNameFormatter.format(today)}.pdf';
      if (mounted) {
        await pdfGenerator.generateAndShowDailySummaryPdf(
          summaryData,
          documentName,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating summary PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      print('[OrdersScreen] Error generating daily summary PDF: $e');
    } finally {
      if (mounted) setState(() => _isGeneratingSummary = false);
    }
  }
}

/// A small animated pulsing dot used to indicate scanner online/offline status.
class _AnimatedStatusDot extends StatefulWidget {
  final Color color;
  final bool pulse;
  final double size;

  const _AnimatedStatusDot({
    required this.color,
    this.pulse = false,
    this.size = 10,
  });

  @override
  State<_AnimatedStatusDot> createState() => _AnimatedStatusDotState();
}

class _AnimatedStatusDotState extends State<_AnimatedStatusDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    if (widget.pulse) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _AnimatedStatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulse && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.pulse && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) => Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: widget.color.withOpacity(
            widget.pulse ? _animation.value : 1.0,
          ),
          shape: BoxShape.circle,
          boxShadow: widget.pulse
              ? [
                  BoxShadow(
                    color: widget.color.withOpacity(0.4 * _animation.value),
                    blurRadius: widget.size * 0.8,
                    spreadRadius: widget.size * 0.2,
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}
