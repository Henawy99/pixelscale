class ResolvedMenuItemMaterial {
  final String materialId;
  final String materialName;
  final String? materialImageUrl;
  final double quantityUsed;
  final String unitOfMeasureUsed;
  final double averageUnitCost;
  final double totalCostForRecipe; // quantityUsed * averageUnitCost

  ResolvedMenuItemMaterial({
    required this.materialId,
    required this.materialName,
    this.materialImageUrl,
    required this.quantityUsed,
    required this.unitOfMeasureUsed,
    required this.averageUnitCost,
  }) : totalCostForRecipe = quantityUsed * averageUnitCost;

  factory ResolvedMenuItemMaterial.fromJson(Map<String, dynamic> mimJson, Map<String, dynamic> materialJson) {
    // Assumes mimJson is from menu_item_materials and materialJson is from material table
    return ResolvedMenuItemMaterial(
      materialId: materialJson['id'] as String,
      materialName: materialJson['name'] as String,
      materialImageUrl: materialJson['item_image_url'] as String?,
      quantityUsed: (mimJson['quantity_used'] as num).toDouble(),
      unitOfMeasureUsed: mimJson['unit_of_measure_for_usage'] as String,
      averageUnitCost: (materialJson['average_unit_cost'] as num?)?.toDouble() ?? 0.0,
    );
  }

  // Example if menu_item_materials join includes material details directly
  factory ResolvedMenuItemMaterial.fromJoinedData(Map<String, dynamic> joinedData) {
    // joinedData is expected to be a row from menu_item_materials
    // with material_id.* fields joined.
    final materialInfo = joinedData['material_id'] as Map<String, dynamic>? ?? {};
    
    return ResolvedMenuItemMaterial(
      materialId: materialInfo['id'] as String? ?? joinedData['material_id'] as String, // Fallback if not nested
      materialName: materialInfo['name'] as String? ?? 'Unknown Material',
      materialImageUrl: materialInfo['item_image_url'] as String?,
      quantityUsed: (joinedData['quantity_used'] as num).toDouble(),
      unitOfMeasureUsed: joinedData['unit_of_measure_for_usage'] as String,
      averageUnitCost: (materialInfo['average_unit_cost'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
