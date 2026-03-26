import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:restaurantadmin/models/order.dart' as app_order;
import 'package:restaurantadmin/models/order_item.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:restaurantadmin/services/order_service.dart';
import 'package:restaurantadmin/utils/snackbar_utils.dart' as snackbar_utils;

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
      // Should ideally not happen if navigated with a valid order
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
      return loadedItems;
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error fetching order items: $e');
      }
      print(
        '[OrderDetailScreen] Error fetching order items for order $orderId: $e',
      );
      return [];
    }
  }

  void _showErrorSnackBar(String message) {
    snackbar_utils.showErrorSnackbar(context, message);
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'preparing':
        return Colors.purple;
      case 'ready':
        return Colors.green;
      case 'delivered':
        return Colors.teal;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildHeader() {
    final statusColor = _getStatusColor(widget.order.status);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [Colors.blue[600]!, Colors.blue[400]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 12,
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
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.receipt_long,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #${widget.order.id?.substring(0, 8) ?? 'Unknown'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.order.brandName ?? widget.order.brandId,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
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
                ),
                child: Text(
                  widget.order.status.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '€${widget.order.totalPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'Total Revenue',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (widget.order.profit != null) ...[
                  Container(
                    width: 1,
                    height: 40,
                    color: Colors.white.withOpacity(0.3),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          '€${widget.order.profit!.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          'Net Profit',
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
                    Icon(Icons.info_outline, color: Colors.blue[600], size: 24),
                    const SizedBox(width: 12),
                    const Text(
                      'Order Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildDetailRow('Order ID:', widget.order.id ?? 'N/A'),
                _buildDetailRow(
                  'Brand:',
                  widget.order.brandName ?? widget.order.brandId,
                ),
                _buildDetailRow('Status:', widget.order.status),
                _buildDetailRow(
                  'Order Date:',
                  DateFormat.yMMMMEEEEd().add_jm().format(
                    widget.order.createdAt.toLocal(),
                  ),
                ),
                if (widget.order.orderTypeName != null)
                  _buildDetailRow('Order Type:', widget.order.orderTypeName!),
                if (widget.order.platformOrderId != null)
                  _buildDetailRow(
                    'Platform ID:',
                    widget.order.platformOrderId!,
                  ),
                if (widget.order.paymentMethod != 'unknown' &&
                    widget.order.paymentMethod.isNotEmpty)
                  _buildDetailRow(
                    'Payment:',
                    widget.order.paymentMethod.toUpperCase(),
                  ),
                if (widget.order.fulfillmentType != null)
                  _buildDetailRow(
                    'Fulfillment:',
                    widget.order.fulfillmentType!.toUpperCase(),
                  ),
                const SizedBox(height: 16),

                // Customer Info Section
                if (widget.order.customerName != null ||
                    widget.order.customerStreet != null ||
                    widget.order.customerCity != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.person,
                              size: 18,
                              color: Colors.blue[700],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Customer Information',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (widget.order.customerName != null)
                          _buildDetailRow('Name:', widget.order.customerName!),
                        if (widget.order.customerStreet != null)
                          _buildDetailRow(
                            'Street:',
                            widget.order.customerStreet!,
                          ),
                        if (widget.order.customerPostcode != null ||
                            widget.order.customerCity != null)
                          _buildDetailRow(
                            'City:',
                            '${widget.order.customerPostcode ?? ''} ${widget.order.customerCity ?? ''}'
                                .trim(),
                          ),
                        if (widget.order.note != null &&
                            widget.order.note!.isNotEmpty)
                          _buildDetailRow('Note:', widget.order.note!),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Column(
                    children: [
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
                    Icon(
                      Icons.restaurant_menu,
                      color: Colors.orange[600],
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Items Ordered',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
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
                        return Container(
                          margin: EdgeInsets.only(
                            bottom: index < items.length - 1 ? 12 : 0,
                          ),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.orange[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.fastfood,
                                  color: Colors.orange[600],
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.menuItemName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Quantity: ${item.quantity}',
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
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.green[600]!,
                                      Colors.green[400]!,
                                    ],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '€${(item.priceAtPurchase * item.quantity).toStringAsFixed(2)}',
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
