import 'dart:async';
import 'package:restaurantadmin/screens/widgets/orders_settings_sheet.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:restaurantadmin/models/order.dart' as app_order;
import 'package:restaurantadmin/widgets/category_card.dart';
import 'package:restaurantadmin/screens/orderable_brand_menu_screen.dart';
import 'package:restaurantadmin/screens/order_detail_screen.dart';
import 'package:restaurantadmin/services/order_service.dart';
import 'package:restaurantadmin/services/daily_summary_service.dart';
import 'package:restaurantadmin/utils/pdf_generator.dart';
import 'package:restaurantadmin/models/driver.dart';
import 'package:restaurantadmin/screens/delivery_monitor_screen.dart';
import 'package:restaurantadmin/widgets/global_order_listener.dart';

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

  List<Driver> _activeDrivers = [];
  List<app_order.Order> _deliveryOrders = [];

  // Date navigation
  late DateTime _selectedDate;

  int _todayOrderCount = 0;
  double _todayTotalRevenue = 0.0;
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
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-${day}T00:00:00';
  }

  Future<void> _fetchTodayStats() async {
    if (!mounted) return;
    try {
      final startOfDay = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      );
      final endOfDay = startOfDay.add(const Duration(days: 1));

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
          revenue += (orderMap['total_price'] as num?)?.toDouble() ?? 0.0;
        }
      }
      setState(() {
        _todayOrderCount = count;
        _todayTotalRevenue = revenue;
        _isLoadingTodayStats = false;
      });
    } catch (e) {
      print('Error fetching stats: $e');
      if (mounted) {
        _showErrorSnackBar('Error fetching stats: $e');
        setState(() {
          _isLoadingTodayStats = false;
          _todayOrderCount = 0;
          _todayTotalRevenue = 0.0;
        });
      }
    }
  }

  Future<List<app_order.Order>> _fetchOrders() async {
    try {
      final startOfDay = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      );
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final dayStart = _formatDateForQuery(startOfDay);
      final dayEnd = _formatDateForQuery(endOfDay);

      final response = await _supabase
          .from('orders')
          .select('*, brands(name), profit')
          .gte('created_at', dayStart)
          .lt('created_at', dayEnd)
          .order('created_at', ascending: false);
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
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with stats
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.indigo[600]!, Colors.indigo[400]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.receipt_long,
                      color: Colors.white,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Orders',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    AnimatedBuilder(
                      animation: _refreshController,
                      builder: (context, child) => Transform.rotate(
                        angle: _refreshRotation.value,
                        child: IconButton(
                          icon: const Icon(
                            Icons.refresh,
                            color: Colors.white70,
                            size: 22,
                          ),
                          onPressed: _loadAllData,
                          tooltip: 'Refresh',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isLoadingTodayStats
                                  ? '...'
                                  : '$_todayOrderCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _isToday() ? "Today's Orders" : 'Orders',
                              style: TextStyle(
                                color: Colors.blue[100],
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isLoadingTodayStats
                                  ? '...'
                                  : '€${_todayTotalRevenue.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Revenue',
                              style: TextStyle(
                                color: Colors.green[100],
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Create order section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create New Order',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Select a brand to start',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),

          // Brand list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 0,
              ),
              itemCount: _brandCardData.length,
              itemBuilder: (context, index) {
                final brand = _brandCardData[index];
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
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
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.grey.shade100,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child:
                                brand['imageUrl'] != null &&
                                    (brand['imageUrl'] as String).isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.asset(
                                      brand['imageUrl'] as String,
                                      width: 56,
                                      height: 56,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Icon(
                                    Icons.storefront_outlined,
                                    size: 28,
                                    color: Colors.grey.shade500,
                                  ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              brand['name'] as String,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.indigo[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.add,
                              size: 18,
                              color: Colors.indigo[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Quick actions footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(top: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Column(
              children: [
                ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          DeliveryMonitorScreen(supabaseClient: _supabase),
                    ),
                  ),
                  icon: const Icon(Icons.delivery_dining, size: 18),
                  label: const Text('Delivery Monitor'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _isGeneratingSummary
                      ? null
                      : _handleGenerateDailySummary,
                  icon: _isGeneratingSummary
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.picture_as_pdf, size: 18),
                  label: Text(
                    _isGeneratingSummary
                        ? 'Generating...'
                        : 'Daily Summary PDF',
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
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
    return RefreshIndicator(
      onRefresh: _loadAllData,
      color: Colors.indigo[600],
      child: FutureBuilder<List<app_order.Order>>(
        future: _ordersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              _animationController.value == 0.0) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const CircularProgressIndicator(),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Loading orders...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Container(
                margin: const EdgeInsets.all(16),
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                    const SizedBox(height: 16),
                    Text(
                      'Error Loading Orders',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.red[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      style: TextStyle(color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () =>
                          setState(() => _ordersFuture = _fetchOrders()),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo[600],
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Container(
                margin: const EdgeInsets.all(16),
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No Orders Found',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'New orders will appear here when placed.',
                      style: TextStyle(color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          final allOrders = snapshot.data!;
          final filteredOrders = _filterOrders(allOrders);
          if (filteredOrders.isEmpty &&
              (_searchQuery.isNotEmpty ||
                  _selectedBrandFilter != 'all' ||
                  _selectedStatusFilter != 'all')) {
            return Center(
              child: Container(
                margin: const EdgeInsets.all(16),
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'No Matching Orders',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Try adjusting your search terms or filters.',
                      style: TextStyle(color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => setState(() {
                        _searchController.clear();
                        _searchQuery = '';
                        _selectedBrandFilter = 'all';
                        _selectedStatusFilter = 'all';
                      }),
                      icon: const Icon(Icons.clear_all),
                      label: const Text('Clear Filters'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[600],
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // Group orders
          // Group orders by status (using both status and deliveryStatus)
          List<app_order.Order> preparing = filteredOrders.where((o) {
            final s = o.status.toLowerCase();
            return s == 'preparing' || s == 'confirmed' || s == 'pending';
          }).toList();

          List<app_order.Order> delivering = filteredOrders.where((o) {
            final s = o.status.toLowerCase();
            final ds = (o.deliveryStatus ?? '').toLowerCase();
            return s == 'ready' ||
                ds == 'ready_to_deliver' ||
                ds == 'out_for_delivery';
          }).toList();

          List<app_order.Order> delivered = filteredOrders.where((o) {
            final s = o.status.toLowerCase();
            final ds = (o.deliveryStatus ?? '').toLowerCase();
            return s == 'delivered' || s == 'completed' || ds == 'delivered';
          }).toList();

          List<app_order.Order> cancelled = filteredOrders
              .where((o) => o.status.toLowerCase().contains('cancelled'))
              .toList();

          // Fallback: if some orders didn't match any above, include them in Preparing
          final categorizedIds = <String?>{
            ...preparing.map((o) => o.id),
            ...delivering.map((o) => o.id),
            ...delivered.map((o) => o.id),
            ...cancelled.map((o) => o.id),
          };
          final leftovers = filteredOrders
              .where((o) => !categorizedIds.contains(o.id))
              .toList();
          if (leftovers.isNotEmpty) preparing = [...leftovers, ...preparing];

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

          List<Widget> buildSection(
            String title,
            List<app_order.Order> orders,
            Color color,
          ) {
            final widgets = <Widget>[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 16,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ];

            if (orders.isEmpty) {
              widgets.add(
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                      'No orders in this section',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                ),
              );
            } else {
              if (w <= 800) {
                // Mobile: single horizontal row per status with smaller tiles
                widgets.add(
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 124,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        itemCount: orders.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, index) => SizedBox(
                          width: 180,
                          child: _buildOrderGridTile(
                            orders[index],
                            compact: true,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              } else {
                // Web/desktop: original grid layout
                widgets.add(
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: w > 1600
                            ? 2.0
                            : (w > 1200 ? 1.6 : (w > 800 ? 1.4 : 1.2)),
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildOrderGridTile(orders[index]),
                        childCount: orders.length,
                      ),
                    ),
                  ),
                );
              }
            }

            return widgets;
          }

          final slivers = <Widget>[];

          // Optional pending banner at top

          slivers
            ..addAll(buildSection('Preparing', preparing, Colors.purple[600]!))
            ..addAll(buildSection('Delivering', delivering, Colors.teal[600]!))
            ..addAll(buildSection('Delivered', delivered, Colors.green[700]!))
            ..addAll(buildSection('Cancelled', cancelled, Colors.red[600]!));

          return CustomScrollView(slivers: slivers);
        },
      ),
    );
  }

  Widget _buildOrderGridTile(app_order.Order order, {bool compact = false}) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: compact ? 98 : 140,
            maxHeight: compact ? 120 : double.infinity,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OrderDetailScreen(order: order),
                    ),
                  ).then((result) {
                    // Refresh orders if order was modified (cancelled, etc.)
                    if (result == true && mounted) {
                      _loadAllData();
                    }
                  });
                },
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 8 : 12,
                    vertical: compact ? 6 : 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Transform.scale(
                            scale: compact ? 0.85 : 1.0,
                            child: _getBrandLogo(
                              order.brandId,
                              order.brandName,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  order.brandName ?? 'Unknown Brand',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: compact ? 12 : 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '#${order.id?.substring(0, 8) ?? ''} • ${DateFormat('MMM d, HH:mm').format(order.createdAt.toLocal())}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: compact ? 10 : 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          compact
                              ? _buildStatusBadgeCompact(order.status)
                              : _buildStatusBadge(order.status),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: compact ? 12 : 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              order.customerName ?? 'Unknown customer',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: compact ? 11 : 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (!compact) ...[
                            Row(
                              children: [
                                _getOrderTypeLogo(order.orderTypeName),
                                const SizedBox(width: 8),
                                Text(
                                  order.orderTypeName ?? 'Standard',
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ] else
                            Row(
                              children: [
                                _getOrderTypeLogo(order.orderTypeName),
                              ],
                            ),
                          Text(
                            '€${order.totalPrice.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
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
      ),
    );
  }

  Widget _buildOrderCard(app_order.Order order) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
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
                  // Refresh orders if order was modified (cancelled, etc.)
                  if (result == true && mounted) {
                    _loadAllData();
                  }
                });
              },
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with logos and status
                    Row(
                      children: [
                        // Order type logo
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: _getOrderTypeLogo(order.orderTypeName),
                        ),
                        const SizedBox(width: 12),

                        // Brand logo
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: _getBrandLogo(order.brandId, order.brandName),
                        ),
                        const SizedBox(width: 16),

                        // Order info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                order.brandName ?? 'Unknown Brand',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.tag,
                                    size: 14,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'ID: ${order.id?.substring(0, 8) ?? 'N/A'}...',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              if (order.fulfillmentType != null &&
                                  order.fulfillmentType!.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      order.fulfillmentType == 'delivery'
                                          ? Icons.delivery_dining
                                          : Icons.storefront,
                                      size: 14,
                                      color: Colors.blue[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.blue[50],
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.blue[200]!,
                                        ),
                                      ),
                                      child: Text(
                                        order.fulfillmentType![0]
                                                .toUpperCase() +
                                            order.fulfillmentType!.substring(1),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.blue[700],
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Status badge
                        _buildStatusBadge(order.status),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Divider
                    Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.grey[300]!,
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Order details in cards
                    Row(
                      children: [
                        Expanded(
                          child: _buildOrderDetailCard(
                            'Total Amount',
                            '€${order.totalPrice.toStringAsFixed(2)}',
                            Icons.euro,
                            [Colors.green[600]!, Colors.green[400]!],
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (order.profit != null)
                          Expanded(
                            child: _buildOrderDetailCard(
                              'Profit',
                              '€${order.profit!.toStringAsFixed(2)}',
                              Icons.trending_up,
                              order.profit! >= 0
                                  ? [Colors.teal[600]!, Colors.teal[400]!]
                                  : [Colors.red[600]!, Colors.red[400]!],
                            ),
                          ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildOrderDetailCard(
                            'Order Time',
                            DateFormat(
                              'HH:mm',
                            ).format(order.createdAt.toLocal()),
                            Icons.access_time,
                            [Colors.blue[600]!, Colors.blue[400]!],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Date and actions row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 14,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 6),
                              Text(
                                DateFormat(
                                  'MMM dd, yyyy',
                                ).format(order.createdAt.toLocal()),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Action menu
                        if (order.status != 'cancelled_stock_returned' &&
                            order.status != 'cancelled_discarded' &&
                            order.status != 'paid' &&
                            order.status != 'completed_employee_meal')
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
                              child: PopupMenuButton<String>(
                                icon: const Icon(
                                  Icons.more_vert,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                tooltip: "Order Actions",
                                onSelected: (value) {
                                  if (value == 'cancel') {
                                    _showCancelOrderDialog(order);
                                  }
                                },
                                itemBuilder: (BuildContext context) => [
                                  const PopupMenuItem<String>(
                                    value: 'cancel',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.cancel_outlined,
                                          color: Colors.red,
                                          size: 18,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Cancel Order',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
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

  Widget _buildDateNavigator() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDateOnly = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final isAtToday = selectedDateOnly.isAtSameMomentAs(today);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Previous day button
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              tooltip: 'Previous day',
              icon: const Icon(Icons.chevron_left, size: 24),
              onPressed: _goToPreviousDay,
            ),
          ),

          const SizedBox(width: 12),

          // Date display with calendar picker
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                setState(() => _selectedDate = picked);
                _loadAllData();
              }
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isToday()
                      ? [Colors.indigo[600]!, Colors.indigo[400]!]
                      : [Colors.grey[600]!, Colors.grey[400]!],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.calendar_today,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _getDateLabel(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      if (!_isToday())
                        Text(
                          DateFormat('yyyy').format(_selectedDate),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Next day button (disabled if at today)
          Container(
            decoration: BoxDecoration(
              color: isAtToday ? Colors.grey[200] : Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              tooltip: isAtToday ? 'Already at today' : 'Next day',
              icon: Icon(
                Icons.chevron_right,
                size: 24,
                color: isAtToday ? Colors.grey[400] : Colors.grey[700],
              ),
              onPressed: isAtToday ? null : _goToNextDay,
            ),
          ),

          const SizedBox(width: 8),

          // Jump to today button (only shown if not at today)
          if (!isAtToday)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green[600]!, Colors.green[400]!],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _goToToday,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.today, color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'Today',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'orders_screen_refresh_fab',
        onPressed: _loadAllData,
        icon: AnimatedBuilder(
          animation: _refreshController,
          builder: (context, child) => Transform.rotate(
            angle: _refreshRotation.value,
            child: const Icon(Icons.refresh),
          ),
        ),
        label: const Text('Refresh'),
      ),
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
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildCompactSearchAndFilters(),
                      ), // Added search/filters for wide screen
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
                // Top bar with title and Create Order (+) button (mobile only)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      const Text(
                        'Orders',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildCompactSearchAndFilters(),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Row(
                    children: [
                      Icon(Icons.list_alt, color: Colors.grey[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Orders for ${_getDateLabel()}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                      ),
                      if (!_isLoadingTodayStats)
                        Text(
                          '$_todayOrderCount • €${_todayTotalRevenue.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),

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
