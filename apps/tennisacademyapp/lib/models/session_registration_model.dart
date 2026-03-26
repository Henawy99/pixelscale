/// One user's registration for a session (pending/approved/rejected).
class SessionRegistrationModel {
  final String id;
  final String sessionId;
  final String userId;
  final String status; // pending, approved, rejected
  final String? createdAt;
  final String? fullName;
  final String? email;

  SessionRegistrationModel({
    required this.id,
    required this.sessionId,
    required this.userId,
    required this.status,
    this.createdAt,
    this.fullName,
    this.email,
  });

  factory SessionRegistrationModel.fromJson(Map<String, dynamic> json) {
    return SessionRegistrationModel(
      id: json['id'] as String,
      sessionId: json['session_id'] as String,
      userId: json['user_id'] as String,
      status: json['status'] as String? ?? 'pending',
      createdAt: json['created_at'] as String?,
      fullName: json['full_name'] as String?,
      email: json['email'] as String?,
    );
  }
}
