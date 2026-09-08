import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:restaurantadmin/models/order.dart' as app_order;
import 'package:restaurantadmin/models/order_item.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:restaurantadmin/services/order_service.dart';
import 'package:restaurantadmin/services/label_printer_service.dart';
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
  late Future<Map<String, dynamic>?> _deliveryTrackingFuture;
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
      _deliveryTrackingFuture = _fetchDeliveryTracking(widget.order.id!);
    } else {
      _orderItemsFuture = Future.value([]);
      _deliveryTrackingFuture = Future.value(null);
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

  Future<Map<String, dynamic>?> _fetchDeliveryTracking(String orderId) async {
    try {
      final response = await _supabase
          .from('route_stops')
          .select('*, delivery_routes(id, status, started_at, planned_departure_at, actual_departure_at, drivers!delivery_routes_assigned_driver_id_fkey(id, name, phone_number))')
          .eq('order_id', orderId)
          .maybeSingle();

      if (response != null) {
        return Map<String, dynamic>.from(response);
      }
    } catch (e) {
      debugPrint('[OrderDetailScreen] Error fetching delivery tracking with FK: $e');
      try {
        final fallback = await _supabase
            .from('route_stops')
            .select('*, delivery_routes(id, status, started_at, planned_departure_at, actual_departure_at)')
            .eq('order_id', orderId)
            .maybeSingle();
        if (fallback != null) {
          return Map<String, dynamic>.from(fallback);
        }
      } catch (e2) {
        debugPrint('[OrderDetailScreen] Fallback delivery tracking failed: $e2');
      }
    }
    return null;
  }

  Future<void> _printStickers() async {
    try {
      final items = await _orderItemsFuture;
      if (items.isEmpty) {
        _showErrorSnackBar('No items to print');
        return;
      }
      
      int successCount = 0;
      for (var item in items) {
        for (int i = 0; i < item.quantity; i++) {
          final success = await LabelPrinterService.printItemLabel(
            itemName: item.menuItemName,
            quantity: 1,
            orderId: widget.order.publicReference ?? widget.order.orderNumber ?? '',
            orderType: widget.order.orderTypeName,
            fulfillmentType: widget.order.fulfillmentType,
          );
          if (success) successCount++;
        }
      }
      
      if (mounted) {
        if (successCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Sent $successCount stickers to printer!'),
            backgroundColor: Colors.green,
          ));
        } else {
          _showErrorSnackBar('Failed to print stickers. Check Zebra connection.');
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Print error: $e');
      }
    }
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isPickup ? Icons.shopping_bag_outlined : Icons.delivery_dining_outlined,
                  color: Colors.grey.shade800,
                  size: 28,
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
                              color: Colors.black87,
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
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Text(
                            isPickup ? 'PICKUP' : 'DELIVERY',
                            style: TextStyle(
                              color: Colors.grey.shade800,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.order.brandName ?? widget.order.brandId,
                      style: TextStyle(
                        color: Colors.grey.shade600,
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
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Text(
                  widget.order.status.replaceAll('_', ' ').toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1, color: Color(0xFFEEEEEE)),
          ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '€${widget.order.totalPrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Total Amount',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (widget.order.orderTypeName != null) ...[
                Container(
                  width: 1,
                  height: 36,
                  color: Colors.grey.shade200,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.order.orderTypeName!,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Platform',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '--:--';
    final local = dt.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Widget _buildTimelineCard() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: FutureBuilder<Map<String, dynamic>?>(
          future: _deliveryTrackingFuture,
          builder: (context, snapshot) {
            final tracking = snapshot.data;
            return _buildTimelineContent(tracking);
          },
        ),
      ),
    );
  }

  Widget _buildTimelineContent(Map<String, dynamic>? tracking) {
    final isPickup = (widget.order.fulfillmentType ?? '').toLowerCase() == 'pickup';

    final orderedTime = widget.order.createdAt.toLocal();

    // Preparation start time
    DateTime? prepTime;
    final raw = widget.order.platformRawData;
    if (raw is Map) {
      final rawConfirmed = raw['confirmedAt'] ?? raw['acceptedAt'] ?? raw['preparation_started_at'];
      if (rawConfirmed != null) {
        prepTime = DateTime.tryParse(rawConfirmed.toString())?.toLocal();
      }
    }
    prepTime ??= orderedTime.add(const Duration(minutes: 2));

    // In Delivery (dispatched) time
    DateTime? inDeliveryTime;
    final routeData = tracking?['delivery_routes'] as Map<String, dynamic>?;
    final routeStarted = routeData?['started_at'] ??
        routeData?['actual_departure_at'] ??
        routeData?['planned_departure_at'];
    if (routeStarted != null) {
      inDeliveryTime = DateTime.tryParse(routeStarted.toString())?.toLocal();
    }
    if (inDeliveryTime == null &&
        (widget.order.deliveryStatus == 'out_for_delivery' ||
         widget.order.deliveryStatus == 'delivered' ||
         widget.order.status == 'delivering' ||
         widget.order.status == 'delivered')) {
      inDeliveryTime = prepTime.add(Duration(minutes: widget.order.foodPrepDuration ?? 15));
    }

    // Estimated arrival / Target
    DateTime? estimatedArrivalTime;
    final plannedArrival = tracking?['planned_arrival_at'] ?? tracking?['estimated_arrival_time'];
    if (plannedArrival != null) {
      estimatedArrivalTime = DateTime.tryParse(plannedArrival.toString())?.toLocal();
    }
    estimatedArrivalTime ??= widget.order.estimatedDeliveryTime?.toLocal() ??
        widget.order.requestedDeliveryTime?.toLocal();

    final targetDeliveryTime = widget.order.estimatedDeliveryTime?.toLocal() ??
        widget.order.requestedDeliveryTime?.toLocal();

    // Actual delivered time
    DateTime? deliveredTime = widget.order.actualDeliveryTime?.toLocal();
    if (deliveredTime == null && tracking?['actual_arrival_time'] != null) {
      deliveredTime = DateTime.tryParse(tracking!['actual_arrival_time'].toString())?.toLocal();
    }

    // Status checks
    final isDelivered = deliveredTime != null ||
        widget.order.deliveryStatus == 'delivered' ||
        widget.order.status == 'delivered' ||
        widget.order.status == 'completed' ||
        tracking?['status'] == 'completed';

    final isInDelivery = !isDelivered &&
        (widget.order.deliveryStatus == 'out_for_delivery' ||
         widget.order.status == 'delivering' ||
         routeData?['status'] == 'in_progress');

    final isPreparing = !isDelivered && !isInDelivery &&
        (widget.order.status == 'preparing' ||
         widget.order.deliveryStatus == 'ready_to_deliver' ||
         widget.order.deliveryStatus == 'assigned_to_route');

    // Driver information
    final driverData = routeData?['drivers'] as Map<String, dynamic>?;
    final driverName = driverData?['name'] as String? ?? widget.order.assignedDriverId;
    final stopSequence = tracking?['sequence_number'] as int?;

    // Lateness calculation
    int? latenessMinutes;
    bool isLate = false;

    if (deliveredTime != null && targetDeliveryTime != null) {
      latenessMinutes = deliveredTime.difference(targetDeliveryTime).inMinutes;
      isLate = latenessMinutes > 0;
    } else if (estimatedArrivalTime != null && targetDeliveryTime != null) {
      final projectedDiff = estimatedArrivalTime.difference(targetDeliveryTime).inMinutes;
      latenessMinutes = projectedDiff;
      isLate = projectedDiff > 0;
    }

    // Durations
    String prepDurationStr = '${widget.order.foodPrepDuration ?? 15}m';
    if (inDeliveryTime != null) {
      final m = inDeliveryTime.difference(prepTime).inMinutes;
      if (m > 0) prepDurationStr = '${m}m';
    }

    String transitDurationStr = '--';
    if (deliveredTime != null && inDeliveryTime != null) {
      final m = deliveredTime.difference(inDeliveryTime).inMinutes;
      if (m > 0) transitDurationStr = '${m}m';
    } else if (isInDelivery && inDeliveryTime != null) {
      final m = DateTime.now().difference(inDeliveryTime).inMinutes;
      transitDurationStr = '${m}m';
    }

    // Build timeline steps
    final List<_TimelineStep> steps;
    if (!isPickup) {
      steps = [
        _TimelineStep(
          title: 'Ordered',
          time: _formatTime(orderedTime),
          isDone: true,
          isActive: false,
          icon: Icons.receipt_long_rounded,
          color: const Color(0xFF2563EB),
        ),
        _TimelineStep(
          title: 'Preparing',
          time: _formatTime(prepTime),
          isDone: isInDelivery || isDelivered,
          isActive: isPreparing,
          icon: Icons.outdoor_grill_rounded,
          color: const Color(0xFFF59E0B),
        ),
        _TimelineStep(
          title: 'In Delivery',
          time: inDeliveryTime != null ? _formatTime(inDeliveryTime) : '--:--',
          isDone: isDelivered,
          isActive: isInDelivery,
          icon: Icons.two_wheeler_rounded,
          color: const Color(0xFF3B82F6),
        ),
        _TimelineStep(
          title: 'Est. Arrival',
          time: estimatedArrivalTime != null ? _formatTime(estimatedArrivalTime) : '--:--',
          isDone: isDelivered,
          isActive: false,
          isTarget: true,
          icon: Icons.flag_rounded,
          color: const Color(0xFF8B5CF6),
        ),
        _TimelineStep(
          title: 'Delivered',
          time: deliveredTime != null ? _formatTime(deliveredTime) : (isDelivered ? 'Done' : 'Pending'),
          isDone: isDelivered,
          isActive: false,
          isLate: isDelivered && isLate,
          latenessMinutes: isDelivered ? latenessMinutes : null,
          icon: isDelivered && isLate ? Icons.timer_off_rounded : Icons.task_alt_rounded,
          color: isDelivered
              ? (isLate ? const Color(0xFFDC2626) : const Color(0xFF16A34A))
              : const Color(0xFF94A3B8),
        ),
      ];
    } else {
      steps = [
        _TimelineStep(
          title: 'Ordered',
          time: _formatTime(orderedTime),
          isDone: true,
          isActive: false,
          icon: Icons.receipt_long_rounded,
          color: const Color(0xFF2563EB),
        ),
        _TimelineStep(
          title: 'Preparing',
          time: _formatTime(prepTime),
          isDone: isDelivered,
          isActive: isPreparing,
          icon: Icons.outdoor_grill_rounded,
          color: const Color(0xFFF59E0B),
        ),
        _TimelineStep(
          title: 'Ready',
          time: _formatTime(widget.order.estimatedPickupTime),
          isDone: isDelivered,
          isActive: !isDelivered && !isPreparing,
          icon: Icons.shopping_bag_rounded,
          color: const Color(0xFF3B82F6),
        ),
        _TimelineStep(
          title: 'Picked Up',
          time: deliveredTime != null ? _formatTime(deliveredTime) : (isDelivered ? 'Done' : 'Pending'),
          isDone: isDelivered,
          isActive: false,
          isLate: isDelivered && isLate,
          latenessMinutes: isDelivered ? latenessMinutes : null,
          icon: Icons.check_circle_rounded,
          color: isDelivered
              ? (isLate ? const Color(0xFFDC2626) : const Color(0xFF16A34A))
              : const Color(0xFF94A3B8),
        ),
      ];
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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
            // Row 1: Header + Punctuality Badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.access_time_filled_rounded,
                    color: Color(0xFF2563EB),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Order & Delivery Timeline',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                // Punctuality Badge
                if (isDelivered) ...[
                  if (isLate && latenessMinutes != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.timer_off_rounded, size: 14, color: Color(0xFFDC2626)),
                          const SizedBox(width: 5),
                          Text(
                            '$latenessMinutes min late',
                            style: const TextStyle(
                              color: Color(0xFFDC2626),
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF16A34A)),
                          const SizedBox(width: 5),
                          Text(
                            latenessMinutes != null && latenessMinutes < 0
                                ? '${-latenessMinutes}m early'
                                : 'On time',
                            style: const TextStyle(
                              color: Color(0xFF16A34A),
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                ] else if (isInDelivery) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF93C5FD)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.two_wheeler_rounded, size: 14, color: Color(0xFF2563EB)),
                        const SizedBox(width: 5),
                        Text(
                          isLate && latenessMinutes != null
                              ? 'Delay +${latenessMinutes}m'
                              : 'In Delivery',
                          style: TextStyle(
                            color: isLate ? const Color(0xFFDC2626) : const Color(0xFF2563EB),
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (isPreparing) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFCD34D)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.outdoor_grill_rounded, size: 14, color: Color(0xFFD97706)),
                        SizedBox(width: 5),
                        Text(
                          'Preparing',
                          style: TextStyle(
                            color: Color(0xFFD97706),
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),

            // Stepper Track
            LayoutBuilder(
              builder: (context, constraints) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(steps.length * 2 - 1, (index) {
                    if (index.isOdd) {
                      // Connector line between node (index ~/ 2) and (index ~/ 2 + 1)
                      final prevStepIdx = index ~/ 2;
                      final isLineDone = steps[prevStepIdx].isDone;
                      return Expanded(
                        child: Container(
                          height: 3,
                          margin: const EdgeInsets.only(top: 17),
                          decoration: BoxDecoration(
                            color: isLineDone
                                ? const Color(0xFF16A34A)
                                : const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    }
                    final step = steps[index ~/ 2];
                    return _buildTimelineNode(step);
                  }),
                );
              },
            ),

            const SizedBox(height: 18),

            // Metrics Summary Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  _buildMetricColumn('Ordered', _formatTime(orderedTime), Icons.receipt_rounded, const Color(0xFF2563EB)),
                  _buildMetricDivider(),
                  _buildMetricColumn('Kitchen Prep', prepDurationStr, Icons.outdoor_grill_rounded, const Color(0xFFD97706)),
                  _buildMetricDivider(),
                  _buildMetricColumn('In Transit', transitDurationStr, Icons.two_wheeler_rounded, const Color(0xFF4F46E5)),
                  _buildMetricDivider(),
                  _buildMetricColumn(
                    isDelivered ? 'Punctuality' : 'Target ETA',
                    isDelivered
                        ? (isLate && latenessMinutes != null ? '+$latenessMinutes min late' : 'On time')
                        : _formatTime(targetDeliveryTime),
                    isDelivered
                        ? (isLate ? Icons.timer_off_rounded : Icons.check_circle_rounded)
                        : Icons.flag_rounded,
                    isDelivered
                        ? (isLate ? const Color(0xFFDC2626) : const Color(0xFF16A34A))
                        : const Color(0xFF7C3AED),
                    isHighlight: isDelivered && isLate,
                  ),
                ],
              ),
            ),

            // Driver assignment bar (if any)
            if (driverName != null && driverName.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.delivery_dining_rounded, size: 18, color: Color(0xFF2563EB)),
                    const SizedBox(width: 8),
                    Text(
                      'Assigned Driver: $driverName',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Color(0xFF1E40AF),
                      ),
                    ),
                    if (stopSequence != null && stopSequence > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDBEAFE),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Delivery Stop #$stopSequence',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                            color: Color(0xFF1E40AF),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineNode(_TimelineStep step) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Circle
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: step.isDone
                ? (step.isLate ? const Color(0xFFDC2626) : (step.isTarget ? const Color(0xFF7C3AED) : const Color(0xFF16A34A)))
                : step.isActive
                    ? step.color
                    : const Color(0xFFF1F5F9),
            shape: BoxShape.circle,
            border: Border.all(
              color: step.isDone || step.isActive
                  ? Colors.transparent
                  : const Color(0xFFCBD5E1),
              width: 1.5,
            ),
            boxShadow: step.isActive
                ? [
                    BoxShadow(
                      color: step.color.withOpacity(0.35),
                      blurRadius: 8,
                      spreadRadius: 2,
                    )
                  ]
                : null,
          ),
          child: Center(
            child: Icon(
              step.isDone && !step.isLate && !step.isTarget
                  ? Icons.check_rounded
                  : step.icon,
              size: 18,
              color: step.isDone || step.isActive ? Colors.white : const Color(0xFF94A3B8),
            ),
          ),
        ),
        const SizedBox(height: 6),
        // Label
        Text(
          step.title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: step.isActive || step.isDone ? FontWeight.w700 : FontWeight.w500,
            color: step.isActive
                ? step.color
                : (step.isDone ? const Color(0xFF1E293B) : const Color(0xFF94A3B8)),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 3),
        // Time pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: step.isLate
                ? const Color(0xFFFEF2F2)
                : (step.isDone ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC)),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: step.isLate
                  ? const Color(0xFFFCA5A5)
                  : (step.isDone ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0)),
            ),
          ),
          child: Text(
            step.time,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              fontFamily: 'monospace',
              color: step.isLate
                  ? const Color(0xFFDC2626)
                  : (step.isDone ? const Color(0xFF15803D) : const Color(0xFF64748B)),
            ),
          ),
        ),
        // Late badge under Delivered
        if (step.isLate && step.latenessMinutes != null) ...[
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            decoration: BoxDecoration(
              color: const Color(0xFFDC2626),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '+${step.latenessMinutes}m late',
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMetricColumn(String label, String value, IconData icon, Color color, {bool isHighlight = false}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: isHighlight ? color : Colors.black87,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricDivider() {
    return Container(
      width: 1,
      height: 24,
      color: const Color(0xFFE2E8F0),
      margin: const EdgeInsets.symmetric(horizontal: 4),
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
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: const Icon(Icons.map_outlined, size: 20, color: Colors.blue),
                                  tooltip: 'Open in Google Maps',
                                  onPressed: () async {
                                    final address = '${widget.order.customerStreet ?? ''}, ${widget.order.customerPostcode ?? ''} ${widget.order.customerCity ?? ''}'.trim();
                                    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}');
                                    if (await canLaunchUrl(uri)) {
                                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                                    } else {
                                      snackbar_utils.showErrorSnackbar(context, 'Could not open Google Maps');
                                    }
                                  },
                                ),
                                const SizedBox(width: 12),
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: const Icon(Icons.copy, size: 18),
                                  tooltip: 'Copy Address',
                                  onPressed: () {
                                    final address = '${widget.order.customerStreet ?? ''}, ${widget.order.customerPostcode ?? ''} ${widget.order.customerCity ?? ''}'.trim();
                                    Clipboard.setData(ClipboardData(text: address));
                                    snackbar_utils.showSuccessSnackbar(context, 'Address copied');
                                  },
                                ),
                              ],
                            ),
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
                    const Spacer(),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.print, size: 18),
                      label: const Text('Print Stickers'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onPressed: _printStickers,
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
    Widget? trailing,
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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  trailing,
                ],
              ],
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
            _buildTimelineCard(),
            _buildDetailCard(),
            _buildItemsCard(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _TimelineStep {
  final String title;
  final String time;
  final bool isDone;
  final bool isActive;
  final bool isTarget;
  final bool isLate;
  final int? latenessMinutes;
  final IconData icon;
  final Color color;

  const _TimelineStep({
    required this.title,
    required this.time,
    required this.isDone,
    required this.isActive,
    this.isTarget = false,
    this.isLate = false,
    this.latenessMinutes,
    required this.icon,
    required this.color,
  });
}
