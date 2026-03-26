import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

class AddMaterialItemScreen extends StatefulWidget {
  final String categoryName;

  const AddMaterialItemScreen({super.key, required this.categoryName});

  @override
  State<AddMaterialItemScreen> createState() => _AddMaterialItemScreenState();
}

class _AddMaterialItemScreenState extends State<AddMaterialItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final SupabaseClient _supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();
  final String _storageBucket = 'materialimages';

  XFile? _selectedImageFile;
  bool _isLoading = false;

  String? _name;
  double? _quantity;
  String? _unitOfMeasure = 'piece'; // Default value
  String? _sellerName;
  String? _itemNumber;
  String? _geminiInfo;

  final List<String> _units = [
    'piece',
    'kilo',
    'ml',
    'liter',
    'gram',
    'bottle',
    'can',
    'pack',
  ];

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1000,
      );
      if (pickedFile != null) {
        setState(() {
          _selectedImageFile = pickedFile;
        });
      }
    } catch (e) {
      print('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String?> _uploadImageToSupabase(
    XFile imageFile,
    String materialName,
  ) async {
    try {
      final fileBytes = await imageFile.readAsBytes();
      final fileExtension = p.extension(imageFile.path);
      final sanitizedMaterialName = materialName.replaceAll(
        RegExp(r'[^a-zA-Z0-9]'),
        '_',
      );
      final uniqueFileName =
          '${widget.categoryName}/$sanitizedMaterialName-${DateTime.now().millisecondsSinceEpoch}$fileExtension';

      await _supabase.storage
          .from(_storageBucket)
          .uploadBinary(
            uniqueFileName,
            fileBytes,
            fileOptions: FileOptions(
              contentType: imageFile.mimeType ?? 'application/octet-stream',
              upsert: false,
            ),
          );

      final imageUrlResponse = _supabase.storage
          .from(_storageBucket)
          .getPublicUrl(uniqueFileName);
      print('Image uploaded: $imageUrlResponse');
      return imageUrlResponse;
    } catch (e) {
      print('Error uploading image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  Future<void> _saveMaterial() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() => _isLoading = true);
      String? imageUrl;

      try {
        if (_selectedImageFile != null && _name != null) {
          imageUrl = await _uploadImageToSupabase(_selectedImageFile!, _name!);
        }

        await _supabase.from('material').insert({
          'name': _name,
          'current_quantity': _quantity,
          'unit_of_measure': _unitOfMeasure,
          'category': widget.categoryName,
          'seller_name': _sellerName,
          'item_number': _itemNumber,
          'item_image_url': imageUrl,
          'gemini_info': _geminiInfo,
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Material "$_name" added to ${widget.categoryName}!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(
          context,
        ).pop(true); // Pop with result true to indicate success/refresh needed
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add material: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add to ${widget.categoryName}'),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveMaterial,
              tooltip: 'Save Material',
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
              if (_selectedImageFile != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: kIsWeb
                        ? Image.network(
                            _selectedImageFile!.path,
                            height: 150,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          )
                        : Image.file(
                            File(_selectedImageFile!.path),
                            height: 150,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
              ElevatedButton.icon(
                icon: const Icon(Icons.image),
                label: Text(
                  _selectedImageFile == null ? 'Pick Image' : 'Change Image',
                ),
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
                              },
                            ),
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
                    },
                  );
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 40),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Material Name*'),
                validator: (value) => value == null || value.isEmpty
                    ? 'Please enter material name'
                    : null,
                onSaved: (value) => _name = value,
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Quantity*'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty)
                    return 'Please enter quantity';
                  if (double.tryParse(value) == null)
                    return 'Please enter a valid number';
                  return null;
                },
                onSaved: (value) => _quantity = double.tryParse(value!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Unit of Measure*',
                ),
                value: _unitOfMeasure,
                items: _units
                    .map(
                      (String unit) => DropdownMenuItem<String>(
                        value: unit,
                        child: Text(unit),
                      ),
                    )
                    .toList(),
                onChanged: (String? newValue) =>
                    setState(() => _unitOfMeasure = newValue),
                onSaved: (value) => _unitOfMeasure = value,
                validator: (value) =>
                    value == null ? 'Please select a unit' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: widget.categoryName,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  enabled: false,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Seller Name'),
                onSaved: (value) => _sellerName = value,
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Item Number'),
                onSaved: (value) => _itemNumber = value,
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Info for Gemini (e.g., alternate names)',
                ),
                onSaved: (value) => _geminiInfo = value,
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              // Save button is in AppBar now
            ],
          ),
        ),
      ),
    );
  }
}
