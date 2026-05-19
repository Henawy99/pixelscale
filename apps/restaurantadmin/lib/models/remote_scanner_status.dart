/// Model representing the status of a remote receipt scanner.
///
/// Data is read from the `scanner_heartbeats` Supabase table and kept
/// up-to-date via realtime subscriptions.
class RemoteScannerStatus {
  final String scannerId;
  final String scannerName;
  final String hostname;
  final String watchPath;
  final String status;
  final DateTime lastHeartbeat;
  final DateTime updatedAt;

  RemoteScannerStatus({
    required this.scannerId,
    required this.scannerName,
    required this.hostname,
    required this.watchPath,
    required this.status,
    required this.lastHeartbeat,
    required this.updatedAt,
  });

  factory RemoteScannerStatus.fromJson(Map<String, dynamic> json) {
    return RemoteScannerStatus(
      scannerId: json['scanner_id'] as String? ?? '',
      scannerName: json['scanner_name'] as String? ?? 'Unknown Scanner',
      hostname: json['hostname'] as String? ?? 'unknown',
      watchPath: json['watch_path'] as String? ?? '',
      status: json['status'] as String? ?? 'offline',
      lastHeartbeat:
          DateTime.tryParse(json['last_heartbeat'] as String? ?? '') ??
              DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updated_at'] as String? ?? '') ??
              DateTime.now(),
    );
  }

  /// A scanner is considered online if its status is `'online'` AND
  /// the last heartbeat was received within the last 90 seconds.
  bool get isOnline {
    if (status != 'online') return false;
    final secondsSinceHeartbeat =
        DateTime.now().difference(lastHeartbeat).inSeconds;
    return secondsSinceHeartbeat < 90;
  }
}
