class DailySummaryData {
  final DateTime date;
  final double totalRevenue;
  final double totalProfit;
  final double totalMaterialCost;
  final int totalOrders; // This is the overall total (including employee meals if you count them)
  final int totalPickupOrders;
  final int totalDeliveryOrders;
  final List<OrderTypeSummary> orderTypeSummaries;
  final double totalCommissionsPaid;

  DailySummaryData({
    required this.date,
    required this.totalRevenue,
    required this.totalProfit,
    required this.totalMaterialCost,
    required this.totalOrders,
    required this.totalPickupOrders,
    required this.totalDeliveryOrders,
    required this.orderTypeSummaries,
    required this.totalCommissionsPaid,
  });
}

class OrderTypeSummary {
  final String typeName;
  final int orderCount;
  final double totalRevenueForType;
  final double totalCommissionForType;
  final double totalProfitForType; 
  final double totalMaterialCostForType;

  OrderTypeSummary({
    required this.typeName,
    required this.orderCount,
    required this.totalRevenueForType,
    required this.totalCommissionForType,
    required this.totalProfitForType,
    required this.totalMaterialCostForType,
  });
}
