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

class _CreateSquadsScreenState extends State<CreateSquadsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supabaseService = SupabaseService();
  final _picker = ImagePicker();
  
  String _squadName = '';
  String _squadLocation = '';
  String? _description;
  List<String> _squadPlayers = [];
  bool _ageLimitEnabled = false;
  String? _minAge;
  String? _maxAge;
  File? _squadLogo;
  bool _isLoading = false;
  bool _isJoinable = true;

  bool get _isFormValid =>
    _squadName.isNotEmpty && 
    _squadLocation.isNotEmpty &&
    _squadPlayers.length >= 5;

  @override
  void initState() {
    super.initState();
    _squadPlayers = [widget.playerProfile.id];
  }

  Widget _buildCard({required Widget child, EdgeInsets? padding}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(20),
        child: child,
      ),
    );
  }

  Widget _buildSectionTitle(String title, {IconData? icon, Widget? trailing}) {
    return Row(
      children: [
        if (icon != null) ...[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF00BF63).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF00BF63), size: 20),
          ),
          const SizedBox(width: 12),
        ],
        
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        if (trailing != null) ...[
          trailing,
        ],
      ],
    );
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
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: _squadLocation == location 
                                ? const Color(0xFF00BF63).withOpacity(0.1)
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _squadLocation == location
                                  ? const Color(0xFF00BF63)
                                  : Colors.grey[300]!,
                            ),
                          ),
                          child: Text(
                            location,
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: _squadLocation == location
                                  ? const Color(0xFF00BF63)
                                  : Colors.black87,
                              fontWeight: _squadLocation == location
                                  ? FontWeight.w600
                                  : FontWeight.normal,
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

  Future<void> _saveForm() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    
    _formKey.currentState?.save();
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
          SnackBar(
            content: const Text('Squad created successfully'),
            backgroundColor: const Color(0xFF00BF63),
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
            content: Text('Error creating squad: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTap: () {
        // Dismiss keyboard when tapping outside
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        backgroundColor: Colors.grey[50],
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
      ),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Squad Logo Section
                _buildCard(
                  child: Column(
                    children: [
                      _buildSectionTitle('Squad Logo', icon: Icons.photo_camera),
                      const SizedBox(height: 20),
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          height: 120,
                          width: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF00BF63),
                              width: 3,
                            ),
                            color: Colors.grey[50],
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
                                        Icons.add_photo_alternate_outlined,
                                        size: 32,
                                        color: const Color(0xFF00BF63),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Optional',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: Colors.grey[600],
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Basic Information Section
                _buildCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('Basic Information', icon: Icons.info_outline),
                      const SizedBox(height: 20),
                      _EnhancedTextInput(
                        label: 'Squad Name',
                        hintText: 'Enter your squad name',
                        onChanged: (value) => setState(() => _squadName = value),
                        icon: Icons.groups,
                      ),
                      const SizedBox(height: 16),
                      _EnhancedTextInput(
                        label: 'Description',
                        hintText: 'Tell us about your squad (optional)',
                        onChanged: (value) => setState(() => _description = value),
                        maxLines: 3,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        icon: Icons.description,
                      ),
                      const SizedBox(height: 16),
                      _EnhancedLocationInput(
                        selectedLocation: _squadLocation,
                        onTap: _showLocationPicker,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Team Setup Section
                _buildCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle(
                        'Team Setup',
                        icon: Icons.group,
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _squadPlayers.length >= 5 
                                ? const Color(0xFF00BF63).withOpacity(0.1)
                                : Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            '${_squadPlayers.length}/5+ players',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: _squadPlayers.length >= 5 
                                  ? const Color(0xFF00BF63)
                                  : Colors.orange[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Invite Button
                      Container(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _inviteFriends,
                          icon: const Icon(Icons.person_add_alt_1, size: 20),
                          label: const Text('Invite Friends'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF00BF63),
                            side: const BorderSide(color: Color(0xFF00BF63)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Players List
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                          color: Colors.grey[50],
                        ),
                        child: _squadPlayers.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.group_add,
                                        size: 32,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Your squad needs at least 5 players',
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.titleSmall?.copyWith(
                                        color: Colors.grey[700],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Tap "Invite Friends" to add members',
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _squadPlayers.length,
                                separatorBuilder: (context, index) => Divider(
                                  height: 1,
                                  color: Colors.grey[200],
                                  indent: 16,
                                  endIndent: 16,
                                ),
                                itemBuilder: (context, index) {
                                  final playerId = _squadPlayers[index];
                                  return FutureBuilder<PlayerProfile?>(
                                    future: _supabaseService.getUserProfileById(playerId),
                                    builder: (context, snapshot) {
                                      if (snapshot.connectionState == ConnectionState.waiting) {
                                        return Container(
                                          padding: const EdgeInsets.all(16),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 44,
                                                height: 44,
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
                                      
                                      if (!snapshot.hasData) return const SizedBox();
                                      
                                      final player = snapshot.data!;
                                      final isHost = playerId == widget.playerProfile.id;
                                      
                                      return PlayerTile(
                                        playerProfile: player,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        actionType: isHost 
                                            ? PlayerTileActionType.customWidget
                                            : PlayerTileActionType.removeIcon,
                                        customTrailingWidget: isHost 
                                            ? Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF00BF63),
                                                  borderRadius: BorderRadius.circular(16),
                                                ),
                                                child: Text(
                                                  'Captain',
                                                  style: theme.textTheme.labelMedium?.copyWith(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              )
                                            : null,
                                        singleActionIcon: Icons.remove_circle_outline,
                                        singleActionIconColor: Colors.red,
                                        onRemove: isHost ? null : () {
                                          setState(() {
                                            _squadPlayers.remove(playerId);
                                          });
                                        },
                                      );
                                    },
                                  );
                                },
                              ),
                      ),
                      
                      if (_squadPlayers.isNotEmpty && _squadPlayers.length < 5) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Add ${5 - _squadPlayers.length} more player${5 - _squadPlayers.length == 1 ? '' : 's'} to create your squad',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.orange[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Squad Settings Section
                _buildCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('Squad Settings', icon: Icons.settings),
                      const SizedBox(height: 20),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.grey[50],
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: SwitchListTile(
                          title: Text(
                            'Allow Join Requests',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            _isJoinable 
                                ? 'Anyone can send a request to join your squad'
                                : 'Your squad is invite-only',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                          value: _isJoinable,
                          onChanged: (bool value) {
                            setState(() {
                              _isJoinable = value;
                            });
                          },
                          secondary: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00BF63).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _isJoinable ? Icons.lock_open : Icons.lock,
                              color: const Color(0xFF00BF63),
                              size: 20,
                            ),
                          ),
                          activeColor: const Color(0xFF00BF63),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 100), // Space for bottom navigation
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: Center(
                child: _buildCard(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        color: Color(0xFF00BF63),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Creating Squad...',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_isFormValid && (_squadName.isNotEmpty || _squadLocation.isNotEmpty || _squadPlayers.isNotEmpty)) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _squadPlayers.length < 5 
                            ? 'Squad requires at least 5 players'
                            : 'Please fill in all required fields',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.red[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isFormValid ? _saveForm : null,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF00BF63),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Create Squad',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
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

class _EnhancedTextInput extends StatelessWidget {
  final String label;
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final int? maxLines;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final IconData? icon;

  const _EnhancedTextInput({
    required this.label,
    this.hintText,
    this.onChanged,
    this.maxLines,
    this.keyboardType,
    this.textInputAction,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF00BF63), width: 2),
        ),
        prefixIcon: icon != null 
            ? Icon(icon, color: const Color(0xFF00BF63), size: 20)
            : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      onChanged: onChanged,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
    );
  }
}

class _EnhancedLocationInput extends StatelessWidget {
  final String selectedLocation;
  final VoidCallback onTap;

  const _EnhancedLocationInput({
    required this.selectedLocation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Icon(
              Icons.location_on,
              color: const Color(0xFF00BF63),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Location',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    selectedLocation.isEmpty ? 'Select Location' : selectedLocation,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: selectedLocation.isEmpty ? Colors.grey[500] : Colors.black87,
                      fontWeight: selectedLocation.isEmpty ? FontWeight.normal : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_drop_down,
              color: Colors.grey[600],
            ),
          ],
        ),
      ),
    );
  }
}
