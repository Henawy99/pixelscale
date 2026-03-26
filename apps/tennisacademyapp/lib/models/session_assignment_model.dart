import 'player_model.dart';

class SessionAssignmentModel {
  final String id;
  final String sessionId;
  final String playerId;
  final int slot; // 1-4
  final String? createdAt;
  final PlayerModel? player;

  SessionAssignmentModel({
    required this.id,
    required this.sessionId,
    required this.playerId,
    required this.slot,
    this.createdAt,
    this.player,
  });

  factory SessionAssignmentModel.fromJson(Map<String, dynamic> json) {
    return SessionAssignmentModel(
      id: json['id'] as String,
      sessionId: json['session_id'] as String,
      playerId: json['player_id'] as String,
      slot: (json['slot'] as num).toInt(),
      createdAt: json['created_at'] as String?,
      player: json['player'] != null ? PlayerModel.fromJson(Map<String, dynamic>.from(json['player'] as Map)) : null,
    );
  }
}
