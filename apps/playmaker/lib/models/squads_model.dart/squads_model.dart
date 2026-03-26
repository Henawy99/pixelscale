class Squad {
  String id;
  String squadName;
  String squadLocation;
  DateTime joined;
  String matchesPlayed;
  String personalLevel;
  String profilePicture;
  String averageAge;
  String captain;
  List<String> squadMembers;
  List<String> bookings;
  bool joinable; // Added this line
  List<String> openTeamsRequests; // Added this line
  String? minAge;
  String? maxAge;
  String? squadLogo;
  String? description;
  String? homeField;

  Squad({
    required this.id,
    required this.squadName,
    required this.squadLocation,
    required this.joined,
    required this.matchesPlayed,
    required this.personalLevel,
    required this.profilePicture,
    required this.averageAge,
    required this.captain,
    required this.squadMembers,
    required this.bookings,
    required this.joinable, // Added this line
    required this.openTeamsRequests, // Added this line
    this.minAge,
    this.maxAge,
    this.squadLogo,
    this.description,
    this.homeField,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'squadName': squadName,
      'squadLocation': squadLocation,
      'joined': joined.toIso8601String(),
      'matchesPlayed': matchesPlayed,
      'personalLevel': personalLevel,
      'profilePicture': profilePicture,
      'averageAge': averageAge,
      'captain': captain,
      'squadMembers': squadMembers,
      'bookings': bookings,
      'joinable': joinable, // Added this line
      'openTeamsRequests': openTeamsRequests, // Added this line
      'minAge': minAge,
      'maxAge': maxAge,
      'squadLogo': squadLogo,
      'description': description,
      'homeField': homeField,
    };
  }

  factory Squad.fromMap(Map<String, dynamic> map) {
    return Squad(
      id: map['id'] ?? "",
      squadName: map['squadName'] ?? "",
      squadLocation: map['squadLocation'] ?? "",
      joined: DateTime.parse(map['joined']),
      matchesPlayed: map['matchesPlayed'] ?? "",
      personalLevel: map['personalLevel'] ?? "",
      profilePicture: map['profilePicture'] ?? "",
      averageAge: map['averageAge'] ?? "",
      captain: map['captain'] ?? "",
      squadMembers: List<String>.from(map['squadMembers'] ?? []),
      bookings: List<String>.from(map['bookings'] ?? []),
      joinable: map['joinable'] ?? false, // Added this line
      openTeamsRequests: List<String>.from(map['openTeamsRequests'] ?? []), // Added this line
      minAge: map['minAge'],
      maxAge: map['maxAge'],
      squadLogo: map['squadLogo'],
      description: map['description'],
      homeField: map['homeField'],
    );
  }
}
