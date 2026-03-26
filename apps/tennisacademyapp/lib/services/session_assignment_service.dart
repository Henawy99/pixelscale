import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/player_model.dart';

class SessionAssignmentService {
  static SupabaseClient get _client => Supabase.instance.client;

  /// Get assignments for a session with player details. Returns map slot (1-4) -> PlayerModel.
  static Future<Map<int, PlayerModel>> getAssignmentsForSession(String sessionId) async {
    final res = await _client
        .from('session_assignments')
        .select('*, player:players(*)')
        .eq('session_id', sessionId);
    final list = res as List;
    final map = <int, PlayerModel>{};
    for (final e in list) {
      final m = Map<String, dynamic>.from(e as Map);
      final slot = (m['slot'] as num).toInt();
      if (m['player'] != null) {
        map[slot] = PlayerModel.fromJson(Map<String, dynamic>.from(m['player'] as Map));
      }
    }
    return map;
  }

  /// Assign a player to a slot (1-4). Replaces any existing assignment in that slot.
  static Future<void> assignPlayerToSlot(String sessionId, String playerId, int slot) async {
    await _client.from('session_assignments').delete().eq('session_id', sessionId).eq('slot', slot);
    await _client.from('session_assignments').insert({
      'session_id': sessionId,
      'player_id': playerId,
      'slot': slot,
    });
  }

  /// Remove assignment from a slot.
  static Future<void> removeAssignment(String sessionId, int slot) async {
    await _client.from('session_assignments').delete().eq('session_id', sessionId).eq('slot', slot);
  }

  /// Remove by assignment id.
  static Future<void> removeAssignmentById(String assignmentId) async {
    await _client.from('session_assignments').delete().eq('id', assignmentId);
  }

  /// Assign a player to a slot (1-4) for all future sessions in a series.
  static Future<void> assignPlayerToSlotSeries(String recurrenceId, String fromDate, String playerId, int slot) async {
    final res = await _client.from('sessions')
        .select('id')
        .eq('recurrence_id', recurrenceId)
        .gte('date', fromDate);
    
    final list = res as List;
    for (final e in list) {
       final sessionId = e['id'] as String;
       await assignPlayerToSlot(sessionId, playerId, slot);
    }
  }

  /// Remove assignment from a slot for all future sessions in a series.
  static Future<void> removeAssignmentSeries(String recurrenceId, String fromDate, int slot) async {
    final res = await _client.from('sessions')
        .select('id')
        .eq('recurrence_id', recurrenceId)
        .gte('date', fromDate);
    
    final list = res as List;
    for (final e in list) {
       final sessionId = e['id'] as String;
       await removeAssignment(sessionId, slot);
    }
  }
}
