import 'dart:async';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:playmakerappstart/models/booking_model.dart';
import 'package:playmakerappstart/models/footballfield_model.dart';
import 'package:playmakerappstart/models/squad.dart';
import 'package:playmakerappstart/models/user_model.dart';

class PaginatedFootballFieldsResult {
  final List<FootballField> fields;
  final int? lastIndex;

  PaginatedFootballFieldsResult({required this.fields, this.lastIndex});
}

class SupabaseService {
  // Get Supabase client instance
  final SupabaseClient _supabase = Supabase.instance.client;

  // ===================================
  // ROBUST STREAM HELPER
  // ===================================

  /// Creates a robust stream that automatically handles errors and reconnects.
  /// This prevents RealtimeSubscribeException from crashing the app.
  /// 
  /// [streamFactory] - A function that creates the stream
  /// [maxRetries] - Maximum number of reconnection attempts (default: 5)
  /// [initialDelay] - Initial delay before retry in milliseconds (default: 1000)
  /// [maxDelay] - Maximum delay between retries in milliseconds (default: 30000)
  Stream<T> _createRobustStream<T>({
    required Stream<T> Function() streamFactory,
    int maxRetries = 5,
    int initialDelay = 1000,
    int maxDelay = 30000,
  }) {
    late StreamController<T> controller;
    StreamSubscription<T>? subscription;
    int retryCount = 0;
    Timer? retryTimer;
    bool isControllerClosed = false;

    void subscribe() {
      if (isControllerClosed) return;
      
      subscription?.cancel();
      subscription = streamFactory().listen(
        (data) {
          if (!isControllerClosed) {
            retryCount = 0; // Reset retry count on successful data
            controller.add(data);
          }
        },
        onError: (error, stackTrace) {
          print('⚠️ Realtime stream error: $error');
          
          if (isControllerClosed) return;
          
          // Check if it's a RealtimeSubscribeException or channel error
          final errorString = error.toString().toLowerCase();
          final isChannelError = errorString.contains('realtimesubscribe') ||
              errorString.contains('channel') ||
              errorString.contains('timeout') ||
              errorString.contains('connection');
          
          if (isChannelError && retryCount < maxRetries) {
            retryCount++;
            // Exponential backoff with jitter
            final delay = (initialDelay * (1 << (retryCount - 1)))
                .clamp(initialDelay, maxDelay);
            final jitter = (delay * 0.1 * (DateTime.now().millisecondsSinceEpoch % 10) / 10).toInt();
            final totalDelay = delay + jitter;
            
            print('🔄 Attempting to reconnect stream (attempt $retryCount/$maxRetries) in ${totalDelay}ms...');
            
            retryTimer?.cancel();
            retryTimer = Timer(Duration(milliseconds: totalDelay), () {
              if (!isControllerClosed) {
                subscribe();
              }
            });
          } else if (!isControllerClosed) {
            // Pass through non-recoverable errors or max retries exceeded
            print('❌ Stream error - max retries exceeded or non-recoverable error');
            controller.addError(error, stackTrace);
          }
        },
        onDone: () {
          if (!isControllerClosed) {
            // If the stream completes unexpectedly, try to reconnect
            if (retryCount < maxRetries) {
              retryCount++;
              final delay = (initialDelay * (1 << (retryCount - 1)))
                  .clamp(initialDelay, maxDelay);
              print('🔄 Stream closed unexpectedly, reconnecting in ${delay}ms...');
              
              retryTimer?.cancel();
              retryTimer = Timer(Duration(milliseconds: delay), () {
                if (!isControllerClosed) {
                  subscribe();
                }
              });
            } else {
              controller.close();
            }
          }
        },
        cancelOnError: false,
      );
    }

    controller = StreamController<T>.broadcast(
      onListen: () {
        subscribe();
      },
      onCancel: () {
        isControllerClosed = true;
        retryTimer?.cancel();
        subscription?.cancel();
      },
    );

    return controller.stream;
  }

  // ===================================
  // USER PROFILE METHODS
  // ===================================

  /// Upload profile image to Supabase Storage and return URL
  Future<String?> uploadImageAndGetURL(String userId, File imageFile) async {
    try {
      print('📤 Uploading profile picture for user: $userId');
      
      // Get file extension
      final fileExtension = imageFile.path.split('.').last.toLowerCase();
      final fileName = '$userId.$fileExtension';
      final filePath = 'profile-pictures/$fileName';
      
      print('   File path: $filePath');
      
      // Read file as bytes
      final fileBytes = await imageFile.readAsBytes();
      
      // Upload to Supabase Storage
      // Use upsert to replace if exists
      await _supabase.storage
          .from('profile-pictures')
          .uploadBinary(
            filePath,
            fileBytes,
            fileOptions: FileOptions(
              contentType: 'image/$fileExtension',
              upsert: true, // Replace if exists
            ),
          );
      
      // Get public URL
      final publicUrl = _supabase.storage
          .from('profile-pictures')
          .getPublicUrl(filePath);
      
      print('✅ Profile picture uploaded successfully');
      print('   URL: $publicUrl');
      
      return publicUrl;
    } catch (e) {
      print("❌ Error uploading image to Supabase Storage: $e");
      return null;
    }
  }

  /// Update user FCM token
  Future<void> updateUserFcmToken(String uid, String token) async {
    try {
      await _supabase
          .from('player_profiles')
          .update({'fcm_token': token})
          .eq('id', uid);
    } catch (e) {
      print("Error updating FCM token: $e");
    }
  }

  /// Create a new user profile
  /// Returns true if a new profile was successfully created
  Future<bool> createUserProfile(Map<String, dynamic> userProfile) async {
    try {
      // First check if user already exists to prevent duplicate notifications
      final existing = await _supabase
          .from('player_profiles')
          .select('id')
          .eq('id', userProfile['id'])
          .maybeSingle();

      if (existing != null) {
        // User already exists, don't create or send notification
        print('User profile already exists for ${userProfile['id']}');
        return false;
      }

      await _supabase.from('player_profiles').insert(_convertToSnakeCase(userProfile));
      
      // Send admin notification for new user signup
      _sendNewUserNotification(userProfile);
      return true;
    } catch (e) {
      print("Error creating user profile: $e");
      return false;
    }
  }
  
  /// Send admin notification for new user signup (async, non-blocking)
  void _sendNewUserNotification(Map<String, dynamic> userProfile) async {
    try {
      print('📲 Sending admin notification for new user signup...');
      await _supabase.functions.invoke(
        'send-admin-notification',
        body: {
          'type': 'new_user',
          'user_id': userProfile['id'],
          'user_name': userProfile['name'] ?? 'Unknown',
          'user_email': userProfile['email'] ?? 'Unknown',
          'title': '👤 New User Signed Up!',
          'body': '${userProfile['name'] ?? 'A new user'} just joined Playmaker',
        },
      );
      print('✅ Admin new user notification sent');
    } catch (e) {
      print('⚠️ Failed to send admin new user notification: $e');
    }
  }

  /// Delete user profile and all related data
  /// Completely removes the user from both database and Supabase Auth
  Future<void> deleteUserProfile() async {
    // Get current user from Supabase
    final supabaseUser = _supabase.auth.currentUser;
    if (supabaseUser == null) throw Exception('No authenticated user');

    final userId = supabaseUser.id;
    final userEmail = supabaseUser.email;

    try {
      print('🗑️ Starting complete account deletion for user: $userId');
      print('   Email: $userEmail');
      
      // Step 1: Delete user's profile picture from Supabase Storage (if exists)
      try {
        // Try to delete all possible image formats
        final extensions = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
        for (final ext in extensions) {
          try {
            final filePath = 'profile-pictures/$userId.$ext';
            await _supabase.storage.from('profile-pictures').remove([filePath]);
            print('✅ Profile picture deleted: $filePath');
          } catch (e) {
            // File doesn't exist with this extension, continue
          }
        }
      } catch (storageError) {
        print('⚠️ No profile picture to delete: $storageError');
      }

      // Step 2: Delete ALL profile data for this email from Supabase database
      // This ensures we delete any orphaned profiles with the same email but different IDs
      // (CASCADE constraints will delete related bookings, squads, etc.)
      print('🗄️ Deleting ALL profiles for email: $userEmail');
      if (userEmail != null && userEmail.isNotEmpty) {
        await _supabase
            .from('player_profiles')
            .delete()
            .eq('email', userEmail);
        print('✅ All profiles for email deleted from database');
      } else {
        // Fallback to deleting by ID if email is not available
        await _supabase
            .from('player_profiles')
            .delete()
            .eq('id', userId);
        print('✅ Profile deleted by ID from database');
      }

      // Step 3: Call Edge Function to delete user from Supabase Auth
      // This uses admin privileges server-side
      print('🔐 Requesting auth account deletion...');
      final session = _supabase.auth.currentSession;
      if (session == null) throw Exception('No active session');

      final response = await _supabase.functions.invoke(
        'delete-user',
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
        },
      );

      if (response.status != 200) {
        final errorData = response.data;
        throw Exception('Failed to delete auth account: ${errorData['error'] ?? 'Unknown error'}');
      }

      print('✅ Auth account deleted successfully');

      // Step 4: Sign out from Supabase
      print('👋 Signing out...');
      await _supabase.auth.signOut();
      
      // Step 5: Sign out from Firebase Auth if user exists there
      try {
        final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
        if (firebaseUser != null) {
          await firebase_auth.FirebaseAuth.instance.signOut();
          print('✅ Signed out from Firebase Auth');
        }
      } catch (e) {
        print('⚠️ Firebase Auth sign out: $e');
      }

      print('🎉 Account completely deleted! User can now create a new account.');
    } catch (e) {
      print('❌ Error during account deletion: $e');
      throw Exception('Failed to delete account: $e');
    }
  }

  /// Get a booking by ID
  Future<Booking?> getBookingById(String bookingId) async {
    try {
      final response = await _supabase
          .from('bookings')
          .select()
          .eq('id', bookingId)
          .single();
      
      return Booking.fromMap(response);
    } catch (e) {
      print('Error getting booking by ID: $e');
      return null;
    }
  }

  /// Update user profile picture
  Future<void> updateUserProfilePicture(String userId, File imageFile) async {
    String? imageUrl = await uploadImageAndGetURL(userId, imageFile);
    if (imageUrl != null) {
      await _supabase
          .from('player_profiles')
          .update({'profile_picture': imageUrl})
          .eq('id', userId);
    }
  }

  /// Store/update user data
  Future<void> storeUserData(PlayerProfile user) async {
    print('🔵 SupabaseService.storeUserData: Starting...');
    print('   User ID: ${user.id}');
    print('   User Email: ${user.email}');
    print('   User Name: ${user.name}');
    
    try {
      final userData = _convertToSnakeCase(user.toMap());
      
      // DEBUG: Check if user_id is in the data
      print('   🔍 DEBUG: Keys in userData: ${userData.keys.toList()}');
      if (userData.containsKey('user_id')) {
        print('   ⚠️ WARNING: user_id found in userData! Value: ${userData['user_id']}');
        // Remove it to avoid UUID casting error
        userData.remove('user_id');
        print('   ✅ Removed user_id from userData');
      }
      
      print('   Converted to snake_case, upserting to player_profiles table...');
      
      await _supabase
          .from('player_profiles')
          .upsert(userData);
      
      print('✅ SupabaseService.storeUserData: SUCCESS! Profile saved for ${user.email}');
    } catch (e) {
      print("❌ SupabaseService.storeUserData: FAILED!");
      print("   Error: $e");
      print("   User Email: ${user.email}");
      print("   User ID: ${user.id}");
      rethrow; // Re-throw so caller can handle
    }
  }

  /// Send join request for a booking
  Future<void> sendJoinRequest(String bookingId, String encodedRequest) async {
    try {
      final response = await _supabase
          .from('bookings')
          .select('open_joining_requests')
          .eq('id', bookingId)
          .single();

      final List<String> currentRequests = 
          List<String>.from(response['open_joining_requests'] ?? []);
      final List<String> updatedRequests = [...currentRequests, encodedRequest];

      await updateBookingJoinRequests(bookingId, updatedRequests);
    } catch (e) {
      throw Exception('Failed to send join request: $e');
    }
  }

  /// Update a specific field for a user
  Future<void> updateUserField(String userId, String field, dynamic value) async {
    try {
      final snakeCaseField = _toSnakeCase(field);
      await _supabase
          .from('player_profiles')
          .update({snakeCaseField: value})
          .eq('id', userId);
    } catch (e) {
      throw Exception('Failed to update user field: $e');
    }
  }

  /// Get user model by ID
  Future<PlayerProfile?> getUserModel(String userId) async {
    try {
      final response = await _supabase
          .from('player_profiles')
          .select()
          .eq('id', userId)
          .single();

      return PlayerProfile.fromMap(_convertToCamelCase(response));
    } catch (e) {
      print('Error getting user model: $e');
      return null;
    }
  }

  /// Get user profile by ID (alias for getUserModel)
  Future<PlayerProfile?> getUserProfileById(String userId) async {
    return getUserModel(userId);
  }

  /// Get user profile by email
  Future<PlayerProfile?> getUserProfileByEmail(String email) async {
    try {
      final response = await _supabase
          .from('player_profiles')
          .select()
          .eq('email', email)
          .maybeSingle();

      if (response == null) return null;
      return PlayerProfile.fromMap(_convertToCamelCase(response));
    } catch (e) {
      print('Error getting user by email: $e');
      return null;
    }
  }

  /// Get player profile by player ID (5-digit ID)
  Future<PlayerProfile?> getPlayerProfile(String playerId) async {
    try {
      final response = await _supabase
          .from('player_profiles')
          .select()
          .eq('player_id', playerId)
          .maybeSingle();

      if (response == null) return null;
      return PlayerProfile.fromMap(_convertToCamelCase(response));
    } catch (e) {
      print('Error getting player profile: $e');
      return null;
    }
  }

  /// Get or create user profile
  Future<PlayerProfile> getOrCreateUserProfile(
      String email, String userId, String name) async {
    try {
      final existingUser = await getUserModel(userId);
      if (existingUser != null) {
        return existingUser;
      }

      // Create new profile
      final newProfile = PlayerProfile(
        id: userId,
        email: email,
        name: name,
        nationality: '',
        age: '',
        preferredPosition: '',
      );

      await storeUserData(newProfile);
      return newProfile;
    } catch (e) {
      throw Exception('Error getting or creating user profile: $e');
    }
  }

  // ===================================
  // BOOKING METHODS
  // ===================================

  /// Create a new booking
  Future<void> createBooking(Booking booking) async {
    try {
      // Check if user is blocked from this field
      final isBlocked = await isUserBlockedFromField(
        booking.footballFieldId, 
        booking.userId,
      );
      if (isBlocked) {
        throw Exception('You are blocked from booking at this field. Please contact the field owner.');
      }
      
      final bookingData = _convertToSnakeCase(booking.toMap());
      // Keep the id from the booking object (it's already a UUID)
      await _supabase.from('bookings').insert(bookingData);
      
      // Send admin notification for new booking
      _sendBookingNotification(booking);
    } catch (e) {
      print("Error creating booking: $e");
      throw Exception('Failed to create booking: $e');
    }
  }
  
  /// Check if a user is blocked from booking at a field
  Future<bool> isUserBlockedFromField(String fieldId, String userId) async {
    try {
      final response = await _supabase
          .from('football_fields')
          .select('blockedUsers')
          .eq('id', fieldId)
          .maybeSingle();
      
      if (response == null) return false;
      
      final blockedUsers = List<String>.from(response['blockedUsers'] ?? []);
      return blockedUsers.contains(userId);
    } catch (e) {
      print('Error checking if user is blocked: $e');
      return false;
    }
  }
  
  /// Send admin notification for new booking (async, non-blocking)
  void _sendBookingNotification(Booking booking) async {
    try {
      print('📲 Sending admin notification for new booking...');
      await _supabase.functions.invoke(
        'send-booking-notification',
        body: {
          'booking_id': booking.id,
          'field_name': booking.footballFieldName,
          'location': booking.locationName,
          'date': booking.date,
          'time_slot': booking.timeSlot,
          'price': booking.price,
          'user_id': booking.userId,
        },
      );
      print('✅ Admin booking notification sent');
    } catch (e) {
      print('⚠️ Failed to send admin booking notification: $e');
    }
    
    // Also send notification to partner (field owner)
    try {
      print('📲 Sending partner notification for new booking...');
      await _supabase.functions.invoke(
        'send-partner-notification',
        body: {
          'type': 'new_booking',
          'field_id': booking.footballFieldId,
          'title': '⚽ New Booking!',
          'body': 'New booking for ${booking.date} at ${booking.timeSlot} - ${booking.price} EGP',
          'data': {
            'date': booking.date,
            'time_slot': booking.timeSlot,
            'price': booking.price.toString(),
          },
        },
      );
      print('✅ Partner booking notification sent');
    } catch (e) {
      print('⚠️ Failed to send partner booking notification: $e');
    }
  }

  /// Create a camera recording schedule for a booking
  /// Returns the schedule ID if successful
  Future<String?> createCameraRecordingSchedule({
    required String bookingId,
    required String fieldId,
    required DateTime startTime,
    required DateTime endTime,
    bool enableBallTracking = true,
  }) async {
    try {
      final durationMinutes = endTime.difference(startTime).inMinutes;
      
      if (durationMinutes <= 0) {
        print('⚠️ Invalid duration for recording schedule');
        return null;
      }
      
      final scheduleId = const Uuid().v4();
      
      await _supabase.from('camera_recording_schedules').insert({
        'id': scheduleId,
        'field_id': fieldId,
        'booking_id': bookingId,
        'scheduled_date': DateFormat('yyyy-MM-dd').format(startTime),
        'start_time': startTime.toUtc().toIso8601String(),
        'end_time': endTime.toUtc().toIso8601String(),
        'status': 'scheduled',
        'enable_ball_tracking': enableBallTracking,
        'total_chunks': (durationMinutes / 10).ceil().clamp(1, 100),
        'chunk_duration_minutes': 10,
      });
      
      print('✅ Camera recording schedule created: $scheduleId');
      return scheduleId;
    } catch (e) {
      print('⚠️ Failed to create camera recording schedule: $e');
      return null;
    }
  }
  
  /// Get camera recording schedule for a booking
  Future<Map<String, dynamic>?> getRecordingScheduleForBooking(String bookingId) async {
    try {
      final response = await _supabase
          .from('camera_recording_schedules')
          .select('*, camera_recording_chunks(*)')
          .eq('booking_id', bookingId)
          .maybeSingle();
      
      return response;
    } catch (e) {
      print('Error getting recording schedule: $e');
      return null;
    }
  }
  
  /// Get camera recording schedule by ID
  Future<Map<String, dynamic>?> getRecordingScheduleById(String scheduleId) async {
    try {
      final response = await _supabase
          .from('camera_recording_schedules')
          .select('*, camera_recording_chunks(*)')
          .eq('id', scheduleId)
          .maybeSingle();
      
      return response;
    } catch (e) {
      print('Error getting recording schedule by ID: $e');
      return null;
    }
  }
  
  /// Get camera recording schedule by field ID and time match
  Future<Map<String, dynamic>?> getRecordingScheduleByFieldAndTime(
    String fieldId,
    String date,
    String timeSlot,
  ) async {
    try {
      // Parse the time slot to get start time
      final times = timeSlot.split('-');
      if (times.length != 2) return null;
      
      final startTime = times[0].trim();
      final dateParts = date.split('-');
      if (dateParts.length != 3) return null;
      
      // Construct the datetime string to search for
      final searchDate = date; // yyyy-MM-dd format
      
      // Query by field_id and scheduled_date, then filter by time
      final response = await _supabase
          .from('camera_recording_schedules')
          .select('*, camera_recording_chunks(*)')
          .eq('field_id', fieldId)
          .eq('scheduled_date', searchDate)
          .order('created_at', ascending: false)
          .limit(5);
      
      if ((response as List).isEmpty) return null;
      
      // Find the schedule that matches the time slot
      for (final schedule in response) {
        final scheduleStartTime = schedule['start_time'];
        if (scheduleStartTime != null) {
          try {
            final scheduleDateTime = DateTime.parse(scheduleStartTime).toLocal();
            final scheduleTimeStr = '${scheduleDateTime.hour.toString().padLeft(2, '0')}:${scheduleDateTime.minute.toString().padLeft(2, '0')}';
            
            if (scheduleTimeStr == startTime) {
              return schedule;
            }
          } catch (e) {
            // Continue to next schedule
          }
        }
      }
      
      // If no exact match, return the most recent one for the field/date
      return response.first;
    } catch (e) {
      print('Error getting recording schedule by field and time: $e');
      return null;
    }
  }
  
  /// Stream recording schedule status for real-time updates
  Stream<Map<String, dynamic>?> streamRecordingSchedule(String scheduleId) {
    return _supabase
        .from('camera_recording_schedules')
        .stream(primaryKey: ['id'])
        .eq('id', scheduleId)
        .map((data) => data.isNotEmpty ? data.first : null);
  }

  /// Update booking with recording schedule ID
  Future<void> updateBookingRecordingScheduleId({
    required String bookingId,
    required String recordingScheduleId,
  }) async {
    try {
      await _supabase
          .from('bookings')
          .update({'recording_schedule_id': recordingScheduleId})
          .eq('id', bookingId);
    } catch (e) {
      print('⚠️ Failed to update booking with recording schedule ID: $e');
    }
  }

  /// Update camera recording schedule status
  Future<void> updateCameraRecordingScheduleStatus(
    String scheduleId,
    String status,
  ) async {
    try {
      await _supabase
          .from('camera_recording_schedules')
          .update({'status': status})
          .eq('id', scheduleId);
      print('✅ Updated camera recording schedule status to: $status');
    } catch (e) {
      print('⚠️ Failed to update camera recording schedule status: $e');
      rethrow;
    }
  }

  /// Update booking join requests
  Future<void> updateBookingJoinRequests(
      String bookingId, List<String> requests) async {
    try {
      await _supabase
          .from('bookings')
          .update({'open_joining_requests': requests})
          .eq('id', bookingId);
    } catch (e) {
      throw Exception('Failed to update booking join requests: $e');
    }
  }

  /// Get bookings for a user (excludes cancelled bookings)
  Future<List<Booking>> getUserBookings(String userId) async {
    try {
      final response = await _supabase
          .from('bookings')
          .select()
          .eq('user_id', userId)
          .neq('status', 'cancelled')
          .neq('status', 'rejected')
          .order('date', ascending: false);

      return (response as List)
          .map((booking) => Booking.fromMap(_convertToCamelCase(booking)))
          .toList();
    } catch (e) {
      print('Error getting user bookings: $e');
      return [];
    }
  }

  /// Update booking
  Future<void> updateBooking(String bookingId, Map<String, dynamic> updates) async {
    try {
      await _supabase
          .from('bookings')
          .update(_convertToSnakeCase(updates))
          .eq('id', bookingId);
    } catch (e) {
      throw Exception('Failed to update booking: $e');
    }
  }

  /// Delete booking
  Future<void> deleteBooking(String bookingId) async {
    try {
      await _supabase
          .from('bookings')
          .delete()
          .eq('id', bookingId);
    } catch (e) {
      throw Exception('Failed to delete booking: $e');
    }
  }

  /// Get open bookings by date (excludes cancelled bookings)
  Future<List<Booking>> getOpenBookingsByDate(String date) async {
    try {
      final response = await _supabase
          .from('bookings')
          .select()
          .eq('date', date)
          .eq('is_open_match', true)
          .neq('status', 'cancelled')
          .neq('status', 'rejected');

      return (response as List)
          .map((booking) => Booking.fromMap(_convertToCamelCase(booking)))
          .toList();
    } catch (e) {
      print('Error getting open bookings by date: $e');
      return [];
    }
  }

  /// Update booking players list
  Future<void> updateBookingPlayers(String bookingId, List<String> players) async {
    try {
      await _supabase
          .from('bookings')
          .update({'invite_players': players})
          .eq('id', bookingId);
    } catch (e) {
      throw Exception('Failed to update booking players: $e');
    }
  }

  /// Add players to booking (array union operation)
  Future<void> addPlayersToBooking(String bookingId, List<String> playerIds) async {
    try {
      final booking = await getBookingById(bookingId);
      if (booking == null) throw Exception('Booking not found');
      
      final currentPlayers = List<String>.from(booking.invitePlayers);
      final uniquePlayers = {...currentPlayers, ...playerIds}.toList();
      
      await updateBookingPlayers(bookingId, uniquePlayers);
    } catch (e) {
      throw Exception('Failed to add players to booking: $e');
    }
  }

  // ===================================
  // SQUAD/TEAM METHODS
  // ===================================

  /// Create a new squad
  Future<String> createSquad(Squad squad) async {
    try {
      final squadData = _convertToSnakeCase(squad.toMap());
      squadData.remove('id'); // Let Supabase generate UUID
      
      final response = await _supabase
          .from('playmaker_squads')
          .insert(squadData)
          .select('id')
          .single();

      return response['id'];
    } catch (e) {
      throw Exception('Failed to create squad: $e');
    }
  }

  /// Get squad by ID
  Future<Squad?> getSquadById(String squadId) async {
    try {
      final response = await _supabase
          .from('playmaker_squads')
          .select()
          .eq('id', squadId)
          .single();

      return Squad.fromMap(_convertToCamelCase(response), response['id']);
    } catch (e) {
      print('Error getting squad: $e');
      return null;
    }
  }

  /// Get squads for a user
  Future<List<Squad>> getUserSquads(String userId) async {
    try {
      final response = await _supabase
          .from('playmaker_squads')
          .select()
          .contains('squad_members', [userId]);

      return (response as List)
          .map((squad) => Squad.fromMap(_convertToCamelCase(squad), squad['id']))
          .toList();
    } catch (e) {
      print('Error getting user squads: $e');
      return [];
    }
  }

  /// Update squad
  Future<void> updateSquad(String squadId, Map<String, dynamic> updates) async {
    try {
      await _supabase
          .from('playmaker_squads')
          .update(_convertToSnakeCase(updates))
          .eq('id', squadId);
    } catch (e) {
      throw Exception('Failed to update squad: $e');
    }
  }

  /// Add player to squad
  Future<void> addPlayerToSquad(String squadId, String playerId) async {
    try {
      final squad = await getSquadById(squadId);
      if (squad == null) throw Exception('Squad not found');

      final updatedMembers = [...squad.squadMembers, playerId];
      await updateSquad(squadId, {'squadMembers': updatedMembers});
    } catch (e) {
      throw Exception('Failed to add player to squad: $e');
    }
  }

  /// Remove player from squad
  Future<void> removePlayerFromSquad(String squadId, String playerId) async {
    try {
      final squad = await getSquadById(squadId);
      if (squad == null) throw Exception('Squad not found');

      final updatedMembers = squad.squadMembers.where((id) => id != playerId).toList();
      await updateSquad(squadId, {'squadMembers': updatedMembers});
    } catch (e) {
      throw Exception('Failed to remove player from squad: $e');
    }
  }

  /// Accept squad join request
  Future<void> acceptSquadJoinRequest(String squadId, String playerId) async {
    try {
      final squad = await getSquadById(squadId);
      if (squad == null) throw Exception('Squad not found');

      // Remove from pending requests
      final updatedPending = squad.pendingRequests.where((id) => id != playerId).toList();
      
      // Add to squad members if not already there
      final updatedMembers = squad.squadMembers.contains(playerId)
          ? squad.squadMembers
          : [...squad.squadMembers, playerId];

      await updateSquad(squadId, {
        'pendingRequests': updatedPending,
        'squadMembers': updatedMembers,
      });

      // Update player's teams joined
      final player = await getUserModel(playerId);
      if (player != null) {
        final updatedTeams = player.teamsJoined.contains(squadId)
            ? player.teamsJoined
            : [...player.teamsJoined, squadId];
        await updateUserField(playerId, 'teamsJoined', updatedTeams);
      }
    } catch (e) {
      throw Exception('Failed to accept squad join request: $e');
    }
  }

  /// Decline squad join request
  Future<void> declineSquadJoinRequest(String squadId, String playerId) async {
    try {
      final squad = await getSquadById(squadId);
      if (squad == null) throw Exception('Squad not found');

      // Remove from pending requests
      final updatedPending = squad.pendingRequests.where((id) => id != playerId).toList();

      await updateSquad(squadId, {
        'pendingRequests': updatedPending,
      });
    } catch (e) {
      throw Exception('Failed to decline squad join request: $e');
    }
  }

  /// Request to join squad
  Future<void> requestToJoinSquad(String squadId, String playerId) async {
    try {
      final squad = await getSquadById(squadId);
      if (squad == null) throw Exception('Squad not found');

      if (squad.pendingRequests.contains(playerId)) {
        throw Exception('Request already sent');
      }

      final updatedPending = [...squad.pendingRequests, playerId];
      await updateSquad(squadId, {
        'pendingRequests': updatedPending,
      });
    } catch (e) {
      throw Exception('Failed to send join request: $e');
    }
  }

  /// Update squad captain
  Future<void> updateSquadCaptain(String squadId, String newCaptainId) async {
    try {
      await updateSquad(squadId, {'captain': newCaptainId});
    } catch (e) {
      throw Exception('Failed to update squad captain: $e');
    }
  }

  /// Update squad joinable status
  Future<void> updateSquadJoinableStatus(String squadId, bool joinable) async {
    try {
      await updateSquad(squadId, {'joinable': joinable});
    } catch (e) {
      throw Exception('Failed to update squad joinable status: $e');
    }
  }

  /// Leave squad (alias for removePlayerFromSquad)
  Future<void> leaveSquad(String squadId, String playerId) async {
    try {
      await removePlayerFromSquad(squadId, playerId);
      
      // Also remove squad from player's teams joined
      final player = await getUserModel(playerId);
      if (player != null) {
        final updatedTeams = player.teamsJoined.where((id) => id != squadId).toList();
        await updateUserField(playerId, 'teamsJoined', updatedTeams);
      }
    } catch (e) {
      throw Exception('Failed to leave squad: $e');
    }
  }

  /// Delete squad
  Future<void> deleteSquad(String squadId) async {
    try {
      await _supabase
          .from('playmaker_squads')
          .delete()
          .eq('id', squadId);
    } catch (e) {
      throw Exception('Failed to delete squad: $e');
    }
  }

  /// Add squad (alias for createSquad)
  Future<String> addSquad(Squad squad, String userId) async {
    return createSquad(squad);
  }

  /// Fetch squads (alias for getUserSquads)
  Future<List<Squad>> fetchSquads(String userId) async {
    return getUserSquads(userId);
  }

  /// Get all joinable squads (for browsing/joining)
  Future<List<Squad>> getAllJoinableSquads() async {
    try {
      final response = await _supabase
          .from('playmaker_squads')
          .select()
          .eq('joinable', true);

      return (response as List)
          .map((squad) => Squad.fromMap(_convertToCamelCase(squad), squad['id']))
          .toList();
    } catch (e) {
      print('Error getting joinable squads: $e');
      return [];
    }
  }

  // ===================================
  // FRIEND MANAGEMENT METHODS
  // ===================================

  /// Send friend request
  Future<void> sendFriendRequest(String senderId, String receiverId) async {
    try {
      await _supabase.from('friend_requests').insert({
        'sender_id': senderId,
        'receiver_id': receiverId,
        'status': 'pending',
      });
    } catch (e) {
      throw Exception('Failed to send friend request: $e');
    }
  }

  /// Accept friend request
  Future<void> acceptFriendRequest(String receiverId, String senderId) async {
    try {
      // Update friend request status
      await _supabase
          .from('friend_requests')
          .update({'status': 'accepted'})
          .eq('sender_id', senderId)
          .eq('receiver_id', receiverId);

      // Add to both users' friends lists
      final receiverProfile = await getUserModel(receiverId);
      final senderProfile = await getUserModel(senderId);

      if (receiverProfile != null && senderProfile != null) {
        final receiverFriends = [...receiverProfile.friends, senderId];
        final senderFriends = [...senderProfile.friends, receiverId];

        await _supabase
            .from('player_profiles')
            .update({'friends': receiverFriends})
            .eq('id', receiverId);

        await _supabase
            .from('player_profiles')
            .update({'friends': senderFriends})
            .eq('id', senderId);
      }
    } catch (e) {
      throw Exception('Failed to accept friend request: $e');
    }
  }

  /// Decline friend request
  Future<void> declineFriendRequest(String receiverId, String senderId) async {
    try {
      await _supabase
          .from('friend_requests')
          .delete()
          .eq('sender_id', senderId)
          .eq('receiver_id', receiverId);
    } catch (e) {
      throw Exception('Failed to decline friend request: $e');
    }
  }

  /// Delete friend
  Future<void> deleteFriend(String userId, String friendId) async {
    try {
      final userProfile = await getUserModel(userId);
      final friendProfile = await getUserModel(friendId);

      if (userProfile != null && friendProfile != null) {
        final userFriends = userProfile.friends.where((id) => id != friendId).toList();
        final friendFriends = friendProfile.friends.where((id) => id != userId).toList();

        await _supabase
            .from('player_profiles')
            .update({'friends': userFriends})
            .eq('id', userId);

        await _supabase
            .from('player_profiles')
            .update({'friends': friendFriends})
            .eq('id', friendId);
      }
    } catch (e) {
      throw Exception('Failed to delete friend: $e');
    }
  }

  /// Fetch player profile by player ID (7-digit ID)
  Future<PlayerProfile?> fetchPlayerProfileByPlayerID(String playerId) async {
    try {
      final response = await _supabase
          .from('player_profiles')
          .select()
          .eq('player_id', playerId)
          .maybeSingle();

      if (response == null) return null;
      return PlayerProfile.fromMap(_convertToCamelCase(response));
    } catch (e) {
      print('Error fetching player by player ID: $e');
      return null;
    }
  }

  // ===================================
  // FOOTBALL FIELD METHODS
  // ===================================

  /// Get paginated football fields
  /// Set [includeDisabled] to true to include disabled fields (for admin app)
  Future<PaginatedFootballFieldsResult> getFootballFields({
    int limit = 20,
    int? startIndex,
    String? locationName,
    bool includeDisabled = false,
  }) async {
    try {
      dynamic query = _supabase
          .from('football_fields')
          .select();

      if (locationName != null && locationName.isNotEmpty) {
        query = query.eq('location_name', locationName);
      }
      
      // Filter out disabled fields unless explicitly requested
      if (!includeDisabled) {
        query = query.neq('is_enabled', false);
        query = query.eq('bookable', true);
      }

      query = query.order('created_at', ascending: false);

      if (startIndex != null) {
        query = query.range(startIndex, startIndex + limit - 1);
      } else {
        query = query.limit(limit);
      }

      final response = await query;

      final fields = (response as List)
          .map((field) => FootballField.fromMap(_convertToCamelCase(field)))
          .toList();

      final newIndex = startIndex != null ? startIndex + fields.length : fields.length;

      return PaginatedFootballFieldsResult(
        fields: fields,
        lastIndex: fields.length < limit ? null : newIndex,
      );
    } catch (e) {
      print("Error fetching football fields: $e");
      return PaginatedFootballFieldsResult(fields: [], lastIndex: null);
    }
  }

  /// Get paginated football fields with offset-based pagination
  /// Set [includeDisabled] to true to include disabled fields (for admin app)
  Future<List<FootballField>> getFootballFieldsPaginated({
    int limit = 20,
    int offset = 0,
    String? locationName,
    bool includeDisabled = false,
  }) async {
    try {
      dynamic query = _supabase
          .from('football_fields')
          .select();

      if (locationName != null && locationName.isNotEmpty) {
        query = query.eq('location_name', locationName);
      }
      
      // Filter out disabled fields unless explicitly requested
      if (!includeDisabled) {
        query = query.neq('is_enabled', false);
        query = query.eq('bookable', true);
      }

      query = query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final response = await query;

      // Debug logging for first field
      if (response is List && response.isNotEmpty) {
        final firstField = response.first;
        print('DEBUG PAGINATED: First field available_time_slots type: ${firstField['available_time_slots']?.runtimeType}');
        print('DEBUG PAGINATED: First field available_time_slots keys: ${firstField['available_time_slots']?.keys}');
        print('DEBUG PAGINATED: First field available_time_slots sample: ${firstField['available_time_slots']?['Monday']?.take(1)}');
      }

      return (response as List)
          .map((field) => FootballField.fromMap(_convertToCamelCase(field)))
          .toList();
    } catch (e) {
      print("Error fetching football fields: $e");
      return [];
    }
  }

  /// Get football field by ID
  Future<FootballField?> getFootballFieldById(String fieldId) async {
    try {
      final response = await _supabase
          .from('football_fields')
          .select()
          .eq('id', fieldId)
          .single();

      // Debug logging for timeslots
      print('DEBUG: Raw response available_time_slots type: ${response['available_time_slots']?.runtimeType}');
      print('DEBUG: Raw response available_time_slots keys: ${response['available_time_slots']?.keys}');
      
      final convertedData = _convertToCamelCase(response);
      print('DEBUG: After camelCase conversion, availableTimeSlots type: ${convertedData['availableTimeSlots']?.runtimeType}');
      print('DEBUG: After camelCase conversion, availableTimeSlots keys: ${convertedData['availableTimeSlots']?.keys}');

      return FootballField.fromMap(convertedData);
    } catch (e) {
      print("Error fetching football field: $e");
      return null;
    }
  }

  /// Create football field
  Future<String> createFootballField(FootballField field) async {
    try {
      final fieldData = _convertToSnakeCase(field.toMap());
      fieldData.remove('id'); // Let Supabase generate UUID

      // Debug logging for timeslots
      print('DEBUG: Creating field with availableTimeSlots keys: ${field.availableTimeSlots.keys}');
      print('DEBUG: Sample Monday slots: ${field.availableTimeSlots['Monday']?.take(2)}');
      print('DEBUG: After snake_case conversion, available_time_slots keys: ${fieldData['available_time_slots']?.keys}');

      final response = await _supabase
          .from('football_fields')
          .insert(fieldData)
          .select('id')
          .single();

      return response['id'];
    } catch (e) {
      throw Exception('Failed to create football field: $e');
    }
  }

  /// Update football field
  Future<void> updateFootballField(dynamic fieldOrId, [Map<String, dynamic>? updates]) async {
    try {
      if (fieldOrId is FootballField) {
        // Update using FootballField object
        final field = fieldOrId;
        await _supabase
            .from('football_fields')
            .update(_convertToSnakeCase(field.toMap()))
            .eq('id', field.id);
      } else if (fieldOrId is String && updates != null) {
        // Update using fieldId and updates map
        await _supabase
            .from('football_fields')
            .update(_convertToSnakeCase(updates))
            .eq('id', fieldOrId);
      } else {
        throw ArgumentError('Invalid arguments. Expected FootballField or (String, Map)');
      }
    } catch (e) {
      throw Exception('Failed to update football field: $e');
    }
  }

  /// Delete football field
  Future<void> deleteFootballField(String fieldId) async {
    try {
      print('DEBUG: Attempting to delete field with ID: $fieldId');
      
      final response = await _supabase
          .from('football_fields')
          .delete()
          .eq('id', fieldId)
          .select(); // Get response to confirm deletion
      
      print('DEBUG: Delete response: $response');
      
      if (response.isEmpty) {
        print('WARNING: No data returned - field may not exist or RLS policy blocking delete');
      } else {
        print('SUCCESS: Field deleted: ${response.length} row(s) affected');
      }
    } catch (e) {
      print('ERROR: Failed to delete field: $e');
      throw Exception('Failed to delete football field: $e');
    }
  }

  // ===================================
  // FIELD CLICK TRACKING
  // ===================================

  /// Track when a user views/clicks on a football field
  /// [source] can be: 'app', 'map', 'search', 'recommendation'
  Future<void> trackFieldClick({
    required String fieldId,
    String? userId,
    String source = 'app',
  }) async {
    try {
      await _supabase.from('field_clicks').insert({
        'field_id': fieldId,
        'user_id': userId,
        'source': source,
        'clicked_at': DateTime.now().toIso8601String(),
      });
      print('📊 Field click tracked: $fieldId by ${userId ?? 'anonymous'}');
    } catch (e) {
      // Don't throw - tracking should not interrupt user experience
      print('⚠️ Failed to track field click: $e');
    }
  }

  /// Get click statistics for a specific field
  Future<Map<String, dynamic>> getFieldClickStats(String fieldId) async {
    try {
      final response = await _supabase.rpc(
        'get_field_click_stats',
        params: {'p_field_id': fieldId},
      );
      
      if (response != null && response.isNotEmpty) {
        return Map<String, dynamic>.from(response[0]);
      }
      
      return {
        'total_clicks': 0,
        'clicks_today': 0,
        'clicks_this_week': 0,
        'clicks_this_month': 0,
        'unique_users': 0,
      };
    } catch (e) {
      print('Error getting field click stats: $e');
      return {
        'total_clicks': 0,
        'clicks_today': 0,
        'clicks_this_week': 0,
        'clicks_this_month': 0,
        'unique_users': 0,
      };
    }
  }

  /// Get recent clicks for a field (for admin view)
  Future<List<Map<String, dynamic>>> getRecentFieldClicks(String fieldId, {int limit = 50}) async {
    try {
      final response = await _supabase.rpc(
        'get_recent_field_clicks',
        params: {
          'p_field_id': fieldId,
          'p_limit': limit,
        },
      );
      
      if (response != null) {
        return List<Map<String, dynamic>>.from(response);
      }
      
      return [];
    } catch (e) {
      print('Error getting recent field clicks: $e');
      return [];
    }
  }

  /// Get aggregated click stats for all fields (for admin dashboard)
  Future<List<Map<String, dynamic>>> getAllFieldsClickStats() async {
    try {
      final response = await _supabase
          .from('field_clicks')
          .select('field_id, clicked_at')
          .order('clicked_at', ascending: false);
      
      // Aggregate stats by field_id
      final Map<String, Map<String, dynamic>> statsMap = {};
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final weekStart = today.subtract(Duration(days: today.weekday - 1));
      final monthStart = DateTime(now.year, now.month, 1);
      
      for (final click in response) {
        final fieldId = click['field_id'] as String;
        final clickedAt = DateTime.parse(click['clicked_at']);
        
        if (!statsMap.containsKey(fieldId)) {
          statsMap[fieldId] = {
            'field_id': fieldId,
            'total_clicks': 0,
            'clicks_today': 0,
            'clicks_this_week': 0,
            'clicks_this_month': 0,
          };
        }
        
        statsMap[fieldId]!['total_clicks'] = (statsMap[fieldId]!['total_clicks'] as int) + 1;
        
        if (clickedAt.isAfter(today)) {
          statsMap[fieldId]!['clicks_today'] = (statsMap[fieldId]!['clicks_today'] as int) + 1;
        }
        if (clickedAt.isAfter(weekStart)) {
          statsMap[fieldId]!['clicks_this_week'] = (statsMap[fieldId]!['clicks_this_week'] as int) + 1;
        }
        if (clickedAt.isAfter(monthStart)) {
          statsMap[fieldId]!['clicks_this_month'] = (statsMap[fieldId]!['clicks_this_month'] as int) + 1;
        }
      }
      
      return statsMap.values.toList();
    } catch (e) {
      print('Error getting all fields click stats: $e');
      return [];
    }
  }

  // ===================================
  // HELPER METHODS (Case Conversion)
  // ===================================

  /// Convert camelCase keys to snake_case for Postgres
  Map<String, dynamic> _convertToSnakeCase(Map<String, dynamic> data) {
    final result = <String, dynamic>{};
    data.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        result[_toSnakeCase(key)] = _convertToSnakeCase(value);
      } else if (value is Map) {
        // Handle Map<String, dynamic> that might not be explicitly typed
        result[_toSnakeCase(key)] = _convertToSnakeCase(Map<String, dynamic>.from(value));
      } else if (value is List && value.isNotEmpty && value.first is Map) {
        result[_toSnakeCase(key)] = value.map((item) => 
            item is Map<String, dynamic> ? _convertToSnakeCase(item) : item).toList();
      } else if (value is List) {
        // Handle empty lists or lists without Maps
        result[_toSnakeCase(key)] = value;
      } else {
        result[_toSnakeCase(key)] = value;
      }
    });
    return result;
  }

  /// Convert snake_case keys to camelCase for Flutter models
  Map<String, dynamic> _convertToCamelCase(Map<String, dynamic> data) {
    final result = <String, dynamic>{};
    data.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        result[_toCamelCase(key)] = _convertToCamelCase(value);
      } else if (value is Map) {
        // Handle Map that might not be explicitly typed as Map<String, dynamic>
        result[_toCamelCase(key)] = _convertToCamelCase(Map<String, dynamic>.from(value));
      } else if (value is List && value.isNotEmpty && value.first is Map) {
        result[_toCamelCase(key)] = value.map((item) => 
            item is Map<String, dynamic> ? _convertToCamelCase(item) : item).toList();
      } else if (value is List) {
        // Handle empty lists or lists without Maps
        result[_toCamelCase(key)] = value;
      } else {
        result[_toCamelCase(key)] = value;
      }
    });
    return result;
  }

  /// Convert string to snake_case
  String _toSnakeCase(String str) {
    return str
        .replaceAllMapped(RegExp(r'[A-Z]'), (match) => '_${match.group(0)!.toLowerCase()}')
        .replaceFirst(RegExp(r'^_'), '');
  }

  /// Convert string to camelCase
  String _toCamelCase(String str) {
    final parts = str.split('_');
    if (parts.length == 1) return parts[0];
    return parts[0] + parts.skip(1).map((part) => 
        part[0].toUpperCase() + part.substring(1)).join('');
  }

  // ===================================
  // REAL-TIME LISTENERS (WITH AUTO-RECONNECT)
  // ===================================

  /// Listen to changes in a user's profile
  Stream<PlayerProfile?> watchUserProfile(String userId) {
    return _createRobustStream<PlayerProfile?>(
      streamFactory: () => _supabase
          .from('player_profiles')
          .stream(primaryKey: ['id'])
          .eq('id', userId)
          .map((data) {
            if (data.isEmpty) return null;
            return PlayerProfile.fromMap(_convertToCamelCase(data.first));
          }),
    );
  }

  /// Listen to changes in bookings where user is host (excludes cancelled bookings)
  Stream<List<Booking>> streamUserBookings(String userId) {
    return _createRobustStream<List<Booking>>(
      streamFactory: () => _supabase
          .from('bookings')
          .stream(primaryKey: ['id'])
          .eq('host', userId)
          .map((data) => (data as List)
              .where((booking) {
                final status = booking['status']?.toString().toLowerCase() ?? '';
                return status != 'cancelled' && status != 'rejected';
              })
              .map((booking) => Booking.fromMap(_convertToCamelCase(booking)))
              .toList()),
    );
  }

  /// Listen to changes in bookings where user is invited (excludes cancelled bookings)
  Stream<List<Booking>> streamUserInvitedBookings(String userId) {
    return _createRobustStream<List<Booking>>(
      streamFactory: () => _supabase
          .from('bookings')
          .stream(primaryKey: ['id'])
          .map((data) => (data as List)
              .where((booking) {
                final status = booking['status']?.toString().toLowerCase() ?? '';
                final isNotCancelled = status != 'cancelled' && status != 'rejected';
                final isInvited = (booking['invite_players'] as List?)?.contains(userId) ?? false;
                return isNotCancelled && isInvited;
              })
              .map((booking) => Booking.fromMap(_convertToCamelCase(booking)))
              .toList()),
    );
  }

  /// Listen to changes in bookings (deprecated - use streamUserBookings or streamUserInvitedBookings)
  Stream<List<Booking>> watchBookings(String userId) {
    return streamUserBookings(userId);
  }

  /// Listen to changes in squads
  Stream<List<Squad>> watchUserSquads(String userId) {
    return _createRobustStream<List<Squad>>(
      streamFactory: () => _supabase
          .from('playmaker_squads')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .map((data) => (data as List)
              .where((squad) => (squad['squad_members'] as List).contains(userId))
              .map((squad) => Squad.fromMap(_convertToCamelCase(squad), squad['id']))
              .toList()),
    );
  }

  /// Listen to changes in a single booking
  Stream<Booking?> streamBooking(String bookingId) {
    return _createRobustStream<Booking?>(
      streamFactory: () => _supabase
          .from('bookings')
          .stream(primaryKey: ['id'])
          .map((data) {
            final filtered = (data as List).where((booking) => booking['id'] == bookingId);
            if (filtered.isEmpty) return null;
            return Booking.fromMap(_convertToCamelCase(filtered.first));
          }),
    );
  }

  /// Listen to user's friends
  Stream<List<PlayerProfile>> streamUserFriends(String userId) {
    return _createRobustStream<List<PlayerProfile>>(
      streamFactory: () => _supabase
          .from('player_profiles')
          .stream(primaryKey: ['id'])
          .eq('id', userId)
          .asyncMap((data) async {
            if (data.isEmpty) return <PlayerProfile>[];
            final user = _convertToCamelCase(data.first);
            final friends = user['friends'] as List? ?? [];
            
            if (friends.isEmpty) return <PlayerProfile>[];
            
            final friendProfiles = await Future.wait(
              friends.map((friendId) => getUserModel(friendId as String)),
            );
            
            return friendProfiles.whereType<PlayerProfile>().toList();
          }),
    );
  }

  /// Listen to open friend requests for a user
  Stream<List<PlayerProfile>> streamOpenFriendRequests(String userId) {
    return _createRobustStream<List<PlayerProfile>>(
      streamFactory: () => _supabase
          .from('friend_requests')
          .stream(primaryKey: ['sender_id', 'receiver_id'])
          .asyncMap((data) async {
            if (data.isEmpty) return <PlayerProfile>[];
            
            // Filter for this user's pending requests
            final pendingRequests = (data as List)
                .where((req) => 
                    req['receiver_id'] == userId && 
                    req['status'] == 'pending')
                .toList();
            
            if (pendingRequests.isEmpty) return <PlayerProfile>[];
            
            final senderIds = pendingRequests
                .map((req) => req['sender_id'] as String)
                .toList();
            
            if (senderIds.isEmpty) return <PlayerProfile>[];
            
            final senderProfiles = await Future.wait(
              senderIds.map((senderId) => getUserModel(senderId)),
            );
            
            return senderProfiles.whereType<PlayerProfile>().toList();
          }),
    );
  }

  // ===================================
  // ADMIN METHODS
  // ===================================

  /// Admin: Get total user count
  Future<int> getTotalUserCount() async {
    try {
      final response = await _supabase
          .from('player_profiles')
          .select('id')
          .count(CountOption.exact);
      return response.count;
    } catch (e) {
      print('Error getting user count: $e');
      return 0;
    }
  }

  /// Admin: Get all users with pagination
  Future<List<PlayerProfile>> getAllUsers({
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      final response = await _supabase
          .from('player_profiles')
          .select()
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List)
          .map((user) => PlayerProfile.fromMap(_convertToCamelCase(user)))
          .toList();
    } catch (e) {
      print('Error getting all users: $e');
      return [];
    }
  }

  /// Admin: Get new users count by date range
  Future<int> getNewUsersCount({required DateTime startDate, DateTime? endDate}) async {
    try {
      dynamic query = _supabase
          .from('player_profiles')
          .select('id')
          .gte('created_at', startDate.toIso8601String());

      if (endDate != null) {
        query = query.lte('created_at', endDate.toIso8601String());
      }

      final response = await query.count(CountOption.exact);
      return response.count;
    } catch (e) {
      print('Error getting new users count: $e');
      return 0;
    }
  }

  /// Admin: Get users by date range
  Future<List<PlayerProfile>> getUsersByDateRange({
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    try {
      dynamic query = _supabase
          .from('player_profiles')
          .select()
          .gte('created_at', startDate.toIso8601String());

      if (endDate != null) {
        query = query.lte('created_at', endDate.toIso8601String());
      }

      query = query.order('created_at', ascending: false);

      final response = await query;

      return (response as List)
          .map((user) => PlayerProfile.fromMap(_convertToCamelCase(user)))
          .toList();
    } catch (e) {
      print('Error getting users by date range: $e');
      return [];
    }
  }

  /// Admin: Get total bookings count
  Future<int> getTotalBookingsCount() async {
    try {
      final response = await _supabase
          .from('bookings')
          .select('id')
          .count(CountOption.exact);
      return response.count;
    } catch (e) {
      print('Error getting bookings count: $e');
      return 0;
    }
  }

  /// Admin: Get all bookings with optional date filter (enriched with user info)
  Future<List<Booking>> getAllBookings({
    String? date,
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      dynamic query = _supabase
          .from('bookings')
          .select();

      if (date != null && date.isNotEmpty) {
        query = query.eq('date', date);
      }

      query = query
          .order('date', ascending: false)
          .range(offset, offset + limit - 1);

      final response = await query as List;

      // Batch-fetch player profiles for all unique host IDs
      final hostIds = response
          .map((b) => b['host'] as String? ?? b['user_id'] as String? ?? '')
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      Map<String, Map<String, dynamic>> profileMap = {};
      if (hostIds.isNotEmpty) {
        try {
          final profiles = await _supabase
              .from('player_profiles')
              .select('id, name, profile_picture')
              .inFilter('id', hostIds);
          for (final p in profiles as List) {
            profileMap[p['id'] as String] = p as Map<String, dynamic>;
          }
        } catch (e) {
          print('⚠️ Could not fetch booking user profiles: $e');
        }
      }

      return response.map((booking) {
        final hostId = booking['host'] as String? ?? booking['user_id'] as String? ?? '';
        final profile = profileMap[hostId];
        final enriched = Map<String, dynamic>.from(booking);
        if (profile != null) {
          enriched['userName'] ??= profile['name'];
          enriched['userPhotoUrl'] ??= profile['profile_picture'];
        }
        return Booking.fromMap(_convertToCamelCase(enriched));
      }).toList();
    } catch (e) {
      print('Error getting all bookings: $e');
      return [];
    }
  }

  /// Admin: Get bookings by date range
  Future<List<Booking>> getBookingsByDateRange({
    required String startDate,
    required String endDate,
  }) async {
    try {
      final response = await _supabase
          .from('bookings')
          .select()
          .gte('date', startDate)
          .lte('date', endDate)
          .order('date', ascending: false);

      return (response as List)
          .map((booking) => Booking.fromMap(_convertToCamelCase(booking)))
          .toList();
    } catch (e) {
      print('Error getting bookings by date range: $e');
      return [];
    }
  }

  /// Admin: Search users by name or email
  Future<List<PlayerProfile>> searchUsers(String query) async {
    try {
      final response = await _supabase
          .from('player_profiles')
          .select()
          .or('name.ilike.%$query%,email.ilike.%$query%,player_id.ilike.%$query%')
          .order('created_at', ascending: false)
          .limit(50);

      return (response as List)
          .map((user) => PlayerProfile.fromMap(_convertToCamelCase(user)))
          .toList();
    } catch (e) {
      print('Error searching users: $e');
      return [];
    }
  }

  /// Admin: Stream user count for real-time updates
  Stream<int> streamUserCount() {
    return _createRobustStream<int>(
      streamFactory: () => _supabase
          .from('player_profiles')
          .stream(primaryKey: ['id'])
          .map((data) => (data as List).length),
    );
  }

  /// Admin: Stream new user registrations
  Stream<List<PlayerProfile>> streamNewUsers({int limit = 10}) {
    return _createRobustStream<List<PlayerProfile>>(
      streamFactory: () => _supabase
          .from('player_profiles')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .limit(limit)
          .map((data) => (data as List)
              .map((user) => PlayerProfile.fromMap(_convertToCamelCase(user)))
              .toList()),
    );
  }

  // ===================================
  // VISITOR TRACKING METHODS
  // ===================================

  /// Track that a user opened the app today (upsert — one row per user per day).
  /// Silent failure — must never disrupt the user experience.
  Future<void> trackAppOpen(String userId) async {
    try {
      final today = DateTime.now();
      final dateStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
          
      // Check if user has already visited today
      final existingVisit = await _supabase
          .from('app_visits')
          .select()
          .eq('user_id', userId)
          .eq('visit_date', dateStr)
          .maybeSingle();

      if (existingVisit == null) {
        // First visit today! Insert record.
        await _supabase.from('app_visits').insert({
          'user_id': userId,
          'visit_date': dateStr,
          'visited_at': today.toIso8601String(),
        });
        
        // Fetch user profile info to send in notification
        String userName = 'A user';
        try {
          final profile = await _supabase
              .from('player_profiles')
              .select('name')
              .eq('id', userId)
              .maybeSingle();
          if (profile != null && profile['name'] != null && profile['name'].toString().isNotEmpty) {
            userName = profile['name'];
          }
        } catch (_) {}

        // Fire admin notification
        try {
          await _supabase.functions.invoke(
            'send-admin-notification',
            body: {
              'type': 'app_open',
              'user_id': userId,
              'user_name': userName,
              'title': '📱 App Opened',
              'body': '$userName just opened the Playmaker app!',
            },
          );
          print('📊 App visit tracked & admin notified for user $userId on $dateStr');
        } catch (e) {
          print('⚠️ Could not send app open admin notification: $e');
        }
      } else {
        // Already visited today, just update the timestamp
        await _supabase.from('app_visits').update({
          'visited_at': today.toIso8601String(),
        }).eq('user_id', userId).eq('visit_date', dateStr);
        // Silently tracked without spamming admin
      }
    } catch (e) {
      // Intentionally silent — visitor tracking should never break the app
      print('⚠️ Could not track app visit: $e');
    }
  }

  /// Admin: Count distinct users who opened the app today.
  Future<int> getTodayVisitorCount() async {
    try {
      final today = DateTime.now();
      final dateStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final response = await _supabase
          .from('app_visits')
          .select('user_id')
          .eq('visit_date', dateStr)
          .count(CountOption.exact);
      return response.count;
    } catch (e) {
      print('Error getting today visitor count: $e');
      return 0;
    }
  }

  // ===================================
  // CHAT METHODS (MIGRATED TO SUPABASE)
  // ===================================

  /// Send a chat message
  Future<void> sendChatMessage(
    String bookingId,
    String senderId,
    String senderName,
    String message,
    String? profilePicture,
  ) async {
    try {
      await _supabase.from('booking_messages').insert({
        'booking_id': bookingId,
        'sender_id': senderId,
        'sender_name': senderName,
        'message': message,
        'profile_picture': profilePicture ?? '',
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to send chat message: $e');
    }
  }

  /// Stream chat messages
  Stream<List<Map<String, dynamic>>> streamChatMessages(String bookingId) {
    return _createRobustStream<List<Map<String, dynamic>>>(
      streamFactory: () => _supabase
          .from('booking_messages')
          .stream(primaryKey: ['id'])
          .eq('booking_id', bookingId)
          .order('created_at', ascending: true)
          .map((data) => List<Map<String, dynamic>>.from(data)),
    );
  }
}

