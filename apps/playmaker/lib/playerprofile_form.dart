import 'package:country_picker/country_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:playmakerappstart/color_class.dart';
import 'package:playmakerappstart/login_screen/login_screen.dart';
import 'package:playmakerappstart/models/user_model.dart';
import 'package:playmakerappstart/position_level_screen.dart';
import 'package:playmakerappstart/utils/validators.dart';
import 'package:playmakerappstart/widgets/custom_snackbar.dart';

class PlayerProfileFormScreen extends StatefulWidget {
  final PlayerProfile userModel;
  final bool appleSignIn;
  
  const PlayerProfileFormScreen({
    Key? key, 
    required this.userModel, 
    this.appleSignIn = false,
  }) : super(key: key);

  @override
  _PlayerProfileFormScreenState createState() => _PlayerProfileFormScreenState();
}

class _PlayerProfileFormScreenState extends State<PlayerProfileFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late String nationality = '', name = '', preferredPosition = '';
  late String personalLevel = '';
  DateTime? selectedBirthDate;
  Country? selectedCountry;
  bool _isFormFilled = false;
  bool _isLoading = false;
  String? _nameError;
  String? _phoneError;
  String? _birthDateError;

  final List<Map<String, String>> positions = [
    {
      'title': 'Goalkeeper (GK)',
      'description': 'The shot-stopper who also starts plays with throws and passes.',
      'icon': '/api/placeholder/80/80'
    },
    {
      'title': 'Last Man Defender',
      'description': 'The most defensive outfield player, acting as the backbone of the team.',
      'icon': '/api/placeholder/80/80'
    },
    {
      'title': 'Winger',
      'description': 'A fast, technical player responsible for creating chances and scoring.',
      'icon': '/api/placeholder/80/80'
    },
    {
      'title': 'Striker',
      'description': 'A forward who plays with their back to goal, holding up play and finishing chances.',
      'icon': '/api/placeholder/80/80'
    },
    {
      'title': 'All Rounder',
      'description': 'A player comfortable in multiple roles, adapting as needed.',
      'icon': '/api/placeholder/80/80'
    }
  ];
  
  final List<Map<String, String>> levels = [
    {
      'title': 'Beginner',
      'description': 'New to football, learning the basics.',
    },
    {
      'title': 'Casual',
      'description': 'Plays regularly, understands the game.',
    },
    {
      'title': 'Skilled',
      'description': 'Good technical skills, tactical awareness.',
    },
    {
      'title': 'Elite',
      'description': 'Strong player, makes an impact.',
    },
    {
      'title': 'Expert',
      'description': 'High-level skills, dominates matches.',
    }
  ];
  
  final _phoneController = TextEditingController();
  String _selectedCountryDialCode = '20';
  String _selectedCountryCode = 'EG';
  final TextEditingController _dayController = TextEditingController();
  final TextEditingController _monthController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();
  final FocusNode _dayFocusNode = FocusNode();
  final FocusNode _monthFocusNode = FocusNode();
  final FocusNode _yearFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _initializeData();
    _dayController.addListener(_updateDateFromControllers);
    _monthController.addListener(_updateDateFromControllers);
    _yearController.addListener(_updateDateFromControllers);
  }

  @override
  void dispose() {
    _dayController.dispose();
    _monthController.dispose();
    _yearController.dispose();
    _dayFocusNode.dispose();
    _monthFocusNode.dispose();
    _yearFocusNode.dispose();
    super.dispose();
  }

  void _initializeData() {
    preferredPosition = widget.userModel.preferredPosition;
    personalLevel = widget.userModel.personalLevel;
    nationality = widget.userModel.nationality;
    name = widget.userModel.name;
    
    if (widget.userModel.age.isNotEmpty) {
      try {
        int age = int.parse(widget.userModel.age);
        selectedBirthDate = DateTime.now().subtract(Duration(days: age * 365));
      } catch (e) {
        selectedBirthDate = null;
      }
    }
    
    _phoneController.text = widget.userModel.phoneNumber.replaceAll('+', '');
    _updateFormFilledStatus();
  }

  void _updateFormFilledStatus() {
    setState(() {
      // Name is always required
      _isFormFilled = name.trim().isNotEmpty;
      
      // Validate name in real-time
      if (name.isNotEmpty) {
        _nameError = Validators.validateName(name);
      } else {
        _nameError = null;
      }
    });
  }

  void _validatePhoneNumber() {
    setState(() {
      final fullPhone = '+$_selectedCountryDialCode${_phoneController.text}';
      _phoneError = Validators.validatePhone(fullPhone);
    });
  }

  void _updateDateFromControllers() {
    // Only update the date, don't show errors while typing
    if (_dayController.text.isNotEmpty && 
        _monthController.text.isNotEmpty && 
        _yearController.text.isNotEmpty) {
      try {
        final day = int.parse(_dayController.text);
        final month = int.parse(_monthController.text);
        final year = int.parse(_yearController.text);
        
        if (day >= 1 && day <= 31 && month >= 1 && month <= 12 && year >= 1900) {
          try {
            final date = DateTime(year, month, day);
            setState(() {
              selectedBirthDate = date;
            });
            return;
          } catch (e) {
            // Invalid date combination (e.g., Feb 30)
          }
        }
      } catch (e) {
        // Invalid numbers
      }
    }
    setState(() {
      selectedBirthDate = null;
    });
  }
  
  /// Validate birth date fields and return error message if invalid
  String? _validateBirthDateFields() {
    // If all fields are empty, birth date is optional
    if (_dayController.text.isEmpty && 
        _monthController.text.isEmpty && 
        _yearController.text.isEmpty) {
      return null;
    }
    
    // If any field is filled, all must be filled
    if (_dayController.text.isEmpty || 
        _monthController.text.isEmpty || 
        _yearController.text.isEmpty) {
      return 'Please complete all birth date fields (DD/MM/YYYY)';
    }
    
    try {
      final day = int.parse(_dayController.text);
      final month = int.parse(_monthController.text);
      final year = int.parse(_yearController.text);
      
      // Validate day
      if (day < 1 || day > 31) {
        _dayFocusNode.requestFocus();
        return 'Day must be between 1 and 31';
      }
      
      // Validate month
      if (month < 1 || month > 12) {
        _monthFocusNode.requestFocus();
        return 'Month must be between 1 and 12';
      }
      
      // Validate year
      final currentYear = DateTime.now().year;
      if (year < 1900) {
        _yearFocusNode.requestFocus();
        return 'Year must be 1900 or later';
      }
      if (year > currentYear) {
        _yearFocusNode.requestFocus();
        return 'Year cannot be in the future';
      }
      
      // Try to create the date to check if it's valid (e.g., not Feb 30)
      try {
        final date = DateTime(year, month, day);
        
        // Check if the date is not in the future
        if (date.isAfter(DateTime.now())) {
          return 'Birth date cannot be in the future';
        }
        
        // Validate age
        return Validators.validateAge(date);
      } catch (e) {
        _dayFocusNode.requestFocus();
        return 'Invalid date (e.g., February 30th doesn\'t exist)';
      }
    } catch (e) {
      return 'Please enter valid numbers';
    }
  }

  Future<void> _showCancelConfirmation() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Cancel Registration?',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        content: Text(
          'Are you sure you want to cancel? Your account will be deleted and you\'ll need to register again.',
          style: GoogleFonts.inter(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Continue Registration',
              style: GoogleFonts.inter(
                color: AppColors.backgroundColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: Text(
              'Cancel & Delete',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        await FirebaseAuth.instance.currentUser?.delete();
      } catch (e) {
        print('Error deleting user: $e');
      }
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginWithPasswordScreen()),
        );
      }
    }
  }

  Widget _buildSectionTitle(String title) {
    final bool isOptional = title.toLowerCase().contains('optional');
    final String displayTitle = isOptional ? title.replaceAll(' (Optional)', '') : title;
    
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Row(
        children: [
          Text(
            displayTitle,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (isOptional) ...[
            const SizedBox(width: 4),
            Text(
              '(Optional)',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _navigateToPositionLevelScreen() async {
    // Validate name (always required)
    final nameValidation = Validators.validateName(name);
    if (nameValidation != null) {
      _showErrorDialog('Invalid Name', nameValidation);
      setState(() => _nameError = nameValidation);
      return;
    }

    // Validate phone if provided
    if (_phoneController.text.isNotEmpty) {
      final fullPhone = '+$_selectedCountryDialCode${_phoneController.text}';
      final phoneValidation = Validators.validatePhone(fullPhone);
      if (phoneValidation != null) {
        _showErrorDialog('Invalid Phone Number', phoneValidation);
        setState(() => _phoneError = phoneValidation);
        return;
      }
    }

    // Validate birth date fields
    final birthDateValidation = _validateBirthDateFields();
    if (birthDateValidation != null) {
      _showErrorDialog('Invalid Birth Date', birthDateValidation);
      setState(() => _birthDateError = birthDateValidation);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final playerId = (DateTime.now().millisecondsSinceEpoch % 10000000).toString().padLeft(7, '0');
      
      final updatedProfile = widget.userModel.copyWith(
        playerId: playerId,
        name: name.trim(),
        age: selectedBirthDate != null ? calculateAge(selectedBirthDate!).toString() : '',
        favouriteClub: '',
        nationality: nationality,
        phoneNumber: _phoneController.text.isNotEmpty 
            ? '+$_selectedCountryDialCode${_phoneController.text}' 
            : '',
      );

      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => PositionLevelScreen(userModel: updatedProfile)),
        );
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.showError(context, 'Error updating profile. Please try again.');
        setState(() => _isLoading = false);
      }
    }
  }

  int calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month || 
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }
  
  /// Show error dialog with the error message
  Future<void> _showErrorDialog(String title, String message) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade400, size: 28),
            const SizedBox(width: 12),
            Text(
              title,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: Colors.red.shade700,
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: GoogleFonts.inter(fontSize: 15, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'OK',
              style: GoogleFonts.inter(
                color: AppColors.backgroundColor,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          title: const Text(
            'Complete Your Profile',
            style: TextStyle(
              color: Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
            onPressed: _showCancelConfirmation,
            tooltip: 'Cancel registration',
          ),
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'Personal Information',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.backgroundColor,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Always show name field (Apple may not provide name after first sign-in)
                _buildSectionTitle('FULL NAME'),
                _buildTextField(
                  initialValue: name,
                  errorText: _nameError,
                  onChanged: (value) {
                    name = value;
                    _updateFormFilledStatus();
                  },
                  validator: (value) => value?.isEmpty ?? true ? 'Name is required' : null,
                ),
                const SizedBox(height: 24),

                _buildSectionTitle('PHONE NUMBER'),
                _buildPhoneField(),
                const SizedBox(height: 24),
                
                _buildSectionTitle('BIRTH DATE (Optional)'),
                _buildBirthDateField(),
                const SizedBox(height: 24),

                _buildSectionTitle('NATIONALITY (Optional)'),
                _buildSelectionTile(
                  title: nationality.isEmpty ? 'Select your nationality' : nationality,
                  leading: selectedCountry?.flagEmoji,
                  onTap: () => _showCountryPicker(context),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: SafeArea(
            child: ElevatedButton(
              onPressed: _isFormFilled && !_isLoading ? _navigateToPositionLevelScreen : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.backgroundColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Next',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String initialValue,
    required Function(String) onChanged,
    required String? Function(String?) validator,
    String? errorText,
  }) {
    return TextFormField(
      initialValue: initialValue,
      onChanged: onChanged,
      validator: validator,
      textInputAction: TextInputAction.next,
      style: const TextStyle(fontSize: 16),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        errorText: errorText,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.backgroundColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
      ),
    );
  }

  Widget _buildSelectionTile({
    required String title,
    String? leading,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            if (leading != null) ...[
              Text(leading, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  color: title.contains('Select') ? Colors.grey : Colors.black,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  void _showCountryPicker(BuildContext context) {
    showCountryPicker(
      context: context,
      favorite: const ['EG'],
      countryListTheme: CountryListThemeData(
        flagSize: 25,
        backgroundColor: Colors.white,
        textStyle: const TextStyle(fontSize: 16),
        bottomSheetHeight: MediaQuery.of(context).size.height * 0.7,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        inputDecoration: InputDecoration(
          labelText: 'Search',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
        ),
      ),
      onSelect: (Country country) {
        setState(() {
          selectedCountry = country;
          nationality = country.name;
          _updateFormFilledStatus();
        });
      },
    );
  }

  Widget _buildBirthDateField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          // Day input
          Expanded(
            child: TextField(
              controller: _dayController,
              focusNode: _dayFocusNode,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 2,
              onChanged: (value) {
                // Clear error when user starts typing
                if (_birthDateError != null) {
                  setState(() => _birthDateError = null);
                }
                if (value.length == 2) {
                  // Move to month field when 2 digits are entered
                  FocusScope.of(context).nextFocus();
                }
              },
              decoration: InputDecoration(
                counterText: '',
                hintText: 'DD',
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: _birthDateError != null && _dayFocusNode.hasFocus 
                        ? Colors.red 
                        : Colors.grey.shade300,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: _birthDateError != null && _dayFocusNode.hasFocus 
                        ? Colors.red 
                        : Colors.grey.shade300,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: _birthDateError != null && _dayFocusNode.hasFocus 
                        ? Colors.red 
                        : AppColors.backgroundColor,
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('/', style: TextStyle(color: Colors.grey.shade400, fontSize: 20)),
          ),
          // Month input
          Expanded(
            child: TextField(
              controller: _monthController,
              focusNode: _monthFocusNode,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 2,
              onChanged: (value) {
                // Clear error when user starts typing
                if (_birthDateError != null) {
                  setState(() => _birthDateError = null);
                }
                if (value.length == 2) {
                  // Move to year field when 2 digits are entered
                  FocusScope.of(context).nextFocus();
                }
              },
              decoration: InputDecoration(
                counterText: '',
                hintText: 'MM',
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: _birthDateError != null && _monthFocusNode.hasFocus 
                        ? Colors.red 
                        : Colors.grey.shade300,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: _birthDateError != null && _monthFocusNode.hasFocus 
                        ? Colors.red 
                        : Colors.grey.shade300,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: _birthDateError != null && _monthFocusNode.hasFocus 
                        ? Colors.red 
                        : AppColors.backgroundColor,
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('/', style: TextStyle(color: Colors.grey.shade400, fontSize: 20)),
          ),
          // Year input
          Expanded(
            flex: 2,
            child: TextField(
              controller: _yearController,
              focusNode: _yearFocusNode,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 4,
              onChanged: (value) {
                // Clear error when user starts typing
                if (_birthDateError != null) {
                  setState(() => _birthDateError = null);
                }
                if (value.length == 4) {
                  // Dismiss keyboard when year is complete
                  FocusScope.of(context).unfocus();
                }
              },
              decoration: InputDecoration(
                counterText: '',
                hintText: 'YYYY',
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: _birthDateError != null && _yearFocusNode.hasFocus 
                        ? Colors.red 
                        : Colors.grey.shade300,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: _birthDateError != null && _yearFocusNode.hasFocus 
                        ? Colors.red 
                        : Colors.grey.shade300,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: _birthDateError != null && _yearFocusNode.hasFocus 
                        ? Colors.red 
                        : AppColors.backgroundColor,
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _showPhoneCountryPicker(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                border: Border(right: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Text(
                    countryCodeToFlag(_selectedCountryCode),
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '+$_selectedCountryDialCode',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const Icon(Icons.keyboard_arrow_down, color: Colors.black54),
                ],
              ),
            ),
          ),
          Expanded(
            child: TextFormField(
              controller: _phoneController,
              style: const TextStyle(fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Phone number',
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                errorText: _phoneError,
                errorStyle: const TextStyle(fontSize: 12),
              ),
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              enableInteractiveSelection: true,
              onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
              onChanged: (value) {
                _updateFormFilledStatus();
                if (value.length > 6) {
                  _validatePhoneNumber();
                } else {
                  setState(() => _phoneError = null);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  String countryCodeToFlag(String countryCode) {
    return countryCode.toUpperCase().replaceAllMapped(
          RegExp(r'[A-Z]'),
          (match) => String.fromCharCode(match.group(0)!.codeUnitAt(0) + 127397),
        );
  }

  void _showPhoneCountryPicker() {
    showCountryPicker(
      context: context,
      favorite: const ['EG'],
      countryListTheme: CountryListThemeData(
        flagSize: 25,
        backgroundColor: Colors.white,
        textStyle: const TextStyle(fontSize: 16),
        bottomSheetHeight: MediaQuery.of(context).size.height * 0.7,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        inputDecoration: InputDecoration(
          labelText: 'Search',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
        ),
      ),
      onSelect: (Country country) {
        setState(() {
          _selectedCountryDialCode = country.phoneCode;
          _selectedCountryCode = country.countryCode;
        });
      },
    );
  }
}
