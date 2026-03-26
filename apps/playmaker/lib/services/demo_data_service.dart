import 'package:playmakerappstart/models/booking_model.dart';
import 'package:playmakerappstart/models/footballfield_model.dart';
import 'package:playmakerappstart/models/user_model.dart';
import 'package:playmakerappstart/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:math';

/// Service that provides realistic demo data using actual fake users
/// generated from the admin panel.
class DemoDataService {
  static final DemoDataService _instance = DemoDataService._internal();
  factory DemoDataService() => _instance;
  DemoDataService._internal();

  final SupabaseService _supabaseService = SupabaseService();
  final SupabaseClient _supabase = Supabase.instance.client;

  List<PlayerProfile> _fakeUsers = [];
  List<FootballField> _fields = [];
  bool _isInitialized = false;

  /// Check if the given email is a demo account
  static bool isDemoAccount(String email) => email == 'demo@playmaker.com';

  /// Initialize demo data by fetching real fake users and fields from Supabase
  Future<void> initialize() async {
    if (_isInitialized && _fakeUsers.isNotEmpty) return;

    try {
      // Fetch fake users from player_profiles where email starts with 'fake_'
      final response = await _supabase
          .from('player_profiles')
          .select()
          .like('email', 'fake_%@playmaker.com')
          .limit(20);

      _fakeUsers = (response as List)
          .map((u) => PlayerProfile.fromMap(_convertToCamelCase(u)))
          .toList();

      // Fetch available fields
      final fieldsResult = await _supabaseService.getFootballFieldsPaginated(
        limit: 10,
        offset: 0,
        includeDisabled: true,
      );
      _fields = fieldsResult;

      _isInitialized = true;
      print('🎭 Demo data initialized: ${_fakeUsers.length} fake users, ${_fields.length} fields');
    } catch (e) {
      print('⚠️ Failed to initialize demo data: $e');
    }
  }

  /// Get a random subset of fake user IDs
  List<String> _getRandomFakeUserIds(int count) {
    if (_fakeUsers.isEmpty) return List.generate(count, (i) => 'fake_$i');
    final random = Random();
    final shuffled = List<PlayerProfile>.from(_fakeUsers)..shuffle(random);
    return shuffled.take(min(count, shuffled.length)).map((u) => u.id).toList();
  }

  /// Get a random fake user to be the host
  String _getRandomHostId() {
    if (_fakeUsers.isEmpty) return 'fake_host';
    final random = Random();
    return _fakeUsers[random.nextInt(_fakeUsers.length)].id;
  }

  /// The Be Pro Fun Hub field ID - used for all demo matches
  static const String _beProFieldId = 'ff897aeb-a1b2-4c2a-b944-38d554878a0f';

  /// Get the Be Pro Fun Hub field specifically
  FootballField _getBeProField() {
    // Try to find the Be Pro Fun Hub field from cached fields
    final beProField = _fields.where((f) => f.id == _beProFieldId).toList();
    if (beProField.isNotEmpty) return beProField.first;
    
    // Fallback to first field if available
    if (_fields.isNotEmpty) return _fields.first;
    
    // Ultimate fallback
    return FootballField.fromMap({
      'id': _beProFieldId,
      'football_field_name': 'Be Pro Fun Hub',
      'location_name': 'Cairo',
      'latitude': 30.0444,
      'longitude': 31.2357,
    });
  }

  /// Generate demo matches for the "Matches" tab
  /// Returns a list of demo bookings (past + upcoming)
  /// All matches use "Be Pro Fun Hub" field and 80 EGP price
  List<Booking> getDemoMatches(String currentUserId) {
    final now = DateTime.now();
    final dateFormat = DateFormat('yyyy-MM-dd');
    final List<Booking> demoBookings = [];

    // All demo matches use Be Pro Fun Hub
    final field = _getBeProField();

    // Past match with video recording
    final pastHost = _getRandomHostId();
    final pastPlayers = _getRandomFakeUserIds(6);
    if (!pastPlayers.contains(currentUserId)) pastPlayers.add(currentUserId);
    demoBookings.add(Booking(
      id: 'demo_past_match',
      userId: pastHost,
      footballFieldId: field.id,
      date: dateFormat.format(now.subtract(const Duration(days: 1))),
      timeSlot: '18:00-19:00',
      price: 80,
      paymentType: 'Cash',
      invitePlayers: pastPlayers,
      inviteSquads: [],
      isOpenMatch: false,
      bookingReference: 'DEMO-REC-001',
      footballFieldName: field.footballFieldName,
      host: pastHost,
      locationName: field.locationName,
      status: 'completed',
      isRecordingEnabled: true,
      maxPlayers: 10,
    ));

    // Past match without recording (3 days ago)
    final pastHost2 = _getRandomHostId();
    final pastPlayers2 = _getRandomFakeUserIds(8);
    if (!pastPlayers2.contains(currentUserId)) pastPlayers2.add(currentUserId);
    demoBookings.add(Booking(
      id: 'demo_past_match_2',
      userId: pastHost2,
      footballFieldId: field.id,
      date: dateFormat.format(now.subtract(const Duration(days: 3))),
      timeSlot: '20:00-21:30',
      price: 80,
      paymentType: 'Card',
      invitePlayers: pastPlayers2,
      inviteSquads: [],
      isOpenMatch: false,
      bookingReference: 'DEMO-REC-002',
      footballFieldName: field.footballFieldName,
      host: pastHost2,
      locationName: field.locationName,
      status: 'completed',
      isRecordingEnabled: false,
      maxPlayers: 14,
    ));

    // Upcoming match (tomorrow)
    final upcomingHost = _getRandomHostId();
    final upcomingPlayers = _getRandomFakeUserIds(4);
    if (!upcomingPlayers.contains(currentUserId)) upcomingPlayers.add(currentUserId);
    demoBookings.add(Booking(
      id: 'demo_upcoming_1',
      userId: upcomingHost,
      footballFieldId: field.id,
      date: dateFormat.format(now.add(const Duration(days: 1))),
      timeSlot: '19:00-20:30',
      price: 80,
      paymentType: 'Cash',
      invitePlayers: upcomingPlayers,
      inviteSquads: [],
      isOpenMatch: true,
      bookingReference: 'DEMO-UPCOMING-001',
      footballFieldName: field.footballFieldName,
      host: upcomingHost,
      locationName: field.locationName,
      status: 'confirmed',
      isRecordingEnabled: true,
      maxPlayers: 10,
    ));

    // Upcoming match (today, later)
    final upcomingHost2 = _getRandomHostId();
    final upcomingPlayers2 = _getRandomFakeUserIds(7);
    if (!upcomingPlayers2.contains(currentUserId)) upcomingPlayers2.add(currentUserId);
    demoBookings.add(Booking(
      id: 'demo_upcoming_2',
      userId: upcomingHost2,
      footballFieldId: field.id,
      date: dateFormat.format(now.add(const Duration(days: 2))),
      timeSlot: '21:00-22:30',
      price: 80,
      paymentType: 'Card',
      invitePlayers: upcomingPlayers2,
      inviteSquads: [],
      isOpenMatch: false,
      bookingReference: 'DEMO-UPCOMING-002',
      footballFieldName: field.footballFieldName,
      host: upcomingHost2,
      locationName: field.locationName,
      status: 'confirmed',
      isRecordingEnabled: false,
      maxPlayers: 14,
    ));

    return demoBookings;
  }

  /// Generate demo open matches for the "Join Matches" screen
  /// All matches use "Be Pro Fun Hub" field and 80 EGP price
  List<Booking> getDemoOpenMatches(String currentUserId, Map<String, FootballField?> fieldsMap) {
    final now = DateTime.now();
    final dateFormat = DateFormat('yyyy-MM-dd');
    final formattedDate = dateFormat.format(now);

    // All demo open matches use Be Pro Fun Hub
    final field = _getBeProField();

    return [
      // Match 1: 6/10 players
      Booking(
        id: 'demo_open_match_1',
        userId: _getRandomHostId(),
        footballFieldId: field.id,
        date: formattedDate,
        timeSlot: '18:00-19:00',
        price: 80,
        paymentType: 'Card',
        invitePlayers: _getRandomFakeUserIds(6),
        inviteSquads: [],
        isOpenMatch: true,
        bookingReference: 'DEMO-OPEN-001',
        footballFieldName: field.footballFieldName,
        host: _getRandomHostId(),
        locationName: field.locationName,
        status: 'confirmed',
        maxPlayers: 10,
      ),
      // Match 2: 3/10 players
      Booking(
        id: 'demo_open_match_2',
        userId: _getRandomHostId(),
        footballFieldId: field.id,
        date: formattedDate,
        timeSlot: '19:00-20:00',
        price: 80,
        paymentType: 'Cash',
        invitePlayers: _getRandomFakeUserIds(3),
        inviteSquads: [],
        isOpenMatch: true,
        bookingReference: 'DEMO-OPEN-002',
        footballFieldName: field.footballFieldName,
        host: _getRandomHostId(),
        locationName: field.locationName,
        status: 'confirmed',
        maxPlayers: 10,
      ),
      // Match 3: 8/14 players
      Booking(
        id: 'demo_open_match_3',
        userId: _getRandomHostId(),
        footballFieldId: field.id,
        date: formattedDate,
        timeSlot: '20:00-21:30',
        price: 80,
        paymentType: 'Card',
        invitePlayers: _getRandomFakeUserIds(8),
        inviteSquads: [],
        isOpenMatch: true,
        bookingReference: 'DEMO-OPEN-003',
        footballFieldName: field.footballFieldName,
        host: _getRandomHostId(),
        locationName: field.locationName,
        status: 'confirmed',
        maxPlayers: 14,
      ),
      // Match 4: 4/10 players  
      Booking(
        id: 'demo_open_match_4',
        userId: _getRandomHostId(),
        footballFieldId: field.id,
        date: formattedDate,
        timeSlot: '21:30-23:00',
        price: 80,
        paymentType: 'Card',
        invitePlayers: _getRandomFakeUserIds(4),
        inviteSquads: [],
        isOpenMatch: true,
        bookingReference: 'DEMO-OPEN-004',
        footballFieldName: field.footballFieldName,
        host: _getRandomHostId(),
        locationName: field.locationName,
        status: 'confirmed',
        maxPlayers: 10,
      ),
    ];
  }

  /// Convert snake_case keys to camelCase for Flutter models
  static Map<String, dynamic> _convertToCamelCase(Map<String, dynamic> data) {
    final result = <String, dynamic>{};
    data.forEach((key, value) {
      final camelKey = _toCamelCase(key);
      if (value is Map<String, dynamic>) {
        result[camelKey] = _convertToCamelCase(value);
      } else if (value is Map) {
        result[camelKey] = _convertToCamelCase(Map<String, dynamic>.from(value));
      } else {
        result[camelKey] = value;
      }
    });
    return result;
  }

  static String _toCamelCase(String str) {
    final parts = str.split('_');
    if (parts.length == 1) return parts[0];
    return parts[0] + parts.skip(1).map((part) =>
      part.isNotEmpty ? part[0].toUpperCase() + part.substring(1) : '').join('');
  }
}
