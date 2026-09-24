import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mycut_core/mycut_core.dart';
import 'package:mycut_receiver/src/services/device_identity_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider for the [ReceiverRepository].
final receiverRepositoryProvider = Provider<ReceiverRepository>((ref) {
  return SupabaseReceiverRepository(Supabase.instance.client);
});

/// State of the Receiver station app.
sealed class ReceiverState {
  const ReceiverState();
}

class ReceiverIdle extends ReceiverState {
  const ReceiverIdle();
}

class ReceiverRedeeming extends ReceiverState {
  const ReceiverRedeeming();
}

class ReceiverActiveLook extends ReceiverState {
  const ReceiverActiveLook(this.payload);
  final RedeemedLookPayload payload;
}

class ReceiverError extends ReceiverState {
  const ReceiverError(this.message);
  final String message;
}

/// Notifier handling barcode scanning, redemption, and consultation state.
class ReceiverNotifier extends StateNotifier<ReceiverState> {
  ReceiverNotifier(this._repository) : super(const ReceiverIdle());

  final ReceiverRepository _repository;
  int _scansToday = 0;

  int get scansToday => _scansToday;

  Future<bool> redeemCode(String rawCode) async {
    state = const ReceiverRedeeming();

    // If input is a full URL (e.g. https://mycut.app/l/K7M4XQ2P), extract code
    var code = rawCode.trim();
    if (code.contains('/l/')) {
      code = code.split('/l/').last;
    }

    final fingerprint = DeviceIdentityService.getDeviceFingerprint();
    final result = await _repository.redeemCode(
      code: code,
      deviceFingerprint: fingerprint,
    );

    return switch (result) {
      Success(:final value) => () {
          _scansToday++;
          state = ReceiverActiveLook(value);
          return true;
        }(),
      Error(:final failure) => () {
          state = ReceiverError(failure.message);
          return false;
        }(),
    };
  }

  void resetToIdle() {
    state = const ReceiverIdle();
  }
}

/// Provider managing receiver station state.
final receiverProvider =
    StateNotifierProvider<ReceiverNotifier, ReceiverState>((ref) {
  final repo = ref.watch(receiverRepositoryProvider);
  return ReceiverNotifier(repo);
});
