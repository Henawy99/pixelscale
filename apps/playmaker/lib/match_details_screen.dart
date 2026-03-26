import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:playmakerappstart/components/player_tile.dart';
import 'package:playmakerappstart/match_recording_widget.dart';
import 'package:playmakerappstart/models/booking_model.dart';
import 'package:playmakerappstart/models/footballfield_model.dart';
import 'package:playmakerappstart/models/user_model.dart';
import 'package:playmakerappstart/player_details_screen.dart';
import 'package:playmakerappstart/friends_screen.dart';
import 'package:playmakerappstart/services/supabase_service.dart';
import 'package:playmakerappstart/services/notification_service.dart';
import 'package:playmakerappstart/localization/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'match_chat_widget.dart';

class MatchDetailsScreen extends StatefulWidget {
  final Booking booking;
  final String currentUserId;
  final FootballField footballField;

  const MatchDetailsScreen({
    super.key,
    required this.booking,
    required this.currentUserId,
    required this.footballField,
  });

  @override
  State<MatchDetailsScreen> createState() => _MatchDetailsScreenState();
}

class _MatchDetailsScreenState extends State<MatchDetailsScreen> with SingleTickerProviderStateMixin {
  late Booking _booking;
  final SupabaseService _supabaseService = SupabaseService();
  final NotificationService _notificationService = NotificationService();
  late Stream<Booking?> _bookingStream;
  BitmapDescriptor? _customIcon;
  late TabController _tabController;
  PlayerProfile? _currentUserProfile;

  @override
  void initState() {
    super.initState();
    _booking = widget.booking;
    // For demo bookings, use a static stream instead of streaming from Supabase
    if (_booking.id.startsWith('demo_')) {
      _bookingStream = Stream.value(_booking);
    } else {
      _bookingStream = _supabaseService.streamBooking(_booking.id);
    }
    _tabController = TabController(length: 2, vsync: this);
    _loadCustomMarker();
    _fetchCurrentUserInfo();
  }

  Future<void> _fetchCurrentUserInfo() async {
    _currentUserProfile = await _fetchUserProfile(widget.currentUserId);
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomMarker() async {
    try {
      final data = await DefaultAssetBundle.of(context).load(
        'assets/images/playmakermarker2.png',
      );
      final resized = await _resizeMarker(data.buffer.asUint8List());
      setState(() {
        _customIcon = BitmapDescriptor.fromBytes(resized);
      });
    } catch (e) {
      // Handle error silently
    }
  }

  Future<Uint8List> _resizeMarker(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 100);
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  Future<PlayerProfile?> _fetchUserProfile(String userId) {
    return SupabaseService().getUserProfileById(userId);
  }

  String _formatDateCompact(String date) {
    final DateTime parsedDate = DateTime.parse(date);
    return DateFormat('MMM d', Localizations.localeOf(context).languageCode).format(parsedDate);
  }

  String _formatTimeRange(String timeSlot) {
    final times = timeSlot.split('-');
    if (times.length != 2) return timeSlot;
    
    final startTime = times[0];
    final endTime = times[1];
    
    final startHour = int.tryParse(startTime.split(':')[0]);
    final startMinute = int.tryParse(startTime.split(':')[1]);
    final endHour = int.tryParse(endTime.split(':')[0]);
    final endMinute = int.tryParse(endTime.split(':')[1]);

    if (startHour == null || startMinute == null || endHour == null || endMinute == null) return timeSlot;
    
    final start = DateTime(1970, 1, 1, startHour, startMinute);
    final end = DateTime(1970, 1, 1, endHour, endMinute);
    
    final localeString = Localizations.localeOf(context).languageCode;
    return '${DateFormat('h:mm a', localeString).format(start)} - ${DateFormat('h:mm a', localeString).format(end)}';
  }

  String _formatDuration(String timeSlot) {
    final times = timeSlot.split('-');
    if (times.length != 2) return '';
    
    final startTime = times[0];
    final endTime = times[1];
    
    final startHour = int.tryParse(startTime.split(':')[0]);
    final startMinute = int.tryParse(startTime.split(':')[1]);
    final endHour = int.tryParse(endTime.split(':')[0]);
    final endMinute = int.tryParse(endTime.split(':')[1]);

    if (startHour == null || startMinute == null || endHour == null || endMinute == null) return '';
    
    final durationMinutes = (endHour * 60 + endMinute) - (startHour * 60 + startMinute);
    
    return '$durationMinutes ${context.loc.minsSuffix}';
  }

  Future<void> _openMapsOptions(BuildContext context) async {
    final urlGoogle = 'https://www.google.com/maps/search/?api=1&query=${widget.footballField.latitude},${widget.footballField.longitude}';
    final urlApple = 'http://maps.apple.com/?ll=${widget.footballField.latitude},${widget.footballField.longitude}';
    final Uri uriGoogle = Uri.parse(urlGoogle);
    final Uri uriApple = Uri.parse(urlApple);

    showModalBottomSheet(
      context: context,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.map),
                title: Text(sheetContext.loc.openInGoogleMaps),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  if (await canLaunchUrl(uriGoogle)) {
                    await launchUrl(uriGoogle);
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(context.loc.couldNotLaunchGoogleMaps)),
                      );
                    }
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.map_outlined),
                title: Text(sheetContext.loc.openInAppleMaps),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  if (await canLaunchUrl(uriApple)) {
                    await launchUrl(uriApple);
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(context.loc.couldNotLaunchAppleMaps)),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCard({required Widget child, EdgeInsets? padding}) {
    return Container(
      width: double.infinity,
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
        padding: padding ?? const EdgeInsets.all(20),
        child: child,
      ),
    );
  }

  Widget _buildSectionTitle(String title, {IconData? icon, Widget? trailing}) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, color: const Color(0xFF00BF63), size: 20),
          const SizedBox(width: 8),
        ],
        Text(
          title,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.black87,
          ),
        ),
        if (trailing != null) ...[
          const Spacer(),
          trailing,
        ],
      ],
    );
  }

  Widget _buildMatchDetailsCard() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(context.loc.matchInformationSectionTitle, icon: Icons.sports_soccer),
          const SizedBox(height: 16),

          // Main Information Row - Venue + Key Details
          Row(
            children: [
              // Venue Information
              Expanded(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00BF63).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.stadium, color: Color(0xFF00BF63), size: 18),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.footballField.footballFieldName,
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.footballField.locationName,
                                  style: GoogleFonts.inter(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(width: 12),
              
              // Compact Map
              Container(
                width: 90,
                height: 75,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      FutureBuilder<LocationPermission>(
                        future: Geolocator.checkPermission(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return Container(
                              color: Colors.grey[100],
                              child: const Center(
                                child: SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(strokeWidth: 1.5),
                                ),
                              ),
                            );
                          }
                          if (snapshot.data == LocationPermission.denied || snapshot.data == LocationPermission.deniedForever) {
                            return Container(
                              color: Colors.grey[100],
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.location_off, size: 16, color: Colors.grey[400]),
                                    const SizedBox(height: 2),
                                    Text(
                                      'No Access',
                                      style: GoogleFonts.inter(
                                        color: Colors.grey[500],
                                        fontSize: 8,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                          return GoogleMap(
                            initialCameraPosition: CameraPosition(
                              target: LatLng(widget.footballField.latitude, widget.footballField.longitude),
                              zoom: 16.0,
                            ),
                            markers: {
                              Marker(
                                markerId: const MarkerId('fieldMarker'),
                                position: LatLng(widget.footballField.latitude, widget.footballField.longitude),
                                icon: _customIcon ?? BitmapDescriptor.defaultMarker,
                              ),
                            },
                            myLocationButtonEnabled: false,
                            myLocationEnabled: false,
                            zoomControlsEnabled: false,
                            mapToolbarEnabled: false,
                            onTap: (_) => _openMapsOptions(context),
                          );
                        },
                      ),
                      Positioned.fill(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _openMapsOptions(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Details Grid - Date, Time, Host in compact layout
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF00BF63).withOpacity(0.1)),
            ),
            child: Column(
              children: [
                // Date and Time Row
                Row(
                  children: [
                    Expanded(
                      child: _buildCompactDetailItem(
                        icon: Icons.calendar_today,
                        label: context.loc.dateLabel,
                        value: _formatDateCompact(_booking.date),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 30,
                      color: Colors.grey[200],
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    Expanded(
                      child: _buildCompactDetailItem(
                        icon: Icons.access_time,
                        label: context.loc.timeLabel,
                        value: _formatTimeRange(_booking.timeSlot),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 30,
                      color: Colors.grey[200],
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    Expanded(
                      child: _buildCompactDetailItem(
                        icon: Icons.timer_outlined,
                        label: 'Duration',
                        value: _formatDuration(_booking.timeSlot),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                Divider(height: 1, color: Colors.grey[100]),
                const SizedBox(height: 16),
                
                // Host and Directions Row
                Row(
                  children: [
                    // Host Information - Compact
                    Expanded(
                      child: FutureBuilder<PlayerProfile?>(
                        future: _fetchUserProfile(_booking.host),
                        builder: (context, snapshot) {
                          final isHost = widget.currentUserId == _booking.host;
                          return Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isHost ? const Color(0xFF00BF63) : Colors.grey[300]!,
                                    width: 1.5,
                                  ),
                                ),
                                child: ClipOval(
                                  child: snapshot.hasData && snapshot.data!.profilePicture.isNotEmpty
                                    ? Image.network(
                                        snapshot.data!.profilePicture,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            color: Colors.grey[200],
                                            child: Icon(
                                              Icons.person,
                                              color: Colors.grey[400],
                                              size: 20,
                                            ),
                                          );
                                        },
                                      )
                                    : Container(
                                        color: Colors.grey[200],
                                        child: Icon(
                                          Icons.person,
                                          color: Colors.grey[400],
                                          size: 20,
                                        ),
                                      ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      context.loc.hostLabel,
                                      style: GoogleFonts.inter(
                                        color: Colors.grey[500],
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      snapshot.hasData ? snapshot.data!.name : context.loc.unableToLoadHost,
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: Colors.black87,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              if (isHost)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00BF63).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    context.loc.youSuffix,
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF00BF63),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                    
                    const SizedBox(width: 12),
                    
                    // Directions Button - Compact
                    OutlinedButton.icon(
                      onPressed: () => _openMapsOptions(context),
                      icon: const Icon(Icons.directions, size: 14),
                      label: Text(
                        'Directions',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF00BF63),
                        side: const BorderSide(color: Color(0xFF00BF63), width: 1),
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        minimumSize: const Size(0, 32),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Description Section (if available)
          if (_booking.description != null && _booking.description!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.description_outlined, color: const Color(0xFF00BF63), size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Match Description',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _booking.description!,
                    style: GoogleFonts.inter(
                      color: Colors.grey[700],
                      height: 1.5,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactDetailItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF00BF63), size: 18),
        const SizedBox(height: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.grey[500],
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: Colors.black87,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildPlayersCard() {
    final bool isHost = widget.currentUserId == _booking.host;
    final bool isParticipant = _booking.invitePlayers.contains(widget.currentUserId);
    final now = DateTime.now();
    final bookingDate = DateTime.parse(_booking.date);
    final timeParts = _booking.timeSlot.split('-');
    bool isPastMatch = false;
    if (timeParts.length == 2) {
      final endTimeString = timeParts[1];
      final endHour = int.tryParse(endTimeString.split(':')[0]);
      final endMinute = int.tryParse(endTimeString.split(':')[1]);
      if (endHour != null && endMinute != null) {
        final endDateTime = bookingDate.add(Duration(hours: endHour, minutes: endMinute));
        isPastMatch = endDateTime.isBefore(now);
      }
    }

    return _buildCard(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            context.loc.playersSectionTitle,
            icon: Icons.group_outlined,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00BF63).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _booking.maxPlayers != null && _booking.maxPlayers! > 0
                        ? '${_booking.invitePlayers.length}/${_booking.maxPlayers}'
                        : '${_booking.invitePlayers.length}',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF00BF63),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                if ((isHost || isParticipant) && !isPastMatch) ...[
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.person_add, size: 20),
                    onPressed: (_booking.maxPlayers != null && _booking.invitePlayers.length >= _booking.maxPlayers!) 
                        ? null 
                        : () => _showAddPlayersBottomSheet(context),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF00BF63),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(36, 36),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          ListView.separated(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _booking.invitePlayers.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final playerId = _booking.invitePlayers[index];
              final bool isCurrentPlayerHost = playerId == _booking.host;
              
              if (playerId.startsWith('guest')) {
                final parts = playerId.split('+');
                if (parts.length == 2) {
                  final guestNumberString = parts[0].replaceAll('guest', '');
                  final hostIdForGuest = parts[1];
                  return FutureBuilder<PlayerProfile?>(
                    future: _fetchUserProfile(hostIdForGuest),
                    builder: (context, hostSnapshot) {
                      if (!hostSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                      }
                      final guestProfile = PlayerProfile(
                        id: playerId,
                        name: context.loc.guestLabel(guestNumberString),
                        personalLevel: context.loc.guestLabel(''),
                        email: '', nationality: '', age: '', preferredPosition: '', profilePicture: '', playerId: '',
                      );
                      return PlayerTile(
                        playerProfile: guestProfile,
                        isGuest: true,
                        guestHostName: hostSnapshot.data!.name,
                        showPosition: false,
                        showPlayerId: false,
                        onTap: () {
                          if (_currentUserProfile != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PlayerDetailsScreen(
                                  player: hostSnapshot.data!,
                                  currentUserProfile: _currentUserProfile!,
                                ),
                              ),
                            );
                          }
                        },
                      );
                    },
                  );
                }
              } else {
                return FutureBuilder<PlayerProfile?>(
                  future: _fetchUserProfile(playerId),
                  builder: (context, playerSnapshot) {
                    if (playerSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                    }
                    if (!playerSnapshot.hasData || playerSnapshot.data == null) {
                      // fallback for fake users
                      return PlayerTile(
                        playerProfile: PlayerProfile(
                          id: playerId,
                          name: 'Player ${playerId.replaceAll('fake_', '')}',
                          email: '', nationality: '', age: '', preferredPosition: '',
                          profilePicture: 'https://ui-avatars.com/api/?name=Player+${playerId.replaceAll('fake_', '')}&background=random',
                        ),
                        isHostContext: isCurrentPlayerHost,
                        onTap: () {},
                      );
                    }
                    final playerProfile = playerSnapshot.data!;
                    return PlayerTile(
                      playerProfile: playerProfile,
                      isHostContext: isCurrentPlayerHost,
                      onTap: () {
                        if (_currentUserProfile != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PlayerDetailsScreen(
                                player: playerProfile,
                                currentUserProfile: _currentUserProfile!,
                              ),
                            ),
                          );
                        }
                      },
                    );
                  },
                );
              }
              return const SizedBox.shrink(); // Fallback
            },
          ),
          // --- WAITING LIST (Pending Requests) ---
          if (_booking.openJoiningRequests.isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.hourglass_top_rounded, size: 16, color: Colors.orange.shade700),
                ),
                const SizedBox(width: 10),
                Text(
                  'Waiting List',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange.shade800,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _booking.openJoiningRequests.length.toString(),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListView.separated(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _booking.openJoiningRequests.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final request = _parseJoinRequest(_booking.openJoiningRequests[index]);
                final playerId = request['playerId'];
                final guestCount = request['guestCount'] as int;
                
                return FutureBuilder<PlayerProfile?>(
                  future: _supabaseService.getUserProfileById(playerId),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      );
                    }
                    final playerProfile = snapshot.data!;
                    
                    // Host sees accept/decline, others see pending status
                    if (isHost) {
                      return PlayerTile(
                        playerProfile: playerProfile,
                        showPosition: true,
                        actionType: PlayerTileActionType.acceptDecline,
                        onAccept: () => _acceptJoinRequest(playerProfile, guestCount),
                        onDecline: () => _declineJoinRequest(playerId),
                        onTap: () => _navigateToPlayerDetails(playerProfile),
                      );
                    } else {
                      // Non-host users see pending status
                      return PlayerTile(
                        playerProfile: playerProfile,
                        showPosition: true,
                        actionType: PlayerTileActionType.statusText,
                        statusText: guestCount > 0 ? 'Pending (+$guestCount)' : 'Pending',
                        statusTextColor: Colors.orange.shade700,
                        onTap: () => _navigateToPlayerDetails(playerProfile),
                      );
                    }
                  },
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Booking?>(
      stream: _bookingStream,
      initialData: _booking,
      builder: (context, snapshot) {
        // Handle errors gracefully - continue showing last known data
        if (snapshot.hasError) {
          print('⚠️ Match details stream error: ${snapshot.error}');
          // If we have cached booking data, continue showing it
          // The robust stream wrapper will handle reconnection
          if (_booking.id.isNotEmpty) {
            // Show a subtle error indicator but keep the UI functional
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Connection issue, reconnecting...'),
                    duration: Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            });
          }
        }
        
        // Use snapshot data if available, otherwise use cached booking
        if (snapshot.hasData && snapshot.data != null) {
          _booking = snapshot.data!;
        } else if (!snapshot.hasData && _booking.id.isEmpty) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        
        // Continue with the last known booking data
        final now = DateTime.now();
        final bookingDate = DateTime.parse(_booking.date);
        final timeParts = _booking.timeSlot.split('-');
        bool isPastMatch = false;
        
        if (timeParts.length == 2) {
          final endTimeString = timeParts[1];
          final endHour = int.tryParse(endTimeString.split(':')[0]);
          final endMinute = int.tryParse(endTimeString.split(':')[1]);
          if (endHour != null && endMinute != null) {
            final endDateTime = bookingDate.add(Duration(hours: endHour, minutes: endMinute));
            isPastMatch = endDateTime.isBefore(now);
          }
        }
        
        final bool isHost = widget.currentUserId == _booking.host;
        final bool isParticipant = _booking.invitePlayers.contains(widget.currentUserId);
        final bool hasRequestedToJoin = _booking.openJoiningRequests.any((request) {
          try {
            final decoded = jsonDecode(request);
            return decoded['playerId'] == widget.currentUserId;
          } catch (e) {
            return false;
          }
        });

        if (_currentUserProfile == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        return Scaffold(
          backgroundColor: Colors.grey[50],
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverOverlapAbsorber(
                  handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                  sliver: SliverAppBar(
                    elevation: 0,
                    pinned: true,
                    forceElevated: innerBoxIsScrolled,
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    centerTitle: true,
                    title: Text(
                      context.loc.matchDetailsTitle,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.black87,
                      ),
                    ),
                    bottom: PreferredSize(
                      preferredSize: const Size.fromHeight(48),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          indicatorColor: const Color(0xFF00BF63),
                          indicatorWeight: 3,
                          labelColor: const Color(0xFF00BF63),
                          unselectedLabelColor: Colors.grey[600],
                          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
                          tabs: [
                            Tab(text: context.loc.detailsTab),
                            Tab(text: context.loc.chatTab),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildDetailsTab(isHost, isParticipant, hasRequestedToJoin, isPastMatch),
                MatchChatWidget(
                  bookingId: _booking.id,
                  currentUserId: widget.currentUserId,
                  currentUserName: _currentUserProfile!.name,
                  currentUserProfile: _currentUserProfile!,
                  isParticipant: isParticipant,
                ),
              ],
            ),
          ),
          bottomNavigationBar: (!isParticipant && !isHost && !isPastMatch)
              ? Container(
                  padding: const EdgeInsets.all(20),
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
                  child: hasRequestedToJoin
                      ? Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 56,
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.orange.shade200),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.hourglass_top_rounded, size: 18, color: Colors.orange.shade700),
                                    const SizedBox(width: 8),
                                    Text(
                                      context.loc.joinRequestPending,
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.orange.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              height: 56,
                              child: OutlinedButton(
                                onPressed: () => _cancelJoinRequest(),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                ),
                                child: Text(
                                  'Cancel',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : FilledButton(
                          onPressed: () => _showJoinOptionsBottomSheet(context),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(56),
                            backgroundColor: const Color(0xFF00BF63),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.sports_soccer, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                context.loc.joinMatchButton,
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                )
              : null,
        );
      },
    );
  }

  Widget _buildDetailsTab(bool isHost, bool isParticipant, bool hasRequestedToJoin, bool isPastMatch) {
    return SafeArea(
      top: false,
      bottom: false,
      child: Builder(
        builder: (context) {
          return CustomScrollView(
            key: const PageStorageKey<String>('detailsScroll'),
            slivers: [
              SliverOverlapInjector(
                handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildMatchDetailsCard(),
                    const SizedBox(height: 20),
                    MatchRecordingWidget(booking: _booking),
                    const SizedBox(height: 20),
                    _buildPlayersCard(),
                    const SizedBox(height: 20),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _navigateToPlayerDetails(PlayerProfile playerProfile) {
    if (_currentUserProfile != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PlayerDetailsScreen(
            player: playerProfile,
            currentUserProfile: _currentUserProfile!,
          ),
        ),
      );
    }
  }

  Future<void> _cancelJoinRequest() async {
    // Demo guard
    if (_booking.id.startsWith('demo_')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Join request cancelled'), backgroundColor: Colors.orange),
        );
      }
      return;
    }
    try {
      final List<String> updatedRequests = List<String>.from(_booking.openJoiningRequests)
        ..removeWhere((request) => _parseJoinRequest(request)['playerId'] == widget.currentUserId);
      await _supabaseService.updateBookingJoinRequests(_booking.id, updatedRequests);
      if (mounted) {
        setState(() {
          _booking = _booking.copyWith(openJoiningRequests: updatedRequests);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Join request cancelled'),
            backgroundColor: Colors.orange.shade700,
          ),
        );
      }
    } catch (e) {
      print('Error cancelling join request: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to cancel request: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showJoinOptionsBottomSheet(BuildContext context) {
    int guestCount = 0;
    bool joinAloneSelected = true;
    bool joinWithGuestsSelected = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext modalContext, StateSetter modalSetState) {
            return Container(
              height: MediaQuery.of(modalContext).size.height * 0.7,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    height: 4, width: 40,
                    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(Icons.sports_soccer, color: Theme.of(modalContext).primaryColor, size: 32),
                          const SizedBox(width: 12),
                          Text(modalContext.loc.joinMatchSheetTitle, style: Theme.of(modalContext).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                        ]),
                        const SizedBox(height: 24),
                        Container(
                          decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                          child: Column(children: [
                            InkWell(
                              onTap: () {
                                modalSetState(() {
                                  joinAloneSelected = true; joinWithGuestsSelected = false; guestCount = 0;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(color: joinAloneSelected ? Theme.of(modalContext).primaryColor.withOpacity(0.1) : null, borderRadius: const BorderRadius.vertical(top: Radius.circular(12))),
                                child: Row(children: [
                                  Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: joinAloneSelected ? Theme.of(modalContext).primaryColor : Colors.grey[300], shape: BoxShape.circle), child: Icon(Icons.person, color: joinAloneSelected ? Colors.white : Colors.grey[600])),
                                  const SizedBox(width: 16),
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(modalContext.loc.joinAloneOption, style: TextStyle(fontWeight: FontWeight.bold, color: joinAloneSelected ? Theme.of(modalContext).primaryColor : Colors.black)),
                                    Text(modalContext.loc.joinAloneSubtitle, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                  ])),
                                  if (joinAloneSelected) Icon(Icons.check_circle, color: Theme.of(modalContext).primaryColor),
                                ]),
                              ),
                            ),
                            Divider(height: 1, color: Colors.grey[300]),
                            InkWell(
                              onTap: () {
                                modalSetState(() {
                                  joinAloneSelected = false; joinWithGuestsSelected = true;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(color: joinWithGuestsSelected ? Theme.of(modalContext).primaryColor.withOpacity(0.1) : null, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12))),
                                child: Row(children: [
                                  Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: joinWithGuestsSelected ? Theme.of(modalContext).primaryColor : Colors.grey[300], shape: BoxShape.circle), child: Icon(Icons.group, color: joinWithGuestsSelected ? Colors.white : Colors.grey[600])),
                                  const SizedBox(width: 16),
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(modalContext.loc.joinWithGuestsOption, style: TextStyle(fontWeight: FontWeight.bold, color: joinWithGuestsSelected ? Theme.of(modalContext).primaryColor : Colors.black)),
                                    Text(modalContext.loc.joinWithGuestsSubtitle, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                  ])),
                                  if (joinWithGuestsSelected) Icon(Icons.check_circle, color: Theme.of(modalContext).primaryColor),
                                ]),
                              ),
                            ),
                          ]),
                        ),
                      ],
                    ),
                  ),
                  if (joinWithGuestsSelected) Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text(modalContext.loc.numberOfGuestsLabel, style: Theme.of(modalContext).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        Row(children: [
                          IconButton(onPressed: guestCount > 0 ? () => modalSetState(() => guestCount--) : null, icon: Icon(Icons.remove_circle_outline, color: guestCount > 0 ? Theme.of(modalContext).primaryColor : Colors.grey[400])),
                          Text('$guestCount', style: Theme.of(modalContext).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                          IconButton(onPressed: guestCount < 5 ? () => modalSetState(() => guestCount++) : null, icon: Icon(Icons.add_circle_outline, color: guestCount < 5 ? Theme.of(modalContext).primaryColor : Colors.grey[400])),
                        ]),
                      ]),
                    ]),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        if (joinAloneSelected) { _joinMatch(); } else { _joinMatchWithGuests(guestCount); }
                      },
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: Text(joinAloneSelected ? modalContext.loc.joinMatchButton : modalContext.loc.joinWithXGuestsButton(guestCount.toString()), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _acceptJoinRequest(PlayerProfile requestingPlayerProfile, int guestCount) async {
    try {
      final bool isAlreadyParticipant = _booking.invitePlayers.contains(requestingPlayerProfile.id);
      List<String> itemsToAdd = [];
      if (!isAlreadyParticipant) {
        itemsToAdd.add(requestingPlayerProfile.id);
      }
      for (int i = 0; i < guestCount; i++) {
        itemsToAdd.add('guest${i + 1}+${requestingPlayerProfile.id}');
      }
      final List<String> currentPlayers = List<String>.from(_booking.invitePlayers);
      final int? maxPlayers = _booking.maxPlayers;

      if (maxPlayers != null && currentPlayers.length + itemsToAdd.length > maxPlayers) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.loc.cannotAcceptRequestMaxPlayers(itemsToAdd.length.toString(), maxPlayers.toString())),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      final List<String> updatedPlayers = [...currentPlayers, ...itemsToAdd];
      final List<String> updatedRequests = List<String>.from(_booking.openJoiningRequests)
        ..removeWhere((request) => _parseJoinRequest(request)['playerId'] == requestingPlayerProfile.id);

      await Future.wait([
        _supabaseService.updateBookingPlayers(_booking.id, updatedPlayers),
        _supabaseService.updateBookingJoinRequests(_booking.id, updatedRequests),
      ]);

      if (mounted) {
        setState(() {
          _booking = _booking.copyWith(
            invitePlayers: updatedPlayers,
            openJoiningRequests: updatedRequests,
          );
        });
        String snackbarMessage;
        if (isAlreadyParticipant) {
          snackbarMessage = context.loc.guestRequestApprovedSnackbar(requestingPlayerProfile.name, guestCount.toString());
        } else {
          if (guestCount > 0) {
            snackbarMessage = context.loc.playerAddedWithGuestsSnackbar(requestingPlayerProfile.name, guestCount.toString());
          } else {
            snackbarMessage = context.loc.playerAddedToMatchSnackbar(requestingPlayerProfile.name);
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(snackbarMessage), backgroundColor: Colors.green),
        );
        
        // Send notification to the accepted player (fire-and-forget)
        final hostName = _currentUserProfile?.name ?? 'The host';
        _notificationService.sendJoinRequestAcceptedNotification(
          toUserId: requestingPlayerProfile.id,
          hostName: hostName,
          fieldName: widget.footballField.footballFieldName,
          date: _booking.date,
          timeSlot: _booking.timeSlot,
        );
      }
    } catch (e) {
      print('Error accepting join request: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.loc.failedToAcceptJoinRequest), backgroundColor: Colors.red),
        );
      }
      try {
        final updatedBooking = await _supabaseService.getBookingById(_booking.id);
        if (updatedBooking != null && mounted) {
          setState(() { _booking = updatedBooking; });
        }
      } catch (fetchError) {
        print('Error re-fetching booking: $fetchError');
         if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.loc.errorRefreshingBooking(fetchError.toString()))),
            );
          }
      }
    }
  }

  Future<void> _declineJoinRequest(String playerId) async {
    try {
      final List<String> updatedRequests = List<String>.from(_booking.openJoiningRequests)
        ..removeWhere((request) => _parseJoinRequest(request)['playerId'] == playerId);
      await _supabaseService.updateBookingJoinRequests(_booking.id, updatedRequests);
      if (mounted) {
        setState(() {
          _booking = _booking.copyWith(openJoiningRequests: updatedRequests);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.loc.declinedJoinRequestSnackbar), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      print('Error declining join request: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.loc.failedToDeclineJoinRequestSnackbar), backgroundColor: Colors.red),
        );
      }
      try {
        final updatedBooking = await _supabaseService.getBookingById(_booking.id);
        if (updatedBooking != null && mounted) {
          setState(() { _booking = updatedBooking; });
        }
      } catch (fetchError) {
        print('Error re-fetching booking: $fetchError');
        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.loc.errorRefreshingBooking(fetchError.toString()))),
            );
          }
      }
    }
  }

  Map<String, dynamic> _parseJoinRequest(String encodedRequest) {
    try {
      return jsonDecode(encodedRequest);
    } catch (e) {
      print('Error parsing join request: $e');
      if (mounted) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text(context.loc.errorParsingJoinRequest(e.toString()))),
        // );
      }
      return {'playerId': '', 'guestCount': 0, 'timestamp': 0};
    }
  }

  void _showAddPlayersBottomSheet(BuildContext context) {
    bool addGuestsSelected = false;
    bool addFriendsSelected = false;
    bool addSquadSelected = false;
    int guestCount = 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext modalContext, StateSetter modalSetState) {
            final int? maxPlayers = _booking.maxPlayers;
            final int currentPlayers = _booking.invitePlayers.length;
            final int availableSlots = maxPlayers != null ? maxPlayers - currentPlayers : 999;
            final bool canAddMore = availableSlots > 0;
            final bool canAddMoreGuests = guestCount < availableSlots;
            final bool canAddSelectedGuests = addGuestsSelected && guestCount > 0 && guestCount <= availableSlots;
            final bool isHost = widget.currentUserId == _booking.host;

            return Container(
              height: MediaQuery.of(modalContext).size.height * 0.7,
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              child: Column(children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  height: 4, width: 40,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(Icons.group_add, color: Theme.of(modalContext).primaryColor, size: 32),
                      const SizedBox(width: 12),
                      Text(modalContext.loc.addPlayersSheetTitle, style: Theme.of(modalContext).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 24),
                    Container(
                      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                      child: Column(children: [
                        InkWell(
                          onTap: () {
                            modalSetState(() { addGuestsSelected = !addGuestsSelected; addFriendsSelected = false; addSquadSelected = false; });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: addGuestsSelected ? Theme.of(modalContext).primaryColor.withOpacity(0.1) : null, borderRadius: const BorderRadius.vertical(top: Radius.circular(12))),
                            child: Row(children: [
                              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: addGuestsSelected ? Theme.of(modalContext).primaryColor : Colors.grey[300], shape: BoxShape.circle), child: Icon(Icons.person_add, color: addGuestsSelected ? Colors.white : Colors.grey[600])),
                              const SizedBox(width: 16),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(modalContext.loc.addGuestsOption, style: TextStyle(fontWeight: FontWeight.bold, color: addGuestsSelected ? Theme.of(modalContext).primaryColor : Colors.black)),
                                Text(modalContext.loc.addGuestsSubtitle, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                              ])),
                              if (addGuestsSelected) Icon(Icons.check_circle, color: Theme.of(modalContext).primaryColor),
                            ]),
                          ),
                        ),
                        Divider(height: 1, color: Colors.grey[300]),
                        InkWell(
                          onTap: () {
                            modalSetState(() { addGuestsSelected = false; addFriendsSelected = true; addSquadSelected = false; });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: addFriendsSelected ? Theme.of(modalContext).primaryColor.withOpacity(0.1) : null),
                            child: Row(children: [
                              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: addFriendsSelected ? Theme.of(modalContext).primaryColor : Colors.grey[300], shape: BoxShape.circle), child: Icon(Icons.people, color: addFriendsSelected ? Colors.white : Colors.grey[600])),
                              const SizedBox(width: 16),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(modalContext.loc.addFriendsOption, style: TextStyle(fontWeight: FontWeight.bold, color: addFriendsSelected ? Theme.of(modalContext).primaryColor : Colors.black)),
                                Text(modalContext.loc.addFriendsSubtitle, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                              ])),
                              if (addFriendsSelected) Icon(Icons.check_circle, color: Theme.of(modalContext).primaryColor),
                            ]),
                          ),
                        ),
                        Divider(height: 1, color: Colors.grey[300]),
                        InkWell(
                          onTap: () async {
                            final squads = await _supabaseService.fetchSquads(widget.currentUserId);
                            if (squads.isEmpty) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.loc.youAreNotMemberOfSquads)));
                              return;
                            }
                            modalSetState(() { addGuestsSelected = false; addFriendsSelected = false; addSquadSelected = true; guestCount = 0; });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: addSquadSelected ? Theme.of(modalContext).primaryColor.withOpacity(0.1) : null, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12))),
                            child: Row(children: [
                              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: addSquadSelected ? Theme.of(modalContext).primaryColor : Colors.grey[300], shape: BoxShape.circle), child: Icon(Icons.groups, color: addSquadSelected ? Colors.white : Colors.grey[600])),
                              const SizedBox(width: 16),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(modalContext.loc.addSquadOption, style: TextStyle(fontWeight: FontWeight.bold, color: addSquadSelected ? Theme.of(modalContext).primaryColor : Colors.black)),
                                Text(modalContext.loc.addSquadSubtitle, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                              ])),
                              if (addSquadSelected) Icon(Icons.check_circle, color: Theme.of(modalContext).primaryColor),
                            ]),
                          ),
                        ),
                      ]),
                    ),
                  ]),
                ),
                if (addGuestsSelected) Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(modalContext.loc.numberOfGuestsLabel, style: Theme.of(modalContext).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      Row(children: [
                        IconButton(onPressed: guestCount > 0 ? () => modalSetState(() => guestCount--) : null, icon: Icon(Icons.remove_circle_outline, color: guestCount > 0 ? Theme.of(modalContext).primaryColor : Colors.grey[400])),
                        Text('$guestCount', style: Theme.of(modalContext).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                        IconButton(onPressed: canAddMore && guestCount < 5 ? () => modalSetState(() => guestCount++) : null, icon: Icon(Icons.add_circle_outline, color: canAddMore && guestCount < 5 ? Theme.of(modalContext).primaryColor : Colors.grey[400])),
                      ]),
                    ]),
                  ]),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Builder(builder: (buttonContext) {
                    VoidCallback? onPressedAction;
                    String buttonText;
                    bool isButtonEnabled = false;
                    if (isHost) {
                      if (addGuestsSelected && canAddSelectedGuests) {
                        onPressedAction = () => _addGuests(guestCount);
                        buttonText = buttonContext.loc.addedXGuestsSnackbar(guestCount.toString()).split(" ").first + " " + buttonContext.loc.addGuestsOption;
                        isButtonEnabled = true;
                      } else if (addFriendsSelected && canAddMore) {
                        onPressedAction = () => _navigateToFriendsList();
                        buttonText = buttonContext.loc.addFriendsOption;
                        isButtonEnabled = true;
                      } else if (addSquadSelected && canAddMore) {
                        onPressedAction = () => _navigateToSquadsList();
                        buttonText = buttonContext.loc.addSquadOption;
                        isButtonEnabled = true;
                      } else {
                        buttonText = buttonContext.loc.selectAction;
                      }
                    } else {
                      if (addGuestsSelected && guestCount > 0 && canAddMoreGuests) {
                        onPressedAction = () => _requestAddGuests(guestCount);
                        buttonText = buttonContext.loc.requestedToAddXGuests(guestCount.toString());
                        isButtonEnabled = true;
                      } else if (addFriendsSelected && canAddMore) {
                        onPressedAction = () => _navigateToFriendsListForRequest();
                        buttonText = buttonContext.loc.addFriendsOption;
                        isButtonEnabled = true;
                      } else if (addSquadSelected && canAddMore) {
                        onPressedAction = () => _navigateToSquadsListForRequest();
                        buttonText = buttonContext.loc.addSquadOption;
                        isButtonEnabled = true;
                      } else {
                        buttonText = buttonContext.loc.selectAction;
                      }
                    }
                    return FilledButton(
                      onPressed: isButtonEnabled ? () { Navigator.pop(sheetContext); onPressedAction?.call(); } : null,
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), disabledBackgroundColor: Colors.grey.shade300, backgroundColor: Theme.of(buttonContext).colorScheme.primary),
                      child: Text(buttonText, style: Theme.of(buttonContext).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
                    );
                  }),
                ),
              ]),
            );
          },
        );
      },
    );
  }

  Future<void> _addGuests(int count) async {
    if (count <= 0) return;
    try {
      final currentBooking = await _supabaseService.getBookingById(_booking.id);
      if (currentBooking == null) {
        throw Exception(context.loc.bookingNotFound);
      }
      final currentInvitePlayers = currentBooking.invitePlayers;
      int highestGuestNumber = 0;
      final hostPrefix = 'guest';
      final hostSuffix = '+${widget.currentUserId}';
      for (String player in currentInvitePlayers) {
        if (player.startsWith(hostPrefix) && player.endsWith(hostSuffix)) {
          String numberPart = player.substring(hostPrefix.length, player.length - hostSuffix.length);
          int? guestNum = int.tryParse(numberPart);
          if (guestNum != null && guestNum > highestGuestNumber) {
            highestGuestNumber = guestNum;
          }
        }
      }
      List<String> guestIds = [];
      for (int i = 1; i <= count; i++) {
        guestIds.add('guest${highestGuestNumber + i}+${widget.currentUserId}');
      }
      await _supabaseService.addPlayersToBooking(_booking.id, guestIds);
      
      // Update local state immediately for instant UI feedback
      if (mounted) {
        setState(() {
          _booking = _booking.copyWith(
            invitePlayers: [...currentInvitePlayers, ...guestIds],
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.loc.addedXGuestsSnackbar(count.toString())), backgroundColor: Theme.of(context).colorScheme.primary),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.loc.errorAddingGuestsSnackbar(e.toString())), backgroundColor: Theme.of(context).colorScheme.error),
      );
    }
  }

  void _navigateToFriendsList() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FriendsScreen(
          playerProfile: PlayerProfile(id: widget.currentUserId, email: '', name: '', friends: [], teamsJoined: [], openFriendRequests: [], nationality: '', age: '', preferredPosition: '', personalLevel: '', profilePicture: ''),
          isSelecting: true,
          onPlayersSelected: (selectedPlayers) async {
            final int? maxPlayers = _booking.maxPlayers;
            final int currentPlayers = _booking.invitePlayers.length;
            if (maxPlayers != null && currentPlayers + selectedPlayers.length > maxPlayers) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.loc.cannotAddSquadMembersLimitReached('', maxPlayers.toString())), backgroundColor: Theme.of(context).colorScheme.error),
                );
              }
              return;
            }
            try {
              final playerIds = selectedPlayers.map((p) => p.id).toList();
              await _supabaseService.addPlayersToBooking(_booking.id, playerIds);
              
              // Update local state immediately for instant UI feedback
              if (mounted) {
                setState(() {
                  _booking = _booking.copyWith(
                    invitePlayers: [..._booking.invitePlayers, ...playerIds],
                  );
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.loc.addedXPlayersSnackbar(selectedPlayers.length.toString())), backgroundColor: Theme.of(context).colorScheme.primary),
                );
              }
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(context.loc.errorAddingPlayersSnackbar(e.toString())), backgroundColor: Theme.of(context).colorScheme.error),
              );
            }
          },
        ),
      ),
    );
  }

  void _navigateToSquadsList() async {
    final squads = await _supabaseService.fetchSquads(widget.currentUserId);
    if (!mounted) return;
    if (squads.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.loc.youAreNotMemberOfSquads)));
      return;
    }
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(dialogContext.loc.selectSquadTitle),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: squads.length,
            itemBuilder: (context, index) {
              final squad = squads[index];
              return ListTile(
                title: Text(squad.squadName),
                subtitle: Text('${squad.squadMembers.length} ${context.loc.membersSuffix}'),
                onTap: () async {
                  Navigator.pop(dialogContext);
                  try {
                    final membersToAdd = squad.squadMembers.where((id) => !_booking.invitePlayers.contains(id)).toList();
                    final int? maxPlayers = _booking.maxPlayers;
                    final int currentPlayers = _booking.invitePlayers.length;
                    if (maxPlayers != null && currentPlayers + membersToAdd.length > maxPlayers) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(context.loc.cannotAddSquadMembersLimitReached(squad.squadName, maxPlayers.toString())), backgroundColor: Theme.of(context).colorScheme.error),
                        );
                      }
                      return;
                    }
                    if (membersToAdd.isEmpty) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.loc.allSquadMembersAlreadyInMatch)));
                      }
                      return;
                    }
                    await _supabaseService.addPlayersToBooking(_booking.id, membersToAdd);
                    
                    // Update local state immediately for instant UI feedback
                    if (mounted) {
                      setState(() {
                        _booking = _booking.copyWith(
                          invitePlayers: [..._booking.invitePlayers, ...membersToAdd],
                        );
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(context.loc.sentXSquadJoinRequests(membersToAdd.length.toString(), squad.squadName)), backgroundColor: Theme.of(context).colorScheme.primary),
                      );
                    }
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(context.loc.errorAddingPlayersSnackbar(e.toString())), backgroundColor: Theme.of(context).colorScheme.error),
                    );
                  }
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(dialogContext.loc.cancel)),
        ],
      ),
    );
  }

  Future<void> _sendJoinRequestForPlayer(String playerId) async {
    if (_booking.invitePlayers.contains(playerId) || _booking.openJoiningRequests.any((req) => _parseJoinRequest(req)['playerId'] == playerId)) return;
    try {
      final joinRequest = {'playerId': playerId, 'guestCount': 0, 'timestamp': DateTime.now().millisecondsSinceEpoch};
      await _supabaseService.sendJoinRequest(_booking.id, jsonEncode(joinRequest));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.loc.failedToSendJoinRequest(e.toString()))));
      }
    }
  }

  void _navigateToFriendsListForRequest() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FriendsScreen(
          playerProfile: PlayerProfile(id: widget.currentUserId, email: '', name: '', nationality: '', age: '', preferredPosition: ''),
          isSelecting: true,
          onPlayersSelected: (selectedPlayers) async {
            int successCount = 0;
            for (var player in selectedPlayers) {
              await _sendJoinRequestForPlayer(player.id);
              successCount++;
            }
            if (mounted && successCount > 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(context.loc.sentXFriendJoinRequests(successCount.toString())), backgroundColor: Theme.of(context).colorScheme.primary),
              );
            }
          },
        ),
      ),
    );
  }

  void _navigateToSquadsListForRequest() async {
    final squads = await _supabaseService.fetchSquads(widget.currentUserId);
    if (!mounted) return;
    if (squads.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.loc.youAreNotMemberOfSquads)));
      return;
    }
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(dialogContext.loc.selectSquadToRequestTitle),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: squads.length,
            itemBuilder: (context, index) {
              final squad = squads[index];
              return ListTile(
                title: Text(squad.squadName),
                subtitle: Text('${squad.squadMembers.length} ${context.loc.membersSuffix}'),
                onTap: () async {
                  Navigator.pop(dialogContext);
                  int successCount = 0;
                  final membersToRequest = squad.squadMembers.where((id) => id != widget.currentUserId && !_booking.invitePlayers.contains(id)).toList();
                  for (var memberId in membersToRequest) {
                    await _sendJoinRequestForPlayer(memberId);
                    successCount++;
                  }
                  if (mounted && successCount > 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(context.loc.sentXSquadJoinRequests(successCount.toString(), squad.squadName)), backgroundColor: Theme.of(context).colorScheme.primary),
                    );
                  }
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(dialogContext.loc.cancel)),
        ],
      ),
    );
  }

  Future<void> _requestAddGuests(int guestCount) async {
    if (guestCount <= 0) return;
    // Demo guard
    if (_booking.id.startsWith('demo_')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.loc.requestedToAddXGuests(guestCount.toString()))));
      }
      return;
    }
    // Prevent duplicate requests
    final alreadyRequested = _booking.openJoiningRequests.any((req) {
      final parsed = _parseJoinRequest(req);
      return parsed['playerId'] == widget.currentUserId;
    });
    if (alreadyRequested) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.loc.joinRequestPending), backgroundColor: Colors.orange),
        );
      }
      return;
    }
    try {
      final joinRequest = {'playerId': widget.currentUserId, 'guestCount': guestCount, 'timestamp': DateTime.now().millisecondsSinceEpoch};
      final encodedRequest = jsonEncode(joinRequest);
      await _supabaseService.sendJoinRequest(_booking.id, encodedRequest);
      
      // Optimistically update local state
      if (mounted) {
        setState(() {
          _booking = _booking.copyWith(
            openJoiningRequests: [..._booking.openJoiningRequests, encodedRequest],
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.loc.requestedToAddXGuests(guestCount.toString()))));
      }
      
      // Send notification to host (fire-and-forget)
      final playerName = _currentUserProfile?.name ?? 'A player';
      _notificationService.sendJoinRequestNotification(
        hostUserId: _booking.host,
        requestingPlayerName: playerName,
        requestingPlayerId: widget.currentUserId,
        fieldName: widget.footballField.footballFieldName,
        date: _booking.date,
        timeSlot: _booking.timeSlot,
        bookingId: _booking.id,
        guestCount: guestCount,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.loc.failedToSendGuestAddRequest(e.toString()))));
      }
    }
  }

  Future<void> _joinMatch() async {
    // Demo guard
    if (_booking.id.startsWith('demo_')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.loc.joinRequestSent)));
      }
      return;
    }
    // Prevent duplicate requests
    final alreadyRequested = _booking.openJoiningRequests.any((req) {
      final parsed = _parseJoinRequest(req);
      return parsed['playerId'] == widget.currentUserId;
    });
    if (alreadyRequested) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.loc.joinRequestPending), backgroundColor: Colors.orange),
        );
      }
      return;
    }
    try {
      final joinRequest = { 'playerId': widget.currentUserId, 'guestCount': 0, 'timestamp': DateTime.now().millisecondsSinceEpoch };
      final encodedRequest = jsonEncode(joinRequest);
      await _supabaseService.sendJoinRequest(widget.booking.id, encodedRequest);
      
      // Optimistically update local state
      if (mounted) {
        setState(() {
          _booking = _booking.copyWith(
            openJoiningRequests: [..._booking.openJoiningRequests, encodedRequest],
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.loc.joinRequestSent)));
      }
      
      // Send notification to host (fire-and-forget)
      final playerName = _currentUserProfile?.name ?? 'A player';
      _notificationService.sendJoinRequestNotification(
        hostUserId: _booking.host,
        requestingPlayerName: playerName,
        requestingPlayerId: widget.currentUserId,
        fieldName: widget.footballField.footballFieldName,
        date: _booking.date,
        timeSlot: _booking.timeSlot,
        bookingId: _booking.id,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.loc.failedToSendJoinRequest(e.toString()))));
      }
    }
  }

  Future<void> _joinMatchWithGuests(int guestCount) async {
    // Demo guard
    if (_booking.id.startsWith('demo_')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.loc.requestedToAddXGuests(guestCount.toString()))));
      }
      return;
    }
    // Prevent duplicate requests
    final alreadyRequested = _booking.openJoiningRequests.any((req) {
      final parsed = _parseJoinRequest(req);
      return parsed['playerId'] == widget.currentUserId;
    });
    if (alreadyRequested) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.loc.joinRequestPending), backgroundColor: Colors.orange),
        );
      }
      return;
    }
    try {
      final joinRequest = { 'playerId': widget.currentUserId, 'guestCount': guestCount, 'timestamp': DateTime.now().millisecondsSinceEpoch };
      final encodedRequest = jsonEncode(joinRequest);
      await _supabaseService.sendJoinRequest(widget.booking.id, encodedRequest);
      
      // Optimistically update local state
      if (mounted) {
        setState(() {
          _booking = _booking.copyWith(
            openJoiningRequests: [..._booking.openJoiningRequests, encodedRequest],
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.loc.requestedToAddXGuests(guestCount.toString()))));
      }
      
      // Send notification to host (fire-and-forget)
      final playerName = _currentUserProfile?.name ?? 'A player';
      _notificationService.sendJoinRequestNotification(
        hostUserId: _booking.host,
        requestingPlayerName: playerName,
        requestingPlayerId: widget.currentUserId,
        fieldName: widget.footballField.footballFieldName,
        date: _booking.date,
        timeSlot: _booking.timeSlot,
        bookingId: _booking.id,
        guestCount: guestCount,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.loc.failedToSendGuestAddRequest(e.toString()))));
      }
    }
  }
}
