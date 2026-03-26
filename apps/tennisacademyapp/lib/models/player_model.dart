import '../constants/levels.dart';

class PlayerModel {
  final String id;
  final String name;
  final String level; // green, red, yellow, orange
  final String className; // Avocado, Lemons, Bee, etc.
  final String? createdAt;
  final bool isRegistered;
  final DateTime? dateOfBirth;
  final int? startedPlayingYear;
  final String? dominantHand; // Right, Left, Both
  final String? avatarUrl;

  PlayerModel({
    required this.id,
    required this.name,
    required this.level,
    required this.className,
    this.createdAt,
    this.isRegistered = false,
    this.dateOfBirth,
    this.startedPlayingYear,
    this.dominantHand,
    this.avatarUrl,
  });

  LevelInfo get levelInfo => levelColorFromDb(level);

  factory PlayerModel.fromJson(Map<String, dynamic> json, {bool isRegistered = false}) {
    return PlayerModel(
      id: json['id'] as String,
      name: (json['name'] ?? json['full_name']) as String? ?? '',
      level: json['level'] as String? ?? 'green',
      className: json['class_name'] as String? ?? '',
      createdAt: json['created_at'] as String?,
      isRegistered: isRegistered,
      dateOfBirth: json['date_of_birth'] != null ? DateTime.tryParse(json['date_of_birth'].toString()) : null,
      startedPlayingYear: json['started_playing_year'] as int?,
      dominantHand: json['dominant_hand'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'level': level,
        'class_name': className,
        'date_of_birth': dateOfBirth?.toIso8601String().split('T')[0],
        'started_playing_year': startedPlayingYear,
        'dominant_hand': dominantHand,
      };
}
