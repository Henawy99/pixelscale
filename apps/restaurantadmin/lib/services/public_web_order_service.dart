import 'package:restaurantadmin/config/online_brands.dart';
import 'package:restaurantadmin/models/cart_item.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WebOrderResult {
  final String orderId;
  final String orderNumber;
  final int dailyOrderNumber;
  final double totalPrice;
  final double? subtotal;
  final double? deliveryFee;
  final String brandName;
  final String status;

  WebOrderResult({
    required this.orderId,
    required this.orderNumber,
    required this.dailyOrderNumber,
    required this.totalPrice,
    this.subtotal,
    this.deliveryFee,
    required this.brandName,
    required this.status,
  });

  factory WebOrderResult.fromJson(Map<String, dynamic> json) {
    return WebOrderResult(
      orderId: json['orderId'] as String,
      orderNumber: json['orderNumber'] as String,
      dailyOrderNumber: (json['dailyOrderNumber'] as num).toInt(),
      totalPrice: (json['totalPrice'] as num).toDouble(),
      subtotal: (json['subtotal'] as num?)?.toDouble(),
      deliveryFee: (json['deliveryFee'] as num?)?.toDouble(),
      brandName: json['brandName'] as String,
      status: json['status'] as String,
    );
  }
}

class PublicWebOrderService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<WebOrderResult> placeOrder({
    required OnlineBrandConfig brand,
    required List<CartItem> cartItems,
    required String fulfillmentType,
    String paymentMethod = 'cash',
    String? customerName,
    String? customerStreet,
    String? customerPostcode,
    String? customerCity,
    String? customerPhone,
    String? note,
    DateTime? requestedDeliveryTime,
    double? deliveryLatitude,
    double? deliveryLongitude,
  }) async {
    final items = cartItems
        .map(
          (c) => {
            'menuItemId': c.menuItemWithRecipe.menuItem.id,
            'quantity': c.quantity,
          },
        )
        .toList();

    final response = await _supabase.functions.invoke(
      'create-web-order',
      body: {
        'brandSlug': brand.slug,
        'items': items,
        'fulfillmentType': fulfillmentType,
        'paymentMethod': paymentMethod,
        'customerName': customerName,
        'customerStreet': customerStreet,
        'customerPostcode': customerPostcode,
        'customerCity': customerCity,
        'customerPhone': customerPhone,
        'note': note,
        'requestedDeliveryTime': requestedDeliveryTime?.toIso8601String(),
        'deliveryLatitude': deliveryLatitude,
        'deliveryLongitude': deliveryLongitude,
      },
    );

    if (response.status < 200 || response.status >= 300) {
      final err = response.data is Map ? response.data['error'] : null;
      throw Exception(err?.toString() ?? 'Bestellung fehlgeschlagen');
    }

    final data = response.data as Map<String, dynamic>;
    if (data['error'] != null) {
      throw Exception(data['error'].toString());
    }

    return WebOrderResult.fromJson(data);
  }
}
