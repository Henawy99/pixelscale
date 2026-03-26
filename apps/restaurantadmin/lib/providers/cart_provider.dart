import 'package:flutter/foundation.dart';
import 'package:restaurantadmin/models/cart_item.dart';
// Still needed for MenuItem type
import 'package:restaurantadmin/models/menu_item_with_recipe.dart'; // Added

class CartProvider with ChangeNotifier {
  final Map<String, CartItem> _items = {}; // Use MenuItem id as key
  String? _activeBrandId;
  String? _activeBrandName;

  Map<String, CartItem> get items => {..._items};
  String? get activeBrandId => _activeBrandId;
  String? get activeBrandName => _activeBrandName;

  int get itemCount {
    // If an active brand is set, only count items for that brand.
    // This logic might need adjustment based on how itemCount is used globally vs. per-brand.
    // For now, let's assume itemCount is global for the badge on OrderableBrandMenuScreen,
    // but the visibility of the badge will be controlled by activeBrandId matching.
    // Or, more simply, itemCount can remain the total number of items in the cart,
    // and the UI decides what to show based on context.
    // Let's keep it simple: itemCount is total items in cart.
    return _items.values.fold(0, (sum, item) => sum + item.quantity);
  }

  // Helper to get item count for a specific brand, useful for the badge
  int itemsInCartForBrand(String brandId) {
    if (_activeBrandId != brandId)
      return 0; // If cart is for another brand, count is 0 for this one
    return _items.values.fold(0, (sum, item) => sum + item.quantity);
  }

  double get totalPrice {
    double total = 0.0;
    _items.forEach((key, cartItem) {
      total += cartItem.subtotal;
    });
    return total;
  }

  // Returns true if item was added/updated, false if brand mismatch
  bool addToCart(
    MenuItemWithRecipe menuItemWithRecipe,
    String brandId,
    String brandName, {
    int quantity = 1,
  }) {
    final menuItem = menuItemWithRecipe
        .menuItem; // Extract base MenuItem for ID and other direct props

    if (_activeBrandId == null || _activeBrandId == '') {
      // Cart is empty, start a new cart for this brand
      _activeBrandId = brandId;
      _activeBrandName = brandName;
      print(
        '[CartProvider] New cart started for brand: $_activeBrandName (ID: $_activeBrandId)',
      );
    } else if (_activeBrandId != brandId) {
      // Cart has items from a different brand
      print(
        '[CartProvider] Attempted to add item from $brandName (ID: $brandId) to cart with items from $_activeBrandName (ID: $_activeBrandId). Action denied.',
      );
      return false; // Indicate failure due to brand mismatch
    }

    // If we reach here, either the cart was empty or the brand matches
    if (_items.containsKey(menuItem.id)) {
      // if item already in cart, update quantity
      _items.update(
        menuItem.id,
        (existingCartItem) => CartItem(
          menuItemWithRecipe:
              existingCartItem.menuItemWithRecipe, // Keep existing full object
          quantity: existingCartItem.quantity + quantity,
        ),
      );
    } else {
      // if item not in cart, add new
      _items.putIfAbsent(
        menuItem.id,
        () => CartItem(
          menuItemWithRecipe:
              menuItemWithRecipe, // Store the full MenuItemWithRecipe
          quantity: quantity,
        ),
      );
    }
    notifyListeners();
    return true; // Indicate success
  }

  void updateItemQuantity(String menuItemId, int newQuantity) {
    if (!_items.containsKey(menuItemId)) {
      return;
    }
    if (newQuantity > 0) {
      _items.update(
        menuItemId,
        (existingCartItem) => CartItem(
          menuItemWithRecipe: existingCartItem.menuItemWithRecipe,
          quantity: newQuantity,
        ),
      );
    } else {
      // If new quantity is 0 or less, remove the item
      _items.remove(menuItemId);
    }
    notifyListeners();
  }

  void incrementItemQuantity(String menuItemId) {
    if (_items.containsKey(menuItemId)) {
      _items.update(
        menuItemId,
        (existingCartItem) => CartItem(
          menuItemWithRecipe: existingCartItem.menuItemWithRecipe,
          quantity: existingCartItem.quantity + 1,
        ),
      );
      notifyListeners();
    }
  }

  void decrementItemQuantity(String menuItemId) {
    if (!_items.containsKey(menuItemId)) {
      return;
    }
    if (_items[menuItemId]!.quantity > 1) {
      _items.update(
        menuItemId,
        (existingCartItem) => CartItem(
          menuItemWithRecipe: existingCartItem.menuItemWithRecipe,
          quantity: existingCartItem.quantity - 1,
        ),
      );
    } else {
      // If quantity is 1, decrementing removes it
      _items.remove(menuItemId);
    }
    notifyListeners();
  }

  void removeFromCart(String menuItemId) {
    _items.remove(menuItemId);
    if (_items.isEmpty) {
      // If cart becomes empty after removal, clear brand info
      _activeBrandId = null;
      _activeBrandName = null;
      print('[CartProvider] Cart is now empty. Brand context cleared.');
    }
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    _activeBrandId = null;
    _activeBrandName = null;
    print('[CartProvider] Cart cleared. Brand context reset.');
    notifyListeners();
  }
}
