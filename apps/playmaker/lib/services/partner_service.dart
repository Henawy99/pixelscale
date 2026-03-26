import 'package:playmakerappstart/models/footballfield_model.dart';
import 'package:playmakerappstart/models/booking_model.dart';
import 'package:playmakerappstart/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for partner/field owner operations
class PartnerService {
  final SupabaseService _supabaseService = SupabaseService();
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Authenticate field owner with email and password
  /// Returns the field if credentials are valid, null otherwise
  Future<FootballField?> authenticateOwner(String email, String password) async {
    try {
      final result = await _supabaseService.getFootballFields(limit: 1000, includeDisabled: true);
      
      // Find field with matching credentials
      for (var field in result.fields) {
        if (field.username.trim().toLowerCase() == email.trim().toLowerCase() &&
            field.password.trim() == password.trim()) {
          return field;
        }
      }
      
      return null; // No matching credentials found
    } catch (e) {
      print('Error authenticating owner: $e');
      return null;
    }
  }

  /// Get all bookings for a specific field
  Future<List<Booking>> getFieldBookings(String fieldId, {String? date}) async {
    try {
      // Get all bookings
      final allBookings = await _supabaseService.getAllBookings(limit: 1000);
      
      // Filter by field ID
      var fieldBookings = allBookings.where((booking) => 
        booking.footballFieldId == fieldId
      ).toList();
      
      // Filter by date if provided
      if (date != null) {
        fieldBookings = fieldBookings.where((booking) => booking.date == date).toList();
      }
      
      // Sort by date descending (newest first)
      fieldBookings.sort((a, b) => b.date.compareTo(a.date));
      
      return fieldBookings;
    } catch (e) {
      print('Error getting field bookings: $e');
      return [];
    }
  }

  /// Get booking statistics for a field
  Future<Map<String, dynamic>> getBookingStats(String fieldId) async {
    try {
      final bookings = await getFieldBookings(fieldId);
      
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
      final startOfMonth = DateTime(now.year, now.month, 1);

      int todayCount = 0;
      int weekCount = 0;
      int monthCount = 0;
      double totalRevenue = 0.0;
      double todayRevenue = 0.0;
      double weekRevenue = 0.0;
      double monthRevenue = 0.0;

      for (var booking in bookings) {
        try {
          final dateParts = booking.date.split('-');
          if (dateParts.length == 3) {
            final bookingDate = DateTime(
              int.parse(dateParts[0]),
              int.parse(dateParts[1]),
              int.parse(dateParts[2]),
            );

            final price = double.tryParse(booking.price.toString()) ?? 0.0;
            totalRevenue += price;

            if (bookingDate.isAtSameMomentAs(today)) {
              todayCount++;
              todayRevenue += price;
            }

            if (bookingDate.isAfter(startOfWeek.subtract(const Duration(days: 1))) ||
                bookingDate.isAtSameMomentAs(startOfWeek)) {
              weekCount++;
              weekRevenue += price;
            }

            if (bookingDate.isAfter(startOfMonth.subtract(const Duration(days: 1))) ||
                bookingDate.isAtSameMomentAs(startOfMonth)) {
              monthCount++;
              monthRevenue += price;
            }
          }
        } catch (e) {
          print('Error calculating stats for booking: $e');
        }
      }

      return {
        'totalBookings': bookings.length,
        'todayBookings': todayCount,
        'weekBookings': weekCount,
        'monthBookings': monthCount,
        'totalRevenue': totalRevenue,
        'todayRevenue': todayRevenue,
        'weekRevenue': weekRevenue,
        'monthRevenue': monthRevenue,
      };
    } catch (e) {
      print('Error getting booking stats: $e');
      return {
        'totalBookings': 0,
        'todayBookings': 0,
        'weekBookings': 0,
        'monthBookings': 0,
        'totalRevenue': 0.0,
        'todayRevenue': 0.0,
        'weekRevenue': 0.0,
        'monthRevenue': 0.0,
      };
    }
  }

  /// Update timeslot availability
  Future<bool> updateTimeslotAvailability({
    required String fieldId,
    required String day,
    required int slotIndex,
    required bool available,
  }) async {
    try {
      // Get the field
      final field = await _supabaseService.getFootballFieldById(fieldId);
      if (field == null) return false;

      // Update the specific timeslot
      if (field.availableTimeSlots.containsKey(day) &&
          slotIndex < field.availableTimeSlots[day]!.length) {
        field.availableTimeSlots[day]![slotIndex]['available'] = available;
        
        // Update the field in database
        await _supabaseService.updateFootballField(field);
        return true;
      }
      
      return false;
    } catch (e) {
      print('Error updating timeslot: $e');
      return false;
    }
  }

  /// Get field by ID
  Future<FootballField?> getFieldById(String fieldId) async {
    try {
      return await _supabaseService.getFootballFieldById(fieldId);
    } catch (e) {
      print('Error getting field: $e');
      return null;
    }
  }

  /// Update field details
  Future<bool> updateField(FootballField field) async {
    try {
      await _supabaseService.updateFootballField(field);
      return true;
    } catch (e) {
      print('Error updating field: $e');
      return false;
    }
  }

  /// Reject a booking
  /// This will:
  /// 1. Delete the booking from the database (freeing up the timeslot)
  /// 2. Send notification to user (handled separately)
  /// 
  /// Note: We delete the booking instead of just updating status so the timeslot
  /// becomes immediately available for other users to book.
  Future<bool> rejectBooking({
    required String bookingId,
    required String fieldId,
    String? rejectionReason,
  }) async {
    try {
      // Delete the booking to free up the timeslot
      await _supabase.from('bookings').delete().eq('id', bookingId);

      print('✅ Booking $bookingId rejected and deleted successfully (timeslot freed)');
      return true;
    } catch (e) {
      print('❌ Error rejecting booking: $e');
      return false;
    }
  }

  /// Block a user from booking at this field
  Future<bool> blockUser({
    required String fieldId,
    required String userId,
    String? userName,
  }) async {
    try {
      // Get current field data
      final field = await _supabaseService.getFootballFieldById(fieldId);
      if (field == null) {
        print('❌ Field not found: $fieldId');
        return false;
      }

      // Check if user is already blocked
      if (field.blockedUsers.contains(userId)) {
        print('⚠️ User $userId is already blocked');
        return true;
      }

      // Add user to blocked list
      final updatedBlockedUsers = [...field.blockedUsers, userId];
      
      // Update field in database - use snake_case for Supabase column name
      await _supabase.from('football_fields').update({
        'blocked_users': updatedBlockedUsers,
      }).eq('id', fieldId);

      print('✅ User $userId blocked from field $fieldId');
      return true;
    } catch (e) {
      print('❌ Error blocking user: $e');
      return false;
    }
  }

  /// Unblock a user from booking at this field
  Future<bool> unblockUser({
    required String fieldId,
    required String userId,
  }) async {
    try {
      // Get current field data
      final field = await _supabaseService.getFootballFieldById(fieldId);
      if (field == null) {
        print('❌ Field not found: $fieldId');
        return false;
      }

      // Remove user from blocked list
      final updatedBlockedUsers = field.blockedUsers.where((id) => id != userId).toList();
      
      // Update field in database - use snake_case for Supabase column name
      await _supabase.from('football_fields').update({
        'blocked_users': updatedBlockedUsers,
      }).eq('id', fieldId);

      print('✅ User $userId unblocked from field $fieldId');
      return true;
    } catch (e) {
      print('❌ Error unblocking user: $e');
      return false;
    }
  }

  /// Get list of blocked users with their profile info
  Future<List<Map<String, dynamic>>> getBlockedUsers(String fieldId) async {
    try {
      // Get field data
      final field = await _supabaseService.getFootballFieldById(fieldId);
      if (field == null || field.blockedUsers.isEmpty) {
        return [];
      }

      // Fetch user profiles for blocked users
      final profiles = await _supabase
          .from('player_profiles')
          .select('id, name, phone_number, photo_url')
          .inFilter('id', field.blockedUsers);

      return List<Map<String, dynamic>>.from(profiles);
    } catch (e) {
      print('❌ Error getting blocked users: $e');
      return [];
    }
  }

  /// Check if a user is blocked from a field
  Future<bool> isUserBlocked(String fieldId, String userId) async {
    try {
      final field = await _supabaseService.getFootballFieldById(fieldId);
      if (field == null) return false;
      return field.blockedUsers.contains(userId);
    } catch (e) {
      print('❌ Error checking if user is blocked: $e');
      return false;
    }
  }

  /// Reject booking and optionally block the user
  Future<Map<String, bool>> rejectBookingAndBlockUser({
    required String bookingId,
    required String fieldId,
    required String userId,
    String? rejectionReason,
    bool blockUser = false,
  }) async {
    final results = <String, bool>{
      'rejected': false,
      'blocked': false,
    };

    // Reject the booking
    results['rejected'] = await rejectBooking(
      bookingId: bookingId,
      fieldId: fieldId,
      rejectionReason: rejectionReason,
    );

    // Block the user if requested
    if (blockUser && userId.isNotEmpty) {
      results['blocked'] = await this.blockUser(
        fieldId: fieldId,
        userId: userId,
      );
    }

    return results;
  }
}
