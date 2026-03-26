import 'package:restaurantadmin/models/menu_item_with_recipe.dart'; // Changed import

class CartItem {
  final MenuItemWithRecipe menuItemWithRecipe; // Changed type
  int quantity;

  CartItem({
    required this.menuItemWithRecipe, // Changed parameter name and type
    this.quantity = 1,
  });

  double get subtotal => menuItemWithRecipe.menuItem.price * quantity; // Adjusted access

  // Optional: methods to increment/decrement quantity if needed directly on the model
  void incrementQuantity() {
    quantity++;
  }

  void decrementQuantity() {
    if (quantity > 1) {
      quantity--;
    }
    // Consider logic for quantity reaching 0 - typically handled by a remove action in the provider
  }
}
