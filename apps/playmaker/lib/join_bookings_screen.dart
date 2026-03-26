import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:playmakerappstart/l10n/app_localizations.dart';
import 'package:playmakerappstart/models/booking_model.dart';
import 'package:playmakerappstart/models/footballfield_model.dart';
import 'package:playmakerappstart/models/user_model.dart';
import 'package:playmakerappstart/services/supabase_service.dart';
import 'package:playmakerappstart/services/demo_data_service.dart';
import 'package:playmakerappstart/fields_list_view.dart';
import 'package:playmakerappstart/match_details_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class JoinBookingsScreen extends StatefulWidget {
  final PlayerProfile playerProfile;

  const JoinBookingsScreen({Key? key, required this.playerProfile}) : super(key: key);

  @override
  _JoinBookingsScreenState createState() => _JoinBookingsScreenState();
}

class _JoinBookingsScreenState extends State<JoinBookingsScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final DemoDataService _demoService = DemoDataService();
  List<Booking> _bookings = [];
  Map<String, FootballField?> _fieldsMap = {};
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();
  String _selectedLocation = '';
  int _guestCount = 0;

  @override
  void initState() {
    super.initState();
    if (DemoDataService.isDemoAccount(widget.playerProfile.email)) {
      _demoService.initialize().then((_) => _fetchBookings());
    } else {
      _fetchBookings();
    }
  }

  Future<void> _fetchBookings() async {
    setState(() => _isLoading = true);
    try {
      // Format date as yyyy-MM-dd to match the format in Firebase
      final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
      print('Fetching bookings for date: $formattedDate'); // Debug log
      
      final fetchedBookings = await _supabaseService.getOpenBookingsByDate(formattedDate);
      print('Fetched ${fetchedBookings.length} open bookings'); // Debug log
      
      // Get unique field IDs from the bookings
      final fieldIds = fetchedBookings.map((b) => b.footballFieldId).toSet();
      print('Found ${fieldIds.length} unique field IDs'); // Debug log
      
      // Fetch field details for each booking
      final fields = await Future.wait(
        fieldIds.map((id) => _supabaseService.getFootballFieldById(id)),
      );

      // Create a map of field IDs to field objects
      final fieldsMap = <String, FootballField?>{
        for (var field in fields)
          if (field != null) field.id: field,
      };
      print('Fetched ${fieldsMap.length} fields'); // Debug log

      // DEMO ACCOUNT LOGIC: ensure the Be Pro Fun Hub field is in the map
      if (DemoDataService.isDemoAccount(widget.playerProfile.email)) {
         const beProFieldId = 'ff897aeb-a1b2-4c2a-b944-38d554878a0f';
         if (!fieldsMap.containsKey(beProFieldId)) {
           try {
             final beProField = await _supabaseService.getFootballFieldById(beProFieldId);
             if (beProField != null) {
               fieldsMap[beProField.id] = beProField;
             }
           } catch(e) {
             print('Error getting Be Pro Fun Hub field: $e');
           }
         }
      }

      setState(() {
        _fieldsMap = fieldsMap;  // Set the fields map first
        var finalBookings = _filterBookings(fetchedBookings);  // Then filter bookings
        
        // --- DEMO ACCOUNT LOGIC ---
        if (DemoDataService.isDemoAccount(widget.playerProfile.email) && _fieldsMap.isNotEmpty) {
          final demoOpenMatches = _demoService.getDemoOpenMatches(
            widget.playerProfile.id,
            _fieldsMap,
          );
          finalBookings = [...demoOpenMatches, ...finalBookings];
        }
        
        _bookings = finalBookings;
        _isLoading = false;
      });
      
      print('After filtering: ${_bookings.length} bookings'); // Debug log
    } catch (e) {
      print('Error in _fetchBookings: $e'); // Debug log
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.joinBookings_failedToLoadOpenMatches),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Booking> _filterBookings(List<Booking> bookings) {
    print('Filtering ${bookings.length} bookings'); // Debug log
    return bookings.where((booking) {
      // First check if booking is null
      if (booking == null) {
        print('Filtering out null booking'); // Debug log
        return false;
      }

      // Safely check booking properties
      if (booking.id == null || booking.footballFieldId == null) {
        print('Filtering out booking with null id or field id'); // Debug log
        return false;
      }

      // Print booking reference and isOpenMatch value for debugging
      print('Booking ${booking.bookingReference}: isOpenMatch=${booking.isOpenMatch}'); // Debug log

      // Only show bookings that are marked as open matches
      if (!booking.isOpenMatch) {
        print('Filtering out booking ${booking.bookingReference}: not an open match'); // Debug log
        return false;
      }

      // Don't show bookings where the current user is already a participant or is the host
      if (booking.invitePlayers?.contains(widget.playerProfile.id) == true || 
          booking.host == widget.playerProfile.id) {
        print('Filtering out booking ${booking.bookingReference}: user is participant or host'); // Debug log
        return false;
      }

      // Safely get field from map
      final field = _fieldsMap[booking.footballFieldId];
      if (field == null) {
        print('Filtering out booking ${booking.bookingReference}: field not found'); // Debug log
        return false;
      }

      // Safely check location filtering
      if (_selectedLocation.isNotEmpty && 
          field.locationName != null &&
          field.locationName != _selectedLocation) {
        print('Filtering out booking ${booking.bookingReference}: location mismatch'); // Debug log
        return false;
      }

      print('Including booking ${booking.bookingReference}'); // Debug log
      return true;
    }).toList();
  }

  Future<void> _joinMatch(Booking booking) async {
    try {
      final updatedInvitePlayers = [...booking.invitePlayers, widget.playerProfile.id];
      await _supabaseService.updateBookingPlayers(booking.id, updatedInvitePlayers);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.joinBookings_successfullyJoinedMatch),
            backgroundColor: const Color(0xFF00BF63),
          ),
        );
        _fetchBookings();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.joinBookings_failedToJoinMatch),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Join Open Matches',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            color: Colors.black87,
            fontSize: 20,
          ),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          SizedBox(
            height: 100,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: 14,
              itemBuilder: (context, index) {
                final date = DateTime.now().add(Duration(days: index));
                return _DateCard(
                  date: date,
                  isSelected: _isSameDate(date, _selectedDate),
                  onTap: () {
                    setState(() => _selectedDate = date);
                    _fetchBookings();
                  },
                );
              },
            ),
          ),
          if (_selectedLocation.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    label: Text(_selectedLocation),
                    selected: true,
                    onSelected: (_) => setState(() {
                      _selectedLocation = '';
                      _bookings = _filterBookings(_bookings);
                    }),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onDeleted: () => setState(() {
                      _selectedLocation = '';
                      _bookings = _filterBookings(_bookings);
                    }),
                  ),
                ],
              ),
            ),
          if (_isLoading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_bookings.isEmpty)
            Expanded(
              child: _EmptyState(
                onBookField: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FieldsListView(
                      playerProfile: widget.playerProfile,
                    ),
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _bookings.length,
                itemBuilder: (context, index) {
                  final booking = _bookings[index];
                  final field = _fieldsMap[booking.footballFieldId];
                  
                  if (field == null) {
                    return const SizedBox.shrink();
                  }

                  return _BookingCard(
                    booking: booking,
                    field: field,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MatchDetailsScreen(
                          booking: booking,
                          currentUserId: widget.playerProfile.id,
                          footballField: field,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showFilterSheet(),
        child: const Icon(Icons.tune),
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FilterBottomSheet(
        selectedLocation: _selectedLocation,
        onLocationChanged: (location) => setState(() {
          _selectedLocation = location;
          _bookings = _filterBookings(_bookings);
        }),
      ),
    );
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

// Clean, simplified date card from FieldBookingScreen
class _DateCard extends StatelessWidget {
  final DateTime date;
  final bool isSelected;
  final VoidCallback onTap;

  const _DateCard({
    required this.date,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateTime.now();
    final isToday = _isSameDay(date, today);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 70,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF00BF63)
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF00BF63)
                    : Colors.grey.withOpacity(0.2),
                width: 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFF00BF63).withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Day name
                Text(
                  isToday ? 'Today' : DateFormat('EEE').format(date),
                  style: TextStyle(
                    fontSize: 12,
                    color: isSelected
                        ? Colors.white
                        : isToday
                            ? const Color(0xFF00BF63)
                            : Colors.grey[600],
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 4),
                // Day number
                Text(
                  date.day.toString(),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                // Month
                Text(
                  DateFormat('MMM').format(date),
                  style: TextStyle(
                    fontSize: 11,
                    color: isSelected
                        ? Colors.white.withOpacity(0.9)
                        : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// Updated Booking Card based on _buildMatchCard style
class _BookingCard extends StatefulWidget { // Changed to StatefulWidget
  final Booking booking;
  final FootballField field;
  final VoidCallback onTap;

  const _BookingCard({
    required this.booking,
    required this.field,
    required this.onTap,
  });

  @override
  State<_BookingCard> createState() => _BookingCardState();
}

class _BookingCardState extends State<_BookingCard> { // New State class
  Map<String, String>? _hostInfo;

  @override
  void initState() {
    super.initState();
    _fetchHostInfo();
  }

  Future<void> _fetchHostInfo() async {
    try {
      final hostProfile = await SupabaseService().getUserProfileById(widget.booking.host);
      if (mounted) {
        if (hostProfile != null) {
          setState(() {
            _hostInfo = {
              'name': hostProfile.name,
              'profilePicture': hostProfile.profilePicture,
            };
          });
        } else if (widget.booking.host == 'admin_1') {
          setState(() {
            _hostInfo = {
               'name': 'PlayMaker Admin',
               'profilePicture': 'https://ui-avatars.com/api/?name=PlayMaker+Admin&background=00BF63&color=fff',
            };
          });
        }
      }
    } catch (e) {
      print("Error fetching host info for booking card: $e");
    }
  }

  String _formatTimeSlot(String timeSlot) {
    final times = timeSlot.split('-');
    if (times.length != 2) return timeSlot; // Handle unexpected format

    // Robustly parse start time (HH:MM)
    final startTimeParts = times[0].split(':');
    if (startTimeParts.length < 2) return timeSlot; // Handle unexpected format
    final startHour = int.tryParse(startTimeParts[0]) ?? 0;
    final startMinute = int.tryParse(startTimeParts[1]) ?? 0;
    final start = DateTime(1970, 1, 1, startHour, startMinute);

    // Robustly parse end time (HH:MM)
    final endTimeParts = times[1].split(':');
    if (endTimeParts.length < 2) return timeSlot; // Handle unexpected format
    final endHour = int.tryParse(endTimeParts[0]) ?? 0;
    final endMinute = int.tryParse(endTimeParts[1]) ?? 0;
    final end = DateTime(1970, 1, 1, endHour, endMinute);

    return '${DateFormat('h:mm a').format(start)} - ${DateFormat('h:mm a').format(end)}';
  }

  // Keep robust duration calculation
  int _calculateDuration(String timeSlot) {
    final times = timeSlot.split('-');
    if (times.length != 2) return 0; // Handle unexpected format

    // Robustly parse start time (HH:MM)
    final startTimeParts = times[0].split(':');
    if (startTimeParts.length < 2) return 0; // Handle unexpected format
    final startHour = int.tryParse(startTimeParts[0]) ?? 0;
    final startMinute = int.tryParse(startTimeParts[1]) ?? 0;
    final start = DateTime(1970, 1, 1, startHour, startMinute);

    // Robustly parse end time (HH:MM)
    final endTimeParts = times[1].split(':');
    if (endTimeParts.length < 2) return 0; // Handle unexpected format
    final endHour = int.tryParse(endTimeParts[0]) ?? 0;
    final endMinute = int.tryParse(endTimeParts[1]) ?? 0;
    final end = DateTime(1970, 1, 1, endHour, endMinute);

    return end.difference(start).inMinutes;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final brandColor = const Color(0xFF00BF63); // Use brand color for open matches
    // Use isUpcoming style since these are joinable
    final bool isUpcomingStyle = true;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: brandColor.withOpacity(0.02), // Upcoming style background
          child: InkWell(
            onTap: widget.onTap,
            splashColor: brandColor.withOpacity(0.1),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.field.footballFieldName,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: brandColor, // Upcoming style color
                          ),
                        ),
                      ),
                      // Replace "Open Match" chip with Duration chip
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.1), // Use primary color
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.timer_outlined, // Use timer icon
                              size: 14,
                              color: colorScheme.primary, // Use primary color
                            ),
                            const SizedBox(width: 4),
                            Text(
                              // Calculate and display duration
                              AppLocalizations.of(context)!.joinBookings_durationInMinutes(_calculateDuration(widget.booking.timeSlot)),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.primary, // Use primary color
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: brandColor.withOpacity(0.8),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          widget.field.locationName,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 16,
                        color: brandColor.withOpacity(0.8),
                      ),
                      const SizedBox(width: 6),
                      // Date is implicitly known from the screen, maybe show time only?
                      // Text(
                      //   _formatDate(booking.date),
                      //   style: theme.textTheme.bodyMedium?.copyWith(
                      //     fontWeight: FontWeight.w500,
                      //     color: Colors.black87,
                      //   ),
                      // ),
                      // const Text(' • ', style: TextStyle(color: Colors.grey)),
                      Icon(
                        Icons.access_time_outlined,
                        size: 16,
                        color: brandColor.withOpacity(0.8),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _formatTimeSlot(widget.booking.timeSlot),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Price per player
                  Row(
                    children: [
                      Icon(
                        Icons.payments_outlined,
                        size: 16,
                        color: brandColor.withOpacity(0.8),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade200, width: 0.5),
                        ),
                        child: Text(
                          '${widget.booking.price.toInt()} EGP / player',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Colors.amber.shade800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Host & Player Count Info
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: brandColor.withOpacity(0.2),
                        backgroundImage: _hostInfo?['profilePicture']?.isNotEmpty == true
                            ? NetworkImage(_hostInfo!['profilePicture']!)
                            : null,
                        child: _hostInfo?['profilePicture']?.isEmpty ?? true
                            ? Text(
                                (_hostInfo?['name'] ?? 'H').substring(0, 1).toUpperCase(),
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: brandColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppLocalizations.of(context)!.joinBookings_hostLabel,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.black54,
                              ),
                            ),
                            Text(
                              _hostInfo?['name'] ?? AppLocalizations.of(context)!.joinBookings_loadingHost,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: brandColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.group_outlined,
                              size: 16,
                              color: brandColor,
                            ),
                            const SizedBox(width: 6),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      '${widget.booking.invitePlayers.length}',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: brandColor,
                                      ),
                                    ),
                                    if (widget.booking.maxPlayers != null)
                                      Text(
                                        ' / ${widget.booking.maxPlayers}',
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          color: Colors.black54,
                                        ),
                                      ),
                                  ],
                                ),
                                if (widget.booking.maxPlayers != null) ... [
                                  Builder(
                                    builder: (context) {
                                      final currentPlayers = widget.booking.invitePlayers.length;
                                      final spotsLeft = widget.booking.maxPlayers! - currentPlayers;
                                      if (spotsLeft > 0) {
                                        return Text(
                                          AppLocalizations.of(context)!.joinBookings_spotsLeft(spotsLeft),
                                          style: theme.textTheme.labelSmall?.copyWith(
                                            color: Colors.orange.shade700,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        );
                                      } else {
                                        return Text(
                                          AppLocalizations.of(context)!.joinBookings_matchFull,
                                          style: theme.textTheme.labelSmall?.copyWith(
                                            color: Colors.red.shade700,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                ] else ... [
                                  Text(
                                    AppLocalizations.of(context)!.joinBookings_playersLabel,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: Colors.black54,
                                    ),
                                  ),
                                ]
                              ],
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
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Chip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceTag extends StatelessWidget {
  final dynamic price;

  const _PriceTag({required this.price});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        BookingUtils.formatPrice(price),
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class BookingUtils {
  static String formatTimeSlot(BuildContext context, String timeSlot) { // Added context
    final times = timeSlot.split('-');
    if (times.length != 2) return timeSlot; // Handle unexpected format

    // Robustly parse start time (HH:MM)
    final startTimeParts = times[0].split(':');
    if (startTimeParts.length < 2) return timeSlot; // Handle unexpected format
    final startHour = int.tryParse(startTimeParts[0]) ?? 0;
    final startMinute = int.tryParse(startTimeParts[1]) ?? 0;
    final start = DateTime(1970, 1, 1, startHour, startMinute);

    // Robustly parse end time (HH:MM)
    final endTimeParts = times[1].split(':');
    if (endTimeParts.length < 2) return timeSlot; // Handle unexpected format
    final endHour = int.tryParse(endTimeParts[0]) ?? 0;
    final endMinute = int.tryParse(endTimeParts[1]) ?? 0;
    final end = DateTime(1970, 1, 1, endHour, endMinute);

    return '${DateFormat('h:mm a', AppLocalizations.of(context)!.localeName).format(start)} - ${DateFormat('h:mm a', AppLocalizations.of(context)!.localeName).format(end)}';
  }

  static int calculateDuration(String timeSlot) {
    final times = timeSlot.split('-');
    if (times.length != 2) return 0; // Handle unexpected format

    // Robustly parse start time (HH:MM)
    final startTimeParts = times[0].split(':');
    if (startTimeParts.length < 2) return 0; // Handle unexpected format
    final startHour = int.tryParse(startTimeParts[0]) ?? 0;
    final startMinute = int.tryParse(startTimeParts[1]) ?? 0;
    final start = DateTime(1970, 1, 1, startHour, startMinute);

    // Robustly parse end time (HH:MM)
    final endTimeParts = times[1].split(':');
    if (endTimeParts.length < 2) return 0; // Handle unexpected format
    final endHour = int.tryParse(endTimeParts[0]) ?? 0;
    final endMinute = int.tryParse(endTimeParts[1]) ?? 0;
    final end = DateTime(1970, 1, 1, endHour, endMinute);

    return end.difference(start).inMinutes;
  }

  static String formatDuration(BuildContext context, int minutes) { // Added context
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (remainingMinutes == 0) {
      return AppLocalizations.of(context)!.fieldBooking_durationHours(hours);
    }
    return AppLocalizations.of(context)!.fieldBooking_durationHoursMinutes(hours, remainingMinutes.toString().padLeft(2, '0'));
  }

  static String formatPrice(dynamic price) {
    // This was already localized in field_booking_screen, can re-use if needed or keep specific.
    // For now, keeping it simple as it's a utility.
    if (price is int) return '$price EGP';
    if (price is double) return '${price.toStringAsFixed(2)} EGP';
    return '$price EGP';
  }
}

class _FilterBottomSheet extends StatefulWidget {
  final String selectedLocation;
  final ValueChanged<String> onLocationChanged;

  const _FilterBottomSheet({
    required this.selectedLocation,
    required this.onLocationChanged,
  });

  @override
  State<_FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<_FilterBottomSheet> {
  late String _location;

  List<String> _locations(BuildContext context) => [ // Made _locations a method
    AppLocalizations.of(context)!.fieldsListView_locationNewCairo,
    AppLocalizations.of(context)!.fieldsListView_locationNasrCity,
    AppLocalizations.of(context)!.fieldsListView_locationShorouk,
    AppLocalizations.of(context)!.fieldsListView_locationMaadi,
    AppLocalizations.of(context)!.fieldsListView_locationSheikhZayed,
    AppLocalizations.of(context)!.fieldsListView_locationOctober,
  ];

  @override
  void initState() {
    super.initState();
    _location = widget.selectedLocation;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 32,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withOpacity(0.1),
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
                    const Icon(
                      Icons.tune,
                      color: Color(0xFF00BF63),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AppLocalizations.of(context)!.joinBookings_filterMatchesTitle,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  AppLocalizations.of(context)!.joinBookings_locationLabel,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _locations(context).map((location) { // Call _locations with context
                    return FilterChip(
                      label: Text(location),
                      selected: _location == location,
                      onSelected: (selected) {
                        setState(() => _location = selected ? location : '');
                        widget.onLocationChanged(_location);
                      },
                      selectedColor: const Color(0xFF00BF63).withOpacity(0.1),
                      checkmarkColor: const Color(0xFF00BF63),
                      labelStyle: TextStyle(
                        color: _location == location
                            ? const Color(0xFF00BF63)
                            : theme.colorScheme.onSurface,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() => _location = '');
                          widget.onLocationChanged('');
                          Navigator.pop(context);
                        },
                        child: Text(AppLocalizations.of(context)!.joinBookings_resetButton),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: Text(AppLocalizations.of(context)!.joinBookings_applyButton),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onBookField;

  const _EmptyState({
    required this.onBookField,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF00BF63).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.sports_soccer_outlined,
                size: 40,
                color: const Color(0xFF00BF63),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              AppLocalizations.of(context)!.joinBookings_noOpenMatchesTitle,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.joinBookings_noOpenMatchesSubtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: onBookField,
                  icon: const Icon(Icons.add),
                  label: Text(AppLocalizations.of(context)!.joinBookings_bookAFieldButton),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF00BF63),
                    minimumSize: const Size(200, 48),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

extension TimeFormatting on String {
  String toAMPM() {
    final hour = int.parse(this);
    if (hour == 0) return '12 AM';
    if (hour == 12) return '12 PM';
    return hour > 12 ? '${hour - 12} PM' : '$hour AM';
  }
}
