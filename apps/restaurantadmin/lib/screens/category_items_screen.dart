// For File
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
// Keep for XFile if passed, but picker itself moves
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:restaurantadmin/models/material_item.dart';
import 'package:restaurantadmin/screens/material_history_screen.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb; // Keep for kIsWeb if used in this file
import 'package:hive/hive.dart'; // Import Hive
// For path operations, if any remain

// Import new screens
import 'package:restaurantadmin/screens/add_material_item_screen.dart';
import 'package:restaurantadmin/screens/edit_material_item_screen.dart';

class CategoryItemsScreen extends StatefulWidget {
  final String categoryName;

  const CategoryItemsScreen({super.key, required this.categoryName});

  @override
  State<CategoryItemsScreen> createState() => _CategoryItemsScreenState();
}

class _CategoryItemsScreenState extends State<CategoryItemsScreen>
    with TickerProviderStateMixin {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<MaterialItem> _materials = [];
  bool _isLoading = true;
  String? _error;

  // final ImagePicker _picker = ImagePicker(); // Moved to new screens
  // XFile? _dialogSelectedImageFile; // Moved to new screens
  // bool _isDialogLoading = false; // Moved to new screens

  // final String _storageBucket = 'materialimages'; // Moved to new screens
  final Duration _cacheDuration = const Duration(minutes: 10);
  late Box<MaterialItem> _materialItemsBox;
  late Box _appSettingsBox; // For storing timestamps

  String get _categoryBoxName =>
      'materials_${widget.categoryName.replaceAll(' ', '_').toLowerCase()}';
  String get _categoryTimestampKey => '${_categoryBoxName}_timestamp';

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

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

    _initHiveAndFetch();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initHiveAndFetch() async {
    // Ensure MaterialItemAdapter is registered (typically in main.dart)
    // if (!Hive.isAdapterRegistered(MaterialItemAdapter().typeId)) {
    //   Hive.registerAdapter(MaterialItemAdapter());
    // }
    _appSettingsBox = Hive.box(
      'app_settings',
    ); // Ensure this box is opened in main.dart
    _materialItemsBox = await Hive.openBox<MaterialItem>(_categoryBoxName);
    await _fetchCategoryMaterials(forceRefresh: false);
  }

  Future<void> _fetchCategoryMaterials({bool forceRefresh = false}) async {
    if (!forceRefresh && _materialItemsBox.isNotEmpty) {
      final int? lastFetchMillis =
          _appSettingsBox.get(_categoryTimestampKey) as int?;
      if (lastFetchMillis != null) {
        final lastFetchTime = DateTime.fromMillisecondsSinceEpoch(
          lastFetchMillis,
        );
        if (DateTime.now().difference(lastFetchTime) < _cacheDuration) {
          if (mounted) {
            setState(() {
              _materials = _materialItemsBox.values.toList();
              _isLoading = false;
              _error = null;
            });
            _animationController.forward();
          }
          print('Loaded materials for ${widget.categoryName} from Hive cache.');
          return;
        }
      }
    }

    if (mounted)
      setState(() {
        _isLoading = true;
        _error = null;
      });

    try {
      print(
        'Fetching materials for ${widget.categoryName} from Supabase for Hive update...',
      );
      final response = await _supabase
          .from('material')
          .select()
          .eq('category', widget.categoryName)
          .order('name', ascending: true);

      final List<MaterialItem> newMaterials = (response as List)
          .map((data) => MaterialItem.fromJson(data as Map<String, dynamic>))
          .toList();

      await _materialItemsBox.clear(); // Clear old items for this category
      // Use a map for putAll to store with material.id as key
      Map<String, MaterialItem> materialsToCache = {
        for (var m in newMaterials) m.id: m,
      };
      await _materialItemsBox.putAll(materialsToCache);
      await _appSettingsBox.put(
        _categoryTimestampKey,
        DateTime.now().millisecondsSinceEpoch,
      );

      if (mounted) {
        setState(() {
          _materials = newMaterials;
          _isLoading = false;
        });
        _animationController.forward();
      }
    } catch (e) {
      print('Error fetching materials for category ${widget.categoryName}: $e');
      if (mounted)
        setState(() {
          _error = 'Failed to load materials: $e';
          _isLoading = false;
        });
    }
  }

  // Methods like _uploadImageToSupabase, _deleteImageFromSupabase, _pickImage
  // will be moved to the new screens or adapted.
  // For now, removing the dialog methods from here.

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

  Widget _buildHeader() {
    final totalValue = _materials.fold(
      0.0,
      (sum, material) =>
          sum +
          (material.currentQuantity * (material.weightedAverageCost ?? 0.0)),
    );

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [Colors.purple[600]!, Colors.purple[400]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.3),
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
            child: const Icon(Icons.inventory_2, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.categoryName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_materials.length} items • €${totalValue.toStringAsFixed(2)} value',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
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
            'Loading ${widget.categoryName} items...',
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
              'Failed to Load Items',
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
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _fetchCategoryMaterials(forceRefresh: true),
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
          Icon(Icons.inventory_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 24),
          Text(
            'No Items Found',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'No materials found in ${widget.categoryName}.\nTap the button below to add your first item.',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple[600]!, Colors.purple[400]!],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () async {
                  // Navigate to AddMaterialItemScreen
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddMaterialItemScreen(
                        categoryName: widget.categoryName,
                      ),
                    ),
                  );
                  if (result == true && mounted) {
                    _fetchCategoryMaterials(forceRefresh: true);
                  }
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Add First Item',
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

  Widget _buildMaterialCard(MaterialItem material, int index) {
    bool needsNotification =
        material.notifyWhenQuantity != null &&
        material.currentQuantity <= material.notifyWhenQuantity!;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
            .animate(
              CurvedAnimation(
                parent: _animationController,
                curve: Interval(
                  (index * 0.1).clamp(0.0, 1.0),
                  ((index * 0.1) + 0.3).clamp(0.0, 1.0),
                  curve: Curves.easeOut,
                ),
              ),
            ),
        child: Container(
          decoration: BoxDecoration(
            color: needsNotification
                ? Colors.red.withOpacity(0.15)
                : Colors.white, // Subtle red tint
            borderRadius: BorderRadius.circular(16),
            border: needsNotification
                ? Border.all(color: Colors.red.shade400, width: 1.5)
                : null, // Red border
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        MaterialHistoryScreen(materialItem: material),
                  ),
                );
                if (result == true && mounted) {
                  _fetchCategoryMaterials(forceRefresh: true);
                }
              },
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Container(
                          decoration: const BoxDecoration(
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16),
                            ),
                          ),
                          child:
                              material.itemImageUrl != null &&
                                  material.itemImageUrl!.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(16),
                                    topRight: Radius.circular(16),
                                  ),
                                  child: CachedNetworkImage(
                                    imageUrl: material.itemImageUrl!,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      color: Colors.grey[100],
                                      child: const Center(
                                        child: SizedBox(
                                          width: 30,
                                          height: 30,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      ),
                                    ),
                                    errorWidget: (context, url, error) =>
                                        Container(
                                          color: Colors.grey[100],
                                          child: Center(
                                            child: Icon(
                                              Icons.broken_image_outlined,
                                              size: 40,
                                              color: Colors.grey[400],
                                            ),
                                          ),
                                        ),
                                  ),
                                )
                              : Container(
                                  decoration: BoxDecoration(
                                    color: Colors.purple[50],
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(16),
                                      topRight: Radius.circular(16),
                                    ),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.inventory_2_outlined,
                                      size: 40,
                                      color: Colors.purple[300],
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    material.name,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Qty: ${material.currentQuantity} ${material.unitOfMeasure}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
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
                                  '€${(material.currentQuantity * (material.weightedAverageCost ?? 0.0)).toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () async {
                            // Navigate to EditMaterialItemScreen
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EditMaterialItemScreen(
                                  materialItem: material,
                                  categoryName:
                                      widget.categoryName, // Pass categoryName
                                ),
                              ),
                            );
                            if (result == true && mounted) {
                              _fetchCategoryMaterials(forceRefresh: true);
                            }
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(
                              Icons.edit,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          widget.categoryName,
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
              icon: const Icon(Icons.refresh),
              onPressed: () => _fetchCategoryMaterials(forceRefresh: true),
              tooltip: 'Refresh',
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (!_isLoading && _error == null && _materials.isNotEmpty)
            _buildHeader(),
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _error != null
                ? _buildErrorState()
                : _materials.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: () =>
                        _fetchCategoryMaterials(forceRefresh: true),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final double screenWidth = constraints.maxWidth;
                        final int crossAxisCount = kIsWeb
                            ? (screenWidth > 1600
                                  ? 7
                                  : (screenWidth > 1300
                                        ? 6
                                        : (screenWidth > 1000
                                              ? 5
                                              : (screenWidth > 800 ? 4 : 3))))
                            : 2;
                        final double cardWidth =
                            (screenWidth - (16.0 * (crossAxisCount + 1))) /
                            crossAxisCount;
                        final double childAspectRatio = kIsWeb
                            ? (screenWidth > 1400 ? 1.0 : 1.05)
                            : 0.85;

                        return GridView.builder(
                          padding: const EdgeInsets.all(16.0),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: 16.0,
                                mainAxisSpacing: 16.0,
                                childAspectRatio: childAspectRatio,
                              ),
                          itemCount: _materials.length,
                          itemBuilder: (context, index) {
                            final material = _materials[index];
                            return _buildMaterialCard(material, index);
                          },
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.purple[600]!, Colors.purple[400]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.purple.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: () async {
            // Navigate to AddMaterialItemScreen
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    AddMaterialItemScreen(categoryName: widget.categoryName),
              ),
            );
            if (result == true && mounted) {
              _fetchCategoryMaterials(forceRefresh: true);
            }
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          label: const Text(
            'Add Item',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          icon: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }
}
