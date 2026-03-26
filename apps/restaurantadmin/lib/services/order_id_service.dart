import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrderIdService {
  final SupabaseClient _supabase;

  OrderIdService(this._supabase);

  /// Generates a unique order ID in format: DDMMYYYYTTTTTTNN
  /// where:
  /// - DD = day (2 digits)
  /// - MM = month (2 digits)
  /// - YYYY = year (4 digits)
  /// - TTTTTT = total orders count (6 digits, zero-padded)
  /// - NN = daily order number (2 digits, zero-padded)
  /// 
  /// Example: 18102025250006 = Oct 18, 2025, 2500th total order, 6th order of the day
  Future<Map<String, dynamic>> generateOrderId() async {
    try {
      final now = DateTime.now();
      
      // Get date components
      final day = now.day.toString().padLeft(2, '0');
      final month = now.month.toString().padLeft(2, '0');
      final year = now.year.toString();
      
      // Get total order count from database
      final totalCountResponse = await _supabase
          .from('orders')
          .select('id')
          .count(CountOption.exact);
      
      final totalCount = totalCountResponse.count + 1; // +1 for the new order
      final totalCountStr = totalCount.toString().padLeft(6, '0');
      
      // Get today's order count
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = todayStart.add(const Duration(days: 1));
      
      final todayCountResponse = await _supabase
          .from('orders')
          .select('id')
          .gte('created_at', todayStart.toIso8601String())
          .lt('created_at', todayEnd.toIso8601String())
          .count(CountOption.exact);
      
      final dailyOrderNumber = todayCountResponse.count + 1; // +1 for the new order
      final dailyOrderStr = dailyOrderNumber.toString().padLeft(2, '0');
      
      // Construct the order ID
      final orderId = '$day$month$year$totalCountStr$dailyOrderStr';
      
      return {
        'orderId': orderId,
        'dailyOrderNumber': dailyOrderNumber,
        'totalOrderCount': totalCount,
      };
    } catch (e) {
      print('[OrderIdService] Error generating order ID: $e');
      // Fallback: use timestamp-based ID
      final now = DateTime.now();
      final fallbackId = DateFormat('ddMMyyyyHHmmss').format(now);
      return {
        'orderId': fallbackId,
        'dailyOrderNumber': 0,
        'totalOrderCount': 0,
      };
    }
  }
  
  /// Extract the daily order number from an order ID
  static int extractDailyOrderNumber(String orderId) {
    if (orderId.length >= 18) {
      final dailyStr = orderId.substring(16, 18);
      return int.tryParse(dailyStr) ?? 0;
    }
    return 0;
  }
  
  /// Extract the date from an order ID
  static DateTime? extractDate(String orderId) {
    if (orderId.length >= 8) {
      try {
        final day = int.parse(orderId.substring(0, 2));
        final month = int.parse(orderId.substring(2, 4));
        final year = int.parse(orderId.substring(4, 8));
        return DateTime(year, month, day);
      } catch (e) {
        return null;
      }
    }
    return null;
  }
  
  /// Format order ID for display (with spaces for readability)
  static String formatForDisplay(String orderId) {
    if (orderId.length >= 18) {
      final date = orderId.substring(0, 8);
      final total = orderId.substring(8, 14);
      final daily = orderId.substring(14, 16);
      return '$date-$total-$daily';
    }
    return orderId;
  }
}

