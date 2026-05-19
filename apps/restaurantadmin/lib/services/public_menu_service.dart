import 'package:restaurantadmin/config/online_brands.dart';
import 'package:restaurantadmin/models/brand_full_menu_data.dart';
import 'package:restaurantadmin/models/menu_category.dart';
import 'package:restaurantadmin/models/menu_item_model.dart';
import 'package:restaurantadmin/models/menu_item_with_recipe.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PublicMenuService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<BrandFullMenuData> fetchMenu(OnlineBrandConfig brand) async {
    final response = await _supabase.functions.invoke(
      'get-public-menu',
      body: {'slug': brand.slug},
    );

    if (response.status < 200 || response.status >= 300) {
      throw Exception(
        'Menu konnte nicht geladen werden (${response.status})',
      );
    }

    final data = response.data as Map<String, dynamic>;
    if (data['error'] != null) {
      throw Exception(data['error'].toString());
    }

    final categoriesPayload = (data['categories'] as List?) ?? [];
    final List<MenuCategoryWithItems> categoriesWithItems = [];

    for (final entry in categoriesPayload) {
      final catJson = entry['category'] as Map<String, dynamic>;
      final category = MenuCategory.fromJson(catJson);
      final itemsJson = (entry['items'] as List?) ?? [];
      final items = itemsJson
          .map((raw) => MenuItem.fromJson(raw as Map<String, dynamic>))
          .where((item) => item.isAvailable)
          .map(
            (item) => MenuItemWithRecipe(menuItem: item, recipe: const []),
          )
          .toList();

      if (items.isNotEmpty) {
        categoriesWithItems.add(
          MenuCategoryWithItems(category: category, itemsWithRecipe: items),
        );
      }
    }

    return BrandFullMenuData(
      brandId: brand.id,
      brandName: brand.name,
      categoriesWithItems: categoriesWithItems,
      lastFetched: DateTime.now(),
    );
  }
}
