import 'package:mycut_core/src/failures.dart';
import 'package:mycut_core/src/models/generation_job.dart';
import 'package:mycut_core/src/result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Contract for AI hairstyle generation operations.
abstract class GenerationRepository {
  /// Requests a new AI generation via the `generate-look` Edge Function.
  ///
  /// Returns the created [GenerationJob] with status `queued`.
  /// Fails with [InsufficientCreditsFailure] if the user has no credits.
  Future<Result<GenerationJob, Failure>> requestGeneration({
    required String lookId,
    required String sourcePhotoId,
    required String styleKey,
    int variations = 4,
  });

  /// Returns a real-time stream of [GenerationJob] updates for [jobId].
  ///
  /// The stream emits a new value whenever the job's status changes
  /// (e.g., queued → running → succeeded).
  Stream<GenerationJob> watchJob(String jobId);

  /// Fetches all generation jobs for a given [lookId].
  Future<Result<List<GenerationJob>, Failure>> getJobsForLook(String lookId);

  /// Returns the current credit balance for the authenticated user.
  Future<Result<int, Failure>> getCredits();
}

/// Supabase-backed implementation of [GenerationRepository].
class SupabaseGenerationRepository implements GenerationRepository {
  const SupabaseGenerationRepository(this._supabase);

  final SupabaseClient _supabase;

  @override
  Future<Result<GenerationJob, Failure>> requestGeneration({
    required String lookId,
    required String sourcePhotoId,
    required String styleKey,
    int variations = 4,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return const Error(AuthFailure(message: 'User is not authenticated'));
      }

      final response = await _supabase.functions.invoke(
        'generate-look',
        body: {
          'lookId': lookId,
          'sourcePhotoId': sourcePhotoId,
          'styleKey': styleKey,
          'variations': variations,
        },
      );

      if (response.status == 402) {
        return const Error(
          InsufficientCreditsFailure(
            message: 'Not enough credits to generate a look',
          ),
        );
      }

      if (response.status != 200) {
        final error = response.data is Map
            ? (response.data as Map)['error']?.toString() ?? 'Unknown error'
            : 'Server error (${response.status})';
        return Error(
          ServerFailure(message: error, statusCode: response.status),
        );
      }

      final data = response.data as Map<String, dynamic>;
      final job = GenerationJob.fromJson(
        data['job'] as Map<String, dynamic>,
      );

      return Success(job);
    } catch (e, st) {
      return Error(ServerFailure(message: e.toString(), stackTrace: st));
    }
  }

  @override
  Stream<GenerationJob> watchJob(String jobId) {
    return _supabase
        .from('generation_jobs')
        .stream(primaryKey: ['id'])
        .eq('id', jobId)
        .map((rows) {
          if (rows.isEmpty) {
            return GenerationJob(
              id: jobId,
              userId: '',
              lookId: '',
              styleKey: '',
              status: GenerationJobStatus.failed,
              errorMessage: 'Job not found',
            );
          }
          return GenerationJob.fromJson(rows.first);
        });
  }

  @override
  Future<Result<List<GenerationJob>, Failure>> getJobsForLook(
    String lookId,
  ) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return const Error(AuthFailure(message: 'User is not authenticated'));
      }

      final data = await _supabase
          .from('generation_jobs')
          .select()
          .eq('look_id', lookId)
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      final jobs = (data as List<dynamic>)
          .map(
            (row) =>
                GenerationJob.fromJson(row as Map<String, dynamic>),
          )
          .toList();

      return Success(jobs);
    } catch (e, st) {
      return Error(ServerFailure(message: e.toString(), stackTrace: st));
    }
  }

  @override
  Future<Result<int, Failure>> getCredits() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return const Error(AuthFailure(message: 'User is not authenticated'));
      }

      final result = await _supabase.rpc<int>(
        'get_credits',
        params: {'p_user_id': user.id},
      );

      return Success(result);
    } catch (e, st) {
      return Error(ServerFailure(message: e.toString(), stackTrace: st));
    }
  }
}
