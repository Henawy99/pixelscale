import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:restaurantadmin/models/menu_category.dart';
import 'package:restaurantadmin/models/menu_item_model.dart';
import 'package:restaurantadmin/screens/unified_edit_menu_item_screen.dart';

class BrandMenuScreen extends StatefulWidget {
  final String brandId;
  final String brandName;

  const BrandMenuScreen({
    super.key,
    required this.brandId,
    required this.brandName,
  });

  @override
  State<BrandMenuScreen> createState() => _BrandMenuScreenState();
}

class _BrandMenuScreenState extends State<BrandMenuScreen>
    with TickerProviderStateMixin {
  List<MenuCategory> _categories = [];
  Map<String, List<MenuItem>> _itemsByCategory = {};
  bool _isLoading = true;
  String? _error;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Search and filter
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isGridView = false;
  String? _selectedCategoryFilter;

  // Lieferando rating
  double? _lieferandoRating;
  int? _lieferandoReviewCount;
  String? _lieferandoUrl;
  DateTime? _lieferandoUpdatedAt;
  bool _isRefreshingRating = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );

    _loadDataWithCacheFallback();
    _fetchLieferandoData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<MenuItem> _getFilteredItems() {
    List<MenuItem> allItems = [];

    if (_selectedCategoryFilter != null) {
      allItems = _itemsByCategory[_selectedCategoryFilter] ?? [];
    } else {
      _itemsByCategory.forEach((key, items) {
        allItems.addAll(items);
      });
    }

    if (_searchQuery.isEmpty) {
      return allItems;
    }

    return allItems.where((item) {
      final nameLower = item.name.toLowerCase();
      final descLower = (item.description ?? '').toLowerCase();
      final queryLower = _searchQuery.toLowerCase();
      return nameLower.contains(queryLower) || descLower.contains(queryLower);
    }).toList();
  }

  Future<void> _loadDataWithCacheFallback() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final categoriesBox = Hive.box<List<dynamic>>('menuCategoriesBox');
      final itemsBox = Hive.box<Map<String, List<dynamic>>>('menuItemsBox');

      final List<dynamic>? cachedCategoriesDynamic = categoriesBox.get(
        widget.brandId,
      );
      final Map<String, List<dynamic>>? cachedItemsMapDynamic = itemsBox.get(
        widget.brandId,
      );

      if (cachedCategoriesDynamic != null && cachedItemsMapDynamic != null) {
        final List<MenuCategory> cachedCategories = cachedCategoriesDynamic
            .cast<MenuCategory>()
            .toList();
        final Map<String, List<MenuItem>> cachedItemsMap = cachedItemsMapDynamic
            .map(
              (key, value) => MapEntry(key, value.cast<MenuItem>().toList()),
            );

        if (cachedCategories.isNotEmpty) {
          if (!mounted) return;
          setState(() {
            _categories = cachedCategories;
            _itemsByCategory = cachedItemsMap;
            _isLoading = false;
          });
          _animationController.forward();
          print("Menu data loaded from cache for brand ${widget.brandId}");
          return;
        }
      }
    } catch (e) {
      print("Error loading menu data from cache: $e. Fetching from network.");
    }

    await _fetchAndCacheMenuData();
  }

  Future<void> _fetchAndCacheMenuData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final supabase = Supabase.instance.client;

      // Fetch categories
      final categoriesResponse = await supabase
          .from('menu_categories')
          .select()
          .eq('brand_id', widget.brandId)
          .order('display_order', ascending: true);

      if (!mounted) return;

      final List<MenuCategory> categories = (categoriesResponse as List)
          .map((data) => MenuCategory.fromJson(data as Map<String, dynamic>))
          .toList();

      // Fetch menu items for each category
      final Map<String, List<MenuItem>> itemsByCategory = {};
      for (final category in categories) {
        final itemsResponse = await supabase
            .from('menu_items')
            .select()
            .eq('category_id', category.id)
            .order('display_order', ascending: true);

        if (!mounted) return;

        final List<MenuItem> items = (itemsResponse as List)
            .map((data) => MenuItem.fromJson(data as Map<String, dynamic>))
            .toList();

        itemsByCategory[category.id] = items;
      }

      // Cache the data
      try {
        final categoriesBox = Hive.box<List<dynamic>>('menuCategoriesBox');
        final itemsBox = Hive.box<Map<String, List<dynamic>>>('menuItemsBox');

        await categoriesBox.put(widget.brandId, categories);
        await itemsBox.put(
          widget.brandId,
          itemsByCategory.map(
            (key, value) => MapEntry(key, value.cast<dynamic>()),
          ),
        );
      } catch (e) {
        print("Error caching menu data: $e");
      }

      if (!mounted) return;
      setState(() {
        _categories = categories;
        _itemsByCategory = itemsByCategory;
        _isLoading = false;
      });
      _animationController.forward();
    } catch (e) {
      print("Error fetching menu data: $e");
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchLieferandoData() async {
    if (!mounted) return;
    try {
      final response = await Supabase.instance.client
          .from('brands')
          .select('lieferando_url, lieferando_rating, lieferando_review_count, lieferando_rating_updated_at')
          .eq('id', widget.brandId)
          .maybeSingle();

      if (!mounted || response == null) return;

      setState(() {
        _lieferandoUrl = response['lieferando_url'] as String?;
        final rawRating = response['lieferando_rating'];
        _lieferandoRating = rawRating != null ? (rawRating as num).toDouble() : null;
        _lieferandoReviewCount = response['lieferando_review_count'] as int?;
        final updatedAtStr = response['lieferando_rating_updated_at'] as String?;
        _lieferandoUpdatedAt =
            updatedAtStr != null ? DateTime.tryParse(updatedAtStr) : null;
      });
    } catch (e) {
      print('Error fetching Lieferando data: $e');
    }
  }

  Future<void> _refreshLieferandoRating() async {
    if (_lieferandoUrl == null || _isRefreshingRating) return;
    if (!mounted) return;
    setState(() => _isRefreshingRating = true);
    try {
      await Supabase.instance.client.functions.invoke(
        'fetch-lieferando-ratings',
        body: {'brand_id': widget.brandId},
      );
      await _fetchLieferandoData();
      if (mounted) {
        _showSuccessSnackBar('Lieferando rating refreshed!');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Could not refresh rating: $e');
      }
    } finally {
      if (mounted) setState(() => _isRefreshingRating = false);
    }
  }

  void _editMenuItem(MenuItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UnifiedEditMenuItemScreen(menuItem: item),
      ),
    ).then((_) {
      // Refresh display
      _fetchAndCacheMenuData();
    });
  }

  Future<void> _deleteMenuItem(MenuItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red[600], size: 28),
            const SizedBox(width: 12),
            const Text('Delete Menu Item'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${item.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // First delete associated materials
      await Supabase.instance.client
          .from('menu_item_materials')
          .delete()
          .eq('menu_item_id', item.id);

      // Then delete the menu item
      await Supabase.instance.client
          .from('menu_items')
          .delete()
          .eq('id', item.id);

      if (mounted) {
        _fetchAndCacheMenuData();
        _showSuccessSnackBar('Menu item deleted successfully!');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to delete menu item: $e');
      }
    }
  }

  Future<void> _addCategory() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _AddEditCategoryDialog(brandId: widget.brandId),
    );

    if (result == true && mounted) {
      _fetchAndCacheMenuData();
      _showSuccessSnackBar('Category added successfully!');
    }
  }

  Future<void> _editCategory(MenuCategory category) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) =>
          _AddEditCategoryDialog(brandId: widget.brandId, category: category),
    );

    if (result == true && mounted) {
      _fetchAndCacheMenuData();
      _showSuccessSnackBar('Category updated successfully!');
    }
  }

  Future<void> _deleteCategory(MenuCategory category) async {
    // Check if category has items
    final itemsInCategory = _itemsByCategory[category.id] ?? [];
    if (itemsInCategory.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange[600],
                size: 28,
              ),
              const SizedBox(width: 12),
              const Text('Cannot Delete'),
            ],
          ),
          content: Text(
            'This category has ${itemsInCategory.length} items. Please move or delete all items before deleting the category.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red[600], size: 28),
            const SizedBox(width: 12),
            const Text('Delete Category'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${category.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await Supabase.instance.client
          .from('menu_categories')
          .delete()
          .eq('id', category.id);

      if (mounted) {
        _fetchAndCacheMenuData();
        _showSuccessSnackBar('Category deleted successfully!');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to delete category: $e');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _loadItemMaterials(
    String menuItemId,
  ) async {
    try {
      final rows = await Supabase.instance.client
          .from('menu_item_materials')
          .select(
            'id, quantity_used, unit_of_measure_for_usage, notes, material_id(id,name,unit_of_measure,item_image_url)',
          )
          .eq('menu_item_id', menuItemId)
          .order('created_at');
      final list = <Map<String, dynamic>>[];
      for (final r in (rows as List)) {
        final m = Map<String, dynamic>.from(r);
        final mat = Map<String, dynamic>.from(m['material_id'] ?? {});
        list.add({
          'id': m['id'] as String,
          'name': mat['name'] ?? '-',
          'unit': mat['unit_of_measure'] ?? '',
          'qty': (m['quantity_used'] as num?)?.toDouble() ?? 0.0,
          'image': mat['item_image_url'] as String?,
          'notes': m['notes'] as String?,
        });
      }
      return list;
    } catch (e) {
      print('Error loading materials: $e');
      return [];
    }
  }

  Widget _buildLieferandoBadge() {
    if (_lieferandoUrl == null) return const SizedBox.shrink();

    const lieferandoOrange = Color(0xFFF7941D);
    final hasRating = _lieferandoRating != null;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Lieferando logo pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: lieferandoOrange,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'lieferando',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (hasRating) ...[
            // Star icons
            ...List.generate(5, (i) {
              final full = i < _lieferandoRating!.floor();
              final half = !full && i < _lieferandoRating!;
              return Icon(
                full
                    ? Icons.star
                    : half
                    ? Icons.star_half
                    : Icons.star_border,
                color: lieferandoOrange,
                size: 16,
              );
            }),
            const SizedBox(width: 5),
            Text(
              _lieferandoRating!.toStringAsFixed(1),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            if (_lieferandoReviewCount != null && _lieferandoReviewCount! > 0) ...[
              const SizedBox(width: 4),
              Text(
                '(${_lieferandoReviewCount})',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ] else ...[
            const Text(
              'Rating not yet fetched',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
          const SizedBox(width: 8),
          // Refresh button with last-updated tooltip
          Tooltip(
            message: _lieferandoUpdatedAt != null
                ? 'Last updated: ${_lieferandoUpdatedAt!.day.toString().padLeft(2, '0')}/${_lieferandoUpdatedAt!.month.toString().padLeft(2, '0')}/${_lieferandoUpdatedAt!.year}  •  Tap to refresh'
                : 'Tap to fetch rating',
            child: GestureDetector(
              onTap: _refreshLieferandoRating,
              child: _isRefreshingRating
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                      ),
                    )
                  : const Icon(Icons.refresh, color: Colors.white70, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final totalItems = _itemsByCategory.values.fold<int>(
      0,
      (sum, list) => sum + list.length,
    );
    final filteredItems = _getFilteredItems();

    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Brand info header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [Colors.orange[600]!, Colors.orange[400]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.restaurant_menu,
                    color: Colors.white,
                    size: 32,
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
                      const SizedBox(height: 4),
                      Text(
                        '${_categories.length} categories • $totalItems items',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      _buildLieferandoBadge(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Search bar
          TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
            decoration: InputDecoration(
              hintText: 'Search menu items...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Filters and view toggle
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip(
                        label: 'All Categories',
                        isSelected: _selectedCategoryFilter == null,
                        onTap: () {
                          setState(() {
                            _selectedCategoryFilter = null;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      ..._categories.map((category) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _buildFilterChip(
                            label: category.name,
                            isSelected: _selectedCategoryFilter == category.id,
                            onTap: () {
                              setState(() {
                                _selectedCategoryFilter = category.id;
                              });
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // View toggle
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () {
                        setState(() {
                          _isGridView = false;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: !_isGridView
                              ? Colors.orange[100]
                              : Colors.transparent,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(8),
                            bottomLeft: Radius.circular(8),
                          ),
                        ),
                        child: Icon(
                          Icons.view_list,
                          size: 20,
                          color: !_isGridView
                              ? Colors.orange[600]
                              : Colors.grey[600],
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _isGridView = true;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _isGridView
                              ? Colors.orange[100]
                              : Colors.transparent,
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(8),
                            bottomRight: Radius.circular(8),
                          ),
                        ),
                        child: Icon(
                          Icons.grid_view,
                          size: 20,
                          color: _isGridView
                              ? Colors.orange[600]
                              : Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (_searchQuery.isNotEmpty || _selectedCategoryFilter != null) ...[
            const SizedBox(height: 8),
            Text(
              'Showing ${filteredItems.length} of $totalItems items',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange[600] : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.orange[600]! : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildMaterialsPreview(String menuItemId, String itemName) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadItemMaterials(menuItemId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.teal[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.teal[600]!,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'Loading materials...',
                  style: TextStyle(fontSize: 10, color: Colors.teal[600]),
                ),
              ],
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 12, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  'Error loading materials',
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        final materials = snapshot.data!;
        if (materials.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 12,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  'No materials',
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return Wrap(
          spacing: 4,
          runSpacing: 4,
          children: materials.map((material) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.teal[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.teal[200]!),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inventory_2, size: 12, color: Colors.teal[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${material['name']} (${material['qty']} ${material['unit']})',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.teal[600],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildMenuItem(MenuItem item, int itemIndex) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _editMenuItem(item),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    // Menu item image
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CachedNetworkImage(
                                imageUrl: item.imageUrl!,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.broken_image_outlined,
                                    size: 30,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ),
                            )
                          : Container(
                              decoration: BoxDecoration(
                                color: Colors.orange[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.restaurant_menu_outlined,
                                size: 30,
                                color: Colors.orange[600],
                              ),
                            ),
                    ),
                    const SizedBox(width: 16),
                    // Menu item details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          if (item.description != null &&
                              item.description!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              item.description!,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
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
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.green[600]!,
                                      Colors.green[400]!,
                                    ],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  "€${item.price.toStringAsFixed(2)}",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              if (item.attributes != null &&
                                  item.attributes!.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    item.attributes!.entries
                                        .map((e) => "${e.key}: ${e.value}")
                                        .join(', '),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Action buttons
                    Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.teal[600]!, Colors.teal[400]!],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => _editMenuItem(item),
                              child: const Padding(
                                padding: EdgeInsets.all(8),
                                child: Icon(
                                  Icons.link,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => _editMenuItem(item),
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Icon(
                                  Icons.edit,
                                  color: Colors.grey[600],
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => _deleteMenuItem(item),
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Icon(
                                  Icons.delete_outline,
                                  color: Colors.red[600],
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Materials preview
                _buildMaterialsPreview(item.id, item.name),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const CircularProgressIndicator(),
          ),
          const SizedBox(height: 24),
          Text(
            'Loading menu for ${widget.brandName}...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
            const SizedBox(height: 20),
            Text(
              'Failed to Load Menu',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _error ?? 'Unknown error occurred',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red[600]!, Colors.red[400]!],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _fetchAndCacheMenuData,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.refresh, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Try Again',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.restaurant_menu, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 24),
          Text(
            'No Menu Categories',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'No menu categories found for ${widget.brandName}.\nContact support to add menu items.',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange[600]!, Colors.orange[400]!],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _fetchAndCacheMenuData,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Refresh Menu',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildCategoryView() {
    return ListView(
      children: [
        _buildHeader(),
        ..._categories.asMap().entries.map((entry) {
          final categoryIndex = entry.key;
          final category = entry.value;
          final itemsInSection = _itemsByCategory[category.id] ?? [];

          return FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0, 0.1),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: _animationController,
                      curve: Interval(
                        (categoryIndex * 0.1).clamp(0.0, 1.0),
                        ((categoryIndex * 0.1) + 0.3).clamp(0.0, 1.0),
                        curve: Curves.easeOut,
                      ),
                    ),
                  ),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.orange[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.restaurant_menu,
                              color: Colors.orange[600],
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              category.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${itemsInSection.length} items',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange[700],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () => _editCategory(category),
                            icon: Icon(
                              Icons.edit,
                              size: 20,
                              color: Colors.grey[600],
                            ),
                            tooltip: 'Edit Category',
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                          ),
                          IconButton(
                            onPressed: () => _deleteCategory(category),
                            icon: Icon(
                              Icons.delete_outline,
                              size: 20,
                              color: Colors.red[600],
                            ),
                            tooltip: 'Delete Category',
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                    if (itemsInSection.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: Text(
                            'No items in this category',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ),
                      )
                    else
                      ...itemsInSection.asMap().entries.map((entry) {
                        final itemIndex = entry.key;
                        final item = entry.value;
                        return _buildMenuItem(item, itemIndex);
                      }),
                  ],
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildFilteredView() {
    final filteredItems = _getFilteredItems();

    return ListView(
      children: [
        _buildHeader(),
        if (filteredItems.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(48),
              child: Column(
                children: [
                  Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No items found',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Try adjusting your search or filters',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          )
        else if (_isGridView)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth > 900
                    ? 3
                    : (constraints.maxWidth > 600 ? 2 : 1);
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: filteredItems.length,
                  itemBuilder: (context, index) {
                    return _buildMenuItemGrid(filteredItems[index]);
                  },
                );
              },
            ),
          )
        else
          ...filteredItems.map((item) => _buildMenuItem(item, 0)),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildMenuItemGrid(MenuItem item) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _editMenuItem(item),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image
              Expanded(
                flex: 3,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    color: Colors.grey[200],
                  ),
                  child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                      ? ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                          child: CachedNetworkImage(
                            imageUrl: item.imageUrl!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[200],
                              child: const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey[200],
                              child: Icon(
                                Icons.broken_image_outlined,
                                size: 40,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        )
                      : Container(
                          color: Colors.orange[100],
                          child: Icon(
                            Icons.restaurant_menu_outlined,
                            size: 48,
                            color: Colors.orange[600],
                          ),
                        ),
                ),
              ),
              // Details
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.green[600]!, Colors.green[400]!],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "€${item.price.toStringAsFixed(2)}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          widget.brandName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: _addCategory,
              tooltip: 'Add Category',
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () async {
                await _fetchAndCacheMenuData();
                if (_error == null) {
                  _showSuccessSnackBar('Menu refreshed successfully!');
                }
              },
              tooltip: 'Refresh Menu',
            ),
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: _isLoading
              ? _buildLoadingState()
              : _error != null
              ? _buildErrorState()
              : _categories.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: () async {
                    await _fetchAndCacheMenuData();
                    if (_error == null) {
                      _showSuccessSnackBar('Menu refreshed successfully!');
                    }
                  },
                  color: Colors.orange,
                  child:
                      _searchQuery.isNotEmpty || _selectedCategoryFilter != null
                      ? _buildFilteredView()
                      : _buildCategoryView(),
                ),
        ),
      ),
    );
  }
}

// Add/Edit Category Dialog
class _AddEditCategoryDialog extends StatefulWidget {
  final String brandId;
  final MenuCategory? category;

  const _AddEditCategoryDialog({required this.brandId, this.category});

  @override
  State<_AddEditCategoryDialog> createState() => _AddEditCategoryDialogState();
}

class _AddEditCategoryDialogState extends State<_AddEditCategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _displayOrderController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.name ?? '');
    _displayOrderController = TextEditingController(
      text: widget.category?.displayOrder.toString() ?? '0',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _displayOrderController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final name = _nameController.text.trim();
      final displayOrder = int.tryParse(_displayOrderController.text) ?? 0;

      if (widget.category == null) {
        // Add new category
        await Supabase.instance.client.from('menu_categories').insert({
          'brand_id': widget.brandId,
          'name': name,
          'display_order': displayOrder,
        });
      } else {
        // Update existing category
        await Supabase.instance.client
            .from('menu_categories')
            .update({'name': name, 'display_order': displayOrder})
            .eq('id', widget.category!.id);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Failed to ${widget.category == null ? 'add' : 'update'} category: $e',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.category != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isEditing ? Icons.edit : Icons.add_circle_outline,
                    color: Colors.orange[600],
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isEditing ? 'Edit Category' : 'Add Category',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Form
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Category Name*',
                      hintText: 'e.g., Appetizers, Main Courses',
                      prefixIcon: const Icon(Icons.category),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a category name';
                      }
                      return null;
                    },
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _displayOrderController,
                    decoration: InputDecoration(
                      labelText: 'Display Order',
                      hintText: '0',
                      helperText: 'Lower numbers appear first',
                      prefixIcon: const Icon(Icons.format_list_numbered),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return null; // Optional field
                      }
                      if (int.tryParse(value) == null) {
                        return 'Please enter a valid number';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: Colors.grey[600], fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            isEditing ? 'Update' : 'Add Category',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
