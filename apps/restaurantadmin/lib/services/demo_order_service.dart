// lib/services/demo_order_service.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DemoOrderService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Creates a demo order cloned randomly from past orders with 60 min ETA,
  /// then triggers the planner to assign it to the demo driver (Abunageb).
  static Future<Map<String, dynamic>> createDemoOrder({String? brandId}) async {
    try {
      final response = await _supabase.functions.invoke(
        'create-demo-order',
        body: {
          'action': 'create',
          if (brandId != null) 'brand_id': brandId,
        },
      );

      if (response.status != 200) {
        throw Exception(response.data?['error'] ?? 'Server error: ${response.status}');
      }

      return response.data as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[DemoOrderService] Error creating demo order: $e');
      rethrow;
    }
  }

  /// Clears all demo orders, demo routes, and resets the demo driver.
  static Future<void> resetDemoOrders({String? brandId}) async {
    try {
      final response = await _supabase.functions.invoke(
        'create-demo-order',
        body: {
          'action': 'reset',
          if (brandId != null) 'brand_id': brandId,
        },
      );

      if (response.status != 200) {
        throw Exception(response.data?['error'] ?? 'Server error: ${response.status}');
      }
    } catch (e) {
      debugPrint('[DemoOrderService] Error resetting demo orders: $e');
      rethrow;
    }
  }
}
