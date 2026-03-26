import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Unified notification service for USER, ADMIN, and PARTNER apps
/// Handles FCM token management and notification triggers
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  // ============================================================
  // INITIALIZATION
  // ============================================================

  /// Initialize notifications for USER app
  Future<void> initializeUserNotifications(String userId) async {
    try {
      print('🔔 Initializing USER notifications for: $userId');
      await _requestPermissions();
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        await _updateUserFcmToken(userId, token);
      }
      _setupTokenRefreshListener(userId, 'user');
      print('✅ USER notifications initialized');
    } catch (e) {
      print('❌ Error initializing USER notifications: $e');
    }
  }

  /// Initialize notifications for PARTNER app
  Future<void> initializePartnerNotifications(String fieldId) async {
    try {
      print('🔔 Initializing PARTNER notifications for field: $fieldId');
      await _requestPermissions();
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        await _registerPartnerDevice(fieldId, token);
      }
      _setupTokenRefreshListener(fieldId, 'partner');
      print('✅ PARTNER notifications initialized');
    } catch (e) {
      print('❌ Error initializing PARTNER notifications: $e');
    }
  }

  Future<void> _requestPermissions() async {
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('✅ Notification permission granted');
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      print('✅ Provisional notification permission granted');
    } else {
      print('❌ Notification permission denied');
    }
  }

  void _setupTokenRefreshListener(String id, String appType) {
    _firebaseMessaging.onTokenRefresh.listen((newToken) {
      print('🔄 FCM Token refreshed');
      if (appType == 'user') {
        _updateUserFcmToken(id, newToken);
      } else if (appType == 'partner') {
        _registerPartnerDevice(id, newToken);
      }
    });
  }

  // ============================================================
  // TOKEN MANAGEMENT
  // ============================================================

  Future<void> _updateUserFcmToken(String userId, String token) async {
    try {
      await _supabase
          .from('player_profiles')
          .update({'fcm_token': token})
          .eq('id', userId);
      print('✅ Updated user FCM token');
    } catch (e) {
      print('❌ Error updating user FCM token: $e');
    }
  }

  Future<void> _registerPartnerDevice(String fieldId, String fcmToken) async {
    try {
      // Get device info
      String deviceInfo = 'Unknown';
      try {
        // Simple device info - could be expanded with device_info_plus package
        deviceInfo = 'Mobile Device';
      } catch (_) {}

      // Check if device already exists for this field
      final existing = await _supabase
          .from('partner_devices')
          .select()
          .eq('field_id', fieldId)
          .eq('fcm_token', fcmToken)
          .maybeSingle();

      if (existing != null) {
        // Update existing device
        await _supabase
            .from('partner_devices')
            .update({
              'updated_at': DateTime.now().toIso8601String(),
              'device_info': deviceInfo,
            })
            .eq('id', existing['id']);
        print('✅ Updated existing partner device (ID: ${existing['id']})');
      } else {
        // Check if this token exists for another field (device switched fields)
        final existingToken = await _supabase
            .from('partner_devices')
            .select()
            .eq('fcm_token', fcmToken)
            .maybeSingle();

        if (existingToken != null) {
          // Update field_id for existing token (device switched to different field)
          await _supabase
              .from('partner_devices')
              .update({
                'field_id': fieldId,
                'updated_at': DateTime.now().toIso8601String(),
                'device_info': deviceInfo,
              })
              .eq('fcm_token', fcmToken);
          print('✅ Updated partner device to new field (ID: ${existingToken['id']})');
        } else {
          // Insert new device
          final result = await _supabase.from('partner_devices').insert({
            'field_id': fieldId,
            'fcm_token': fcmToken,
            'device_info': deviceInfo,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          }).select().single();
          print('✅ Registered new partner device (ID: ${result['id']})');
        }
      }
      
      print('📱 FCM Token: ${fcmToken.substring(0, 30)}...');
    } catch (e) {
      print('❌ Error registering partner device: $e');
    }
  }
  
  /// Unregister partner device (call on logout)
  /// Removes FCM token from partner_devices table
  Future<void> unregisterPartnerDevice(String fieldId) async {
    try {
      final fcmToken = await _firebaseMessaging.getToken();
      if (fcmToken == null) {
        print('⚠️ No FCM token to unregister');
        return;
      }
      
      print('🔔 Unregistering partner device...');
      
      // Delete the device registration
      await _supabase
          .from('partner_devices')
          .delete()
          .eq('fcm_token', fcmToken);
      
      print('✅ Partner device unregistered');
    } catch (e) {
      print('❌ Error unregistering partner device: $e');
    }
  }

  // ============================================================
  // USER APP NOTIFICATIONS
  // ============================================================

  /// Send booking reminder (1 hour before)
  Future<void> sendBookingReminder({
    required String userId,
    required String fieldName,
    required String date,
    required String timeSlot,
  }) async {
    try {
      final response = await _supabase.functions.invoke('send-user-notification', body: {
        'type': 'booking_reminder',
        'user_id': userId,
        'title': '⏰ Booking Reminder',
        'body': 'Your game at $fieldName starts in 1 hour! ($timeSlot)',
        'data': {
          'field_name': fieldName,
          'date': date,
          'time_slot': timeSlot,
        },
      });
      if (response.status != 200) {
        throw Exception('Function returned status ${response.status}: ${response.data}');
      }
      print('✅ Booking reminder sent');
    } catch (e) {
      print('❌ Error sending booking reminder: $e');
      rethrow;
    }
  }

  /// Send friend request notification
  Future<void> sendFriendRequestNotification({
    required String toUserId,
    required String fromUserName,
    required String fromUserId,
  }) async {
    try {
      final response = await _supabase.functions.invoke('send-user-notification', body: {
        'type': 'friend_request',
        'user_id': toUserId,
        'title': '👋 New Friend Request',
        'body': '$fromUserName wants to be your friend!',
        'data': {
          'from_user_id': fromUserId,
          'from_user_name': fromUserName,
        },
      });
      if (response.status != 200) {
        throw Exception('Function returned status ${response.status}: ${response.data}');
      }
      print('✅ Friend request notification sent');
    } catch (e) {
      print('❌ Error sending friend request notification: $e');
      rethrow;
    }
  }

  /// Send friend request declined notification
  Future<void> sendFriendRequestDeclinedNotification({
    required String toUserId,
    required String declinedByName,
  }) async {
    try {
      final response = await _supabase.functions.invoke('send-user-notification', body: {
        'type': 'friend_request_declined',
        'user_id': toUserId,
        'title': '😔 Friend Request Declined',
        'body': '$declinedByName declined your friend request',
        'data': {
          'declined_by_name': declinedByName,
        },
      });
      if (response.status != 200) {
        throw Exception('Function returned status ${response.status}: ${response.data}');
      }
      print('✅ Friend request declined notification sent');
    } catch (e) {
      print('❌ Error sending friend request declined notification: $e');
      rethrow;
    }
  }

  /// Send squad join request notification to host and members
  Future<void> sendSquadJoinRequestNotification({
    required List<String> memberIds,
    required String requestingUserName,
    required String requestingUserId,
    required String squadName,
    required String squadId,
  }) async {
    try {
      final response = await _supabase.functions.invoke('send-user-notification', body: {
        'type': 'squad_join_request',
        'user_ids': memberIds,
        'title': '⚽ Squad Join Request',
        'body': '$requestingUserName wants to join $squadName',
        'data': {
          'requesting_user_id': requestingUserId,
          'requesting_user_name': requestingUserName,
          'squad_id': squadId,
          'squad_name': squadName,
        },
      });
      if (response.status != 200) {
        throw Exception('Function returned status ${response.status}: ${response.data}');
      }
      print('✅ Squad join request notification sent');
    } catch (e) {
      print('❌ Error sending squad join request notification: $e');
      rethrow;
    }
  }

  /// Send join request notification to host
  Future<void> sendJoinRequestNotification({
    required String hostUserId,
    required String requestingPlayerName,
    required String requestingPlayerId,
    required String fieldName,
    required String date,
    required String timeSlot,
    required String bookingId,
    int guestCount = 0,
  }) async {
    try {
      final guestText = guestCount > 0 ? ' (with $guestCount guest${guestCount > 1 ? 's' : ''})' : '';
      final response = await _supabase.functions.invoke('send-user-notification', body: {
        'type': 'join_request',
        'user_id': hostUserId,
        'title': '🙋 New Join Request',
        'body': '$requestingPlayerName wants to join your game at $fieldName$guestText',
        'data': {
          'requesting_player_id': requestingPlayerId,
          'requesting_player_name': requestingPlayerName,
          'field_name': fieldName,
          'date': date,
          'time_slot': timeSlot,
          'booking_id': bookingId,
          'guest_count': guestCount.toString(),
        },
      });
      if (response.status != 200) {
        throw Exception('Function returned status ${response.status}: ${response.data}');
      }
      print('✅ Join request notification sent to host');
    } catch (e) {
      print('❌ Error sending join request notification: $e');
      // Don't rethrow - notification failure shouldn't block the join request
    }
  }

  /// Send join request accepted notification to the requesting player
  Future<void> sendJoinRequestAcceptedNotification({
    required String toUserId,
    required String hostName,
    required String fieldName,
    required String date,
    required String timeSlot,
  }) async {
    try {
      final response = await _supabase.functions.invoke('send-user-notification', body: {
        'type': 'join_request_accepted',
        'user_id': toUserId,
        'title': '🎉 Join Request Accepted!',
        'body': '$hostName accepted your request to join the game at $fieldName',
        'data': {
          'host_name': hostName,
          'field_name': fieldName,
          'date': date,
          'time_slot': timeSlot,
        },
      });
      if (response.status != 200) {
        throw Exception('Function returned status ${response.status}: ${response.data}');
      }
      print('✅ Join request accepted notification sent');
    } catch (e) {
      print('❌ Error sending join request accepted notification: $e');
    }
  }

  /// Send player joined game notification
  Future<void> sendPlayerJoinedGameNotification({
    required List<String> playerIds,
    required String newPlayerName,
    required String fieldName,
    required String date,
    required String timeSlot,
  }) async {
    try {
      final response = await _supabase.functions.invoke('send-user-notification', body: {
        'type': 'player_joined_game',
        'user_ids': playerIds,
        'title': '🎉 New Player Joined!',
        'body': '$newPlayerName joined the game at $fieldName',
        'data': {
          'new_player_name': newPlayerName,
          'field_name': fieldName,
          'date': date,
          'time_slot': timeSlot,
        },
      });
      if (response.status != 200) {
        throw Exception('Function returned status ${response.status}: ${response.data}');
      }
      print('✅ Player joined game notification sent');
    } catch (e) {
      print('❌ Error sending player joined game notification: $e');
      rethrow;
    }
  }

  /// Send booking rejected notification
  Future<void> sendBookingRejectedNotification({
    required String userId,
    required String fieldName,
    required String date,
    required String timeSlot,
    String? rejectionReason,
  }) async {
    try {
      final response = await _supabase.functions.invoke('send-user-notification', body: {
        'type': 'booking_rejected',
        'user_id': userId,
        'title': '❌ Booking Rejected',
        'body': 'Your booking at $fieldName on $date ($timeSlot) was rejected${rejectionReason != null ? ': $rejectionReason' : ''}',
        'data': {
          'field_name': fieldName,
          'date': date,
          'time_slot': timeSlot,
          'rejection_reason': rejectionReason ?? '',
        },
      });
      if (response.status != 200) {
        throw Exception('Function returned status ${response.status}: ${response.data}');
      }
      print('✅ Booking rejected notification sent');
    } catch (e) {
      print('❌ Error sending booking rejected notification: $e');
      rethrow;
    }
  }

  /// Send recording ready notification
  Future<void> sendRecordingReadyNotification({
    required String userId,
    required String fieldName,
    required String date,
    required String timeSlot,
    String? videoUrl,
  }) async {
    try {
      final response = await _supabase.functions.invoke('send-user-notification', body: {
        'type': 'recording_ready',
        'user_id': userId,
        'title': '🎬 Your Match Recording is Ready!',
        'body': 'Your game at $fieldName on $date ($timeSlot) has been recorded. Watch it now!',
        'data': {
          'field_name': fieldName,
          'date': date,
          'time_slot': timeSlot,
          'video_url': videoUrl ?? '',
        },
      });
      if (response.status != 200) {
        throw Exception('Function returned status ${response.status}: ${response.data}');
      }
      print('✅ Recording ready notification sent');
    } catch (e) {
      print('❌ Error sending recording ready notification: $e');
      rethrow;
    }
  }

  /// Send match cancelled notification
  Future<void> sendMatchCancelledNotification({
    required List<String> playerIds,
    required String fieldName,
    required String date,
    required String timeSlot,
    required bool isHost,
    String? cancelledByName,
  }) async {
    try {
      final title = isHost ? '🚫 Your Match Cancelled' : '🚫 Match Cancelled';
      final body = isHost 
          ? 'Your hosted match at $fieldName on $date ($timeSlot) has been cancelled'
          : '${cancelledByName ?? 'The host'} cancelled the match at $fieldName on $date ($timeSlot)';
      
      final response = await _supabase.functions.invoke('send-user-notification', body: {
        'type': 'match_cancelled',
        'user_ids': playerIds,
        'title': title,
        'body': body,
        'data': {
          'field_name': fieldName,
          'date': date,
          'time_slot': timeSlot,
          'cancelled_by': cancelledByName ?? '',
        },
      });
      if (response.status != 200) {
        throw Exception('Function returned status ${response.status}: ${response.data}');
      }
      print('✅ Match cancelled notification sent');
    } catch (e) {
      print('❌ Error sending match cancelled notification: $e');
      rethrow;
    }
  }

  // ============================================================
  // PARTNER APP NOTIFICATIONS
  // ============================================================

  /// Send new booking notification to partner
  Future<void> sendPartnerNewBookingNotification({
    required String fieldId,
    required String userName,
    required String date,
    required String timeSlot,
    required int price,
  }) async {
    try {
      final response = await _supabase.functions.invoke('send-partner-notification', body: {
        'type': 'new_booking',
        'field_id': fieldId,
        'title': '⚽ New Booking!',
        'body': '$userName booked for $date at $timeSlot - $price EGP',
        'data': {
          'user_name': userName,
          'date': date,
          'time_slot': timeSlot,
          'price': price.toString(),
        },
      });
      if (response.status != 200) {
        throw Exception('Function returned status ${response.status}: ${response.data}');
      }
      print('✅ Partner new booking notification sent');
    } catch (e) {
      print('❌ Error sending partner new booking notification: $e');
      rethrow;
    }
  }

  /// Send booking cancelled notification to partner
  Future<void> sendPartnerBookingCancelledNotification({
    required String fieldId,
    required String userName,
    required String date,
    required String timeSlot,
  }) async {
    try {
      final response = await _supabase.functions.invoke('send-partner-notification', body: {
        'type': 'booking_cancelled',
        'field_id': fieldId,
        'title': '❌ Booking Cancelled',
        'body': '$userName cancelled their booking for $date at $timeSlot',
        'data': {
          'user_name': userName,
          'date': date,
          'time_slot': timeSlot,
        },
      });
      if (response.status != 200) {
        throw Exception('Function returned status ${response.status}: ${response.data}');
      }
      print('✅ Partner booking cancelled notification sent');
    } catch (e) {
      print('❌ Error sending partner booking cancelled notification: $e');
      rethrow;
    }
  }

  // ============================================================
  // HELPER: Get FCM tokens for users
  // ============================================================

  /// Get FCM tokens for multiple users (useful for testing)
  Future<List<String>> getUserFcmTokens(List<String> userIds) async {
    try {
      final response = await _supabase
          .from('player_profiles')
          .select('fcm_token')
          .inFilter('id', userIds);
      
      return (response as List)
          .map((r) => r['fcm_token'] as String?)
          .where((token) => token != null && token.isNotEmpty)
          .cast<String>()
          .toList();
    } catch (e) {
      print('❌ Error getting user FCM tokens: $e');
      return [];
    }
  }

  Future<String?> getUserFcmToken(String userId) async {
    try {
      final response = await _supabase
          .from('player_profiles')
          .select('fcm_token')
          .eq('id', userId)
          .maybeSingle();
      
      return response?['fcm_token'] as String?;
    } catch (e) {
      print('❌ Error getting user FCM token: $e');
      return null;
    }
  }
}

// ============================================================
// NOTIFICATION TYPES ENUM
// ============================================================

enum NotificationType {
  // USER APP
  bookingReminder,
  friendRequest,
  friendRequestDeclined,
  squadJoinRequest,
  playerJoinedGame,
  joinRequest,
  joinRequestAccepted,
  bookingRejected,
  matchCancelled,
  recordingReady,
  
  // PARTNER APP
  newBooking,
  bookingCancelled,
  
  // ADMIN APP
  newUser,
  newBookingAdmin,
}

extension NotificationTypeExtension on NotificationType {
  String get value {
    switch (this) {
      case NotificationType.bookingReminder:
        return 'booking_reminder';
      case NotificationType.friendRequest:
        return 'friend_request';
      case NotificationType.friendRequestDeclined:
        return 'friend_request_declined';
      case NotificationType.squadJoinRequest:
        return 'squad_join_request';
      case NotificationType.playerJoinedGame:
        return 'player_joined_game';
      case NotificationType.joinRequest:
        return 'join_request';
      case NotificationType.joinRequestAccepted:
        return 'join_request_accepted';
      case NotificationType.bookingRejected:
        return 'booking_rejected';
      case NotificationType.matchCancelled:
        return 'match_cancelled';
      case NotificationType.recordingReady:
        return 'recording_ready';
      case NotificationType.newBooking:
        return 'new_booking';
      case NotificationType.bookingCancelled:
        return 'booking_cancelled';
      case NotificationType.newUser:
        return 'new_user';
      case NotificationType.newBookingAdmin:
        return 'new_booking_admin';
    }
  }

  static NotificationType? fromString(String? value) {
    if (value == null) return null;
    for (var type in NotificationType.values) {
      if (type.value == value) return type;
    }
    return null;
  }
}

