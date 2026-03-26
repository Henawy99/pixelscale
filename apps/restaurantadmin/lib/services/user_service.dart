import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:restaurantadmin/models/profile.dart';

class UserService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<Profile?> getUserProfile(String userId) async {
    try {
      final response = await _supabase
          .from('profiles') // Assuming your table is named 'profiles'
          .select()
          .eq('id', userId)
          .single(); // Use .single() as 'id' should be unique

      return Profile.fromJson(response);
    } catch (e) {
      print('Error fetching user profile for $userId: $e');
      // Consider how to handle errors: rethrow, return null, or return a default Profile
      // For now, returning null, AuthGate will need to handle this.
      return null;
    }
  }

  // You can add other user-related service methods here, e.g.:
  // Future<void> updateUserProfile(Profile profile) async { ... }
  // Future<List<Profile>> getAllUsersByRole(String role) async { ... }
}
