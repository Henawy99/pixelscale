import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:restaurantadmin/models/order.dart' as app_order;
import 'package:restaurantadmin/screens/order_detail_screen.dart';

enum DatePreset { today, thisWeek, thisMonth, custom }
enum PlatformFilter { all, lieferando, foodora, other }
enum PaymentFilter { all, cash, online }

class IntensiveFilterScreen extends StatefulWidget {
  final DateTime? initialDate;

  const IntensiveFilterScreen({super.key, this.initialDate});

  @override
  State<IntensiveFilterScreen> createState() => _IntensiveFilterScreenState();
}

class _IntensiveFilterScreenState extends State<IntensiveFilterScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'de_AT', symbol: '€');
  final DateFormat _dateFormat = DateFormat('dd.MM.yyyy');
  final DateFormat _timeFormat = DateFormat('HH:mm');

  DatePreset _selectedPreset = DatePreset.today;
  late DateTime _startDate;
  late DateTime _endDate;

  PlatformFilter _platformFilter = PlatformFilter.all;
  PaymentFilter _paymentFilter = PaymentFilter.all;
  String _selectedBrand = 'all';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = false;
  List<app_order.Order> _orders = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final now = widget.initialDate ?? DateTime.now();
    _setPreset(DatePreset.today, baseDate: now, fetch: false);
    _fetchOrders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _setPreset(DatePreset preset, {DateTime? baseDate, bool fetch = true}) {
    final now = baseDate ?? DateTime.now();
    DateTime start;
    DateTime end;

    switch (preset) {
      case DatePreset.today:
        start = DateTime(now.year, now.month, now.day);
        end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        break;
      case DatePreset.thisWeek:
        // Week starting Monday to Sunday
        final weekday = now.weekday; // 1 = Monday, 7 = Sunday
        final monday = now.subtract(Duration(days: weekday - 1));
        start = DateTime(monday.year, monday.month, monday.day);
        final sunday = monday.add(const Duration(days: 6));
        end = DateTime(sunday.year, sunday.month, sunday.day, 23, 59, 59, 999);
        break;
      case DatePreset.thisMonth:
        start = DateTime(now.year, now.month, 1);
        final nextMonth = DateTime(now.year, now.month + 1, 1);
        end = nextMonth.subtract(const Duration(milliseconds: 1));
        break;
      case DatePreset.custom:
        start = _startDate;
        end = _endDate;
        break;
    }

    setState(() {
      _selectedPreset = preset;
      _startDate = start;
      _endDate = end;
    });

    if (fetch) {
      _fetchOrders();
    }
  }

  Future<void> _pickCustomDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: DateTimeRange(
        start: _startDate.isBefore(DateTime(2023, 1, 1)) ? now : _startDate,
        end: _endDate.isAfter(DateTime(now.year + 1, 12, 31)) ? now : _endDate,
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.indigo.shade600,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedPreset = DatePreset.custom;
        _startDate = DateTime(picked.start.year, picked.start.month, picked.start.day);
        _endDate = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59, 999);
      });
      _fetchOrders();
    }
  }

  Future<void> _fetchOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final startUtc = _startDate.toUtc().toIso8601String();
      final endUtc = _endDate.toUtc().toIso8601String();

      final response = await _supabase
          .from('orders')
          .select('*, brands(name), profit')
          .gte('created_at', startUtc)
          .lte('created_at', endUtc)
          .order('created_at', ascending: false);

      final list = (response as List)
          .map((data) => app_order.Order.fromJson(data as Map<String, dynamic>))
          .toList();

      if (mounted) {
        setState(() {
          _orders = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load orders: $e';
        });
      }
    }
  }

  List<app_order.Order> get _filteredOrders {
    return _orders.where((order) {
      // 1. Platform Filter
      final type = (order.orderTypeName ?? '').toLowerCase();
      if (_platformFilter == PlatformFilter.lieferando && !type.contains('lieferando')) {
        return false;
      }
      if (_platformFilter == PlatformFilter.foodora && !type.contains('foodora')) {
        return false;
      }
      if (_platformFilter == PlatformFilter.other && (type.contains('lieferando') || type.contains('foodora'))) {
        return false;
      }

      // 2. Payment Method Filter
      final payMethod = order.paymentMethod.toLowerCase();
      final isCash = payMethod == 'cash' || payMethod.contains('bar') || payMethod == 'bar';
      if (_paymentFilter == PaymentFilter.cash && !isCash) {
        return false;
      }
      if (_paymentFilter == PaymentFilter.online && isCash) {
        return false;
      }

      // 3. Brand Filter
      if (_selectedBrand != 'all' && order.brandId != _selectedBrand) {
        return false;
      }

      // 4. Search Query
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase().trim();
        final cust = (order.customerName ?? '').toLowerCase();
        final addr = (order.customerStreet ?? '').toLowerCase();
        final ref = (order.publicReference ?? '').toLowerCase();
        final orderNum = (order.orderNumber ?? '').toLowerCase();
        final dailyNum = (order.dailyOrderNumber?.toString() ?? '');
        final platformId = (order.platformOrderId ?? '').toLowerCase();

        final match = cust.contains(query) ||
            addr.contains(query) ||
            ref.contains(query) ||
            orderNum.contains(query) ||
            dailyNum.contains(query) ||
            platformId.contains(query);

        if (!match) return false;
      }

      return true;
    }).toList();
  }

  // Summary Metrics calculations on filtered orders
  double get _totalRevenue {
    double total = 0.0;
    for (final o in _filteredOrders) {
      final status = (o.status).toLowerCase();
      if (status != 'cancelled' && status != 'canceled') {
        total += o.totalPrice;
      }
    }
    return total;
  }

  int get _validOrderCount {
    int count = 0;
    for (final o in _filteredOrders) {
      final status = (o.status).toLowerCase();
      if (status != 'cancelled' && status != 'canceled') {
        count++;
      }
    }
    return count;
  }

  // Lieferando & Foodora revenue breakdowns
  double get _lieferandoRevenue {
    double total = 0.0;
    for (final o in _filteredOrders) {
      final type = (o.orderTypeName ?? '').toLowerCase();
      final status = (o.status).toLowerCase();
      if (type.contains('lieferando') && status != 'cancelled' && status != 'canceled') {
        total += o.totalPrice;
      }
    }
    return total;
  }

  double get _foodoraRevenue {
    double total = 0.0;
    for (final o in _filteredOrders) {
      final type = (o.orderTypeName ?? '').toLowerCase();
      final status = (o.status).toLowerCase();
      if (type.contains('foodora') && status != 'cancelled' && status != 'canceled') {
        total += o.totalPrice;
      }
    }
    return total;
  }

  double get _cashRevenue {
    double total = 0.0;
    for (final o in _filteredOrders) {
      final payMethod = o.paymentMethod.toLowerCase();
      final status = (o.status).toLowerCase();
      final isCash = payMethod == 'cash' || payMethod.contains('bar') || payMethod == 'bar';
      if (isCash && status != 'cancelled' && status != 'canceled') {
        total += o.totalPrice;
      }
    }
    return total;
  }

  double get _onlineRevenue {
    double total = 0.0;
    for (final o in _filteredOrders) {
      final payMethod = o.paymentMethod.toLowerCase();
      final status = (o.status).toLowerCase();
      final isCash = payMethod == 'cash' || payMethod.contains('bar') || payMethod == 'bar';
      if (!isCash && status != 'cancelled' && status != 'canceled') {
        total += o.totalPrice;
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredOrders;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Intensive Filter & Analytics',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              'Date range, platforms, payments & revenue',
              style: TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload Data',
            onPressed: _fetchOrders,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Controls Section (Scrollable horizontally or compact vertically)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Date Presets Bar
                _buildDatePresets(),
                const SizedBox(height: 10),

                // 2. Active Date Range Display Button
                _buildDateRangeButton(),
                const SizedBox(height: 12),

                // 3. Platform & Payment Filters
                _buildFilterChipsRow(),
                const SizedBox(height: 10),

                // 4. Search Bar
                _buildSearchBar(),
              ],
            ),
          ),

          // Main Content: Analytics Card + Order List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? _buildErrorWidget()
                    : RefreshIndicator(
                        onRefresh: _fetchOrders,
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            // Revenue & Analytics Hero Card
                            _buildRevenueSummaryCard(),
                            const SizedBox(height: 16),

                            // Section header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Orders (${filtered.length})',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                if (filtered.length != _orders.length)
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _platformFilter = PlatformFilter.all;
                                        _paymentFilter = PaymentFilter.all;
                                        _selectedBrand = 'all';
                                        _searchController.clear();
                                        _searchQuery = '';
                                      });
                                    },
                                    child: const Text('Reset Filters', style: TextStyle(fontSize: 12)),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Order Cards
                            if (filtered.isEmpty)
                              _buildEmptyState()
                            else
                              ...filtered.map((order) => _buildOrderCard(order)),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePresets() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildPresetChip('Today', DatePreset.today),
          const SizedBox(width: 8),
          _buildPresetChip('Whole Week', DatePreset.thisWeek),
          const SizedBox(width: 8),
          _buildPresetChip('Whole Month', DatePreset.thisMonth),
          const SizedBox(width: 8),
          _buildPresetChip('Custom Range', DatePreset.custom, isCustom: true),
        ],
      ),
    );
  }

  Widget _buildPresetChip(String label, DatePreset preset, {bool isCustom = false}) {
    final isSelected = _selectedPreset == preset;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isCustom) const Icon(Icons.date_range, size: 14),
          if (isCustom) const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (isCustom) {
          _pickCustomDateRange();
        } else {
          _setPreset(preset);
        }
      },
      selectedColor: Colors.indigo.shade600,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        fontSize: 12,
      ),
      backgroundColor: Colors.grey.shade100,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildDateRangeButton() {
    final rangeText = '${_dateFormat.format(_startDate)} – ${_dateFormat.format(_endDate)}';
    return InkWell(
      onTap: _pickCustomDateRange,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.indigo.shade50.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.indigo.shade100),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined, size: 16, color: Colors.indigo.shade700),
            const SizedBox(width: 8),
            Text(
              rangeText,
              style: TextStyle(
                color: Colors.indigo.shade900,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const Spacer(),
            Text(
              'Change',
              style: TextStyle(
                color: Colors.indigo.shade700,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 16, color: Colors.indigo.shade700),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChipsRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Platform Row
        Row(
          children: [
            const Text('Platform:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)),
            const SizedBox(width: 8),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildPlatformChip('All', PlatformFilter.all, null),
                    const SizedBox(width: 6),
                    _buildPlatformChip('Lieferando', PlatformFilter.lieferando, const Color(0xFFFF8000)),
                    const SizedBox(width: 6),
                    _buildPlatformChip('Foodora', PlatformFilter.foodora, const Color(0xFFD70F64)),
                    const SizedBox(width: 6),
                    _buildPlatformChip('Web / Other', PlatformFilter.other, Colors.indigo.shade700),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Payment Row
        Row(
          children: [
            const Text('Payment:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)),
            const SizedBox(width: 8),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildPaymentChip('All', PaymentFilter.all, null),
                    const SizedBox(width: 6),
                    _buildPaymentChip('Cash', PaymentFilter.cash, const Color(0xFF2E7D32), Icons.payments_outlined),
                    const SizedBox(width: 6),
                    _buildPaymentChip('Online', PaymentFilter.online, const Color(0xFF1976D2), Icons.credit_card_outlined),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPlatformChip(String label, PlatformFilter filter, Color? brandColor) {
    final isSelected = _platformFilter == filter;
    final color = brandColor ?? Colors.black87;
    return InkWell(
      onTap: () => setState(() => _platformFilter = filter),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.12) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (brandColor != null)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(color: brandColor, shape: BoxShape.circle),
              ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? color : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentChip(String label, PaymentFilter filter, Color? accentColor, [IconData? icon]) {
    final isSelected = _paymentFilter == filter;
    final color = accentColor ?? Colors.black87;
    return InkWell(
      onTap: () => setState(() => _paymentFilter = filter),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.12) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null)
              Icon(icon, size: 14, color: isSelected ? color : Colors.black54),
            if (icon != null) const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? color : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Search customer, address, order #...',
          hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey.shade600),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 16),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
        onChanged: (val) => setState(() => _searchQuery = val),
      ),
    );
  }

  Widget _buildRevenueSummaryCard() {
    final avgOrder = _validOrderCount > 0 ? _totalRevenue / _validOrderCount : 0.0;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.indigo.shade800,
            Colors.indigo.shade600,
            Colors.blue.shade600,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.shade900.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Revenue',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_dateFormat.format(_startDate)} – ${_dateFormat.format(_endDate)}',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _currencyFormat.format(_totalRevenue),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 16),

          // Metrics Row
          Row(
            children: [
              _buildMetricItem('Orders', '$_validOrderCount', Icons.receipt_long),
              _buildMetricDivider(),
              _buildMetricItem('Avg. Order', _currencyFormat.format(avgOrder), Icons.show_chart),
              _buildMetricDivider(),
              _buildMetricItem('Lieferando', _currencyFormat.format(_lieferandoRevenue), Icons.storefront),
              _buildMetricDivider(),
              _buildMetricItem('Foodora', _currencyFormat.format(_foodoraRevenue), Icons.delivery_dining),
            ],
          ),

          const SizedBox(height: 14),
          // Cash vs Online Sub-Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Row(
                  children: [
                    const Icon(Icons.payments, color: Color(0xFF81C784), size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Cash: ${_currencyFormat.format(_cashRevenue)}',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                Container(width: 1, height: 16, color: Colors.white24),
                Row(
                  children: [
                    const Icon(Icons.credit_card, color: Color(0xFF90CAF9), size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Online: ${_currencyFormat.format(_onlineRevenue)}',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white70, size: 12),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricDivider() {
    return Container(
      width: 1,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: Colors.white24,
    );
  }

  Widget _buildOrderCard(app_order.Order order) {
    final isLieferando = (order.orderTypeName ?? '').toLowerCase().contains('lieferando');
    final isFoodora = (order.orderTypeName ?? '').toLowerCase().contains('foodora');
    final payMethod = order.paymentMethod.toLowerCase();
    final isCash = payMethod == 'cash' || payMethod.contains('bar') || payMethod == 'bar';

    final platformColor = isLieferando
        ? const Color(0xFFFF8000)
        : isFoodora
            ? const Color(0xFFD70F64)
            : Colors.indigo.shade600;

    final platformName = isLieferando
        ? 'Lieferando'
        : isFoodora
            ? 'Foodora'
            : (order.orderTypeName?.isNotEmpty == true ? order.orderTypeName! : 'Web/Store');

    final orderIdentifier = order.dailyOrderNumber != null
        ? '#${order.dailyOrderNumber}'
        : order.publicReference != null
            ? '#${order.publicReference}'
            : order.orderNumber != null
                ? '#${order.orderNumber}'
                : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => OrderDetailScreen(order: order)),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row: Brand, ID, Price
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          if (orderIdentifier.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Text(
                                orderIdentifier,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          Flexible(
                            child: Text(
                              order.brandName ?? 'Store Order',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _currencyFormat.format(order.totalPrice),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Customer info
                if (order.customerName != null && order.customerName!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.person_outline, size: 14, color: Colors.black54),
                        const SizedBox(width: 4),
                        Text(
                          order.customerName!,
                          style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w500),
                        ),
                        if (order.customerStreet != null && order.customerStreet!.isNotEmpty) ...[
                          const Text(' • ', style: TextStyle(color: Colors.black38)),
                          Flexible(
                            child: Text(
                              order.customerStreet!,
                              style: const TextStyle(fontSize: 12, color: Colors.black54),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                const SizedBox(height: 8),
                const Divider(height: 1),
                const SizedBox(height: 8),

                // Badges Row
                Row(
                  children: [
                    // Platform badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: platformColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.storefront, size: 12, color: platformColor),
                          const SizedBox(width: 4),
                          Text(
                            platformName,
                            style: TextStyle(
                              color: platformColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Payment badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isCash ? const Color(0xFFE8F5E9) : const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isCash ? Icons.payments_outlined : Icons.credit_card_outlined,
                            size: 12,
                            color: isCash ? const Color(0xFF2E7D32) : const Color(0xFF1976D2),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isCash ? 'Cash' : 'Online',
                            style: TextStyle(
                              color: isCash ? const Color(0xFF2E7D32) : const Color(0xFF1976D2),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Fulfillment type
                    if (order.fulfillmentType != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          order.fulfillmentType!.toUpperCase(),
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                    const Spacer(),

                    // Timestamp
                    Text(
                      '${_dateFormat.format(order.createdAt)} ${_timeFormat.format(order.createdAt)}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Icon(Icons.filter_list_off, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'No orders match your filter criteria',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 6),
            Text(
              'Try adjusting the date range or platform/payment filters.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _fetchOrders, child: const Text('Try Again')),
          ],
        ),
      ),
    );
  }
}
