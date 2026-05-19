import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:restaurantadmin/config/delivery_zones.dart';
import 'package:restaurantadmin/config/online_brands.dart';
import 'package:restaurantadmin/models/brand_full_menu_data.dart';
import 'package:restaurantadmin/models/menu_item_with_recipe.dart';
import 'package:restaurantadmin/providers/cart_provider.dart';
import 'package:restaurantadmin/services/public_menu_service.dart';
import 'package:restaurantadmin/widgets/public/public_checkout_panel.dart';

/// Customer-facing online ordering for one ghost kitchen brand.
class PublicBrandOrderScreen extends StatefulWidget {
  final OnlineBrandConfig brand;

  const PublicBrandOrderScreen({super.key, required this.brand});

  @override
  State<PublicBrandOrderScreen> createState() => _PublicBrandOrderScreenState();
}

class _PublicBrandOrderScreenState extends State<PublicBrandOrderScreen>
    with SingleTickerProviderStateMixin {
  final _menuService = PublicMenuService();
  BrandFullMenuData? _menu;
  bool _loading = true;
  String? _error;
  TabController? _tabController;
  int _mobileTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadMenu();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _loadMenu() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final menu = await _menuService.fetchMenu(widget.brand);
      _tabController?.dispose();
      _tabController = menu.categoriesWithItems.isNotEmpty
          ? TabController(
              length: menu.categoriesWithItems.length,
              vsync: this,
            )
          : null;
      if (mounted) {
        setState(() {
          _menu = menu;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _addToCart(MenuItemWithRecipe item, {int qty = 1}) {
    final cart = context.read<CartProvider>();
    for (var i = 0; i < qty; i++) {
      final ok = cart.addToCart(item, widget.brand.id, widget.brand.name);
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Warenkorb enthält Artikel einer anderen Marke.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text('${item.menuItem.name} hinzugefügt')),
          ],
        ),
        duration: const Duration(milliseconds: 1200),
        behavior: SnackBarBehavior.floating,
        backgroundColor: widget.brand.primaryColor,
      ),
    );
  }

  int _qtyInCart(CartProvider cart, String menuItemId) {
    return cart.items[menuItemId]?.quantity ?? 0;
  }

  Widget? _buildMobileCartFab(BuildContext context) {
    if (MediaQuery.sizeOf(context).width >= 900) return null;
    return Consumer<CartProvider>(
      builder: (_, cart, __) {
        if (cart.itemCount == 0 || _mobileTabIndex == 1) {
          return const SizedBox.shrink();
        }
        return FloatingActionButton.extended(
          onPressed: () => setState(() => _mobileTabIndex = 1),
          backgroundColor: widget.brand.primaryColor,
          icon: const Icon(Icons.shopping_cart),
          label: Text(
            'Warenkorb (${cart.itemCount}) · ${formatEuro(cart.totalPrice)}',
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: widget.brand.primaryColor,
          primary: widget.brand.primaryColor,
        ),
        useMaterial3: true,
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.grey.shade200),
          ),
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
          ],
        ),
        floatingActionButton: _buildMobileCartFab(context),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadMenu,
                child: const Text('Erneut laden'),
              ),
            ],
          ),
        ),
      );
    }
    if (_menu == null || _menu!.categoriesWithItems.isEmpty) {
      return const Center(child: Text('Keine Menüpunkte verfügbar.'));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final menuPanel = _buildMenuPanel();
        final checkout = PublicCheckoutPanel(brand: widget.brand);

        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: menuPanel),
              Container(width: 1, color: Colors.grey.shade300),
              Expanded(flex: 2, child: checkout),
            ],
          );
        }

        return Column(
          children: [
            Container(
              color: Colors.white,
              child: Row(
                children: [
                  _mobileTabChip(0, Icons.restaurant_menu, 'Speisekarte'),
                  _mobileTabChip(1, Icons.shopping_cart_outlined, 'Warenkorb'),
                ],
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _mobileTabIndex,
                children: [menuPanel, checkout],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _mobileTabChip(int index, IconData icon, String label) {
    final selected = _mobileTabIndex == index;
    return Expanded(
      child: Material(
        color: selected
            ? widget.brand.primaryColor.withValues(alpha: 0.1)
            : Colors.white,
        child: InkWell(
          onTap: () => setState(() => _mobileTabIndex = index),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected ? widget.brand.primaryColor : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    color: selected ? widget.brand.primaryColor : Colors.grey[700],
                  ),
                ),
                if (index == 1)
                  Consumer<CartProvider>(
                    builder: (_, cart, __) {
                      if (cart.itemCount == 0) return const SizedBox.shrink();
                      return Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: widget.brand.primaryColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${cart.itemCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            widget.brand.primaryColor,
            widget.brand.accentColor,
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.asset(
                      widget.brand.logoAssetPath,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.restaurant,
                        size: 48,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.brand.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.brand.tagline,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.92),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _headerChip(Icons.store, 'Abholung: $kKitchenAddress'),
                  _headerChip(Icons.delivery_dining, 'Lieferung Salzburg & Umgebung'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuPanel() {
    final categories = _menu!.categoriesWithItems;
    return Column(
      children: [
        if (_tabController != null)
          Material(
            color: Colors.white,
            elevation: 1,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: widget.brand.primaryColor,
              unselectedLabelColor: Colors.grey,
              indicatorColor: widget.brand.primaryColor,
              tabAlignment: TabAlignment.start,
              tabs: categories.map((c) => Tab(text: c.category.name)).toList(),
            ),
          ),
        Expanded(
          child: _tabController != null
              ? TabBarView(
                  controller: _tabController,
                  children: categories.map(_categoryList).toList(),
                )
              : _categoryList(categories.first),
        ),
      ],
    );
  }

  Widget _categoryList(MenuCategoryWithItems categoryWithItems) {
    final items = categoryWithItems.itemsWithRecipe;
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      itemBuilder: (context, index) => _menuItemCard(items[index]),
    );
  }

  Widget _menuItemCard(MenuItemWithRecipe item) {
    final menuItem = item.menuItem;
    return Consumer<CartProvider>(
      builder: (context, cart, _) {
        final qty = _qtyInCart(cart, menuItem.id);
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (menuItem.imageUrl != null && menuItem.imageUrl!.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CachedNetworkImage(
                      imageUrl: menuItem.imageUrl!,
                      width: 88,
                      height: 88,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        width: 88,
                        height: 88,
                        color: Colors.grey.shade200,
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (_, __, ___) => _placeholderImage(),
                    ),
                  )
                else
                  _placeholderImage(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        menuItem.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      if (menuItem.description != null &&
                          menuItem.description!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            menuItem.description!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                              height: 1.3,
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        formatEuro(menuItem.price),
                        style: TextStyle(
                          color: widget.brand.primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (qty == 0)
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _addToCart(item),
                            icon: const Icon(Icons.add, size: 20),
                            label: const Text('Hinzufügen'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: widget.brand.primaryColor,
                              side: BorderSide(color: widget.brand.primaryColor),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        )
                      else
                        Row(
                          children: [
                            IconButton.filledTonal(
                              onPressed: () {
                                if (qty > 1) {
                                  cart.updateItemQuantity(menuItem.id, qty - 1);
                                } else {
                                  cart.removeFromCart(menuItem.id);
                                }
                              },
                              icon: const Icon(Icons.remove),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                '$qty',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            IconButton.filled(
                              style: IconButton.styleFrom(
                                backgroundColor: widget.brand.primaryColor,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () =>
                                  cart.updateItemQuantity(menuItem.id, qty + 1),
                              icon: const Icon(Icons.add),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _placeholderImage() {
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(Icons.fastfood, color: Colors.grey[400], size: 36),
    );
  }
}
