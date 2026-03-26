import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:playmakerappstart/invite_friends_bottom_sheet.dart';
import 'package:playmakerappstart/l10n/app_localizations.dart';
import 'package:playmakerappstart/models/footballfield_model.dart';
import 'package:playmakerappstart/models/user_model.dart';
import 'package:playmakerappstart/payment_screen.dart';
import 'package:playmakerappstart/services/supabase_service.dart';
// Temporarily unused - re-enable when Players section is restored
// ignore: unused_import
import 'package:playmakerappstart/components/player_tile.dart';

class BookingDetailsScreen extends StatefulWidget {
  final FootballField field;
  final PlayerProfile playerProfile;
  final DateTime selectedDate;
  final Map<String, dynamic> selectedTimeSlot;

  const BookingDetailsScreen({
    super.key,
    required this.field,
    required this.playerProfile,
    required this.selectedDate,
    required this.selectedTimeSlot,
  });

  @override
  State<BookingDetailsScreen> createState() => _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends State<BookingDetailsScreen> {
  final _squadController = TextEditingController();
  final _descriptionController = TextEditingController();
  Set<String> _invitedPlayers = {};
  Set<String> _invitedSquads = {};
  bool _isOpenMatch = false;
  final SupabaseService _supabaseService = SupabaseService();
  
  int _guestCount = 0;
  bool _isRecordingEnabled = false;
  final int _recordingPrice = 100;
  late int _maxPlayers;
  late int _defaultMaxPlayers;
  bool _limitMaxPlayers = true;

  int get _currentTotalPlayers => 1 + _invitedPlayers.length + _guestCount;

  @override
  void initState() {
    super.initState();
    _calculateDefaultMaxPlayers();
    
    // Camera recording is mandatory if field has camera
    if (widget.field.hasCamera) {
      _isRecordingEnabled = true;
    }
  }

  void _calculateDefaultMaxPlayers() {
    switch (widget.field.fieldSize) {
      case '5-a-side':
        _defaultMaxPlayers = 10;
        break;
      case '6-a-side':
        _defaultMaxPlayers = 12;
        break;
      case '7-a-side':
        _defaultMaxPlayers = 14;
        break;
      default:
        _defaultMaxPlayers = 10;
    }
    _maxPlayers = _defaultMaxPlayers;
  }

  @override
  void dispose() {
    _squadController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // Temporarily disabled - re-enable when Players section is restored
  // ignore: unused_element
  Future<void> _inviteFriends() async {
    final selectedFriends = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => InviteFriendsBottomSheet(
        playerProfile: widget.playerProfile,
        initiallySelectedFriends: _invitedPlayers.toList(),
      ),
    );

    if (selectedFriends != null) {
      if (_limitMaxPlayers) {
        int availableSlots = _maxPlayers - _currentTotalPlayers;
        if (selectedFriends.length > availableSlots) {
          if (availableSlots > 0) {
            _invitedPlayers.addAll(selectedFriends.take(availableSlots));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppLocalizations.of(context)!.bookingDetails_playerLimitReachedSomeAdded(availableSlots)),
                backgroundColor: Colors.orange,
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppLocalizations.of(context)!.bookingDetails_playerLimitReachedNoneAdded(_maxPlayers)),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } else {
          _invitedPlayers.addAll(selectedFriends);
        }
      } else {
        _invitedPlayers.addAll(selectedFriends);
      }
      setState(() {});
    }
  }

  void _navigateToPayment() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentScreen(
          playerProfile: widget.playerProfile,
          field: widget.field,
          selectedDate: widget.selectedDate,
          selectedTimeSlot: widget.selectedTimeSlot,
          invitePlayers: _invitedPlayers.toList(),
          inviteSquads: _invitedSquads.toList(),
          isOpenMatch: !_isOpenMatch,
          description: _descriptionController.text.trim(),
          guestCount: _guestCount,
          isRecordingEnabled: _isRecordingEnabled,
          maxPlayers: _limitMaxPlayers ? _maxPlayers : null,
        ),
      ),
    );
  }

  String _formatTimeSlot(String timeSlot) {
    final times = timeSlot.split('-');
    if (times.length != 2) return timeSlot;
    
    final startTime = times[0];
    final endTime = times[1];
    
    final startHour = int.parse(startTime.split(':')[0]);
    final startMinute = int.parse(startTime.split(':')[1]);
    final endHour = int.parse(endTime.split(':')[0]);
    final endMinute = int.parse(endTime.split(':')[1]);
    
    final start = DateTime(1970, 1, 1, startHour, startMinute);
    final end = DateTime(1970, 1, 1, endHour, endMinute);
    
    return '${DateFormat('h:mm a', AppLocalizations.of(context)!.localeName).format(start)} - ${DateFormat('h:mm a', AppLocalizations.of(context)!.localeName).format(end)}';
  }

  // Temporarily disabled - re-enable when Players section is restored
  // ignore: unused_element
  Future<PlayerProfile?> _fetchPlayerProfile(String playerId) async {
    try {
      return await _supabaseService.getUserProfileById(playerId);
    } catch (e) {
      return null;
    }
  }

  int _calculateTotalPrice() {
    final dynamic priceValue = widget.selectedTimeSlot['price'];
    int basePrice;
    if (priceValue is int) {
      basePrice = priceValue;
    } else if (priceValue is num) {
      basePrice = priceValue.toInt();
    } else if (priceValue is String) {
      basePrice = int.tryParse(priceValue) ?? 0;
    } else {
      basePrice = 0;
    }
    if (_isRecordingEnabled) {
      return basePrice + _recordingPrice;
    }
    return basePrice;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Match Details',
            style: GoogleFonts.inter(
              color: Colors.black,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Summary Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF00BF63).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF00BF63).withOpacity(0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.field.footballFieldName,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildSummaryBadge(
                          Icons.calendar_today, 
                          DateFormat('EEE, MMM d').format(widget.selectedDate),
                        ),
                        const SizedBox(width: 10),
                        _buildSummaryBadge(
                          Icons.access_time, 
                          _formatTimeSlot(widget.selectedTimeSlot['time']),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // 2. Settings
              Text(
                AppLocalizations.of(context)!.bookingDetails_matchSettings,
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black),
              ),
              const SizedBox(height: 16),
              
              _buildSettingsContainer(
                children: [
                  _buildSwitchRow(
                    title: AppLocalizations.of(context)!.bookingDetails_privateMatch,
                    subtitle: _isOpenMatch 
                        ? 'Only invited players can see this'
                        : 'Anyone can see and request to join',
                    value: _isOpenMatch,
                    onChanged: (val) => setState(() => _isOpenMatch = val),
                    icon: _isOpenMatch ? Icons.lock_outline : Icons.public,
                  ),
                  
                  if (widget.field.hasCamera) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Divider(height: 1, color: Colors.grey[100]),
                    ),
                    // Camera recording is mandatory - always enabled
                    _buildCameraRecordingRow(),
                  ],
                  
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Divider(height: 1, color: Colors.grey[100]),
                  ),
                  
                  // Max Players Logic
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.groups_outlined, size: 20, color: Colors.black87),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                AppLocalizations.of(context)!.bookingDetails_limitMaxPlayers,
                                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                            ),
                            Switch(
                              value: _limitMaxPlayers,
                              onChanged: (val) {
                                setState(() {
                                  _limitMaxPlayers = val;
                                  if (val && _maxPlayers < _defaultMaxPlayers) {
                                    _maxPlayers = _defaultMaxPlayers;
                                  }
                                });
                              },
                              activeColor: const Color(0xFF00BF63),
                            ),
                          ],
                        ),
                        if (_limitMaxPlayers) ...[
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildCounterButton(
                                icon: Icons.remove,
                                onTap: (_maxPlayers > 2 && _maxPlayers > _currentTotalPlayers)
                                    ? () => setState(() => _maxPlayers--)
                                    : null,
                              ),
                              Container(
                                width: 80,
                                alignment: Alignment.center,
                                child: Text(
                                  '$_maxPlayers',
                                  style: GoogleFonts.inter(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF00BF63),
                                  ),
                                ),
                              ),
                              _buildCounterButton(
                                icon: Icons.add,
                                onTap: () => setState(() => _maxPlayers++),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Players section temporarily hidden
              // TODO: Re-enable Bring Guests and Invite Players when needed
              /*
              // 3. Players
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppLocalizations.of(context)!.playersSectionTitle,
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00BF63).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _limitMaxPlayers
                          ? '$_currentTotalPlayers / $_maxPlayers'
                          : '$_currentTotalPlayers Players',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF00BF63),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              _buildSettingsContainer(
                children: [
                  // Guests
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.person_add_alt_1_outlined, size: 20, color: Colors.black87),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            AppLocalizations.of(context)!.bookingDetails_bringGuests,
                            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                        ),
                        _buildCounterButton(
                          icon: Icons.remove,
                          onTap: _guestCount > 0 
                              ? () => setState(() => _guestCount--)
                              : null,
                          small: true,
                        ),
                        Container(
                          width: 40,
                          alignment: Alignment.center,
                          child: Text(
                            '$_guestCount',
                            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                        _buildCounterButton(
                          icon: Icons.add,
                          onTap: (!_limitMaxPlayers || _currentTotalPlayers < _maxPlayers)
                              ? () => setState(() => _guestCount++)
                              : null,
                          small: true,
                        ),
                      ],
                    ),
                  ),
                  
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Divider(height: 1, color: Colors.grey[100]),
                  ),
                  
                  // Invite Button
                  InkWell(
                    onTap: (!_limitMaxPlayers || _currentTotalPlayers < _maxPlayers)
                        ? _inviteFriends
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00BF63).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.add, size: 20, color: Color(0xFF00BF63)),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            AppLocalizations.of(context)!.bookingDetails_invitePlayers,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF00BF63),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Player List
                  if (_invitedPlayers.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Divider(height: 1, color: Colors.grey[100]),
                    ),
                    ListView.separated(
                      padding: const EdgeInsets.all(16),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _invitedPlayers.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final playerId = _invitedPlayers.elementAt(index);
                        return FutureBuilder<PlayerProfile?>(
                          future: _fetchPlayerProfile(playerId),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return Container(
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              );
                            }
                            final player = snapshot.data!;
                            return Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Colors.grey[200],
                                  backgroundImage: player.profilePicture.isNotEmpty 
                                      ? NetworkImage(player.profilePicture) 
                                      : null,
                                  child: player.profilePicture.isEmpty 
                                      ? Text(player.name[0].toUpperCase(), style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 12))
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    player.name,
                                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 18, color: Colors.red),
                                  onPressed: () => setState(() => _invitedPlayers.remove(playerId)),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 32),
              */

              // 4. Description
              Text(
                'Notes (Optional)',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                maxLines: 3,
                style: GoogleFonts.inter(fontSize: 14),
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context)!.bookingDetails_matchDescriptionHint,
                  hintStyle: GoogleFonts.inter(color: Colors.grey[400]),
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF00BF63), width: 1),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
              
              const SizedBox(height: 100),
            ],
          ),
        ),
        bottomNavigationBar: Container(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).padding.bottom),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Row(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '${_calculateTotalPrice()} EGP',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF00BF63),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 20),
              Expanded(
                child: ElevatedButton(
                  onPressed: _navigateToPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00BF63),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.bookingDetails_continue,
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: const Color(0xFF00BF63)),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsContainer({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  /// Camera recording row - always enabled (mandatory)
  Widget _buildCameraRecordingRow() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF00BF63).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.videocam, size: 20, color: Color(0xFF00BF63)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      AppLocalizations.of(context)!.bookingDetails_cameraRecording,
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00BF63),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Included',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Your match will be recorded (+$_recordingPrice EGP)',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          // Always on indicator instead of switch
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF00BF63).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, size: 16, color: Color(0xFF00BF63)),
                const SizedBox(width: 4),
                Text(
                  'ON',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF00BF63),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: Colors.black87),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF00BF63),
          ),
        ],
      ),
    );
  }

  Widget _buildCounterButton({required IconData icon, required VoidCallback? onTap, bool small = false}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: EdgeInsets.all(small ? 6 : 10),
          decoration: BoxDecoration(
            border: Border.all(
              color: onTap == null ? Colors.grey.shade200 : Colors.grey.shade300,
            ),
            shape: BoxShape.circle,
            color: onTap == null ? Colors.grey.shade50 : Colors.white,
          ),
          child: Icon(
            icon, 
            size: small ? 16 : 20, 
            color: onTap == null ? Colors.grey.shade300 : Colors.black87,
          ),
        ),
      ),
    );
  }
}
