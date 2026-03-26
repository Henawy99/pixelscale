import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:restaurantadmin/models/menu_item_model.dart';
import 'package:restaurantadmin/models/brand.dart'; // Import Brand model
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

class EditMenuItemScreen extends StatefulWidget {
  final MenuItem menuItem;

  const EditMenuItemScreen({super.key, required this.menuItem});

  @override
  State<EditMenuItemScreen> createState() => _EditMenuItemScreenState();
}

class _EditMenuItemScreenState extends State<EditMenuItemScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  bool _isLoading = false;
  bool _isUploadingImage = false;
  String? _selectedBrandId; // To hold the selected brand ID
  List<Brand> _brands = []; // To hold the list of fetched brands
  bool _isLoadingBrands = true; // To manage brand loading state

  XFile? _pickedImageFile;
  String? _currentImageUrl;

  final ImagePicker _picker = ImagePicker();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );

    _nameController = TextEditingController(text: widget.menuItem.name);
    _descriptionController = TextEditingController(
      text: widget.menuItem.description ?? '',
    );
    _priceController = TextEditingController(
      text: widget.menuItem.price.toStringAsFixed(2),
    );
    _currentImageUrl = widget.menuItem.imageUrl;
    _selectedBrandId =
        widget.menuItem.brandId; // Initialize with current brand_id

    _fetchBrands();
    _animationController.forward();
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
        // Ensure _selectedBrandId is valid or set to null if not found (or first if item has no brand)
        if (_selectedBrandId != null &&
            !_brands.any((b) => b.id == _selectedBrandId)) {
          _selectedBrandId = null;
        } else if (_selectedBrandId == null &&
            _brands.isNotEmpty &&
            widget.menuItem.brandId == null) {
          // Optionally default to the first brand if no brand is initially set and brands are available
          // _selectedBrandId = _brands.first.id;
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

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
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

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [Colors.green[600]!, Colors.green[400]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
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
            child: const Icon(Icons.edit, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Edit Menu Item',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.menuItem.name,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
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

  Widget _buildImageSection() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
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
                      'Menu Item Image',
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
                    height: 200,
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
                    height: 200,
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
                                    errorWidget: (context, url, error) =>
                                        Container(
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
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue[600]!, Colors.blue[400]!],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: _pickImage,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.upload_file_outlined,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _currentImageUrl != null ||
                                          _pickedImageFile != null
                                      ? 'Change Image'
                                      : 'Upload Image',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_currentImageUrl != null || _pickedImageFile != null)
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
                            onTap: _removeImage,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.delete_outline,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Remove Image',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormSection() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
            .animate(
              CurvedAnimation(
                parent: _animationController,
                curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
              ),
            ),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
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
                crossAxisAlignment: CrossAxisAlignment.start,
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
                        return 'Please enter a valid number for the price';
                      }
                      if (double.parse(value) < 0) {
                        return 'Price cannot be negative';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  // Brand Dropdown
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
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
        'image_url': newImageUrl, // This can be null if image was removed
        'brand_id': _selectedBrandId, // Add selected brand_id
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Edit Menu Item',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          if (!_isLoading)
            Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green[600]!, Colors.green[400]!],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _saveChanges,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.save, color: Colors.white, size: 18),
                        SizedBox(width: 4),
                        Text(
                          'Save',
                          style: TextStyle(
                            color: Colors.white,
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
      body: _isLoading
          ? Center(
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
                    'Saving changes...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  _buildHeader(),
                  _buildImageSection(),
                  _buildFormSection(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}
