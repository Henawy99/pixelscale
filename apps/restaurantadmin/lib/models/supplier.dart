import 'purchase_catalog_item.dart';

/// Supplier model (app-level) matching Supabase `public.suppliers`.
/// Minimal fields requested: name, ai_rules, address, and a purchase items list.
/// Extended: post code, street address, and whether it's an online supplier.
class Supplier {
  final String id; // uuid
  final DateTime createdAt;
  final DateTime? updatedAt;

  final String name;
  final String? address; // optional; only persisted if column exists
  final String? streetAddress; // maps to column public.suppliers.street_address (optional)
  final String? postCode; // maps to column public.suppliers.post_code (optional)
  final bool? isOnlineSupplier; // maps to column public.suppliers.is_online_supplier (optional)
  final String? aiRules; // maps to column public.suppliers.ai_rules
  final String? imageUrl; // maps to column public.suppliers.image_url (optional)

  /// Optional embedded list if fetched via RPC/join. Not persisted directly by toJson().
  final List<PurchaseCatalogItem> purchaseItems;

  Supplier({
    required this.id,
    required this.createdAt,
    this.updatedAt,
    required this.name,
    this.address,
    this.streetAddress,
    this.postCode,
    this.isOnlineSupplier,
    this.aiRules,
    this.imageUrl,
    this.purchaseItems = const [],
  });

  factory Supplier.fromJson(Map<String, dynamic> json) {
    // Allow both snake_case (from Supabase) and camelCase (local)
    final itemsJson = (json['purchase_items'] ?? json['purchaseItems']) as List<dynamic>?;
    return Supplier(
      id: (json['id'] ?? '') as String,
      createdAt: DateTime.tryParse((json['created_at'] ?? json['createdAt'] ?? '') as String) ?? DateTime.now(),
      updatedAt: DateTime.tryParse((json['updated_at'] ?? json['updatedAt']) as String? ?? ''),
      name: (json['name'] ?? '') as String,
      address: (json['address'] ?? json['adress']) as String?,
      streetAddress: (json['street_address'] ?? json['streetAddress'] ?? json['street_adress']) as String?,
      postCode: (json['post_code'] ?? json['postCode'] ?? json['postcode']) as String?,
      isOnlineSupplier: (json['is_online_supplier'] ?? json['isOnlineSupplier']) as bool?,
      aiRules: (json['ai_rules'] ?? json['aiRules']) as String?,
      imageUrl: (json['image_url'] ?? json['imageUrl']) as String?,
      purchaseItems: itemsJson == null
          ? const []
          : itemsJson
              .map((e) => PurchaseCatalogItem.fromJson(e as Map<String, dynamic>))
              .toList(),
    );
  }

  /// JSON for inserting/updating a supplier row (does not include nested items)
  Map<String, dynamic> toJson({bool includeAddress = false}) {
    return {
      'name': name,
      if (aiRules != null) 'ai_rules': aiRules,
      // Optional fields depending on DB availability
      if (includeAddress && address != null) 'address': address,
      if (streetAddress != null) 'street_address': streetAddress,
      if (postCode != null) 'post_code': postCode,
      if (isOnlineSupplier != null) 'is_online_supplier': isOnlineSupplier,
      if (imageUrl != null) 'image_url': imageUrl,
    };
  }

  Supplier copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? name,
    String? address,
    String? streetAddress,
    String? postCode,
    bool? isOnlineSupplier,
    String? aiRules,
    String? imageUrl,
    List<PurchaseCatalogItem>? purchaseItems,
  }) {
    return Supplier(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      name: name ?? this.name,
      address: address ?? this.address,
      streetAddress: streetAddress ?? this.streetAddress,
      postCode: postCode ?? this.postCode,
      isOnlineSupplier: isOnlineSupplier ?? this.isOnlineSupplier,
      aiRules: aiRules ?? this.aiRules,
      imageUrl: imageUrl ?? this.imageUrl,
      purchaseItems: purchaseItems ?? this.purchaseItems,
    );
  }

  @override
  String toString() =>
      'Supplier(id: $id, name: $name, address: ${address ?? ''}, street: ${streetAddress ?? ''}, postCode: ${postCode ?? ''}, online: ${isOnlineSupplier ?? false}, imageUrl: ${imageUrl ?? ''}, items: ${purchaseItems.length})';
}

