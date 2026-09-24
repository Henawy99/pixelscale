import 'package:mycut_core/src/models/look.dart';

/// A logged consultation event occurring when a barber tablet redeems
/// a look QR code.
class Consultation {
  const Consultation({
    required this.id,
    required this.lookId,
    this.deviceId,
    this.salonId,
    this.barberId,
    this.notes,
    this.afterPhotoPath,
    this.scannedAt,
  });

  factory Consultation.fromJson(Map<String, dynamic> json) {
    return Consultation(
      id: json['id'] as String? ?? '',
      lookId: json['look_id'] as String? ?? '',
      deviceId: json['device_id'] as String?,
      salonId: json['salon_id'] as String?,
      barberId: json['barber_id'] as String?,
      notes: json['notes'] as String?,
      afterPhotoPath: json['after_photo_path'] as String?,
      scannedAt: json['scanned_at'] != null
          ? DateTime.tryParse(json['scanned_at'] as String)
          : null,
    );
  }

  final String id;
  final String lookId;
  final String? deviceId;
  final String? salonId;
  final String? barberId;
  final String? notes;
  final String? afterPhotoPath;
  final DateTime? scannedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'look_id': lookId,
        if (deviceId != null) 'device_id': deviceId,
        if (salonId != null) 'salon_id': salonId,
        if (barberId != null) 'barber_id': barberId,
        if (notes != null) 'notes': notes,
        if (afterPhotoPath != null) 'after_photo_path': afterPhotoPath,
        if (scannedAt != null) 'scanned_at': scannedAt!.toIso8601String(),
      };
}

/// The decoded data returned to the Receiver app upon redeeming a share code.
class RedeemedLookPayload {
  const RedeemedLookPayload({
    required this.consultationId,
    required this.look,
    required this.renders,
    required this.customerFirstName,
    required this.scannedAt,
  });

  factory RedeemedLookPayload.fromJson(Map<String, dynamic> json) {
    final rendersJson = json['renders'] as List<dynamic>? ?? [];
    final renders = rendersJson
        .map((r) => LookRender.fromJson(r as Map<String, dynamic>))
        .toList();

    return RedeemedLookPayload(
      consultationId: json['consultation_id'] as String? ?? '',
      look: Look.fromJson(
        json['look'] as Map<String, dynamic>? ?? {},
        renders: renders,
      ),
      renders: renders,
      customerFirstName: json['customer_first_name'] as String? ?? 'Customer',
      scannedAt: json['scanned_at'] != null
          ? DateTime.tryParse(json['scanned_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  final String consultationId;
  final Look look;
  final List<LookRender> renders;
  final String customerFirstName;
  final DateTime scannedAt;
}
