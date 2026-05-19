import 'dart:io';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

const String supabaseUrl = 'https://hdmycuncdlbefiiwlrca.supabase.co';
const String supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhkbXljdW5jZGxiZWZpaXdscmNhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTA0MTQ0NjIsImV4cCI6MjA2NTk5MDQ2Mn0.EqbT-LkOAnr7vOXlX93W5rsNF4HedWJqpvLVdPeu6l0';
// Service role key — used only for admin storage uploads (bypasses RLS)
const String _serviceRoleKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhkbXljdW5jZGxiZWZpaXdscmNhIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1MDQxNDQ2MiwiZXhwIjoyMDY1OTkwNDYyfQ.mVbJSO9hKyy7Dfd1AwPWZptzIvuZX_L_HwHFSYlscA0';

const String _adminEmail = 'boody@animight.com';
const String _adminPassword = '0000';

SupabaseClient get supabase => Supabase.instance.client;

// Separate client with service role key — only used for admin storage uploads
final SupabaseClient _adminStorageClient = SupabaseClient(supabaseUrl, _serviceRoleKey);

// ─────────────────────────────────────────────
// Auth
// ─────────────────────────────────────────────

Future<bool> signInAsAdmin() async {
  try {
    final res = await supabase.auth.signInWithPassword(
      email: _adminEmail,
      password: _adminPassword,
    );
    return res.user != null;
  } catch (_) {
    return false;
  }
}

Future<void> signOut() async {
  await supabase.auth.signOut();
}

bool get isAdminLoggedIn {
  final user = supabase.auth.currentUser;
  return user != null && user.email == _adminEmail;
}

// ─────────────────────────────────────────────
// Wallpapers
// ─────────────────────────────────────────────

Future<List<Map<String, dynamic>>> fetchRemoteWallpapers() async {
  try {
    final data = await supabase
        .from('animight_wallpapers')
        .select()
        .order('sort_order', ascending: true)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(data);
  } catch (_) {
    return [];
  }
}

Future<({String? url, String? error})> uploadWallpaperImage(File imageFile, String fileName) async {
  try {
    final path = 'wallpapers/$fileName';
    // Use the service-role client so the upload bypasses RLS
    await _adminStorageClient.storage
        .from('animight-wallpapers')
        .upload(path, imageFile, fileOptions: const FileOptions(upsert: true));
    final url = _adminStorageClient.storage
        .from('animight-wallpapers')
        .getPublicUrl(path);
    return (url: url, error: null);
  } catch (e) {
    // ignore: avoid_print
    print('[Animight] upload error: $e');
    return (url: null, error: e.toString());
  }
}

Future<({String? url, String? error})> uploadWallpaperBytes(Uint8List bytes, String fileName) async {
  try {
    final path = 'wallpapers/$fileName';
    await _adminStorageClient.storage
        .from('animight-wallpapers')
        .uploadBinary(path, bytes, fileOptions: const FileOptions(upsert: true));
    final url = _adminStorageClient.storage
        .from('animight-wallpapers')
        .getPublicUrl(path);
    return (url: url, error: null);
  } catch (e) {
    // ignore: avoid_print
    print('[Animight] upload error: $e');
    return (url: null, error: e.toString());
  }
}

Future<bool> addWallpaper({
  required String name,
  required String bluetoothName,
  required String imageUrl,
  bool isComingSoon = false,
}) async {
  try {
    await supabase.from('animight_wallpapers').insert({
      'name': name,
      'bluetooth_name': bluetoothName,
      'image_url': imageUrl,
      'is_coming_soon': isComingSoon,
    });
    return true;
  } catch (_) {
    return false;
  }
}

Future<bool> deleteWallpaper(String id) async {
  try {
    await supabase.from('animight_wallpapers').delete().eq('id', id);
    return true;
  } catch (_) {
    return false;
  }
}

/// Update any subset of editable fields for a wallpaper.
Future<bool> updateWallpaper({
  required String id,
  String? name,
  String? bluetoothName,
  bool? isComingSoon,
  int? sortOrder,
}) async {
  try {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (bluetoothName != null) updates['bluetooth_name'] = bluetoothName;
    if (isComingSoon != null) updates['is_coming_soon'] = isComingSoon;
    if (sortOrder != null) updates['sort_order'] = sortOrder;
    if (updates.isEmpty) return true;
    await supabase.from('animight_wallpapers').update(updates).eq('id', id);
    return true;
  } catch (_) {
    return false;
  }
}

/// Persist a new sort order for a list of wallpapers.
/// Each entry: {'id': String, 'sort_order': int}
Future<void> batchUpdateSortOrder(List<Map<String, dynamic>> items) async {
  try {
    await Future.wait(items.map((item) =>
        supabase
            .from('animight_wallpapers')
            .update({'sort_order': item['sort_order']})
            .eq('id', item['id'])));
  } catch (_) {}
}

// ─────────────────────────────────────────────
// Visitors
// ─────────────────────────────────────────────

Future<void> recordVisit() async {
  try {
    await supabase.from('animight_visitors').insert({
      'visit_date': DateTime.now().toIso8601String().substring(0, 10),
    });
  } catch (_) {}
}

Future<int> getTodayVisitorCount() async {
  try {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final data = await supabase
        .from('animight_visitors')
        .select()
        .eq('visit_date', today);
    return (data as List).length;
  } catch (_) {
    return 0;
  }
}
