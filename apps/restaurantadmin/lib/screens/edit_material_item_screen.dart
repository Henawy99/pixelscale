import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:restaurantadmin/models/material_item.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditMaterialItemScreen extends StatefulWidget {
  final MaterialItem materialItem;
  final String categoryName; // Added to pass category name for image path

  const EditMaterialItemScreen({
    super.key, 
    required this.materialItem,
    required this.categoryName, // Added
  });

  @override
  State<EditMaterialItemScreen> createState() => _EditMaterialItemScreenState();
}

class _EditMaterialItemScreenState extends State<EditMaterialItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final SupabaseClient _supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();
  final String _storageBucket = 'materialimages';

  XFile? _selectedImageFile;
  bool _isLoading = false;
  bool _removeCurrentImage = false;

  late String? _name;
  late double? _quantity;
  late String? _unitOfMeasure;
  late String? _sellerName;
  late String? _itemNumber;
  late String? _currentImageUrl;
  late String? _geminiInfo;
  late double? _notifyWhenQuantity; // Added for notify when quantity

  final List<String> _units = ['piece', 'kilo', 'ml', 'liter', 'gram', 'bottle', 'can', 'pack'];

 @override
  void initState() {
    super.initState();
    _name = widget.materialItem.name;
    _quantity = widget.materialItem.currentQuantity;
    _unitOfMeasure = widget.materialItem.unitOfMeasure;
    _sellerName = widget.materialItem.sellerName;
    _itemNumber = widget.materialItem.itemNumber;
    _currentImageUrl = widget.materialItem.itemImageUrl;
    _geminiInfo = widget.materialItem.geminiInfo;
    _notifyWhenQuantity = widget.materialItem.notifyWhenQuantity; // Initialize notifyWhenQuantity
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source, imageQuality: 70, maxWidth: 1000);
      if (pickedFile != null) {
        setState(() {
          _selectedImageFile = pickedFile;
          _removeCurrentImage = false; // If new image picked, don't remove current one conceptually until save
        });
      }
    } catch (e) {
      print('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<String?> _uploadImageToSupabase(XFile imageFile, String materialName, {String? oldImageUrl}) async {
     try {
      // Delete old image if a new one is uploaded and an old one exists
      if (oldImageUrl != null && oldImageUrl.isNotEmpty) {
        try {
          final Uri oldUri = Uri.parse(oldImageUrl);
          final String oldStoragePath = oldUri.pathSegments.sublist(oldUri.pathSegments.indexOf(_storageBucket) + 1).join('/');
          if (oldStoragePath.isNotEmpty) {
            await _supabase.storage.from(_storageBucket).remove([oldStoragePath]);
            print('Successfully deleted old image: $oldStoragePath');
          }
        } catch (e) {
          print('Failed to delete old image $oldImageUrl: $e. Continuing with new upload.');
        }
      }

      final fileBytes = await imageFile.readAsBytes();
      final fileExtension = p.extension(imageFile.path);
      final sanitizedMaterialName = materialName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      // Use categoryName from widget for consistency
      final uniqueFileName = '${widget.categoryName}/$sanitizedMaterialName-${DateTime.now().millisecondsSinceEpoch}$fileExtension';


      await _supabase.storage.from(_storageBucket).uploadBinary(
            uniqueFileName,
            fileBytes,
            fileOptions: FileOptions(contentType: imageFile.mimeType ?? 'application/octet-stream', upsert: false), // upsert false for new unique name
          );
      
      final imageUrlResponse = _supabase.storage.from(_storageBucket).getPublicUrl(uniqueFileName);
      print('Image uploaded: $imageUrlResponse');
      return imageUrlResponse;
    } catch (e) {
      print('Error uploading image: $e');
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload image: $e'), backgroundColor: Colors.red),
        );
      }
      return null;
    }
  }

  Future<void> _deleteImageFromSupabase(String imageUrl) async {
    try {
      final Uri uri = Uri.parse(imageUrl);
      // Ensure we correctly find the start of the path after the bucket name
      final int bucketNameIndex = uri.pathSegments.indexOf(_storageBucket);
      if (bucketNameIndex == -1 || bucketNameIndex + 1 >= uri.pathSegments.length) {
        print('Could not determine valid storage path from URL: $imageUrl');
        return;
      }
      final String storagePath = uri.pathSegments.sublist(bucketNameIndex + 1).join('/');
       if (storagePath.isNotEmpty) {
        await _supabase.storage.from(_storageBucket).remove([storagePath]);
        print('Successfully deleted image from storage: $storagePath');
      }
    } catch (e) {
      print('Failed to delete image $imageUrl from storage: $e');
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete image from storage: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }


  Future<void> _saveMaterialChanges() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() => _isLoading = true);
      
      String? finalImageUrl = _currentImageUrl;

      try {
        if (_selectedImageFile != null && _name != null) { // New image picked
          finalImageUrl = await _uploadImageToSupabase(_selectedImageFile!, _name!, oldImageUrl: _currentImageUrl);
        } else if (_removeCurrentImage && _currentImageUrl != null && _currentImageUrl!.isNotEmpty) { // Existing image marked for removal
          await _deleteImageFromSupabase(_currentImageUrl!);
          finalImageUrl = null;
        }

        await _supabase.from('material').update({
          'name': _name,
          'current_quantity': _quantity,
          'unit_of_measure': _unitOfMeasure,
          'seller_name': _sellerName,
          'item_number': _itemNumber,
          'item_image_url': finalImageUrl,
          'gemini_info': _geminiInfo,
          'notify_when_quantity': _notifyWhenQuantity, // Add notifyWhenQuantity to update
          // 'category' is not changed here, assuming item stays in its category
        }).eq('id', widget.materialItem.id);
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Material "$_name" updated!'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop(true); // Pop with result true to indicate success/refresh needed
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update material: $e'), backgroundColor: Colors.red),
        );
      } finally {
        if(mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit "${widget.materialItem.name}"'),
         actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white)),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveMaterialChanges,
              tooltip: 'Save Changes',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // Image Preview and Picker
              if (_selectedImageFile != null) // Show newly picked image
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: kIsWeb
                        ? Image.network(_selectedImageFile!.path, height: 150, width: double.infinity, fit: BoxFit.cover)
                        : Image.file(File(_selectedImageFile!.path), height: 150, width: double.infinity, fit: BoxFit.cover),
                  ),
                )
              else if (_currentImageUrl != null && _currentImageUrl!.isNotEmpty && !_removeCurrentImage) // Show existing image if not marked for removal
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      _currentImageUrl!,
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, st) => Container(
                        height: 150, width: double.infinity, color: Colors.grey[200],
                        child: const Center(child: Icon(Icons.broken_image, size: 50, color: Colors.grey)),
                      ),
                    ),
                  ),
                )
              else if (_removeCurrentImage || (_currentImageUrl == null || _currentImageUrl!.isEmpty)) // Show placeholder if image removed or never existed
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(child: Icon(Icons.image_not_supported, size: 50, color: Colors.grey)),
                ),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.image),
                      label: const Text('Change Image'),
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          builder: (BuildContext bc) {
                            return SafeArea(
                              child: Wrap(
                                children: <Widget>[
                                  ListTile(
                                      leading: const Icon(Icons.photo_library),
                                      title: const Text('Gallery'),
                                      onTap: () {
                                        _pickImage(ImageSource.gallery);
                                        Navigator.of(context).pop();
                                      }),
                                  ListTile(
                                    leading: const Icon(Icons.photo_camera),
                                    title: const Text('Camera'),
                                    onTap: () {
                                      _pickImage(ImageSource.camera);
                                      Navigator.of(context).pop();
                                    },
                                  ),
                                ],
                              ),
                            );
                          });
                      },
                    ),
                  ),
                  if (_currentImageUrl != null && _currentImageUrl!.isNotEmpty && !_removeCurrentImage) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.delete_outline, color: Colors.white),
                        label: const Text('Remove', style: TextStyle(color: Colors.white)),
                        onPressed: () {
                          setState(() {
                            _removeCurrentImage = true;
                            _selectedImageFile = null; // Clear any newly picked file if removing
                          });
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      ),
                    ),
                  ]
                ],
              ),
              const SizedBox(height: 20),
              TextFormField(
                initialValue: _name,
                decoration: const InputDecoration(labelText: 'Material Name*'),
                validator: (value) => value == null || value.isEmpty ? 'Please enter material name' : null,
                onSaved: (value) => _name = value,
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: _quantity?.toString(),
                decoration: const InputDecoration(labelText: 'Quantity*'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please enter quantity';
                  if (double.tryParse(value) == null) return 'Please enter a valid number';
                  return null;
                },
                onSaved: (value) => _quantity = double.tryParse(value!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: _notifyWhenQuantity?.toString(),
                decoration: InputDecoration(
                  labelText: 'Notify When Quantity (Optional)',
                  hintText: 'e.g., 5 (triggers alert if quantity is ≤ 5)',
                  suffixText: _unitOfMeasure, // Show the unit of measure
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    if (double.tryParse(value) == null) {
                      return 'Please enter a valid number.';
                    }
                    if (double.parse(value) < 0) {
                      return 'Quantity cannot be negative.';
                    }
                  }
                  return null;
                },
                onSaved: (value) {
                  _notifyWhenQuantity = (value != null && value.isNotEmpty) ? double.tryParse(value) : null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Unit of Measure*'),
                value: _unitOfMeasure,
                items: _units.map((String unit) => DropdownMenuItem<String>(value: unit, child: Text(unit))).toList(),
                onChanged: (String? newValue) => setState(() => _unitOfMeasure = newValue),
                onSaved: (value) => _unitOfMeasure = value,
                validator: (value) => value == null ? 'Please select a unit' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: widget.categoryName, // Display original category
                decoration: const InputDecoration(labelText: 'Category', enabled: false),
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: _sellerName,
                decoration: const InputDecoration(labelText: 'Seller Name'),
                onSaved: (value) => _sellerName = value,
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: _itemNumber,
                decoration: const InputDecoration(labelText: 'Item Number'),
                onSaved: (value) => _itemNumber = value,
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: _geminiInfo,
                decoration: const InputDecoration(labelText: 'Info for Gemini (e.g., alternate names)'),
                onSaved: (value) => _geminiInfo = value,
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              // Save button is in AppBar
            ],
          ),
        ),
      ),
    );
  }
}
