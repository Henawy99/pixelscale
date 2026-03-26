// lib/models/driver_availability.dart
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;

class DriverAvailability {
  final String driverId;
  final String? driverName;
  final bool isOnline;
  final LatLng? lastKnownLocation;
  final DateTime lastUpdated;

  DriverAvailability({
    required this.driverId,
    this.driverName,
    required this.isOnline,
    this.lastKnownLocation,
    required this.lastUpdated,
  });

  Map<String, dynamic> toJson() {
    return {
      'driver_id': driverId,
      'driver_name': driverName,
      'is_online': isOnline,
      'last_known_latitude': lastKnownLocation?.latitude,
      'last_known_longitude': lastKnownLocation?.longitude,
      'last_updated': lastUpdated.toIso8601String(),
    };
  }

  factory DriverAvailability.fromJson(Map<String, dynamic> json) {
    LatLng? location;
    if (json['last_known_latitude'] != null && json['last_known_longitude'] != null) {
      location = LatLng(
        (json['last_known_latitude'] as num).toDouble(),
        (json['last_known_longitude'] as num).toDouble(),
      );
    }
    
    return DriverAvailability(
      driverId: json['driver_id'] as String,
      driverName: json['driver_name'] as String?,
      isOnline: json['is_online'] as bool? ?? false,
      lastKnownLocation: location,
      lastUpdated: DateTime.parse(json['last_updated'] as String),
    );
  }

  DriverAvailability copyWith({
    String? driverId,
    String? driverName,
    bool? isOnline,
    LatLng? lastKnownLocation,
    DateTime? lastUpdated,
  }) {
    return DriverAvailability(
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      isOnline: isOnline ?? this.isOnline,
      lastKnownLocation: lastKnownLocation ?? this.lastKnownLocation,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
