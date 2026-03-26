import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:playmakerappstart/custom_dialoag.dart';
import 'package:playmakerappstart/login_screen/login_screen.dart';
import 'package:playmakerappstart/login_screen/login_screen_bloc.dart';
import 'package:playmakerappstart/models/user_model.dart';
import 'package:country_picker/country_picker.dart';
import 'package:playmakerappstart/privacy_policy_modal.dart';
import 'package:playmakerappstart/services/supabase_service.dart';
import 'package:playmakerappstart/positions_bottom_sheet.dart';
import 'package:playmakerappstart/friends_screen.dart';
import 'package:playmakerappstart/tabs/matches_tab.dart';
import 'package:playmakerappstart/mysquads_screen.dart';
import 'package:intl/intl.dart';

import 'package:playmakerappstart/terms_conditions_modal.dart';
import 'package:playmakerappstart/position_level_screen.dart';
import 'package:playmakerappstart/language_settings_screen.dart';
import 'package:playmakerappstart/localization/app_localizations.dart';

class ProfileScreen extends StatefulWidget {
  final PlayerProfile playerProfile;

  const ProfileScreen({
    super.key, 
    required this.playerProfile,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _supabaseService = SupabaseService();
  final _authenticationBloc = AuthenticationBloc();
  final _picker = ImagePicker();
  late PlayerProfile _currentPlayerProfile;
  
  bool _isLoading = false;
  File? _image;
  final _brandColor = const Color(0xFF00BF63);
  List<int> birthYears = [];

  @override
  void initState() {
    super.initState();
    _currentPlayerProfile = widget.playerProfile;
    _initializeBirthYears();
  }

  void _initializeBirthYears() {
    int currentYear = DateTime.now().year;
    birthYears = List.generate(100, (index) => currentYear - index);
  }

  void _showNationalityPicker() {
    showCountryPicker(
      context: context,
      favorite: const ['EG'],
      countryListTheme: CountryListThemeData(
        flagSize: 25,
        backgroundColor: Colors.white,
        textStyle: GoogleFonts.inter(fontSize: 16),
        bottomSheetHeight: MediaQuery.of(context).size.height * 0.7,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        inputDecoration: InputDecoration(
          labelText: context.loc.search,
          labelStyle: GoogleFonts.inter(),
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
        ),
      ),
      onSelect: (Country country) async {
        await _supabaseService.updateUserField(
          _currentPlayerProfile.id,
          'nationality',
          country.name,
        );
        if (mounted) {
          setState(() {
            _currentPlayerProfile = _currentPlayerProfile.copyWith(nationality: country.name);
          });
        }
      },
    );
  }

  void _showBirthDatePicker() {
    final TextEditingController dayController = TextEditingController();
    final TextEditingController monthController = TextEditingController();
    final TextEditingController yearController = TextEditingController();

    if (_currentPlayerProfile.age.isNotEmpty) {
      try {
        final birthDate = DateTime.now().subtract(Duration(days: int.parse(_currentPlayerProfile.age) * 365));
        dayController.text = birthDate.day.toString().padLeft(2, '0');
        monthController.text = birthDate.month.toString().padLeft(2, '0');
        yearController.text = birthDate.year.toString();
      } catch (e) {
        // Invalid age format
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(context.loc.cancel, style: GoogleFonts.inter()),
                  ),
                  Text(
                    context.loc.birthDateTitle,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      if (dayController.text.isNotEmpty &&
                          monthController.text.isNotEmpty &&
                          yearController.text.isNotEmpty) {
                        try {
                          final day = int.parse(dayController.text);
                          final month = int.parse(monthController.text);
                          final year = int.parse(yearController.text);
                          
                          if (day >= 1 && day <= 31 && month >= 1 && month <= 12) {
                            final date = DateTime(year, month, day);
                            final now = DateTime.now();
                            int age = now.year - date.year;
                            if (now.month < date.month ||
                                (now.month == date.month && now.day < date.day)) {
                              age--;
                            }
                            
                            if (age >= 5 && age <= 100) {
                              await _supabaseService.updateUserField(
                                _currentPlayerProfile.id,
                                'age',
                                age.toString(),
                              );
                              if (mounted) {
                                setState(() {
                                  _currentPlayerProfile = _currentPlayerProfile.copyWith(age: age.toString());
                                });
                                Navigator.pop(context);
                              }
                            }
                          }
                        } catch (e) {
                          // Invalid date
                        }
                      }
                    },
                    child: Text(context.loc.done, style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildDateInput(dayController, context.loc.hintDD, 2),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text('/', style: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 20)),
                  ),
                  Expanded(
                    child: _buildDateInput(monthController, context.loc.hintMM, 2),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text('/', style: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 20)),
                  ),
                  Expanded(
                    flex: 2,
                    child: _buildDateInput(yearController, context.loc.hintYYYY, 4, isLast: true),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateInput(TextEditingController controller, String hint, int maxLength, {bool isLast = false}) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      maxLength: maxLength,
      style: GoogleFonts.inter(fontSize: 16),
      onChanged: (value) {
        if (value.length == maxLength && !isLast) {
          FocusScope.of(context).nextFocus();
        } else if (value.length == maxLength && isLast) {
          FocusScope.of(context).unfocus();
        }
      },
      decoration: InputDecoration(
        counterText: '',
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: Colors.grey[400]),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _brandColor),
        ),
      ),
    );
  }

  void _showPhoneNumberPicker() {
    final TextEditingController phoneController = TextEditingController();
    String selectedCountryDialCode = '20';
    String selectedCountryCode = 'EG';

    if (_currentPlayerProfile.phoneNumber.isNotEmpty) {
      final phone = _currentPlayerProfile.phoneNumber;
      if (phone.startsWith('+')) {
        phoneController.text = phone.substring(phone.indexOf(selectedCountryDialCode) + selectedCountryDialCode.length);
      } else {
        phoneController.text = phone;
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(context.loc.cancel, style: GoogleFonts.inter()),
                  ),
                  Text(
                    context.loc.phoneNumberTitle,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      if (phoneController.text.isNotEmpty) {
                        final newPhoneNumber = '+$selectedCountryDialCode${phoneController.text}';
                        await _supabaseService.updateUserField(
                          _currentPlayerProfile.id,
                          'phoneNumber',
                          newPhoneNumber,
                        );
                        if (mounted) {
                          setModalState(() {});
                          setState(() {
                            _currentPlayerProfile = _currentPlayerProfile.copyWith(phoneNumber: newPhoneNumber);
                          });
                          Navigator.pop(context);
                        }
                      }
                    },
                    child: Text(context.loc.done, style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        showCountryPicker(
                          context: context,
                          favorite: const ['EG'],
                          countryListTheme: CountryListThemeData(
                            flagSize: 25,
                            backgroundColor: Colors.white,
                            textStyle: GoogleFonts.inter(fontSize: 16),
                            bottomSheetHeight: MediaQuery.of(context).size.height * 0.7,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                            inputDecoration: InputDecoration(
                              labelText: context.loc.search,
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade200),
                              ),
                            ),
                          ),
                          onSelect: (Country country) {
                            setModalState(() {
                              selectedCountryDialCode = country.phoneCode;
                              selectedCountryCode = country.countryCode;
                            });
                          },
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        decoration: BoxDecoration(
                          border: Border(right: BorderSide(color: Colors.grey.shade200)),
                        ),
                        child: Row(
                          children: [
                            Text(
                              countryCodeToFlag(selectedCountryCode),
                              style: const TextStyle(fontSize: 20),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '+$selectedCountryDialCode',
                              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500),
                            ),
                            const Icon(Icons.keyboard_arrow_down, color: Colors.black54),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: phoneController,
                        style: GoogleFonts.inter(fontSize: 16),
                        decoration: InputDecoration(
                          hintText: context.loc.hintPhoneNumber,
                          hintStyle: GoogleFonts.inter(color: Colors.grey[400]),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => FocusScope.of(context).unfocus(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPositionPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PositionsBottomSheetModal(
        currentPosition: _currentPlayerProfile.preferredPosition,
        onPositionSelected: (String newPosition) async {
          await _supabaseService.updateUserField(
            _currentPlayerProfile.id,
            'preferredPosition',
            newPosition,
          );
          if (mounted) {
            setState(() {
              _currentPlayerProfile = _currentPlayerProfile.copyWith(preferredPosition: newPosition);
            });
          }
        },
      ),
    );
  }

  void _showNameEditor() {
    final TextEditingController nameController = TextEditingController(text: _currentPlayerProfile.name);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(context.loc.cancel, style: GoogleFonts.inter()),
                  ),
                  Text(
                    context.loc.fullNameTitle,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      if (nameController.text.trim().isNotEmpty) {
                        await _supabaseService.updateUserField(
                          _currentPlayerProfile.id,
                          'name',
                          nameController.text.trim(),
                        );
                        if (mounted) {
                          setState(() {
                            _currentPlayerProfile = _currentPlayerProfile.copyWith(name: nameController.text.trim());
                          });
                          Navigator.pop(context);
                        }
                      }
                    },
                    child: Text(context.loc.done, style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                autofocus: true,
                style: GoogleFonts.inter(fontSize: 16),
                decoration: InputDecoration(
                  hintText: context.loc.hintEnterFullName,
                  hintStyle: GoogleFonts.inter(color: Colors.grey[400]),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _brandColor, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showLevelPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LevelBottomSheetModal(
        currentLevel: _currentPlayerProfile.personalLevel,
        gamesPlayed: _currentPlayerProfile.numberOfGames,
        onLevelSelected: (String newLevel) async {
          await _supabaseService.updateUserField(
            _currentPlayerProfile.id,
            'personalLevel',
            newLevel,
          );
          if (mounted) {
            setState(() {
              _currentPlayerProfile = _currentPlayerProfile.copyWith(personalLevel: newLevel);
            });
          }
        },
      ),
    );
  }

  Future<void> _pickImageAndUpdateProfile() async {
    setState(() => _isLoading = true);
    
    try {
      final image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        final imageFile = File(image.path);
        await _supabaseService.updateUserProfilePicture(
          _currentPlayerProfile.id,
          imageFile,
        );
        
        final updatedProfileData = await _supabaseService.getUserModel(_currentPlayerProfile.id);
        if (updatedProfileData != null) {
          setState(() {
            _image = imageFile;
            _currentPlayerProfile = updatedProfileData;
          });
        } else {
          print(context.loc.couldNotFetchUpdatedProfile);
        }
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteAccount() async {
    final TextEditingController confirmController = TextEditingController();
    final confirmationWord = "playmaker";
    bool isConfirmationValid = false;

    final bool confirmed = await CustomDialog.show(
      context: context,
      title: context.loc.deleteAccount,
      message: context.loc.deleteAccountWarningMessage,
      confirmText: context.loc.deleteAccount,
      cancelText: context.loc.cancel,
      isDestructive: true,
      icon: Icons.delete_forever,
      confirmColor: Colors.red,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const Divider(height: 32),
                  Text(
                    context.loc.typeToConfirmDeletion(confirmationWord),
                    style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: confirmController,
                    style: GoogleFonts.inter(),
                    decoration: InputDecoration(
                      hintText: confirmationWord,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.red),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: (value) {
                      setState(() {
                        isConfirmationValid = value.toLowerCase() == confirmationWord;
                      });
                    },
                  ),
                  if (confirmController.text.isNotEmpty && !isConfirmationValid)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        context.loc.pleaseTypeExactly(confirmationWord),
                        style: GoogleFonts.inter(color: Colors.red, fontSize: 12),
                      ),
                    ),
                ],
              ),
            );
          }
        );
      },
      onConfirm: isConfirmationValid ? () async {
        await _performAccountDeletion();
      } : null,
    ) ?? false;

    if (confirmed && isConfirmationValid) {
      await _performAccountDeletion();
    }
  }

  Future<void> _performAccountDeletion() async {
    setState(() => _isLoading = true);
    try {
      await _supabaseService.deleteUserProfile();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.loc.accountDeletedSuccess),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginWithPasswordScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      print('Error deleting account: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.loc.errorDeletingAccount(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showLogoutDialog() {
    CustomDialog.show(
      context: context,
      title: context.loc.logout,
      message: context.loc.logoutConfirmationMessage,
      confirmText: context.loc.logout,
      cancelText: context.loc.cancel,
      icon: Icons.logout_rounded,
      isDestructive: true,
      onConfirm: () => _authenticationBloc.logOut(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    final country = Country.tryParse(_currentPlayerProfile.nationality) ?? Country.worldWide;

    if (_currentPlayerProfile.isGuest) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: _brandColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.account_circle_outlined,
                    size: 80,
                    color: _brandColor,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  context.loc.createProfileTitle,
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  context.loc.signUpToAccessFeatures,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                _buildFeatureItem(
                  icon: Icons.sports_soccer,
                  text: context.loc.featureBookFields,
                ),
                const SizedBox(height: 12),
                _buildFeatureItem(
                  icon: Icons.group,
                  text: context.loc.featureJoinCreateSquads,
                ),
                const SizedBox(height: 12),
                _buildFeatureItem(
                  icon: Icons.calendar_today,
                  text: context.loc.featureScheduleMatches,
                ),
                const SizedBox(height: 12),
                _buildFeatureItem(
                  icon: Icons.person_add,
                  text: context.loc.featureConnectPlayers,
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => const LoginWithPasswordScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brandColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    context.loc.getStarted,
                    style: GoogleFonts.inter(
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

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250,
            floating: false,
            pinned: true,
            backgroundColor: _brandColor,
            elevation: 0,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      _brandColor,
                      _brandColor.withOpacity(0.8),
                    ],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    _buildProfileImage(),
                    const SizedBox(height: 16),
                    Text(
                      _currentPlayerProfile.name,
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      _currentPlayerProfile.email,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  _buildStatsRow(),
                  const SizedBox(height: 28),
                  
                  _buildProfileSection(
                    context.loc.personalInformation,
                    [
                      _ProfileItem(
                        icon: Icons.person_outline,
                        label: context.loc.name,
                        value: _currentPlayerProfile.name,
                      ),
                      _ProfileItem(
                        icon: Icons.cake_outlined,
                        label: context.loc.age,
                        value: _currentPlayerProfile.age,
                      ),
                      _ProfileItem(
                        icon: Icons.phone_outlined,
                        label: context.loc.phoneLabel, 
                        value: _currentPlayerProfile.phoneNumber,
                      ),
                      _ProfileItem(
                        icon: Icons.public_outlined,
                        label: context.loc.nationality,
                        value: "${country.flagEmoji} ${country.name}",
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildProfileSection(
                    context.loc.playerDetails,
                    [
                      _ProfileItem(
                        icon: Icons.badge_outlined,
                        label: context.loc.playerId,
                        value: _currentPlayerProfile.playerId ?? "",
                      ),
                      _ProfileItem(
                        icon: Icons.sports_soccer_outlined,
                        label: context.loc.position,
                        value: _currentPlayerProfile.preferredPosition,
                      ),
                      _ProfileItem(
                        icon: Icons.trending_up_outlined,
                        label: context.loc.level,
                        value: _currentPlayerProfile.personalLevel,
                      ),
                      _ProfileItem(
                        icon: Icons.calendar_today_outlined,
                        label: context.loc.joined,
                        value: _formatJoinedDate(_currentPlayerProfile.joined),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  
                  _buildSettingsSection(),
                  
                  const SizedBox(height: 24),
                  _buildLogoutButton(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileImage() {
    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: CircleAvatar(
            radius: 60,
            backgroundColor: Colors.grey[50],
            backgroundImage: _image != null
                ? FileImage(_image!)
                : _currentPlayerProfile.profilePicture.isNotEmpty
                    ? NetworkImage(_currentPlayerProfile.profilePicture) as ImageProvider
                    : null,
            child: _isLoading
                ? CircularProgressIndicator(color: _brandColor)
                : _image == null && _currentPlayerProfile.profilePicture.isEmpty
                    ? Icon(Icons.person, size: 40, color: Colors.grey[300])
                    : null,
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: GestureDetector(
            onTap: _pickImageAndUpdateProfile,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _brandColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStatItem(context.loc.statGames, _currentPlayerProfile.numberOfGames.toString(), onTap: () {
              if (!_currentPlayerProfile.isGuest) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => MatchesScreen(
                      userModel: _currentPlayerProfile,
                    ),
                  ),
                );
              }
            }),
            _buildVerticalDivider(),
            _buildStatItem(context.loc.statFriends, _currentPlayerProfile.numberOfFriends.toString(), onTap: () {
              if (!_currentPlayerProfile.isGuest) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => FriendsScreen(
                      playerProfile: _currentPlayerProfile,
                    ),
                  ),
                );
              }
            }),
            _buildVerticalDivider(),
            _buildStatItem(context.loc.statSquads, _currentPlayerProfile.numberOfSquads.toString(), onTap: () {
              if (!_currentPlayerProfile.isGuest) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => MySquadScreen(
                      playerProfile: _currentPlayerProfile,
                    ),
                  ),
                );
              }
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      height: 40,
      width: 1,
      color: Colors.grey[200],
    );
  }

  Widget _buildStatItem(String label, String value, {VoidCallback? onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _brandColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileSection(String title, List<_ProfileItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: items.map(_buildProfileItem).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileItem(_ProfileItem item) {
    final bool isEditable = item.label == context.loc.age || 
                          item.label == context.loc.nationality || 
                          item.label == context.loc.phoneLabel || 
                          item.label == context.loc.position ||
                          item.label == context.loc.name ||
                          item.label == context.loc.level;
    
    VoidCallback? onTapAction;
    if (isEditable) {
      if (item.label == context.loc.age) {
        onTapAction = _showBirthDatePicker;
      } else if (item.label == context.loc.nationality) {
        onTapAction = _showNationalityPicker;
      } else if (item.label == context.loc.phoneLabel) { 
        onTapAction = _showPhoneNumberPicker;
      } else if (item.label == context.loc.position) {
        onTapAction = _showPositionPicker;
      } else if (item.label == context.loc.name) {
        onTapAction = _showNameEditor;
      } else if (item.label == context.loc.level) {
        onTapAction = _showLevelPicker;
      }
    }

    return InkWell(
      onTap: onTapAction,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                item.icon,
                color: Colors.grey[700],
                size: 18,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.value.isNotEmpty ? item.value : 'Not set',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            if (isEditable)
              Icon(
                Icons.edit_outlined,
                size: 16,
                color: _brandColor,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            context.loc.settings,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildSettingsItem(
                title: context.loc.languageSettingsTitle,
                icon: Icons.language_outlined,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LanguageSettingsScreen()),
                ),
              ),
              Divider(height: 1, color: Colors.grey[100]),
              _buildSettingsItem(
                title: context.loc.privacyPolicy,
                icon: Icons.privacy_tip_outlined,
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => const PrivacyPolicyModal(),
                  );
                },
              ),
              Divider(height: 1, color: Colors.grey[100]),
              _buildSettingsItem(
                title: context.loc.termsConditions,
                icon: Icons.description_outlined,
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => const TermsAndConditionsModal(),
                  );
                },
              ),
              Divider(height: 1, color: Colors.grey[100]),
              _buildSettingsItem(
                title: context.loc.deleteAccount,
                icon: Icons.delete_outline,
                onTap: _deleteAccount,
                isDestructive: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsItem({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDestructive ? Colors.red.withOpacity(0.05) : Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: isDestructive ? Colors.red : Colors.grey[700],
                size: 18,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDestructive ? Colors.red : Colors.black87,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.grey[400],
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _showLogoutDialog,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: BorderSide(color: _brandColor),
        ),
        icon: Icon(Icons.logout_rounded, color: _brandColor),
        label: Text(
          context.loc.logout,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: _brandColor,
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem({required IconData icon, required String text}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _brandColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: _brandColor,
            size: 20,
          ),
        ),
        const SizedBox(width: 16),
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 16,
            color: Colors.black87,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  String countryCodeToFlag(String countryCode) {
    return countryCode.toUpperCase().replaceAllMapped(
          RegExp(r'[A-Z]'),
          (match) => String.fromCharCode(match.group(0)!.codeUnitAt(0) + 127397),
        );
  }

  String _formatJoinedDate(String dateString) {
    if (dateString.isEmpty) return '';
    
    try {
      final DateTime date = DateTime.parse(dateString);
      return DateFormat('dd.MM.yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }
}

class _ProfileItem {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileItem({
    required this.icon,
    required this.label,
    required this.value,
  });
}
