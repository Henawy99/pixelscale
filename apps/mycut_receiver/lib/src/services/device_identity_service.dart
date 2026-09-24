import 'dart:math';

/// Service managing persistent tablet device fingerprinting.
class DeviceIdentityService {
  DeviceIdentityService._();

  static String? _cachedFingerprint;

  /// Returns a stable device fingerprint for this receiver station.
  static String getDeviceFingerprint() {
    if (_cachedFingerprint != null) {
      return _cachedFingerprint!;
    }

    // Generate pseudo-random UUID format for local session
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // UUID v4
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    _cachedFingerprint = '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';

    return _cachedFingerprint!;
  }
}
