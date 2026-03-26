import 'package:flutter/material.dart';
import 'package:playmakerappstart/color_class.dart';
import 'package:playmakerappstart/localization/app_localizations.dart';
import 'package:playmakerappstart/main_screen.dart';
import 'package:playmakerappstart/models/user_model.dart';
import 'package:playmakerappstart/positions_bottom_sheet.dart';
import 'package:playmakerappstart/services/supabase_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class PositionLevelScreen extends StatefulWidget {
  final PlayerProfile userModel;
  
  const PositionLevelScreen({
    Key? key, 
    required this.userModel, 
  }) : super(key: key);

  @override
  _PositionLevelScreenState createState() => _PositionLevelScreenState();
}

class _PositionLevelScreenState extends State<PositionLevelScreen> {
  late String preferredPosition = '';
  late String personalLevel = '';
  bool _isFormFilled = false;
  bool _isLoading = false;

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

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    preferredPosition = widget.userModel.preferredPosition;
    personalLevel = widget.userModel.personalLevel;
    _updateFormFilledStatus();
  }

  void _updateFormFilledStatus() {
    setState(() {
      _isFormFilled = preferredPosition.isNotEmpty && personalLevel.isNotEmpty;
    });
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.grey.shade700,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Future<void> _submitProfile() async {
    setState(() => _isLoading = true);

    try {
      // Handle FCM token retrieval with error fallback
      String? fcmToken;
      try {
        fcmToken = await FirebaseMessaging.instance.getToken();
      } catch (fcmError) {
        print('Error getting FCM token: $fcmError');
        // Continue without FCM token - we'll update it later
        fcmToken = "";
      }

      // Create the final profile using copyWith
      final finalProfile = widget.userModel.copyWith(
        preferredPosition: preferredPosition,
        personalLevel: personalLevel,
        fcmToken: fcmToken ?? "",
      );

      await SupabaseService().storeUserData(finalProfile);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => MainScreen(userModel: finalProfile)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.loc.errorUpdatingProfileSnackbar(e.toString()))),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
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
          title: Text(
            context.loc.yourPlayingStyleTitle,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                context.loc.tellUsAboutYourGameTitle,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.backgroundColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.loc.tellUsAboutYourGameSubtitle,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 32),
              
              _buildSectionTitle(context.loc.preferredPositionSectionTitle),
              _buildSelectionTile(
                title: preferredPosition.isEmpty ? context.loc.selectYourPositionPlaceholder : preferredPosition,
                onTap: () => _showPositionPicker(context),
              ),
              const SizedBox(height: 24),
              
              _buildSectionTitle(context.loc.yourLevelSectionTitle),
              _buildSelectionTile(
                title: personalLevel.isEmpty ? context.loc.selectYourLevelPlaceholder : personalLevel,
                onTap: () => _showLevelPicker(context),
              ),
              
              if (preferredPosition.isNotEmpty) ...[
                const SizedBox(height: 32),
                _buildSelectedPositionCard(),
              ],
              
              if (personalLevel.isNotEmpty) ...[
                const SizedBox(height: 24),
                _buildSelectedLevelCard(),
              ],
            ],
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
              onPressed: _isFormFilled && !_isLoading ? _submitProfile : null,
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
                  : Text(
                      context.loc.completeProfileButton,
                      style: const TextStyle(
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

  Widget _buildSelectedPositionCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.backgroundColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.backgroundColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.sports_soccer,
              color: AppColors.backgroundColor,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.loc.selectedPositionCardLabel,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  preferredPosition,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedLevelCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.backgroundColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.backgroundColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.trending_up,
              color: AppColors.backgroundColor,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.loc.selectedLevelCardLabel,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  personalLevel,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getLevelDescription(),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getLevelDescription() {
    final level = levels.firstWhere(
      (l) => l['title'] == personalLevel,
      orElse: () => {'description': ''},
    );
    return level['description'] ?? '';
  }

  Widget _buildSelectionTile({
    required String title,
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

  void _showPositionPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PositionsBottomSheetModal(
        currentPosition: preferredPosition,
        onPositionSelected: (String newPosition) {
          setState(() {
            preferredPosition = newPosition;
            _updateFormFilledStatus();
          });
        },
      ),
    );
  }

  void _showLevelPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LevelBottomSheetModal(
        currentLevel: personalLevel,
        onLevelSelected: (String newLevel) {
          setState(() {
            personalLevel = newLevel;
            _updateFormFilledStatus();
          });
        },
      ),
    );
  }
}

class LevelBottomSheetModal extends StatelessWidget {
  final Function(String) onLevelSelected;
  final String currentLevel;
  final int gamesPlayed;

  const LevelBottomSheetModal({
    Key? key,
    required this.onLevelSelected,
    required this.currentLevel,
    this.gamesPlayed = 0,
  }) : super(key: key);

  List<Map<String, dynamic>> _getLocalizedLevels(BuildContext context) {
    final bool isExpertUnlocked = gamesPlayed >= 10;
    return [
      {
        'key': 'Beginner', // Keep original key
        'title': context.loc.beginner,
        'description': context.loc.levelBeginnerDescription,
        'stars': 1,
        'locked': false,
      },
      {
        'key': 'Casual',
        'title': context.loc.casual,
        'description': context.loc.levelCasualDescription,
        'stars': 2,
        'locked': false,
      },
      {
        'key': 'Skilled',
        'title': context.loc.skilled,
        'description': context.loc.levelSkilledDescription,
        'stars': 3,
        'locked': false,
      },
      {
        'key': 'Elite',
        'title': context.loc.elite,
        'description': context.loc.levelEliteDescription,
        'stars': 4,
        'locked': false,
      },
      {
        'key': 'Expert',
        'title': context.loc.expert,
        'description': context.loc.levelExpertDescription,
        'stars': 5,
        'locked': !isExpertUnlocked,
        'lockReason': context.loc.levelExpertLockReason(gamesPlayed),
      }
    ];
  }

  @override
  Widget build(BuildContext context) {
    final localizedLevels = _getLocalizedLevels(context);
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          _buildHeader(),
          _buildTitle(context),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: localizedLevels.map((level) =>
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildLevelCard(context, level, localizedLevels),
                ),
              ).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildTitle(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Text(
            context.loc.selectYourLevelTitle,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.loc.selectYourLevelSubtitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLevelCard(BuildContext context, Map<String, dynamic> level, List<Map<String, dynamic>> allLevels) {
    final originalTitleKey = allLevels.firstWhere((l) => l['title'] == level['title'], orElse: () => {'key': ''})['key'];
    final isSelected = originalTitleKey == currentLevel;
    final isLocked = level['locked'] ?? false;
    final isExpert = level['key'] == 'Expert'; // Match by key
    final bool justUnlocked = isExpert && gamesPlayed >= 10 && gamesPlayed < 15 && !isLocked;
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: justUnlocked
            ? Colors.amber.shade400
            : isLocked
              ? Colors.grey.shade300
              : isSelected 
                ? Theme.of(context).primaryColor
                : Colors.grey.shade200,
          width: (isSelected || justUnlocked) ? 2 : 1,
        ),
        color: justUnlocked
          ? Colors.amber.shade50
          : isLocked
            ? Colors.grey.shade100
            : isSelected 
              ? Theme.of(context).primaryColor.withOpacity(0.05)
              : Colors.white,
      ),
      child: InkWell(
        onTap: isLocked
          ? () {
              // Show a message when locked level is tapped
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(level['lockReason'].toString()), // Already localized
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          : () {
              onLevelSelected(level['key']!); // Use key for saving
              Navigator.pop(context);
            },
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _buildLevelStars(context, level, isLocked),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildLevelInfo(level, isLocked),
                  ),
                  _buildLockOrSelectionIndicator(context, isSelected, isLocked, level),
                ],
              ),
            ),
            if (justUnlocked)
              Positioned(
                top: 0,
                right: 16,
                child: Container(
                  transform: Matrix4.translationValues(0, -10, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade400,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.lock_open,
                        size: 12,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        context.loc.levelUnlockedBadge,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelStars(BuildContext context, Map<String, dynamic> level, bool isLocked) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isLocked ? Colors.grey.shade200 : Colors.grey.shade100,
      ),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            // For filled stars (up to the level's star count)
            if (index < level['stars']) {
              return Icon(
                Icons.star,
                color: isLocked ? Colors.grey.shade400 : Theme.of(context).primaryColor,
                size: 12,
              );
            }
            // For empty stars
            return Icon(
              Icons.star_border,
              color: Colors.grey.shade400,
              size: 12,
            );
          }),
        ),
      ),
    );
  }

  Widget _buildLevelInfo(Map<String, dynamic> level, bool isLocked) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              level['title'],
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isLocked ? Colors.grey.shade500 : Colors.black,
              ),
            ),
            if (isLocked) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.lock_outline,
                size: 16,
                color: Colors.grey.shade500,
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          isLocked ? level['lockReason'].toString() : level['description'].toString(), // Already localized
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        if (isLocked && level['key'] == 'Expert' && gamesPlayed > 0) ...[ // Match by key
          const SizedBox(height: 6),
          ClipRounded(
            child: LinearProgressIndicator(
              value: gamesPlayed / 10,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                gamesPlayed >= 10 
                  ? Colors.green.shade400 
                  : Colors.amber.shade400,
              ),
              minHeight: 6,
            ),
          ),
        ],
      ],
    );
  }

  Widget ClipRounded({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: child,
    );
  }

  Widget _buildLockOrSelectionIndicator(BuildContext context, bool isSelected, bool isLocked, Map<String, dynamic> level) {
    if (isLocked) {
      final isExpert = level['key'] == 'Expert'; // Match by key
      final bool isAlmostUnlocked = isExpert && gamesPlayed >= 8 && gamesPlayed < 10;
      
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isAlmostUnlocked ? Colors.amber.shade100 : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isAlmostUnlocked ? Icons.lock_clock : Icons.lock_outline,
              size: 14,
              color: isAlmostUnlocked ? Colors.amber.shade700 : Colors.grey.shade600,
            ),
            const SizedBox(width: 4),
            Text(
              isAlmostUnlocked ? context.loc.levelAlmostUnlockedBadge : context.loc.levelLockedBadge,
              style: TextStyle(
                fontSize: 12,
                color: isAlmostUnlocked ? Colors.amber.shade700 : Colors.grey.shade600,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }
    
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Icon(
        isSelected ? Icons.check_circle : Icons.arrow_forward_ios,
        color: isSelected 
          ? Theme.of(context).primaryColor
          : Colors.grey.shade400,
        size: isSelected ? 24 : 16,
      ),
    );
  }
}
