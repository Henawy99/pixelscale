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
  final String? customerPhone; // Customer contact phone
  final String? verificationCode; // Lieferando phone masking/verify code
  final String? publicReference; // Platform short reference (e.g. #3FPDK7)
  final String? deliveryNotes; // Floor, door, buzzer instructions
  final dynamic platformRawData; // Complete raw JSON data from platform
  final int? foodPrepDuration; // Preparation duration in minutes
  final DateTime? requestedDeliveryTime;
  final DateTime? actualDeliveryTime;
  final DateTime? estimatedDeliveryTime; // Lieferando restaurant_estimated_delivery_time
  final DateTime? estimatedPickupTime; // Lieferando restaurant_estimated_pickup_time
  final String? platformOrderId; // For receipt-specific order IDs
  final String? note; // Order notes/comments
  final String?
  deliveryStatus; // e.g., "ready_to_deliver", "out_for_delivery", "delivered"
  final String?
  deliveryRouteId; // ID of the DeliveryRoute this order belongs to
  final int? deliveryRouteSequence; // Sequence number within its route
  final bool isDemo; // Flag for simulated/demo orders
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
    this.customerPhone,
    this.verificationCode,
    this.publicReference,
    this.deliveryNotes,
    this.platformRawData,
    this.foodPrepDuration,
    this.requestedDeliveryTime,
    this.actualDeliveryTime,
    this.estimatedDeliveryTime,
    this.estimatedPickupTime,
    this.platformOrderId,
    this.note,
    this.deliveryStatus,
    this.deliveryRouteId,
    this.deliveryRouteSequence,
    this.isDemo = false,
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
      'customer_phone': customerPhone,
      'verification_code': verificationCode,
      'public_reference': publicReference,
      'delivery_notes': deliveryNotes,
      'platform_raw_data': platformRawData,
      'food_prep_duration': foodPrepDuration,
      'requested_delivery_time': requestedDeliveryTime?.toIso8601String(),
      'actual_delivery_time': actualDeliveryTime?.toIso8601String(),
      'estimated_delivery_time': estimatedDeliveryTime?.toIso8601String(),
      'estimated_pickup_time': estimatedPickupTime?.toIso8601String(),
      'platform_order_id': platformOrderId,
      'note': note,
      'delivery_status': deliveryStatus,
      'delivery_route_id': deliveryRouteId,
      'delivery_route_sequence': deliveryRouteSequence,
      'is_demo': isDemo,
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

    // Fallback extraction from platform_raw_data if direct columns are null
    Map<String, dynamic>? rawMap;
    if (json['platform_raw_data'] is Map) {
      rawMap = Map<String, dynamic>.from(json['platform_raw_data'] as Map);
    }
    final rawCustomer = rawMap != null && rawMap['customer'] is Map ? rawMap['customer'] as Map : null;
    final detailsOrder = rawMap != null && rawMap['details'] is Map && rawMap['details']['order'] is Map
        ? rawMap['details']['order'] as Map
        : null;
    final deliveryLocation = detailsOrder != null && detailsOrder['delivery'] is Map && detailsOrder['delivery']['location'] is Map
        ? detailsOrder['delivery']['location'] as Map
        : null;

    final String? parsedCustomerPhone = (json['customer_phone'] as String?) ??
        (rawCustomer != null ? rawCustomer['phone_number']?.toString() : null);

    final String? parsedVerificationCode = (json['verification_code'] as String?) ??
        (rawCustomer != null ? rawCustomer['phone_masking_code']?.toString() : null);

    final String? parsedPublicRef = (json['public_reference'] as String?) ??
        (rawMap != null ? rawMap['public_reference']?.toString() : null) ??
        (json['platform_order_id'] as String?);

    String? parsedCustomerStreet = (json['customer_street'] as String?) ??
        (deliveryLocation != null ? deliveryLocation['AddressText']?.toString() : null);

    final rawStreetNumber = rawCustomer != null ? rawCustomer['street_number']?.toString() : null;
    if (parsedCustomerStreet != null &&
        rawStreetNumber != null &&
        rawStreetNumber.isNotEmpty &&
        !RegExp(r'\d').hasMatch(parsedCustomerStreet)) {
      parsedCustomerStreet = '$parsedCustomerStreet $rawStreetNumber';
    }

    final String? parsedCustomerCity = (json['customer_city'] as String?) ??
        (deliveryLocation != null ? deliveryLocation['city']?.toString() : null);

    final String? parsedCustomerPostcode = (json['customer_postcode'] as String?) ??
        (deliveryLocation != null ? deliveryLocation['postCode']?.toString() : null);

    DateTime? parseDateHelper(String? key, String? rawKey) {
      final val = json[key] as String?;
      if (val != null && val.isNotEmpty) {
        final d = DateTime.tryParse(val);
        if (d != null) return d;
      }
      if (rawMap != null && rawKey != null) {
        final rVal = rawMap[rawKey]?.toString();
        if (rVal != null && rVal.isNotEmpty) {
          return DateTime.tryParse(rVal);
        }
      }
      return null;
    }

    final DateTime? parsedEstDelivery = parseDateHelper('estimated_delivery_time', 'restaurant_estimated_delivery_time');
    final DateTime? parsedEstPickup = parseDateHelper('estimated_pickup_time', 'restaurant_estimated_pickup_time');

    // If items passed directly or inside json
    List<OrderItem> resolvedItems = items;
    if (resolvedItems.isEmpty && json['order_items'] is List && (json['order_items'] as List).isNotEmpty) {
      resolvedItems = (json['order_items'] as List)
          .map((i) => OrderItem.fromJson(i as Map<String, dynamic>))
          .toList();
    }

    return Order(
      id: json['id'] as String?,
      orderNumber: json['order_number'] as String?,
      dailyOrderNumber: (json['daily_order_number'] as num?)?.toInt(),
      brandId:
          json['brand_id'] as String? ?? 'UNKNOWN_BRAND_ID', // Provide fallback
      brandName: fetchedBrandName,
      orderItems: resolvedItems,
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
      customerStreet: parsedCustomerStreet,
      customerPostcode: parsedCustomerPostcode,
      customerCity: parsedCustomerCity,
      customerPhone: parsedCustomerPhone,
      verificationCode: parsedVerificationCode,
      publicReference: parsedPublicRef,
      deliveryNotes: json['delivery_notes'] as String?,
      platformRawData: json['platform_raw_data'],
      foodPrepDuration: (json['food_prep_duration'] as num?)?.toInt() ??
          (rawMap != null && rawMap['food_preparation_duration'] != null
              ? int.tryParse(rawMap['food_preparation_duration'].toString())
              : null),
      requestedDeliveryTime: json['requested_delivery_time'] == null
          ? null
          : DateTime.tryParse(json['requested_delivery_time'] as String),
      actualDeliveryTime: json['actual_delivery_time'] == null
          ? null
          : DateTime.tryParse(json['actual_delivery_time'] as String),
      estimatedDeliveryTime: parsedEstDelivery,
      estimatedPickupTime: parsedEstPickup,
      platformOrderId: json['platform_order_id'] as String?,
      note: json['note'] as String?,
      deliveryStatus: json['delivery_status'] as String?,
      deliveryRouteId: json['delivery_route_id'] as String?,
      deliveryRouteSequence: (json['delivery_route_sequence'] as num?)?.toInt(),
      isDemo: json['is_demo'] as bool? ?? false,
    );
  }
}
