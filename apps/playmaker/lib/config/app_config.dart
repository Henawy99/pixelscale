/// App flavor configuration for User, Admin, and Partner apps
enum AppFlavor { user, admin, partner }

class AppConfig {
  static AppFlavor _flavor = AppFlavor.user;
  
  /// Set the current app flavor
  static void setFlavor(AppFlavor flavor) {
    _flavor = flavor;
  }
  
  /// Get the current flavor
  static AppFlavor get flavor => _flavor;
  
  /// Check if running admin app
  static bool get isAdmin => _flavor == AppFlavor.admin;
  
  /// Check if running user app
  static bool get isUser => _flavor == AppFlavor.user;
  
  /// Check if running partner app
  static bool get isPartner => _flavor == AppFlavor.partner;
  
  /// Get app name based on flavor
  static String get appName {
    switch (_flavor) {
      case AppFlavor.admin:
        return 'Playmaker Admin';
      case AppFlavor.partner:
        return 'Playmaker Partner';
      case AppFlavor.user:
      default:
        return 'Playmaker';
    }
  }
  
  /// Get bundle ID based on flavor
  static String get bundleId {
    switch (_flavor) {
      case AppFlavor.admin:
        return 'com.playmaker.admin';
      case AppFlavor.partner:
        return 'com.playmaker.partner';
      case AppFlavor.user:
      default:
        return 'com.playmaker.app';
    }
  }
  
  /// Admin email
  static const String adminEmail = 'youssef@gmail.com';
  
  /// FCM topic for admin notifications
  static const String adminNotificationTopic = 'admin_notifications';
}

