import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng; // Optional for current location

class Driver {
  final String id; // Corresponds to the 'id' in your Supabase 'drivers' table (UUID)
  final String? userId; // Corresponds to the 'user_id' in 'drivers' table, which links to 'auth.users.id'
  String name;
  bool isOnline;
  LatLng? currentLocation; // Optional: For real-time location tracking on the map
  DateTime? lastSeenAt;
  final String? currentDeliveryRouteId; // Added field
  final DateTime? createdAt; // When the driver was added
  final int colorIndex; // Employee color index (0-7)

  Driver({
    required this.id,
    this.userId,
    required this.name,
    this.isOnline = false,
    this.currentLocation,
    this.lastSeenAt,
    this.currentDeliveryRouteId, // Added to constructor
    this.createdAt,
    this.colorIndex = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'is_online': isOnline,
      // currentLocation is typically not directly stored in the main driver record this way,
      // but rather updated frequently or fetched from a separate location tracking table/service.
      // For simplicity in the model, it's included but might not be part of toJson for DB persistence.
      'last_seen_at': lastSeenAt?.toIso8601String(),
      'current_delivery_route_id': currentDeliveryRouteId, // Added to toJson
    };
  }

  /// Parse a timestamp string from Supabase, ensuring it's treated as UTC.
  /// Supabase often returns UTC timestamps without the 'Z' suffix, which causes
  /// Dart's DateTime.tryParse to treat them as local time — leading to wrong
  /// times being displayed after .toLocal() conversion.
  static DateTime? _parseUtcTimestamp(String? s) {
    if (s == null) return null;
    final dt = DateTime.tryParse(s);
    if (dt == null) return null;
    // If already UTC, return as-is. Otherwise, re-create as UTC since
    // Supabase stores everything in UTC.
    return dt.isUtc
        ? dt
        : DateTime.utc(dt.year, dt.month, dt.day, dt.hour, dt.minute,
            dt.second, dt.millisecond, dt.microsecond);
  }

  factory Driver.fromJson(Map<String, dynamic> json) {
    double? lat = (json['current_latitude'] as num?)?.toDouble();
    double? lng = (json['current_longitude'] as num?)?.toDouble();
    LatLng? location;
    if (lat != null && lng != null) {
      location = LatLng(lat, lng);
    }

    // Generate a stable color index from driver ID if not stored
    int colorIdx = (json['color_index'] as int?) ?? 0;
    if (colorIdx == 0 && json['id'] != null) {
      // Use hash of ID to get a consistent color
      colorIdx = (json['id'] as String).hashCode.abs() % 8;
    }

    return Driver(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      name: json['name'] as String? ?? 'Unnamed Driver',
      isOnline: json['is_online'] as bool? ?? false,
      lastSeenAt: _parseUtcTimestamp(json['last_seen_at'] as String?),
      currentLocation: location, // Populate from parsed lat/lng
      currentDeliveryRouteId: json['current_route_id'] as String?, // Fetches current_route_id from DB
      createdAt: _parseUtcTimestamp(json['created_at'] as String?),
      colorIndex: colorIdx,
    );
  }
}
