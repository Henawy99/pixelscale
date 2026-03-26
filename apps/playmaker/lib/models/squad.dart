class Squad {
  final String id;
  final String squadName;
  final String squadLocation;
  final String captain;
  final List<String> squadMembers;
  final List<String> pendingRequests;
  final List<String> openTeamsRequests;
  final String? squadLogo;
  final String profilePicture;
  final String matchesPlayed;
  final double? averageAge; // Changed to double?
  final bool joinable; 

  Squad({
    required this.id,
    required this.squadName,
    required this.squadLocation,
    required this.captain,
    required this.squadMembers,
    required this.pendingRequests,
    required this.openTeamsRequests,
    this.squadLogo,
    required this.profilePicture,
    required this.matchesPlayed,
    this.averageAge, // No longer required, nullable
    required this.joinable,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'squadName': squadName,
      'squadLocation': squadLocation,
      'captain': captain,
      'squadMembers': squadMembers,
      'pendingRequests': pendingRequests,
      'openTeamsRequests': openTeamsRequests,
      'squadLogo': squadLogo,
      'profilePicture': profilePicture,
      'matchesPlayed': matchesPlayed,
      'averageAge': averageAge, // Stays as double?
      'joinable': joinable,
    };
  }

  factory Squad.fromMap(Map<String, dynamic> map, String id) {
    return Squad(
      id: id,
      squadName: map['squadName'] ?? '',
      squadLocation: map['squadLocation'] ?? '',
      captain: map['captain'] ?? '',
      squadMembers: List<String>.from(map['squadMembers'] ?? []),
      pendingRequests: List<String>.from(map['pendingRequests'] ?? []),
      openTeamsRequests: List<String>.from(map['openTeamsRequests'] ?? []),
      squadLogo: map['squadLogo'],
      profilePicture: map['profilePicture'] ?? '',
      matchesPlayed: map['matchesPlayed']?.toString() ?? '0',
      averageAge: _parseAverageAge(map['averageAge']), // Use helper for robust parsing
      joinable: map['joinable'] ?? true, 
    );
  }

  static double? _parseAverageAge(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      return double.tryParse(value);
    } else if (value is num) {
      return value.toDouble();
    }
    return null; // Or handle error appropriately
  }

  Squad copyWith({
    String? id,
    String? squadName,
    String? squadLocation,
    String? captain,
    List<String>? squadMembers,
    List<String>? pendingRequests,
    List<String>? openTeamsRequests,
    String? squadLogo,
    String? profilePicture,
    String? matchesPlayed,
    double? averageAge, // Changed to double?
    bool? joinable, 
    String? description, 
  }) {
    return Squad(
      id: id ?? this.id,
      squadName: squadName ?? this.squadName,
      squadLocation: squadLocation ?? this.squadLocation,
      captain: captain ?? this.captain,
      squadMembers: squadMembers ?? this.squadMembers,
      pendingRequests: pendingRequests ?? this.pendingRequests,
      openTeamsRequests: openTeamsRequests ?? this.openTeamsRequests,
      squadLogo: squadLogo ?? this.squadLogo,
      profilePicture: profilePicture ?? this.profilePicture,
      matchesPlayed: matchesPlayed ?? this.matchesPlayed,
      averageAge: averageAge ?? this.averageAge, // Correctly copy double?
      joinable: joinable ?? this.joinable, 
      // description: description ?? this.description, 
    );
  }
}
