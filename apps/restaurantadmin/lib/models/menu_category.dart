import 'package:hive/hive.dart';

part 'menu_category.g.dart';

@HiveType(typeId: 3)
class MenuCategory {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String brandId;
  @HiveField(2)
  final String name;
  @HiveField(3)
  final String? description;
  @HiveField(4)
  final int displayOrder;
  @HiveField(5)
  final DateTime createdAt;

  MenuCategory({
    required this.id,
    required this.brandId,
    required this.name,
    this.description,
    required this.displayOrder,
    required this.createdAt,
  });

  factory MenuCategory.fromJson(Map<String, dynamic> json) {
    return MenuCategory(
      id: json['id'] as String,
      brandId: json['brand_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      displayOrder: json['display_order'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'brand_id': brandId,
      'name': name,
      'description': description,
      'display_order': displayOrder,
      // 'id' and 'created_at' are usually handled by the database.
    };
  }
}
