import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InventoryStatisticsScreen extends StatefulWidget {
  const InventoryStatisticsScreen({super.key});

  @override
  State<InventoryStatisticsScreen> createState() => _InventoryStatisticsScreenState();
}

class _InventoryStatisticsScreenState extends State<InventoryStatisticsScreen> 
    with TickerProviderStateMixin {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = true;
  String? _error;

  // Animation controllers
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Data holders for statistics
  double? _spentLast7Days;
  double? _spentLast30Days;
  Map<String, double> _spendingByWholesaler = {};
  Map<String, double> _spendingByItem = {};

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOut));

    _fetchAllStatistics();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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

  Future<void> _fetchAllStatistics() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _calculateSpendingLast7Days();
      await _calculateSpendingLast30Days();
      await _calculateSpendingByWholesaler();
      await _calculateSpendingByItem();

    } catch (e) {
      print('Error fetching inventory statistics: $e');
      if (mounted) {
        _error = 'Failed to load statistics: $e';
      }
    } finally {
      if (mounted) {
        print('[InventoryStatisticsScreen] _fetchAllStatistics completed. _spentLast7Days: $_spentLast7Days, _spentLast30Days: $_spentLast30Days');
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _calculateSpendingLast7Days() async {
    final now = DateTime.now();
    final endDate = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    final startDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));

    print('[InventoryStatisticsScreen] Fetching spending for last 7 days: ${DateFormat.yMd().add_Hms().format(startDate)} - ${DateFormat.yMd().add_Hms().format(endDate)}');

    final response = await _supabase
        .from('receipts')
        .select('total_amount')
        .eq('status', 'active')
        .gte('receipt_date', startDate.toIso8601String())
        .lte('receipt_date', endDate.toIso8601String());

    double total = 0;
    for (var row in response as List) {
      total += (row['total_amount'] as num?)?.toDouble() ?? 0.0;
    }
    print('[InventoryStatisticsScreen] Calculated total for last 7 days: $total');
    if (mounted) {
      setState(() {
        _spentLast7Days = total;
      });
    }
  }

  Future<void> _calculateSpendingLast30Days() async {
    final now = DateTime.now();
    final endDate = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    final startDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 29));
    
    print('[InventoryStatisticsScreen] Fetching spending for last 30 days: ${DateFormat.yMd().add_Hms().format(startDate)} - ${DateFormat.yMd().add_Hms().format(endDate)}');

    final response = await _supabase
        .from('receipts')
        .select('total_amount')
        .eq('status', 'active')
        .gte('receipt_date', startDate.toIso8601String())
        .lte('receipt_date', endDate.toIso8601String());
    
    double total = 0;
    for (var row in response as List) {
      total += (row['total_amount'] as num?)?.toDouble() ?? 0.0;
    }
    print('[InventoryStatisticsScreen] Calculated total for last 30 days: $total');
    if (mounted) {
      setState(() {
        _spentLast30Days = total;
      });
    }
  }

  Future<void> _calculateSpendingByWholesaler() async {
    final response = await _supabase
        .from('receipts')
        .select('wholesaler_name, total_amount')
        .eq('status', 'active');

    Map<String, double> spendingMap = {};
    for (var row in response as List) {
      final String wholesaler = (row['wholesaler_name'] as String?) ?? 'Unknown Wholesaler';
      final double amount = (row['total_amount'] as num?)?.toDouble() ?? 0.0;
      spendingMap.update(wholesaler, (value) => value + amount, ifAbsent: () => amount);
    }

    var sortedEntries = spendingMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    _spendingByWholesaler = Map.fromEntries(sortedEntries);

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _calculateSpendingByItem() async {
    final purchaseTypes = ['MANUAL_RECEIPT', 'ENTRY', 'INITIAL_STOCK']; 

    final response = await _supabase
        .from('inventory_log')
        .select('material_name, total_price_paid')
        .filter('change_type', 'in', purchaseTypes)
        .not('total_price_paid', 'is', null);

    Map<String, double> spendingMap = {};
    for (var row in response as List) {
      final String materialName = (row['material_name'] as String?) ?? 'Unknown Item';
      final double amount = (row['total_price_paid'] as num?)?.toDouble() ?? 0.0;
      if (amount > 0) {
        spendingMap.update(materialName, (value) => value + amount, ifAbsent: () => amount);
      }
    }

    var sortedEntries = spendingMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    _spendingByItem = Map.fromEntries(sortedEntries);

    if (mounted) {
      setState(() {}); 
    }
  }

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [Colors.indigo[600]!, Colors.indigo[400]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.analytics,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Inventory Statistics',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
            ),
                SizedBox(height: 4),
                Text(
                  'Comprehensive spending analytics',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCards() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Last 7 Days',
                  _spentLast7Days != null ? '€${_spentLast7Days!.toStringAsFixed(2)}' : '€0.00',
                  Icons.calendar_view_week,
                  [Colors.blue[600]!, Colors.blue[400]!],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  'Last 30 Days',
                  _spentLast30Days != null ? '€${_spentLast30Days!.toStringAsFixed(2)}' : '€0.00',
                  Icons.calendar_month,
                  [Colors.green[600]!, Colors.green[400]!],
                ),
              ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, List<Color> gradientColors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWholesalerSpendingCard() {
    final topWholesalersToShow = _spendingByWholesaler.entries.take(5).toList();

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.2),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _animationController,
          curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
        )),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
      child: Padding(
            padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                    Icon(Icons.storefront, color: Colors.orange[600], size: 24),
                    const SizedBox(width: 12),
                    const Text(
                      'Top Wholesalers',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
              ],
            ),
                const SizedBox(height: 16),
            if (topWholesalersToShow.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.storefront_outlined, size: 40, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          Text(
                            'No Data Available',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'No wholesaler spending data found',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Column(
                    children: topWholesalersToShow.asMap().entries.map((entry) {
                      final index = entry.key;
                      final data = entry.value;
                      return Container(
                        margin: EdgeInsets.only(bottom: index < topWholesalersToShow.length - 1 ? 12 : 0),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.orange[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    color: Colors.orange[600],
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data.key,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'All-time spending',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.orange[600]!, Colors.orange[400]!],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '€${data.value.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
              ),
            if (_spendingByWholesaler.length > topWholesalersToShow.length)
              Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Center(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.orange[600]!, Colors.orange[400]!],
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
                    ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Full wholesaler list view not yet implemented'),
                                  backgroundColor: Colors.orange,
                                ),
                    );
                  },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.visibility, color: Colors.white, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'View All Wholesalers',
                                    style: TextStyle(
                                      color: Colors.white,
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
              ),
          ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemSpendingCard() {
    final topItemsToShow = _spendingByItem.entries.take(5).toList();

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.2),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _animationController,
          curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
        )),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
      child: Padding(
            padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                    Icon(Icons.inventory_2, color: Colors.purple[600], size: 24),
                    const SizedBox(width: 12),
                    const Text(
                      'Top Items by Spending',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (topItemsToShow.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.inventory_outlined, size: 40, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          Text(
                            'No Data Available',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'No item spending data found',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Column(
                    children: topItemsToShow.asMap().entries.map((entry) {
                      final index = entry.key;
                      final data = entry.value;
                      return Container(
                        margin: EdgeInsets.only(bottom: index < topItemsToShow.length - 1 ? 12 : 0),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.purple[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    color: Colors.purple[600],
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data.key,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Total spending',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.purple[600]!, Colors.purple[400]!],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '€${data.value.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                if (_spendingByItem.length > topItemsToShow.length)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Center(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.purple[600]!, Colors.purple[400]!],
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
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Full item spending list view not yet implemented'),
                                  backgroundColor: Colors.purple,
                                ),
                              );
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.visibility, color: Colors.white, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'View All Items',
                                    style: TextStyle(
                                      color: Colors.white,
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
                  ),
              ],
            ),
          ),
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
          'Inventory Statistics',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
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
                onTap: _fetchAllStatistics,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh, color: Colors.white, size: 18),
                      SizedBox(width: 4),
                      Text(
                        'Refresh',
                        style: TextStyle(
                          color: Colors.white,
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
      body: _isLoading
          ? Center(
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
                    'Loading statistics...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : _error != null
              ? Center(
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
                          'Error Loading Statistics',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.red[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          style: TextStyle(color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _fetchAllStatistics,
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
                )
              : RefreshIndicator(
                  onRefresh: _fetchAllStatistics,
                  color: Colors.indigo,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 8),
                        _buildOverviewCards(),
                        const SizedBox(height: 16),
                        if (_spendingByWholesaler.isNotEmpty) _buildWholesalerSpendingCard(),
                        if (_spendingByItem.isNotEmpty) _buildItemSpendingCard(),
                        const SizedBox(height: 20),
                    ],
                    ),
                  ),
                ),
    );
  }
}
