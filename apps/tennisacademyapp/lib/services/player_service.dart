import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/player_model.dart';

class PlayerService {
  static SupabaseClient get _client => Supabase.instance.client;

  static Future<List<PlayerModel>> fetchPlayers() async {
    // players table only has: id, name, level, class_name, created_at (no date_of_birth)
    final futures = await Future.wait([
      _client.from('players').select('id, name, level, class_name, created_at'),
      _client.from('profiles').select('*').eq('role', 'player'),
    ]);
    
    final offlinePlayers = (futures[0] as List)
        .map((e) => PlayerModel.fromJson(Map<String, dynamic>.from(e as Map), isRegistered: false));
    final registeredPlayers = (futures[1] as List)
        .map((e) => PlayerModel.fromJson(Map<String, dynamic>.from(e as Map), isRegistered: true));
        
    final allPlayers = [...offlinePlayers, ...registeredPlayers];
    allPlayers.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    
    return allPlayers;
  }

  static Future<PlayerModel> createPlayer({required String name, required String level, required String className}) async {
    final res = await _client.from('players').insert({
      'name': name,
      'level': level,
      'class_name': className,
    }).select().single();
    return PlayerModel.fromJson(Map<String, dynamic>.from(res as Map));
  }

  static Future<PlayerModel> updatePlayer(
    String id, {
    required bool isRegistered,
    String? name,
    String? level,
    String? className,
    DateTime? dateOfBirth,
    int? startedPlayingYear,
    String? dominantHand,
  }) async {
    final map = <String, dynamic>{};
    if (name != null) map[isRegistered ? 'full_name' : 'name'] = name;
    if (level != null) map['level'] = level;
    if (className != null) map['class_name'] = className;
    // Only profiles table has these columns; players table only has name, level, class_name
    if (isRegistered) {
      if (dateOfBirth != null) map['date_of_birth'] = dateOfBirth.toIso8601String().split('T')[0];
      if (startedPlayingYear != null) map['started_playing_year'] = startedPlayingYear;
      if (dominantHand != null) map['dominant_hand'] = dominantHand;
    }
    
    final table = isRegistered ? 'profiles' : 'players';
    final res = await _client.from(table).update(map).eq('id', id).select().single();
    return PlayerModel.fromJson(Map<String, dynamic>.from(res as Map), isRegistered: isRegistered);
  }

  static Future<void> deletePlayer(String id, {required bool isRegistered}) async {
    final table = isRegistered ? 'profiles' : 'players';
    await _client.from(table).delete().eq('id', id);
  }
}
