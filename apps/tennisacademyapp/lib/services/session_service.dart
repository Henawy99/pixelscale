import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/session_model.dart';
import '../models/session_registration_model.dart';

/// Session service: create, update, delete, add/remove players, join/leave.
class SessionService {
  static SupabaseClient get _client => Supabase.instance.client;

  /// Get sessions for a date with player counts and current user status.
  static Future<List<SessionModel>> fetchSessions(String date) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    final res = await _client
        .from('sessions')
        .select('*, session_registrations(status, user_id)')
        .eq('date', date)
        .order('start_time', ascending: true);

    if (res.isEmpty) return [];

    // Batch fetch profile names for all user_ids
    final allUserIds = <String>{};
    for (final s in res) {
      final regs = s['session_registrations'] as List? ?? [];
      for (final r in regs) {
        allUserIds.add(r['user_id'] as String);
      }
    }

    Map<String, String> namesByUserId = {};
    if (allUserIds.isNotEmpty) {
      final profiles = await _client
          .from('profiles')
          .select('id, full_name')
          .inFilter('id', allUserIds.toList());
      for (final p in profiles) {
        namesByUserId[p['id'] as String] = p['full_name'] as String? ?? 'Unknown';
      }
    }

    return res.map<SessionModel>((s) {
      final regs = s['session_registrations'] as List? ?? [];
      final valid = regs.where((r) => ['pending', 'approved'].contains(r['status'])).toList();
      final myRegList = regs.cast<Map>().where((r) => r['user_id'] == userId).toList();
      final myReg = myRegList.isEmpty ? null : myRegList.first as Map<String, dynamic>?;
      final playerNames = valid.map((r) => namesByUserId[r['user_id'] as String] ?? 'Unknown').toList();

      return SessionModel.fromJson(
        Map<String, dynamic>.from(s as Map),
        playerCount: valid.length,
        userStatus: myReg != null ? (myReg['status'] as String?) : null,
        playerNames: playerNames,
      );
    }).toList();
  }

  static Future<Map<String, dynamic>> joinSession(String sessionId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    final res = await _client.rpc('join_session', params: {
      'p_session_id': sessionId,
      'p_user_id': userId,
    });
    return Map<String, dynamic>.from(res as Map);
  }

  static Future<void> leaveSession(String sessionId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    await _client
        .from('session_registrations')
        .delete()
        .eq('session_id', sessionId)
        .eq('user_id', userId);
  }

  /// Admin: create session (single or recurring).
  static Future<void> createSession({
    required String date, // First date YYYY-MM-DD
    required int courtId,
    required String name,
    required String startTime,
    required String endTime,
    String? fitnessStartTime,
    String? fitnessEndTime,
    int maxCapacity = 4,
    String? recurrenceRule, // 'daily', 'weekly'
    int repeatCount = 1,
  }) async {
    final recurrenceId = repeatCount > 1 ? const Uuid().v4() : null;
    final startDate = DateTime.parse(date);

    for (int i = 0; i < repeatCount; i++) {
      DateTime current = startDate;
      if (recurrenceRule == 'daily') {
        current = startDate.add(Duration(days: i));
      } else if (recurrenceRule == 'weekly') {
        current = startDate.add(Duration(days: i * 7));
      }
      
      final dateStr = current.toIso8601String().split('T')[0];

      await _client.from('sessions').insert({
        'date': dateStr,
        'court_id': courtId,
        'name': name,
        'start_time': startTime,
        'end_time': endTime,
        'fitness_start_time': fitnessStartTime,
        'fitness_end_time': fitnessEndTime,
        'max_capacity': maxCapacity,
        'recurrence_id': recurrenceId,
        'recurrence_rule': recurrenceRule,
      });
    }
  }

  static Future<SessionModel> updateSession(String id, Map<String, dynamic> updates) async {
    final res = await _client.from('sessions').update(updates).eq('id', id).select().single();
    return SessionModel.fromJson(Map<String, dynamic>.from(res as Map));
  }

  /// Admin: delete session.
  static Future<void> deleteSession(String id) async {
    await _client.from('sessions').delete().eq('id', id);
  }
  
  /// Admin: delete entire series.
  static Future<void> deleteSessionSeries(String recurrenceId) async {
    await _client.from('sessions').delete().eq('recurrence_id', recurrenceId);
  }

  static Future<bool> isSessionFull(String sessionId) async {
    final session = await _client.from('sessions').select('max_capacity').eq('id', sessionId).single();
    final maxCap = (session['max_capacity'] as num?)?.toInt() ?? 4;
    final list = await _client
        .from('session_registrations')
        .select('id')
        .eq('session_id', sessionId)
        .inFilter('status', ['pending', 'approved']);
    final n = (list as List).length;
    return n >= maxCap;
  }

  static Future<void> addPlayerToSession(String sessionId, String userId) async {
    final full = await isSessionFull(sessionId);
    if (full) throw Exception('Session is full');

    await _client.from('session_registrations').insert({
      'session_id': sessionId,
      'user_id': userId,
      'status': 'approved',
    });
  }

  static Future<void> removePlayerFromSession(String registrationId) async {
    await _client.from('session_registrations').delete().eq('id', registrationId);
  }

  static Future<List<SessionRegistrationModel>> getSessionRegistrations(String sessionId) async {
    final regs = await _client.from('session_registrations').select('*').eq('session_id', sessionId);
    if (regs.isEmpty) return [];

    final userIds = regs.map<String>((r) => r['user_id'] as String).toSet().toList();
    final profiles = await _client.from('profiles').select('id, full_name, email').inFilter('id', userIds);
    final byId = <String, Map>{};
    for (final p in profiles) {
      byId[p['id'] as String] = p;
    }

    return regs.map((r) {
      final m = Map<String, dynamic>.from(r as Map);
      final p = byId[m['user_id']];
      if (p != null) {
        m['full_name'] = p['full_name'];
        m['email'] = p['email'];
      }
      return SessionRegistrationModel.fromJson(m);
    }).toList();
  }

  static Future<void> updateRegistrationStatus(String registrationId, String status) async {
    await _client.from('session_registrations').update({'status': status}).eq('id', registrationId);
  }

  static Future<List<Map<String, dynamic>>> findProfileByEmail(String email) async {
    final res = await _client.from('profiles').select('id, full_name, email').eq('email', email);
    final list = res as List;
    if (list.isEmpty) return [];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// Admin: fetch sessions for a date with roster slot assignments (session_assignments + players).
  static Future<List<SessionModel>> fetchSessionsWithSlotAssignments(String date) async {
    final res = await _client
        .from('sessions')
        .select('*, session_assignments(slot, player:players(id, name, level, class_name))')
        .eq('date', date)
        .order('start_time', ascending: true);
    if (res.isEmpty) return [];

    return (res as List).map<SessionModel>((s) {
      final sessionMap = Map<String, dynamic>.from(s as Map);
      final assignments = sessionMap['session_assignments'] as List? ?? [];
      final slotNames = <int, String>{};
      for (final a in assignments) {
        final m = a as Map;
        final slot = (m['slot'] as num).toInt();
        final player = m['player'];
        slotNames[slot] = player != null ? (player['name'] as String? ?? '') : '';
      }
      final session = SessionModel.fromJson(
        sessionMap,
        playerCount: slotNames.length,
        userStatus: null,
        playerNames: [],
      );
      session.slotPlayerNames = {
        1: slotNames[1] ?? '',
        2: slotNames[2] ?? '',
        3: slotNames[3] ?? '',
        4: slotNames[4] ?? '',
      };
      return session;
    }).toList();
  }

  /// Admin: fetch sessions for a date range (inclusive) with slot assignments.
  static Future<List<SessionModel>> fetchSessionsWithSlotAssignmentsRange(String startDate, String endDate) async {
    final res = await _client
        .from('sessions')
        .select('*, session_assignments(slot, player:players(id, name, level, class_name))')
        .gte('date', startDate)
        .lte('date', endDate)
        .order('date', ascending: true)
        .order('start_time', ascending: true);
    if (res.isEmpty) return [];

    return (res as List).map<SessionModel>((s) {
      final sessionMap = Map<String, dynamic>.from(s as Map);
      final assignments = sessionMap['session_assignments'] as List? ?? [];
      final slotNames = <int, String>{};
      for (final a in assignments) {
        final m = a as Map;
        final slot = (m['slot'] as num).toInt();
        final player = m['player'];
        slotNames[slot] = player != null ? (player['name'] as String? ?? '') : '';
      }
      final session = SessionModel.fromJson(
        sessionMap,
        playerCount: slotNames.length,
        userStatus: null,
        playerNames: [],
      );
      session.slotPlayerNames = {
        1: slotNames[1] ?? '',
        2: slotNames[2] ?? '',
        3: slotNames[3] ?? '',
        4: slotNames[4] ?? '',
      };
      return session;
    }).toList();
  }
}
