import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:restaurantadmin/models/order.dart'
    as app_order; // Import app_order
import 'package:restaurantadmin/screens/auth/login_screen.dart'; // Import LoginScreen
import 'package:restaurantadmin/screens/order_detail_screen.dart'; // Import OrderDetailScreen
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:restaurantadmin/widgets/global_order_listener.dart'
    show OrderNotificationService;

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen>
    with TickerProviderStateMixin {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isRestoring = false;

  double? _todayProfit;
  double? _last7DaysProfit;
  double? _last30DaysProfit;
  double? _last3MonthsProfit;

  // Income (Revenue) overview
  double? _todayRevenue;
  double? _last7DaysRevenue;
  double? _last30DaysRevenue;
  double? _last3MonthsRevenue;

  // Purchases (expenses) overview
  double? _todayPurchases;
  double? _last7DaysPurchases;
  double? _last30DaysPurchases;
  double? _last3MonthsPurchases;

  DateTime _selectedMonth = DateTime.now();
  double? _selectedMonthProfit;
  double? _selectedMonthRevenue;
  double? _selectedMonthPurchases;
  List<app_order.Order> _selectedMonthOrders = [];
  bool _isLoadingProfits = true;
  bool _isLoadingMonthDetails = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
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

    _fetchAllProfitData();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Color _getColorShade(Color baseColor, int shade) {
    if (baseColor == Colors.blue) {
      return shade == 600 ? Colors.blue[600]! : Colors.blue[400]!;
    } else if (baseColor == Colors.green) {
      return shade == 600 ? Colors.green[600]! : Colors.green[400]!;
    } else if (baseColor == Colors.orange) {
      return shade == 600 ? Colors.orange[600]! : Colors.orange[400]!;
    } else if (baseColor == Colors.purple) {
      return shade == 600 ? Colors.purple[600]! : Colors.purple[400]!;
    }
    return baseColor;
  }

  Future<void> _fetchAllProfitData() async {
    setState(() => _isLoadingProfits = true);
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = todayStart.add(const Duration(days: 1));

      // Profits
      _todayProfit = await _fetchProfitForDateRange(todayStart, todayEnd);
      _last7DaysProfit = await _fetchProfitForDateRange(
        now.subtract(const Duration(days: 6)),
        now.add(const Duration(days: 1)),
      );
      _last30DaysProfit = await _fetchProfitForDateRange(
        now.subtract(const Duration(days: 29)),
        now.add(const Duration(days: 1)),
      );
      _last3MonthsProfit = await _fetchProfitForDateRange(
        DateTime(now.year, now.month - 3, now.day),
        now.add(const Duration(days: 1)),
      );

      // Revenue
      _todayRevenue = await _fetchRevenueForRange(todayStart, todayEnd);
      _last7DaysRevenue = await _fetchRevenueForRange(
        now.subtract(const Duration(days: 6)),
        now.add(const Duration(days: 1)),
      );
      _last30DaysRevenue = await _fetchRevenueForRange(
        now.subtract(const Duration(days: 29)),
        now.add(const Duration(days: 1)),
      );
      _last3MonthsRevenue = await _fetchRevenueForRange(
        DateTime(now.year, now.month - 3, now.day),
        now.add(const Duration(days: 1)),
      );

      // Purchases (expenses)
      _todayPurchases = await _fetchPurchasesForRange(todayStart, todayEnd);
      _last7DaysPurchases = await _fetchPurchasesForRange(
        now.subtract(const Duration(days: 6)),
        now.add(const Duration(days: 1)),
      );
      _last30DaysPurchases = await _fetchPurchasesForRange(
        now.subtract(const Duration(days: 29)),
        now.add(const Duration(days: 1)),
      );
      _last3MonthsPurchases = await _fetchPurchasesForRange(
        DateTime(now.year, now.month - 3, now.day),
        now.add(const Duration(days: 1)),
      );

      await _fetchProfitForSelectedMonth();
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error fetching profit data: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingProfits = false);
      }
    }
  }

  Future<double> _fetchProfitForDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final List<Map<String, dynamic>> response = await _supabase
          .from('orders')
          .select('profit')
          .gte('created_at', startDate.toIso8601String())
          .lt('created_at', endDate.toIso8601String());

      double totalProfit = 0;
      for (var row in response) {
        totalProfit += (row['profit'] as num?)?.toDouble() ?? 0.0;
      }
      return totalProfit;
    } catch (e) {
      debugPrint('Error fetching profit for range $startDate - $endDate: $e');
      throw Exception('Failed to fetch profit for range: $e');
    }
  }

  Future<double> _fetchRevenueForRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final List<Map<String, dynamic>> response = await _supabase
          .from('orders')
          .select('total_price')
          .gte('created_at', startDate.toIso8601String())
          .lt('created_at', endDate.toIso8601String());
      double total = 0;
      for (var row in response) {
        total += (row['total_price'] as num?)?.toDouble() ?? 0.0;
      }
      return total;
    } catch (e) {
      throw Exception('Failed to fetch revenue: $e');
    }
  }

  Future<double> _fetchPurchasesForRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final List<Map<String, dynamic>> response = await _supabase
          .from('purchases')
          .select('total_amount, receipt_date')
          .gte('receipt_date', startDate.toIso8601String())
          .lt('receipt_date', endDate.toIso8601String());
      double total = 0;
      for (var row in response) {
        total += (row['total_amount'] as num?)?.toDouble() ?? 0.0;
      }
      return total;
    } catch (e) {
      // If purchases table doesn't exist or RLS denies, default to 0 and surface message
      debugPrint('Purchases lookup failed: $e');
      return 0.0;
    }
  }

  Future<void> _fetchProfitForSelectedMonth() async {
    if (!mounted) return;
    setState(() {
      _isLoadingMonthDetails = true;
      _selectedMonthOrders = [];
      _selectedMonthProfit = null;
    });

    try {
      final firstDayOfMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month,
        1,
      );
      final firstDayOfNextMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + 1,
        1,
      );

      final response = await _supabase
          .from('orders')
          .select(
            'id, created_at, total_price, profit, order_type_name, brand_id, brands(name)',
          )
          .gte('created_at', firstDayOfMonth.toIso8601String())
          .lt('created_at', firstDayOfNextMonth.toIso8601String())
          .order('created_at', ascending: false);

      if (!mounted) return;

      final List<app_order.Order> fetchedOrders = (response as List)
          .map((data) => app_order.Order.fromJson(data as Map<String, dynamic>))
          .toList();

      double monthProfit = 0;
      double monthRevenue = 0;
      for (var order in fetchedOrders) {
        monthProfit += order.profit ?? 0.0;
        monthRevenue += order.totalPrice;
      }
      final monthPurchases = await _fetchPurchasesForRange(
        firstDayOfMonth,
        firstDayOfNextMonth,
      );

      setState(() {
        _selectedMonthOrders = fetchedOrders;
        _selectedMonthProfit = monthProfit;
        _selectedMonthRevenue = monthRevenue;
        _selectedMonthPurchases = monthPurchases;
      });
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar(
          'Error fetching orders for ${DateFormat.yMMMM().format(_selectedMonth)}: $e',
        );
        setState(() {
          _selectedMonthOrders = [];
          _selectedMonthProfit = null;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingMonthDetails = false);
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
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

  Future<void> _performRestoreOperations(BuildContext context) async {
    final supabase = _supabase;

    setState(() {
      _isRestoring = true;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Padding(
            padding: EdgeInsets.all(24.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text("Restoring data..."),
              ],
            ),
          ),
        );
      },
    );

    try {
      print('Deleting from inventory_log...');
      await supabase
          .from('inventory_log')
          .delete()
          .gte('created_at', '1970-01-01T00:00:00Z');

      print('Updating material table...');
      await supabase
          .from('material')
          .update({'current_quantity': 0, 'average_unit_cost': 0})
          .gte('created_at', '1970-01-01T00:00:00Z');

      // Delete dependent rows first to satisfy FK constraints
      print('Deleting from order_items...');
      await supabase
          .from('order_items')
          .delete()
          .gte('created_at', '1970-01-01T00:00:00Z');

      // Receipts may reference orders; delete them before orders
      print('Deleting from receipts...');
      await supabase
          .from('receipts')
          .delete()
          .gte('created_at', '1970-01-01T00:00:00Z');
      print('Deleting from canceled_receipts...');
      await supabase
          .from('canceled_receipts')
          .delete()
          .gte('created_at', '1970-01-01T00:00:00Z');

      // Delivery-related tables (best-effort)
      try {
        print('Deleting from route_stops...');
        await supabase
            .from('route_stops')
            .delete()
            .gte('created_at', '1970-01-01T00:00:00Z');
      } catch (e) {
        debugPrint('route_stops delete skipped: $e');
      }
      try {
        print('Deleting from delivery_routes...');
        await supabase
            .from('delivery_routes')
            .delete()
            .gte('created_at', '1970-01-01T00:00:00Z');
      } catch (e) {
        debugPrint('delivery_routes delete skipped: $e');
      }

      // Purchases and purchase_items
      try {
        print('Deleting from purchase_items...');
        await supabase
            .from('purchase_items')
            .delete()
            .gte('created_at', '1970-01-01T00:00:00Z');
      } catch (e) {
        debugPrint('purchase_items delete skipped: $e');
      }
      try {
        print('Deleting from purchases...');
        await supabase
            .from('purchases')
            .delete()
            .gte('created_at', '1970-01-01T00:00:00Z');
      } catch (e) {
        debugPrint('purchases delete skipped: $e');
      }

      // Finally, delete ALL orders - use a simple approach that catches everything
      print('Deleting from orders...');
      try {
        // First attempt: Delete with date filter
        await supabase
            .from('orders')
            .delete()
            .gte('created_at', '1970-01-01T00:00:00Z');
      } catch (e) {
        debugPrint('First delete attempt: $e');
      }

      // Second attempt: Verify and delete any remaining orders
      try {
        final remainingOrders = await supabase.from('orders').select('id');

        if (remainingOrders.isNotEmpty) {
          debugPrint(
            'Found ${remainingOrders.length} remaining orders, deleting individually...',
          );
          for (var order in remainingOrders) {
            try {
              await supabase.from('orders').delete().eq('id', order['id']);
            } catch (e) {
              debugPrint('Failed to delete order ${order['id']}: $e');
            }
          }
        }
      } catch (e) {
        debugPrint('Verification/cleanup: $e');
      }

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();

        // Verify orders were deleted
        final checkOrders = await supabase.from('orders').select('id').limit(1);
        final orderCount = (checkOrders is List) ? checkOrders.length : 0;

        if (orderCount > 0) {
          _showErrorSnackBar(
            'Warning: Some orders may not have been deleted. Check database permissions.',
          );
        } else {
          _showSuccessSnackBar(
            'Application data restored successfully. All orders deleted.',
          );
        }

        // Ask Orders screen to refresh its data immediately
        try {
          OrderNotificationService().notifyNewOrder('refresh_after_restore');
        } catch (_) {}

        // Refresh profit data to show cleared state
        await _fetchAllProfitData();
      }
    } catch (e) {
      print('Error during restore operation: $e');
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _showErrorSnackBar('Error restoring data: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRestoring = false;
        });
      }
    }
  }

  void _showRestoreConfirmationDialog() {
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
              const Text('Confirm Restore'),
            ],
          ),
          content: const Text(
            'Are you sure you want to restore application data?\n\nThis will delete:\n'
            '• All inventory stock records (quantities set to 0)\n'
            '• All inventory logs\n'
            '• All orders (including order items)\n'
            '• All receipts (active and cancelled)\n'
            '• All purchases (including purchase items)\n\n'
            'This action cannot be undone.',
            style: TextStyle(fontSize: 14),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Restore Data'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _performRestoreOperations(context);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildFinanceOverviewCards() {
    final overview = [
      {
        'title': "Today's",
        'revenue': _todayRevenue,
        'purchases': _todayPurchases,
        'profit': _todayProfit,
      },
      {
        'title': 'Last 7 Days',
        'revenue': _last7DaysRevenue,
        'purchases': _last7DaysPurchases,
        'profit': _last7DaysProfit,
      },
      {
        'title': 'Last 30 Days',
        'revenue': _last30DaysRevenue,
        'purchases': _last30DaysPurchases,
        'profit': _last30DaysProfit,
      },
      {
        'title': 'Last 3 Months',
        'revenue': _last3MonthsRevenue,
        'purchases': _last3MonthsPurchases,
        'profit': _last3MonthsProfit,
      },
    ];

    Widget cell(String label, double? value, Color color) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[700])),
          const SizedBox(height: 2),
          Text(
            value != null ? '€${value.toStringAsFixed(2)}' : '€0.00',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: color,
              fontSize: 14,
            ),
          ),
        ],
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Finance Overview',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: MediaQuery.of(context).size.width > 1300
                  ? 4
                  : (MediaQuery.of(context).size.width > 1000
                        ? 3
                        : (MediaQuery.of(context).size.width > 700 ? 2 : 1)),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.4,
            ),
            itemCount: overview.length,
            itemBuilder: (context, index) {
              final row = overview[index];
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            row['title'] as String,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              cell(
                                'Revenue',
                                row['revenue'] as double?,
                                Colors.blue[700]!,
                              ),
                              cell(
                                'Purchases',
                                row['purchases'] as double?,
                                Colors.orange[800]!,
                              ),
                              cell(
                                'Profit',
                                row['profit'] as double?,
                                Colors.green[700]!,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyDetailsSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Monthly Details',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue[600]!, Colors.blue[400]!],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _isLoadingProfits || _isLoadingMonthDetails
                          ? null
                          : () async {
                              final DateTime? picked = await showDatePicker(
                                context: context,
                                initialDate: _selectedMonth,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now().add(
                                  const Duration(days: 365),
                                ),
                                initialDatePickerMode: DatePickerMode.year,
                              );
                              if (picked != null &&
                                  (picked.year != _selectedMonth.year ||
                                      picked.month != _selectedMonth.month)) {
                                setState(() {
                                  _selectedMonth = DateTime(
                                    picked.year,
                                    picked.month,
                                  );
                                });
                                await _fetchProfitForSelectedMonth();
                              }
                            },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calendar_month,
                              color: Colors.white,
                              size: 16,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Select Month',
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
            const SizedBox(height: 16),
            Text(
              DateFormat.yMMMM().format(_selectedMonth),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green[50]!, Colors.green[100]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.account_balance_wallet,
                    color: Colors.green[600],
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Monthly Profit',
                        style: TextStyle(
                          color: Colors.green[700],
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      _isLoadingMonthDetails
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _selectedMonthProfit != null
                                  ? '€${_selectedMonthProfit!.toStringAsFixed(2)}'
                                  : '€0.00',
                              style: TextStyle(
                                color: Colors.green[700],
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (_isLoadingMonthDetails)
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Loading orders...',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              )
            else if (_selectedMonthOrders.isEmpty)
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No orders found',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No orders were placed in ${DateFormat.yMMMM().format(_selectedMonth)}',
                      style: TextStyle(color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.list_alt, color: Colors.grey[700], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Individual Orders (${_selectedMonthOrders.length})',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _selectedMonthOrders.length,
                    itemBuilder: (context, index) {
                      final order = _selectedMonthOrders[index];
                      return FadeTransition(
                        opacity: _fadeAnimation,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      OrderDetailScreen(order: order),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: Colors.blue[50],
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.blue[200]!,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.receipt,
                                        color: Colors.blue[600],
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${order.brandName ?? 'Unknown Brand'} - ${order.id?.substring(0, 8)}...',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${DateFormat('MMM d, HH:mm').format(order.createdAt.toLocal())} • ${order.orderTypeName ?? 'Standard'}',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Total: €${order.totalPrice.toStringAsFixed(2)}',
                                            style: TextStyle(
                                              color: Colors.grey[700],
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          'Profit',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 10,
                                          ),
                                        ),
                                        Text(
                                          order.profit != null
                                              ? '€${order.profit!.toStringAsFixed(2)}'
                                              : 'N/A',
                                          style: TextStyle(
                                            color: order.profit == null
                                                ? Colors.grey
                                                : (order.profit! >= 0
                                                      ? Colors.green[700]
                                                      : Colors.red[700]),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.arrow_forward_ios,
                                      size: 12,
                                      color: Colors.grey[400],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestoreSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange[600],
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Data Management',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Restore Application Data',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This will permanently delete all orders, receipts, and inventory data. Use with caution.',
                    style: TextStyle(fontSize: 14, color: Colors.orange[700]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange[600]!, Colors.orange[400]!],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _isRestoring ? null : _showRestoreConfirmationDialog,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isRestoring)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          else
                            const Icon(
                              Icons.restore_page_outlined,
                              color: Colors.white,
                              size: 20,
                            ),
                          const SizedBox(width: 8),
                          Text(
                            _isRestoring
                                ? 'Restoring...'
                                : 'Restore Application Data',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Payments & Profits',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            tooltip: 'Logout',
            onPressed: () async {
              try {
                await Supabase.instance.client.auth.signOut();
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                    (route) => false,
                  );
                }
              } catch (e) {
                if (mounted) {
                  _showErrorSnackBar('Logout failed: ${e.toString()}');
                }
              }
            },
          ),
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _isLoadingProfits ? null : _fetchAllProfitData,
              tooltip: 'Refresh Profits',
            ),
          ),
        ],
      ),
      body: _isLoadingProfits
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Loading profit data...',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildFinanceOverviewCards(),
                      _buildMonthlyDetailsSection(),
                      _buildRestoreSection(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
