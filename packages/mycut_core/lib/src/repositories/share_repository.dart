import 'package:mycut_core/src/failures.dart';
import 'package:mycut_core/src/models/consultation.dart';
import 'package:mycut_core/src/models/look_share.dart';
import 'package:mycut_core/src/result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Contract for managing look share codes and watching consultation status.
abstract class ShareRepository {
  /// Generates or rotates an ephemeral 30-min share code for [lookId].
  Future<Result<LookShare, Failure>> rotateShareCode(String lookId);

  /// Listens to real-time consultation events for [lookId].
  ///
  /// Emits a [Consultation] immediately when a barber tablet scans the QR code.
  Stream<Consultation> watchConsultationsForLook(String lookId);
}

/// Supabase-backed implementation of [ShareRepository].
class SupabaseShareRepository implements ShareRepository {
  const SupabaseShareRepository(this._supabase);

  final SupabaseClient _supabase;

  @override
  Future<Result<LookShare, Failure>> rotateShareCode(String lookId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return const Error(AuthFailure(message: 'User is not authenticated'));
      }

      final response = await _supabase.rpc<Map<String, dynamic>>(
        'rotate_share_code',
        params: {'p_look_id': lookId},
      );

      final data = response;
      final code = data['code'] as String? ?? '';
      final share = LookShare(
        code: code,
        lookId: lookId,
        userId: user.id,
        expiresAt: DateTime.parse(data['expires_at'] as String),
        shareUrl: data['share_url'] as String? ?? 'https://mycut.app/l/$code',
      );

      return Success(share);
    } catch (e, st) {
      return Error(ServerFailure(message: e.toString(), stackTrace: st));
    }
  }

  @override
  Stream<Consultation> watchConsultationsForLook(String lookId) {
    return _supabase
        .from('consultations')
        .stream(primaryKey: ['id'])
        .eq('look_id', lookId)
        .map((rows) {
          if (rows.isEmpty) {
            throw StateError('No consultations');
          }
          return Consultation.fromJson(rows.last);
        })
        .handleError((dynamic _) {
          // Swallow stream errors (e.g. empty list on initial listen)
        });
  }
}
