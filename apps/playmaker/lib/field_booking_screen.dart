import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:playmakerappstart/l10n/app_localizations.dart';
import 'package:playmakerappstart/models/footballfield_model.dart';
import 'package:playmakerappstart/models/user_model.dart';
import 'package:playmakerappstart/models/booking_model.dart';
import 'package:playmakerappstart/booking_details_screen.dart';
import 'package:playmakerappstart/match_details_screen.dart';
import 'package:playmakerappstart/services/supabase_service.dart';
import 'package:url_launcher/url_launcher.dart';

class FieldBookingScreen extends StatefulWidget {
  final FootballField field;
  final PlayerProfile playerProfile;
  final DateTime? selectedDate;

  const FieldBookingScreen({
    super.key,
    required this.field,
    required this.playerProfile,
    this.selectedDate,
  });

  @override
  State<FieldBookingScreen> createState() => _FieldBookingScreenState();
}

class _FieldBookingScreenState extends State<FieldBookingScreen> with SingleTickerProviderStateMixin {
  late DateTime _selectedDate;
  Map<String, dynamic>? _selectedTimeSlot;
  List<Map<String, dynamic>> _timeSlots = [];
  List<Booking> _bookedSlots = [];
  bool _isLoading = true;
  late AnimationController _animationController;
  final SupabaseService _supabaseService = SupabaseService();

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.selectedDate ?? DateTime.now();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _fetchData();
        // Track field view for analytics (non-blocking)
        _trackFieldView();
      }
    });
  }

  /// Track field view for admin analytics
  void _trackFieldView() {
    _supabaseService.trackFieldClick(
      fieldId: widget.field.id,
      userId: widget.playerProfile.id,
      source: 'field_booking',
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;

    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _fetchTimeSlots(),
        _fetchBookings(),
      ]);
    } catch (e) {
      print('Error occurred during _fetchData\'s Future.wait: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchTimeSlots() async {
    final dayOfWeek = DateFormat('EEEE', 'en').format(_selectedDate).toLowerCase();
    final newTimeSlots = widget.field.availableTimeSlots[dayOfWeek] ?? [];
    if (mounted) {
      setState(() {
        _timeSlots = newTimeSlots;
      });
    }
  }

  bool _isBookingActiveOnDate(Booking masterBooking, DateTime targetDate) {
    if (!masterBooking.isRecurring || masterBooking.recurringOriginalDate == null) {
      return false;
    }

    DateTime originalStartDate;
    try {
      originalStartDate = DateFormat('yyyy-MM-dd', AppLocalizations.of(context)!.localeName).parse(masterBooking.recurringOriginalDate!);
    } catch (e) {
      return false;
    }

    final normalizedTargetDate = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final normalizedOriginalStartDate = DateTime(originalStartDate.year, originalStartDate.month, originalStartDate.day);

    if (normalizedTargetDate.isBefore(normalizedOriginalStartDate)) {
      return false;
    }

    if (masterBooking.recurringEndDate != null && masterBooking.recurringEndDate!.isNotEmpty) {
      try {
        final recurringEndDateValue = DateFormat('yyyy-MM-dd', AppLocalizations.of(context)!.localeName).parse(masterBooking.recurringEndDate!);
        final normalizedRecurringEndDate = DateTime(recurringEndDateValue.year, recurringEndDateValue.month, recurringEndDateValue.day);
        if (normalizedTargetDate.isAfter(normalizedRecurringEndDate)) {
          return false;
        }
      } catch (e) {
        return false;
      }
    }

    final formattedTargetDateString = DateFormat('yyyy-MM-dd', AppLocalizations.of(context)!.localeName).format(normalizedTargetDate);
    if (masterBooking.recurringExceptions.contains(formattedTargetDateString)) {
      return false;
    }

    if (masterBooking.recurringType == 'daily') {
      return true;
    }

    if (masterBooking.recurringType == 'weekly') {
      return normalizedTargetDate.weekday == normalizedOriginalStartDate.weekday;
    }

    return false;
  }

  Future<void> _fetchBookings() async {
    final formattedSelectedDate = DateFormat('yyyy-MM-dd', AppLocalizations.of(context)!.localeName).format(_selectedDate);
    
    try {
      final allBookings = await _supabaseService.getAllBookings();
      
      // Filter for this field AND exclude cancelled/rejected bookings
      final fieldBookings = allBookings.where((booking) => 
        booking.footballFieldId == widget.field.id &&
        booking.status.toLowerCase() != 'cancelled' &&
        booking.status.toLowerCase() != 'rejected'
      ).toList();

      final List<Booking> newBookedSlots = [];
      for (var booking in fieldBookings) {
        if (booking.isRecurring) {
          if (_isBookingActiveOnDate(booking, _selectedDate)) {
            newBookedSlots.add(booking.copyWith(date: formattedSelectedDate));
          }
        } else {
          if (booking.date == formattedSelectedDate) {
            newBookedSlots.add(booking);
          }
        }
      }
      
      if (mounted) {
        setState(() {
          _bookedSlots = newBookedSlots;
        });
      }
    } catch (e) {
      print('Error fetching bookings: $e');
      if (mounted) {
        setState(() {
          _bookedSlots = [];
        });
      }
    }
  }
  
  Booking? _getBookingForSlot(String timeSlotValue) {
    for (final booking in _bookedSlots) {
      if (booking.timeSlot == timeSlotValue) {
        return booking;
      }
    }
    return null;
  }

  Future<void> _navigateToMatchDetails(Booking booking) async {
    // Navigate to match details screen where user can see the match and request to join
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MatchDetailsScreen(
          booking: booking,
          currentUserId: widget.playerProfile.id,
          footballField: widget.field,
        ),
      ),
    );
  }

  Future<void> _navigateToBookingDetails() async {
    if (_selectedTimeSlot == null) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookingDetailsScreen(
          playerProfile: widget.playerProfile,
          field: widget.field,
          selectedDate: _selectedDate,
          selectedTimeSlot: _selectedTimeSlot!,
        ),
      ),
    );

    if (result == 'booking_success' && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.fieldBooking_bookingCreatedSuccessfully)),
      );
    }
  }

  bool _isSameDate(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          color: Colors.black87, 
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Info Section (Moved below image)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.field.footballFieldName,
                              style: GoogleFonts.inter(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    widget.field.locationName,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Directions Button
                      Material(
                        color: const Color(0xFF00BF63).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: () {
                            final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${widget.field.latitude},${widget.field.longitude}');
                            launchUrl(url);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            child: const Icon(Icons.directions, color: Color(0xFF00BF63)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Amenities / Chips Row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _ModernInfoChip(
                          icon: Icons.sports_soccer, 
                          label: widget.field.fieldSize,
                        ),
                        const SizedBox(width: 12),
                        _ModernInfoChip(
                          icon: Icons.payments_outlined, 
                          label: AppLocalizations.of(context)!.fieldBooking_priceRangeEGP(widget.field.priceRange),
                        ),
                        if (widget.field.hasCamera) ...[
                          const SizedBox(width: 12),
                          _ModernInfoChip(
                            icon: Icons.videocam_outlined, 
                            label: 'Camera',
                            isHighlighted: true,
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                  
                  // Date Selection
                  Text(
                    AppLocalizations.of(context)!.fieldBooking_selectDate,
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 85,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: 14,
                      itemBuilder: (context, index) {
                        final date = DateTime.now().add(Duration(days: index));
                        return _ModernDateCard(
                          date: date,
                          isSelected: _isSameDate(date, _selectedDate),
                          locale: AppLocalizations.of(context)!.localeName,
                          onTap: () {
                            setState(() {
                              _selectedDate = date;
                              _selectedTimeSlot = null;
                            });
                            _fetchData();
                          },
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 32),
                  
                  // Time Slots Header
                  Text(
                    AppLocalizations.of(context)!.fieldBooking_availableTimeSlots,
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ),

          // Time Slots List (Changed from Grid to List)
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: Color(0xFF00BF63))),
            )
          else if (_timeSlots.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.event_busy, size: 48, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text(
                      AppLocalizations.of(context)!.fieldBooking_noTimeSlotsAvailable,
                      style: GoogleFonts.inter(fontSize: 16, color: Colors.grey[500], fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final timeSlot = _timeSlots[index];
                    final isSelected = _selectedTimeSlot == timeSlot;
                    final bookingForSlot = _getBookingForSlot(timeSlot['time'] as String);
                    final isBooked = bookingForSlot != null;
                    bool isPast = false;
                    final now = DateTime.now();
                    if (_isSameDate(_selectedDate, now)) {
                      try {
                        final timeSlotString = timeSlot['time'] as String;
                        final startTimeString = timeSlotString.split('-')[0];
                        final hour = int.parse(startTimeString.split(':')[0]);
                        final minute = int.parse(startTimeString.split(':')[1]);
                        final timeSlotStartDateTime = DateTime(
                          _selectedDate.year,
                          _selectedDate.month,
                          _selectedDate.day,
                          hour,
                          minute,
                        );
                        if (timeSlotStartDateTime.isBefore(now)) isPast = true;
                      } catch (_) {}
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ModernTimeSlotCard(
                        timeSlot: timeSlot,
                        isSelected: isSelected,
                        isBooked: isBooked,
                        isPast: isPast,
                        booking: bookingForSlot,
                        locale: AppLocalizations.of(context)!.localeName,
                        onTap: () => setState(() => _selectedTimeSlot = timeSlot),
                        onBookedTap: bookingForSlot != null 
                            ? () => _navigateToMatchDetails(bookingForSlot) 
                            : null,
                      ),
                    );
                  },
                  childCount: _timeSlots.length,
                ),
              ),
            ),
        ],
      ),
      
      bottomNavigationBar: _selectedTimeSlot == null 
        ? null 
        : SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
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
                  'Price',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
                ),
                Text(
                  AppLocalizations.of(context)!.fieldBooking_priceEGP(_selectedTimeSlot!['price']),
                  style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: const Color(0xFF00BF63)),
                ),
              ],
            ),
            const SizedBox(width: 20),
            Expanded(
              child: ElevatedButton(
                onPressed: _navigateToBookingDetails,
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
                  AppLocalizations.of(context)!.fieldBooking_continueToBooking,
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
}

// ... (Helper classes remain mostly the same, but _ModernTimeSlotCard needs update)

class _ModernInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isHighlighted;

  const _ModernInfoChip({
    required this.icon, 
    required this.label,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isHighlighted ? const Color(0xFF00BF63).withOpacity(0.15) : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isHighlighted ? const Color(0xFF00BF63) : Colors.grey[200]!,
          width: isHighlighted ? 1.5 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon, 
            size: 16, 
            color: isHighlighted ? const Color(0xFF00BF63) : Colors.grey[700],
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isHighlighted ? const Color(0xFF00BF63) : Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModernDateCard extends StatelessWidget {
  final DateTime date;
  final bool isSelected;
  final VoidCallback onTap;
  final String locale;

  const _ModernDateCard({
    required this.date,
    required this.isSelected,
    required this.onTap,
    required this.locale,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 65,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF00BF63) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? const Color(0xFF00BF63) : Colors.grey[200]!,
                width: 1,
              ),
              boxShadow: isSelected 
                  ? [BoxShadow(color: const Color(0xFF00BF63).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]
                  : [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  DateFormat('EEE', locale).format(date).toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white.withOpacity(0.9) : Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('d', locale).format(date),
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModernTimeSlotCard extends StatefulWidget {
  final Map<String, dynamic> timeSlot;
  final bool isSelected;
  final bool isBooked;
  final bool isPast;
  final Booking? booking;
  final String locale;
  final VoidCallback? onTap;
  final VoidCallback? onBookedTap;

  const _ModernTimeSlotCard({
    required this.timeSlot,
    required this.isSelected,
    required this.isBooked,
    required this.isPast,
    required this.locale,
    this.booking,
    this.onTap,
    this.onBookedTap,
  });

  @override
  State<_ModernTimeSlotCard> createState() => _ModernTimeSlotCardState();
}

class _ModernTimeSlotCardState extends State<_ModernTimeSlotCard> {
  String? _hostName;
  bool _isLoadingHost = false;

  @override
  void initState() {
    super.initState();
    if (widget.booking != null) {
      _fetchHostName();
    }
  }

  @override
  void didUpdateWidget(_ModernTimeSlotCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.booking != oldWidget.booking && widget.booking != null) {
      _fetchHostName();
    }
  }

  Future<void> _fetchHostName() async {
    if (widget.booking == null) return;
    
    setState(() => _isLoadingHost = true);
    try {
      final hostProfile = await SupabaseService().getUserProfileById(widget.booking!.host);
      if (mounted && hostProfile != null) {
        setState(() {
          _hostName = hostProfile.name;
          _isLoadingHost = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingHost = false);
      }
    }
  }

  String _formatTime(String timeStr) {
    try {
      final parts = timeStr.split(':');
      final dt = DateTime(2022, 1, 1, int.parse(parts[0]), int.parse(parts[1]));
      return DateFormat('h:mm a', widget.locale).format(dt);
    } catch (e) {
      return timeStr;
    }
  }

  String _calculateDuration(String timeSlotStr) {
    try {
      final times = timeSlotStr.split('-');
      if (times.length != 2) return '';
      
      final startTimeParts = times[0].split(':');
      final endTimeParts = times[1].split(':');
      
      final startHour = int.parse(startTimeParts[0]);
      final startMinute = int.parse(startTimeParts[1]);
      final endHour = int.parse(endTimeParts[0]);
      final endMinute = int.parse(endTimeParts[1]);
      
      final start = DateTime(2022, 1, 1, startHour, startMinute);
      final end = DateTime(2022, 1, 1, endHour, endMinute);
      
      final duration = end.difference(start);
      if (duration.inHours > 0) {
        return '${duration.inHours}h ${duration.inMinutes % 60 > 0 ? "${duration.inMinutes % 60}m" : ""}';
      } else {
        return '${duration.inMinutes}m';
      }
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBooked = widget.isBooked;
    final isPast = widget.isPast;
    final isSelected = widget.isSelected;
    final timeSlot = widget.timeSlot;
    
    // Booked slots are tappable to view match details
    final isDisabled = isPast && !isBooked;
    final timeString = timeSlot['time'] as String;
    final startTime = timeString.split('-')[0];
    final endTime = timeString.split('-')[1];
    
    final formattedStart = _formatTime(startTime);
    final formattedEnd = _formatTime(endTime);
    final duration = _calculateDuration(timeString);

    Color bgColor = Colors.white;
    Color borderColor = Colors.grey[200]!;
    Color textColor = Colors.black87;

    if (isBooked) {
      bgColor = const Color(0xFF00BF63).withOpacity(0.08);
      borderColor = const Color(0xFF00BF63).withOpacity(0.3);
      textColor = Colors.black87;
    } else if (isPast) {
      bgColor = Colors.grey.shade50;
      borderColor = Colors.grey.shade200;
      textColor = Colors.grey.shade400;
    } else if (isSelected) {
      bgColor = const Color(0xFF00BF63).withOpacity(0.05);
      borderColor = const Color(0xFF00BF63);
      textColor = const Color(0xFF00BF63);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isBooked 
            ? widget.onBookedTap 
            : (isDisabled ? null : widget.onTap),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: isSelected ? 1.5 : 1),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$formattedStart - $formattedEnd',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      duration,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isPast ? textColor : Colors.grey[500],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    // Show host name if booked
                    if (isBooked && widget.booking != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 14,
                            color: const Color(0xFF00BF63),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _isLoadingHost 
                                  ? 'Loading...' 
                                  : (_hostName ?? 'Unknown'),
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF00BF63),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (isBooked)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00BF63).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'View Match',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF00BF63),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 12,
                            color: const Color(0xFF00BF63),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              else if (isSelected)
                const Icon(Icons.check_circle, color: Color(0xFF00BF63))
              else if (!isPast)
                Text(
                  '${timeSlot['price']} EGP',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF00BF63),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
