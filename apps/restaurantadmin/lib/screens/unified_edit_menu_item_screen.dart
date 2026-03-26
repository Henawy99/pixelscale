import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:restaurantadmin/models/menu_item_model.dart';
import 'package:restaurantadmin/models/menu_item_material.dart';
import 'package:restaurantadmin/models/material_item.dart';
import 'package:restaurantadmin/models/brand.dart';

class UnifiedEditMenuItemScreen extends StatefulWidget {
  final MenuItem menuItem;

  const UnifiedEditMenuItemScreen({super.key, required this.menuItem});

  @override
  State<UnifiedEditMenuItemScreen> createState() =>
      _UnifiedEditMenuItemScreenState();
}

class _UnifiedEditMenuItemScreenState extends State<UnifiedEditMenuItemScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          widget.menuItem.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.green[600],
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: Colors.green[600],
              indicatorWeight: 3,
              tabs: const [
                Tab(icon: Icon(Icons.edit_note), text: 'Item Details'),
                Tab(icon: Icon(Icons.inventory_2), text: 'Materials'),
              ],
            ),
          ),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: TabBarView(
          controller: _tabController,
          children: [
            _ItemDetailsTab(menuItem: widget.menuItem),
            _MaterialsTab(menuItem: widget.menuItem),
          ],
        ),
      ),
    );
  }
}

// Item Details Tab
class _ItemDetailsTab extends StatefulWidget {
  final MenuItem menuItem;

  const _ItemDetailsTab({required this.menuItem});

  @override
  State<_ItemDetailsTab> createState() => _ItemDetailsTabState();
}

class _ItemDetailsTabState extends State<_ItemDetailsTab>
    with AutomaticKeepAliveClientMixin {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  bool _isLoading = false;
  bool _isUploadingImage = false;
  String? _selectedBrandId;
  List<Brand> _brands = [];
  bool _isLoadingBrands = true;

  XFile? _pickedImageFile;
  String? _currentImageUrl;

  final ImagePicker _picker = ImagePicker();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.menuItem.name);
    _descriptionController = TextEditingController(
      text: widget.menuItem.description ?? '',
    );
    _priceController = TextEditingController(
      text: widget.menuItem.price.toStringAsFixed(2),
    );
    _currentImageUrl = widget.menuItem.imageUrl;
    _selectedBrandId = widget.menuItem.brandId;
    _fetchBrands();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _fetchBrands() async {
    setState(() => _isLoadingBrands = true);
    try {
      final response = await Supabase.instance.client
          .from('brands')
          .select('id, name');
      final List<Brand> loadedBrands = (response as List)
          .map((data) => Brand.fromJson(data as Map<String, dynamic>))
          .toList();
      setState(() {
        _brands = loadedBrands;
        if (_selectedBrandId != null &&
            !_brands.any((b) => b.id == _selectedBrandId)) {
          _selectedBrandId = null;
        }
        _isLoadingBrands = false;
      });
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to load brands: $e');
        setState(() => _isLoadingBrands = false);
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (BuildContext bc) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Select Image Source',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.photo_library, color: Colors.blue[600]),
                    ),
                    title: const Text('Gallery'),
                    subtitle: const Text('Choose from your photos'),
                    onTap: () async {
                      Navigator.of(context).pop();
                      final XFile? pickedFile = await _picker.pickImage(
                        source: ImageSource.gallery,
                      );
                      if (pickedFile != null) {
                        setState(() {
                          _pickedImageFile = pickedFile;
                        });
                      }
                    },
                  ),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.photo_camera, color: Colors.green[600]),
                    ),
                    title: const Text('Camera'),
                    subtitle: const Text('Take a new photo'),
                    onTap: () async {
                      Navigator.of(context).pop();
                      final XFile? pickedFile = await _picker.pickImage(
                        source: ImageSource.camera,
                      );
                      if (pickedFile != null) {
                        setState(() {
                          _pickedImageFile = pickedFile;
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      _showErrorSnackBar('Failed to pick image: $e');
    }
  }

  Future<String?> _uploadImage(XFile imageFile) async {
    setState(() => _isUploadingImage = true);
    try {
      final supabase = Supabase.instance.client;
      const bucketName = 'menu_item_images';
      final fileExtension = imageFile.path.split('.').last.toLowerCase();
      final fileName =
          '${widget.menuItem.id}_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
      final filePath = 'public/$fileName';

      final bytes = await imageFile.readAsBytes();
      await supabase.storage
          .from(bucketName)
          .uploadBinary(
            filePath,
            bytes,
            fileOptions: FileOptions(
              contentType: imageFile.mimeType ?? 'image/$fileExtension',
              upsert: true,
            ),
          );

      final String publicUrl = supabase.storage
          .from(bucketName)
          .getPublicUrl(filePath);
      return publicUrl;
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Image upload failed: ${e.toString()}');
      }
      return null;
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  Future<void> _removeImage() async {
    setState(() {
      _pickedImageFile = null;
      _currentImageUrl = null;
    });
    _showWarningSnackBar('Image will be removed upon saving.');
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_selectedBrandId == null) {
      _showErrorSnackBar('Please select a brand for the menu item.');
      return;
    }

    setState(() => _isLoading = true);
    String? newImageUrl = _currentImageUrl;

    try {
      if (_pickedImageFile != null) {
        newImageUrl = await _uploadImage(_pickedImageFile!);
        if (newImageUrl == null && mounted) {
          setState(() => _isLoading = false);
          return;
        }
      }

      final supabase = Supabase.instance.client;
      final newName = _nameController.text;
      final newDescription = _descriptionController.text;
      final newPrice = double.tryParse(_priceController.text);

      if (newPrice == null) {
        if (mounted) {
          _showErrorSnackBar('Invalid price format.');
        }
        setState(() => _isLoading = false);
        return;
      }

      Map<String, dynamic> updateData = {
        'name': newName,
        'description': newDescription.isNotEmpty ? newDescription : null,
        'price': newPrice,
        'image_url': newImageUrl,
        'brand_id': _selectedBrandId,
      };

      await supabase
          .from('menu_items')
          .update(updateData)
          .eq('id', widget.menuItem.id);

      if (mounted) {
        _showSuccessSnackBar('Menu item updated successfully!');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to update item: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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

  void _showWarningSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.orange[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Saving changes...',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideScreen = constraints.maxWidth > 900;

        return SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(isWideScreen ? 24 : 16),
            child: isWideScreen ? _buildWideLayout() : _buildNarrowLayout(),
          ),
        );
      },
    );
  }

  Widget _buildWideLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 2, child: _buildImageSection()),
        const SizedBox(width: 24),
        Expanded(flex: 3, child: _buildFormSection()),
      ],
    );
  }

  Widget _buildNarrowLayout() {
    return Column(
      children: [
        _buildImageSection(),
        const SizedBox(height: 16),
        _buildFormSection(),
      ],
    );
  }

  Widget _buildImageSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.image, color: Colors.green[600], size: 24),
                const SizedBox(width: 12),
                const Text(
                  'Item Image',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_isUploadingImage)
              Container(
                height: 250,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        'Uploading image...',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              )
            else
              Container(
                height: 250,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _pickedImageFile != null
                      ? (kIsWeb
                            ? Image.network(
                                _pickedImageFile!.path,
                                fit: BoxFit.cover,
                              )
                            : Image.file(
                                File(_pickedImageFile!.path),
                                fit: BoxFit.cover,
                              ))
                      : (_currentImageUrl != null &&
                                _currentImageUrl!.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: _currentImageUrl!,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: Colors.grey[200],
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: Colors.grey[200],
                                  child: Center(
                                    child: Icon(
                                      Icons.broken_image_outlined,
                                      size: 50,
                                      color: Colors.grey[400],
                                    ),
                                  ),
                                ),
                              )
                            : Container(
                                color: Colors.grey[100],
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.image_not_supported_outlined,
                                        size: 50,
                                        color: Colors.grey[400],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'No image selected',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )),
                ),
              ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ElevatedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.upload_file_outlined),
                  label: Text(
                    _currentImageUrl != null || _pickedImageFile != null
                        ? 'Change Image'
                        : 'Upload Image',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                if (_currentImageUrl != null || _pickedImageFile != null)
                  ElevatedButton.icon(
                    onPressed: _removeImage,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Remove'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
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

  Widget _buildFormSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.edit_note, color: Colors.green[600], size: 24),
                  const SizedBox(width: 12),
                  const Text(
                    'Item Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Item Name*',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  prefixIcon: const Icon(Icons.restaurant_menu),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the item name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description (Optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  prefixIcon: const Icon(Icons.description),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                decoration: InputDecoration(
                  labelText: 'Price*',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  prefixIcon: const Icon(Icons.euro),
                  prefixText: '€',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the price';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  if (double.parse(value) < 0) {
                    return 'Price cannot be negative';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              if (_isLoadingBrands)
                const Center(child: CircularProgressIndicator())
              else if (_brands.isEmpty)
                const Text('No brands available. Please add brands first.')
              else
                DropdownButtonFormField<String>(
                  value: _selectedBrandId,
                  decoration: InputDecoration(
                    labelText: 'Brand*',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                    prefixIcon: const Icon(Icons.storefront),
                  ),
                  items: _brands.map((Brand brand) {
                    return DropdownMenuItem<String>(
                      value: brand.id,
                      child: Text(brand.name),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedBrandId = newValue;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a brand';
                    }
                    return null;
                  },
                ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _saveChanges,
                icon: const Icon(Icons.save),
                label: const Text('Save Changes'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Materials Tab
class _MaterialsTab extends StatefulWidget {
  final MenuItem menuItem;

  const _MaterialsTab({required this.menuItem});

  @override
  State<_MaterialsTab> createState() => _MaterialsTabState();
}

class _MaterialsTabState extends State<_MaterialsTab>
    with AutomaticKeepAliveClientMixin {
  List<MenuItemMaterial> _linkedMaterials = [];
  bool _isLoading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetchLinkedMaterials();
  }

  Future<void> _fetchLinkedMaterials() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('menu_item_materials')
          .select('*, material_id(id, name, item_image_url)')
          .eq('menu_item_id', widget.menuItem.id)
          .order('created_at', ascending: true);

      if (!mounted) return;

      final List<MenuItemMaterial> fetchedLinks = [];

      for (var data in response as List) {
        final mapData = data as Map<String, dynamic>;
        String? materialName;
        String? materialImageUrl;
        if (mapData['material_id'] is Map) {
          final materialDataMap =
              mapData['material_id'] as Map<String, dynamic>;
          materialName = materialDataMap['name'] as String?;
          materialImageUrl = materialDataMap['item_image_url'] as String?;
        }
        fetchedLinks.add(
          MenuItemMaterial.fromJson(
            mapData,
            materialName: materialName,
            materialItemImageUrlParam: materialImageUrl,
          ),
        );
      }

      setState(() {
        _linkedMaterials = fetchedLinks;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Failed to load linked materials: ${e.toString()}";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteLinkedMaterial(String linkId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange[600],
              size: 28,
            ),
            const SizedBox(width: 12),
            const Text('Confirm Deletion'),
          ],
        ),
        content: const Text(
          'Are you sure you want to remove this material link?',
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
          .from('menu_item_materials')
          .delete()
          .eq('id', linkId);

      if (mounted) {
        _showSuccessSnackBar('Material link removed successfully!');
        _fetchLinkedMaterials();
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to remove material link: $e');
      }
    }
  }

  Future<void> _navigateToAddMaterialLink() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return _AddMaterialLinkDialog(menuItemId: widget.menuItem.id);
      },
    );

    if (result == true && mounted) {
      _fetchLinkedMaterials();
    }
  }

  Future<void> _handleQuantityUpdate(
    String linkId,
    double newQuantity,
    String unitOfMeasure,
  ) async {
    try {
      await Supabase.instance.client
          .from('menu_item_materials')
          .update({
            'quantity_used': newQuantity,
            'unit_of_measure_for_usage': unitOfMeasure,
          })
          .eq('id', linkId);

      if (mounted) {
        _showSuccessSnackBar('Quantity updated successfully!');
        _fetchLinkedMaterials();
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to update quantity: $e');
      }
    }
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

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
            const SizedBox(height: 16),
            Text(
              'Failed to Load Materials',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
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
              onPressed: _fetchLinkedMaterials,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideScreen = constraints.maxWidth > 900;

        return Stack(
          children: [
            if (_linkedMaterials.isEmpty)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 80,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'No Materials Linked',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Tap the button below to start linking materials.',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              RefreshIndicator(
                onRefresh: _fetchLinkedMaterials,
                child: isWideScreen ? _buildGridView() : _buildListView(),
              ),
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton.extended(
                onPressed: _navigateToAddMaterialLink,
                backgroundColor: Colors.teal[600],
                icon: const Icon(Icons.add_link, color: Colors.white),
                label: const Text(
                  'Link Materials',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.all(16).copyWith(bottom: 80),
      itemCount: _linkedMaterials.length,
      itemBuilder: (context, index) {
        final link = _linkedMaterials[index];
        return _MaterialLinkCard(
          menuItemMaterial: link,
          onQuantityUpdate: (newQuantity, newUnit) async {
            await _handleQuantityUpdate(link.id, newQuantity, newUnit);
          },
          onDelete: () => _deleteLinkedMaterial(link.id),
        );
      },
    );
  }

  Widget _buildGridView() {
    return GridView.builder(
      padding: const EdgeInsets.all(16).copyWith(bottom: 80),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.5,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _linkedMaterials.length,
      itemBuilder: (context, index) {
        final link = _linkedMaterials[index];
        return _MaterialLinkCard(
          menuItemMaterial: link,
          onQuantityUpdate: (newQuantity, newUnit) async {
            await _handleQuantityUpdate(link.id, newQuantity, newUnit);
          },
          onDelete: () => _deleteLinkedMaterial(link.id),
        );
      },
    );
  }
}

// Material Link Card Widget
class _MaterialLinkCard extends StatefulWidget {
  final MenuItemMaterial menuItemMaterial;
  final Future<void> Function(double newQuantity, String newUnit)
  onQuantityUpdate;
  final Future<void> Function() onDelete;

  const _MaterialLinkCard({
    required this.menuItemMaterial,
    required this.onQuantityUpdate,
    required this.onDelete,
  });

  @override
  State<_MaterialLinkCard> createState() => _MaterialLinkCardState();
}

class _MaterialLinkCardState extends State<_MaterialLinkCard> {
  late TextEditingController _quantityController;
  late String _currentUnitOfMeasure;
  final _formKey = GlobalKey<FormState>();
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(
      text: widget.menuItemMaterial.quantityUsed.toString(),
    );
    _currentUnitOfMeasure = widget.menuItemMaterial.unitOfMeasureUsed;
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _saveQuantity() async {
    if (_formKey.currentState!.validate()) {
      final newQuantity = double.tryParse(_quantityController.text);
      if (newQuantity != null && newQuantity > 0) {
        await widget.onQuantityUpdate(newQuantity, _currentUnitOfMeasure);
        setState(() => _isEditing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Row(
            children: [
              // Material image
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey[200],
                ),
                child:
                    widget.menuItemMaterial.materialItemImageUrl != null &&
                        widget.menuItemMaterial.materialItemImageUrl!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl:
                              widget.menuItemMaterial.materialItemImageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (context, url, error) => Icon(
                            Icons.broken_image_outlined,
                            color: Colors.grey[600],
                          ),
                        ),
                      )
                    : Icon(
                        Icons.inventory_2_outlined,
                        color: Colors.teal[600],
                        size: 30,
                      ),
              ),
              const SizedBox(width: 16),
              // Material details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.menuItemMaterial.materialName ?? 'Unknown',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_isEditing)
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _quantityController,
                              decoration: InputDecoration(
                                labelText: 'Quantity',
                                suffixText: _currentUnitOfMeasure,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 12,
                                ),
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              validator: (value) {
                                if (value == null || value.isEmpty)
                                  return 'Required';
                                final dValue = double.tryParse(value);
                                if (dValue == null) return 'Invalid';
                                if (dValue <= 0) return '> 0';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: _saveQuantity,
                            icon: Icon(Icons.check, color: Colors.green[600]),
                          ),
                          IconButton(
                            onPressed: () => setState(() => _isEditing = false),
                            icon: Icon(Icons.close, color: Colors.grey[600]),
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${widget.menuItemMaterial.quantityUsed} $_currentUnitOfMeasure',
                              style: TextStyle(
                                color: Colors.blue[700],
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => setState(() => _isEditing = true),
                            icon: Icon(
                              Icons.edit,
                              color: Colors.grey[600],
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              // Delete button
              IconButton(
                onPressed: widget.onDelete,
                icon: Icon(Icons.delete_outline, color: Colors.red[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Add Material Dialog (same as before but simplified)
class _AddMaterialLinkDialog extends StatefulWidget {
  final String menuItemId;

  const _AddMaterialLinkDialog({required this.menuItemId});

  @override
  State<_AddMaterialLinkDialog> createState() => _AddMaterialLinkDialogState();
}

class _AddMaterialLinkDialogState extends State<_AddMaterialLinkDialog> {
  final _formKey = GlobalKey<FormState>();
  final List<MaterialItem> _selectedMaterials = [];
  final Map<String, double> _quantities = {};
  final Map<String, String> _notes = {};

  List<MaterialItem> _availableMaterials = [];
  List<MaterialItem> _filteredMaterials = [];
  bool _isLoadingMaterials = true;
  final TextEditingController _searchController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchAvailableMaterials();
    _searchController.addListener(_filterMaterials);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterMaterials() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredMaterials = List.from(_availableMaterials);
      } else {
        _filteredMaterials = _availableMaterials
            .where((material) => material.name.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  Future<void> _fetchAvailableMaterials() async {
    setState(() => _isLoadingMaterials = true);
    try {
      final response = await Supabase.instance.client
          .from('material')
          .select()
          .order('name', ascending: true);
      if (!mounted) return;
      final materials = (response as List)
          .map((data) => MaterialItem.fromJson(data as Map<String, dynamic>))
          .toList();
      setState(() {
        _availableMaterials = materials;
        _filteredMaterials = List.from(materials);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching materials: $e'),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingMaterials = false);
    }
  }

  void _toggleMaterialSelection(MaterialItem material) {
    setState(() {
      if (_selectedMaterials.any((m) => m.id == material.id)) {
        _selectedMaterials.removeWhere((m) => m.id == material.id);
        _quantities.remove(material.id);
        _notes.remove(material.id);
      } else {
        _selectedMaterials.add(material);
        _quantities[material.id] = 1.0;
        _notes[material.id] = '';
      }
    });
  }

  Future<void> _submitLinks() async {
    if (_selectedMaterials.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select at least one material.'),
          backgroundColor: Colors.orange[600],
        ),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() => _isSubmitting = true);

      try {
        final links = _selectedMaterials.map((material) {
          final quantity = _quantities[material.id] ?? 1.0;
          final notes = _notes[material.id]?.trim();
          return {
            'menu_item_id': widget.menuItemId,
            'material_id': material.id,
            'quantity_used': quantity,
            'unit_of_measure_for_usage': material.unitOfMeasure,
            'notes': notes?.isNotEmpty == true ? notes : null,
          };
        }).toList();

        await Supabase.instance.client
            .from('menu_item_materials')
            .insert(links);

        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to link materials: $e'),
              backgroundColor: Colors.red[600],
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.add_link, color: Colors.teal[600], size: 28),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Link Materials',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                if (_selectedMaterials.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.teal[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_selectedMaterials.length} selected',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.teal[700],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            // Search
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search materials...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Materials list
            Expanded(
              child: _isLoadingMaterials
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredMaterials.isEmpty
                  ? const Center(child: Text('No materials found'))
                  : Form(
                      key: _formKey,
                      child: ListView.builder(
                        itemCount: _filteredMaterials.length,
                        itemBuilder: (context, index) {
                          final material = _filteredMaterials[index];
                          final isSelected = _selectedMaterials.any(
                            (m) => m.id == material.id,
                          );

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.teal[50]
                                  : Colors.white,
                              border: Border.all(
                                color: isSelected
                                    ? Colors.teal[300]!
                                    : Colors.grey[200]!,
                                width: isSelected ? 2 : 1,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                ListTile(
                                  leading: Checkbox(
                                    value: isSelected,
                                    onChanged: (_) =>
                                        _toggleMaterialSelection(material),
                                  ),
                                  title: Text(material.name),
                                  subtitle: Text(
                                    'Unit: ${material.unitOfMeasure}',
                                  ),
                                  onTap: () =>
                                      _toggleMaterialSelection(material),
                                ),
                                if (isSelected) ...[
                                  const Divider(height: 1),
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: TextFormField(
                                            initialValue:
                                                _quantities[material.id]
                                                    ?.toString() ??
                                                '1.0',
                                            decoration: InputDecoration(
                                              labelText: 'Quantity',
                                              suffixText:
                                                  material.unitOfMeasure,
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              isDense: true,
                                            ),
                                            keyboardType:
                                                const TextInputType.numberWithOptions(
                                                  decimal: true,
                                                ),
                                            validator: (value) {
                                              if (value == null ||
                                                  value.isEmpty)
                                                return 'Required';
                                              final dValue = double.tryParse(
                                                value,
                                              );
                                              if (dValue == null)
                                                return 'Invalid';
                                              if (dValue <= 0) return '> 0';
                                              return null;
                                            },
                                            onSaved: (value) =>
                                                _quantities[material.id] =
                                                    double.tryParse(
                                                      value ?? '1.0',
                                                    ) ??
                                                    1.0,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: TextFormField(
                                            initialValue:
                                                _notes[material.id] ?? '',
                                            decoration: InputDecoration(
                                              labelText: 'Notes (Optional)',
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              isDense: true,
                                            ),
                                            onSaved: (value) =>
                                                _notes[material.id] =
                                                    value ?? '',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ),
            ),
            const SizedBox(height: 20),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitLinks,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
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
                            'Link ${_selectedMaterials.length} Material${_selectedMaterials.length == 1 ? '' : 's'}',
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
