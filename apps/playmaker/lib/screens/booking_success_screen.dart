import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:intl/intl.dart';
import 'package:playmakerappstart/main_screen.dart';
import 'package:playmakerappstart/models/footballfield_model.dart';
import 'package:playmakerappstart/models/user_model.dart';

class BookingSuccessScreen extends StatefulWidget {
  final PlayerProfile playerProfile;
  final FootballField field;
  final DateTime selectedDate;
  final Map<String, dynamic> selectedTimeSlot;
  final int totalPrice;

  const BookingSuccessScreen({
    super.key,
    required this.playerProfile,
    required this.field,
    required this.selectedDate,
    required this.selectedTimeSlot,
    required this.totalPrice,
  });

  @override
  State<BookingSuccessScreen> createState() => _BookingSuccessScreenState();
}

class _BookingSuccessScreenState extends State<BookingSuccessScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  final InAppReview _inAppReview = InAppReview.instance;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleReview() async {
    try {
      if (await _inAppReview.isAvailable()) {
        await _inAppReview.requestReview();
      } else {
        await _inAppReview.openStoreListing(
          appStoreId: '6463660309', // Playmaker App Store ID
        );
      }
    } catch (e) {
      print('Error requesting review: $e');
    }
  }

  void _navigateToHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => MainScreen(userModel: widget.playerProfile),
      ),
      (route) => false,
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
    
    return '${DateFormat('h:mm a').format(start)} - ${DateFormat('h:mm a').format(end)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              
              // Success Animation
              ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00BF63).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Color(0xFF00BF63),
                    size: 80,
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              Text(
                'Booking Confirmed!',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
              
              const SizedBox(height: 12),
              
              Text(
                'Your match has been successfully booked.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 40),

              // Booking Details Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  children: [
                    _buildDetailRow(
                      Icons.stadium_outlined,
                      widget.field.footballFieldName,
                    ),
                    const SizedBox(height: 16),
                    _buildDetailRow(
                      Icons.calendar_today_outlined,
                      DateFormat('EEEE, d MMMM y').format(widget.selectedDate),
                    ),
                    const SizedBox(height: 16),
                    _buildDetailRow(
                      Icons.access_time,
                      _formatTimeSlot(widget.selectedTimeSlot['time']),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Rate App Button
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF00BF63).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF00BF63).withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) => const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 2),
                        child: Icon(Icons.star, color: Colors.orange, size: 24),
                      )),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Enjoying Playmaker?',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Please take a moment to rate us!',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _handleReview,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00BF63),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Rate App',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Back to Home Button
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _navigateToHome,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Back to Home',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
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

  Widget _buildDetailRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF00BF63)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}
