import 'package:restaurantadmin/models/order_item.dart';

class Order {
  final String? id; // Nullable if creating locally before DB insert
  final String? orderNumber; // Custom order number: DDMMYYYYTTTTTTNN
  final int? dailyOrderNumber; // Daily order number (NN part)
  final String brandId;
  final String? brandName; // To store fetched brand name
  final List<OrderItem>
  orderItems; // Keep for detail view, but make optional for list
  final double totalPrice;
  final String
  status; // e.g., "pending_payment", "confirmed", "preparing", "completed", "cancelled"
  final DateTime createdAt;
  final DateTime? scannedDate; // When the receipt was scanned
  final double? profit; // Added profit field
  final String? orderTypeName;
  final String? orderTypeId; // UUID
  final double? commissionAmount;
  final double? fixedServiceFee;
  final double? deliveryFee; // Delivery fee
  final double? totalMaterialCost; // Added total material cost
  final String paymentMethod; // e.g., 'cash', 'online', 'card_terminal'
  final String? stripePaymentIntentId; // For Stripe payments
  final String? fulfillmentType; // e.g., 'pickup', 'delivery'
  final String? assignedDriverId; // ID of the assigned driver
  final double? deliveryLatitude; // Latitude for delivery
  final double? deliveryLongitude; // Longitude for delivery
  final String? customerName;
  final String? customerStreet; // Full street address including number
  final String? customerPostcode;
  final String? customerCity;
  final DateTime? requestedDeliveryTime;
  final DateTime? actualDeliveryTime;
  final String? platformOrderId; // For receipt-specific order IDs
  final String? note; // Order notes/comments
  final String?
  deliveryStatus; // e.g., "ready_to_deliver", "out_for_delivery", "delivered"
  final String?
  deliveryRouteId; // ID of the DeliveryRoute this order belongs to
  final int? deliveryRouteSequence; // Sequence number within its route
  // Add other fields as needed, e.g., userId, tableNumber

  Order({
    this.id,
    this.orderNumber,
    this.dailyOrderNumber,
    required this.brandId,
    this.brandName,
    this.orderItems = const [], // Default to empty list
    required this.totalPrice,
    required this.status, // e.g., "pending_payment", "processing_terminal", "paid", "failed"
    required this.createdAt,
    this.scannedDate,
    this.profit,
    this.orderTypeName,
    this.orderTypeId,
    this.commissionAmount,
    this.fixedServiceFee,
    this.deliveryFee,
    this.totalMaterialCost,
    required this.paymentMethod,
    this.stripePaymentIntentId,
    this.fulfillmentType,
    this.assignedDriverId,
    this.deliveryLatitude,
    this.deliveryLongitude,
    this.customerName,
    this.customerStreet,
    this.customerPostcode,
    this.customerCity,
    this.requestedDeliveryTime,
    this.actualDeliveryTime,
    this.platformOrderId,
    this.note,
    this.deliveryStatus,
    this.deliveryRouteId,
    this.deliveryRouteSequence,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id, // Client-generated ID
      'order_number': orderNumber,
      'daily_order_number': dailyOrderNumber,
      'brand_id': brandId,
      'total_price': totalPrice,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'scanned_date': scannedDate?.toIso8601String(),
      'profit': profit,
      'order_type_name': orderTypeName,
      'order_type_id': orderTypeId,
      'commission_amount': commissionAmount,
      'fixed_service_fee': fixedServiceFee,
      'delivery_fee': deliveryFee,
      'total_material_cost': totalMaterialCost,
      'payment_method': paymentMethod,
      'stripe_payment_intent_id': stripePaymentIntentId,
      'fulfillment_type': fulfillmentType,
      'assigned_driver_id': assignedDriverId,
      'delivery_latitude': deliveryLatitude,
      'delivery_longitude': deliveryLongitude,
      'customer_name': customerName,
      'customer_street': customerStreet,
      'customer_postcode': customerPostcode,
      'customer_city': customerCity,
      'requested_delivery_time': requestedDeliveryTime?.toIso8601String(),
      'actual_delivery_time': actualDeliveryTime?.toIso8601String(),
      'platform_order_id': platformOrderId,
      'note': note,
      'delivery_status': deliveryStatus,
      'delivery_route_id': deliveryRouteId,
      'delivery_route_sequence': deliveryRouteSequence,
    };
  }

  factory Order.fromJson(
    Map<String, dynamic> json, {
    List<OrderItem> items = const [],
  }) {
    // items is now optional
    String? fetchedBrandName;
    if (json['brands'] != null && json['brands'] is Map) {
      fetchedBrandName = json['brands']['name'] as String?;
    } else if (json['brand_name'] != null) {
      // Fallback if brand_name is directly in json
      fetchedBrandName = json['brand_name'] as String?;
    }

    // Helper to safely parse DateTime, returning a default or throwing if absolutely critical and no default makes sense
    DateTime parseDateTime(String? dateString, String fieldName) {
      if (dateString == null) {
        print(
          "Warning: DateTime field '$fieldName' is null. Using current time as fallback.",
        );
        return DateTime.now(); // Or throw FormatException if this is unacceptable
      }
      try {
        return DateTime.parse(dateString);
      } catch (e) {
        print(
          "Warning: Invalid date format for '$fieldName' ('$dateString'). Using current time as fallback. Error: $e",
        );
        return DateTime.now(); // Or throw
      }
    }

    return Order(
      id: json['id'] as String?,
      orderNumber: json['order_number'] as String?,
      dailyOrderNumber: (json['daily_order_number'] as num?)?.toInt(),
      brandId:
          json['brand_id'] as String? ?? 'UNKNOWN_BRAND_ID', // Provide fallback
      brandName: fetchedBrandName,
      orderItems: items,
      totalPrice:
          (json['total_price'] as num?)?.toDouble() ??
          0.0, // Handle null total_price
      status: json['status'] as String? ?? 'unknown', // Provide fallback
      createdAt: parseDateTime(
        json['created_at'] as String?,
        'created_at',
      ), // Use helper
      scannedDate: json['scanned_date'] == null ? null : DateTime.tryParse(json['scanned_date'] as String),
      profit: (json['profit'] as num?)?.toDouble(),
      orderTypeName: json['order_type_name'] as String?,
      orderTypeId: json['order_type_id'] as String?,
      commissionAmount: (json['commission_amount'] as num?)?.toDouble(),
      fixedServiceFee: (json['fixed_service_fee'] as num?)?.toDouble(),
      deliveryFee: (json['delivery_fee'] as num?)?.toDouble(),
      totalMaterialCost: (json['total_material_cost'] as num?)?.toDouble(),
      paymentMethod: json['payment_method'] as String? ?? 'unknown_method',
      stripePaymentIntentId: json['stripe_payment_intent_id'] as String?,
      fulfillmentType: json['fulfillment_type'] as String?,
      assignedDriverId: json['assigned_driver_id'] as String?,
      deliveryLatitude: (json['delivery_latitude'] as num?)?.toDouble(),
      deliveryLongitude: (json['delivery_longitude'] as num?)?.toDouble(),
      customerName: json['customer_name'] as String?,
      customerStreet: json['customer_street'] as String?,
      customerPostcode: json['customer_postcode'] as String?,
      customerCity: json['customer_city'] as String?,
      requestedDeliveryTime: json['requested_delivery_time'] == null
          ? null
          : DateTime.tryParse(json['requested_delivery_time'] as String),
      actualDeliveryTime: json['actual_delivery_time'] == null
          ? null
          : DateTime.tryParse(json['actual_delivery_time'] as String),
      platformOrderId: json['platform_order_id'] as String?,
      note: json['note'] as String?,
      deliveryStatus: json['delivery_status'] as String?,
      deliveryRouteId: json['delivery_route_id'] as String?,
      deliveryRouteSequence: (json['delivery_route_sequence'] as num?)?.toInt(),
    );
  }
}
