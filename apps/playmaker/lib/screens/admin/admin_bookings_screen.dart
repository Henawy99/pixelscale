import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:playmakerappstart/models/booking_model.dart';
import 'package:playmakerappstart/services/supabase_service.dart';
import 'package:playmakerappstart/services/notification_service.dart';
import 'package:intl/intl.dart';
import 'package:playmakerappstart/screens/admin/booking_detail_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AdminBookingsScreen extends StatefulWidget {
  const AdminBookingsScreen({Key? key}) : super(key: key);

  @override
  State<AdminBookingsScreen> createState() => _AdminBookingsScreenState();
}

class _AdminBookingsScreenState extends State<AdminBookingsScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final NotificationService _notificationService = NotificationService();

  List<Booking> _bookings = [];
  int _totalBookings = 0;
  int _bookingsToday = 0;
  int _bookingsThisWeek = 0;
  int _bookingsThisMonth = 0;
  double _totalRevenue = 0.0;
  bool _isLoading = true;
  String? _selectedDate;

  @override
  void initState() {
    super.initState();
    _fetchBookings();
  }

  Future<void> _fetchBookings() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      // Fetch all bookings
      final bookings = await _supabaseService.getAllBookings(
        date: _selectedDate,
        limit: 1000,
      );

      // Sort by date descending (newest first)
      bookings.sort((a, b) {
        try {
          return b.date.compareTo(a.date);
        } catch (e) {
          return 0;
        }
      });

      // Calculate statistics
      _calculateStatistics(bookings);

      if (mounted) {
        setState(() {
          _bookings = bookings;
          _totalBookings = bookings.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching bookings: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Failed to load bookings');
      }
    }
  }

  void _calculateStatistics(List<Booking> bookings) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
    final startOfMonth = DateTime(now.year, now.month, 1);

    int todayCount = 0;
    int weekCount = 0;
    int monthCount = 0;
    double revenue = 0.0;

    for (var booking in bookings) {
      try {
        // Parse booking date (format: yyyy-MM-dd)
        final dateParts = booking.date.split('-');
        if (dateParts.length == 3) {
          final bookingDate = DateTime(
            int.parse(dateParts[0]),
            int.parse(dateParts[1]),
            int.parse(dateParts[2]),
          );

          if (bookingDate.isAtSameMomentAs(today)) {
            todayCount++;
          }

          if (bookingDate.isAfter(startOfWeek.subtract(const Duration(days: 1))) ||
              bookingDate.isAtSameMomentAs(startOfWeek)) {
            weekCount++;
          }

          if (bookingDate.isAfter(startOfMonth.subtract(const Duration(days: 1))) ||
              bookingDate.isAtSameMomentAs(startOfMonth)) {
            monthCount++;
          }
        }

        // Calculate revenue (assuming price field exists)
        if (booking.price != null) {
          revenue += double.tryParse(booking.price.toString()) ?? 0.0;
        }
      } catch (e) {
        print('Error calculating stats for booking: $e');
      }
    }

    setState(() {
      _bookingsToday = todayCount;
      _bookingsThisWeek = weekCount;
      _bookingsThisMonth = monthCount;
      _totalRevenue = revenue;
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _showCancelBookingDialog(Booking booking) async {
    final reasonController = TextEditingController();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            const SizedBox(width: 8),
            const Text('Cancel Booking'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to cancel this booking?',
              style: GoogleFonts.inter(fontSize: 14),
            ),
            const SizedBox(height: 12),
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
                    booking.footballFieldName,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  Text('Date: ${booking.date}'),
                  Text('Time: ${booking.timeSlot}'),
                  if (booking.price != null) Text('Price: EGP ${booking.price}'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: 'Cancellation Reason (Optional)',
                hintText: 'e.g., Field maintenance, Weather conditions...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'The user will be notified and the time slot will become available again.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
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
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Booking'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cancel Booking'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _cancelBooking(booking, reasonController.text.trim());
    }
  }

  Future<void> _cancelBooking(Booking booking, String? reason) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // 1. Update booking status to 'cancelled'
      await _supabaseService.updateBooking(booking.id, {
        'status': 'cancelled',
      });

      // 2. Cancel any associated camera recording schedule
      if (booking.recordingScheduleId != null) {
        try {
          await _supabaseService.updateCameraRecordingScheduleStatus(
            booking.recordingScheduleId!,
            'cancelled',
          );
          print('📹 Cancelled associated recording schedule: ${booking.recordingScheduleId}');
        } catch (e) {
          print('⚠️ Could not cancel recording schedule: $e');
        }
      }

      // 3. Send push notification to the user
      try {
        await _notificationService.sendBookingRejectedNotification(
          userId: booking.userId,
          fieldName: booking.footballFieldName,
          date: booking.date,
          timeSlot: booking.timeSlot,
          rejectionReason: reason?.isNotEmpty == true ? reason : null,
        );
        print('✅ Sent cancellation notification to user');
      } catch (e) {
        print('⚠️ Could not send notification: $e');
      }

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Refresh bookings list
      await _fetchBookings();

      if (mounted) {
        _showSuccess('Booking cancelled successfully. User has been notified.');
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.pop(context);
      
      print('Error cancelling booking: $e');
      _showError('Failed to cancel booking: $e');
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    if (status.isEmpty) return 'Pending';
    return status[0].toUpperCase() + status.substring(1).toLowerCase();
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      setState(() {
        _selectedDate = DateFormat('yyyy-MM-dd').format(date);
      });
      _fetchBookings();
    }
  }

  void _clearDateFilter() {
    setState(() => _selectedDate = null);
    _fetchBookings();
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isWideScreen,
  }) {
    if (isWideScreen) {
      // Compact horizontal layout for web
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      // Original vertical layout for mobile
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWideScreen = size.width > 900;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchBookings,
              child: ListView(
                padding: EdgeInsets.all(isWideScreen ? 24 : 16),
                children: [
                  // Statistics Cards - Responsive Layout
                  if (isWideScreen)
                    // Web: Horizontal row of compact stats
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            title: 'Total Bookings',
                            value: _totalBookings.toString(),
                            icon: Icons.calendar_today,
                            color: Colors.blue,
                            isWideScreen: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            title: 'Today',
                            value: _bookingsToday.toString(),
                            icon: Icons.today,
                            color: Colors.green,
                            isWideScreen: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            title: 'This Week',
                            value: _bookingsThisWeek.toString(),
                            icon: Icons.calendar_view_week,
                            color: Colors.orange,
                            isWideScreen: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            title: 'Total Revenue',
                            value: 'EGP ${_totalRevenue.toStringAsFixed(0)}',
                            icon: Icons.attach_money,
                            color: Colors.purple,
                            isWideScreen: true,
                          ),
                        ),
                      ],
                    )
                  else
                    // Mobile: Grid layout
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.4,
                      children: [
                        _buildStatCard(
                          title: 'Total Bookings',
                          value: _totalBookings.toString(),
                          icon: Icons.calendar_today,
                          color: Colors.blue,
                          isWideScreen: false,
                        ),
                        _buildStatCard(
                          title: 'Today',
                          value: _bookingsToday.toString(),
                          icon: Icons.today,
                          color: Colors.green,
                          isWideScreen: false,
                        ),
                        _buildStatCard(
                          title: 'This Week',
                          value: _bookingsThisWeek.toString(),
                          icon: Icons.calendar_view_week,
                          color: Colors.orange,
                          isWideScreen: false,
                        ),
                        _buildStatCard(
                          title: 'Total Revenue',
                          value: 'EGP ${_totalRevenue.toStringAsFixed(0)}',
                          icon: Icons.attach_money,
                          color: Colors.purple,
                          isWideScreen: false,
                        ),
                      ],
                    ),

                  SizedBox(height: isWideScreen ? 24 : 20),

                  // Date Filter
                  Container(
                    constraints: BoxConstraints(maxWidth: isWideScreen ? 400 : double.infinity),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _selectDate,
                            icon: const Icon(Icons.filter_list),
                            label: Text(
                              _selectedDate != null
                                  ? 'Filter: $_selectedDate'
                                  : 'Filter by Date',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black87,
                              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        if (_selectedDate != null) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: _clearDateFilter,
                            icon: const Icon(Icons.clear),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.red.shade100,
                              foregroundColor: Colors.red.shade700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Bookings List Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_bookings.length} Bookings',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _fetchBookings,
                        tooltip: 'Refresh',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Bookings List
                  if (_bookings.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(Icons.event_busy, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              'No bookings found',
                              style: GoogleFonts.inter(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (isWideScreen)
                    // Web: Table-like layout
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          // Header
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                            ),
                            child: Row(
                              children: [
                                const SizedBox(width: 48), // Icon space
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    'Field',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    'Booked By',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    'Date',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    'Time',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 80,
                                  child: Text(
                                    'Status',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 100,
                                  child: Text(
                                    'Price',
                                    textAlign: TextAlign.right,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 100), // Actions space
                              ],
                            ),
                          ),
                          // Booking Rows
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _bookings.length,
                            separatorBuilder: (context, index) => Divider(
                              height: 1,
                              color: Colors.grey.shade200,
                            ),
                            itemBuilder: (context, index) {
                              final booking = _bookings[index];
                              final isCancelled = booking.status.toLowerCase() == 'cancelled' || 
                                                  booking.status.toLowerCase() == 'rejected';
                              return InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => BookingDetailScreen(booking: booking),
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: isCancelled ? Colors.red.shade50 : Colors.green.shade50,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          isCancelled ? Icons.cancel : Icons.sports_soccer,
                                          color: isCancelled ? Colors.red.shade700 : Colors.green.shade700,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          booking.footballFieldName,
                                          style: GoogleFonts.inter(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                            decoration: isCancelled ? TextDecoration.lineThrough : null,
                                            color: isCancelled ? Colors.grey : null,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      // Booked By column
                                      Expanded(
                                        flex: 2,
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 14,
                                              backgroundColor: Colors.grey.shade200,
                                              backgroundImage: (booking.userPhotoUrl != null && booking.userPhotoUrl!.isNotEmpty)
                                                  ? CachedNetworkImageProvider(booking.userPhotoUrl!)
                                                  : null,
                                              child: (booking.userPhotoUrl == null || booking.userPhotoUrl!.isEmpty)
                                                  ? Text(
                                                      (booking.userName?.isNotEmpty == true)
                                                          ? booking.userName![0].toUpperCase()
                                                          : '?',
                                                      style: GoogleFonts.inter(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w600,
                                                        color: Colors.grey.shade600,
                                                      ),
                                                    )
                                                  : null,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                booking.userName ?? 'Unknown',
                                                style: GoogleFonts.inter(
                                                  fontSize: 13,
                                                  color: isCancelled ? Colors.grey : Colors.black87,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: Text(
                                          booking.date,
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            color: isCancelled ? Colors.grey : Colors.grey.shade700,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: Text(
                                          booking.timeSlot,
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            color: isCancelled ? Colors.grey : Colors.grey.shade700,
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 80,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(booking.status).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            _getStatusText(booking.status),
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: _getStatusColor(booking.status),
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 100,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (booking.price != null)
                                              Text(
                                                'EGP ${booking.price}',
                                                style: GoogleFonts.inter(
                                                  fontWeight: FontWeight.w700,
                                                  color: isCancelled ? Colors.grey : Colors.green.shade700,
                                                  fontSize: 14,
                                                  decoration: isCancelled ? TextDecoration.lineThrough : null,
                                                ),
                                              ),
                                            Text(
                                              booking.isOpenMatch ? 'Open' : 'Private',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(
                                        width: 100,
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            if (!isCancelled)
                                              IconButton(
                                                onPressed: () => _showCancelBookingDialog(booking),
                                                icon: const Icon(Icons.cancel_outlined),
                                                color: Colors.red.shade400,
                                                iconSize: 20,
                                                tooltip: 'Cancel Booking',
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(
                                                  minWidth: 32,
                                                  minHeight: 32,
                                                ),
                                              ),
                                            Icon(
                                              Icons.chevron_right,
                                              color: Colors.grey.shade400,
                                              size: 20,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    )
                  else
                    // Mobile: Card layout
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _bookings.length,
                      itemBuilder: (context, index) {
                        final booking = _bookings[index];
                        final isCancelled = booking.status.toLowerCase() == 'cancelled' || 
                                            booking.status.toLowerCase() == 'rejected';
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => BookingDetailScreen(booking: booking),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: isCancelled ? Colors.red.shade100 : Colors.green.shade100,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          isCancelled ? Icons.cancel : Icons.sports_soccer,
                                          color: isCancelled ? Colors.red.shade700 : Colors.green.shade700,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    booking.footballFieldName,
                                                    style: GoogleFonts.inter(
                                                      fontWeight: FontWeight.w600,
                                                      decoration: isCancelled ? TextDecoration.lineThrough : null,
                                                      color: isCancelled ? Colors.grey : null,
                                                    ),
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: _getStatusColor(booking.status).withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: Text(
                                                    _getStatusText(booking.status),
                                                    style: GoogleFonts.inter(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w600,
                                                      color: _getStatusColor(booking.status),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            // Booked By row
                                            if (booking.userName != null && booking.userName!.isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(bottom: 4),
                                                child: Row(
                                                  children: [
                                                    CircleAvatar(
                                                      radius: 10,
                                                      backgroundColor: Colors.grey.shade200,
                                                      backgroundImage: (booking.userPhotoUrl != null && booking.userPhotoUrl!.isNotEmpty)
                                                          ? CachedNetworkImageProvider(booking.userPhotoUrl!)
                                                          : null,
                                                      child: (booking.userPhotoUrl == null || booking.userPhotoUrl!.isEmpty)
                                                          ? Text(
                                                              booking.userName![0].toUpperCase(),
                                                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                                                            )
                                                          : null,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Expanded(
                                                      child: Text(
                                                        booking.userName!,
                                                        style: GoogleFonts.inter(
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.w500,
                                                          color: isCancelled ? Colors.grey : Colors.grey.shade800,
                                                        ),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            Text(
                                              'Date: ${booking.date}',
                                              style: TextStyle(
                                                color: isCancelled ? Colors.grey : Colors.grey.shade700,
                                              ),
                                            ),
                                            Text(
                                              'Time: ${booking.timeSlot}',
                                              style: TextStyle(
                                                color: isCancelled ? Colors.grey : Colors.grey.shade700,
                                              ),
                                            ),
                                            Text(
                                              '${booking.invitePlayers.length} players',
                                              style: TextStyle(
                                                color: isCancelled ? Colors.grey : Colors.grey.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          if (booking.price != null)
                                            Text(
                                              'EGP ${booking.price}',
                                              style: GoogleFonts.inter(
                                                fontWeight: FontWeight.w700,
                                                color: isCancelled ? Colors.grey : Colors.green.shade700,
                                                fontSize: 16,
                                                decoration: isCancelled ? TextDecoration.lineThrough : null,
                                              ),
                                            ),
                                          Text(
                                            booking.isOpenMatch ? 'Open' : 'Private',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  if (!isCancelled) ...[
                                    const Divider(height: 16),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton.icon(
                                          onPressed: () => _showCancelBookingDialog(booking),
                                          icon: Icon(Icons.cancel_outlined, color: Colors.red.shade400, size: 18),
                                          label: Text(
                                            'Cancel Booking',
                                            style: TextStyle(color: Colors.red.shade400),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
    );
  }
}

