import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────────────

enum SessionStatus { active, expired, unknown }

class LieferandoSession {
  final String accountId;
  final String label;
  final SessionStatus status;
  final DateTime? lastCheckedAt;
  final DateTime? lastOrderSeenAt;

  const LieferandoSession({
    required this.accountId,
    required this.label,
    required this.status,
    this.lastCheckedAt,
    this.lastOrderSeenAt,
  });

  factory LieferandoSession.fromJson(Map<String, dynamic> json) {
    SessionStatus parseStatus(String? s) {
      switch (s) {
        case 'active':
          return SessionStatus.active;
        case 'expired':
          return SessionStatus.expired;
        default:
          return SessionStatus.unknown;
      }
    }

    return LieferandoSession(
      accountId: json['accountId'] as String? ?? '',
      label: json['label'] as String? ?? json['accountId'] as String? ?? 'Unknown',
      status: parseStatus(json['status'] as String?),
      lastCheckedAt: json['lastCheckedAt'] != null
          ? DateTime.tryParse(json['lastCheckedAt'] as String)
          : null,
      lastOrderSeenAt: json['lastOrderSeenAt'] != null
          ? DateTime.tryParse(json['lastOrderSeenAt'] as String)
          : null,
    );
  }
}

class ReloginResult {
  final bool success;
  final String message;
  final String? vncHost;
  final int? vncPort;

  const ReloginResult({
    required this.success,
    required this.message,
    this.vncHost,
    this.vncPort,
  });

  factory ReloginResult.fromJson(Map<String, dynamic> json) {
    return ReloginResult(
      success: json['status'] == 'login_window_opened',
      message: json['message'] as String? ?? 'Login window opened.',
      vncHost: json['vncHost'] as String?,
      vncPort: json['vncPort'] as int?,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Service
// ─────────────────────────────────────────────────────────────────────────────

class LieferandoService {
  LieferandoService._internal();
  static final LieferandoService _instance = LieferandoService._internal();
  factory LieferandoService() => _instance;

  // Notifier for the base URL (settable from settings)
  final ValueNotifier<String> monitorBaseUrl = ValueNotifier<String>('');

  String get _baseUrl => monitorBaseUrl.value.trim().replaceAll(RegExp(r'/$'), '');

  bool get isConfigured => _baseUrl.isNotEmpty;

  // ── Fetch all session statuses ─────────────────────────────────────────────
  Future<List<LieferandoSession>> fetchSessions() async {
    if (!isConfigured) return [];

    final uri = Uri.parse('$_baseUrl/api/sessions');
    final response = await http
        .get(uri, headers: {'Content-Type': 'application/json'})
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Monitor returned ${response.statusCode}: ${response.body}');
    }

    final List<dynamic> list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => LieferandoSession.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Trigger re-login for one account ──────────────────────────────────────
  Future<ReloginResult> triggerRelogin(String accountId) async {
    final uri = Uri.parse('$_baseUrl/api/sessions/$accountId/relogin');
    final response = await http
        .post(uri, headers: {'Content-Type': 'application/json'})
        .timeout(const Duration(seconds: 15));

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(json['error'] ?? 'Unknown error (${response.statusCode})');
    }
    return ReloginResult.fromJson(json);
  }

  // ── Confirm re-login is complete ───────────────────────────────────────────
  Future<SessionStatus> confirmReloginComplete(String accountId) async {
    final uri = Uri.parse('$_baseUrl/api/sessions/$accountId/relogin-complete');
    final response = await http
        .post(uri, headers: {'Content-Type': 'application/json'})
        .timeout(const Duration(seconds: 15));

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(json['error'] ?? 'Unknown error (${response.statusCode})');
    }

    switch (json['status'] as String?) {
      case 'active':
        return SessionStatus.active;
      case 'expired':
        return SessionStatus.expired;
      default:
        return SessionStatus.unknown;
    }
  }
}
