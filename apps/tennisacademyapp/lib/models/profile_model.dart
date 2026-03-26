/// User profile from profiles table (role = admin | player | etc.)
class ProfileModel {
  final String id;
  final String fullName;
  final String? email;
  final String role; // admin, player, parent, coach
  final DateTime? dateOfBirth;
  final String? phone;
  final int? startedPlayingYear;
  final String? dominantHand; // Right, Left, Both
  final String? avatarUrl;

  ProfileModel({
    required this.id,
    required this.fullName,
    this.email,
    required this.role,
    this.dateOfBirth,
    this.phone,
    this.startedPlayingYear,
    this.dominantHand,
    this.avatarUrl,
  });

  bool get isAdmin => role == 'admin';

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String?,
      role: json['role'] as String? ?? 'player',
      dateOfBirth: json['date_of_birth'] != null ? DateTime.tryParse(json['date_of_birth'].toString()) : null,
      phone: json['phone'] as String?,
      startedPlayingYear: json['started_playing_year'] as int?,
      dominantHand: json['dominant_hand'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'full_name': fullName,
        'role': role,
        'date_of_birth': dateOfBirth?.toIso8601String().split('T')[0],
        'phone': phone,
        'started_playing_year': startedPlayingYear,
        'dominant_hand': dominantHand,
        'avatar_url': avatarUrl,
      };
  
  ProfileModel copyWith({
    String? fullName,
    String? phone,
    DateTime? dateOfBirth,
    int? startedPlayingYear,
    String? dominantHand,
    String? avatarUrl,
  }) {
    return ProfileModel(
      id: id,
      fullName: fullName ?? this.fullName,
      email: email,
      role: role,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      phone: phone ?? this.phone,
      startedPlayingYear: startedPlayingYear ?? this.startedPlayingYear,
      dominantHand: dominantHand ?? this.dominantHand,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }
}
