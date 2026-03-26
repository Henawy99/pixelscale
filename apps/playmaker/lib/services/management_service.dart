import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:playmakerappstart/config/app_config.dart';
import 'package:playmakerappstart/services/admin_notification_service.dart';
import 'package:playmakerappstart/services/notification_service.dart';
import 'package:playmakerappstart/services/supabase_auth_service.dart';

/// Service to handle management app functionality
/// Handles unified login/logout for both Admin and Partner roles
class ManagementService {
  static final ManagementService _instance = ManagementService._internal();
  factory ManagementService() => _instance;
  ManagementService._internal();

  /// Current logged in field ID (for partner)
  String? _currentFieldId;
  
  /// Set the current field ID (call after partner login)
  void setCurrentFieldId(String? fieldId) {
    _currentFieldId = fieldId;
  }
  
  /// Get the current field ID
  String? get currentFieldId => _currentFieldId;
  
  /// Logout and cleanup FCM tokens based on current role
  /// This ensures notifications are properly unregistered
  Future<void> logout() async {
    if (kIsWeb) {
      // Web doesn't have FCM
      await SupabaseAuthService().signOut();
      return;
    }
    
    try {
      if (AppConfig.isAdmin) {
        // Unregister admin device
        print('🔔 Unregistering admin FCM token...');
        await AdminNotificationService().unregisterAdminDevice();
        print('✅ Admin device unregistered');
      } else if (AppConfig.isPartner) {
        // Unregister partner device
        print('🔔 Unregistering partner FCM token...');
        if (_currentFieldId != null) {
          await NotificationService().unregisterPartnerDevice(_currentFieldId!);
        }
        print('✅ Partner device unregistered');
      }
    } catch (e) {
      print('⚠️ Failed to unregister FCM token: $e');
    }
    
    // Clear field ID
    _currentFieldId = null;
    
    // Sign out from Supabase auth (if applicable)
    try {
      await SupabaseAuthService().signOut();
    } catch (e) {
      print('⚠️ Supabase sign out error: $e');
    }
  }
  
  /// Check if running in unified management app mode
  /// Returns true if the app was launched from main_management.dart
  static bool get isUnifiedMode {
    // In unified mode, both admin and partner run from same app
    // We can check this by the bundle ID or other means
    // For now, we'll use a simple flag that can be set
    return _isUnifiedMode;
  }
  
  static bool _isUnifiedMode = false;
  
  /// Set unified mode (called from main_management.dart)
  static void setUnifiedMode(bool value) {
    _isUnifiedMode = value;
  }
}
