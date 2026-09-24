import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mycut_core/mycut_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider for the [GenerationRepository].
final generationRepositoryProvider = Provider<GenerationRepository>((ref) {
  return SupabaseGenerationRepository(Supabase.instance.client);
});

/// The current credit balance for the authenticated user.
final creditsProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(generationRepositoryProvider);
  final result = await repo.getCredits();
  return switch (result) {
    Success(:final value) => value,
    Error() => 0,
  };
});

/// State for a generation request in progress.
class GenerationState {
  const GenerationState({
    this.job,
    this.renders = const [],
    this.isRequesting = false,
    this.error,
  });

  final GenerationJob? job;
  final List<LookRender> renders;
  final bool isRequesting;
  final String? error;

  GenerationState copyWith({
    GenerationJob? job,
    List<LookRender>? renders,
    bool? isRequesting,
    String? error,
  }) {
    return GenerationState(
      job: job ?? this.job,
      renders: renders ?? this.renders,
      isRequesting: isRequesting ?? this.isRequesting,
      error: error,
    );
  }

  bool get isComplete =>
      job?.status == GenerationJobStatus.succeeded && renders.isNotEmpty;

  bool get isFailed => job?.status == GenerationJobStatus.failed;

  bool get isRunning =>
      job?.status == GenerationJobStatus.running ||
      job?.status == GenerationJobStatus.queued;
}

/// Notifier managing a single generation request lifecycle.
class GenerationNotifier extends StateNotifier<GenerationState> {
  GenerationNotifier(this._repo, this._looksRepo)
      : super(const GenerationState());

  final GenerationRepository _repo;
  final LooksRepository _looksRepo;

  /// Starts a new generation request.
  Future<void> generate({
    required String lookId,
    required String sourcePhotoId,
    required String styleKey,
  }) async {
    state = state.copyWith(isRequesting: true);

    final result = await _repo.requestGeneration(
      lookId: lookId,
      sourcePhotoId: sourcePhotoId,
      styleKey: styleKey,
    );

    switch (result) {
      case Success(:final value):
        state = state.copyWith(job: value, isRequesting: false);
        // Start watching for status updates
        _watchJobStatus(value.id, lookId);
      case Error(:final failure):
        state = state.copyWith(
          isRequesting: false,
          error: failure.message,
        );
    }
  }

  void _watchJobStatus(String jobId, String lookId) {
    _repo.watchJob(jobId).listen((job) {
      state = state.copyWith(job: job);

      // When succeeded, fetch the renders
      if (job.status == GenerationJobStatus.succeeded) {
        _fetchRenders(lookId);
      }
    });
  }

  Future<void> _fetchRenders(String lookId) async {
    final result = await _looksRepo.getLookById(lookId);
    switch (result) {
      case Success(:final value):
        // Filter for preview renders from this generation
        final previewRenders = value.renders
            .where((r) => r.resolution == 'preview' && r.provider == 'gemini')
            .toList();
        state = state.copyWith(renders: previewRenders);
      case Error():
        break;
    }
  }

  /// Resets the state for a new generation attempt.
  void reset() {
    state = const GenerationState();
  }
}

/// Provider for a generation notifier scoped to the explore screen.
final generationNotifierProvider =
    StateNotifierProvider.autoDispose<GenerationNotifier, GenerationState>(
        (ref) {
  final genRepo = ref.watch(generationRepositoryProvider);
  final looksRepo = ref.watch(
    Provider<LooksRepository>(
      (ref) => SupabaseLooksRepository(Supabase.instance.client),
    ),
  );
  return GenerationNotifier(genRepo, looksRepo);
});

/// Stream provider for watching a specific job's status.
final jobStreamProvider =
    StreamProvider.family<GenerationJob, String>((ref, jobId) {
  final repo = ref.watch(generationRepositoryProvider);
  return repo.watchJob(jobId);
});
