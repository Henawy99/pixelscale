import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:restaurantadmin/models/menu_category.dart';
import 'package:restaurantadmin/models/menu_item_with_recipe.dart';
import 'package:restaurantadmin/models/brand_full_menu_data.dart';
import 'package:restaurantadmin/providers/cart_provider.dart';
import 'package:restaurantadmin/screens/cart_screen.dart';
import 'package:restaurantadmin/services/menu_cache_service.dart';
import 'package:restaurantadmin/widgets/menu_item_card.dart';
import 'package:restaurantadmin/widgets/cart_view_widget.dart';
import 'package:restaurantadmin/screens/order_type_settings_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrderableBrandMenuScreen extends StatefulWidget {
  final String brandId;
  final String brandName;

  const OrderableBrandMenuScreen({
    super.key,
    required this.brandId,
    required this.brandName,
  });

  @override
  State<OrderableBrandMenuScreen> createState() =>
      _OrderableBrandMenuScreenState();
}

class _OrderableBrandMenuScreenState extends State<OrderableBrandMenuScreen>
    with TickerProviderStateMixin {
  BrandFullMenuData? _brandMenuData;
  List<OrderTypeConfig> _orderTypeConfigs = [];
  bool _isLoading = true;
  String? _error;

  // Animation controllers
  late AnimationController _headerAnimationController;
  late AnimationController _menuAnimationController;
  TabController? _tabController; // Made TabController nullable

  final MenuCacheService _menuCacheService = MenuCacheService();

  @override
  void initState() {
    super.initState();
    _headerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _menuAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _loadInitialData();
  }

  @override
  void dispose() {
    _headerAnimationController.dispose();
    _menuAnimationController.dispose();
    _tabController?.dispose(); // Use null-aware operator for safe disposal
    super.dispose();
  }

  Future<void> _loadInitialData({bool forceRefresh = false}) async {
    await _loadMenuData(forceRefresh: forceRefresh);
    if (_error == null) {
      await _fetchOrderTypeConfigs();
    }
    _headerAnimationController.forward();
    _menuAnimationController.forward();
  }

  Future<void> _fetchOrderTypeConfigs() async {
    if (!mounted) return;
    try {
      final response = await Supabase.instance.client
          .from('order_type_configs')
          .select()
          .eq('brand_id', widget.brandId)
          .eq('is_active', true)
          .order('display_order', ascending: true);
      if (mounted) {
        setState(() {
          _orderTypeConfigs = (response as List)
              .map(
                (data) =>
                    OrderTypeConfig.fromJson(data as Map<String, dynamic>),
              )
              .toList();
        });
      }
    } catch (e) {
      print('Error fetching order type configs: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not load order types: $e'),
            backgroundColor: Colors.red[600],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _loadMenuData({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      _brandMenuData = await _menuCacheService.getFullMenuForBrand(
        widget.brandId,
        widget.brandName,
        forceRefresh: forceRefresh,
      );
      if (mounted) {
        // Dispose previous controller if it exists
        _tabController?.dispose();
        _tabController = null; // Reset to null

        if (_brandMenuData != null &&
            _brandMenuData!.categoriesWithItems.isNotEmpty) {
          _tabController = TabController(
            length: _brandMenuData!.categoriesWithItems.length,
            vsync: this,
          );
        }
        // If no categories, _tabController remains null.
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching menu data: $e'),
            backgroundColor: Colors.red[600],
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() {
          _error = 'Error fetching menu data: $e';
          _isLoading = false;
          _brandMenuData = null;
        });
      }
      print(
        '[OrderableBrandMenuScreen] CRITICAL ERROR fetching menu data for Brand ID: ${widget.brandId}, Name: ${widget.brandName}: $e',
      );
      print('[OrderableBrandMenuScreen] StackTrace: $stackTrace');
    }
  }

  Widget _buildModernHeader() {
    return AnimatedBuilder(
      animation: _headerAnimationController,
      builder: (context, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
              .animate(
                CurvedAnimation(
                  parent: _headerAnimationController,
                  curve: Curves.easeOutBack,
                ),
              ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).primaryColor,
                  Theme.of(context).primaryColor.withOpacity(0.8),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.2),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.brandName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Create your order',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!kIsWeb)
                          Consumer<CartProvider>(
                            builder: (_, cart, ch) {
                              final itemsInBrandCart = cart.itemsInCartForBrand(
                                widget.brandId,
                              );
                              return Stack(
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.shopping_cart_outlined,
                                      color: Colors.white,
                                    ),
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.white.withOpacity(
                                        0.2,
                                      ),
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const CartScreen(),
                                        ),
                                      );
                                    },
                                  ),
                                  if (itemsInBrandCart > 0)
                                    Positioned(
                                      right: 6,
                                      top: 6,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.red[500],
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        constraints: const BoxConstraints(
                                          minWidth: 20,
                                          minHeight: 20,
                                        ),
                                        child: Text(
                                          itemsInBrandCart.toString(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        IconButton(
                          icon: const Icon(Icons.refresh, color: Colors.white),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.2),
                          ),
                          onPressed: () => _loadInitialData(forceRefresh: true),
                          tooltip: 'Refresh Menu',
                        ),
                        if (kIsWeb)
                          IconButton(
                            icon: const Icon(
                              Icons.settings_applications_outlined,
                              color: Colors.white,
                            ),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.2),
                            ),
                            tooltip: 'Order Type Settings',
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => OrderTypeSettingsScreen(
                                    brandId: widget.brandId,
                                  ),
                                ),
                              );
                              _fetchOrderTypeConfigs();
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoryHeader(MenuCategory category) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.restaurant_menu,
                  color: Theme.of(context).primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  category.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (category.description != null &&
              category.description!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              category.description!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMenuItemCard(MenuItemWithRecipe menuItemWithRecipe, int index) {
    final menuItem = menuItemWithRecipe.menuItem;

    return AnimatedContainer(
      duration: Duration(milliseconds: 300 + (index * 50)),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            final cartProvider = Provider.of<CartProvider>(
              context,
              listen: false,
            );
            final bool addedSuccessfully = cartProvider.addToCart(
              menuItemWithRecipe,
              widget.brandId,
              widget.brandName,
            );

            if (addedSuccessfully) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text('${menuItem.name} added to cart'),
                    ],
                  ),
                  backgroundColor: Colors.green[600],
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Cannot add item. Cart has items from "${cartProvider.activeBrandName ?? 'another brand'}".',
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: Colors.orange[600],
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey[100],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child:
                        menuItem.imageUrl != null &&
                            menuItem.imageUrl!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: menuItem.imageUrl!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.0,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Theme.of(context).primaryColor,
                                  ),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Icon(
                              Icons.restaurant_menu_outlined,
                              size: 30,
                              color: Colors.grey[500],
                            ),
                          )
                        : Icon(
                            Icons.restaurant_menu_outlined,
                            size: 30,
                            color: Colors.grey[500],
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        menuItem.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (menuItem.description != null &&
                          menuItem.description!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          menuItem.description!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '€${menuItem.price.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.add_shopping_cart,
                              color: Theme.of(context).primaryColor,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWebMenuItemCard(
    MenuItemWithRecipe menuItemWithRecipe,
    int index,
  ) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300 + (index * 25)),
      curve: Curves.easeOutCubic,
      child: MenuItemCard(
        menuItemWithRecipe: menuItemWithRecipe,
        brandId: widget.brandId,
        brandName: widget.brandName,
      ),
    );
  }

  Widget _buildMenuContent() {
    // This method will be replaced by _buildCategorizedMenuTabs
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading delicious menu...',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
            const SizedBox(height: 16),
            Text(
              'Oops! Something went wrong',
              style: TextStyle(
                fontSize: 18,
                color: Colors.red[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _loadInitialData(forceRefresh: true),
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    if (_brandMenuData == null || _brandMenuData!.categoriesWithItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.restaurant_menu_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No menu available',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              'Menu items will appear here once available',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    // This existing _buildMenuContent will be replaced by the TabBarView structure.
    // The logic for displaying items per category will be moved into the TabBarView children.
    // For now, let's comment it out to avoid conflicts and prepare for the new structure.
    /*
    return AnimatedBuilder(
      animation: _menuAnimationController,
      builder: (context, child) {
        // ... existing implementation ...
      },
    );
    */
    // Placeholder until the new method is fully integrated
    return const Center(child: Text("Menu content will be here with tabs."));
  }

  Widget _buildCategorizedMenuTabs() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading delicious menu...',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
            const SizedBox(height: 16),
            Text(
              'Oops! Something went wrong',
              style: TextStyle(
                fontSize: 18,
                color: Colors.red[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _loadInitialData(forceRefresh: true),
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    if (_brandMenuData == null || _brandMenuData!.categoriesWithItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.restaurant_menu_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No menu available',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              'Menu items will appear here once available',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    // After initial loading/error/no data checks, explicitly check _tabController
    if (_tabController == null) {
      // This case means there are no categories, or an issue prevented controller initialization.
      // The "No menu available" or "No categories to display" widget (already present above) handles this.
      // Or, if _isLoading is false and _error is null, but _brandMenuData is null or has empty categories.
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.tab_unselected_outlined,
              size: 48,
              color: Colors.grey[500],
            ),
            const SizedBox(height: 16),
            Text(
              'No categories available to display as tabs.',
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // If _tabController is not null, proceed to build TabBar and TabBarView
    return Column(
      children: <Widget>[
        Container(
          color: Theme.of(
            context,
          ).primaryColor, // Using primaryColor for the TabBar background
          child: TabBar(
            controller:
                _tabController!, // Safe to use ! due to the null check above
            isScrollable: true,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withOpacity(0.7),
            indicatorColor: Theme.of(
              context,
            ).colorScheme.secondary, // Accent color for indicator
            indicatorWeight: 3.0,
            labelPadding: const EdgeInsets.symmetric(
              horizontal: 20.0,
            ), // More padding for tabs
            tabs: _brandMenuData!.categoriesWithItems.map((categoryWithItems) {
              // _brandMenuData is non-null here due to earlier checks
              return Tab(
                child: Text(
                  categoryWithItems.category.name.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController!, // Safe to use !
            children: _brandMenuData!.categoriesWithItems.map((
              categoryWithItems,
            ) {
              // _brandMenuData is non-null
              final itemsInSection = categoryWithItems.itemsWithRecipe;
              if (itemsInSection.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'No items in "${categoryWithItems.category.name}".',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  ),
                );
              }
              if (kIsWeb) {
                return GridView.builder(
                  padding: const EdgeInsets.all(16.0), // Consistent padding
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 320.0, // Max width for each item
                    childAspectRatio:
                        2 /
                        2.5, // Aspect ratio (width / height) - adjust for content
                    crossAxisSpacing:
                        16.0, // Spacing between items horizontally
                    mainAxisSpacing: 16.0, // Spacing between items vertically
                  ),
                  itemCount: itemsInSection.length,
                  itemBuilder: (context, itemIndex) {
                    return _buildWebMenuItemCard(
                      itemsInSection[itemIndex],
                      itemIndex,
                    );
                  },
                );
              } else {
                // Mobile
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8.0,
                  ), // Padding for the list
                  itemCount: itemsInSection.length,
                  itemBuilder: (context, itemIndex) {
                    return _buildMenuItemCard(
                      itemsInSection[itemIndex],
                      itemIndex,
                    );
                  },
                );
              }
            }).toList(),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          _buildModernHeader(),
          Expanded(
            child: kIsWeb
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: _buildCategorizedMenuTabs(), // Use new method
                      ),
                      Container(width: 1, color: Colors.grey[300]),
                      Expanded(
                        flex: 1,
                        child: Material(
                          elevation: 4.0,
                          child: Container(
                            color: Colors.white,
                            child: CartViewWidget(
                              orderTypeConfigs: _orderTypeConfigs,
                              brandId: widget.brandId,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : _buildCategorizedMenuTabs(), // Use new method for mobile too
          ),
        ],
      ),
    );
  }
}
