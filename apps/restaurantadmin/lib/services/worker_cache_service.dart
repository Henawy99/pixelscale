import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:restaurantadmin/models/worker_cache_models.dart';

class WorkerCacheService {
  static const String _brandsBoxName = 'worker_brands_cache';
  static const String _categoriesBoxName = 'worker_categories_cache';
  static const String _menuItemsBoxName = 'worker_menu_items_cache';
  static const String _materialsBoxName = 'worker_materials_cache';
  static const String _menuItemMaterialsBoxName = 'worker_menu_item_materials_cache';
  static const String _metadataBoxName = 'worker_cache_metadata';
  
  static const Duration _cacheValidityDuration = Duration(hours: 24);
  
  late Box<CachedBrand> _brandsBox;
  late Box<CachedCategory> _categoriesBox;
  late Box<CachedMenuItem> _menuItemsBox;
  late Box<CachedMaterial> _materialsBox;
  late Box<CachedMenuItemMaterial> _menuItemMaterialsBox;
  late Box<WorkerCacheMetadata> _metadataBox;
  
  final SupabaseClient _supabase = Supabase.instance.client;
  
  static WorkerCacheService? _instance;
  static WorkerCacheService get instance {
    _instance ??= WorkerCacheService._();
    return _instance!;
  }
  
  WorkerCacheService._();
  
  Future<void> initialize() async {
    print('Initializing WorkerCacheService...');
    _brandsBox = await Hive.openBox<CachedBrand>(_brandsBoxName);
    _categoriesBox = await Hive.openBox<CachedCategory>(_categoriesBoxName);
    _menuItemsBox = await Hive.openBox<CachedMenuItem>(_menuItemsBoxName);
    _materialsBox = await Hive.openBox<CachedMaterial>(_materialsBoxName);
    _menuItemMaterialsBox = await Hive.openBox<CachedMenuItemMaterial>(_menuItemMaterialsBoxName);
    _metadataBox = await Hive.openBox<WorkerCacheMetadata>(_metadataBoxName);
    print('WorkerCacheService initialized successfully');
  }
  
  // Brands caching
  Future<List<CachedBrand>> getBrands({bool forceRefresh = false}) async {
    if (!forceRefresh && _isCacheValid('brands')) {
      return _brandsBox.values.toList();
    }
    
    try {
      final response = await _supabase
          .from('brands')
          .select('id,name,image_url,created_at')
          .order('name');
      
      final brands = (response as List)
          .map((data) => CachedBrand.fromJson(data as Map<String, dynamic>))
          .toList();
      
      await _brandsBox.clear();
      for (final brand in brands) {
        await _brandsBox.put(brand.id, brand);
      }
      
      await _updateCacheMetadata('brands');
      return brands;
    } catch (e) {
      print('Error fetching brands: $e');
      return _brandsBox.values.toList(); // Return cached data on error
    }
  }
  
  // Categories caching
  Future<List<CachedCategory>> getCategoriesForBrand(String brandId, {bool forceRefresh = false}) async {
    final cacheKey = 'categories_$brandId';
    
    if (!forceRefresh && _isCacheValid(cacheKey)) {
      return _categoriesBox.values
          .where((cat) => cat.brandId == brandId)
          .toList()
        ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    }
    
    try {
      final response = await _supabase
          .from('menu_categories')
          .select('id,name,display_order,brand_id')
          .eq('brand_id', brandId)
          .order('display_order');
      
      final categories = (response as List)
          .map((data) => CachedCategory.fromJson(data as Map<String, dynamic>))
          .toList();
      
      // Remove old categories for this brand
      final oldCategories = _categoriesBox.values
          .where((cat) => cat.brandId == brandId)
          .toList();
      for (final oldCat in oldCategories) {
        await _categoriesBox.delete(oldCat.id);
      }
      
      // Add new categories
      for (final category in categories) {
        await _categoriesBox.put(category.id, category);
      }
      
      await _updateCacheMetadata(cacheKey);
      return categories;
    } catch (e) {
      print('Error fetching categories: $e');
      return _categoriesBox.values
          .where((cat) => cat.brandId == brandId)
          .toList()
        ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    }
  }
  
  // Menu items caching
  Future<List<CachedMenuItem>> getMenuItemsForCategory(String categoryId, {bool forceRefresh = false}) async {
    final cacheKey = 'menu_items_$categoryId';
    
    if (!forceRefresh && _isCacheValid(cacheKey)) {
      return _menuItemsBox.values
          .where((item) => item.categoryId == categoryId)
          .toList()
        ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    }
    
    try {
      final response = await _supabase
          .from('menu_items')
          .select('id,name,price,image_url,display_order,category_id')
          .eq('category_id', categoryId)
          .order('display_order');
      
      final menuItems = (response as List)
          .map((data) => CachedMenuItem.fromJson(data as Map<String, dynamic>))
          .toList();
      
      // Remove old menu items for this category
      final oldItems = _menuItemsBox.values
          .where((item) => item.categoryId == categoryId)
          .toList();
      for (final oldItem in oldItems) {
        await _menuItemsBox.delete(oldItem.id);
      }
      
      // Add new menu items
      for (final menuItem in menuItems) {
        await _menuItemsBox.put(menuItem.id, menuItem);
      }
      
      await _updateCacheMetadata(cacheKey);
      return menuItems;
    } catch (e) {
      print('Error fetching menu items: $e');
      return _menuItemsBox.values
          .where((item) => item.categoryId == categoryId)
          .toList()
        ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    }
  }
  
  // Materials caching
  Future<List<CachedMaterial>> getMaterials({bool forceRefresh = false}) async {
    print('Getting materials, forceRefresh: $forceRefresh');
    if (!forceRefresh && _isCacheValid('materials')) {
      print('Loading materials from cache');
      return _materialsBox.values.toList();
    }
    
    try {
      print('Fetching materials from Supabase...');
      final response = await _supabase
          .from('material')
          .select('id,name,unit_of_measure,item_image_url');
      
      print('Supabase response: ${response.length} materials');
      final materials = (response as List)
          .map((data) => CachedMaterial.fromJson(data as Map<String, dynamic>))
          .toList();
      
      await _materialsBox.clear();
      for (final material in materials) {
        await _materialsBox.put(material.id, material);
      }
      
      await _updateCacheMetadata('materials');
      print('Materials cached successfully: ${materials.length} items');
      return materials;
    } catch (e) {
      print('Error fetching materials: $e');
      return _materialsBox.values.toList();
    }
  }
  
  // Menu item materials caching
  Future<List<CachedMenuItemMaterial>> getMaterialsForMenuItem(String menuItemId, {bool forceRefresh = false}) async {
    final cacheKey = 'menu_item_materials_$menuItemId';
    print('Getting materials for menu item: $menuItemId, forceRefresh: $forceRefresh');
    
    if (!forceRefresh && _isCacheValid(cacheKey)) {
      print('Loading menu item materials from cache');
      return _menuItemMaterialsBox.values
          .where((mat) => mat.menuItemId == menuItemId)
          .toList();
    }
    
    try {
      print('Fetching menu item materials from Supabase...');
      final response = await _supabase
          .from('menu_item_materials')
          .select('id,quantity_used,unit_of_measure_for_usage,notes,material_id,menu_item_id')
          .eq('menu_item_id', menuItemId)
          .order('created_at');
      
      print('Supabase response for menu item materials: ${response.length} items');
      final materials = (response as List)
          .map((data) => CachedMenuItemMaterial.fromJson(data as Map<String, dynamic>))
          .toList();
      
      // Remove old materials for this menu item
      final oldMaterials = _menuItemMaterialsBox.values
          .where((mat) => mat.menuItemId == menuItemId)
          .toList();
      for (final oldMat in oldMaterials) {
        await _menuItemMaterialsBox.delete(oldMat.id);
      }
      
      // Add new materials
      for (final material in materials) {
        await _menuItemMaterialsBox.put(material.id, material);
      }
      
      await _updateCacheMetadata(cacheKey);
      print('Menu item materials cached successfully: ${materials.length} items');
      return materials;
    } catch (e) {
      print('Error fetching menu item materials: $e');
      return _menuItemMaterialsBox.values
          .where((mat) => mat.menuItemId == menuItemId)
          .toList();
    }
  }
  
  // Update a material's Arabic name locally and try to persist to server (best-effort)
  Future<void> setMaterialArabicName(String materialId, String? arabicName) async {
    final existing = _materialsBox.get(materialId);
    if (existing != null) {
      final updated = CachedMaterial(
        id: existing.id,
        name: existing.name,
        arabicName: (arabicName?.trim().isEmpty ?? true) ? null : arabicName?.trim(),
        unitOfMeasure: existing.unitOfMeasure,
        imageUrl: existing.imageUrl,
        lastUpdated: DateTime.now(),
      );
      await _materialsBox.put(materialId, updated);
    }

    // Best-effort server update (column may not exist yet)
    try {
      await _supabase
          .from('material')
          .update({'arabic_name': arabicName})
          .eq('id', materialId);
    } catch (e) {
      // Silently ignore if column doesn't exist or network fails
      print('Skipping Supabase arabic_name update (non-fatal): $e');
    }
  }

  // Get material details by ID
  CachedMaterial? getMaterialById(String materialId) {
    return _materialsBox.get(materialId);
  }
  
  // Check if cache is valid
  bool _isCacheValid(String cacheType) {
    final metadata = _metadataBox.get(cacheType);
    if (metadata == null) return false;
    
    return DateTime.now().difference(metadata.lastUpdated) < _cacheValidityDuration;
  }
  
  // Update cache metadata
  Future<void> _updateCacheMetadata(String cacheType) async {
    final metadata = WorkerCacheMetadata(
      cacheType: cacheType,
      lastUpdated: DateTime.now(),
    );
    await _metadataBox.put(cacheType, metadata);
  }
  
  // Clear all cache
  Future<void> clearAllCache() async {
    await _brandsBox.clear();
    await _categoriesBox.clear();
    await _menuItemsBox.clear();
    await _materialsBox.clear();
    await _menuItemMaterialsBox.clear();
    await _metadataBox.clear();
  }
  
  // Clear cache for specific brand
  Future<void> clearBrandCache(String brandId) async {
    // Remove categories for this brand
    final categoriesToRemove = _categoriesBox.values
        .where((cat) => cat.brandId == brandId)
        .toList();
    for (final cat in categoriesToRemove) {
      await _categoriesBox.delete(cat.id);
      // Also remove menu items for this category
      final itemsToRemove = _menuItemsBox.values
          .where((item) => item.categoryId == cat.id)
          .toList();
      for (final item in itemsToRemove) {
        await _menuItemsBox.delete(item.id);
      }
    }
    
    // Remove metadata for this brand
    final metadataKeys = _metadataBox.keys
        .where((key) => key.toString().contains(brandId))
        .toList();
    for (final key in metadataKeys) {
      await _metadataBox.delete(key);
    }
  }
  
  // Get cache statistics
  Map<String, int> getCacheStats() {
    return {
      'brands': _brandsBox.length,
      'categories': _categoriesBox.length,
      'menu_items': _menuItemsBox.length,
      'materials': _materialsBox.length,
      'menu_item_materials': _menuItemMaterialsBox.length,
    };
  }
  
  // Close all boxes
  Future<void> dispose() async {
    await _brandsBox.close();
    await _categoriesBox.close();
    await _menuItemsBox.close();
    await _materialsBox.close();
    await _menuItemMaterialsBox.close();
    await _metadataBox.close();
  }
}
