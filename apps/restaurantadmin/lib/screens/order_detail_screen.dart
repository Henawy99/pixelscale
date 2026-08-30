import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:restaurantadmin/models/order.dart' as app_order;
import 'package:restaurantadmin/models/order_item.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:restaurantadmin/services/order_service.dart';
import 'package:restaurantadmin/utils/snackbar_utils.dart' as snackbar_utils;
import 'package:url_launcher/url_launcher.dart';

class OrderDetailScreen extends StatefulWidget {
  final app_order.Order order;

  const OrderDetailScreen({super.key, required this.order});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen>
    with TickerProviderStateMixin {
  late Future<List<OrderItem>> _orderItemsFuture;
  late OrderService _orderService;
  bool _saving = false;

  final SupabaseClient _supabase = Supabase.instance.client;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

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
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );

    if (widget.order.id != null) {
      _orderService = OrderService();
      _orderItemsFuture = _fetchOrderItems(widget.order.id!);
    } else {
      _orderItemsFuture = Future.value([]);
    }

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<List<OrderItem>> _fetchOrderItems(String orderId) async {
    try {
      final response = await _supabase
          .from('order_items')
          .select()
          .eq('order_id', orderId);

      final List<OrderItem> loadedItems = (response as List)
          .map((data) => OrderItem.fromJson(data as Map<String, dynamic>))
          .toList();
      if (loadedItems.isNotEmpty) {
        return loadedItems;
      }
    } catch (e) {
      print(
        '[OrderDetailScreen] Error fetching order items for order $orderId: $e',
      );
    }

    // Fallback 1: widget.order.orderItems if preloaded
    if (widget.order.orderItems.isNotEmpty) {
      return widget.order.orderItems;
    }

    // Fallback 2: parse from platform_raw_data
    final raw = widget.order.platformRawData;
    if (raw is Map) {
      final detailsOrder = raw['details'] is Map ? raw['details']['order'] : null;
      final rawItems = (detailsOrder is Map ? detailsOrder['items'] : null) ??
          raw['items'] ??
          (raw['summary'] is Map ? raw['summary']['items'] : null);

      if (rawItems is List && rawItems.isNotEmpty) {
        return rawItems.map((item) {
          final map = item is Map ? item : <String, dynamic>{};
          return OrderItem(
            orderId: orderId,
            menuItemName: map['name']?.toString() ?? map['parentName']?.toString() ?? 'Unknown Item',
            quantity: (map['quantity'] as num?)?.toInt() ?? 1,
            priceAtPurchase: (map['unitPrice'] as num?)?.toDouble() ?? 0.0,
            specifications: map['options'],
            itemRemarks: map['customerNotes']?.toString(),
          );
        }).toList();
      }
    }

    return [];
  }

  void _showErrorSnackBar(String message) {
    snackbar_utils.showErrorSnackbar(context, message);
  }

  Future<void> _callCustomer({bool useDirectGateway = true}) async {
    final verifyCode = widget.order.verificationCode;
    final phone = widget.order.customerPhone;

    String? dialString;
    if (useDirectGateway && verifyCode != null && verifyCode.isNotEmpty) {
      // Lieferando automated masking gateway with DTMF verify code pause
      dialString = 'tel:+4314350148,$verifyCode#';
    } else if (phone != null && phone.isNotEmpty) {
      dialString = 'tel:$phone';
    } else if (verifyCode != null && verifyCode.isNotEmpty) {
      dialString = 'tel:+4314350148,$verifyCode#';
    }

    if (dialString == null) {
      if (mounted) {
        snackbar_utils.showErrorSnackbar(
          context,
          'No phone number or verification code found for this order',
        );
      }
      return;
    }

    try {
      final uri = Uri.parse(dialString);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        // Fallback without special characters
        final fallback = Uri.parse('tel:+4314350148');
        await launchUrl(fallback);
      }
    } catch (e) {
      if (mounted) {
        snackbar_utils.showErrorSnackbar(context, 'Could not start call: $e');
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'pending_confirmation':
        return Colors.orange;
      case 'confirmed':
      case 'kitchen':
      case 'in_kitchen':
        return Colors.blue;
      case 'preparing':
        return Colors.purple;
      case 'ready':
      case 'ready_for_pickup':
        return Colors.green;
      case 'delivered':
      case 'completed':
        return Colors.teal;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildHeader() {
    final statusColor = _getStatusColor(widget.order.status);
    final isPickup = (widget.order.fulfillmentType ?? '').toLowerCase() == 'pickup';
    final ref = widget.order.publicReference ??
        widget.order.platformOrderId ??
        (widget.order.id != null && widget.order.id!.length >= 8
            ? widget.order.id!.substring(0, 8)
            : 'Order');

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: isPickup
              ? [const Color(0xFFE65100), const Color(0xFFF57C00)]
              : [Colors.blue[700]!, Colors.blue[500]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: (isPickup ? Colors.orange : Colors.blue).withOpacity(0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isPickup ? Icons.shopping_bag_outlined : Icons.delivery_dining_outlined,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '#$ref',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isPickup ? 'PICKUP' : 'DELIVERY',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.order.brandName ?? widget.order.brandId,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  widget.order.status.replaceAll('_', ' ').toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '€${widget.order.totalPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'Total Amount',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (widget.order.orderTypeName != null) ...[
                  Container(
                    width: 1,
                    height: 36,
                    color: Colors.white.withOpacity(0.3),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.order.orderTypeName!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Text(
                          'Platform',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard() {
    final isPickup = (widget.order.fulfillmentType ?? '').toLowerCase() == 'pickup';

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
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
                    Icon(Icons.info_outline, color: Colors.blue[600], size: 22),
                    const SizedBox(width: 10),
                    const Text(
                      'Order Details',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (widget.order.publicReference != null)
                  _buildDetailRow('Reference:', '#${widget.order.publicReference}'),
                _buildDetailRow(
                  'Brand:',
                  widget.order.brandName ?? widget.order.brandId,
                ),
                _buildDetailRow(
                  'Fulfillment:',
                  isPickup ? '🏃 Pickup (Abholung)' : '🛵 Delivery (Lieferung)',
                  isEmphasized: true,
                ),
                _buildDetailRow(
                  'Order Time:',
                  DateFormat('dd.MM.yyyy HH:mm').format(
                    widget.order.createdAt.toLocal(),
                  ),
                ),
                if (widget.order.estimatedDeliveryTime != null)
                  _buildDetailRow(
                    'Est. Delivery Time:',
                    DateFormat('HH:mm (dd.MM.)').format(
                      widget.order.estimatedDeliveryTime!.toLocal(),
                    ),
                    isEmphasized: true,
                  ),
                if (widget.order.estimatedPickupTime != null)
                  _buildDetailRow(
                    'Est. Pickup Time:',
                    DateFormat('HH:mm (dd.MM.)').format(
                      widget.order.estimatedPickupTime!.toLocal(),
                    ),
                    isEmphasized: true,
                  ),
                if (widget.order.platformOrderId != null)
                  _buildDetailRow(
                    '${widget.order.orderTypeName ?? 'Platform'} ID:',
                    widget.order.platformOrderId!,
                  ),
                if (widget.order.paymentMethod.isNotEmpty)
                  _buildDetailRow(
                    'Payment:',
                    widget.order.paymentMethod.toUpperCase(),
                  ),

                // Delivery Notes Banner (Door/Floor instructions)
                if (widget.order.deliveryNotes != null &&
                    widget.order.deliveryNotes!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFD54F)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.apartment,
                          color: Color(0xFFE65100),
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Delivery / Floor / Door Notes',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Color(0xFFE65100),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.order.deliveryNotes!,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Customer Information Section
                if (widget.order.customerName != null ||
                    widget.order.customerPhone != null ||
                    widget.order.verificationCode != null ||
                    widget.order.customerStreet != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue[50]?.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.person_pin_circle_outlined,
                              size: 20,
                              color: Colors.blue[800],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Customer & Contact',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Colors.blue[900],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (widget.order.customerName != null)
                          _buildDetailRow('Name:', widget.order.customerName!),
                        if (widget.order.customerPhone != null &&
                            widget.order.customerPhone!.isNotEmpty)
                          _buildDetailRow(
                            'Phone Number:',
                            widget.order.customerPhone!,
                            isEmphasized: true,
                          ),
                        if (widget.order.customerStreet != null)
                          _buildDetailRow(
                            'Address:',
                            widget.order.customerStreet!,
                          ),
                        if (widget.order.customerPostcode != null ||
                            widget.order.customerCity != null)
                          _buildDetailRow(
                            'City:',
                            '${widget.order.customerPostcode ?? ''} ${widget.order.customerCity ?? ''}'
                                .trim(),
                          ),

                        // Verification code display
                        if (widget.order.verificationCode != null &&
                            widget.order.verificationCode!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange[100],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.orange[300]!),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.vpn_key_outlined,
                                      size: 16,
                                      color: Colors.orange[900],
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Verify Code: ${widget.order.verificationCode}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: Colors.orange[900],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.copy, size: 18),
                                tooltip: 'Copy Verify Code',
                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(text: widget.order.verificationCode!),
                                  );
                                  snackbar_utils.showSuccessSnackbar(
                                    context,
                                    'Verify code copied: ${widget.order.verificationCode}',
                                  );
                                },
                              ),
                            ],
                          ),
                        ],

                        // DIRECT CALL BUTTONS
                        const SizedBox(height: 12),
                        Column(
                          children: [
                            if (widget.order.verificationCode != null &&
                                widget.order.verificationCode!.isNotEmpty) ...[
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2E7D32),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    elevation: 2,
                                  ),
                                  onPressed: () => _callCustomer(useDirectGateway: true),
                                  icon: const Icon(Icons.phone_forwarded, size: 20),
                                  label: Text(
                                    'Call via Gateway (+4314350148 #${widget.order.verificationCode})',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            if (widget.order.customerPhone != null &&
                                widget.order.customerPhone!.isNotEmpty)
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF1565C0),
                                    side: const BorderSide(color: Color(0xFF1565C0)),
                                    padding: const EdgeInsets.symmetric(vertical: 11),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed: () => _callCustomer(useDirectGateway: false),
                                  icon: const Icon(Icons.phone, size: 18),
                                  label: Text(
                                    'Call Direct (${widget.order.customerPhone})',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),

                        if (widget.order.note != null &&
                            widget.order.note!.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _buildDetailRow('Remarks:', widget.order.note!),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Price & Fee Breakdown
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green[50]?.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Column(
                    children: [
                      if (widget.order.deliveryFee != null && widget.order.deliveryFee! > 0)
                        _buildDetailRow(
                          'Delivery Fee:',
                          '€${widget.order.deliveryFee!.toStringAsFixed(2)}',
                        ),
                      if (widget.order.fixedServiceFee != null && widget.order.fixedServiceFee! > 0)
                        _buildDetailRow(
                          'Service Fee:',
                          '€${widget.order.fixedServiceFee!.toStringAsFixed(2)}',
                        ),
                      _buildDetailRow(
                        'Total Revenue:',
                        '€${widget.order.totalPrice.toStringAsFixed(2)}',
                        isEmphasized: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemsCard() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
            .animate(
              CurvedAnimation(
                parent: _animationController,
                curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
              ),
            ),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
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
                      Icons.restaurant_menu,
                      color: Colors.orange[700],
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Items Ordered',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                FutureBuilder<List<OrderItem>>(
                  future: _orderItemsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return _buildLoadingState();
                    }
                    if (snapshot.hasError) {
                      return _buildErrorState(
                        'Error loading items: ${snapshot.error}',
                      );
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return _buildEmptyItemsState();
                    }

                    final items = snapshot.data!;
                    return Column(
                      children: items.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        final lineTotal = item.priceAtPurchase * item.quantity;

                        return Container(
                          margin: EdgeInsets.only(
                            bottom: index < items.length - 1 ? 12 : 0,
                          ),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.orange[100],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.fastfood_outlined,
                                      color: Colors.orange[800],
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              '${item.quantity}x ',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                                color: Color(0xFFE65100),
                                              ),
                                            ),
                                            Expanded(
                                              child: Text(
                                                item.menuItemName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (item.categoryName != null &&
                                            item.categoryName!.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.blue[50],
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              item.categoryName!,
                                              style: TextStyle(
                                                color: Colors.blue[800],
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                        if (item.itemRemarks != null &&
                                            item.itemRemarks!.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            'Note: ${item.itemRemarks}',
                                            style: const TextStyle(
                                              color: Colors.redAccent,
                                              fontSize: 12,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 4),
                                        Text(
                                          'Unit: €${item.priceAtPurchase.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green[600],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '€${lineTotal.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: const CircularProgressIndicator(),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading order items...',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline, color: Colors.red[400], size: 40),
          const SizedBox(height: 12),
          Text(
            'Failed to Load Items',
            style: TextStyle(
              color: Colors.red[700],
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: TextStyle(color: Colors.red[600], fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyItemsState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, color: Colors.grey[400], size: 40),
          const SizedBox(height: 12),
          Text(
            'No Items Found',
            style: TextStyle(
              color: Colors.grey[700],
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No items found for this order.',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    bool isEmphasized = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: isEmphasized ? 14 : 13,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: isEmphasized ? 14 : 13,
                fontWeight: isEmphasized ? FontWeight.bold : FontWeight.normal,
                color: isEmphasized ? Colors.green[700] : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCancelOrderDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange[600],
              size: 28,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Cancel Order?', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to cancel this order?',
              style: TextStyle(color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange[700], size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action will mark the order as cancelled.',
                      style: TextStyle(color: Colors.orange[800], fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep Order'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _cancelOrder();
            },
            icon: const Icon(Icons.cancel, size: 18),
            label: const Text('Cancel Order'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelOrder() async {
    if (widget.order.id == null) {
      snackbar_utils.showErrorSnackbar(
        context,
        'Cannot cancel order: Order ID is missing',
      );
      return;
    }

    setState(() => _saving = true);

    try {
      debugPrint('[OrderDetailScreen] Cancelling order: ${widget.order.id}');

      // First verify the order exists
      final existingOrder = await _supabase
          .from('orders')
          .select('id, status')
          .eq('id', widget.order.id!)
          .maybeSingle();

      debugPrint('[OrderDetailScreen] Existing order: $existingOrder');

      if (existingOrder == null) {
        if (!mounted) return;
        snackbar_utils.showErrorSnackbar(
          context,
          'Order not found in database',
        );
        return;
      }

      // Update order status to cancelled (without .select() to avoid empty response issue)
      await _supabase
          .from('orders')
          .update({'status': 'cancelled'})
          .eq('id', widget.order.id!);

      // Verify the update worked
      final updatedOrder = await _supabase
          .from('orders')
          .select('id, status')
          .eq('id', widget.order.id!)
          .maybeSingle();

      debugPrint('[OrderDetailScreen] Updated order: $updatedOrder');

      if (!mounted) return;

      if (updatedOrder != null && updatedOrder['status'] == 'cancelled') {
        snackbar_utils.showSuccessSnackbar(
          context,
          'Order cancelled successfully',
        );
        // Go back to previous screen with result indicating refresh needed
        Navigator.of(context).pop(true);
      } else {
        snackbar_utils.showErrorSnackbar(
          context,
          'Update may have failed. Current status: ${updatedOrder?['status'] ?? 'unknown'}',
        );
      }
    } catch (e) {
      debugPrint('[OrderDetailScreen] Error cancelling order: $e');
      if (!mounted) return;
      snackbar_utils.showErrorSnackbar(context, 'Failed to cancel order: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Order Details',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          // Only show cancel button if order is not already cancelled
          if (!widget.order.status.toLowerCase().contains('cancelled'))
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: Colors.grey[700]),
              tooltip: 'More options',
              onSelected: (value) {
                if (value == 'cancel') {
                  _showCancelOrderDialog();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem<String>(
                  value: 'cancel',
                  child: Row(
                    children: [
                      Icon(Icons.cancel_outlined, color: Colors.red, size: 20),
                      SizedBox(width: 12),
                      Text('Cancel Order', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(),
            _buildDetailCard(),
            _buildItemsCard(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
