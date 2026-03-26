import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:playmakerappstart/models/user_model.dart';
import './models/squad.dart';
import 'package:playmakerappstart/mysquads_screen.dart';
import 'package:playmakerappstart/services/supabase_service.dart';
import 'package:playmakerappstart/invite_friends_bottom_sheet.dart';
import 'package:playmakerappstart/components/player_tile.dart';

class CreateSquadsScreen extends StatefulWidget {
  final PlayerProfile playerProfile;

  const CreateSquadsScreen({
    super.key,
    required this.playerProfile,
  });

  @override
  State<CreateSquadsScreen> createState() => _CreateSquadsScreenState();
}

class _CreateSquadsScreenState extends State<CreateSquadsScreen> with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  final _supabaseService = SupabaseService();
  final _picker = ImagePicker();

  int _currentStep = 0;
  final int _totalSteps = 4;

  // Form data
  String _squadName = '';
  String _squadLocation = '';
  String? _description;
  List<String> _squadPlayers = [];
  File? _squadLogo;
  bool _isLoading = false;
  bool _isJoinable = true;

  late AnimationController _animationController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _squadPlayers = [widget.playerProfile.id];
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _progressAnimation = Tween<double>(begin: 0, end: 0.25).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentStep++;
        _progressAnimation = Tween<double>(
          begin: _progressAnimation.value,
          end: (_currentStep + 1) / _totalSteps,
        ).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
        );
        _animationController.forward(from: 0);
      });
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentStep--;
        _progressAnimation = Tween<double>(
          begin: _progressAnimation.value,
          end: (_currentStep + 1) / _totalSteps,
        ).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
        );
        _animationController.forward(from: 0);
      });
    }
  }

  bool get _canProceed {
    switch (_currentStep) {
      case 0:
        return _squadName.isNotEmpty;
      case 1:
        return _squadLocation.isNotEmpty;
      case 2:
        return _squadPlayers.length >= 5;
      case 3:
        return true;
      default:
        return false;
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _squadLogo = File(pickedFile.path));
    }
  }

  Future<void> _inviteFriends() async {
    final invitedFriends = await showModalBottomSheet<List<String>>(
      context: context,
      builder: (context) => InviteFriendsBottomSheet(
        playerProfile: widget.playerProfile,
        initiallySelectedFriends: _squadPlayers.where((id) => id != widget.playerProfile.id).toList(),
      ),
    );

    if (invitedFriends != null) {
      setState(() {
        final uniquePlayers = {widget.playerProfile.id, ...invitedFriends};
        _squadPlayers = uniquePlayers.toList();
      });
    }
  }

  void _showLocationPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00BF63).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.location_on, color: Color(0xFF00BF63), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Select Location',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      'New Cairo',
                      'Nasr City',
                      'Shorouk',
                      'Maadi',
                      'Sheikh Zayed',
                      'October'
                    ].map((location) => Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _squadLocation = location;
                          });
                          Navigator.pop(context);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          decoration: BoxDecoration(
                            color: _squadLocation == location
                                ? const Color(0xFF00BF63).withOpacity(0.1)
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _squadLocation == location
                                  ? const Color(0xFF00BF63)
                                  : Colors.grey[300]!,
                              width: 2,
                            ),
                          ),
                          child: Text(
                            location,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: _squadLocation == location
                                  ? const Color(0xFF00BF63)
                                  : Colors.black87,
                              fontWeight: _squadLocation == location
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    )).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createSquad() async {
    setState(() => _isLoading = true);

    try {
      String? squadLogoUrl;
      if (_squadLogo != null) {
        squadLogoUrl = await _supabaseService.uploadImageAndGetURL(
          widget.playerProfile.id,
          _squadLogo!,
        );
      }

      final newSquad = Squad(
        id: '',
        squadName: _squadName,
        squadLocation: _squadLocation,
        captain: widget.playerProfile.id,
        squadMembers: [widget.playerProfile.id],
        pendingRequests: [],
        openTeamsRequests: [],
        profilePicture: squadLogoUrl ?? '',
        matchesPlayed: '0',
        averageAge: 0.0,
        joinable: _isJoinable,
      );

      await _supabaseService.addSquad(newSquad, widget.playerProfile.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Squad created successfully!'),
              ],
            ),
            backgroundColor: Color(0xFF00BF63),
          ),
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => MySquadScreen(
              playerProfile: widget.playerProfile,
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Error: $error')),
              ],
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(
            'Create Squad',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: Colors.black87,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Stack(
          children: [
            Column(
              children: [
                // Progress Indicator
                _buildProgressIndicator(),

                // Step Content
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildStep1Identity(),
                      _buildStep2Details(),
                      _buildStep3Team(),
                      _buildStep4Review(),
                    ],
                  ),
                ),
              ],
            ),

            // Loading Overlay
            if (_isLoading)
              Container(
                color: Colors.black54,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(
                          color: Color(0xFF00BF63),
                          strokeWidth: 3,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Creating Squad...',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'This won\'t take long',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        bottomNavigationBar: _buildBottomNavigation(),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          Row(
            children: List.generate(_totalSteps, (index) {
              final isCompleted = index < _currentStep;
              final isCurrent = index == _currentStep;

              return Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 4,
                        decoration: BoxDecoration(
                          color: isCompleted || isCurrent
                              ? const Color(0xFF00BF63)
                              : Colors.grey[200],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    if (index < _totalSteps - 1) const SizedBox(width: 8),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Step ${_currentStep + 1} of $_totalSteps',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF00BF63),
                ),
              ),
              Text(
                _getStepTitle(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getStepTitle() {
    switch (_currentStep) {
      case 0:
        return 'Squad Identity';
      case 1:
        return 'Squad Details';
      case 2:
        return 'Build Team';
      case 3:
        return 'Review';
      default:
        return '';
    }
  }

  Widget _buildBottomNavigation() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).padding.bottom,
      ),
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
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousStep,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF00BF63),
                  side: const BorderSide(color: Color(0xFF00BF63), width: 2),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Back',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 16),
          Expanded(
            flex: _currentStep > 0 ? 2 : 1,
            child: FilledButton(
              onPressed: _canProceed
                  ? (_currentStep == _totalSteps - 1 ? _createSquad : _nextStep)
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF00BF63),
                disabledBackgroundColor: Colors.grey[300],
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _currentStep == _totalSteps - 1 ? 'Create Squad' : 'Continue',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _currentStep == _totalSteps - 1
                        ? Icons.check_circle_outline
                        : Icons.arrow_forward,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Step 1: Squad Identity (Logo & Name)
  Widget _buildStep1Identity() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          const Icon(
            Icons.groups_rounded,
            size: 80,
            color: Color(0xFF00BF63),
          ),
          const SizedBox(height: 24),
          Text(
            'Let\'s start with\nyour squad identity',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Choose a memorable name and logo for your squad',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 48),

          // Logo Picker
          Center(
            child: GestureDetector(
              onTap: _pickImage,
              child: Stack(
                children: [
                  Container(
                    height: 140,
                    width: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF00BF63),
                        width: 4,
                      ),
                      color: Colors.grey[50],
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00BF63).withOpacity(0.2),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: _squadLogo != null
                          ? Image.file(
                              _squadLogo!,
                              fit: BoxFit.cover,
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_photo_alternate_rounded,
                                  size: 40,
                                  color: const Color(0xFF00BF63),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Add Logo',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'Optional',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[500],
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  if (_squadLogo != null)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFF00BF63),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 48),

          // Squad Name Input
          Text(
            'Squad Name',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: _squadName,
            decoration: InputDecoration(
              hintText: 'e.g., Thunder Squad, Warriors FC',
              filled: true,
              fillColor: Colors.grey[50],
              prefixIcon: const Icon(
                Icons.shield_outlined,
                color: Color(0xFF00BF63),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFF00BF63), width: 2),
              ),
              contentPadding: const EdgeInsets.all(20),
            ),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            onChanged: (value) => setState(() => _squadName = value),
            textCapitalization: TextCapitalization.words,
          ),

          const SizedBox(height: 20),

          if (_squadName.isNotEmpty)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 300),
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 20 * (1 - value)),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00BF63).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF00BF63).withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Color(0xFF00BF63),
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Great name! Ready to continue',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFF00BF63),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // Step 2: Squad Details (Description & Location)
  Widget _buildStep2Details() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          const Icon(
            Icons.info_rounded,
            size: 80,
            color: Color(0xFF00BF63),
          ),
          const SizedBox(height: 24),
          Text(
            'Tell us more about\nyour squad',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Add a description and select your main playing area',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 48),

          // Description
          Text(
            'Description',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'Optional - Tell potential members about your squad',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: _description,
            decoration: InputDecoration(
              hintText: 'We play every weekend and love friendly competition...',
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFF00BF63), width: 2),
              ),
              contentPadding: const EdgeInsets.all(20),
            ),
            maxLines: 4,
            textInputAction: TextInputAction.newline,
            onChanged: (value) => setState(() => _description = value),
          ),

          const SizedBox(height: 32),

          // Location
          Text(
            'Primary Location',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'Where does your squad usually play?',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _showLocationPicker,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _squadLocation.isEmpty ? Colors.grey[50] : const Color(0xFF00BF63).withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _squadLocation.isEmpty ? Colors.grey[300]! : const Color(0xFF00BF63),
                  width: _squadLocation.isEmpty ? 1 : 2,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00BF63).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.location_on,
                      color: Color(0xFF00BF63),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _squadLocation.isEmpty ? 'Select Location' : _squadLocation,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: _squadLocation.isEmpty ? Colors.grey[500] : Colors.black87,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_squadLocation.isEmpty)
                          Text(
                            'Tap to choose',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[500],
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            ),
          ),

          if (_squadLocation.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF00BF63).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF00BF63).withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: Color(0xFF00BF63),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Perfect! Now let\'s build your team',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF00BF63),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // Step 3: Build Team
  Widget _buildStep3Team() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                const Icon(
                  Icons.group_add_rounded,
                  size: 80,
                  color: Color(0xFF00BF63),
                ),
                const SizedBox(height: 24),
                Text(
                  'Build your team',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Invite at least 5 players to create your squad',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 32),

                // Player Count Badge
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: _squadPlayers.length >= 5
                          ? const Color(0xFF00BF63)
                          : Colors.orange,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: (_squadPlayers.length >= 5
                                  ? const Color(0xFF00BF63)
                                  : Colors.orange)
                              .withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.people, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '${_squadPlayers.length} / 5+ Players',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Invite Button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _inviteFriends,
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('Invite Friends'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF00BF63),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Players List
                if (_squadPlayers.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(48),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.group_outlined,
                            size: 48,
                            color: Colors.grey[500],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'No players yet',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap "Invite Friends" above',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _squadPlayers.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final playerId = _squadPlayers[index];
                      return FutureBuilder<PlayerProfile?>(
                        future: _supabaseService.getUserProfileById(playerId),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return _buildPlayerSkeleton();
                          }

                          if (!snapshot.hasData) return const SizedBox();

                          final player = snapshot.data!;
                          final isHost = playerId == widget.playerProfile.id;

                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: PlayerTile(
                              playerProfile: player,
                              contentPadding: const EdgeInsets.all(16),
                              actionType: isHost
                                  ? PlayerTileActionType.customWidget
                                  : PlayerTileActionType.removeIcon,
                              customTrailingWidget: isHost
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF00BF63),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: const Text(
                                        'Captain',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    )
                                  : null,
                              singleActionIcon: Icons.remove_circle_outline,
                              singleActionIconColor: Colors.red,
                              onRemove: isHost
                                  ? null
                                  : () {
                                      setState(() {
                                        _squadPlayers.remove(playerId);
                                      });
                                    },
                            ),
                          );
                        },
                      );
                    },
                  ),

                if (_squadPlayers.isNotEmpty && _squadPlayers.length < 5) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.orange, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Add ${5 - _squadPlayers.length} more player${5 - _squadPlayers.length == 1 ? '' : 's'}',
                            style: const TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (_squadPlayers.length >= 5) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00BF63).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF00BF63).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Color(0xFF00BF63),
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Awesome! You have enough players to continue',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF00BF63),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerSkeleton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 16,
                  width: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  height: 12,
                  width: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Step 4: Review & Settings
  Widget _buildStep4Review() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          const Icon(
            Icons.check_circle_outline_rounded,
            size: 80,
            color: Color(0xFF00BF63),
          ),
          const SizedBox(height: 24),
          Text(
            'Almost done!',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Review your squad details and adjust settings',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 48),

          // Squad Preview Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00BF63), Color(0xFF00A056)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00BF63).withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                if (_squadLogo != null)
                  Container(
                    height: 100,
                    width: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    child: ClipOval(
                      child: Image.file(
                        _squadLogo!,
                        fit: BoxFit.cover,
                      ),
                    ),
                  )
                else
                  Container(
                    height: 100,
                    width: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      color: Colors.white.withOpacity(0.2),
                    ),
                    child: const Icon(
                      Icons.shield,
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  _squadName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on, color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        _squadLocation,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildStatBadge(Icons.people, '${_squadPlayers.length}', 'Players'),
                    const SizedBox(width: 20),
                    _buildStatBadge(Icons.sports_soccer, '0', 'Matches'),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Description (if provided)
          if (_description != null && _description!.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Color(0xFF00BF63),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Description',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _description!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[700],
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Squad Settings
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.settings,
                        color: Color(0xFF00BF63),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Squad Settings',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  title: Text(
                    'Allow Join Requests',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    _isJoinable
                        ? 'Anyone can send a request to join'
                        : 'Your squad is invite-only',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  secondary: Icon(
                    _isJoinable ? Icons.lock_open : Icons.lock,
                    color: const Color(0xFF00BF63),
                  ),
                  value: _isJoinable,
                  onChanged: (value) => setState(() => _isJoinable = value),
                  activeColor: const Color(0xFF00BF63),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Ready to create message
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF00BF63).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF00BF63).withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Color(0xFF00BF63),
                  size: 32,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ready to create!',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: const Color(0xFF00BF63),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap "Create Squad" below to finish',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF00BF63),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildStatBadge(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

