import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mycut_core/mycut_core.dart';
import 'package:mycut_cutspec/mycut_cutspec.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider for the [LooksRepository]. Defaults to [SupabaseLooksRepository].
final looksRepositoryProvider = Provider<LooksRepository>((ref) {
  return SupabaseLooksRepository(Supabase.instance.client);
});

/// Provider for the [ShareRepository]. Defaults to [SupabaseShareRepository].
final shareRepositoryProvider = Provider<ShareRepository>((ref) {
  return SupabaseShareRepository(Supabase.instance.client);
});

/// Notifier managing customer looks.
class LooksNotifier extends StateNotifier<AsyncValue<List<Look>>> {
  LooksNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadLooks();
  }

  final LooksRepository _repository;

  Future<void> loadLooks() async {
    state = const AsyncValue.loading();
    final result = await _repository.getLooks();
    state = switch (result) {
      Success(:final value) => AsyncValue.data(value),
      Error(:final failure) => AsyncValue.error(
          failure.message,
          failure.stackTrace ?? StackTrace.current,
        ),
    };
  }

  Future<Look?> saveLook({
    required String title,
    String styleKey = 'custom',
    CutSpec? cutSpec,
    Uint8List? imageBytes,
    String? imageFileName,
  }) async {
    final result = await _repository.createLook(
      title: title,
      styleKey: styleKey,
      cutSpec: cutSpec,
      imageBytes: imageBytes,
      imageFileName: imageFileName,
    );

    return switch (result) {
      Success(:final value) => () {
          final current = state.valueOrNull ?? [];
          state = AsyncValue.data([value, ...current]);
          return value;
        }(),
      Error() => null,
    };
  }
}

/// Provider exposing the list of customer looks.
final looksListProvider =
    StateNotifierProvider<LooksNotifier, AsyncValue<List<Look>>>((ref) {
  final repo = ref.watch(looksRepositoryProvider);
  return LooksNotifier(repo);
});
