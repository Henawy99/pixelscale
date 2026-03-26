class MenuItemMaterial {
  final String id;
  final DateTime createdAt;
  final String menuItemId;
  final String materialId;
  final double quantityUsed;
  final String unitOfMeasureUsed;
  final String? notes;

  // Optional: To hold denormalized material name for easier display if needed
  final String? materialName;
  final String? materialItemImageUrl; // Added for material image

  MenuItemMaterial({
    required this.id,
    required this.createdAt,
    required this.menuItemId,
    required this.materialId,
    required this.quantityUsed,
    required this.unitOfMeasureUsed,
    this.notes,
    this.materialName,
    this.materialItemImageUrl, // Added
  });

  factory MenuItemMaterial.fromJson(Map<String, dynamic> json, {String? materialName, String? materialItemImageUrlParam}) {
    // Helper to safely get a non-nullable string or throw
    String getRequiredString(String key, Map<String, dynamic> sourceJson) {
      final value = sourceJson[key];
      if (value == null) {
        throw FormatException("Missing required field '$key' in MenuItemMaterial JSON: $sourceJson");
      }
      if (value is! String) {
        throw FormatException("Field '$key' is not a String (is ${value.runtimeType}) in MenuItemMaterial JSON: $sourceJson");
      }
      return value;
    }

    String actualMaterialId;
    String? fetchedMaterialName = materialName; // Use the passed one first, if any
    String? fetchedMaterialItemImageUrl = materialItemImageUrlParam; // Use passed one first

    final materialIdField = json['material_id'];
    if (materialIdField is Map<String, dynamic>) {
      // Data comes from a join, material_id is an object
      final materialData = materialIdField;
      actualMaterialId = materialData['id'] as String? ?? (throw FormatException("Missing 'id' in nested material_id object in MenuItemMaterial JSON: $json"));
      // If materialName wasn't passed explicitly, try to get it from the joined data
      fetchedMaterialName ??= materialData['name'] as String?;
      fetchedMaterialItemImageUrl ??= materialData['item_image_url'] as String?; // Get image URL
    } else if (materialIdField is String) {
      // Data is flat, material_id is just a UUID string
      actualMaterialId = materialIdField;
    } else if (materialIdField == null) {
      throw FormatException("Missing required field 'material_id' in MenuItemMaterial JSON: $json");
    } 
    else {
      throw FormatException("Field 'material_id' is not a String or a Map (is ${materialIdField.runtimeType}) in MenuItemMaterial JSON: $json");
    }
    
    // If materialName still null after checking joined data, try to get it from a direct 'material_name' field.
    // This handles cases where the join might be aliased or structured differently in other queries,
    // or if materialName was not passed as a parameter.
    fetchedMaterialName ??= json['material_name'] as String?;

    final createdAtString = getRequiredString('created_at', json);
    DateTime createdAtDate;
    try {
      createdAtDate = DateTime.parse(createdAtString);
    } catch (e) {
      throw FormatException("Invalid date format for 'created_at' ('$createdAtString') in MenuItemMaterial JSON: $e");
    }

    // Ensure quantityUsed is present and a number, default to 0.0 if necessary (though DB should prevent null)
    final quantityNum = json['quantity_used'];
    if (quantityNum == null) {
        throw FormatException("Missing required field 'quantity_used' in MenuItemMaterial JSON: $json");
    }
    if (quantityNum is! num) {
        throw FormatException("Field 'quantity_used' is not a number (is ${quantityNum.runtimeType}) in MenuItemMaterial JSON: $json");
    }

    return MenuItemMaterial(
      id: getRequiredString('id', json),
      createdAt: createdAtDate,
      menuItemId: getRequiredString('menu_item_id', json),
      materialId: actualMaterialId, // actualMaterialId is validated above
      quantityUsed: (quantityNum).toDouble(),
      unitOfMeasureUsed: getRequiredString('unit_of_measure_for_usage', json),
      notes: json['notes'] as String?, // notes is nullable, so direct cast is fine
      materialName: fetchedMaterialName, // fetchedMaterialName is nullable
      materialItemImageUrl: fetchedMaterialItemImageUrl, // Add image URL
    );
  }

  Map<String, dynamic> toJson() { // For creating or updating
    return {
      'menu_item_id': menuItemId,
      'material_id': materialId,
      'quantity_used': quantityUsed,
      'unit_of_measure_used': unitOfMeasureUsed,
      'notes': notes,
      // materialName is not part of the direct table schema for menu_item_materials,
      // it would be joined or handled separately.
    };
  }
}
