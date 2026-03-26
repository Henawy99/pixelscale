import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:playmakerappstart/models/footballfield_model.dart';
import 'package:playmakerappstart/services/supabase_service.dart';
import 'package:playmakerappstart/widgets/custom_snackbar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditFootballFieldScreen extends StatefulWidget {
  final FootballField field;

  const EditFootballFieldScreen({Key? key, required this.field}) : super(key: key);

  @override
  State<EditFootballFieldScreen> createState() => _EditFootballFieldScreenState();
}

class _EditFootballFieldScreenState extends State<EditFootballFieldScreen> {
  final _formKey = GlobalKey<FormState>();
  final SupabaseService _supabaseService = SupabaseService();
  
  late TextEditingController _nameController;
  late TextEditingController _streetNameController;
  late TextEditingController _latitudeController;
  late TextEditingController _longitudeController;
  late TextEditingController _openingHoursController;
  late TextEditingController _priceRangeController;
  late TextEditingController _commissionPercentageController;
  late TextEditingController _cameraUsernameController;
  late TextEditingController _cameraPasswordController;
  late TextEditingController _cameraIpAddressController;
  
  // Owner & Assistant Contact Controllers
  late TextEditingController _ownerNameController;
  late TextEditingController _ownerPhoneController;
  
  // Dynamic list of assistants (name + phone)
  List<Map<String, TextEditingController>> _assistantControllers = [];
  
  // City & Area Controllers
  late TextEditingController _cityController;
  late TextEditingController _areaController;

  late String _selectedLocation;
  late String _fieldSize;
  late bool _bookable;
  late bool _isEnabled;  // Field visibility status
  List<String> _existingPhotos = [];
  List<XFile> _newImages = [];  // Changed to XFile for web compatibility
  bool _isLoading = false;

  late Map<String, bool> _amenities;
  late Map<String, List<Map<String, dynamic>>> _availableTimeSlots;

  @override
  void initState() {
    super.initState();
    
    // Initialize controllers with existing data
    _nameController = TextEditingController(text: widget.field.footballFieldName);
    _streetNameController = TextEditingController(text: widget.field.streetName);
    _latitudeController = TextEditingController(text: widget.field.latitude.toString());
    _longitudeController = TextEditingController(text: widget.field.longitude.toString());
    _openingHoursController = TextEditingController(text: widget.field.openingHours);
    _priceRangeController = TextEditingController(text: widget.field.priceRange);
    _commissionPercentageController = TextEditingController(text: widget.field.commissionPercentage);
    _cameraUsernameController = TextEditingController(text: widget.field.cameraUsername ?? '');
    _cameraPasswordController = TextEditingController(text: widget.field.cameraPassword ?? '');
    _cameraIpAddressController = TextEditingController(text: widget.field.cameraIpAddress ?? '');
    
    // Initialize owner contact controllers
    _ownerNameController = TextEditingController(text: widget.field.ownerName ?? '');
    _ownerPhoneController = TextEditingController(text: widget.field.ownerPhoneNumber ?? '');
    
    // Initialize assistants from existing data
    for (var assistant in widget.field.assistants) {
      _assistantControllers.add({
        'name': TextEditingController(text: assistant['name'] ?? ''),
        'phone': TextEditingController(text: assistant['phone'] ?? ''),
      });
    }
    
    // Initialize city & area controllers
    _cityController = TextEditingController(text: widget.field.city ?? '');
    _areaController = TextEditingController(text: widget.field.area ?? '');

    _selectedLocation = widget.field.locationName;
    _fieldSize = widget.field.fieldSize;
    _bookable = widget.field.bookable;
    _isEnabled = widget.field.isEnabled;
    _existingPhotos = List.from(widget.field.photos);
    
    // Deep copy amenities
    _amenities = Map<String, bool>.from(widget.field.amenities);
    
    // Deep copy time slots
    _availableTimeSlots = {};
    widget.field.availableTimeSlots.forEach((day, slots) {
      _availableTimeSlots[day] = List<Map<String, dynamic>>.from(
        slots.map((slot) => Map<String, dynamic>.from(slot))
      );
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _streetNameController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _openingHoursController.dispose();
    _priceRangeController.dispose();
    _commissionPercentageController.dispose();
    _cameraUsernameController.dispose();
    _cameraPasswordController.dispose();
    _cameraIpAddressController.dispose();
    _ownerNameController.dispose();
    _ownerPhoneController.dispose();
    // Dispose all assistant controllers
    for (var assistant in _assistantControllers) {
      assistant['name']?.dispose();
      assistant['phone']?.dispose();
    }
    _cityController.dispose();
    _areaController.dispose();
    super.dispose();
  }

  void _addAssistant() {
    setState(() {
      _assistantControllers.add({
        'name': TextEditingController(),
        'phone': TextEditingController(),
      });
    });
  }

  void _removeAssistant(int index) {
    setState(() {
      _assistantControllers[index]['name']?.dispose();
      _assistantControllers[index]['phone']?.dispose();
      _assistantControllers.removeAt(index);
    });
  }

  List<Map<String, String>> _getAssistantsList() {
    return _assistantControllers
        .where((a) => 
            (a['name']?.text.trim().isNotEmpty ?? false) || 
            (a['phone']?.text.trim().isNotEmpty ?? false))
        .map((a) => {
              'name': a['name']?.text.trim() ?? '',
              'phone': a['phone']?.text.trim() ?? '',
            })
        .toList();
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage();
    if (pickedFiles.isNotEmpty) {
      setState(() {
        // Add new images to existing list (keep as XFile for web compatibility)
        _newImages.addAll(pickedFiles);
      });
      print('📸 Selected ${pickedFiles.length} new photos. Total new photos: ${_newImages.length}');
    }
  }

  Future<List<String>> _uploadNewImages() async {
    List<String> imageUrls = [];
    final supabase = Supabase.instance.client;
    
    print('📸 Starting upload of ${_newImages.length} new images to Supabase Storage...');
    print('📦 Storage bucket: football_fields');
    print('🌐 Platform: ${kIsWeb ? "Web" : "Mobile"}');
    
    for (int i = 0; i < _newImages.length; i++) {
      final image = _newImages[i];
      try {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        
        print('   📤 Uploading image ${i + 1}/${_newImages.length}...');
        print('   📂 File name: $fileName');
        print('   📁 Original path: ${image.path}');
        
        // Read file as bytes (works on both web and mobile)
        final Uint8List bytes = await image.readAsBytes();
        print('   📊 File size: ${(bytes.length / 1024).toStringAsFixed(2)} KB');
        
        if (bytes.isEmpty) {
          print('   ⚠️ Warning: File is empty, skipping...');
          continue;
        }
        
        // Upload to Supabase Storage
        await supabase.storage
            .from('football_fields')
            .uploadBinary(
              fileName,
              bytes,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                upsert: true,
              ),
            );
        
        print('   ⏳ Getting public URL...');
        
        // Get public URL
        final url = supabase.storage
            .from('football_fields')
            .getPublicUrl(fileName);
        
        imageUrls.add(url);
        print('   ✅ Uploaded successfully!');
        print('   🔗 URL: $url');
      } catch (e, stackTrace) {
        print('   ❌ UPLOAD FAILED!');
        print('   Error: $e');
        print('   Stack: $stackTrace');
        
        // Show detailed error to user with copy button
        if (mounted) {
          CustomSnackbar.showError(context, 'Upload failed: ${e.toString()}');
        }
      }
    }
    
    print('📸 Upload complete! ${imageUrls.length}/${_newImages.length} new images uploaded successfully');
    return imageUrls;
  }

  Future<void> _updateField() async {
    if (!_formKey.currentState!.validate()) {
      CustomSnackbar.showError(context, 'Please fill all required fields.');
      return;
    }

    if (_existingPhotos.isEmpty && _newImages.isEmpty) {
      CustomSnackbar.showError(context, 'Please add at least one photo for the field.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      print('💾 Updating field...');
      print('   Existing photos: ${_existingPhotos.length}');
      print('   New photos to upload: ${_newImages.length}');
      
      // Upload new images
      List<String> newPhotoUrls = [];
      if (_newImages.isNotEmpty) {
        print('🖼️ Uploading ${_newImages.length} new photos...');
        newPhotoUrls = await _uploadNewImages();
        print('✅ New photos uploaded! URLs: $newPhotoUrls');
      }

      // Combine existing and new photos
      List<String> allPhotos = [..._existingPhotos, ...newPhotoUrls];
      print('📸 Total photos to save: ${allPhotos.length} (${_existingPhotos.length} existing + ${newPhotoUrls.length} new)');

      // Create updated field object
      final updatedField = FootballField(
        id: widget.field.id,
        footballFieldName: _nameController.text,
        locationName: _selectedLocation,
        streetName: _streetNameController.text,
        latitude: double.tryParse(_latitudeController.text) ?? widget.field.latitude,
        longitude: double.tryParse(_longitudeController.text) ?? widget.field.longitude,
        openingHours: _openingHoursController.text,
        priceRange: _priceRangeController.text,
        photos: allPhotos,
        availableTimeSlots: _availableTimeSlots,
        amenities: _amenities,
        fieldSize: _fieldSize,
        commissionPercentage: _commissionPercentageController.text,
        bookable: _bookable,
        bookings: widget.field.bookings, // Keep existing bookings
        username: widget.field.username,
        password: widget.field.password,
        cameraUsername: _amenities['cameraRecording'] == true ? _cameraUsernameController.text : null,
        cameraPassword: _amenities['cameraRecording'] == true ? _cameraPasswordController.text : null,
        cameraIpAddress: _amenities['cameraRecording'] == true ? _cameraIpAddressController.text : null,
        hasCamera: _amenities['cameraRecording'] ?? false,
        ownerName: _ownerNameController.text.trim().isNotEmpty ? _ownerNameController.text.trim() : null,
        ownerPhoneNumber: _ownerPhoneController.text.trim().isNotEmpty ? _ownerPhoneController.text.trim() : null,
        assistants: _getAssistantsList(),
        createdAt: widget.field.createdAt ?? DateTime.now(), // Keep existing or set now
        city: _cityController.text.trim().isNotEmpty ? _cityController.text.trim() : null,
        area: _areaController.text.trim().isNotEmpty ? _areaController.text.trim() : null,
        blockedUsers: widget.field.blockedUsers, // Preserve existing blocklist
        isEnabled: _isEnabled, // Field visibility status
      );

      // Update in Supabase
      print('📤 Saving to Supabase with ${updatedField.photos.length} photos...');
      await _supabaseService.updateFootballField(updatedField);
      print('✅ Field updated in Supabase successfully!');

      if (mounted) {
        final successMessage = 'Football field updated successfully!\n\n'
            '📸 Total Photos: ${updatedField.photos.length}\n'
            '   (${_existingPhotos.length} existing + ${newPhotoUrls.length} new)';
        CustomSnackbar.show(context, message: successMessage);
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.showError(context, 'Failed to update field: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _addTimeSlot(String day) {
    final fromTimeController = TextEditingController();
    final toTimeController = TextEditingController();
    final priceController = TextEditingController();
    bool applyToAllDays = false;
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                'Add Time Slot',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Day indicator
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Text(
                        applyToAllDays ? 'All Weekdays' : day,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // From Time
                    Text(
                      'From Time',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: fromTimeController,
                      keyboardType: TextInputType.datetime,
                      decoration: InputDecoration(
                        hintText: '09:00',
                        helperText: 'Format: HH:mm (e.g., 09:00)',
                        prefixIcon: const Icon(Icons.access_time),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // To Time
                    Text(
                      'To Time',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: toTimeController,
                      keyboardType: TextInputType.datetime,
                      decoration: InputDecoration(
                        hintText: '10:00',
                        helperText: 'Format: HH:mm (e.g., 10:00)',
                        prefixIcon: const Icon(Icons.access_time_filled),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Price
                    Text(
                      'Price',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: priceController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: '300',
                        helperText: 'Price in EGP',
                        prefixIcon: const Icon(Icons.attach_money),
                        suffixText: 'EGP',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Apply to all weekdays checkbox
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: CheckboxListTile(
                        title: Text(
                          'Apply to all weekdays',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          'Add this time slot to Monday-Sunday',
                          style: GoogleFonts.inter(fontSize: 12),
                        ),
                        value: applyToAllDays,
                        onChanged: (value) {
                          setDialogState(() {
                            applyToAllDays = value ?? false;
                          });
                        },
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final fromTime = fromTimeController.text.trim();
                    final toTime = toTimeController.text.trim();
                    final price = priceController.text.trim();
                    
                    // Validate inputs
                    if (fromTime.isEmpty || toTime.isEmpty || price.isEmpty) {
                      CustomSnackbar.showError(context, 'Please fill all fields');
                      return;
                    }
                    
                    // Validate time format (simple check)
                    final timeRegex = RegExp(r'^\d{2}:\d{2}$');
                    if (!timeRegex.hasMatch(fromTime) || !timeRegex.hasMatch(toTime)) {
                      CustomSnackbar.showError(context, 'Please use HH:mm format (e.g., 09:00)');
                      return;
                    }
                    
                    final timeSlotString = '$fromTime - $toTime';
                    final priceValue = double.tryParse(price);
                    
                    if (priceValue == null) {
                      CustomSnackbar.showError(context, 'Please enter a valid price');
                      return;
                    }
                    
                    setState(() {
                      if (applyToAllDays) {
                        // Apply to all days
                        for (var dayKey in _availableTimeSlots.keys) {
                          _availableTimeSlots[dayKey]!.add({
                            'time': timeSlotString,
                            'price': priceValue,
                            'available': true,
                          });
                          // Sort by time
                          _availableTimeSlots[dayKey]!.sort((a, b) => 
                            a['time'].toString().compareTo(b['time'].toString()));
                        }
                      } else {
                        // Apply to selected day only
                        _availableTimeSlots[day]!.add({
                          'time': timeSlotString,
                          'price': priceValue,
                          'available': true,
                        });
                        // Sort by time
                        _availableTimeSlots[day]!.sort((a, b) => 
                          a['time'].toString().compareTo(b['time'].toString()));
                      }
                    });
                    
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Add Time Slot'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildCard({required String title, required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    bool isRequired = true,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label + (isRequired ? ' *' : ''),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        validator: validator ??
            (value) {
              if (isRequired && (value == null || value.isEmpty)) {
                return '$label is required';
              }
              return null;
            },
      ),
    );
  }

  String _getAmenityLabel(String key) {
    switch (key) {
      case 'parking': return 'Parking Available';
      case 'toilets': return 'Toilets';
      case 'cafeteria': return 'Cafeteria';
      case 'floodlights': return 'Floodlights';
      case 'qualityField': return 'High Quality Field';
      case 'ballIncluded': return 'Ball Included';
      case 'cameraRecording': return 'Camera Recording';
      default: return key;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: Text('Edit Football Field', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.black87)),
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black87),
          bottom: TabBar(
            labelColor: Colors.green,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.green,
            isScrollable: true,
            labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
            tabs: const [
              Tab(text: 'Basic Info'),
              Tab(text: 'Details & Photos'),
              Tab(text: 'Schedule'),
              Tab(text: 'Settings'),
            ],
          ),
          actions: [
            if (!_isLoading)
              TextButton(
                onPressed: _updateField,
                child: Text('Save', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: TabBarView(
                  children: [
                    // Tab 1: Basic Info
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          _buildCard(
                            title: 'Field Identity',
                            children: [
                              _buildTextField(controller: _nameController, label: 'Field Name'),
                              _buildTextField(controller: _streetNameController, label: 'Street Name'),
                            ],
                          ),
                          _buildCard(
                            title: 'Location',
                            children: [
                              DropdownButtonFormField<String>(
                                value: _selectedLocation,
                                decoration: InputDecoration(
                                  labelText: 'Location *',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                items: [
                                  'Cairo', 'Alexandria', 'Giza', 'New Cairo', '6th of October',
                                  'Maadi', 'Heliopolis', 'Nasr City', 'Zamalek'
                                ].map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                                onChanged: (v) => setState(() => _selectedLocation = v!),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(child: _buildTextField(controller: _cityController, label: 'City')),
                                  const SizedBox(width: 16),
                                  Expanded(child: _buildTextField(controller: _areaController, label: 'Area')),
                                ],
                              ),
                              _buildTextField(controller: _latitudeController, label: 'Latitude', keyboardType: TextInputType.number),
                              _buildTextField(controller: _longitudeController, label: 'Longitude', keyboardType: TextInputType.number),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Tab 2: Details & Photos
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          _buildCard(
                            title: 'Photos',
                            children: [
                              if (_existingPhotos.isNotEmpty) ...[
                                Text('Current', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.grey)),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: _existingPhotos.map((url) => Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: CachedNetworkImage(
                                          imageUrl: url, width: 80, height: 80, fit: BoxFit.cover,
                                          placeholder: (_, __) => Container(color: Colors.grey.shade200),
                                        ),
                                      ),
                                      Positioned(right: 0, top: 0, child: GestureDetector(
                                        onTap: () => setState(() => _existingPhotos.remove(url)),
                                        child: const Icon(Icons.cancel, color: Colors.red, size: 20),
                                      )),
                                    ],
                                  )).toList(),
                                ),
                                const SizedBox(height: 16),
                              ],
                              if (_newImages.isNotEmpty) ...[
                                Text('New', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.green)),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: _newImages.asMap().entries.map((e) => Stack(
                                    children: [
                                      FutureBuilder<Uint8List>(
                                        future: e.value.readAsBytes(),
                                        builder: (ctx, snap) => snap.hasData 
                                          ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(snap.data!, width: 80, height: 80, fit: BoxFit.cover))
                                          : const SizedBox(width: 80, height: 80),
                                      ),
                                      Positioned(right: 0, top: 0, child: GestureDetector(
                                        onTap: () => setState(() => _newImages.removeAt(e.key)),
                                        child: const Icon(Icons.cancel, color: Colors.red, size: 20),
                                      )),
                                    ],
                                  )).toList(),
                                ),
                                const SizedBox(height: 16),
                              ],
                              OutlinedButton.icon(
                                onPressed: _pickImages,
                                icon: const Icon(Icons.add_photo_alternate),
                                label: const Text('Add Photos'),
                              ),
                            ],
                          ),
                          _buildCard(
                            title: 'Amenities',
                            children: _amenities.entries.map((e) => CheckboxListTile(
                              title: Text(_getAmenityLabel(e.key)),
                              value: e.value,
                              activeColor: Colors.green,
                              onChanged: (v) => setState(() => _amenities[e.key] = v!),
                            )).toList(),
                          ),
                          if (_amenities['cameraRecording'] == true)
                            _buildCard(
                              title: 'Camera Config',
                              children: [
                                _buildTextField(controller: _cameraUsernameController, label: 'Username'),
                                _buildTextField(controller: _cameraPasswordController, label: 'Password'),
                                _buildTextField(controller: _cameraIpAddressController, label: 'IP Address'),
                              ],
                            ),
                        ],
                      ),
                    ),

                    // Tab 3: Schedule
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          _buildCard(
                            title: 'General',
                            children: [
                              _buildTextField(controller: _openingHoursController, label: 'Opening Hours'),
                              _buildTextField(controller: _priceRangeController, label: 'Default Price Range'),
                            ],
                          ),
                          _buildCard(
                            title: 'Time Slots',
                            children: _availableTimeSlots.keys.map((day) => ExpansionTile(
                              title: Text(day, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                              subtitle: Text('${_availableTimeSlots[day]!.length} slots', style: TextStyle(color: Colors.grey)),
                              children: [
                                ..._availableTimeSlots[day]!.map((s) => ListTile(
                                  dense: true,
                                  title: Text('${s['time']}'),
                                  subtitle: Text('${s['price']} EGP'),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                    onPressed: () => setState(() => _availableTimeSlots[day]!.remove(s)),
                                  ),
                                )),
                                TextButton.icon(
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('Add Slot'),
                                  onPressed: () => _addTimeSlot(day),
                                )
                              ],
                            )).toList(),
                          ),
                        ],
                      ),
                    ),

                    // Tab 4: Settings
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          _buildCard(
                            title: 'Status',
                            children: [
                              // Field Enabled/Disabled Switch
                              Container(
                                decoration: BoxDecoration(
                                  color: _isEnabled ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _isEnabled ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3),
                                  ),
                                ),
                                child: SwitchListTile(
                                  title: Text(
                                    'Field Enabled',
                                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                                  ),
                                  subtitle: Text(
                                    _isEnabled 
                                        ? 'Visible in User App' 
                                        : 'Hidden from User App',
                                    style: TextStyle(
                                      color: _isEnabled ? Colors.green[700] : Colors.red[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  value: _isEnabled,
                                  activeColor: Colors.green,
                                  inactiveThumbColor: Colors.red,
                                  inactiveTrackColor: Colors.red.withOpacity(0.3),
                                  onChanged: (v) => setState(() => _isEnabled = v),
                                ),
                              ),
                              const SizedBox(height: 16),
                              SwitchListTile(
                                title: const Text('Field is Bookable'),
                                subtitle: Text(_bookable ? 'Active' : 'Inactive', style: const TextStyle(color: Colors.grey)),
                                value: _bookable,
                                activeColor: Colors.green,
                                onChanged: (v) => setState(() => _bookable = v),
                              ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<String>(
                                value: _fieldSize,
                                decoration: InputDecoration(
                                  labelText: 'Field Size',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                items: ['5-a-side', '6-a-side', '7-a-side', '8-a-side', '11-a-side']
                                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                                    .toList(),
                                onChanged: (v) => setState(() => _fieldSize = v!),
                              ),
                            ],
                          ),
                          _buildCard(
                            title: 'Owner & Contacts',
                            children: [
                              _buildTextField(controller: _ownerNameController, label: 'Owner Name', isRequired: false),
                              _buildTextField(controller: _ownerPhoneController, label: 'Owner Phone', keyboardType: TextInputType.phone, isRequired: false),
                              const Divider(height: 32),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Assistants', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                                  IconButton(icon: const Icon(Icons.add_circle, color: Colors.green), onPressed: _addAssistant),
                                ],
                              ),
                              ..._assistantControllers.asMap().entries.map((e) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: TextField(
                                  controller: e.value['name'],
                                  decoration: InputDecoration(labelText: 'Name ${e.key + 1}', isDense: true),
                                ),
                                subtitle: TextField(
                                  controller: e.value['phone'],
                                  decoration: InputDecoration(labelText: 'Phone ${e.key + 1}', isDense: true),
                                  keyboardType: TextInputType.phone,
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _removeAssistant(e.key),
                                ),
                              )),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

