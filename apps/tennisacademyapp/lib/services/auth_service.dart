import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile_model.dart';

class AuthService {
  static SupabaseClient get client => Supabase.instance.client;
  static User? get currentUser => client.auth.currentUser;

  /// Fetch profile for current user (role, name, etc.)
  static Future<ProfileModel?> getProfile() async {
    final uid = currentUser?.id;
    if (uid == null) return null;
    final res = await client.from('profiles').select().eq('id', uid).maybeSingle();
    if (res == null) return null;
    return ProfileModel.fromJson(Map<String, dynamic>.from(res as Map));
  }

  static Future<void> signIn(String email, String password) async {
    await client.auth.signInWithPassword(email: email, password: password);
  }

  static Future<void> signUp(String email, String password, String fullName) async {
    await client.auth.signUp(
      email: email, 
      password: password, 
      data: {'full_name': fullName}
    );
  }

  static Future<void> signOut() async {
    await client.auth.signOut();
  }
  
  static Future<void> updateProfile(String userId, Map<String, dynamic> data) async {
    await client.from('profiles').update(data).eq('id', userId);
  }
  
  static Future<String?> uploadAvatar(String userId, var fileBytes, String fileName) async {
    final path = '$userId/$fileName';
    await client.storage.from('avatars').uploadBinary(
          path,
          fileBytes,
          fileOptions: const FileOptions(upsert: true),
        );
    return client.storage.from('avatars').getPublicUrl(path);
  }

  static Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;
}
