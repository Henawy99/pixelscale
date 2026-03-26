import 'package:restaurantadmin/models/menu_item_model.dart';
import 'package:restaurantadmin/models/resolved_menu_item_material.dart';

class MenuItemWithRecipe {
  final MenuItem menuItem;
  final List<ResolvedMenuItemMaterial> recipe;
  final double totalMaterialCostForOneUnit;

  MenuItemWithRecipe({
    required this.menuItem,
    required this.recipe,
  }) : totalMaterialCostForOneUnit = recipe.fold(0.0, (sum, material) => sum + material.totalCostForRecipe);

  // If you plan to serialize this (e.g., for Hive caching directly),
  // you might need a fromJson / toJson that handles nested objects.
  // For now, focusing on in-memory representation.
}
