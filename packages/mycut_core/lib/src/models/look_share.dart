/// Ephemeral share code metadata for the QR handoff.
class LookShare {
  const LookShare({
    required this.code,
    required this.lookId,
    required this.expiresAt,
    required this.shareUrl,
    this.userId = '',
    this.maxRedemptions = 20,
    this.redemptionCount = 0,
    this.revokedAt,
    this.createdAt,
  });

  factory LookShare.fromJson(Map<String, dynamic> json) {
    return LookShare(
      code: json['code'] as String? ?? '',
      lookId: json['look_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      expiresAt: DateTime.parse(
        json['expires_at'] as String? ?? DateTime.now().toIso8601String(),
      ),
      shareUrl: json['share_url'] as String? ??
          'https://mycut.app/l/${json['code'] ?? ''}',
      maxRedemptions: (json['max_redemptions'] as num?)?.toInt() ?? 20,
      redemptionCount: (json['redemption_count'] as num?)?.toInt() ?? 0,
      revokedAt: json['revoked_at'] != null
          ? DateTime.tryParse(json['revoked_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  /// 8-character Crockford Base32 code.
  final String code;

  /// Foreign key referencing the shared Look.
  final String lookId;

  /// Foreign key referencing the customer user.
  final String userId;

  /// Expiry timestamp (typically 30 minutes from creation).
  final DateTime expiresAt;

  /// Web universal link (e.g. "https://mycut.app/l/K7M4XQ2P").
  final String shareUrl;

  /// Maximum allowed scans before expiry.
  final int maxRedemptions;

  /// Current scan counter.
  final int redemptionCount;

  /// Revocation timestamp if manually cancelled.
  final DateTime? revokedAt;

  /// Creation timestamp.
  final DateTime? createdAt;

  /// Whether this code has expired based on current local time.
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Whether this code was revoked.
  bool get isRevoked => revokedAt != null;

  /// Whether this code is still valid for redemption.
  bool get isValid =>
      !isExpired && !isRevoked && redemptionCount < maxRedemptions;

  /// Duration remaining before expiry.
  Duration get remainingDuration {
    final diff = expiresAt.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'look_id': lookId,
        'user_id': userId,
        'expires_at': expiresAt.toIso8601String(),
        'share_url': shareUrl,
        'max_redemptions': maxRedemptions,
        'redemption_count': redemptionCount,
        if (revokedAt != null) 'revoked_at': revokedAt!.toIso8601String(),
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      };
}
