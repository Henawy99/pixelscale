import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
// import 'package:flutter_paymob/flutter_paymob.dart'; // Removed: Using native SDK via MethodChannel
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:playmakerappstart/l10n/app_localizations.dart';
import 'package:playmakerappstart/models/booking_model.dart';
import 'package:playmakerappstart/models/footballfield_model.dart';
import 'package:playmakerappstart/models/user_model.dart';
import 'package:playmakerappstart/services/supabase_service.dart';
import 'package:playmakerappstart/services/demo_data_service.dart';
import 'package:playmakerappstart/services/paymob_native_sdk_service.dart';
import 'package:uuid/uuid.dart';
import 'package:playmakerappstart/screens/booking_success_screen.dart';

class PaymentScreen extends StatefulWidget {
  final PlayerProfile playerProfile;
  final FootballField field;
  final DateTime selectedDate;
  final Map<String, dynamic> selectedTimeSlot;
  final List<String> invitePlayers;
  final List<String> inviteSquads;
  final bool isOpenMatch;
  final String? description;
  final int guestCount;
  final bool isRecordingEnabled;
  final int recordingPrice = 100;
  final int? maxPlayers;

  const PaymentScreen({
    super.key,
    required this.playerProfile,
    required this.field,
    required this.selectedDate,
    required this.selectedTimeSlot,
    required this.invitePlayers,
    required this.inviteSquads,
    required this.isOpenMatch,
    this.description,
    this.guestCount = 0,
    this.isRecordingEnabled = false,
    this.maxPlayers,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String? _selectedPaymentMethod = 'Cash'; // Default to Cash
  String? _selectedWallet;
  String _walletPhoneNumber = '';
  bool _isProcessing = false;
  
  // Native SDK service for Apple Pay
  final PaymobNativeSdkService _nativeSdkService = PaymobNativeSdkService();

  void _navigateToSuccessScreen() {
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => BookingSuccessScreen(
          playerProfile: widget.playerProfile,
          field: widget.field,
          selectedDate: widget.selectedDate,
          selectedTimeSlot: widget.selectedTimeSlot,
          totalPrice: _calculateTotalPrice(),
        ),
      ),
      (route) => false,
    );
  }

  /// Show wallet selector bottom sheet
  void _showWalletSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _WalletSelector(
        selectedWallet: _selectedWallet,
        phoneNumber: _walletPhoneNumber.isNotEmpty 
            ? _walletPhoneNumber 
            : widget.playerProfile.phoneNumber,
        onWalletSelected: (wallet, phone) {
          setState(() {
            _selectedWallet = wallet;
            _walletPhoneNumber = phone;
            _selectedPaymentMethod = 'Mobile Wallet';
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _processPayment() async {
    if (_selectedPaymentMethod == null || _isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      String paymentDetails;
      
      switch (_selectedPaymentMethod) {
        case 'Credit Card':
          await _processCardPayment();
          return;
        case 'Mobile Wallet':
          await _processWalletPayment();
          return;
        case 'Apple Pay':
          await _processApplePayPayment();
          return;
        case 'Cash':
          paymentDetails = 'Cash';
          break;
        default:
          paymentDetails = _selectedPaymentMethod!;
      }

      await _createBooking(paymentDetails);

      _navigateToSuccessScreen();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment failed: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  /// Process card payment using Paymob Native SDK
  Future<void> _processCardPayment() async {
    try {
      final nameParts = widget.playerProfile.name.split(' ');
      final firstName = nameParts.isNotEmpty && nameParts[0].isNotEmpty 
          ? nameParts[0] 
          : 'User';
      final lastName = nameParts.length > 1 && nameParts[1].isNotEmpty 
          ? nameParts.sublist(1).join(' ') 
          : 'Playmaker';
      final email = widget.playerProfile.email.isNotEmpty 
          ? widget.playerProfile.email 
          : 'user@playmaker.app';
      final phone = widget.playerProfile.phoneNumber.isNotEmpty 
          ? widget.playerProfile.phoneNumber 
          : '01000000000';

      final result = await _nativeSdkService.processPayment(
        amountCents: _calculateTotalPrice() * 100, // Convert to cents
        currency: 'EGP',
        customerFirstName: firstName,
        customerLastName: lastName,
        customerEmail: email,
        customerPhone: phone,
        paymentMethods: ['card'],
        orderId: _generateReference(),
      );

      switch (result) {
        case PaymentResult.success:
          print('✅ Card payment successful!');
          await _createBooking('Credit Card - Paymob');
          _navigateToSuccessScreen();
          break;
        case PaymentResult.pending:
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Payment is pending. Please wait.'), backgroundColor: Colors.orange, behavior: SnackBarBehavior.floating),
            );
          }
          break;
        case PaymentResult.rejected:
        case PaymentResult.error:
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Payment failed. Please try again.'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
            );
          }
          break;
      }
    } catch (e) {
      print('Card payment error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Card payment failed: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
  
  /// Process mobile wallet payment using Paymob Native SDK
  Future<void> _processWalletPayment() async {
    // Ensure phone number is valid
    String phoneNumber = _walletPhoneNumber.isNotEmpty 
        ? _walletPhoneNumber 
        : widget.playerProfile.phoneNumber;
    
    // Clean up phone number (Egyptian format)
    phoneNumber = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (phoneNumber.startsWith('2')) phoneNumber = phoneNumber.substring(1);
    if (!phoneNumber.startsWith('0')) phoneNumber = '0$phoneNumber';
    
    if (phoneNumber.length < 11) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid wallet phone number'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    
    try {
      final nameParts = widget.playerProfile.name.split(' ');
      final firstName = nameParts.isNotEmpty && nameParts[0].isNotEmpty 
          ? nameParts[0] 
          : 'User';
      final lastName = nameParts.length > 1 && nameParts[1].isNotEmpty 
          ? nameParts.sublist(1).join(' ') 
          : 'Playmaker';
      final email = widget.playerProfile.email.isNotEmpty 
          ? widget.playerProfile.email 
          : 'user@playmaker.app';

      final result = await _nativeSdkService.processPayment(
        amountCents: _calculateTotalPrice() * 100, // Convert to cents
        currency: 'EGP',
        customerFirstName: firstName,
        customerLastName: lastName,
        customerEmail: email,
        customerPhone: phoneNumber, // Use the extracted wallet phone number
        paymentMethods: ['wallet'],
        orderId: _generateReference(),
      );

      switch (result) {
        case PaymentResult.success:
          print('✅ Wallet payment successful!');
          await _createBooking('Mobile Wallet - $_selectedWallet');
          _navigateToSuccessScreen();
          break;
        case PaymentResult.pending:
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Payment is pending. Please wait.'), backgroundColor: Colors.orange, behavior: SnackBarBehavior.floating),
            );
          }
          break;
        case PaymentResult.rejected:
        case PaymentResult.error:
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Payment failed. Please try again.'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
            );
          }
          break;
      }
    } catch (e) {
      print('Wallet payment error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Wallet payment failed: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
  
  /// Process Apple Pay payment using Paymob Native SDK
  /// This uses the native iOS SDK via MethodChannel for true Apple Pay support
  Future<void> _processApplePayPayment() async {
    try {
      print('═══════════════════════════════════════════════════════════');
      print('🍎 PROCESSING APPLE PAY PAYMENT');
      print('═══════════════════════════════════════════════════════════');
      
      // Get user details for billing
      // Split name into first and last name for billing
      final nameParts = widget.playerProfile.name.split(' ');
      final firstName = nameParts.isNotEmpty && nameParts[0].isNotEmpty 
          ? nameParts[0] 
          : 'User';
      final lastName = nameParts.length > 1 && nameParts[1].isNotEmpty 
          ? nameParts.sublist(1).join(' ') 
          : 'Playmaker';
      final email = widget.playerProfile.email.isNotEmpty 
          ? widget.playerProfile.email 
          : 'user@playmaker.app';
      final phone = widget.playerProfile.phoneNumber.isNotEmpty 
          ? widget.playerProfile.phoneNumber 
          : '01000000000';
      
      // Use Native SDK service to process payment
      final result = await _nativeSdkService.processPayment(
        amountCents: _calculateTotalPrice() * 100, // Convert to cents
        currency: 'EGP',
        customerFirstName: firstName,
        customerLastName: lastName,
        customerEmail: email,
        customerPhone: phone,
        paymentMethods: ['apple_pay', 'card'], // Prefer Apple Pay, fallback to card
        orderId: _generateReference(),
      );
      
      switch (result) {
        case PaymentResult.success:
          print('✅ Apple Pay payment successful!');
          await _createBooking('Apple Pay - Paymob');
          
          _navigateToSuccessScreen();
          break;
          
        case PaymentResult.pending:
          print('⏳ Apple Pay payment pending');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Payment is pending. Please wait for confirmation.'),
                backgroundColor: Colors.orange,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          break;
          
        case PaymentResult.rejected:
          print('❌ Apple Pay payment rejected');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Payment was rejected. Please try again.'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          break;
          
        case PaymentResult.error:
          print('❌ Apple Pay payment error');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Payment failed. Please try another payment method.'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          break;
      }
    } catch (e) {
      print('❌ Apple Pay error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Apple Pay failed: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _createBooking(String paymentMethod) async {
    // Demo guard - don't create real bookings for demo account
    if (DemoDataService.isDemoAccount(widget.playerProfile.email)) {
      print('🎭 Demo mode: simulating booking creation');
      return;
    }
    try {
      final bookingRef = _generateReference();
      final bookingId = const Uuid().v4();
      
      final bookingStatus = 'pending';
      
      List<String> finalInvitePlayers = [widget.playerProfile.id, ...widget.invitePlayers];

      for (int i = 1; i <= widget.guestCount; i++) {
        finalInvitePlayers.add('guest$i+${widget.playerProfile.id}');
      }

      // First create the booking (without recording schedule ID initially)
      final booking = Booking(
        cameraUsername: widget.field.cameraUsername,
        cameraPassword: widget.field.cameraPassword,
        cameraIpAddress: widget.field.cameraIpAddress,
        locationName: widget.field.locationName,
        footballFieldName: widget.field.footballFieldName,
        bookingReference: bookingRef,
        host: widget.playerProfile.id,
        id: bookingId,
        userId: widget.playerProfile.id,
        footballFieldId: widget.field.id,
        date: DateFormat('yyyy-MM-dd').format(widget.selectedDate),
        timeSlot: widget.selectedTimeSlot['time'],
        price: _parsePrice(widget.selectedTimeSlot['price']),
        paymentType: paymentMethod,
        invitePlayers: finalInvitePlayers,
        inviteSquads: widget.inviteSquads,
        isOpenMatch: widget.isOpenMatch,
        description: widget.description,
        isRecordingEnabled: widget.isRecordingEnabled,
        status: bookingStatus,
        maxPlayers: widget.maxPlayers,
        recordingScheduleId: null, // Will be updated after schedule creation
      );

      // Create the booking FIRST (so the foreign key constraint is satisfied)
      await SupabaseService().createBooking(booking);
      print('✅ Booking created: $bookingId');

      // THEN create recording schedule if recording is enabled and field has camera
      // (must happen AFTER booking exists due to foreign key constraint)
      if (widget.isRecordingEnabled && widget.field.hasCamera) {
        // Small delay to ensure booking is fully committed to database
        // (handles potential replication lag in Supabase)
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Verify booking exists before creating schedule
        final bookingExists = await SupabaseService().getBookingById(bookingId);
        if (bookingExists == null) {
          print('⚠️ Booking not found after creation, waiting longer...');
          await Future.delayed(const Duration(seconds: 1));
        }
        // Parse time slot to get start and end times
        final timeSlot = widget.selectedTimeSlot['time'] as String;
        final times = timeSlot.split('-');
        if (times.length == 2) {
          final startTimeParts = times[0].split(':');
          final endTimeParts = times[1].split(':');
          
          final startHour = int.parse(startTimeParts[0]);
          final startMinute = int.parse(startTimeParts[1]);
          final endHour = int.parse(endTimeParts[0]);
          final endMinute = int.parse(endTimeParts[1]);
          
          final startTime = DateTime(
            widget.selectedDate.year,
            widget.selectedDate.month,
            widget.selectedDate.day,
            startHour,
            startMinute,
          );
          
          final endTime = DateTime(
            widget.selectedDate.year,
            widget.selectedDate.month,
            widget.selectedDate.day,
            endHour,
            endMinute,
          );
          
          // Create the recording schedule (booking now exists)
          final recordingScheduleId = await SupabaseService().createCameraRecordingSchedule(
            bookingId: bookingId,
            fieldId: widget.field.id,
            startTime: startTime,
            endTime: endTime,
            enableBallTracking: true,
          );
          
          print('📹 Recording schedule created: $recordingScheduleId');
          
          // Update booking with the recording schedule ID
          if (recordingScheduleId != null) {
            await SupabaseService().updateBookingRecordingScheduleId(
              bookingId: bookingId,
              recordingScheduleId: recordingScheduleId,
            );
            print('📹 Booking updated with recording schedule ID');
          }
        }
      }
      
      // Note: Updating local player profile state isn't strictly necessary here 
      // if we are navigating away to MainScreen which re-fetches or uses provided model.
      // But keeping it for consistency with previous logic if navigation fails/delays.
    } catch (e) {
      print('Error creating booking: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.paymentScreen_failedToCreateBooking(e.toString()))),
        );
      }
      rethrow;
    }
  }

  String _generateReference() {
    final timestamp = DateFormat('yyyyMMddHHmmss').format(DateTime.now());
    final random = Random().nextInt(100000).toString().padLeft(5, '0');
    return '$timestamp$random';
  }

  /// Parse price from various formats (int, num, String)
  int _parsePrice(dynamic priceValue) {
    if (priceValue is int) {
      return priceValue;
    } else if (priceValue is num) {
      return priceValue.toInt();
    } else if (priceValue is String) {
      return int.tryParse(priceValue) ?? 0;
    }
    return 0;
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
    if (widget.isRecordingEnabled && widget.field.hasCamera) {
      return basePrice + widget.recordingPrice;
    }
    return basePrice;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AppLocalizations.of(context)!.paymentScreen_checkoutTitle,
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
            // 1. Order Summary
            Text(
              AppLocalizations.of(context)!.paymentScreen_bookingSummaryTitle,
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black),
            ),
            const SizedBox(height: 16),
            _buildOrderSummaryCard(),
            
            const SizedBox(height: 32),

            // 2. Payment Method Selection
            Text(
              AppLocalizations.of(context)!.paymentScreen_paymentMethodSectionTitle,
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black),
            ),
            const SizedBox(height: 16),
            
            // Credit Card payment
            _buildPaymentMethodTile(
              title: AppLocalizations.of(context)!.paymentScreen_creditCardOption,
              icon: FontAwesomeIcons.creditCard,
              id: 'Credit Card',
            ),
            
            const SizedBox(height: 12),
            
            // Apple Pay (iOS only)
            if (Platform.isIOS) ...[
              _buildPaymentMethodTile(
                title: 'Apple Pay',
                icon: FontAwesomeIcons.apple,
                id: 'Apple Pay',
              ),
              const SizedBox(height: 12),
            ],
            
            // Mobile Wallet payment
            _buildPaymentMethodTile(
              title: AppLocalizations.of(context)!.paymentScreen_mobileWalletOption,
              icon: FontAwesomeIcons.wallet,
              id: 'Mobile Wallet',
              onTap: () => _showWalletSelector(),
            ),
            
            // Show selected wallet if Mobile Wallet is selected
            if (_selectedPaymentMethod == 'Mobile Wallet' && _selectedWallet != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00BF63).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Color(0xFF00BF63), size: 16),
                    const SizedBox(width: 8),
                    Text(
                      _selectedWallet!,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF00BF63),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 12),
            
            // Cash payment
            _buildPaymentMethodTile(
              title: AppLocalizations.of(context)!.paymentScreen_cashOption,
              icon: FontAwesomeIcons.moneyBill1,
              id: 'Cash',
            ),
            
            const SizedBox(height: 16),
            
            // Info box based on selected payment method
            _buildPaymentInfoBox(),
            
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
                  AppLocalizations.of(context)!.paymentScreen_totalPriceLabel,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  AppLocalizations.of(context)!.paymentScreen_priceEGP(_calculateTotalPrice()),
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
              child: ElevatedButton.icon(
                onPressed: (_selectedPaymentMethod != null && !_isProcessing) 
                    ? _processPayment 
                    : null,
                icon: _isProcessing 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.check_circle_outline, size: 20),
                label: Text(
                  _isProcessing 
                      ? 'Processing...' 
                      : 'Confirm Booking'
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00BF63),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  disabledBackgroundColor: Colors.grey[300],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF00BF63).withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF00BF63).withOpacity(0.1)),
      ),
      child: Column(
        children: [
          _buildSummaryRow(
            Icons.calendar_today, 
            DateFormat('EEE, MMM d', AppLocalizations.of(context)!.localeName).format(widget.selectedDate)
          ),
          const SizedBox(height: 12),
          _buildSummaryRow(
            Icons.access_time, 
            _formatTimeSlot(widget.selectedTimeSlot['time'])
          ),
          const SizedBox(height: 12),
          _buildSummaryRow(
            Icons.location_on, 
            widget.field.footballFieldName
          ),
          
          if (widget.isRecordingEnabled && widget.field.hasCamera) ...[
            const SizedBox(height: 12),
            _buildSummaryRow(
              Icons.videocam, 
              'Recording Enabled'
            ),
          ],

          const SizedBox(height: 16),
          Divider(height: 1, color: Colors.grey[300]),
          const SizedBox(height: 16),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppLocalizations.of(context)!.paymentScreen_fieldRentalLabel,
                style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 14),
              ),
              Text(
                AppLocalizations.of(context)!.paymentScreen_priceEGP(widget.selectedTimeSlot['price']),
                style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.black87),
              ),
            ],
          ),
          if (widget.isRecordingEnabled && widget.field.hasCamera) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Camera Recording',
                  style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 14),
                ),
                Text(
                  '+${AppLocalizations.of(context)!.paymentScreen_priceEGP(widget.recordingPrice)}',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.black87),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF00BF63)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodTile({
    required String title,
    required IconData icon,
    required String id,
    VoidCallback? onTap,
  }) {
    final isSelected = _selectedPaymentMethod == id;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap ?? () {
          setState(() {
            _selectedPaymentMethod = id;
            if (id != 'Mobile Wallet') _selectedWallet = null;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF00BF63).withOpacity(0.05) : Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFF00BF63) : Colors.grey[200]!,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: isSelected ? const Color(0xFF00BF63) : Colors.grey[600]),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: isSelected ? const Color(0xFF00BF63) : Colors.black87,
                  ),
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_circle, color: Color(0xFF00BF63), size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentInfoBox() {
    String message;
    IconData icon;
    MaterialColor color;
    
    switch (_selectedPaymentMethod) {
      case 'Credit Card':
        message = 'Pay securely with your credit or debit card. Your booking will be confirmed immediately.';
        icon = Icons.security;
        color = Colors.green;
        break;
      case 'Apple Pay':
        message = 'Pay quickly and securely with Apple Pay using Face ID or Touch ID. Your booking will be confirmed immediately.';
        icon = Icons.apple;
        color = Colors.grey;
        break;
      case 'Mobile Wallet':
        message = 'Pay using your mobile wallet (Vodafone Cash, Orange Cash, etc.). You will be redirected to complete the payment.';
        icon = Icons.phone_android;
        color = Colors.purple;
        break;
      case 'Cash':
      default:
        message = 'Pay at the field when you arrive. Your booking will be confirmed once payment is received.';
        icon = Icons.info_outline;
        color = Colors.blue;
        break;
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.shade100),
      ),
      child: Row(
        children: [
          Icon(icon, color: color.shade600, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: color.shade700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletSelector extends StatefulWidget {
  final String? selectedWallet;
  final String phoneNumber;
  final void Function(String wallet, String phone) onWalletSelected;

  const _WalletSelector({
    required this.selectedWallet,
    required this.phoneNumber,
    required this.onWalletSelected,
  });

  @override
  State<_WalletSelector> createState() => _WalletSelectorState();
}

class _WalletSelectorState extends State<_WalletSelector> {
  late TextEditingController _phoneController;
  String? _tempSelectedWallet;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(text: widget.phoneNumber);
    _tempSelectedWallet = widget.selectedWallet;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _selectWallet(String wallet) {
    setState(() {
      _tempSelectedWallet = wallet;
    });
  }

  void _confirmSelection() {
    if (_tempSelectedWallet != null && _phoneController.text.isNotEmpty) {
      widget.onWalletSelected(_tempSelectedWallet!, _phoneController.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      decoration: BoxDecoration(
        color: Colors.white,
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
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.paymentScreen_selectMobileWalletTitle,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Phone number input
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Wallet Phone Number',
                    hintText: '01xxxxxxxxx',
                    prefixIcon: const Icon(Icons.phone, color: Color(0xFF00BF63)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF00BF63), width: 2),
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                Text(
                  'Select Wallet Provider',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 12),
                
                _WalletOption(
                  name: AppLocalizations.of(context)!.paymentScreen_vodafoneCash,
                  imagePath: 'assets/images/mobile-wallet-logos/vodafone-cash.png',
                  isSelected: _tempSelectedWallet == AppLocalizations.of(context)!.paymentScreen_vodafoneCash,
                  onTap: () => _selectWallet(AppLocalizations.of(context)!.paymentScreen_vodafoneCash),
                ),
                const SizedBox(height: 12),
                _WalletOption(
                  name: AppLocalizations.of(context)!.paymentScreen_etisalatCash,
                  imagePath: 'assets/images/mobile-wallet-logos/etisalat-cash.png',
                  isSelected: _tempSelectedWallet == AppLocalizations.of(context)!.paymentScreen_etisalatCash,
                  onTap: () => _selectWallet(AppLocalizations.of(context)!.paymentScreen_etisalatCash),
                ),
                const SizedBox(height: 12),
                _WalletOption(
                  name: AppLocalizations.of(context)!.paymentScreen_orangeCash,
                  imagePath: 'assets/images/mobile-wallet-logos/orange-cash.png',
                  isSelected: _tempSelectedWallet == AppLocalizations.of(context)!.paymentScreen_orangeCash,
                  onTap: () => _selectWallet(AppLocalizations.of(context)!.paymentScreen_orangeCash),
                ),
                const SizedBox(height: 12),
                _WalletOption(
                  name: AppLocalizations.of(context)!.paymentScreen_otherWallets,
                  icon: Icons.account_balance_wallet_outlined,
                  isSelected: _tempSelectedWallet == AppLocalizations.of(context)!.paymentScreen_otherWallets,
                  onTap: () => _selectWallet(AppLocalizations.of(context)!.paymentScreen_otherWallets),
                ),
                
                const SizedBox(height: 20),
                
                // Confirm button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (_tempSelectedWallet != null && _phoneController.text.length >= 11) 
                        ? _confirmSelection 
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00BF63),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      disabledBackgroundColor: Colors.grey[300],
                    ),
                    child: Text(
                      'Confirm Wallet',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
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

class _WalletOption extends StatelessWidget {
  final String name;
  final String? imagePath;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _WalletOption({
    required this.name,
    this.imagePath,
    this.icon,
    required this.isSelected,
    required this.onTap,
  }) : assert(imagePath != null || icon != null);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF00BF63).withOpacity(0.05) : Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFF00BF63) : Colors.grey[200]!,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              if (imagePath != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Image.asset(
                    imagePath!,
                    width: 24,
                    height: 24,
                    fit: BoxFit.contain,
                  ),
                )
              else if (icon != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.grey[600],
                    size: 24,
                  ),
                ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  name,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: isSelected ? const Color(0xFF00BF63) : Colors.black87,
                  ),
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_circle, color: Color(0xFF00BF63), size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
