/// Global configuration constants for MyCut apps.
abstract final class MyCutConfig {
  /// Supabase project URL.
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://dmopqtelmyubwsylqhwt.supabase.co',
  );

  /// Supabase publishable API key.
  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZ'
        'iI6ImRtb3BxdGVsbXl1YndzeWxxaHd0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODk'
        '5NDc1MzQsImV4cCI6MjEwNTUyMzUzNH0.U98k9_KiWN8jXHbWS3XAi08rJH0xwp79'
        'j8E7LcEF75Y',
  );

  /// Backward-compatible alias for [supabasePublishableKey].
  static const String supabaseAnonKey = supabasePublishableKey;
}
