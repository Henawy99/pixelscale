enum InventoryValueEventType { added, deducted }

class InventoryValueEvent {
  final String id; // Corresponds to receipt_id or order_id
  final DateTime eventDate;
  final InventoryValueEventType type;
  final double valueChange; // Always positive, type determines if added/deducted
  final String description; // e.g., "Receipt: Wholesaler X" or "Order #12345"
  final Map<String, dynamic>? rawData; // To store the original order or receipt data for detail view

  InventoryValueEvent({
    required this.id,
    required this.eventDate,
    required this.type,
    required this.valueChange,
    required this.description,
    this.rawData,
  });
}
