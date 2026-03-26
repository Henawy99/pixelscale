import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service to track and retrieve Al Baseet page visitor statistics
class AlBaseetVisitorService {
  static final AlBaseetVisitorService _instance = AlBaseetVisitorService._internal();
  factory AlBaseetVisitorService() => _instance;
  AlBaseetVisitorService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  String? _deviceId;
  DateTime? _sessionStart;
  String? _currentVisitId;

  /// Get or generate a unique device ID
  String get deviceId {
    _deviceId ??= DateTime.now().millisecondsSinceEpoch.toString() + 
                  '_${hashCode.toString()}';
    return _deviceId!;
  }

  /// Get platform string
  String get platform {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'unknown';
  }

  /// Track a page visit
  Future<void> trackVisit({String screen = 'home'}) async {
    try {
      _sessionStart = DateTime.now();
      
      final response = await _supabase
          .from('al_baseet_visits')
          .insert({
            'device_id': deviceId,
            'platform': platform,
            'screen_viewed': screen,
            'metadata': {
              'app_version': '1.0.0',
              'timestamp': DateTime.now().toIso8601String(),
            },
          })
          .select('id')
          .single();
      
      _currentVisitId = response['id'];
      print('✅ Al Baseet visit tracked: $_currentVisitId');
    } catch (e) {
      print('❌ Error tracking visit: $e');
    }
  }

  /// Update session duration when leaving
  Future<void> endSession() async {
    if (_currentVisitId == null || _sessionStart == null) return;
    
    try {
      final duration = DateTime.now().difference(_sessionStart!).inSeconds;
      
      await _supabase
          .from('al_baseet_visits')
          .update({'session_duration_seconds': duration})
          .eq('id', _currentVisitId!);
      
      print('✅ Session ended, duration: ${duration}s');
    } catch (e) {
      print('❌ Error ending session: $e');
    }
  }

  /// Get total visitor count
  Future<int> getTotalVisitors() async {
    try {
      final response = await _supabase
          .from('al_baseet_visits')
          .select('id')
          .count();
      
      return response.count;
    } catch (e) {
      print('❌ Error getting total visitors: $e');
      // Fallback: try to count manually
      try {
        final data = await _supabase
            .from('al_baseet_visits')
            .select('id');
        return (data as List).length;
      } catch (_) {
        return 0;
      }
    }
  }

  /// Get today's visitor count
  Future<int> getTodayVisitors() async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      
      final response = await _supabase
          .from('al_baseet_visits')
          .select('id')
          .gte('visited_at', startOfDay.toIso8601String())
          .count();
      
      return response.count;
    } catch (e) {
      print('❌ Error getting today visitors: $e');
      return 0;
    }
  }

  /// Get unique visitors count
  Future<int> getUniqueVisitors() async {
    try {
      final data = await _supabase
          .from('al_baseet_visits')
          .select('device_id');
      
      final uniqueDevices = (data as List)
          .map((e) => e['device_id'])
          .where((id) => id != null)
          .toSet();
      
      return uniqueDevices.length;
    } catch (e) {
      print('❌ Error getting unique visitors: $e');
      return 0;
    }
  }

  /// Get visitor stats as a map
  Future<Map<String, int>> getVisitorStats() async {
    final results = await Future.wait([
      getTotalVisitors(),
      getTodayVisitors(),
      getUniqueVisitors(),
    ]);
    
    return {
      'total': results[0],
      'today': results[1],
      'unique': results[2],
    };
  }

  /// Stream visitor count updates (polls every 10 seconds)
  Stream<int> visitorCountStream() async* {
    while (true) {
      yield await getTotalVisitors();
      await Future.delayed(const Duration(seconds: 10));
    }
  }
}
