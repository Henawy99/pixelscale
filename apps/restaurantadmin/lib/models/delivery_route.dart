// lib/models/delivery_route.dart
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;
import 'package:restaurantadmin/models/route_stop.dart'; // Adjusted import path
import 'package:flutter_polyline_points/flutter_polyline_points.dart'; // Added import

class DeliveryRoute {
  final String id; // Unique ID for the route (e.g., UUID)
  final String assignedDriverId;
  final List<RouteStop> stops; // Ordered list of stops
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String status; // e.g., "pending_assignment", "assigned", "in_progress", "completed", "cancelled"
  final double totalEstimatedDistanceMeters;
  final double totalEstimatedDurationSeconds; // Includes travel and service times
  final LatLng storeCoordinates; // Starting and ending point (depot)
  final List<LatLng> polylinePoints; // Full route polyline for map display
  final String brandId; // To associate route with a store/brand

  DeliveryRoute({
    required this.id,
    required this.assignedDriverId,
    required this.stops,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
    required this.status,
    required this.totalEstimatedDistanceMeters,
    required this.totalEstimatedDurationSeconds,
    required this.storeCoordinates,
    required this.polylinePoints,
    required this.brandId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'assigned_driver_id': assignedDriverId,
      'stops': stops.map((stop) => stop.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
      'started_at': startedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'status': status,
      'total_estimated_distance_meters': totalEstimatedDistanceMeters,
      'total_estimated_duration_seconds': totalEstimatedDurationSeconds,
      'store_latitude': storeCoordinates.latitude,
      'store_longitude': storeCoordinates.longitude,
      'polyline_points': polylinePoints.map((p) => {'latitude': p.latitude, 'longitude': p.longitude}).toList(),
      'brand_id': brandId,
    };
  }

  factory DeliveryRoute.fromJson(Map<String, dynamic> json) {
    var stopsList = json['stops'] as List<dynamic>? ?? [];
    List<LatLng> decodedPolylinePoints = [];
    
    if (json['polyline_points'] != null && json['polyline_points'] is String) {
      PolylinePoints polylinePointsDecoder = PolylinePoints();
      List<PointLatLng> result = polylinePointsDecoder.decodePolyline(json['polyline_points'] as String);
      if (result.isNotEmpty) {
        decodedPolylinePoints = result.map((point) => LatLng(point.latitude, point.longitude)).toList();
      }
    } else if (json['polyline_points'] != null && json['polyline_points'] is List) {
      // Fallback for old format if any data exists like that, or handle error
      // This part assumes the old (incorrect) format of List<Map<String, double>>
      var polylinePointsList = json['polyline_points'] as List<dynamic>;
       decodedPolylinePoints = polylinePointsList.map((p) {
        final map = p as Map<String, dynamic>;
        return LatLng(
          (map['latitude'] as num).toDouble(),
          (map['longitude'] as num).toDouble(),
        );
      }).toList();
    }


    return DeliveryRoute(
      id: json['id'] as String,
      assignedDriverId: json['assigned_driver_id'] as String,
      stops: stopsList.map((stopJson) => RouteStop.fromJson(stopJson as Map<String, dynamic>)).toList(),
      createdAt: DateTime.parse(json['created_at'] as String),
      startedAt: json['started_at'] == null ? null : DateTime.parse(json['started_at'] as String),
      completedAt: json['completed_at'] == null ? null : DateTime.parse(json['completed_at'] as String),
      status: json['status'] as String,
      totalEstimatedDistanceMeters: (json['total_estimated_distance_meters'] as num).toDouble(),
      totalEstimatedDurationSeconds: (json['total_estimated_duration_seconds'] as num).toDouble(),
      storeCoordinates: LatLng(
        (json['store_latitude'] as num).toDouble(),
        (json['store_longitude'] as num).toDouble(),
      ),
      polylinePoints: decodedPolylinePoints, // Use decoded points
      brandId: json['brand_id'] as String,
    );
  }
}
