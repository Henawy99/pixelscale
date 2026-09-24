import 'dart:typed_data';
import 'package:mycut_core/src/failures.dart';
import 'package:mycut_core/src/models/look.dart';
import 'package:mycut_core/src/result.dart';
import 'package:mycut_cutspec/mycut_cutspec.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Contract for accessing and saving customer Looks.
abstract class LooksRepository {
  /// Fetches all active looks for the authenticated user.
  Future<Result<List<Look>, Failure>> getLooks({bool includeArchived = false});

  /// Fetches a single look by [id] including its renders.
  Future<Result<Look, Failure>> getLookById(String id);

  /// Saves a new look along with an optional initial render photo.
  Future<Result<Look, Failure>> createLook({
    required String title,
    String styleKey = 'custom',
    CutSpec? cutSpec,
    Uint8List? imageBytes,
    String? imageFileName,
    RenderView view = RenderView.front,
  });

  /// Creates a look initialized with 4-angle headshots for AI simulation.
  Future<Result<({Look look, String sourcePhotoId}), Failure>>
      createLookWithHeadshots({
    required Uint8List frontImageBytes,
    Uint8List? leftImageBytes,
    Uint8List? rightImageBytes,
    Uint8List? backImageBytes,
    String title = 'My AI Hairstyle',
  });

  /// Archives a look.
  Future<Result<void, Failure>> archiveLook(String id);
}

/// Supabase-backed implementation of [LooksRepository].
class SupabaseLooksRepository implements LooksRepository {
  const SupabaseLooksRepository(this._supabase);

  final SupabaseClient _supabase;

  @override
  Future<Result<List<Look>, Failure>> getLooks({
    bool includeArchived = false,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return const Error(AuthFailure(message: 'User is not authenticated'));
      }

      var query = _supabase
          .from('looks')
          .select('*, look_renders(*)')
          .eq('user_id', user.id);

      if (!includeArchived) {
        query = query.eq('is_archived', false);
      }

      final data = await query.order('created_at', ascending: false);
      final looks = (data as List<dynamic>).map((row) {
        final rowMap = row as Map<String, dynamic>;
        final rendersJson = rowMap['look_renders'] as List<dynamic>? ?? [];
        final renders = rendersJson
            .map((r) => LookRender.fromJson(r as Map<String, dynamic>))
            .toList();
        return Look.fromJson(rowMap, renders: renders);
      }).toList();

      return Success(looks);
    } catch (e, st) {
      return Error(ServerFailure(message: e.toString(), stackTrace: st));
    }
  }

  @override
  Future<Result<Look, Failure>> getLookById(String id) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return const Error(AuthFailure(message: 'User is not authenticated'));
      }

      final data = await _supabase
          .from('looks')
          .select('*, look_renders(*)')
          .eq('id', id)
          .maybeSingle();

      if (data == null) {
        return const Error(NotFoundFailure(message: 'Look not found'));
      }

      final rendersJson = data['look_renders'] as List<dynamic>? ?? [];
      final renders = rendersJson
          .map((r) => LookRender.fromJson(r as Map<String, dynamic>))
          .toList();

      return Success(Look.fromJson(data, renders: renders));
    } catch (e, st) {
      return Error(ServerFailure(message: e.toString(), stackTrace: st));
    }
  }

  @override
  Future<Result<Look, Failure>> createLook({
    required String title,
    String styleKey = 'custom',
    CutSpec? cutSpec,
    Uint8List? imageBytes,
    String? imageFileName,
    RenderView view = RenderView.front,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return const Error(AuthFailure(message: 'User is not authenticated'));
      }

      final insertedLook = await _supabase
          .from('looks')
          .insert({
            'user_id': user.id,
            'title': title,
            'style_key': styleKey,
            'cut_spec': cutSpec?.toJson(),
            'prompt_snapshot': <String, dynamic>{},
          })
          .select()
          .single();

      final lookId = insertedLook['id'] as String;
      final renders = <LookRender>[];

      // If an initial image is provided, upload to private 'renders' bucket
      if (imageBytes != null) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = imageFileName ?? 'front_$timestamp.jpg';
        final storagePath = '${user.id}/$lookId/$fileName';

        await _supabase.storage.from('renders').uploadBinary(
              storagePath,
              imageBytes,
              fileOptions: const FileOptions(contentType: 'image/jpeg'),
            );

        final insertedRender = await _supabase
            .from('look_renders')
            .insert({
              'look_id': lookId,
              'view': view.value,
              'storage_path': storagePath,
              'provider': 'manual-upload',
              'resolution': 'final',
            })
            .select()
            .single();

        renders.add(LookRender.fromJson(insertedRender));
      }

      return Success(Look.fromJson(insertedLook, renders: renders));
    } catch (e, st) {
      return Error(ServerFailure(message: e.toString(), stackTrace: st));
    }
  }

  @override
  Future<Result<({Look look, String sourcePhotoId}), Failure>>
      createLookWithHeadshots({
    required Uint8List frontImageBytes,
    Uint8List? leftImageBytes,
    Uint8List? rightImageBytes,
    Uint8List? backImageBytes,
    String title = 'My AI Hairstyle',
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return const Error(AuthFailure(message: 'User is not authenticated'));
      }

      final ts = DateTime.now().millisecondsSinceEpoch;
      final frontPath = '${user.id}/${ts}_front.jpg';

      // 1. Upload front photo to faces bucket
      await _supabase.storage.from('faces').uploadBinary(
            frontPath,
            frontImageBytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );

      // Optional angles
      if (leftImageBytes != null) {
        await _supabase.storage.from('faces').uploadBinary(
              '${user.id}/${ts}_left.jpg',
              leftImageBytes,
              fileOptions: const FileOptions(contentType: 'image/jpeg'),
            );
      }
      if (rightImageBytes != null) {
        await _supabase.storage.from('faces').uploadBinary(
              '${user.id}/${ts}_right.jpg',
              rightImageBytes,
              fileOptions: const FileOptions(contentType: 'image/jpeg'),
            );
      }
      if (backImageBytes != null) {
        await _supabase.storage.from('faces').uploadBinary(
              '${user.id}/${ts}_back.jpg',
              backImageBytes,
              fileOptions: const FileOptions(contentType: 'image/jpeg'),
            );
      }

      // 2. Insert into source_photos
      final photoRow = await _supabase
          .from('source_photos')
          .insert({
            'user_id': user.id,
            'storage_path': frontPath,
            'moderation_status': 'ok',
          })
          .select()
          .single();

      final sourcePhotoId = photoRow['id'] as String;

      // 3. Create Look associated with this source photo
      final lookRow = await _supabase
          .from('looks')
          .insert({
            'user_id': user.id,
            'source_photo_id': sourcePhotoId,
            'title': title,
            'style_key': 'custom',
            'prompt_snapshot': <String, dynamic>{},
          })
          .select()
          .single();

      final look = Look.fromJson(lookRow);
      return Success((look: look, sourcePhotoId: sourcePhotoId));
    } catch (e, st) {
      return Error(ServerFailure(message: e.toString(), stackTrace: st));
    }
  }

  @override
  Future<Result<void, Failure>> archiveLook(String id) async {
    try {
      await _supabase.from('looks').update({'is_archived': true}).eq('id', id);
      return const Success(null);
    } catch (e, st) {
      return Error(ServerFailure(message: e.toString(), stackTrace: st));
    }
  }
}
