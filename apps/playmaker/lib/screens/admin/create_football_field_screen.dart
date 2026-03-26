import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:playmakerappstart/models/footballfield_model.dart';
import 'package:playmakerappstart/services/supabase_service.dart';
import 'package:playmakerappstart/widgets/custom_snackbar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreateFootballFieldScreen extends StatefulWidget {
  const CreateFootballFieldScreen({Key? key}) : super(key: key);

  @override
  State<CreateFootballFieldScreen> createState() => _CreateFootballFieldScreenState();
}

class _CreateFootballFieldScreenState extends State<CreateFootballFieldScreen> {
  final _formKey = GlobalKey<FormState>();
  final SupabaseService _supabaseService = SupabaseService();
  
  // Controllers
  final _nameController = TextEditingController();
  final _openingHoursController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _priceRangeController = TextEditingController();
  final _streetNameController = TextEditingController();
  final _ownerEmailController = TextEditingController();
  final _ownerPasswordController = TextEditingController(text: '123456'); // Default password for testing
  
  // Camera Recording Controllers
  final _cameraIpController = TextEditingController();
  final _cameraUsernameController = TextEditingController();
  final _cameraPasswordController = TextEditingController();
  final _raspberryPiIpController = TextEditingController();
  final _simCardNumberController = TextEditingController();
  final _routerIpController = TextEditingController();
  
  // Owner & Assistant Contact Controllers
  final _ownerNameController = TextEditingController();
  final _ownerPhoneController = TextEditingController();
  
  // Dynamic list of assistants (name + phone)
  List<Map<String, TextEditingController>> _assistantControllers = [];
  
  // City & Area Controllers
  final _cityController = TextEditingController();
  final _areaController = TextEditingController();
  
  // State
  int _currentStep = 0;
  String _selectedLocation = 'Cairo';
  String _fieldSize = '5-a-side';
  List<XFile> _selectedImages = [];  // Changed to XFile for web compatibility
  bool _isLoading = false;
  
  // Time slots by day
  final Map<String, List<Map<String, dynamic>>> _availableTimeSlots = {
    'Monday': [],
    'Tuesday': [],
    'Wednesday': [],
    'Thursday': [],
    'Friday': [],
    'Saturday': [],
    'Sunday': [],
  };
  
  // Amenities
  final Map<String, bool> _amenities = {
    'parking': false,
    'toilets': false,
    'cafeteria': false,
    'floodlights': false,
    'qualityField': false,
    'ballIncluded': false,
    'cameraRecording': false,
  };

  final List<String> _locations = [
    'Cairo',
    'Alexandria',
    'Giza',
    'New Cairo',
    '6th of October',
    'Maadi',
    'Heliopolis',
    'Nasr City',
    'Zamalek',
  ];

  final List<String> _fieldSizes = [
    '5-a-side',
    '6-a-side',
    '7-a-side',
    '8-a-side',
    '11-a-side',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _openingHoursController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _priceRangeController.dispose();
    _streetNameController.dispose();
    _ownerEmailController.dispose();
    _ownerPasswordController.dispose();
    _cameraIpController.dispose();
    _cameraUsernameController.dispose();
    _cameraPasswordController.dispose();
    _raspberryPiIpController.dispose();
    _simCardNumberController.dispose();
    _routerIpController.dispose();
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
    final images = await picker.pickMultiImage();
    
    if (images.isNotEmpty) {
      setState(() {
        // Add new images to existing list (keep as XFile for web compatibility)
        _selectedImages.addAll(images);
      });
    }
  }

  Future<List<String>> _uploadImages() async {
    List<String> urls = [];
    final supabase = Supabase.instance.client;
    
    print('📸 Starting upload of ${_selectedImages.length} images to Supabase Storage...');
    print('📦 Storage bucket: football_fields');
    print('🌐 Platform: ${kIsWeb ? "Web" : "Mobile"}');
    
    for (int i = 0; i < _selectedImages.length; i++) {
      final image = _selectedImages[i];
      try {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        
        print('   📤 Uploading image ${i + 1}/${_selectedImages.length}...');
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
        
        urls.add(url);
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
    
    print('📸 Upload complete! ${urls.length}/${_selectedImages.length} images uploaded successfully');
    return urls;
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
                      _showError('Please fill all fields');
                      return;
                    }
                    
                    // Validate time format (simple check)
                    final timeRegex = RegExp(r'^\d{2}:\d{2}$');
                    if (!timeRegex.hasMatch(fromTime) || !timeRegex.hasMatch(toTime)) {
                      _showError('Please use HH:mm format (e.g., 09:00)');
                      return;
                    }
                    
                    final timeSlotString = '$fromTime - $toTime';
                    final priceValue = double.tryParse(price);
                    
                    if (priceValue == null) {
                      _showError('Please enter a valid price');
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

  void _removeTimeSlot(String day, int index) {
    setState(() {
      _availableTimeSlots[day]!.removeAt(index);
    });
  }

  void _autoGenerateTimeslots() {
    final openingHoursText = _openingHoursController.text.trim();
    if (openingHoursText.isEmpty) {
      _showError('Please enter opening hours first');
      return;
    }

    // Parse opening hours (e.g., "9 AM - 11 PM" or "09:00 - 23:00")
    try {
      // Remove common words and clean the string
      final cleaned = openingHoursText
          .toLowerCase()
          .replaceAll('am', '')
          .replaceAll('pm', '')
          .replaceAll('a.m.', '')
          .replaceAll('p.m.', '')
          .trim();

      // Try to extract numbers
      final parts = cleaned.split('-');
      if (parts.length != 2) {
        _showError('Please use format: "9 AM - 11 PM" or "09:00 - 23:00"');
        return;
      }

      int startHour = 0;
      int endHour = 0;

      // Try to parse start time
      final startStr = parts[0].trim().replaceAll(':', '').replaceAll(' ', '');
      if (startStr.length <= 2) {
        // Simple hour format (e.g., "9")
        startHour = int.parse(startStr);
      } else {
        // Time format (e.g., "0900")
        startHour = int.parse(startStr.substring(0, 2));
      }

      // Try to parse end time
      final endStr = parts[1].trim().replaceAll(':', '').replaceAll(' ', '');
      if (endStr.length <= 2) {
        // Simple hour format (e.g., "23")
        endHour = int.parse(endStr);
      } else {
        // Time format (e.g., "2300")
        endHour = int.parse(endStr.substring(0, 2));
      }

      // Handle PM conversion if original text had PM
      if (openingHoursText.toLowerCase().contains('pm') && endHour < 12) {
        endHour += 12;
      }
      if (openingHoursText.toLowerCase().contains('am') && startHour == 12) {
        startHour = 0;
      }

      // Validate hours
      if (startHour < 0 || startHour > 23 || endHour < 0 || endHour > 23 || startHour >= endHour) {
        _showError('Invalid hours. Start must be before end (0-23)');
        return;
      }

      // Show confirmation dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            'Auto-Generate Timeslots',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This will create hourly timeslots from ${startHour.toString().padLeft(2, '0')}:00 to ${endHour.toString().padLeft(2, '0')}:00 for all weekdays.',
                style: GoogleFonts.inter(fontSize: 14),
              ),
              const SizedBox(height: 16),
              Text(
                'Number of slots per day: ${endHour - startHour}',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'You can still add or delete timeslots manually afterwards.',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.blue.shade900),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _generateHourlySlots(startHour, endHour);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
              ),
              child: const Text('Generate'),
            ),
          ],
        ),
      );
    } catch (e) {
      _showError('Could not parse opening hours. Use format: "9 AM - 11 PM"');
    }
  }

  void _generateHourlySlots(int startHour, int endHour) {
    final defaultPrice = _priceRangeController.text.contains('-')
        ? _priceRangeController.text.split('-')[0].trim().replaceAll(RegExp(r'[^0-9]'), '')
        : '300';

    setState(() {
      for (var day in _availableTimeSlots.keys) {
        _availableTimeSlots[day]!.clear(); // Clear existing slots

        for (int hour = startHour; hour < endHour; hour++) {
          final fromTime = '${hour.toString().padLeft(2, '0')}:00';
          final toTime = '${(hour + 1).toString().padLeft(2, '0')}:00';
          final timeSlotString = '$fromTime - $toTime';

          _availableTimeSlots[day]!.add({
            'time': timeSlotString,
            'price': double.tryParse(defaultPrice) ?? 300.0,
            'available': true,
          });
        }
      }
    });

    _showSuccess('Generated ${endHour - startHour} timeslots for each day!');
  }

  Future<void> _createField() async {
    if (!_formKey.currentState!.validate()) {
      _showError('Please fill all required fields');
      return;
    }

    // Check if at least one time slot is added
    bool hasTimeSlots = _availableTimeSlots.values.any((slots) => slots.isNotEmpty);
    if (!hasTimeSlots) {
      _showError('Please add at least one time slot or use auto-generate');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Upload images
      List<String> photoUrls = [];
      if (_selectedImages.isNotEmpty) {
        print('🖼️ Uploading ${_selectedImages.length} photos...');
        photoUrls = await _uploadImages();
        print('✅ Photos uploaded! URLs: $photoUrls');
      } else {
        print('⚠️ No photos selected');
      }

      // Create field object
      final field = FootballField(
        id: '', // Will be generated by Supabase
        footballFieldName: _nameController.text,
        locationName: _selectedLocation,
        streetName: _streetNameController.text,
        latitude: double.tryParse(_latitudeController.text) ?? 30.0444,
        longitude: double.tryParse(_longitudeController.text) ?? 31.2357,
        openingHours: _openingHoursController.text,
        priceRange: _priceRangeController.text,
        photos: photoUrls,
        availableTimeSlots: _availableTimeSlots,
        amenities: _amenities,
        fieldSize: _fieldSize,
        commissionPercentage: '0',
        bookable: true,
        bookings: [],
        username: _ownerEmailController.text.trim(),
        password: _ownerPasswordController.text.trim(),
        cameraUsername: _amenities['cameraRecording'] == true ? _cameraUsernameController.text.trim() : null,
        cameraPassword: _amenities['cameraRecording'] == true ? _cameraPasswordController.text.trim() : null,
        cameraIpAddress: _amenities['cameraRecording'] == true ? _cameraIpController.text.trim() : null,
        raspberryPiIp: _amenities['cameraRecording'] == true ? _raspberryPiIpController.text.trim() : null,
        routerIp: _amenities['cameraRecording'] == true ? _routerIpController.text.trim() : null,
        simCardNumber: _amenities['cameraRecording'] == true ? _simCardNumberController.text.trim() : null,
        hasCamera: _amenities['cameraRecording'] ?? false,
        ownerName: _ownerNameController.text.trim().isNotEmpty ? _ownerNameController.text.trim() : null,
        ownerPhoneNumber: _ownerPhoneController.text.trim().isNotEmpty ? _ownerPhoneController.text.trim() : null,
        assistants: _getAssistantsList(),
        createdAt: DateTime.now(),
        city: _cityController.text.trim().isNotEmpty ? _cityController.text.trim() : null,
        area: _areaController.text.trim().isNotEmpty ? _areaController.text.trim() : null,
        blockedUsers: [], // New fields start with empty blocklist
      );

      // Debug log for partner credentials
      print('🔑 Partner Portal Credentials:');
      print('   Email: ${field.username}');
      print('   Password: ${field.password}');
      print('📸 Photos to be saved: ${field.photos.length} URLs');

      // Save to Supabase
      await _supabaseService.createFootballField(field);
      print('✅ Field created in Supabase with ${field.photos.length} photos!');

      if (mounted) {
        final successMessage = 'Football field created successfully!\n\n'
            '📸 Photos: ${field.photos.length} uploaded\n'
            'Partner Login:\n'
            'Email: ${field.username}\n'
            'Password: ${field.password}';
        
        _showSuccess(successMessage);
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      _showError('Error creating field: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    // Use CustomSnackbar with copy button for database/API errors
    final isApiError = message.contains('Exception') || 
                       message.contains('Error') || 
                       message.contains('Failed') ||
                       message.contains('Postgrest');
    CustomSnackbar.showError(context, message, showCopyButton: isApiError);
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          'Create Football Field',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Theme(
              data: Theme.of(context).copyWith(
                colorScheme: Theme.of(context).colorScheme.copyWith(
                      primary: Colors.green,
                      secondary: Colors.green,
                    ),
              ),
              child: Stepper(
                type: StepperType.vertical,
                currentStep: _currentStep,
                onStepContinue: _handleStepContinue,
                onStepCancel: _handleStepCancel,
                controlsBuilder: (context, details) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: details.onStepContinue,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              _currentStep == _steps().length - 1 ? 'Create Field' : 'Next',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        if (_currentStep > 0) ...[
                          const SizedBox(width: 16),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: details.onStepCancel,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                side: BorderSide(color: Colors.grey.shade300),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Back',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
                steps: _steps(),
              ),
            ),
    );
  }

  void _handleStepContinue() {
    // Validation logic per step
    switch (_currentStep) {
      case 0: // Basic Info
        if (_nameController.text.isEmpty) {
          _showError('Please enter field name');
          return;
        }
        if (_selectedLocation.isEmpty) {
          _showError('Please select a location');
          return;
        }
        break;
      case 1: // Details
        if (_openingHoursController.text.isEmpty) {
          _showError('Please enter opening hours');
          return;
        }
        if (_priceRangeController.text.isEmpty) {
          _showError('Please enter price range');
          return;
        }
        break;
      case 2: // Photos
        if (_selectedImages.isEmpty) {
          _showError('Please add at least one photo');
          return;
        }
        break;
      case 3: // Time Slots
        bool hasTimeSlots = _availableTimeSlots.values.any((slots) => slots.isNotEmpty);
        if (!hasTimeSlots) {
          _showError('Please add at least one time slot or use auto-generate');
          return;
        }
        break;
      case 4: // Credentials & Contacts
        if (_ownerEmailController.text.isEmpty || !_ownerEmailController.text.contains('@')) {
          _showError('Please enter a valid owner email');
          return;
        }
        if (_ownerPasswordController.text.length < 6) {
          _showError('Password must be at least 6 characters');
          return;
        }
        // If validation passes, create field
        _createField();
        return;
    }

    setState(() {
      if (_currentStep < _steps().length - 1) {
        _currentStep += 1;
      }
    });
  }

  void _handleStepCancel() {
    setState(() {
      if (_currentStep > 0) {
        _currentStep -= 1;
      }
    });
  }

  List<Step> _steps() {
    return [
      Step(
        title: Text('Basic Information', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        subtitle: Text('Name, Location, Size', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
        isActive: _currentStep >= 0,
        state: _currentStep > 0 ? StepState.complete : StepState.indexed,
        content: Column(
          children: [
            _buildTextField(
              controller: _nameController,
              label: 'Field Name',
              icon: Icons.sports_soccer,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _streetNameController,
              label: 'Street Address',
              icon: Icons.location_on,
            ),
            const SizedBox(height: 16),
            _buildDropdown(
              value: _selectedLocation,
              label: 'Location',
              items: _locations,
              onChanged: (value) => setState(() => _selectedLocation = value!),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _cityController,
                    label: 'City',
                    icon: Icons.location_city,
                    hint: 'e.g., Cairo',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    controller: _areaController,
                    label: 'Area',
                    icon: Icons.place,
                    hint: 'e.g., Maadi',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildDropdown(
              value: _fieldSize,
              label: 'Field Size',
              items: _fieldSizes,
              onChanged: (value) => setState(() => _fieldSize = value!),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _latitudeController,
                    label: 'Latitude',
                    icon: Icons.map,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    controller: _longitudeController,
                    label: 'Longitude',
                    icon: Icons.map,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      Step(
        title: Text('Details & Amenities', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        isActive: _currentStep >= 1,
        state: _currentStep > 1 ? StepState.complete : StepState.indexed,
        content: Column(
          children: [
            _buildTextField(
              controller: _openingHoursController,
              label: 'Opening Hours (e.g., 9 AM - 11 PM)',
              icon: Icons.access_time,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _priceRangeController,
              label: 'Price Range (e.g., 200-500)',
              icon: Icons.attach_money,
            ),
            const SizedBox(height: 24),
            Text('Amenities', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 8),
            ..._amenities.entries.map((entry) {
              return CheckboxListTile(
                title: Text(_getAmenityLabel(entry.key), style: GoogleFonts.inter(fontSize: 14)),
                value: entry.value,
                onChanged: (value) {
                  setState(() => _amenities[entry.key] = value ?? false);
                },
                dense: true,
                activeColor: Colors.green,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              );
            }).toList(),
            
            if (_amenities['cameraRecording'] == true) ...[
              const SizedBox(height: 24),
              Text('Camera Configuration', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16)),
              const SizedBox(height: 16),
              _buildTextField(controller: _cameraIpController, label: 'Camera IP', icon: Icons.videocam),
              const SizedBox(height: 12),
              _buildTextField(controller: _cameraUsernameController, label: 'Username', icon: Icons.person),
              const SizedBox(height: 12),
              _buildTextField(controller: _cameraPasswordController, label: 'Password', icon: Icons.lock, obscureText: true),
              const SizedBox(height: 12),
              _buildTextField(controller: _raspberryPiIpController, label: 'Raspberry Pi IP', icon: Icons.computer),
              const SizedBox(height: 12),
              _buildTextField(controller: _routerIpController, label: 'Router IP', icon: Icons.router),
              const SizedBox(height: 12),
              _buildTextField(controller: _simCardNumberController, label: 'SIM Number', icon: Icons.sim_card),
            ],
          ],
        ),
      ),
      Step(
        title: Text('Photos', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        isActive: _currentStep >= 2,
        state: _currentStep > 2 ? StepState.complete : StepState.indexed,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_selectedImages.isNotEmpty)
              Container(
                height: 120,
                margin: const EdgeInsets.only(bottom: 16),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedImages.length,
                  itemBuilder: (context, index) {
                    return FutureBuilder<Uint8List>(
                      future: _selectedImages[index].readAsBytes(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const SizedBox(width: 120, child: Center(child: CircularProgressIndicator()));
                        return Container(
                          width: 120,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(
                              image: MemoryImage(snapshot.data!),
                              fit: BoxFit.cover,
                            ),
                          ),
                          child: Stack(
                            children: [
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () => setState(() => _selectedImages.removeAt(index)),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                    child: const Icon(Icons.close, color: Colors.white, size: 16),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            Center(
              child: ElevatedButton.icon(
                onPressed: _pickImages,
                icon: const Icon(Icons.add_photo_alternate),
                label: const Text('Select Photos'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade50,
                  foregroundColor: Colors.blue.shade700,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
      Step(
        title: Text('Time Slots', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        isActive: _currentStep >= 3,
        state: _currentStep > 3 ? StepState.complete : StepState.indexed,
        content: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.blue),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Quick Generate', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                        Text('Create slots based on opening hours', style: GoogleFonts.inter(fontSize: 12, color: Colors.blue.shade700)),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _autoGenerateTimeslots,
                    child: const Text('Generate'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ..._availableTimeSlots.entries.map((entry) {
              final day = entry.key;
              final slots = entry.value;
              if (slots.isEmpty) {
                return ExpansionTile(
                  title: Text(day, style: GoogleFonts.inter(fontSize: 14)),
                  trailing: TextButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add'),
                    onPressed: () => _addTimeSlot(day),
                  ),
                );
              }
              return ExpansionTile(
                title: Text(day, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                subtitle: Text('${slots.length} slots', style: GoogleFonts.inter(color: Colors.green)),
                children: [
                  ...slots.asMap().entries.map((e) => ListTile(
                    dense: true,
                    title: Text(e.value['time']),
                    subtitle: Text('${e.value['price']} EGP'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                      onPressed: () => _removeTimeSlot(day, e.key),
                    ),
                  )),
                  ListTile(
                    leading: const Icon(Icons.add, color: Colors.green),
                    title: const Text('Add another slot'),
                    onTap: () => _addTimeSlot(day),
                  ),
                ],
              );
            }).toList(),
          ],
        ),
      ),
      Step(
        title: Text('Credentials & Contacts', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        isActive: _currentStep >= 4,
        state: _currentStep > 4 ? StepState.complete : StepState.indexed,
        content: Column(
          children: [
            _buildTextField(
              controller: _ownerEmailController,
              label: 'Owner Email (Login)',
              icon: Icons.email,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _ownerPasswordController,
              label: 'Owner Password',
              icon: Icons.lock,
              obscureText: true,
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            Text('Contact Information', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _ownerNameController,
              label: 'Owner Name',
              icon: Icons.person,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _ownerPhoneController,
              label: 'Owner Phone',
              icon: Icons.phone,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Assistants', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                TextButton.icon(
                  onPressed: _addAssistant,
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            ),
            ..._assistantControllers.asMap().entries.map((entry) {
              final index = entry.key;
              return Card(
                margin: const EdgeInsets.only(top: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Assistant ${index + 1}', style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                            onPressed: () => _removeAssistant(index),
                          ),
                        ],
                      ),
                      _buildTextField(
                        controller: entry.value['name']!,
                        label: 'Name',
                        icon: Icons.person_outline,
                      ),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: entry.value['phone']!,
                        label: 'Phone',
                        icon: Icons.phone_android,
                        keyboardType: TextInputType.phone,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    ];
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    String? hint,
    bool obscureText = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon != null ? Icon(icon, size: 20) : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.green, width: 2),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required String label,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      items: items.map((item) {
        return DropdownMenuItem(
          value: item,
          child: Text(item),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  String _getAmenityLabel(String key) {
    const labels = {
      'parking': 'Parking',
      'toilets': 'Toilets',
      'cafeteria': 'Cafeteria',
      'floodlights': 'Floodlights',
      'qualityField': 'Quality Field',
      'ballIncluded': 'Ball Included',
      'cameraRecording': 'Camera Recording',
    };
    return labels[key] ?? key;
  }
}

