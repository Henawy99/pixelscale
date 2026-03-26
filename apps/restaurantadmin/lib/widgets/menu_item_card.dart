import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:restaurantadmin/models/menu_item_model.dart';
import 'package:restaurantadmin/models/menu_item_with_recipe.dart'; // Added
import 'package:restaurantadmin/providers/cart_provider.dart';

class MenuItemCard extends StatelessWidget {
  // final MenuItem menuItem; // Replaced
  final MenuItemWithRecipe menuItemWithRecipe; // New property
  final String brandId; 
  final String brandName; 

  const MenuItemCard({
    super.key,
    // required this.menuItem, // Replaced
    required this.menuItemWithRecipe, // New property
    required this.brandId,
    required this.brandName,
  });

  @override
  Widget build(BuildContext context) {
    final MenuItem menuItem = menuItemWithRecipe.menuItem; // Extract for convenience
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    return Card(
      elevation: 3.0,
      margin: const EdgeInsets.all(8.0),
      clipBehavior: Clip.antiAlias, // Ensures the image respects card borders
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      child: InkWell(
        onTap: () {
          final bool addedSuccessfully = cartProvider.addToCart(
            menuItemWithRecipe, // Pass MenuItemWithRecipe
            brandId,
            brandName,
          );
          // Snackbar logic can be re-added here if desired, or handled globally
          // For example, showing a success message or an error if adding failed.
          // For now, keeping it minimal as per previous removal of snackbar.
          if (addedSuccessfully) {
            // Optionally, provide some feedback, e.g., a subtle animation or a temporary overlay
            print('${menuItem.name} added to cart for $brandName.');
          } else {
            print('Failed to add ${menuItem.name}. Cart may have items from another brand.');
            // Consider showing a more user-visible error if this is a common scenario
            // For example, using ScaffoldMessenger if context is readily available or passed.
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
          // Image section
          Expanded(
            flex: 3, 
            child: menuItem.imageUrl != null && menuItem.imageUrl!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: menuItem.imageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const Center(
                        child: SizedBox(
                            width: 30,
                            height: 30,
                            child: CircularProgressIndicator(strokeWidth: 2.0))),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.broken_image_outlined,
                          size: 40, color: Colors.grey),
                    ),
                  )
                : Container(
                    color: Colors.grey[200],
                    child: const Icon(Icons.restaurant_menu_outlined,
                        size: 50, color: Colors.grey),
                  ),
          ),
          Expanded(
            flex: 4, 
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                children: <Widget>[
                  Text(
                    menuItem.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (menuItem.description != null &&
                      menuItem.description!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        menuItem.description!,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  // Display total material cost for one unit
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      'Cost: ${menuItemWithRecipe.totalMaterialCostForOneUnit.toStringAsFixed(2)} €',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.blueGrey[700]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Spacer(), 
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        '${menuItem.price.toStringAsFixed(2)} €',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      // The ElevatedButton for "Add" is removed as the whole card is now tappable.
                      // If you still want a visual cue, consider adding an Icon here,
                      // but without an onPressed action as the InkWell handles it.
                      // Example: Icon(Icons.add_shopping_cart, size: 24, color: Theme.of(context).colorScheme.primary),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      ), // This closes the InkWell
    );
  }
}
