import 'dart:convert';
import 'package:hive/hive.dart';

part 'menu_item_model.g.dart';

@HiveType(typeId: 4)
class MenuItem {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final DateTime createdAt;
  @HiveField(2)
  final String? brandId; // Changed to nullable
  @HiveField(3)
  final String categoryId; // Foreign key to MenuCategory
  @HiveField(4)
  final String name;
  @HiveField(5)
  final String? description;
  @HiveField(6)
  final double price;
  @HiveField(7)
  final String? imageUrl;
  @HiveField(8)
  final Map<String, dynamic>? attributes; // For extra details like size, caffeine
  @HiveField(9)
  final int displayOrder;
  @HiveField(10)
  final bool isAvailable;

  MenuItem({
    required this.id,
    required this.createdAt,
    this.brandId, // Changed to nullable
    required this.categoryId,
    required this.name,
    this.description,
    required this.price,
    this.imageUrl,
    this.attributes,
    required this.displayOrder,
    required this.isAvailable,
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    final brandIdFromJson = json['brand_id'] as String?;
    // The warning is still useful to identify data issues, but we won't default to empty string anymore.
    if (brandIdFromJson == null) {
      print("MenuItem.fromJson WARNING: 'brand_id' is null or missing in JSON data for item ID: ${json['id']}. Assigning null. JSON: $json");
    }
    return MenuItem(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      brandId: brandIdFromJson, // Assign directly, can be null
      categoryId: json['category_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      price: (json['price'] as num).toDouble(),
      imageUrl: json['image_url'] as String?,
      attributes: json['attributes'] == null 
          ? null 
          : (json['attributes'] is String // Handle if attributes are stored as a JSON string
              ? jsonDecode(json['attributes'] as String) as Map<String, dynamic> 
              : json['attributes'] as Map<String, dynamic>),
      displayOrder: json['display_order'] as int? ?? 0, // Default to 0 if null
      isAvailable: json['is_available'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      // 'id' and 'created_at' are usually handled by the database for new entries
      'brand_id': brandId, // Can be null if the object's brandId is null
      'category_id': categoryId,
      'name': name,
      'description': description,
      'price': price,
      'image_url': imageUrl,
      'attributes': attributes == null ? null : jsonEncode(attributes), // Store as JSON string
      'display_order': displayOrder,
      'is_available': isAvailable,
    };
  }
}
