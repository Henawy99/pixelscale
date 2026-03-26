// lib/models/route_stop.dart
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;

enum RouteStopType { store, customerDelivery }

class RouteStop {
  final String id; // Unique ID for the stop (e.g., UUID)
  final String? orderId; // Null if it's a store stop
  final RouteStopType type; // 'store' or 'customerDelivery'
  final int sequenceNumber; // Order in the route
  final LatLng coordinates;
  final String? customerName; // If type is customerDelivery
  final String? customerAddress; // If type is customerDelivery (full address for display)
  final DateTime estimatedArrivalTime;
  final DateTime? actualArrivalTime;
  final DateTime? departureTime; // When driver leaves this stop (actual or estimated for planning)
  final String status; // e.g., "pending", "in_progress", "completed", "skipped", "failed"
  final double estimatedTravelTimeToNextStopSeconds; // Duration from this stop to the next
  final double estimatedServiceTimeSeconds; // Time spent at this stop (e.g., handover)

  RouteStop({
    required this.id,
    this.orderId,
    required this.type,
    required this.sequenceNumber,
    required this.coordinates,
    this.customerName,
    this.customerAddress,
    required this.estimatedArrivalTime,
    this.actualArrivalTime,
    this.departureTime,
    required this.status,
    required this.estimatedTravelTimeToNextStopSeconds,
    required this.estimatedServiceTimeSeconds,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      'type': type.toString().split('.').last, // "store" or "customerDelivery"
      'sequence_number': sequenceNumber,
      'latitude': coordinates.latitude,
      'longitude': coordinates.longitude,
      'customer_name': customerName,
      'customer_address': customerAddress,
      'estimated_arrival_time': estimatedArrivalTime.toIso8601String(),
      'actual_arrival_time': actualArrivalTime?.toIso8601String(),
      'departure_time': departureTime?.toIso8601String(),
      'status': status,
      'estimated_travel_time_to_next_stop_seconds': estimatedTravelTimeToNextStopSeconds,
      'estimated_service_time_seconds': estimatedServiceTimeSeconds,
    };
  }

  factory RouteStop.fromJson(Map<String, dynamic> json) {
    return RouteStop(
      id: json['id'] as String,
      orderId: json['order_id'] as String?,
      type: RouteStopType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => RouteStopType.customerDelivery, // Default or throw error
      ),
      sequenceNumber: (json['sequence_number'] as num).toInt(),
      coordinates: LatLng(
        (json['latitude'] as num).toDouble(),
        (json['longitude'] as num).toDouble(),
      ),
      customerName: json['customer_name'] as String?,
      customerAddress: json['customer_address'] as String?,
      estimatedArrivalTime: DateTime.parse(json['estimated_arrival_time'] as String),
      actualArrivalTime: json['actual_arrival_time'] == null
          ? null
          : DateTime.parse(json['actual_arrival_time'] as String),
      departureTime: json['departure_time'] == null
          ? null
          : DateTime.parse(json['departure_time'] as String),
      status: json['status'] as String,
      estimatedTravelTimeToNextStopSeconds: (json['estimated_travel_time_to_next_stop_seconds'] as num).toDouble(),
      estimatedServiceTimeSeconds: (json['estimated_service_time_seconds'] as num).toDouble(),
    );
  }
}
