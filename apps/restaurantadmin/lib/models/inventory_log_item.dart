import 'package:hive/hive.dart';

part 'inventory_log_item.g.dart'; // Will be generated

@HiveType(typeId: 1) // Unique typeId for Hive (MaterialItem was 0)
class InventoryLogItem extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final DateTime createdAt;

  @HiveField(2)
  final String materialId;

  @HiveField(3)
  final String materialName;

  @HiveField(4)
  final String changeType; // "ENTRY", "OUT", "CORRECTION", "INITIAL_STOCK"
  
  @HiveField(5)
  final double quantityChange;

  @HiveField(6)
  final double newQuantityAfterChange;

  @HiveField(7)
  final String? sourceDetails;

  @HiveField(8)
  final String? userId;

  @HiveField(9)
  final double? unitPricePaid; // Added
  
  @HiveField(10)
  final double? totalPricePaid; // Added

  InventoryLogItem({
    required this.id,
    required this.createdAt,
    required this.materialId,
    required this.materialName,
    required this.changeType,
    required this.quantityChange,
    required this.newQuantityAfterChange,
    this.sourceDetails,
    this.userId,
    this.unitPricePaid, // Added
    this.totalPricePaid, // Added
  });

  factory InventoryLogItem.fromJson(Map<String, dynamic> json) {
    return InventoryLogItem(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      materialId: json['material_id'] as String,
      materialName: json['material_name'] as String,
      changeType: json['change_type'] as String,
      quantityChange: (json['quantity_change'] as num).toDouble(),
      newQuantityAfterChange: (json['new_quantity_after_change'] as num).toDouble(),
      sourceDetails: json['source_details'] as String?,
      userId: json['user_id'] as String?,
      unitPricePaid: (json['unit_price_paid'] as num?)?.toDouble(), // Added
      totalPricePaid: (json['total_price_paid'] as num?)?.toDouble(), // Added
    );
  }

  // toJson might not be needed if logs are only created server-side or via specific app actions
  // but can be useful for consistency or local caching if implemented.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'created_at': createdAt.toIso8601String(),
      'material_id': materialId,
      'material_name': materialName,
      'change_type': changeType,
      'quantity_change': quantityChange,
      'new_quantity_after_change': newQuantityAfterChange,
      'source_details': sourceDetails,
      'user_id': userId,
      'unit_price_paid': unitPricePaid, // Added
      'total_price_paid': totalPricePaid, // Added
    };
  }
}
