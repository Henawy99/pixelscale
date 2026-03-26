import 'package:restaurantadmin/models/material_item.dart'; // Assuming MaterialItem is your existing model for materials

class ReceiptItem {
  final MaterialItem material;
  double quantity;
  double unitPricePaid;
  final String? unitOfMeasure; // To display alongside quantity

  ReceiptItem({
    required this.material,
    this.quantity = 0.0,
    this.unitPricePaid = 0.0,
    this.unitOfMeasure,
  });

  double get totalPricePaid => quantity * unitPricePaid;

  // Optional: If you need to convert to/from JSON for any reason (e.g., local storage)
  Map<String, dynamic> toJson() {
    return {
      'material_id': material.id,
      'material_name': material.name,
      'quantity': quantity,
      'unit_price_paid': unitPricePaid,
      'total_price_paid': totalPricePaid,
      'unit_of_measure': unitOfMeasure ?? material.unitOfMeasure,
    };
  }
}
