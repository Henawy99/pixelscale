class Profile {
  final String id; // Corresponds to the auth.users.id
  final String role; // e.g., 'admin', 'driver', 'customer'
  final String? email; // Optional: email from auth.users
  final String? fullName; // Optional: full name if stored in profiles
  // Add other profile-specific fields as needed

  Profile({
    required this.id,
    required this.role,
    this.email,
    this.fullName,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role,
      'email': email,
      'full_name': fullName,
    };
  }

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      role: json['role'] as String? ?? 'customer', // Default to 'customer' if role is not set
      email: json['email'] as String?,
      fullName: json['full_name'] as String?,
    );
  }
}
