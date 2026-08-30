class OrderItem {
  final String? id; // Nullable if creating locally before DB insert
  final String orderId;
  final String? menuItemId; // Nullable for scanned orders without menu item matching
  final String menuItemName; // Denormalized for easier display
  final int quantity;
  final double priceAtPurchase; // Price of a single item at the time of purchase
  final String? brandId; // To know which brand this order item belongs to
  final String? categoryName; // Category name (e.g. Signature Burger, Beilagen)
  final String? itemCode;
  final dynamic specifications; // Options / specifications list
  final String? itemRemarks; // Item specific remarks/notes

  OrderItem({
    this.id,
    required this.orderId,
    this.menuItemId,
    required this.menuItemName,
    required this.quantity,
    required this.priceAtPurchase,
    this.brandId,
    this.categoryName,
    this.itemCode,
    this.specifications,
    this.itemRemarks,
  });

  Map<String, dynamic> toJson() {
    return {
      'order_id': orderId,
      'menu_item_id': menuItemId,
      'menu_item_name': menuItemName,
      'quantity': quantity,
      'price_at_purchase': priceAtPurchase,
      'brand_id': brandId,
      'category_name': categoryName,
      'item_code': itemCode,
      'specifications': specifications,
      'item_remarks': itemRemarks,
    };
  }

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] as String?,
      orderId: json['order_id'] as String? ?? '',
      menuItemId: json['menu_item_id'] as String?,
      menuItemName: json['menu_item_name'] as String? ?? 'Unknown Item',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      priceAtPurchase: (json['price_at_purchase'] as num?)?.toDouble() ?? 0.0,
      brandId: json['brand_id'] as String?,
      categoryName: json['category_name'] as String?,
      itemCode: json['item_code'] as String?,
      specifications: json['specifications'],
      itemRemarks: json['item_remarks'] as String?,
    );
  }
}
