import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:restaurantadmin/widgets/category_card.dart';
import 'package:restaurantadmin/services/worker_cache_service.dart';
import 'package:restaurantadmin/models/worker_cache_models.dart';

class WorkerMenusScreen extends StatefulWidget {
  final VoidCallback? onBrandSelectionChanged;

  const WorkerMenusScreen({super.key, this.onBrandSelectionChanged});

  @override
  State<WorkerMenusScreen> createState() => WorkerMenusScreenState();
}

class WorkerMenusScreenState extends State<WorkerMenusScreen>
    with TickerProviderStateMixin {
  final _cacheService = WorkerCacheService.instance;
  bool _loading = true;
  String? _error;

  List<CachedBrand> _brands = [];
  String? _selectedBrandId;

  List<CachedCategory> _categories = [];
  Map<String, List<CachedMenuItem>> _itemsByCategory = {};

  // Animations to match Menus UI feel
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  String? _selectedCategoryId; // For category chip filtering
  bool _isArabic = false; // Language toggle
  // Exposed helpers for shell
  bool get hasSelectedBrand => _selectedBrandId != null;
  void clearBrandSelection() {
    setState(() {
      _selectedBrandId = null;
      _selectedCategoryId = null;
      _categories = [];
      _itemsByCategory = {};
      _searchQuery = '';
    });
    widget.onBrandSelectionChanged?.call();
  }

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

    // Start animation after a short delay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _animationController.forward();
      }
    });

    _fetchBrands();
  }

  Widget _buildBrandPicker() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final crossAxisCount = isMobile
            ? 2
            : (constraints.maxWidth > 1000 ? 5 : 3);
        return Column(
          children: [
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.store_mall_directory, color: Colors.orange[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isArabic ? 'اختر العلامة التجارية' : 'Choose a Brand',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  // Language toggle
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: () => setState(() => _isArabic = false),
                          style: TextButton.styleFrom(
                            backgroundColor: !_isArabic
                                ? Colors.orange[600]
                                : Colors.transparent,
                            foregroundColor: !_isArabic
                                ? Colors.white
                                : Colors.orange[700],
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                          ),
                          child: const Text(
                            'EN',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(() => _isArabic = true),
                          style: TextButton.styleFrom(
                            backgroundColor: _isArabic
                                ? Colors.orange[600]
                                : Colors.transparent,
                            foregroundColor: _isArabic
                                ? Colors.white
                                : Colors.orange[700],
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                          ),
                          child: const Text(
                            'عربي',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Refresh',
                    icon: const Icon(Icons.refresh),
                    onPressed: () => _fetchBrands(forceRefresh: true),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.1,
                ),
                itemCount: _brands.length,
                itemBuilder: (context, index) {
                  final brand = _brands[index];
                  return CategoryCard(
                    categoryName: brand.name,
                    imageUrl: brand.imageUrl,
                    isNetworkImage:
                        brand.imageUrl != null &&
                        brand.imageUrl!.startsWith('http'),
                    onTap: () async {
                      setState(() {
                        _selectedBrandId = brand.id;
                        _selectedCategoryId = null;
                      });
                      await _fetchMenuForBrand(brand.id);
                      widget.onBrandSelectionChanged?.call();
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();

    super.dispose();
  }

  Future<void> _fetchBrands({bool forceRefresh = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _brands = await _cacheService.getBrands(forceRefresh: forceRefresh);
      if (_brands.isNotEmpty) {
        // Wait for user to select brand on the new picker screen
      }
    } catch (e) {
      print('Error fetching brands: $e');
      _error = e.toString();
    } finally {
      if (mounted)
        setState(() {
          _loading = false;
        });
    }
  }

  Future<void> _fetchMenuForBrand(
    String brandId, {
    bool forceRefresh = false,
  }) async {
    setState(() {
      _loading = true;
      _error = null;
      _categories = [];
      _itemsByCategory = {};
    });
    try {
      // Fetch categories for this brand
      _categories = await _cacheService.getCategoriesForBrand(
        brandId,
        forceRefresh: forceRefresh,
      );

      // Fetch menu items for each category
      for (final category in _categories) {
        final items = await _cacheService.getMenuItemsForCategory(
          category.id,
          forceRefresh: forceRefresh,
        );
        _itemsByCategory[category.id] = items;
      }

      // Auto-select first category on mobile for simpler UX
      if (_categories.isNotEmpty) {
        _selectedCategoryId ??= _categories.first.id;
      }
    } catch (e) {
      print('Error fetching menu: $e');
      _error = e.toString();
    } finally {
      if (mounted)
        setState(() {
          _loading = false;
        });
    }
  }

  // Removed hardcoded ingredient translations

  // Removed hardcoded unit translations

  Future<List<Map<String, dynamic>>> _loadItemMaterials(
    String menuItemId,
  ) async {
    try {
      print('=== LOADING MATERIALS FOR MENU ITEM: $menuItemId ===');

      // Temporarily bypass cache and fetch directly from Supabase to debug
      final supabase = Supabase.instance.client;

      // Get menu item materials directly from Supabase
      print('Fetching menu item materials from Supabase...');
      final menuItemMaterialsResponse = await supabase
          .from('menu_item_materials')
          .select(
            'id,quantity_used,unit_of_measure_for_usage,notes,material_id,menu_item_id',
          )
          .eq('menu_item_id', menuItemId)
          .order('created_at');

      print(
        'Direct Supabase response for menu item materials: ${menuItemMaterialsResponse.length} items',
      );
      print('Response data: $menuItemMaterialsResponse');

      if (menuItemMaterialsResponse.isEmpty) {
        print('❌ No materials found for menu item: $menuItemId');
        return [];
      }

      // Get all materials directly from Supabase
      print('Fetching all materials from Supabase...');
      final materialsResponse = await supabase
          .from('material')
          .select('id,name,unit_of_measure,item_image_url');

      print(
        'Direct Supabase response for materials: ${materialsResponse.length} items',
      );
      final materialsMap = {
        for (var m in materialsResponse) m['id'] as String: m,
      };

      final list = <Map<String, dynamic>>[];

      for (final menuItemMaterialData in menuItemMaterialsResponse) {
        final materialId = menuItemMaterialData['material_id'] as String;
        print('Processing menu item material: $materialId');

        final material = materialsMap[materialId];
        if (material != null) {
          final englishName = material['name'] as String;
          final unit =
              (menuItemMaterialData['unit_of_measure_for_usage'] as String?)
                      ?.isNotEmpty ==
                  true
              ? menuItemMaterialData['unit_of_measure_for_usage'] as String
              : material['unit_of_measure'] as String;
          final arabicName =
              (material['arabic_name'] as String?)?.isNotEmpty == true
              ? material['arabic_name'] as String
              : englishName;

          print('✅ Material: $englishName -> Arabic: $arabicName, Unit: $unit');
          list.add({
            'name': englishName,
            'arabic_name': arabicName,
            'unit': unit,
            'qty': menuItemMaterialData['quantity_used'] as double,
            'image': material['item_image_url'] as String?,
            'notes': menuItemMaterialData['notes'] as String?,
          });
        } else {
          print('❌ Material not found for ID: $materialId');
        }
      }

      print('=== RETURNING ${list.length} MATERIALS ===');
      return list;
    } catch (e) {
      print('❌ Error loading materials: $e');
      print('Stack trace: ${StackTrace.current}');
      return [];
    }
  }

  List<CachedMenuItem> _getFilteredItems() {
    Iterable<CachedMenuItem> pool;
    if (_selectedCategoryId != null) {
      pool = _itemsByCategory[_selectedCategoryId] ?? const <CachedMenuItem>[];
    } else {
      pool = _itemsByCategory.values.expand((items) => items);
    }
    if (_searchQuery.isEmpty) return pool.toList();
    return pool
        .where(
          (item) =>
              item.name.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();
  }

  void _openItemDialog(CachedMenuItem item) async {
    print('=== OPENING DIALOG FOR ITEM: ${item.name} (ID: ${item.id}) ===');
    final materials = await _loadItemMaterials(item.id);
    print('=== LOADED ${materials.length} MATERIALS FOR DIALOG ===');

    if (!mounted) {
      print('Widget not mounted, returning');
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange[600]!, Colors.orange[400]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.fastfood,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '€${item.price.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Item Image
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: (item.imageUrl?.isNotEmpty ?? false)
                            ? CachedNetworkImage(
                                imageUrl: item.imageUrl!,
                                height: 200,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  height: 200,
                                  color: Colors.grey[200],
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  height: 200,
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.fastfood, size: 48),
                                ),
                              )
                            : Container(
                                height: 200,
                                width: double.infinity,
                                color: Colors.grey[200],
                                child: const Icon(Icons.fastfood, size: 48),
                              ),
                      ),

                      const SizedBox(height: 24),

                      // Materials Section
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.teal[50],
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.teal[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.inventory_2,
                                  color: Colors.teal[600],
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _isArabic
                                      ? 'المواد والكميات'
                                      : 'Materials & Quantities',
                                  style: TextStyle(
                                    color: Colors.teal[700],
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (materials.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _isArabic
                                          ? 'لا توجد مواد مرتبطة بهذا العنصر'
                                          : 'No materials linked to this item',
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              )
                            else
                              ...materials.asMap().entries.map((entry) {
                                final index = entry.key;
                                final material = entry.value;
                                return Container(
                                  margin: EdgeInsets.only(
                                    bottom: index < materials.length - 1
                                        ? 12
                                        : 0,
                                  ),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.teal[100]!,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      // Material Image
                                      if ((material['image'] as String?)
                                              ?.isNotEmpty ??
                                          false)
                                        Container(
                                          margin: const EdgeInsets.only(
                                            right: 12,
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            child: CachedNetworkImage(
                                              imageUrl:
                                                  material['image'] as String,
                                              width: 40,
                                              height: 40,
                                              fit: BoxFit.cover,
                                              placeholder: (context, url) =>
                                                  Container(
                                                    width: 40,
                                                    height: 40,
                                                    color: Colors.grey[200],
                                                    child: const Icon(
                                                      Icons.image,
                                                      size: 20,
                                                    ),
                                                  ),
                                              errorWidget:
                                                  (context, url, error) =>
                                                      Container(
                                                        width: 40,
                                                        height: 40,
                                                        color: Colors.grey[200],
                                                        child: const Icon(
                                                          Icons.image,
                                                          size: 20,
                                                        ),
                                                      ),
                                            ),
                                          ),
                                        )
                                      else
                                        Container(
                                          margin: const EdgeInsets.only(
                                            right: 12,
                                          ),
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: Colors.teal[100],
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.inventory_2,
                                            color: Colors.teal[600],
                                            size: 20,
                                          ),
                                        ),

                                      // Material Details
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              () {
                                                final displayName = _isArabic
                                                    ? (material['arabic_name']
                                                          as String)
                                                    : (material['name']
                                                          as String);
                                                print(
                                                  'Displaying material name: $displayName (Arabic mode: $_isArabic)',
                                                );
                                                return displayName;
                                              }(),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (_isArabic)
                                              Align(
                                                alignment: Alignment.centerLeft,
                                                child: TextButton.icon(
                                                  onPressed: () async {
                                                    final currentArabic =
                                                        material['arabic_name']
                                                            as String?;
                                                    final controller =
                                                        TextEditingController(
                                                          text: currentArabic,
                                                        );
                                                    final newName = await showDialog<String>(
                                                      context: context,
                                                      builder: (dCtx) {
                                                        return AlertDialog(
                                                          title: const Text(
                                                            'تعديل الاسم العربي',
                                                          ),
                                                          content: TextField(
                                                            controller:
                                                                controller,
                                                            decoration: InputDecoration(
                                                              labelText:
                                                                  'Arabic name',
                                                              hintText:
                                                                  material['name']
                                                                      as String,
                                                            ),
                                                          ),
                                                          actions: [
                                                            TextButton(
                                                              onPressed: () =>
                                                                  Navigator.pop(
                                                                    dCtx,
                                                                  ),
                                                              child: const Text(
                                                                'إلغاء',
                                                              ),
                                                            ),
                                                            ElevatedButton(
                                                              onPressed: () =>
                                                                  Navigator.pop(
                                                                    dCtx,
                                                                    controller
                                                                        .text
                                                                        .trim(),
                                                                  ),
                                                              child: const Text(
                                                                'حفظ',
                                                              ),
                                                            ),
                                                          ],
                                                        );
                                                      },
                                                    );

                                                    if (newName != null) {
                                                      try {
                                                        // Persist locally and best-effort to server
                                                        final allMaterials =
                                                            await _cacheService
                                                                .getMaterials();
                                                        final match = allMaterials.firstWhere(
                                                          (m) =>
                                                              m.name ==
                                                              (material['name']
                                                                  as String),
                                                          orElse: () => allMaterials
                                                              .firstWhere(
                                                                (m) =>
                                                                    m.id ==
                                                                    (material['id']
                                                                            as String? ??
                                                                        ''),
                                                              ), // fallback if id carried later
                                                        );
                                                        await _cacheService
                                                            .setMaterialArabicName(
                                                              match.id,
                                                              newName,
                                                            );

                                                        setState(() {
                                                          material['arabic_name'] =
                                                              newName.isEmpty
                                                              ? material['name']
                                                              : newName;
                                                        });
                                                      } catch (e) {
                                                        ScaffoldMessenger.of(
                                                          context,
                                                        ).showSnackBar(
                                                          SnackBar(
                                                            content: Text(
                                                              'تعذر حفظ الاسم العربي: $e',
                                                            ),
                                                          ),
                                                        );
                                                      }
                                                    }
                                                  },
                                                  icon: const Icon(
                                                    Icons.edit,
                                                    size: 14,
                                                  ),
                                                  label: const Text(
                                                    'تعديل',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  style: TextButton.styleFrom(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            if (_isArabic &&
                                                (material['name'] as String) !=
                                                    (material['arabic_name']
                                                        as String)) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                material['name'] as String,
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 11,
                                                  fontStyle: FontStyle.italic,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                            const SizedBox(height: 4),
                                            Text(
                                              _isArabic
                                                  ? '${(material['qty'] as double).toStringAsFixed(2)} ${material['unit']}'
                                                  : '${(material['qty'] as double).toStringAsFixed(2)} ${material['unit']}',
                                              style: TextStyle(
                                                color: Colors.teal[600],
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            if (material['notes'] != null &&
                                                (material['notes'] as String)
                                                    .isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                _isArabic
                                                    ? 'ملاحظة: ${material['notes']}'
                                                    : 'Note: ${material['notes']}',
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 10,
                                                  fontStyle: FontStyle.italic,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                          ],
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

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
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
            color: Colors.orange.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.restaurant_menu,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isArabic
                              ? (isMobile
                                    ? 'قائمة الطعام'
                                    : 'دليل قائمة الطعام للعمال')
                              : (isMobile ? 'Menu' : 'Worker Menu Guide'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _isArabic
                              ? '${_categories.length} فئة • ${_itemsByCategory.values.fold<int>(0, (sum, list) => sum + list.length)} عنصر'
                              : '${_categories.length} categories • ${_itemsByCategory.values.fold<int>(0, (sum, list) => sum + list.length)} items',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Category chips (horizontal scroll on mobile)
              if (_categories.isNotEmpty)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          selected: _selectedCategoryId == null,
                          label: Text(_isArabic ? 'الكل' : 'All'),
                          onSelected: (_) =>
                              setState(() => _selectedCategoryId = null),
                        ),
                      ),
                      ..._categories.map((category) {
                        final selected = _selectedCategoryId == category.id;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            selected: selected,
                            label: Text(category.name),
                            onSelected: (_) => setState(
                              () => _selectedCategoryId = category.id,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        decoration: InputDecoration(
          hintText: _isArabic
              ? 'البحث في عناصر القائمة...'
              : 'Search menu items...',
          prefixIcon: Icon(Icons.search, color: Colors.orange[600]),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                  icon: const Icon(Icons.clear),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  int _getCrossAxisCount(double screenWidth) {
    if (screenWidth > 1200) return 4; // Large desktop
    if (screenWidth > 900) return 3; // Desktop
    if (screenWidth > 600) return 2; // Tablet
    return 1; // Mobile
  }

  Widget _buildItemsGrid() {
    final filteredItems = _getFilteredItems();
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = _getCrossAxisCount(constraints.maxWidth);
        final isMobile = constraints.maxWidth <= 600;
        if (isMobile) {
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: filteredItems.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = filteredItems[index];
              return Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                elevation: 1,
                child: InkWell(
                  onTap: () => _openItemDialog(item),
                  borderRadius: BorderRadius.circular(16),
                  child: Row(
                    children: [
                      // Thumbnail
                      ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          bottomLeft: Radius.circular(16),
                        ),
                        child: SizedBox(
                          width: 110,
                          height: 90,
                          child: (item.imageUrl?.isNotEmpty ?? false)
                              ? CachedNetworkImage(
                                  imageUrl: item.imageUrl!,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.fastfood, size: 36),
                                ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Icon(
                          Icons.chevron_right,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.8,
          ),
          itemCount: filteredItems.length,
          itemBuilder: (context, index) {
            final item = filteredItems[index];
            return FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position:
                    Tween<Offset>(
                      begin: const Offset(0, 0.2),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: _animationController,
                        curve: Interval(
                          (index * 0.05).clamp(0.0, 1.0),
                          ((index * 0.05) + 0.3).clamp(0.0, 1.0),
                          curve: Curves.easeOut,
                        ),
                      ),
                    ),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _openItemDialog(item),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Item Image
                          Expanded(
                            flex: 3,
                            child: ClipRRect(
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(16),
                                topRight: Radius.circular(16),
                              ),
                              child: (item.imageUrl?.isNotEmpty ?? false)
                                  ? CachedNetworkImage(
                                      imageUrl: item.imageUrl!,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        color: Colors.grey[200],
                                        child: const Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      ),
                                      errorWidget: (context, url, error) =>
                                          Container(
                                            color: Colors.grey[200],
                                            child: const Icon(
                                              Icons.fastfood,
                                              size: 48,
                                            ),
                                          ),
                                    )
                                  : Container(
                                      color: Colors.grey[200],
                                      child: const Icon(
                                        Icons.fastfood,
                                        size: 48,
                                      ),
                                    ),
                            ),
                          ),

                          // Item Details
                          Expanded(
                            flex: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const Spacer(),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.inventory_2,
                                        color: Colors.teal[600],
                                        size: 16,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _isArabic
                                            ? 'عرض المواد'
                                            : 'View Materials',
                                        style: TextStyle(
                                          color: Colors.teal[600],
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 24),
          Text(
            _isArabic ? 'لم يتم العثور على عناصر' : 'No Items Found',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _searchQuery.isEmpty
                ? (_isArabic
                      ? 'لا توجد عناصر قائمة متاحة لهذه العلامة التجارية.'
                      : 'No menu items available for this brand.')
                : (_isArabic
                      ? 'لا توجد عناصر تطابق بحثك "$_searchQuery".'
                      : 'No items match your search "$_searchQuery".'),
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          if (_searchQuery.isNotEmpty) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                });
              },
              icon: const Icon(Icons.clear),
              label: Text(_isArabic ? 'مسح البحث' : 'Clear Search'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[600],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ],
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
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const CircularProgressIndicator(),
          ),
          const SizedBox(height: 24),
          Text(
            _isArabic ? 'جاري تحميل عناصر القائمة...' : 'Loading menu items...',
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
              color: Colors.black.withValues(alpha: 0.1),
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
              _isArabic ? 'عذراً! حدث خطأ ما' : 'Oops! Something went wrong',
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
            ElevatedButton.icon(
              onPressed: () => _fetchBrands(),
              icon: const Icon(Icons.refresh),
              label: Text(_isArabic ? 'حاول مرة أخرى' : 'Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Back behavior is handled by the shell; no PopScope here
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: RefreshIndicator(
        onRefresh: () async {
          if (_selectedBrandId != null) {
            await _fetchMenuForBrand(_selectedBrandId!, forceRefresh: true);
          } else {
            await _fetchBrands(forceRefresh: true);
          }
        },
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: _loading
                ? _buildLoadingState()
                : _error != null
                ? _buildErrorState()
                : (_selectedBrandId == null
                      ? _buildBrandPicker()
                      : Column(
                          children: [
                            _buildHeader(),
                            _buildSearchBar(),
                            Expanded(
                              child: _getFilteredItems().isEmpty
                                  ? _buildEmptyState()
                                  : _buildItemsGrid(),
                            ),
                          ],
                        )),
          ),
        ),
      ),
    );
  }
}
