import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:cross_file/cross_file.dart';
import 'package:restaurantadmin/models/supplier.dart';

// Dark theme palette - user-friendly contrast
const _kDarkBg = Color(0xFF1A1D21);
const _kDarkCard = Color(0xFF25282D);
const _kDarkSurface = Color(0xFF2D3138);
const _kTextPrimary = Color(0xFFE8EAED);
const _kTextSecondary = Color(0xFF9CA3AF);
const _kAccent = Color(0xFF3B82F6);
const _kAccentGreen = Color(0xFF22C55E);
const _kBorder = Color(0xFF3F4448);

/// Unit options for dropdown selection
const _kUnitOptions = ['gram', 'kg', 'liter', 'ml', 'unit', 'box', 'piece', 'bag'];
const _kBaseUnitOptions = ['gram', 'kg', 'liter', 'ml'];
/// VAT rate options (percent)
const _kVatOptions = [10, 20];
/// Virtual category for items without a category
const _kUncategorizedCategoryName = 'Sonstige';

class SupplierDetailScreen extends StatefulWidget {
  final Supplier supplier;

  const SupplierDetailScreen({super.key, required this.supplier});

  @override
  State<SupplierDetailScreen> createState() => _SupplierDetailScreenState();
}

class _SupplierDetailScreenState extends State<SupplierDetailScreen> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  List<Map<String, dynamic>> _purchaseItems = [];
  List<Map<String, dynamic>> _categoryList = [];
  String? _selectedCategory;
  String _searchQuery = '';
  String? _uploadingItemId;
  String? _draggingOverItemId;
  String? _uploadingCategoryId;
  String? _draggingOverCategoryId;

  @override
  void initState() {
    super.initState();
    _loadPurchaseItems();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final resp = await _supabase
          .from('supplier_categories')
          .select('id, name, image_url')
          .eq('supplier_id', widget.supplier.id)
          .order('name');
      if (!mounted) return;
      setState(() {
        _categoryList = (resp as List).cast<Map<String, dynamic>>();
      });
    } catch (e) {
      debugPrint('Load categories: $e');
    }
  }

  List<String> get _categories =>
      _categoryList.map((c) => c['name'] as String).toList();

  /// [showLoading] false = silent refresh (e.g. after image upload) to keep scroll position.
  Future<void> _loadPurchaseItems({bool showLoading = true}) async {
    if (showLoading) setState(() => _loading = true);
    try {
      // Query only columns that exist in the table
      final resp = await _supabase
          .from('purchase_catalog_items')
          .select(
            'id, name, receipt_name, article_number, ean, unit, default_quantity, last_known_price, vat_rate, category, material_id, base_unit, conversion_ratio, notes, image_url, created_at',
          )
          .eq('supplier_id', widget.supplier.id)
          .order('name');

      // Fetch material names separately
      final items = (resp as List).cast<Map<String, dynamic>>();

      for (final item in items) {
        if (item['material_id'] != null) {
          try {
            final material = await _supabase
                .from('material')
                .select('name, unit_of_measure, item_image_url')
                .eq('id', item['material_id'])
                .maybeSingle();
            if (material != null) {
              item['material_name'] = material['name'];
              item['material_unit'] = material['unit_of_measure'];
              item['material_image'] = material['item_image_url'];
            }
          } catch (e) {
            debugPrint('Error fetching material: $e');
          }
        }
      }

      setState(() => _purchaseItems = items);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading items: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted && showLoading) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredItems {
    if (_searchQuery.isEmpty) return _purchaseItems;
    final query = _searchQuery.toLowerCase();
    return _purchaseItems.where((item) {
      final name = (item['name'] as String? ?? '').toLowerCase();
      final receiptName = (item['receipt_name'] as String? ?? '').toLowerCase();
      final materialName = (item['material_name'] as String? ?? '')
          .toLowerCase();
      final articleNumber = (item['article_number'] as String? ?? '').toLowerCase();
      final ean = (item['ean'] as String? ?? '').toLowerCase();
      return name.contains(query) ||
          receiptName.contains(query) ||
          materialName.contains(query) ||
          articleNumber.contains(query) ||
          ean.contains(query);
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredItemsForView {
    final list = _filteredItems;
    if (_selectedCategory == null) return list;
    if (_selectedCategory == _kUncategorizedCategoryName) {
      return list.where((i) {
        final c = i['category'] as String?;
        return c == null || c.isEmpty;
      }).toList();
    }
    return list.where((i) => i['category'] == _selectedCategory).toList();
  }

  List<Map<String, dynamic>> get _displayCategoryList {
    return [
      ..._categoryList,
      {'id': null, 'name': _kUncategorizedCategoryName, 'image_url': null},
    ];
  }

  int _itemCountForCategory(String name) {
    if (name == _kUncategorizedCategoryName) {
      return _purchaseItems.where((i) {
        final c = i['category'] as String?;
        return c == null || c.isEmpty;
      }).length;
    }
    return _purchaseItems.where((i) => i['category'] == name).length;
  }

  int get _linkedCount =>
      _purchaseItems.where((i) => i['material_id'] != null).length;

  bool get _showCategoryDropdown => _categories.isNotEmpty;

  Future<void> _uploadImageForItem(Map<String, dynamic> item, XFile file) async {
    final id = item['id'] as String?;
    if (id == null) return;
    final ext = file.name.split('.').last.toLowerCase();
    if (!['jpg', 'jpeg', 'png', 'webp'].contains(ext)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please drop an image file (jpg, png, webp)'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    setState(() => _uploadingItemId = id);
    try {
      final bytes = await file.readAsBytes();
      final fileName = '${DateTime.now().toIso8601String()}.$ext';
      final filePath = 'purchase_items/$fileName';
      await _supabase.storage.from('purchase_items').uploadBinary(
        filePath,
        bytes,
        fileOptions: FileOptions(contentType: file.mimeType),
      );
      final imageUrl = _supabase.storage.from('purchase_items').getPublicUrl(filePath);
      await _supabase
          .from('purchase_catalog_items')
          .update({'image_url': imageUrl})
          .eq('id', id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image updated'), backgroundColor: Colors.green),
        );
        _loadPurchaseItems(showLoading: false);
      }
    } catch (e) {
      debugPrint('Error uploading image for item: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingItemId = null);
    }
  }

  Future<void> _showBulkAddDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _BulkAddItemsDialog(
        supplierId: widget.supplier.id,
        supplierName: widget.supplier.name,
        supabase: _supabase,
      ),
    );
    if (result == true && mounted) _loadPurchaseItems(showLoading: false);
  }

  Future<void> _editItem(Map<String, dynamic> item) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) =>
          _PurchaseItemEditDialog(supplierId: widget.supplier.id, item: item),
    );
    if (result == true && mounted) {
      _loadPurchaseItems(showLoading: false);
    }
  }

  Future<void> _deleteItem(Map<String, dynamic> item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Are you sure you want to delete "${item['name']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _supabase
          .from('purchase_catalog_items')
          .delete()
          .eq('id', item['id']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Item deleted'),
            backgroundColor: Colors.green,
          ),
        );
        _loadPurchaseItems(showLoading: false);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _addNewItem() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) =>
          _PurchaseItemEditDialog(supplierId: widget.supplier.id, item: null),
    );
    if (result == true && mounted) {
      _loadPurchaseItems(showLoading: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredItemsForView;

    return Scaffold(
      backgroundColor: _kDarkBg,
      appBar: AppBar(
        leading: _selectedCategory != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _selectedCategory = null),
              )
            : null,
        title: Text(_selectedCategory ?? widget.supplier.name),
        backgroundColor: _kDarkCard,
        foregroundColor: _kTextPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.category_outlined),
            onPressed: _loading ? null : _showManageCategoriesDialog,
            tooltip: 'Manage categories',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadPurchaseItems,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.playlist_add),
            onPressed: _loading ? null : _showBulkAddDialog,
            tooltip: 'Bulk add items',
          ),
        ],
      ),
      floatingActionButton: (_categoryList.isEmpty || _selectedCategory != null)
          ? FloatingActionButton.extended(
              onPressed: _addNewItem,
              icon: const Icon(Icons.add),
              label: const Text('Add Item'),
              backgroundColor: _kAccentGreen,
              foregroundColor: Colors.white,
            )
          : null,
      body: _categoryList.isNotEmpty && _selectedCategory == null
          ? _buildCategoryCardsView()
          : Column(
        children: [
          // Compact supplier header card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _kDarkCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kBorder, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _kDarkSurface,
                        borderRadius: BorderRadius.circular(10),
                        image:
                            (widget.supplier.imageUrl != null &&
                                widget.supplier.imageUrl!.isNotEmpty)
                            ? DecorationImage(
                                image: NetworkImage(widget.supplier.imageUrl!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child:
                          (widget.supplier.imageUrl == null ||
                              widget.supplier.imageUrl!.isEmpty)
                          ? Icon(
                              widget.supplier.isOnlineSupplier == true
                                  ? Icons.cloud_done_outlined
                                  : Icons.storefront_outlined,
                              color: _kAccent,
                              size: 22,
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.supplier.name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: _kTextPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Compact stats row - short labels to prevent overflow
                Row(
                  children: [
                    _buildStatChip(
                      '${_purchaseItems.length}',
                      'Items',
                      Icons.inventory_2_outlined,
                    ),
                    const SizedBox(width: 8),
                    _buildStatChip(
                      '$_linkedCount',
                      'Linked',
                      Icons.link,
                    ),
                    const SizedBox(width: 8),
                    _buildStatChip(
                      '${_purchaseItems.length - _linkedCount}',
                      'Unlinked',
                      Icons.link_off,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            child: TextField(
              style: const TextStyle(color: _kTextPrimary),
              decoration: InputDecoration(
                hintText: 'Search items...',
                hintStyle: const TextStyle(color: _kTextSecondary),
                prefixIcon: Icon(Icons.search, size: 20, color: _kTextSecondary),
                filled: true,
                fillColor: _kDarkCard,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _kBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _kBorder),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          const SizedBox(height: 12),

          // Items list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add_circle_outline,
                            size: 56,
                            color: _kAccentGreen,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isEmpty
                                ? 'No items yet'
                                : 'No match for "$_searchQuery"',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: _kTextPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _searchQuery.isEmpty
                                ? 'Tap the green button below to add products'
                                : 'Try a different search',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: _kTextSecondary,
                              fontSize: 14,
                            ),
                          ),
                          if (_searchQuery.isEmpty) ...[
                            const SizedBox(height: 20),
                            FilledButton.icon(
                              onPressed: _addNewItem,
                              icon: const Icon(Icons.add, size: 20),
                              label: const Text('Add Item'),
                              style: FilledButton.styleFrom(
                                backgroundColor: _kAccentGreen,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadPurchaseItems,
                    color: _kAccent,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filtered.length,
                      itemBuilder: (ctx, index) =>
                          _buildItemCard(filtered[index]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCardsView() {
    final displayList = _displayCategoryList;
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 600;
    final crossAxisCount = isDesktop
        ? displayList.length.clamp(2, 20)
        : (width > 400 ? 3 : 2);
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Text(
              'Shop by category',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _kTextPrimary,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.15,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final cat = displayList[index];
                final categoryId = cat['id'] as String?;
                final name = cat['name'] as String? ?? '';
                final imageUrl = cat['image_url'] as String?;
                final itemCount = _itemCountForCategory(name);
                final canDropImage = categoryId != null;
                final isDraggingOver = canDropImage && _draggingOverCategoryId == categoryId;
                final isUploading = canDropImage && _uploadingCategoryId == categoryId;

                Widget cardContent = Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: isUploading ? null : () => setState(() => _selectedCategory = name),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDraggingOver ? const Color(0xFF1E3A2F) : _kDarkCard,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDraggingOver ? _kAccentGreen : _kBorder,
                          width: isDraggingOver ? 2 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
                              child: imageUrl != null && imageUrl.isNotEmpty
                                  ? Image.network(
                                      imageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => _categoryImagePlaceholder(),
                                    )
                                  : _categoryImagePlaceholder(),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    color: _kTextPrimary,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (itemCount > 0)
                                  Text(
                                    '$itemCount item${itemCount == 1 ? '' : 's'}',
                                    style: const TextStyle(
                                      fontSize: 9,
                                      color: _kTextSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );

                if (canDropImage) {
                  cardContent = DropTarget(
                    onDragDone: (detail) {
                      if (detail.files.isNotEmpty) _uploadImageForCategory(categoryId, detail.files.first);
                    },
                    onDragEntered: (_) => setState(() => _draggingOverCategoryId = categoryId),
                    onDragExited: (_) => setState(() => _draggingOverCategoryId = null),
                    child: Stack(
                      children: [
                        cardContent,
                        if (isDraggingOver)
                          Positioned(
                            right: 4,
                            top: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: _kAccentGreen,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('Drop image', style: TextStyle(color: Colors.white, fontSize: 10)),
                            ),
                          ),
                        if (isUploading)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Center(
                                child: SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }

                return cardContent;
              },
              childCount: displayList.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _categoryImagePlaceholder() {
    return Container(
      color: _kDarkSurface,
      child: const Center(
        child: Icon(Icons.category_outlined, size: 28, color: _kTextSecondary),
      ),
    );
  }

  Widget _buildStatChip(String value, String label, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: _kDarkSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _kBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _kAccent, size: 16),
            const SizedBox(width: 6),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      color: _kTextPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    label,
                    style: const TextStyle(
                      color: _kTextSecondary,
                      fontSize: 10,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showManageCategoriesDialog() async {
    final addController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: _kDarkCard,
            title: const Text('Manage categories', style: TextStyle(color: _kTextPrimary)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Add a category for this supplier. Items can then be assigned in the list.',
                    style: TextStyle(color: _kTextSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: addController,
                          style: const TextStyle(color: _kTextPrimary),
                          decoration: InputDecoration(
                            hintText: 'New category name',
                            hintStyle: const TextStyle(color: _kTextSecondary),
                            filled: true,
                            fillColor: _kDarkSurface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: _kBorder),
                            ),
                          ),
                          onSubmitted: (_) async {
                            await _addCategory(addController.text.trim(), setDialogState);
                            addController.clear();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: () async {
                          await _addCategory(addController.text.trim(), setDialogState);
                          addController.clear();
                        },
                        icon: const Icon(Icons.add),
                        style: IconButton.styleFrom(backgroundColor: _kAccentGreen),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text('Categories:', style: TextStyle(color: _kTextSecondary, fontSize: 12)),
                  const SizedBox(height: 8),
                  if (_categoryList.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text('None yet. Add one above.', style: TextStyle(color: _kTextSecondary, fontSize: 13)),
                    )
                  else
                    ..._categoryList.map((cat) {
                      final id = cat['id'] as String?;
                      final name = cat['name'] as String? ?? '';
                      final imageUrl = cat['image_url'] as String?;
                      final isUploading = id != null && _uploadingCategoryId == id;
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 6),
                        leading: GestureDetector(
                          onTap: isUploading ? null : () => _pickCategoryImage(id!, name, setDialogState),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: _kDarkSurface,
                                  borderRadius: BorderRadius.circular(8),
                                  image: (imageUrl != null && imageUrl.isNotEmpty)
                                      ? DecorationImage(
                                          image: NetworkImage(imageUrl),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: (imageUrl == null || imageUrl.isEmpty)
                                    ? const Icon(Icons.add_photo_alternate, color: _kTextSecondary)
                                    : null,
                              ),
                              if (isUploading)
                                const Positioned.fill(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(color: Colors.black54),
                                    child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        title: Text(name, style: const TextStyle(color: _kTextPrimary)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                          onPressed: () => _deleteCategory(name, setDialogState),
                        ),
                      );
                    }),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Done'),
              ),
            ],
          );
        },
      ),
    );
    addController.dispose();
  }

  Future<void> _addCategory(String name, void Function(void Function()) setDialogState) async {
    if (name.isEmpty) return;
    try {
      await _supabase.from('supplier_categories').insert({
        'supplier_id': widget.supplier.id,
        'name': name,
      });
      await _loadCategories();
      if (!mounted) return;
      setDialogState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add category: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _uploadImageForCategory(String categoryId, XFile file) async {
    final ext = file.name.split('.').last.toLowerCase();
    if (!['jpg', 'jpeg', 'png', 'webp'].contains(ext)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Use jpg, png or webp'), backgroundColor: Colors.red),
        );
      }
      return;
    }
    setState(() => _uploadingCategoryId = categoryId);
    try {
      final bytes = await file.readAsBytes();
      final path = 'category_images/${widget.supplier.id}/$categoryId.jpg';
      await _supabase.storage.from('purchase_items').uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(contentType: 'image/jpeg', upsert: true),
      );
      final imageUrl = _supabase.storage.from('purchase_items').getPublicUrl(path);
      await _supabase.from('supplier_categories').update({'image_url': imageUrl}).eq('id', categoryId);
      await _loadCategories();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Category image updated'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingCategoryId = null);
    }
  }

  Future<void> _pickCategoryImage(String categoryId, String categoryName, void Function(void Function()) setDialogState) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null || !mounted) return;
    await _uploadImageForCategory(categoryId, picked);
    if (mounted) setDialogState(() {});
  }

  Future<void> _deleteCategory(String name, void Function(void Function()) setDialogState) async {
    try {
      await _supabase.from('supplier_categories').delete().eq('supplier_id', widget.supplier.id).eq('name', name);
      await _supabase.from('purchase_catalog_items').update({'category': null}).eq('supplier_id', widget.supplier.id).eq('category', name);
      await _loadCategories();
      await _loadPurchaseItems();
      if (!mounted) return;
      setDialogState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete category: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _updateItemCategory(Map<String, dynamic> item, String? category) async {
    final id = item['id'] as String?;
    if (id == null) return;
    try {
      await _supabase
          .from('purchase_catalog_items')
          .update({'category': category}).eq('id', id);
      if (!mounted) return;
      setState(() {
        final i = _purchaseItems.indexWhere((e) => (e['id'] as String?) == id);
        if (i >= 0) _purchaseItems[i]['category'] = category;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update category: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildCategoryDropdown(Map<String, dynamic> item) {
    final current = item['category'] as String?;
    final value = (current != null && _categories.contains(current))
        ? current
        : null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: 'Category',
          labelStyle: const TextStyle(color: _kTextSecondary, fontSize: 11),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          filled: true,
          fillColor: _kDarkSurface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _kBorder),
          ),
        ),
        dropdownColor: _kDarkCard,
        style: const TextStyle(color: _kTextPrimary, fontSize: 13),
        hint: const Text('Choose category', style: TextStyle(color: _kTextSecondary, fontSize: 12)),
        items: _categories
            .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13))))
            .toList(),
        onChanged: (v) => _updateItemCategory(item, v),
      ),
    );
  }

  /// Article number row with optional copy button (Metro: copy without decimal).
  Widget _buildArticleNumberRow(Map<String, dynamic> item) {
    final raw = item['article_number'];
    final display = raw?.toString().trim() ?? '';
    if (display.isEmpty) return const SizedBox.shrink();
    final isMetro = widget.supplier.name.toLowerCase().contains('metro');
    // For Metro, value to copy: remove decimal if it's a whole number (e.g. 72616.0 -> 72616).
    String copyValue = display;
    if (isMetro) {
      final n = num.tryParse(display);
      if (n != null && n == n.toInt()) copyValue = n.toInt().toString();
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Art. #$display',
          style: const TextStyle(
            color: _kTextSecondary,
            fontSize: 12,
          ),
        ),
        if (isMetro) ...[
          const SizedBox(width: 6),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            iconSize: 18,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: copyValue));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Copied: $copyValue'),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.copy, color: _kTextSecondary),
            tooltip: 'Copy article number',
          ),
        ],
      ],
    );
  }

  /// Right-side block on item card: price and price per unit.
  Widget _buildItemCardPriceBlock(Map<String, dynamic> item) {
    final priceVal = item['last_known_price'];
    final price = priceVal is num ? priceVal.toDouble() : double.tryParse(priceVal?.toString() ?? '');
    final qtyVal = item['default_quantity'];
    final qty = qtyVal is num ? qtyVal.toDouble() : double.tryParse(qtyVal?.toString() ?? '');
    final unit = item['unit'] as String? ?? 'unit';

    final String priceText = (price != null && !price.isNaN)
        ? '€${price.toStringAsFixed(2)}'
        : '—';

    String perUnitText = '—';
    if (price != null && !price.isNaN && qty != null && qty > 0) {
      final costPerUnit = price / qty;
      if (costPerUnit < 1 && costPerUnit > 0) {
        final cents = costPerUnit * 100;
        final centsStr = cents >= 1 && cents == cents.roundToDouble()
            ? '${cents.toInt()}'
            : cents.toStringAsFixed(3);
        perUnitText = '$centsStr cent${cents.toInt() == 1 ? '' : 's'} per $unit';
      } else {
        perUnitText = '€${costPerUnit.toStringAsFixed(2)} per $unit';
      }
    }

    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            priceText,
            style: const TextStyle(
              color: _kTextPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            perUnitText,
            style: const TextStyle(
              color: _kTextSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    final isLinked = item['material_id'] != null;
    final materialName = item['material_name'] as String?;
    final conversionRatio = item['conversion_ratio'] as num?;
    final baseUnit = item['base_unit'] as String?;
    final materialImage = item['material_image'] as String?;
    final itemImage = item['image_url'] as String?;
    final displayImage = (itemImage != null && itemImage.isNotEmpty) ? itemImage : materialImage;
    final itemId = item['id'] as String?;
    final isUploading = itemId != null && _uploadingItemId == itemId;
    final isDraggingOver = itemId != null && _draggingOverItemId == itemId;

    return DropTarget(
      onDragDone: (detail) {
        if (detail.files.isNotEmpty) _uploadImageForItem(item, detail.files.first);
      },
      onDragEntered: (_) => setState(() => _draggingOverItemId = itemId),
      onDragExited: (_) => setState(() => _draggingOverItemId = null),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        elevation: 0,
        color: isDraggingOver ? const Color(0xFF1E3A2F) : _kDarkCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: isDraggingOver ? _kAccentGreen : _kBorder,
            width: isDraggingOver ? 2 : 1,
          ),
        ),
        child: Stack(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: isUploading ? null : () => _editItem(item),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Item icon or material image – full height of tile, square (width = height)
                        AspectRatio(
                          aspectRatio: 1,
                          child: Container(
                            decoration: BoxDecoration(
                              color: isLinked ? const Color(0xFF1E3A2F) : _kDarkSurface,
                              borderRadius: BorderRadius.circular(10),
                              image: (displayImage != null && displayImage.isNotEmpty)
                                  ? DecorationImage(
                                      image: NetworkImage(displayImage),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: (displayImage == null || displayImage.isEmpty)
                                ? Center(
                                    child: Icon(
                                      isLinked
                                          ? Icons.check_circle_outline
                                          : Icons.help_outline,
                                      color: isLinked
                                          ? _kAccentGreen
                                          : _kTextSecondary,
                                      size: 28,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['name'] as String? ?? 'Unknown',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: _kTextPrimary,
                          ),
                        ),
                        if (item['receipt_name'] != null &&
                            item['receipt_name'] != item['name'])
                          Text(
                            'Receipt: ${item['receipt_name']}',
                            style: const TextStyle(
                              color: _kTextSecondary,
                              fontSize: 12,
                            ),
                          ),
                        if (item['article_number'] != null &&
                            (item['article_number'] as String).isNotEmpty)
                          _buildArticleNumberRow(item),
                        if (item['ean'] != null &&
                            (item['ean'] as String).isNotEmpty)
                          Text(
                            'EAN: ${item['ean']}',
                            style: const TextStyle(
                              color: _kTextSecondary,
                              fontSize: 12,
                            ),
                          ),
                        const SizedBox(height: 6),
                        // Link status
                        if (isLinked)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E3A2F),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFF166534)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.link,
                                  size: 14,
                                  color: _kAccentGreen,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  materialName ?? 'Linked',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _kAccentGreen,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF422006),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFB45309)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.link_off,
                                  size: 14,
                                  color: Colors.orange[400],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Not linked',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.orange[400],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        // Category dropdown (e.g. for Metro) – tap doesn't open edit
                        if (_showCategoryDropdown) ...[
                          const SizedBox(height: 10),
                          _buildCategoryDropdown(item),
                        ],
                      ],
                    ),
                  ),
                  _buildItemCardPriceBlock(item),
                  // Action buttons
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: _kTextSecondary),
                    onSelected: (value) {
                      if (value == 'edit') {
                        _editItem(item);
                      } else if (value == 'delete') {
                        _deleteItem(item);
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
              // Conversion info
              if (isLinked && conversionRatio != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A3A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF2D5A5A)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.swap_horiz,
                        size: 18,
                        color: const Color(0xFF5D9B9B),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${conversionRatio.toString().replaceAll(RegExp(r"([.]*0)(?!.*\d)"), "")} ${baseUnit ?? ''}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: _kTextPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      if (materialName != null)
                        Text(
                          materialName,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF5D9B9B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      if (materialImage != null && materialImage.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            image: DecorationImage(
                              image: NetworkImage(materialImage),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              // Notes
              if (item['notes'] != null &&
                  (item['notes'] as String).isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  item['notes'] as String,
                  style: const TextStyle(
                    fontSize: 12,
                    color: _kTextSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
                ],
              ),
            ),
          ),
          if (isUploading)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                alignment: Alignment.center,
                child: const CircularProgressIndicator(color: Colors.white),
              ),
            ),
          if (isDraggingOver)
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _kAccentGreen,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Drop image', style: TextStyle(color: Colors.white, fontSize: 11)),
              ),
            ),
        ],
      ),
    ),
    );
  }
}

/// One row in the bulk add form.
class _BulkAddRow {
  final TextEditingController name = TextEditingController();
  final TextEditingController articleNumber = TextEditingController();
  final TextEditingController price = TextEditingController();
  final TextEditingController receiptName = TextEditingController();
  final TextEditingController ean = TextEditingController();
  final TextEditingController defaultQty = TextEditingController();
  final TextEditingController notes = TextEditingController();
  String? selectedUnit;
  int? selectedVat; // 10 or 20
  void dispose() {
    name.dispose();
    articleNumber.dispose();
    price.dispose();
    receiptName.dispose();
    ean.dispose();
    defaultQty.dispose();
    notes.dispose();
  }
}

/// Bulk add purchase items with list tiles and text fields per item.
class _BulkAddItemsDialog extends StatefulWidget {
  final String supplierId;
  final String supplierName;
  final SupabaseClient supabase;

  const _BulkAddItemsDialog({
    required this.supplierId,
    required this.supplierName,
    required this.supabase,
  });

  @override
  State<_BulkAddItemsDialog> createState() => _BulkAddItemsDialogState();
}

class _BulkAddItemsDialogState extends State<_BulkAddItemsDialog> {
  bool _adding = false;
  final List<_BulkAddRow> _rows = [];

  @override
  void initState() {
    super.initState();
    _addRow();
    _addRow();
    _addRow();
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  void _addRow() {
    final row = _BulkAddRow();
    row.price.addListener(() => setState(() {}));
    row.defaultQty.addListener(() => setState(() {}));
    setState(() => _rows.add(row));
  }

  void _addRows(int count) {
    for (int i = 0; i < count; i++) {
      final row = _BulkAddRow();
      row.price.addListener(() => setState(() {}));
      row.defaultQty.addListener(() => setState(() {}));
      _rows.add(row);
    }
    setState(() {});
  }

  void _removeRow(int index) {
    if (_rows.length <= 1) return;
    _rows[index].dispose();
    setState(() => _rows.removeAt(index));
  }

  static InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _kTextSecondary, fontSize: 12),
      filled: true,
      fillColor: _kDarkSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _kBorder),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    );
  }

  /// Read-only: Price after VAT = price * (1 + vat/100).
  Widget _buildBulkRowPriceAfterVat(_BulkAddRow row) {
    final price = double.tryParse(row.price.text.replaceAll(',', '.'));
    final vat = row.selectedVat;
    if (price == null || price <= 0 || vat == null) {
      return _readOnlyBox('Price after VAT: —', isFilled: false);
    }
    final afterVat = price * (1 + vat / 100);
    return _readOnlyBox('Price after VAT: €${afterVat.toStringAsFixed(2)}', isFilled: true);
  }

  /// Read-only: Price per unit = price / default qty (e.g. €0.01 per gram).
  Widget _buildBulkRowPricePerUnit(_BulkAddRow row) {
    final price = double.tryParse(row.price.text.replaceAll(',', '.'));
    final qty = double.tryParse(row.defaultQty.text.replaceAll(',', '.'));
    final unit = row.selectedUnit ?? 'unit';
    if (price == null || qty == null || qty <= 0) {
      return _readOnlyBox('Price per unit: —', isFilled: false);
    }
    final costPerUnit = price / qty;
    final String text;
    if (costPerUnit < 1 && costPerUnit > 0) {
      final cents = (costPerUnit * 100);
      final centsStr = cents >= 1 && cents == cents.roundToDouble()
          ? '${cents.toInt()}'
          : cents.toStringAsFixed(3);
      text = 'Price per unit: $centsStr cent${cents.toInt() == 1 ? '' : 's'} per $unit';
    } else {
      text = 'Price per unit: €${costPerUnit.toStringAsFixed(2)} per $unit';
    }
    return _readOnlyBox(text, isFilled: true, icon: Icons.straighten);
  }

  Widget _readOnlyBox(String text, {required bool isFilled, IconData icon = Icons.receipt_long}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isFilled ? const Color(0xFF1E3A2F) : _kDarkSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isFilled ? const Color(0xFF2D5A5A) : _kBorder),
      ),
      child: Row(
        children: [
          Icon(
            isFilled ? icon : Icons.calculate,
            size: 18,
            color: isFilled ? _kAccentGreen : _kTextSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: isFilled ? _kTextPrimary : _kTextSecondary,
                fontSize: 13,
                fontWeight: isFilled ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addAll() async {
    setState(() => _adding = true);
    int added = 0;
    int skipped = 0;
    try {
      for (final row in _rows) {
        final name = row.name.text.trim();
        final articleNumber = row.articleNumber.text.trim();
        final priceVal = double.tryParse(row.price.text.replaceAll(',', '.').trim());
        if (name.isEmpty && articleNumber.isEmpty) continue;
        final finalName = name.isEmpty ? 'Unnamed' : name;
        if (articleNumber.isNotEmpty) {
          final existing = await widget.supabase
              .from('purchase_catalog_items')
              .select('id')
              .eq('supplier_id', widget.supplierId)
              .eq('article_number', articleNumber)
              .maybeSingle();
          if (existing != null) {
            skipped++;
            continue;
          }
        }
        final receiptName = row.receiptName.text.trim();
        final ean = row.ean.text.trim();
        final defaultQtyVal = double.tryParse(row.defaultQty.text.replaceAll(',', '.').trim());
        await widget.supabase.from('purchase_catalog_items').insert({
          'supplier_id': widget.supplierId,
          'name': finalName,
          'receipt_name': receiptName.isEmpty ? null : receiptName,
          'article_number': articleNumber.isEmpty ? null : articleNumber,
          'ean': ean.isEmpty ? null : ean,
          'unit': row.selectedUnit,
          'default_quantity': (defaultQtyVal != null && !defaultQtyVal.isNaN) ? defaultQtyVal : null,
          'last_known_price': (priceVal != null && !priceVal.isNaN) ? priceVal : null,
          'vat_rate': row.selectedVat,
          'notes': row.notes.text.trim().isEmpty ? null : row.notes.text.trim(),
        });
        added++;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added $added item(s)${skipped > 0 ? ", $skipped duplicate(s) skipped" : ""}.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _kDarkCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 560,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.playlist_add, color: _kAccentGreen),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Bulk add items — ${widget.supplierName}',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: _kTextPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: _kTextSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _rows.length + 1,
                itemBuilder: (context, index) {
                  if (index == _rows.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 16),
                      child: Row(
                        children: [
                          TextButton.icon(
                            onPressed: _adding ? null : _addRow,
                            icon: const Icon(Icons.add_circle_outline, size: 20),
                            label: const Text('Add row'),
                            style: TextButton.styleFrom(foregroundColor: _kAccentGreen),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: _adding ? null : () => _addRows(10),
                            icon: const Icon(Icons.add_circle_outline, size: 18),
                            label: const Text('Add 10 rows'),
                            style: TextButton.styleFrom(foregroundColor: _kAccentGreen),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: _adding ? null : () => _addRows(50),
                            icon: const Icon(Icons.add_circle_outline, size: 18),
                            label: const Text('Add 50 rows'),
                            style: TextButton.styleFrom(foregroundColor: _kAccentGreen),
                          ),
                        ],
                      ),
                    );
                  }
                  final row = _rows[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    color: _kDarkSurface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: _kBorder),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Item ${index + 1}',
                                style: const TextStyle(
                                  color: _kTextSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              if (_rows.length > 1)
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                                  onPressed: _adding ? null : () => _removeRow(index),
                                  tooltip: 'Remove row',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: row.name,
                            style: const TextStyle(color: _kTextPrimary, fontSize: 14),
                            decoration: _decoration('Name'),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: row.articleNumber,
                                  style: const TextStyle(color: _kTextPrimary, fontSize: 14),
                                  decoration: _decoration('Art. number'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: row.price,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  style: const TextStyle(color: _kTextPrimary, fontSize: 14),
                                  decoration: _decoration('Price (€)'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: row.receiptName,
                            style: const TextStyle(color: _kTextPrimary, fontSize: 13),
                            decoration: _decoration('Receipt name'),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: row.ean,
                            style: const TextStyle(color: _kTextPrimary, fontSize: 13),
                            decoration: _decoration('EAN (Optional)'),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: row.selectedUnit != null && _kUnitOptions.contains(row.selectedUnit) ? row.selectedUnit : null,
                                  decoration: _decoration('Unit'),
                                  dropdownColor: _kDarkCard,
                                  style: const TextStyle(color: _kTextPrimary, fontSize: 13),
                                  hint: const Text('Unit', style: TextStyle(color: _kTextSecondary, fontSize: 12)),
                                  items: _kUnitOptions.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                                  onChanged: (v) => setState(() => row.selectedUnit = v),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: row.defaultQty,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  style: const TextStyle(color: _kTextPrimary, fontSize: 13),
                                  decoration: _decoration('Default qty'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<int?>(
                            value: row.selectedVat != null && _kVatOptions.contains(row.selectedVat) ? row.selectedVat : null,
                            decoration: _decoration('VAT'),
                            dropdownColor: _kDarkCard,
                            style: const TextStyle(color: _kTextPrimary, fontSize: 13),
                            hint: const Text('VAT', style: TextStyle(color: _kTextSecondary, fontSize: 12)),
                            items: [
                              const DropdownMenuItem<int?>(value: null, child: Text('—')),
                              ..._kVatOptions.map((v) => DropdownMenuItem<int?>(value: v, child: Text('$v%'))),
                            ],
                            onChanged: (v) => setState(() => row.selectedVat = v),
                          ),
                          const SizedBox(height: 8),
                          _buildBulkRowPriceAfterVat(row),
                          const SizedBox(height: 8),
                          _buildBulkRowPricePerUnit(row),
                          const SizedBox(height: 8),
                          TextField(
                            controller: row.notes,
                            maxLines: 2,
                            style: const TextStyle(color: _kTextPrimary, fontSize: 13),
                            decoration: _decoration('Notes'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: _kBorder)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _adding ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _adding ? null : _addAll,
                    icon: _adding
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.add_circle),
                    label: Text(_adding ? 'Adding...' : 'Add all'),
                    style: FilledButton.styleFrom(backgroundColor: _kAccentGreen),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog for editing/creating purchase items
class _PurchaseItemEditDialog extends StatefulWidget {
  final String supplierId;
  final Map<String, dynamic>? item;

  const _PurchaseItemEditDialog({required this.supplierId, this.item});

  @override
  State<_PurchaseItemEditDialog> createState() =>
      _PurchaseItemEditDialogState();
}

class _PurchaseItemEditDialogState extends State<_PurchaseItemEditDialog> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _receiptNameCtrl = TextEditingController();
  final _articleNumberCtrl = TextEditingController();
  final _eanCtrl = TextEditingController();
  final _defaultQtyCtrl = TextEditingController();
  final _lastKnownPriceCtrl = TextEditingController();
  final _conversionCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String? _materialId;
  String? _materialName;
  String? _materialImage;
  String? _baseUnit;
  String? _selectedUnit;
  int? _selectedVat; // 10 or 20 (percent)
  String? _existingImageUrl;
  XFile? _pickedImage;
  bool _saving = false;
  bool _uploadingImage = false;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _lastKnownPriceCtrl.addListener(() => setState(() {}));
    _defaultQtyCtrl.addListener(() => setState(() {}));
    final item = widget.item;
    if (item != null) {
      _nameCtrl.text = item['name'] as String? ?? '';
      _receiptNameCtrl.text = item['receipt_name'] as String? ?? '';
      _articleNumberCtrl.text = item['article_number'] as String? ?? '';
      _eanCtrl.text = item['ean'] as String? ?? '';
      _existingImageUrl = item['image_url'] as String?;
      final unit = item['unit'] as String?;
      _selectedUnit =
          unit != null && _kUnitOptions.contains(unit) ? unit : null;
      _defaultQtyCtrl.text = (item['default_quantity']?.toString() ?? '');
      _lastKnownPriceCtrl.text = (item['last_known_price']?.toString() ?? '');
      final vat = item['vat_rate'];
      if (vat != null) {
        final vatInt = vat is int ? vat : (vat is num ? vat.toInt() : null);
        _selectedVat = (vatInt != null && _kVatOptions.contains(vatInt)) ? vatInt : null;
      } else {
        _selectedVat = null;
      }
      _materialId = item['material_id'] as String?;
      _materialName = item['material_name'] as String?;
      _materialImage = item['material_image'] as String?;
      _baseUnit = item['base_unit'] as String?;
      if (_baseUnit != null && !_kBaseUnitOptions.contains(_baseUnit)) {
        _baseUnit = _kBaseUnitOptions.first;
      }
      if (_materialId != null && _baseUnit == null) {
        _baseUnit = _kBaseUnitOptions.first;
      }
      _conversionCtrl.text = (item['conversion_ratio']?.toString() ?? '');
      _notesCtrl.text = item['notes'] as String? ?? '';
    }
  }

  Future<void> _pickMaterial() async {
    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (ctx) => _MaterialPickerDialog(
        initialQuery: _nameCtrl.text.isNotEmpty
            ? _nameCtrl.text
            : _receiptNameCtrl.text,
      ),
    );
    if (result != null) {
      setState(() {
        _materialId = result['id'] as String?;
        _materialName = result['name'] as String?;
        _materialImage = result['item_image_url'] as String?;
        final u = result['unit_of_measure'] as String?;
        _baseUnit = u != null && _kBaseUnitOptions.contains(u)
            ? u
            : (u?.isNotEmpty == true ? u : _kBaseUnitOptions.first);
      });
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _pickedImage = image;
      });
    }
  }

  Future<String?> _uploadImage() async {
    if (_pickedImage == null) return _existingImageUrl;
    setState(() => _uploadingImage = true);
    try {
      final bytes = await _pickedImage!.readAsBytes();
      final fileExt = _pickedImage!.name.split('.').last;
      final fileName = '${DateTime.now().toIso8601String()}.$fileExt';
      final filePath = 'purchase_items/$fileName';
      
      await _supabase.storage.from('purchase_items').uploadBinary(
            filePath,
            bytes,
            fileOptions: FileOptions(contentType: _pickedImage!.mimeType),
          );
      
      final imageUrl = _supabase.storage.from('purchase_items').getPublicUrl(filePath);
      return imageUrl;
    } catch (e) {
      debugPrint('Error uploading image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading image: $e'), backgroundColor: Colors.red),
        );
      }
      return null;
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final imageUrl = await _uploadImage();

      // Only include columns that exist in the table
      final payload = {
        'supplier_id': widget.supplierId,
        'name': _nameCtrl.text.trim(),
        'receipt_name': _receiptNameCtrl.text.trim().isNotEmpty
            ? _receiptNameCtrl.text.trim()
            : null,
        'article_number': _articleNumberCtrl.text.trim().isNotEmpty
            ? _articleNumberCtrl.text.trim()
            : null,
        'ean': _eanCtrl.text.trim().isNotEmpty ? _eanCtrl.text.trim() : null,
        'image_url': imageUrl,
        'unit': _selectedUnit,
        'default_quantity': double.tryParse(
          _defaultQtyCtrl.text.replaceAll(',', '.'),
        ),
        'last_known_price': double.tryParse(
          _lastKnownPriceCtrl.text.replaceAll(',', '.'),
        ),
        'vat_rate': _selectedVat,
        'material_id': _materialId,
        'base_unit': _baseUnit,
        'conversion_ratio': double.tryParse(
          _conversionCtrl.text.replaceAll(',', '.'),
        ),
        'notes': _notesCtrl.text.trim().isNotEmpty
            ? _notesCtrl.text.trim()
            : null,
      };

      if (widget.item == null) {
        final articleNumber = _articleNumberCtrl.text.trim();
        if (articleNumber.isNotEmpty) {
          final existing = await _supabase
              .from('purchase_catalog_items')
              .select('id')
              .eq('supplier_id', widget.supplierId)
              .eq('article_number', articleNumber)
              .maybeSingle();
          if (existing != null) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Article number "$articleNumber" already exists for this supplier.'),
                backgroundColor: Colors.red,
              ),
            );
            setState(() => _saving = false);
            return;
          }
        }
        await _supabase.from('purchase_catalog_items').insert(payload);
      } else {
        await _supabase
            .from('purchase_catalog_items')
            .update(payload)
            .eq('id', widget.item!['id']);
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static InputDecoration _darkInputDecoration(String label, {String? hint, IconData? icon}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: _kTextSecondary),
      hintStyle: const TextStyle(color: _kTextSecondary),
      prefixIcon: icon != null ? Icon(icon, color: _kTextSecondary, size: 20) : null,
      filled: true,
      fillColor: _kDarkSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _kBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _kBorder),
      ),
    );
  }

  /// Cost per unit = last_known_price / default_quantity. Display e.g. "1 cent per gram" or "€1.50 per kg".
  Widget _buildCostPerUnit() {
    final price = double.tryParse(_lastKnownPriceCtrl.text.replaceAll(',', '.'));
    final qty = double.tryParse(_defaultQtyCtrl.text.replaceAll(',', '.'));
    final unit = _selectedUnit ?? 'unit';
    if (price == null || qty == null || qty <= 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _kDarkSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kBorder),
        ),
        child: Row(
          children: [
            Icon(Icons.calculate, size: 20, color: _kTextSecondary),
            const SizedBox(width: 10),
            Text(
              'Cost per unit: —',
              style: const TextStyle(color: _kTextSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }
    final costPerUnit = price / qty;
    final String costText;
      if (costPerUnit < 1 && costPerUnit > 0) {
        final cents = (costPerUnit * 100);
        final centsStr = cents >= 1 && cents == cents.roundToDouble()
            ? '${cents.toInt()}'
            : cents.toStringAsFixed(3);
        costText = '$centsStr cent${cents.toInt() == 1 ? '' : 's'} per $unit';
    } else {
      costText = '€${costPerUnit.toStringAsFixed(2)} per $unit';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A2F),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2D5A5A)),
      ),
      child: Row(
        children: [
          Icon(Icons.calculate, size: 20, color: _kAccentGreen),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Cost per unit: $costText',
              style: const TextStyle(
                color: _kTextPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Price after VAT = last_known_price * (1 + vat_rate/100). Shown below VAT dropdown.
  Widget _buildPriceAfterVat() {
    final price = double.tryParse(_lastKnownPriceCtrl.text.replaceAll(',', '.'));
    final vat = _selectedVat;
    if (price == null || price <= 0 || vat == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _kDarkSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kBorder),
        ),
        child: Row(
          children: [
            Icon(Icons.receipt_long, size: 20, color: _kTextSecondary),
            const SizedBox(width: 10),
            Text(
              'Price after VAT: —',
              style: const TextStyle(color: _kTextSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }
    final priceAfterVat = price * (1 + vat / 100);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A2F),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2D5A5A)),
      ),
      child: Row(
        children: [
          Icon(Icons.receipt_long, size: 20, color: _kAccentGreen),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Price after VAT: €${priceAfterVat.toStringAsFixed(2)}',
              style: const TextStyle(
                color: _kTextPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _kDarkCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header - dark theme
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A2F),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                border: const Border(
                  bottom: BorderSide(color: _kBorder),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.inventory_2, color: _kAccentGreen, size: 22),
                  const SizedBox(width: 12),
                  Text(
                    widget.item == null
                        ? 'Add Purchase Item'
                        : 'Edit Purchase Item',
                    style: const TextStyle(
                      color: _kTextPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: _kTextSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Form
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image Picker with Drag & Drop
                      Center(
                        child: DropTarget(
                          onDragDone: (detail) {
                            if (detail.files.isNotEmpty) {
                              final file = detail.files.first;
                              final ext = file.name.split('.').last.toLowerCase();
                              if (['jpg', 'jpeg', 'png', 'webp'].contains(ext)) {
                                setState(() {
                                  _pickedImage = file;
                                });
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please drop an image file (jpg, png, webp)'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          onDragEntered: (detail) {
                            setState(() => _isDragging = true);
                          },
                          onDragExited: (detail) {
                            setState(() => _isDragging = false);
                          },
                          child: GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: _isDragging 
                                    ? _kAccentGreen.withOpacity(0.1) 
                                    : _kDarkSurface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _isDragging ? _kAccentGreen : _kBorder,
                                  width: _isDragging ? 2 : 1,
                                ),
                              ),
                              child: _pickedImage != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: kIsWeb
                                          ? Image.network(
                                              _pickedImage!.path,
                                              fit: BoxFit.cover,
                                              width: 100,
                                              height: 100,
                                            )
                                          : Image.file(
                                              File(_pickedImage!.path),
                                              fit: BoxFit.cover,
                                              width: 100,
                                              height: 100,
                                            ),
                                    )
                                  : (_existingImageUrl != null
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: Image.network(
                                            _existingImageUrl!,
                                            fit: BoxFit.cover,
                                            width: 100,
                                            height: 100,
                                          ),
                                        )
                                      : Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.add_a_photo,
                                              color: _isDragging ? _kAccentGreen : _kTextSecondary,
                                              size: 32,
                                            ),
                                            if (_isDragging)
                                              const Padding(
                                                padding: EdgeInsets.only(top: 4),
                                                child: Text(
                                                  'Drop Here',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: _kAccentGreen,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        )),
                            ),
                          ),
                        ),
                      ),
                      if (_pickedImage != null || _existingImageUrl != null)
                        Center(
                          child: TextButton(
                            onPressed: () => setState(() {
                              _pickedImage = null;
                              _existingImageUrl = null;
                            }),
                            child: const Text('Remove Image', style: TextStyle(color: Colors.red)),
                          ),
                        ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameCtrl,
                        style: const TextStyle(color: _kTextPrimary),
                        decoration: _darkInputDecoration('Name *', icon: Icons.label_outline),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _receiptNameCtrl,
                        style: const TextStyle(color: _kTextPrimary),
                        decoration: _darkInputDecoration(
                          'Receipt Name (as seen on receipt)',
                          icon: Icons.receipt_long_outlined,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _articleNumberCtrl,
                        style: const TextStyle(color: _kTextPrimary),
                        decoration: _darkInputDecoration(
                          'Article Number',
                          hint: 'e.g., 12345',
                          icon: Icons.numbers,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _eanCtrl,
                        style: const TextStyle(color: _kTextPrimary),
                        decoration: _darkInputDecoration(
                          'EAN (Optional)',
                          hint: 'e.g., 4001234567890',
                          icon: Icons.qr_code,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedUnit,
                              hint: const Text(
                                'Select unit',
                                style: TextStyle(color: _kTextSecondary),
                              ),
                              decoration: _darkInputDecoration('Unit'),
                              dropdownColor: _kDarkCard,
                              style: const TextStyle(color: _kTextPrimary),
                              items: _kUnitOptions
                                  .map((u) => DropdownMenuItem(
                                        value: u,
                                        child: Text(u),
                                      ))
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _selectedUnit = v),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _defaultQtyCtrl,
                              style: const TextStyle(color: _kTextPrimary),
                              keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true),
                              decoration: _darkInputDecoration('Default Qty'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _lastKnownPriceCtrl,
                        style: const TextStyle(color: _kTextPrimary),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: _darkInputDecoration(
                          'Last known price (€)',
                          hint: 'e.g. 4.00',
                          icon: Icons.euro,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildCostPerUnit(),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int?>(
                        value: _selectedVat,
                        decoration: _darkInputDecoration('VAT', icon: Icons.percent),
                        dropdownColor: _kDarkCard,
                        style: const TextStyle(color: _kTextPrimary),
                        hint: const Text('Select VAT', style: TextStyle(color: _kTextSecondary)),
                        items: [
                          const DropdownMenuItem<int?>(value: null, child: Text('—')),
                          ..._kVatOptions.map((v) => DropdownMenuItem<int?>(value: v, child: Text('$v%'))),
                        ],
                        onChanged: (v) => setState(() => _selectedVat = v),
                      ),
                      const SizedBox(height: 12),
                      _buildPriceAfterVat(),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _materialId != null
                              ? const Color(0xFF1E3A2F)
                              : _kDarkSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _materialId != null
                                ? _kAccentGreen
                                : _kBorder,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _materialId != null ? Icons.check_circle : Icons.link,
                                  color: _materialId != null ? _kAccentGreen : _kTextSecondary,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Material Link',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _materialId != null ? _kAccentGreen : _kTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                if (_materialImage != null && _materialImage!.isNotEmpty) ...[
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(6),
                                      image: DecorationImage(
                                        image: NetworkImage(_materialImage!),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                                Expanded(
                                  child: Text(
                                    _materialName ?? 'Not linked',
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: _materialId != null ? _kTextPrimary : _kTextSecondary,
                                    ),
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: _pickMaterial,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _kAccent,
                                    foregroundColor: Colors.white,
                                  ),
                                  icon: const Icon(Icons.search, size: 18),
                                  label: Text(_materialId != null ? 'Change' : 'Link'),
                                ),
                                if (_materialId != null) ...[
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.clear, color: _kTextSecondary),
                                    onPressed: () => setState(() {
                                      _materialId = null;
                                      _materialName = null;
                                      _materialImage = null;
                                      _baseUnit = null;
                                    }),
                                    tooltip: 'Remove link',
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _notesCtrl,
                        style: const TextStyle(color: _kTextPrimary),
                        maxLines: 3,
                        decoration: _darkInputDecoration('Notes').copyWith(alignLabelWithHint: true),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: _kDarkSurface,
                border: Border(top: BorderSide(color: _kBorder)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(color: _kTextSecondary)),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(backgroundColor: _kAccent),
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save, size: 20),
                    label: Text(_saving ? 'Saving...' : 'Save'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog for picking a material
class _MaterialPickerDialog extends StatefulWidget {
  final String initialQuery;
  const _MaterialPickerDialog({required this.initialQuery});

  @override
  State<_MaterialPickerDialog> createState() => _MaterialPickerDialogState();
}

class _MaterialPickerDialogState extends State<_MaterialPickerDialog> {
  final _supabase = Supabase.instance.client;
  final _controller = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialQuery;
    _search();
  }

  Future<void> _search() async {
    setState(() => _loading = true);
    try {
      final q = _controller.text.trim();
      final resp = q.isEmpty
          ? await _supabase
              .from('material')
              .select('id, name, unit_of_measure, item_image_url, category')
              .order('name', ascending: true)
              .limit(50)
          : await _supabase
              .from('material')
              .select('id, name, unit_of_measure, item_image_url, category')
              .ilike('name', '%$q%')
              .order('name', ascending: true)
              .limit(50);
      if (mounted) {
        setState(() => _results = (resp as List).cast<Map<String, dynamic>>());
      }
    } catch (e) {
      debugPrint('Search error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _kDarkCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        height: 500,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Material',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _kTextPrimary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              style: const TextStyle(color: _kTextPrimary),
              decoration: InputDecoration(
                hintText: 'Search materials...',
                hintStyle: const TextStyle(color: _kTextSecondary),
                prefixIcon: const Icon(Icons.search, color: _kTextSecondary),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward, color: _kAccent),
                  onPressed: _search,
                ),
                filled: true,
                fillColor: _kDarkSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _kBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _kBorder),
                ),
              ),
              onSubmitted: (_) => _search(),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: _kAccent),
                    )
                  : _results.isEmpty
                  ? Center(
                      child: Text(
                        'No materials found',
                        style: TextStyle(color: _kTextSecondary),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (ctx, i) {
                        final m = _results[i];
                        final imageUrl = m['item_image_url'] as String?;
                        return ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _kDarkSurface,
                              borderRadius: BorderRadius.circular(8),
                              image: (imageUrl != null && imageUrl.isNotEmpty)
                                  ? DecorationImage(
                                      image: NetworkImage(imageUrl),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: (imageUrl == null || imageUrl.isEmpty)
                                ? const Icon(Icons.inventory_2, size: 20, color: _kTextSecondary)
                                : null,
                          ),
                          title: Text(
                            m['name'] as String? ?? '',
                            style: const TextStyle(color: _kTextPrimary),
                          ),
                          subtitle: Text(
                            '${m['unit_of_measure'] ?? ''} • ${m['category'] ?? ''}',
                            style: const TextStyle(color: _kTextSecondary),
                          ),
                          onTap: () => Navigator.pop(context, m),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: _kTextSecondary)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
