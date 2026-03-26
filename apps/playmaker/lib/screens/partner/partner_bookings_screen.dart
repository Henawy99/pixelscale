import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:playmakerappstart/l10n/app_localizations.dart';
import 'package:playmakerappstart/models/footballfield_model.dart';
import 'package:playmakerappstart/models/booking_model.dart';
import 'package:playmakerappstart/services/partner_service.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class PartnerBookingsScreen extends StatefulWidget {
  final FootballField field;

  const PartnerBookingsScreen({Key? key, required this.field}) : super(key: key);

  @override
  State<PartnerBookingsScreen> createState() => _PartnerBookingsScreenState();
}

class _PartnerBookingsScreenState extends State<PartnerBookingsScreen> {
  final PartnerService _partnerService = PartnerService();
  final SupabaseClient _supabase = Supabase.instance.client;
  
  List<Map<String, dynamic>> _allTimeslots = [];
  List<Booking> _allBookings = [];
  Map<String, Map<String, dynamic>> _playerProfiles = {}; // Cache player profiles
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Load timeslots from field (convert map to flat list)
      _allTimeslots = _extractTimeslotsForDate(_selectedDate);
      
      // Load all bookings for this field
      final bookings = await _partnerService.getFieldBookings(widget.field.id);
      
      // Fetch player profiles for Playmaker bookings
      await _fetchPlayerProfiles(bookings);
      
      if (mounted) {
        setState(() {
          _allBookings = bookings;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Fetch all player profiles for Playmaker bookings
  Future<void> _fetchPlayerProfiles(List<Booking> bookings) async {
    // Get unique host IDs for Playmaker bookings
    final hostIds = bookings
        .where((b) => !b.fieldManagerBooking)
        .map((b) => b.host)
        .whereType<String>() // Filter out nulls
        .toSet();
    
    if (hostIds.isEmpty) return;
    
    try {
      final profiles = await _supabase
          .from('player_profiles')
          .select('id, name, phone_number')
          .inFilter('id', hostIds.toList());
      
      // Store in map for quick lookup
      _playerProfiles = {
        for (var profile in profiles)
          profile['id'] as String: profile
      };
    } catch (e) {
      print('Error fetching player profiles: $e');
    }
  }

  // Extract timeslots for the selected day
  List<Map<String, dynamic>> _extractTimeslotsForDate(DateTime date) {
    final dayName = _getDayName(date).toLowerCase();
    final dayTimeslots = widget.field.availableTimeSlots[dayName];
    
    if (dayTimeslots == null || dayTimeslots.isEmpty) {
      return [];
    }
    
    return dayTimeslots;
  }

  String _getDayName(DateTime date) {
    const days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    return days[date.weekday - 1];
  }

  // Convert numbers to Arabic numerals
  String _toArabicNumerals(String input) {
    if (Localizations.localeOf(context).languageCode != 'ar') {
      return input;
    }
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    String result = input;
    for (int i = 0; i < english.length; i++) {
      result = result.replaceAll(english[i], arabic[i]);
    }
    return result;
  }

  // Format time in 12-hour format with Arabic support
  String _formatTime(String timeRange) {
    if (!timeRange.contains('-')) return timeRange;
    
    final parts = timeRange.split('-').map((e) => e.trim()).toList();
    if (parts.length != 2) return timeRange;
    
    String formatted;
    if (Localizations.localeOf(context).languageCode == 'ar') {
      // Arabic: 12-hour format with صباحاً/مساءً
      final start = _to12HourArabic(parts[0]);
      final end = _to12HourArabic(parts[1]);
      formatted = '$start - $end';
    } else {
      // English: 12-hour format with AM/PM
      final start = _to12HourEnglish(parts[0]);
      final end = _to12HourEnglish(parts[1]);
      formatted = '$start - $end';
    }
    return formatted;
  }

  String _to12HourArabic(String time24) {
    try {
      final parts = time24.split(':');
      int hour = int.parse(parts[0]);
      final minute = parts[1];
      
      String period = hour >= 12 ? 'مساءً' : 'صباحاً';
      if (hour > 12) hour -= 12;
      if (hour == 0) hour = 12;
      
      return '${_toArabicNumerals('$hour')}:${_toArabicNumerals(minute)} $period';
    } catch (e) {
      return time24;
    }
  }

  String _to12HourEnglish(String time24) {
    try {
      final parts = time24.split(':');
      int hour = int.parse(parts[0]);
      final minute = parts[1];
      
      String period = hour >= 12 ? 'PM' : 'AM';
      if (hour > 12) hour -= 12;
      if (hour == 0) hour = 12;
      
      return '$hour:$minute $period';
    } catch (e) {
      return time24;
    }
  }

  // Format date for display
  String _formatDisplayDate(DateTime date) {
    final locale = Localizations.localeOf(context).languageCode;
    if (locale == 'ar') {
      final weekday = _getArabicWeekday(date.weekday);
      final day = _toArabicNumerals(date.day.toString());
      final month = _getArabicMonth(date.month);
      final year = _toArabicNumerals(date.year.toString());
      return '$weekday، $day $month $year';
    } else {
      return DateFormat('EEE, MMM d, yyyy').format(date);
    }
  }

  String _getArabicWeekday(int weekday) {
    const weekdays = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
    return weekdays[weekday - 1];
  }

  String _getArabicMonth(int month) {
    const months = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
    return months[month - 1];
  }

  // Get bookings for selected date
  List<Booking> _getBookingsForDate() {
    final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
    return _allBookings.where((booking) {
      if (booking.isRecurring) {
        // Check if this recurring booking applies to the selected date
        return _isRecurringBookingActiveOnDate(booking, _selectedDate);
      }
      return booking.date == formattedDate;
    }).toList();
  }

  // Check if a recurring booking is active on a given date
  bool _isRecurringBookingActiveOnDate(Booking booking, DateTime date) {
    if (!booking.isRecurring) return false;
    
    final formattedDate = DateFormat('yyyy-MM-dd').format(date);
    
    // Check if date is in exceptions list
    if (booking.recurringExceptions.contains(formattedDate)) {
      return false;
    }
    
    // Parse original date
    DateTime originalDate;
    try {
      originalDate = DateTime.parse(booking.recurringOriginalDate ?? booking.date);
    } catch (e) {
      originalDate = DateTime.parse(booking.date);
    }
    
    // Check if date is before the original booking
    if (date.isBefore(DateTime(originalDate.year, originalDate.month, originalDate.day))) {
      return false;
    }
    
    // Check end date if specified
    if (booking.recurringEndDate != null && booking.recurringEndDate!.isNotEmpty) {
      try {
        final endDate = DateTime.parse(booking.recurringEndDate!);
        if (date.isAfter(endDate)) {
          return false;
        }
      } catch (e) {
        print('Error parsing end date: $e');
      }
    }
    
    // Check recurrence pattern
    if (booking.recurringType == 'daily') {
      return true;
    } else if (booking.recurringType == 'weekly') {
      return date.weekday == originalDate.weekday;
    }
    
    return false;
  }

  // Find booking for a specific timeslot
  Booking? _findBookingForTimeslot(String timeSlot) {
    final bookingsForDate = _getBookingsForDate();
    try {
      return bookingsForDate.firstWhere((booking) => booking.timeSlot == timeSlot);
    } catch (e) {
      return null;
    }
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      setState(() {
        _selectedDate = date;
        _allTimeslots = _extractTimeslotsForDate(date);
      });
    }
  }

  Future<void> _createPartnerBooking(String timeSlot, int price) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _CreateBookingDialog(
        timeSlot: timeSlot,
        price: price,
        date: _selectedDate,
      ),
    );

    if (result != null) {
      try {
        // Show loading
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator()),
        );

        final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
        
        // Generate unique booking reference
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final bookingReference = 'PARTNER_${widget.field.id}_$timestamp';

        // Create booking (using snake_case for database columns)
        // Note: Partner bookings don't link to player_profiles, so:
        // - user_id is NOT set (NULL)
        // - host is NOT set (NULL) 
        // Customer info is stored in user_name and user_email instead
        final bookingData = {
          'football_field_id': widget.field.id,
          'date': formattedDate,
          'time_slot': timeSlot,
          'price': price,
          'payment_type': 'Partner Booking',
          'booking_reference': bookingReference,
          'invite_players': [],
          'invite_squads': [],
          'is_open_match': false,
          'football_field_name': widget.field.footballFieldName,
          // No 'host' field - it references player_profiles which doesn't apply here
          'location_name': widget.field.locationName,
          'status': 'confirmed',
          'open_joining_requests': [],
          'is_recording_enabled': result['recordGame'] ?? false,
          'field_manager_booking': true, // This flag identifies partner bookings
          'is_recurring': result['isRecurring'] ?? false,
          'recurring_type': result['recurringType'],
          'recurring_original_date': formattedDate,
          'recurring_end_date': result['recurringEndDate'],
          'recurring_exceptions': [],
          'user_name': result['name'], // Customer name stored here
          'user_email': result['phone'], // Customer phone stored here
          'notes': result['notes'],
        };

        final response = await _supabase.from('bookings').insert(bookingData).select('id').single();
        final bookingId = response['id'] as String;

        // If recording requested, create a camera recording schedule
        if (result['recordGame'] == true) {
          try {
            final times = timeSlot.split('-');
            if (times.length == 2) {
              final startTimeStr = times[0].trim();
              final endTimeStr = times[1].trim();
              
              final startParts = startTimeStr.split(':');
              final endParts = endTimeStr.split(':');
              
              if (startParts.length == 2 && endParts.length == 2) {
                final startHour = int.parse(startParts[0]);
                final startMin = int.parse(startParts[1]);
                final endHour = int.parse(endParts[0]);
                final endMin = int.parse(endParts[1]);
                
                final startTime = DateTime(
                  _selectedDate.year,
                  _selectedDate.month,
                  _selectedDate.day,
                  startHour,
                  startMin,
                );
                
                var endTime = DateTime(
                  _selectedDate.year,
                  _selectedDate.month,
                  _selectedDate.day,
                  endHour,
                  endMin,
                );
                
                // If end time is before start time, it probably spans past midnight
                if (endTime.isBefore(startTime)) {
                  endTime = endTime.add(const Duration(days: 1));
                }

                // Add buffer
                final actualStartTime = startTime.subtract(const Duration(minutes: 5));
                final actualEndTime = endTime.add(const Duration(minutes: 5));

                await _supabase.from('camera_recording_schedules').insert({
                  'field_id': widget.field.id,
                  'booking_id': bookingId,
                  'scheduled_date': formattedDate,
                  'start_time': actualStartTime.toUtc().toIso8601String(),
                  'end_time': actualEndTime.toUtc().toIso8601String(),
                  'status': 'scheduled',
                  'enable_ball_tracking': true,
                  'total_chunks': (actualEndTime.difference(actualStartTime).inMinutes / 10).ceil().clamp(1, 100),
                  'chunk_duration_minutes': 10,
                });
              }
            }
          } catch (e) {
            print('⚠️ Error creating recording schedule: $e');
          }
        }

        if (mounted) {
          Navigator.pop(context); // Close loading dialog
          await _loadData(); // Reload data
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result['isRecurring'] == true 
                    ? 'Recurring booking created successfully!' 
                    : 'Booking created successfully!',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error creating booking: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: Column(
                children: [
                  // Date Selector
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.white,
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _selectedDate = _selectedDate.subtract(const Duration(days: 1));
                              _allTimeslots = _extractTimeslotsForDate(_selectedDate);
                            });
                          },
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: _selectDate,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.calendar_today, size: 20, color: Colors.blue.shade700),
                                  const SizedBox(width: 8),
                                  Text(
                                    _formatDisplayDate(_selectedDate),
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _selectedDate = _selectedDate.add(const Duration(days: 1));
                              _allTimeslots = _extractTimeslotsForDate(_selectedDate);
                            });
                          },
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                  ),

                  // Timeslots List
                  Expanded(
                    child: _allTimeslots.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.access_time_outlined, size: 64, color: Colors.grey.shade300),
                                const SizedBox(height: 16),
                                Text(
                                  'No timeslots configured',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _allTimeslots.length,
                            itemBuilder: (context, index) {
                              final timeslot = _allTimeslots[index];
                              final timeString = timeslot['time'] as String? ?? '';
                              final price = int.tryParse(timeslot['price']?.toString() ?? '0') ?? 0;
                              final booking = _findBookingForTimeslot(timeString);
                              final isBooked = booking != null;
                              
                              // Get player profile data if this is a Playmaker booking
                              Map<String, dynamic>? playerProfile;
                              if (booking != null && !booking.fieldManagerBooking) {
                                playerProfile = _playerProfiles[booking.host];
                              }

                              return _TimeslotCard(
                                timeslot: timeslot,
                                booking: booking,
                                isBooked: isBooked,
                                formattedTime: _formatTime(timeString),
                                formattedPrice: _toArabicNumerals(price.toString()),
                                playerProfile: playerProfile, // Pass player data
                                onTap: () {
                                  if (!isBooked) {
                                    // Create partner booking
                                    _createPartnerBooking(timeString, price);
                                  } else {
                                    // Show booking details
                                    _showBookingDetails(booking);
                                  }
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not launch phone dialer for $phoneNumber'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showBookingDetails(Booking booking) async {
    final l10n = AppLocalizations.of(context)!;
    
    // Fetch player profile data for Playmaker bookings
    String? playerName;
    String? playerPhone;
    
    if (!booking.fieldManagerBooking) {
      try {
        final profile = await _supabase
            .from('player_profiles')
            .select('name, phone_number')
            .eq('id', booking.host)
            .maybeSingle();
        
        if (profile != null) {
          playerName = profile['name'] as String?;
          playerPhone = profile['phone_number'] as String?;
        }
      } catch (e) {
        print('Error fetching player profile: $e');
      }
    }
    
    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(24),
          child: ListView(
            controller: scrollController,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: booking.status == 'rejected'
                          ? Colors.red.shade100
                          : booking.fieldManagerBooking 
                              ? Colors.blue.shade100
                              : Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      booking.status == 'rejected'
                          ? Icons.cancel
                          : booking.fieldManagerBooking 
                              ? Icons.person 
                              : Icons.sports_soccer,
                      color: booking.status == 'rejected'
                          ? Colors.red.shade700
                          : booking.fieldManagerBooking 
                              ? Colors.blue.shade700
                              : Colors.green.shade700,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          booking.status == 'rejected'
                              ? 'Rejected Booking'
                              : booking.fieldManagerBooking 
                                  ? l10n.partner_bookings_partnerBooking
                                  : l10n.partner_bookings_userBooking,
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          _formatTime(booking.timeSlot),
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              // Status badge
              if (booking.status == 'rejected') ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.red.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'This booking was rejected',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.red.shade700,
                              ),
                            ),
                            if (booking.rejectionReason != null && booking.rejectionReason!.isNotEmpty)
                              Text(
                                'Reason: ${booking.rejectionReason}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.red.shade600,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              const Divider(height: 32),
              _DetailRow(
                icon: Icons.person, 
                label: l10n.partner_bookingDetails_host, 
                value: playerName ?? booking.userName ?? booking.host
              ),
              if ((playerPhone != null && playerPhone.isNotEmpty) || 
                  (booking.userEmail != null && booking.userEmail!.isNotEmpty))
                _PhoneDetailRow(
                  icon: Icons.phone, 
                  label: l10n.partner_bookingDetails_phone, 
                  value: playerPhone ?? booking.userEmail ?? 'N/A',
                  onCall: () => _makePhoneCall(playerPhone ?? booking.userEmail!),
                ),
              _DetailRow(
                icon: Icons.attach_money,
                label: l10n.partner_bookingDetails_price,
                value: '${l10n.partner_bookings_price} ${_toArabicNumerals(booking.price.toString())}',
              ),
              if (booking.isRecurring) ...[
                _DetailRow(
                  icon: Icons.repeat,
                  label: l10n.partner_bookingDetails_recurring,
                  value: booking.recurringType?.toUpperCase() ?? 'N/A',
                ),
              ],
              if (booking.notes != null && booking.notes!.isNotEmpty)
                _DetailRow(icon: Icons.notes, label: l10n.partner_bookingDetails_notes, value: booking.notes ?? ''),
              
              // Action buttons for USER bookings (not partner bookings, not already rejected)
              if (!booking.fieldManagerBooking && booking.status != 'rejected') ...[
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                Text(
                  'Actions',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                
                // Reject Booking Button
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _showRejectBookingDialog(booking, playerName);
                  },
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Reject Booking'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Block User Button
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _showBlockUserDialog(booking.host, playerName ?? booking.userName ?? 'User');
                  },
                  icon: const Icon(Icons.block),
                  label: const Text('Block User'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange.shade700,
                    side: BorderSide(color: Colors.orange.shade700),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Show reject booking dialog
  void _showRejectBookingDialog(Booking booking, String? playerName) {
    final reasonController = TextEditingController();
    bool blockUser = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.cancel, color: Colors.red.shade700),
              ),
              const SizedBox(width: 12),
              const Text('Reject Booking'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        playerName ?? booking.userName ?? 'User',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${booking.date} • ${_formatTime(booking.timeSlot)}',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Reason for rejection (optional):',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: reasonController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'e.g., Field maintenance, Double booking...',
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: CheckboxListTile(
                    title: Text(
                      'Also block this user',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      'Prevent them from booking again',
                      style: GoogleFonts.inter(fontSize: 12),
                    ),
                    value: blockUser,
                    onChanged: (value) {
                      setDialogState(() => blockUser = value ?? false);
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.red.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'The user will be notified that their booking was rejected.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ),
                    ],
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
              onPressed: () async {
                Navigator.pop(context);
                await _rejectBooking(
                  booking,
                  reasonController.text.trim(),
                  blockUser,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
              ),
              child: const Text('Reject Booking'),
            ),
          ],
        ),
      ),
    );
  }

  /// Show block user dialog
  void _showBlockUserDialog(String userId, String userName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.block, color: Colors.orange.shade700),
            ),
            const SizedBox(width: 12),
            const Text('Block User'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to block "$userName"?',
              style: GoogleFonts.inter(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This user will not be able to book at your field anymore. You can unblock them later from the Blocked Users list.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
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
            onPressed: () async {
              Navigator.pop(context);
              await _blockUser(userId, userName);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Block User'),
          ),
        ],
      ),
    );
  }

  /// Reject a booking
  Future<void> _rejectBooking(Booking booking, String reason, bool alsoBlockUser) async {
    // Store booking host before deletion for blocking
    final bookingHost = booking.host;
    
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Send rejection notification BEFORE deleting (so we have the booking data)
      await _sendRejectionNotification(booking, reason);
      
      final results = await _partnerService.rejectBookingAndBlockUser(
        bookingId: booking.id,
        fieldId: widget.field.id,
        userId: bookingHost,
        rejectionReason: reason.isNotEmpty ? reason : null,
        blockUser: alsoBlockUser,
      );

      if (mounted) {
        Navigator.pop(context); // Close loading
        
        String message = 'Booking rejected! Timeslot is now available.';
        if (alsoBlockUser && results['blocked'] == true) {
          message += ' User has been blocked.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
          ),
        );
        
        // Reload data to show freed timeslot
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error rejecting booking: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Block a user
  Future<void> _blockUser(String userId, String userName) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final success = await _partnerService.blockUser(
        fieldId: widget.field.id,
        userId: userId,
        userName: userName,
      );

      if (mounted) {
        Navigator.pop(context); // Close loading
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success 
                ? '$userName has been blocked from booking.'
                : 'Failed to block user.'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error blocking user: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Send rejection notification to user
  Future<void> _sendRejectionNotification(Booking booking, [String? reason]) async {
    try {
      // Get user's FCM token
      final userProfile = await _supabase
          .from('player_profiles')
          .select('fcm_token')
          .eq('id', booking.host)
          .maybeSingle();
      
      if (userProfile == null || userProfile['fcm_token'] == null) {
        print('⚠️ No FCM token found for user ${booking.host}');
        return;
      }

      // Send notification via Edge Function
      await _supabase.functions.invoke(
        'send-booking-rejection-notification',
        body: {
          'fcm_token': userProfile['fcm_token'],
          'field_name': widget.field.footballFieldName,
          'date': booking.date,
          'time_slot': booking.timeSlot,
          'reason': reason,
        },
      );
      
      print('✅ Rejection notification sent to user ${booking.host}');
    } catch (e) {
      print('❌ Error sending rejection notification: $e');
    }
  }
}

class _TimeslotCard extends StatelessWidget {
  final Map<String, dynamic> timeslot;
  final Booking? booking;
  final bool isBooked;
  final String formattedTime;
  final String formattedPrice;
  final Map<String, dynamic>? playerProfile; // Player profile data
  final VoidCallback onTap;

  const _TimeslotCard({
    required this.timeslot,
    required this.booking,
    required this.isBooked,
    required this.formattedTime,
    required this.formattedPrice,
    this.playerProfile, // Optional player data
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isPartnerBooking = booking?.fieldManagerBooking ?? false;
    final isUserBooking = isBooked && !isPartnerBooking;
    
    // Get display name and phone
    String? displayName;
    String? displayPhone;
    
    if (isBooked) {
      if (isUserBooking && playerProfile != null) {
        // Playmaker booking - use player profile data
        displayName = playerProfile!['name'] as String?;
        displayPhone = playerProfile!['phone_number'] as String?;
      } else {
        // Partner booking - use booking data
        displayName = booking?.userName;
        displayPhone = booking?.userEmail;
      }
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8), // ✅ Reduced from 12
        padding: const EdgeInsets.all(12), // ✅ Reduced from 16
        decoration: BoxDecoration(
          color: isUserBooking 
              ? Colors.green.shade50 
              : isPartnerBooking 
                  ? Colors.blue.shade50
                  : Colors.white,
          borderRadius: BorderRadius.circular(10), // ✅ Reduced from 12
          border: Border.all(
            color: isUserBooking 
                ? Colors.green.shade200 
                : isPartnerBooking 
                    ? Colors.blue.shade200
                    : Colors.grey.shade200,
            width: 1.5, // ✅ Reduced from 2
          ),
        ),
        child: Row(
          children: [
            // Time & Price Column
            SizedBox(
              width: 100, // ✅ Reduced from 120
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formattedTime,
                    style: GoogleFonts.inter(
                      fontSize: 13, // ✅ Reduced from 15
                      fontWeight: FontWeight.w700,
                      color: isBooked ? Colors.black87 : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$formattedPrice ${l10n.partner_bookings_price}',
                    style: GoogleFonts.inter(
                      fontSize: 12, // ✅ Reduced from 14
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(width: 12), // ✅ Reduced from 16
            
            // Status Indicator
            Container(
              width: 3, // ✅ Reduced from 4
              height: 40, // ✅ Reduced from 50
              decoration: BoxDecoration(
                color: isUserBooking 
                    ? Colors.green.shade400 
                    : isPartnerBooking 
                        ? Colors.blue.shade400
                        : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            const SizedBox(width: 12), // ✅ Reduced from 16
            
            // Booking Info or Available
            Expanded(
              child: isBooked
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Name
                        Row(
                          children: [
                            Icon(
                              isPartnerBooking 
                                  ? Icons.person_outline 
                                  : Icons.sports_soccer,
                              size: 14, // ✅ Reduced from 16
                              color: isPartnerBooking 
                                  ? Colors.blue.shade700
                                  : Colors.green.shade700,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                displayName ?? booking?.host ?? 'N/A', // ✅ Show player name
                                style: GoogleFonts.inter(
                                  fontSize: 14, // ✅ Reduced from 16
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        // Phone Number
                        if (displayPhone != null && displayPhone.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.phone, size: 12, color: Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  displayPhone, // ✅ Show player phone
                                  style: GoogleFonts.inter(
                                    fontSize: 12, // ✅ Reduced from 14
                                    color: Colors.grey.shade600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                        // Recurring indicator
                        if (booking?.isRecurring ?? false) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.repeat, size: 10, color: Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Text(
                                booking?.recurringType?.toUpperCase() ?? '',
                                style: GoogleFonts.inter(
                                  fontSize: 10, // ✅ Reduced from 12
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    )
                  : Row(
                      children: [
                        Icon(Icons.add_circle_outline, color: Colors.blue.shade600, size: 18), // ✅ Reduced from 20
                        const SizedBox(width: 6), // ✅ Reduced from 8
                        Text(
                          l10n.partner_bookings_available,
                          style: GoogleFonts.inter(
                            fontSize: 13, // ✅ Reduced from 14
                            color: Colors.blue.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
            ),
            
            // Arrow
            Icon(
              Icons.chevron_right,
              color: isBooked ? Colors.grey.shade700 : Colors.blue.shade600,
              size: 20, // ✅ Reduced
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhoneDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onCall;

  const _PhoneDetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        value,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onCall,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.phone,
                                size: 18,
                                color: Colors.green.shade700,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Call',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
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

class _CreateBookingDialog extends StatefulWidget {
  final String timeSlot;
  final int price;
  final DateTime date;

  const _CreateBookingDialog({
    required this.timeSlot,
    required this.price,
    required this.date,
  });

  @override
  State<_CreateBookingDialog> createState() => _CreateBookingDialogState();
}

class _CreateBookingDialogState extends State<_CreateBookingDialog> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isRecurring = false;
  String _recurringType = 'weekly';
  DateTime? _endDate;
  bool _recordGame = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _toArabicNumerals(String input) {
    if (Localizations.localeOf(context).languageCode != 'ar') {
      return input;
    }
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    String result = input;
    for (int i = 0; i < english.length; i++) {
      result = result.replaceAll(english[i], arabic[i]);
    }
    return result;
  }

  String _formatTime(String timeRange) {
    if (!timeRange.contains('-')) return timeRange;
    
    final parts = timeRange.split('-').map((e) => e.trim()).toList();
    if (parts.length != 2) return timeRange;
    
    String formatted;
    if (Localizations.localeOf(context).languageCode == 'ar') {
      final start = _to12HourArabic(parts[0]);
      final end = _to12HourArabic(parts[1]);
      formatted = '$start - $end';
    } else {
      final start = _to12HourEnglish(parts[0]);
      final end = _to12HourEnglish(parts[1]);
      formatted = '$start - $end';
    }
    return formatted;
  }

  String _to12HourArabic(String time24) {
    try {
      final parts = time24.split(':');
      int hour = int.parse(parts[0]);
      final minute = parts[1];
      
      String period = hour >= 12 ? 'مساءً' : 'صباحاً';
      if (hour > 12) hour -= 12;
      if (hour == 0) hour = 12;
      
      return '${_toArabicNumerals('$hour')}:${_toArabicNumerals(minute)} $period';
    } catch (e) {
      return time24;
    }
  }

  String _to12HourEnglish(String time24) {
    try {
      final parts = time24.split(':');
      int hour = int.parse(parts[0]);
      final minute = parts[1];
      
      String period = hour >= 12 ? 'PM' : 'AM';
      if (hour > 12) hour -= 12;
      if (hour == 0) hour = 12;
      
      return '$hour:$minute $period';
    } catch (e) {
      return time24;
    }
  }

  String _formatDisplayDate(DateTime date) {
    final locale = Localizations.localeOf(context).languageCode;
    if (locale == 'ar') {
      final day = _toArabicNumerals(date.day.toString());
      final month = _getArabicMonth(date.month);
      final year = _toArabicNumerals(date.year.toString());
      return '$day $month $year';
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }

  String _getArabicMonth(int month) {
    const months = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.add_circle, color: Colors.blue.shade700),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.partner_createBooking_title,
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${_formatTime(widget.timeSlot)} • ${l10n.partner_bookings_price} ${_toArabicNumerals(widget.price.toString())}',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),

              // Name
              Text(
                l10n.partner_createBooking_customerName,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: l10n.partner_createBooking_customerNameHint,
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Phone
              Text(
                l10n.partner_createBooking_phoneNumber,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: '${l10n.partner_createBooking_phoneNumberHint} (Optional)',
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Record Game Option
              Row(
                children: [
                   Checkbox(
                    value: _recordGame,
                    onChanged: (value) => setState(() => _recordGame = value ?? false),
                    activeColor: Colors.blue.shade600,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Record game',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Automatically start AI camera recording',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Notes
              Text(
                l10n.partner_createBooking_notes,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: l10n.partner_createBooking_notesHint,
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 16),

              // Recurring Option
              Row(
                children: [
                  Checkbox(
                    value: _isRecurring,
                    onChanged: (value) => setState(() => _isRecurring = value ?? false),
                  ),
                  Expanded(
                    child: Text(
                      l10n.partner_createBooking_makeRecurring,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              if (_isRecurring) ...[
                const SizedBox(height: 16),
                
                // Recurring Type
                Text(
                  l10n.partner_createBooking_repeat,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _RecurringOption(
                        label: l10n.partner_createBooking_daily,
                        isSelected: _recurringType == 'daily',
                        onTap: () => setState(() => _recurringType = 'daily'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _RecurringOption(
                        label: l10n.partner_createBooking_weekly,
                        isSelected: _recurringType == 'weekly',
                        onTap: () => setState(() => _recurringType = 'weekly'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // End Date
                Text(
                  l10n.partner_createBooking_endDate,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: widget.date.add(const Duration(days: 30)),
                      firstDate: widget.date,
                      lastDate: widget.date.add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      setState(() => _endDate = date);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, size: 18, color: Colors.grey.shade600),
                        const SizedBox(width: 12),
                        Text(
                          _endDate != null 
                              ? _formatDisplayDate(_endDate!)
                              : l10n.partner_createBooking_selectEndDate,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: _endDate != null ? Colors.black87 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        l10n.partner_cancel,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_nameController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.partner_createBooking_fillRequired),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        Navigator.pop(context, {
                          'name': _nameController.text,
                          'phone': _phoneController.text,
                          'notes': _notesController.text,
                          'isRecurring': _isRecurring,
                          'recurringType': _isRecurring ? _recurringType : null,
                          'recurringEndDate': _isRecurring && _endDate != null 
                              ? DateFormat('yyyy-MM-dd').format(_endDate!)
                              : null,
                          'recordGame': _recordGame,
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        l10n.partner_createBooking_create,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecurringOption extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _RecurringOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade600 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }
}
