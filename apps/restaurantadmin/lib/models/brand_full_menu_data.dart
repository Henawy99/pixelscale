import 'package:restaurantadmin/models/menu_category.dart';
import 'package:restaurantadmin/models/menu_item_with_recipe.dart';

class MenuCategoryWithItems {
  final MenuCategory category;
  final List<MenuItemWithRecipe> itemsWithRecipe;

  MenuCategoryWithItems({
    required this.category,
    required this.itemsWithRecipe,
  });
}

class BrandFullMenuData {
  final String brandId;
  final String brandName;
  final List<MenuCategoryWithItems> categoriesWithItems;
  final DateTime lastFetched;

  BrandFullMenuData({
    required this.brandId,
    required this.brandName,
    required this.categoriesWithItems,
    required this.lastFetched,
  });

  // If you plan to serialize this for Hive, you'll need fromJson/toJson
  // and potentially TypeAdapters for nested custom objects.
}
