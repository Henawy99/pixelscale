import 'package:intl/intl.dart';
import 'package:restaurantadmin/models/daily_summary_data.dart';
import 'package:restaurantadmin/models/order.dart' as app_order;
import 'package:supabase_flutter/supabase_flutter.dart';

class DailySummaryService {
  final SupabaseClient _supabase = Supabase.instance.client;
  static const String _employeeOrderTypeName = "Employee Meal";

  Future<DailySummaryData> generateDailySummary(DateTime date) async {
    final DateFormat formatter = DateFormat('yyyy-MM-dd');
    final String dateString = formatter.format(date);

    final todayStart = DateTime(
      date.year,
      date.month,
      date.day,
    ).toIso8601String();
    final tomorrowStart = DateTime(
      date.year,
      date.month,
      date.day,
    ).add(const Duration(days: 1)).toIso8601String();

    print(
      '[DailySummaryService] Fetching orders for summary from $todayStart to $tomorrowStart',
    );

    try {
      final response = await _supabase
          .from('orders')
          .select(
            'total_price, profit, total_material_cost, order_type_name, commission_amount, fixed_service_fee, fulfillment_type',
          ) // Added fulfillment_type
          .gte('created_at', todayStart)
          .lt('created_at', tomorrowStart);

      final List<app_order.Order> orders = (response as List)
          .map((data) => app_order.Order.fromJson(data as Map<String, dynamic>))
          .toList();

      print(
        '[DailySummaryService] Fetched ${orders.length} orders for date: $dateString',
      );

      double overallTotalRevenue = 0;
      double overallTotalProfit = 0;
      double overallTotalMaterialCost = 0;
      int overallTotalOrders = 0;
      int overallPickupOrders = 0; // New counter
      int overallDeliveryOrders = 0; // New counter
      double overallTotalCommissions = 0;

      Map<String, MutableOrderTypeSummary> orderTypeSummaryMap = {};

      for (var order in orders) {
        overallTotalOrders++;

        // Count fulfillment types
        if (order.fulfillmentType == 'pickup') {
          overallPickupOrders++;
        } else if (order.fulfillmentType == 'delivery') {
          overallDeliveryOrders++;
        }

        final String typeName = order.orderTypeName ?? 'Standard Order';
        MutableOrderTypeSummary summary = orderTypeSummaryMap.putIfAbsent(
          typeName,
          () => MutableOrderTypeSummary(typeName: typeName),
        );

        summary.orderCount++;

        if (order.orderTypeName != _employeeOrderTypeName) {
          overallTotalRevenue += order.totalPrice;
          summary.totalRevenueForType += order.totalPrice;
        }

        // Profit and MaterialCost should be counted for all orders, including employee meals (where profit would be negative)
        // Assuming order.profit already represents the net profit (Revenue - COGS - Commissions - Fees)
        // If order.profit was meant to be gross profit (Revenue - COGS), then DailySummaryService logic would need adjustment.
        // Based on current OrderService, order.profit is net profit.
        overallTotalProfit += order.profit ?? 0;
        summary.totalProfitForType += order.profit ?? 0;

        overallTotalMaterialCost += order.totalMaterialCost ?? 0;
        summary.totalMaterialCostForType += order.totalMaterialCost ?? 0;

        final double commission = order.commissionAmount ?? 0;
        final double serviceFee =
            order.fixedServiceFee ??
            0; // Assuming fixedServiceFee is also a "commission" from platform
        final double currentOrderCommissions = commission + serviceFee;

        overallTotalCommissions += currentOrderCommissions;
        summary.totalCommissionForType += currentOrderCommissions;
      }

      final List<OrderTypeSummary> finalOrderTypeSummaries = orderTypeSummaryMap
          .values
          .map(
            (mutableSummary) => OrderTypeSummary(
              typeName: mutableSummary.typeName,
              orderCount: mutableSummary.orderCount,
              totalRevenueForType: mutableSummary.totalRevenueForType,
              totalCommissionForType: mutableSummary.totalCommissionForType,
              totalProfitForType: mutableSummary.totalProfitForType,
              totalMaterialCostForType: mutableSummary.totalMaterialCostForType,
            ),
          )
          .toList();

      return DailySummaryData(
        date: date,
        totalRevenue: overallTotalRevenue,
        totalProfit: overallTotalProfit,
        totalMaterialCost: overallTotalMaterialCost,
        totalOrders: overallTotalOrders,
        totalPickupOrders: overallPickupOrders, // Pass to constructor
        totalDeliveryOrders: overallDeliveryOrders, // Pass to constructor
        orderTypeSummaries: finalOrderTypeSummaries,
        totalCommissionsPaid: overallTotalCommissions,
      );
    } catch (e, stackTrace) {
      print('[DailySummaryService] Error generating daily summary: $e');
      print('[DailySummaryService] StackTrace: $stackTrace');
      // Depending on how you want to handle errors, you might rethrow or return an empty/error state
      throw Exception('Failed to generate daily summary: $e');
    }
  }
}

// Helper class for mutable accumulation
class MutableOrderTypeSummary {
  final String typeName;
  int orderCount = 0;
  double totalRevenueForType = 0;
  double totalCommissionForType = 0;
  double totalProfitForType = 0;
  double totalMaterialCostForType = 0;

  MutableOrderTypeSummary({required this.typeName});
}
