import 'package:firebase_auth/firebase_auth.dart';

class PlayerProfile {
  final String id;
  final String email;
  final String name;
  final String? playerId; // Unique 5-digit ID
  final String joined; // ISO 8601 date string
  final String phoneNumber;
  final String nationality;
  final String age;
  final String favouriteClub;
  final String preferredPosition;
  final String personalLevel;
  final String profilePicture;
  final String? fcmToken;
  final bool isGuest;
  final String rank;
  final String verified; 
  final bool verifiedEmail;
  final List<String> bookings;
  final List<String> openFriendRequests;
  final List<String> friends;
  final List<String> teamsJoined;
  final List<String> sentFriendRequests;
  final List<String> openTeamsRequests; // Assuming this exists
  final List<String> openBookingRequests; // Assuming this exists
  final String teamsJoinedHistory; // Assuming this exists

  int get numberOfGames => bookings.length;
  int get numberOfFriends => friends.length;
  int get numberOfSquads => teamsJoined.length;

  PlayerProfile({
    required this.id,
    required this.email,
    required this.name,
    required this.nationality,
    required this.age,
    required this.preferredPosition,
    String? joined,
    this.playerId,
    this.phoneNumber = '', // Add default
    this.favouriteClub = '', // Add default
    this.personalLevel = '', // Default was 'Beginner'?, check consistency
    this.profilePicture = '',
    this.fcmToken,
    this.isGuest = false,
    this.rank = 'Rookie', // Add default
    this.verified = 'false', // Add default
    this.verifiedEmail = false, // Add default
    this.teamsJoinedHistory = '', // Add default
    // Optional Lists with defaults
    List<String>? bookings,
    List<String>? openFriendRequests,
    List<String>? friends,
    List<String>? teamsJoined,
    List<String>? sentFriendRequests,
    List<String>? openTeamsRequests,
    List<String>? openBookingRequests,
  })  : joined = joined ?? DateTime.now().toIso8601String(),
        bookings = bookings ?? [],
        openFriendRequests = openFriendRequests ?? [],
        friends = friends ?? [],
        teamsJoined = teamsJoined ?? [],
        sentFriendRequests = sentFriendRequests ?? [],
        openTeamsRequests = openTeamsRequests ?? [],
        openBookingRequests = openBookingRequests ?? [];

  Map<String, dynamic> toMap() {
    return {
      'id': id, // Primary key (UUID as text)
      // NOTE: user_id is auto-populated by database trigger, no need to send it
      'email': email,
      'name': name,
      'playerId': playerId,
      'joined': joined,
      'phoneNumber': phoneNumber, // Add writing
      'nationality': nationality,
      'age': age,
      'favouriteClub': favouriteClub, // Add writing
      'preferredPosition': preferredPosition,
      'personalLevel': personalLevel,
      'profilePicture': profilePicture,
      'fcmToken': fcmToken,
      'isGuest': isGuest,
      'rank': rank, // Add writing
      'verified': verified, // Add writing
      'verifiedEmail': verifiedEmail, // Add writing
      'teamsJoinedHistory': teamsJoinedHistory, // Add writing
      // Lists
      'bookings': bookings,
      'openFriendRequests': openFriendRequests,
      'friends': friends,
      'teamsJoined': teamsJoined,
      'sentFriendRequests': sentFriendRequests,
      'openTeamsRequests': openTeamsRequests, // Add writing
      'openBookingRequests': openBookingRequests, // Add writing
    };
  }

  PlayerProfile copyWith({
    String? id,
    String? email,
    String? name,
    String? playerId,
    String? joined,
    String? phoneNumber,
    String? nationality,
    String? age,
    String? favouriteClub,
    String? preferredPosition,
    String? personalLevel,
    String? profilePicture,
    String? fcmToken,
    bool? isGuest,
    String? rank,
    String? verified,
    bool? verifiedEmail,
    String? teamsJoinedHistory,
    List<String>? bookings,
    List<String>? openFriendRequests,
    List<String>? friends,
    List<String>? teamsJoined,
    List<String>? sentFriendRequests,
    List<String>? openTeamsRequests,
    List<String>? openBookingRequests,
  }) {
    // Ensure ALL parameters required by the PlayerProfile constructor are explicitly passed.
    return PlayerProfile(
      // Required fields:
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      nationality: nationality ?? this.nationality, // Explicitly pass, falling back to 'this'
      age: age ?? this.age,                         // Explicitly pass, falling back to 'this'
      preferredPosition: preferredPosition ?? this.preferredPosition, // Explicitly pass, falling back to 'this'
      // Optional fields:
      playerId: playerId ?? this.playerId,
      joined: joined ?? this.joined,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      favouriteClub: favouriteClub ?? this.favouriteClub,
      personalLevel: personalLevel ?? this.personalLevel,
      profilePicture: profilePicture ?? this.profilePicture,
      fcmToken: fcmToken ?? this.fcmToken,
      isGuest: isGuest ?? this.isGuest,
      rank: rank ?? this.rank,
      verified: verified ?? this.verified,
      verifiedEmail: verifiedEmail ?? this.verifiedEmail,
      teamsJoinedHistory: teamsJoinedHistory ?? this.teamsJoinedHistory,
      // Lists:
      bookings: bookings ?? this.bookings,
      openFriendRequests: openFriendRequests ?? this.openFriendRequests,
      friends: friends ?? this.friends,
      teamsJoined: teamsJoined ?? this.teamsJoined,
      sentFriendRequests: sentFriendRequests ?? this.sentFriendRequests,
      openTeamsRequests: openTeamsRequests ?? this.openTeamsRequests,
      openBookingRequests: openBookingRequests ?? this.openBookingRequests,
    );
  }

  factory PlayerProfile.fromMap(Map<String, dynamic> map) {
    return PlayerProfile(
      id: map['id'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      playerId: map['playerId'], // Keep as potentially null
      joined: map['joined'] ?? DateTime.now().toIso8601String(),
      phoneNumber: map['phoneNumber'] ?? '', // Add reading
      nationality: map['nationality'] ?? '',
      age: map['age'] ?? '',
      favouriteClub: map['favouriteClub'] ?? '', // Add reading
      preferredPosition: map['preferredPosition'] ?? '',
      personalLevel: map['personalLevel'] ?? '', // Check default consistency
      profilePicture: map['profilePicture'] ?? '',
      fcmToken: map['fcmToken'], // Keep as potentially null
      isGuest: map['isGuest'] ?? false,
      rank: map['rank'] ?? 'Rookie', // Add reading
      verified: map['verified'] ?? 'false', // Add reading
      verifiedEmail: map['verifiedEmail'] ?? false, // Add reading
      teamsJoinedHistory: map['teamsJoinedHistory'] ?? '', // Add reading
      // Lists
      bookings: List<String>.from(map['bookings'] ?? []),
      openFriendRequests: List<String>.from(map['openFriendRequests'] ?? []),
      friends: List<String>.from(map['friends'] ?? []),
      teamsJoined: List<String>.from(map['teamsJoined'] ?? []),
      sentFriendRequests: List<String>.from(map['sentFriendRequests'] ?? []),
      openTeamsRequests: List<String>.from(map['openTeamsRequests'] ?? []), // Add reading
      openBookingRequests: List<String>.from(map['openBookingRequests'] ?? []), // Add reading
    );
  }

  factory PlayerProfile.fromFirebaseUser(User user) {
    return PlayerProfile(
      name: user.displayName ?? '',
      email: user.email ?? '',
      phoneNumber: user.phoneNumber ?? '',
      verifiedEmail: user.emailVerified,
      id: user.uid,
      nationality: '',
      age: '',
      preferredPosition: '',
    );
  }
}
