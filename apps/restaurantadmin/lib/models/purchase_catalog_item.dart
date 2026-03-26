/// Canonical Purchase Item defined per supplier, mapped to a MaterialItem.
/// Matches Supabase table `public.purchase_catalog_items`.
class PurchaseCatalogItem {
  final String id; // uuid
  final String supplierId;

  final String name; // canonical name
  final String? receiptName; // raw name seen on receipts (alias)
  final String? unit; // e.g., 'box', 'piece'
  final double? defaultQuantity; // default qty in receipt unit

  final String? itemNumber; // optional: supplier article number (may require DB column)

  final String? materialId; // linked MaterialItem id
  final String? baseUnit; // e.g., 'kg', 'piece'
  final double? conversionRatio; // base units per 1 receipt unit

  final String? notes;
  final DateTime? createdAt;

  final double? fixedQuantityBaseUnits; // supports fixed qty regardless of receipt parsing
  final bool? isFixedQuantity;

  PurchaseCatalogItem({
    required this.id,
    required this.supplierId,
    required this.name,
    this.receiptName,
    this.unit,
    this.defaultQuantity,
    this.itemNumber,
    this.materialId,
    this.baseUnit,
    this.conversionRatio,
    this.notes,
    this.createdAt,
    this.fixedQuantityBaseUnits,
    this.isFixedQuantity,
  });

  factory PurchaseCatalogItem.fromJson(Map<String, dynamic> json) {
    return PurchaseCatalogItem(
      id: (json['id'] ?? '') as String,
      supplierId: (json['supplier_id'] ?? json['supplierId'] ?? '') as String,
      name: (json['name'] ?? '') as String,
      receiptName: json['receipt_name'] as String?,
      unit: json['unit'] as String?,
      defaultQuantity: (json['default_quantity'] as num?)?.toDouble(),
      itemNumber: json['item_number'] as String?,
      materialId: json['material_id'] as String?,
      baseUnit: json['base_unit'] as String?,
      conversionRatio: (json['conversion_ratio'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      fixedQuantityBaseUnits: (json['fixed_quantity_base_units'] as num?)?.toDouble(),
      isFixedQuantity: json['is_fixed_quantity'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'supplier_id': supplierId,
      'name': name,
      if (receiptName != null) 'receipt_name': receiptName,
      if (unit != null) 'unit': unit,
      if (defaultQuantity != null) 'default_quantity': defaultQuantity,
      if (itemNumber != null) 'item_number': itemNumber,
      if (materialId != null) 'material_id': materialId,
      if (baseUnit != null) 'base_unit': baseUnit,
      if (conversionRatio != null) 'conversion_ratio': conversionRatio,
      if (notes != null) 'notes': notes,
      if (fixedQuantityBaseUnits != null) 'fixed_quantity_base_units': fixedQuantityBaseUnits,
      if (isFixedQuantity != null) 'is_fixed_quantity': isFixedQuantity,
    };
  }
}

