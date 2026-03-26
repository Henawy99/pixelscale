import 'package:hive/hive.dart';

part 'worker_cache_models.g.dart';

// Cached brand model for worker app
@HiveType(typeId: 20)
class CachedBrand extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String? imageUrl;

  @HiveField(3)
  final DateTime lastUpdated;

  CachedBrand({
    required this.id,
    required this.name,
    this.imageUrl,
    required this.lastUpdated,
  });

  factory CachedBrand.fromJson(Map<String, dynamic> json) {
    return CachedBrand(
      id: json['id'] as String,
      name: json['name'] as String,
      imageUrl: json['image_url'] as String?,
      lastUpdated: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'image_url': imageUrl,
    };
  }
}

// Cached category model for worker app
@HiveType(typeId: 21)
class CachedCategory extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String brandId;

  @HiveField(3)
  final int displayOrder;

  @HiveField(4)
  final DateTime lastUpdated;

  CachedCategory({
    required this.id,
    required this.name,
    required this.brandId,
    required this.displayOrder,
    required this.lastUpdated,
  });

  factory CachedCategory.fromJson(Map<String, dynamic> json) {
    return CachedCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      brandId: json['brand_id'] as String,
      displayOrder: json['display_order'] as int? ?? 0,
      lastUpdated: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'brand_id': brandId,
      'display_order': displayOrder,
    };
  }
}

// Cached menu item model for worker app
@HiveType(typeId: 22)
class CachedMenuItem extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String categoryId;

  @HiveField(3)
  final double price;

  @HiveField(4)
  final String? imageUrl;

  @HiveField(5)
  final int displayOrder;

  @HiveField(6)
  final DateTime lastUpdated;

  CachedMenuItem({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.price,
    this.imageUrl,
    required this.displayOrder,
    required this.lastUpdated,
  });

  factory CachedMenuItem.fromJson(Map<String, dynamic> json) {
    return CachedMenuItem(
      id: json['id'] as String,
      name: json['name'] as String,
      categoryId: json['category_id'] as String,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      imageUrl: json['image_url'] as String?,
      displayOrder: json['display_order'] as int? ?? 0,
      lastUpdated: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category_id': categoryId,
      'price': price,
      'image_url': imageUrl,
      'display_order': displayOrder,
    };
  }
}

// Cached material model for worker app
@HiveType(typeId: 23)
class CachedMaterial extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String? arabicName;

  @HiveField(3)
  final String unitOfMeasure;

  @HiveField(4)
  final String? imageUrl;

  @HiveField(5)
  final DateTime lastUpdated;

  CachedMaterial({
    required this.id,
    required this.name,
    this.arabicName,
    required this.unitOfMeasure,
    this.imageUrl,
    required this.lastUpdated,
  });

  factory CachedMaterial.fromJson(Map<String, dynamic> json) {
    return CachedMaterial(
      id: json['id'] as String,
      name: json['name'] as String,
      arabicName: json['arabic_name'] as String?,
      unitOfMeasure: json['unit_of_measure'] as String? ?? '',
      imageUrl: json['item_image_url'] as String?,
      lastUpdated: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'arabic_name': arabicName,
      'unit_of_measure': unitOfMeasure,
      'item_image_url': imageUrl,
    };
  }
}

// Cached menu item material model for worker app
@HiveType(typeId: 24)
class CachedMenuItemMaterial extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String menuItemId;

  @HiveField(2)
  final String materialId;

  @HiveField(3)
  final double quantityUsed;

  @HiveField(4)
  final String unitOfMeasureForUsage;

  @HiveField(5)
  final String? notes;

  @HiveField(6)
  final DateTime lastUpdated;

  CachedMenuItemMaterial({
    required this.id,
    required this.menuItemId,
    required this.materialId,
    required this.quantityUsed,
    required this.unitOfMeasureForUsage,
    this.notes,
    required this.lastUpdated,
  });

  factory CachedMenuItemMaterial.fromJson(Map<String, dynamic> json) {
    return CachedMenuItemMaterial(
      id: json['id'] as String,
      menuItemId: json['menu_item_id'] as String,
      materialId: json['material_id'] as String,
      quantityUsed: (json['quantity_used'] as num?)?.toDouble() ?? 0.0,
      unitOfMeasureForUsage: json['unit_of_measure_for_usage'] as String? ?? '',
      notes: json['notes'] as String?,
      lastUpdated: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'menu_item_id': menuItemId,
      'material_id': materialId,
      'quantity_used': quantityUsed,
      'unit_of_measure_for_usage': unitOfMeasureForUsage,
      'notes': notes,
    };
  }
}

// Cache metadata model
@HiveType(typeId: 25)
class WorkerCacheMetadata extends HiveObject {
  @HiveField(0)
  final String cacheType;

  @HiveField(1)
  final DateTime lastUpdated;

  @HiveField(2)
  final String? brandId;

  @HiveField(3)
  final int version;

  WorkerCacheMetadata({
    required this.cacheType,
    required this.lastUpdated,
    this.brandId,
    this.version = 1,
  });
}
