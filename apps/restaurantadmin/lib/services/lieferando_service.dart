import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────────────

enum SessionStatus { active, expired, unknown }

class PlatformSession {
  final String accountId;
  final String label;
  final SessionStatus status;
  final DateTime? lastCheckedAt;
  final DateTime? lastOrderSeenAt;
  final String platform;

  const PlatformSession({
    required this.accountId,
    required this.label,
    required this.status,
    required this.platform,
    this.lastCheckedAt,
    this.lastOrderSeenAt,
  });

  factory PlatformSession.fromJson(Map<String, dynamic> json, String platform) {
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

    return PlatformSession(
      accountId: json['accountId'] as String? ?? '',
      label: json['label'] as String? ?? json['accountId'] as String? ?? 'Unknown',
      status: parseStatus(json['status'] as String?),
      platform: platform,
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

class PlatformSessionService {
  PlatformSessionService._internal();
  static final PlatformSessionService _instance = PlatformSessionService._internal();
  factory PlatformSessionService() => _instance;

  // Notifier for the base URL (settable from settings, default to Hetzner VPS)
  final ValueNotifier<String> monitorBaseUrl =
      ValueNotifier<String>('http://46.225.213.75:3001');

  String get _lieferandoBaseUrl => monitorBaseUrl.value.trim().replaceAll(RegExp(r'/$'), '');
  String get _foodoraBaseUrl {
    try {
      final uri = Uri.parse(_lieferandoBaseUrl);
      return '${uri.scheme}://${uri.host}:3002';
    } catch (_) {
      return '';
    }
  }

  bool get isConfigured => _lieferandoBaseUrl.isNotEmpty;

  // ── Fetch all session statuses ─────────────────────────────────────────────
  Future<List<PlatformSession>> fetchSessions() async {
    if (!isConfigured) return [];

    final List<PlatformSession> allSessions = [];

    // Fetch Lieferando
    try {
      final uri = Uri.parse('$_lieferandoBaseUrl/api/sessions');
      final response = await http
          .get(uri, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body) as List<dynamic>;
        allSessions.addAll(list.map((e) => PlatformSession.fromJson(e as Map<String, dynamic>, 'lieferando')));
      }
    } catch (e) {
      print('Lieferando fetch error: $e');
    }

    // Fetch Foodora
    try {
      final uri = Uri.parse('$_foodoraBaseUrl/api/foodora/sessions');
      final response = await http
          .get(uri, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body) as List<dynamic>;
        allSessions.addAll(list.map((e) => PlatformSession.fromJson(e as Map<String, dynamic>, 'foodora')));
      }
    } catch (e) {
      print('Foodora fetch error: $e');
    }

    return allSessions;
  }

  // ── Trigger re-login for one account ──────────────────────────────────────
  Future<ReloginResult> triggerRelogin(String accountId, String platform) async {
    final baseUrl = platform == 'foodora' ? _foodoraBaseUrl : _lieferandoBaseUrl;
    final path = platform == 'foodora' ? '/api/foodora/sessions/$accountId/relogin' : '/api/sessions/$accountId/relogin';
    
    final uri = Uri.parse('$baseUrl$path');
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
  Future<SessionStatus> confirmReloginComplete(String accountId, String platform) async {
    final baseUrl = platform == 'foodora' ? _foodoraBaseUrl : _lieferandoBaseUrl;
    final path = platform == 'foodora' ? '/api/foodora/sessions/$accountId/relogin-complete' : '/api/sessions/$accountId/relogin-complete';
    
    final uri = Uri.parse('$baseUrl$path');
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
