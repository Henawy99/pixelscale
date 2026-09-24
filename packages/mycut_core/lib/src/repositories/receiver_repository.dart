import 'package:mycut_core/src/failures.dart';
import 'package:mycut_core/src/models/consultation.dart';
import 'package:mycut_core/src/models/look.dart';
import 'package:mycut_core/src/result.dart';
import 'package:mycut_core/src/utils/crockford_base32.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Contract for the Barber Receiver station app.
abstract class ReceiverRepository {
  /// Redeems an 8-character share code, registering device activity
  /// and retrieving the customer's Look, signed render URLs, and CutSpec.
  Future<Result<RedeemedLookPayload, Failure>> redeemCode({
    required String code,
    required String deviceFingerprint,
  });

  /// Fetches recent consultations for this receiver device.
  Future<Result<List<Consultation>, Failure>> getRecentConsultations({
    required String deviceFingerprint,
    int limit = 50,
  });
}

/// Supabase-backed implementation of [ReceiverRepository].
class SupabaseReceiverRepository implements ReceiverRepository {
  const SupabaseReceiverRepository(this._supabase);

  final SupabaseClient _supabase;

  @override
  Future<Result<List<Consultation>, Failure>> getRecentConsultations({
    required String deviceFingerprint,
    int limit = 50,
  }) async {
    try {
      final rows = await _supabase
          .from('consultations')
          .select('*, receiver_devices!inner(device_fingerprint)')
          .eq('receiver_devices.device_fingerprint', deviceFingerprint)
          .order('scanned_at', ascending: false)
          .limit(limit);

      final consultations = (rows as List<dynamic>)
          .map((r) => Consultation.fromJson(r as Map<String, dynamic>))
          .toList();

      return Success(consultations);
    } catch (e, st) {
      return Error(ServerFailure(message: e.toString(), stackTrace: st));
    }
  }

  @override
  Future<Result<RedeemedLookPayload, Failure>> redeemCode({
    required String code,
    required String deviceFingerprint,
  }) async {
    try {
      final normalizedCode = CrockfordBase32.normalize(code);
      if (normalizedCode.length != 8) {
        return const Error(
          ValidationFailure(
            message: 'Invalid code format. Expected 8 characters.',
          ),
        );
      }

      final response = await _supabase.rpc<Map<String, dynamic>>(
        'redeem_share_code',
        params: {
          'p_code': normalizedCode,
          'p_device_fingerprint': deviceFingerprint,
        },
      );

      final data = response;
      final rawRenders = data['renders'] as List<dynamic>? ?? [];

      // Generate 15-minute signed URLs for each render
      final rendersWithSignedUrls = await Future.wait(
        rawRenders.map((r) async {
          final renderMap = r as Map<String, dynamic>;
          final storagePath = renderMap['storage_path'] as String? ?? '';
          String? signedUrl;

          if (storagePath.isNotEmpty) {
            try {
              signedUrl = await _supabase.storage
                  .from('renders')
                  .createSignedUrl(storagePath, 900); // 15 min
            } catch (_) {
              // Graceful fallback if storage object unavailable
            }
          }

          return LookRender(
            id: renderMap['id'] as String? ?? '',
            lookId: renderMap['look_id'] as String? ?? '',
            view: RenderView.fromValue(renderMap['view'] as String? ?? 'front'),
            storagePath: storagePath,
            resolution: renderMap['resolution'] as String? ?? 'final',
            signedUrl: signedUrl,
          );
        }),
      );

      final payload = RedeemedLookPayload(
        consultationId: data['consultation_id'] as String? ?? '',
        look: Look.fromJson(
          data['look'] as Map<String, dynamic>? ?? {},
          renders: rendersWithSignedUrls,
        ),
        renders: rendersWithSignedUrls,
        customerFirstName: data['customer_first_name'] as String? ?? 'Customer',
        scannedAt: data['scanned_at'] != null
            ? DateTime.tryParse(data['scanned_at'] as String) ?? DateTime.now()
            : DateTime.now(),
      );

      return Success(payload);
    } catch (e, st) {
      return Error(ServerFailure(message: e.toString(), stackTrace: st));
    }
  }
}
