import 'package:restaurantadmin/models/brand_full_menu_data.dart';
import 'package:restaurantadmin/models/menu_category.dart';
import 'package:restaurantadmin/models/menu_item_model.dart';
// For parsing menu_item_materials rows
import 'package:restaurantadmin/models/resolved_menu_item_material.dart';
import 'package:restaurantadmin/models/menu_item_with_recipe.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MenuCacheService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final Map<String, BrandFullMenuData> _cachedMenus = {};
  final Duration _cacheDuration = const Duration(minutes: 30);

  Future<BrandFullMenuData> getFullMenuForBrand(
    String brandId,
    String brandName, {
    bool forceRefresh = false,
  }) async {
    final now = DateTime.now();
    if (!forceRefresh && _cachedMenus.containsKey(brandId)) {
      final cachedData = _cachedMenus[brandId]!;
      if (now.difference(cachedData.lastFetched) < _cacheDuration) {
        print('[MenuCacheService] Returning cached menu for brand: $brandName');
        return cachedData;
      }
    }

    print('[MenuCacheService] Fetching fresh menu for brand: $brandName');

    try {
      // 1. Fetch all categories for the brand
      final categoriesResponse = await _supabase
          .from('menu_categories')
          .select()
          .eq('brand_id', brandId)
          .order('display_order', ascending: true);

      final List<MenuCategory> categories = (categoriesResponse as List)
          .map((data) => MenuCategory.fromJson(data as Map<String, dynamic>))
          .toList();

      // 2. Fetch all menu items for the brand
      // This could be optimized by fetching all menu items for the brand in one go
      // and then associating them with categories client-side.
      // Or, fetch all menu_item_materials and all materials in bulk.

      final List<MenuItem> allMenuItemsForBrand = [];
      final menuItemsResponse = await _supabase
          .from('menu_items')
          .select()
          .filter(
            'category_id',
            'in',
            categories.map((c) => c.id).toList(),
          ); // Corrected "in" filter

      allMenuItemsForBrand.addAll(
        (menuItemsResponse as List).map(
          (data) => MenuItem.fromJson(data as Map<String, dynamic>),
        ),
      );

      // 3. Fetch all menu_item_materials for these menu items
      // We need material details (esp. average_unit_cost) for ResolvedMenuItemMaterial
      final menuItemIds = allMenuItemsForBrand.map((mi) => mi.id).toList();
      List<Map<String, dynamic>> allMenuItemMaterialsData = [];
      if (menuItemIds.isNotEmpty) {
        final mimResponse = await _supabase
            .from('menu_item_materials')
            .select(
              '*, material_id(*)',
            ) // Join with material table to get all material fields
            .filter('menu_item_id', 'in', menuItemIds); // Corrected "in" filter
        allMenuItemMaterialsData = (mimResponse as List)
            .cast<Map<String, dynamic>>();
      }

      // 4. Construct MenuItemWithRecipe for all menu items
      Map<String, List<ResolvedMenuItemMaterial>> recipesMap = {};
      for (var mimData in allMenuItemMaterialsData) {
        final menuItemId = mimData['menu_item_id'] as String;
        recipesMap.putIfAbsent(menuItemId, () => []);
        // ResolvedMenuItemMaterial.fromJoinedData expects 'material_id' to be a map
        if (mimData['material_id'] != null &&
            mimData['material_id'] is Map<String, dynamic>) {
          recipesMap[menuItemId]!.add(
            ResolvedMenuItemMaterial.fromJoinedData(mimData),
          );
        } else {
          // This case should ideally not happen if the join material_id(*) works as expected
          // Or if material_id is just a UUID and we need another fetch for material details
          print(
            "[MenuCacheService] Warning: Material details not fully joined for menu_item_material: ${mimData['id']}. Cost might be 0.",
          );
          // Create a ResolvedMenuItemMaterial with potentially missing cost info if join failed
          recipesMap[menuItemId]!.add(
            ResolvedMenuItemMaterial(
              materialId:
                  mimData['material_id'] as String, // This would be just the ID
              materialName: 'Unknown (fetch separately)', // Placeholder
              quantityUsed: (mimData['quantity_used'] as num).toDouble(),
              unitOfMeasureUsed: mimData['unit_of_measure_for_usage'] as String,
              averageUnitCost: 0.0, // Default if not found
            ),
          );
        }
      }

      List<MenuItemWithRecipe> allMenuItemsWithRecipe = [];
      for (var menuItem in allMenuItemsForBrand) {
        allMenuItemsWithRecipe.add(
          MenuItemWithRecipe(
            menuItem: menuItem,
            recipe: recipesMap[menuItem.id] ?? [],
          ),
        );
      }

      // 5. Structure into BrandFullMenuData
      List<MenuCategoryWithItems> categoriesWithItemsList = [];
      for (var category in categories) {
        categoriesWithItemsList.add(
          MenuCategoryWithItems(
            category: category,
            itemsWithRecipe: allMenuItemsWithRecipe
                .where(
                  (itemWithRecipe) =>
                      itemWithRecipe.menuItem.categoryId == category.id,
                )
                .toList(),
          ),
        );
      }

      final brandMenuData = BrandFullMenuData(
        brandId: brandId,
        brandName: brandName,
        categoriesWithItems: categoriesWithItemsList,
        lastFetched: now,
      );

      _cachedMenus[brandId] = brandMenuData;
      print(
        '[MenuCacheService] Successfully fetched and cached menu for brand: $brandName',
      );
      return brandMenuData;
    } catch (e, stacktrace) {
      print('[MenuCacheService] Error fetching full menu for $brandName: $e');
      print(stacktrace);
      throw Exception('Failed to load full menu for $brandName: $e');
    }
  }

  void clearCacheForBrand(String brandId) {
    _cachedMenus.remove(brandId);
    print('[MenuCacheService] Cleared cache for brand ID: $brandId');
  }

  void clearAllCaches() {
    _cachedMenus.clear();
    print('[MenuCacheService] Cleared all menu caches.');
  }
}
