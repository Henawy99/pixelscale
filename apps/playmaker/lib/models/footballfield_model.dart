// import 'package:cloud_firestore/cloud_firestore.dart'; // Removed - using Supabase

class FootballField {
  final String id;
  final String footballFieldName;
  final String locationName;
  final String streetName;
  final List<String> photos;
  final String openingHours;
  final bool bookable;
  final List<String> bookings;
  final double latitude;
  final double longitude;
  final String priceRange;
  final Map<String, List<Map<String, dynamic>>> availableTimeSlots;
  final String commissionPercentage;
  final String username;
  final String password;
  final Map<String, bool> amenities;
  final String fieldSize;  // "5-a-side" or "7-a-side"
  final String? cameraUsername;
  final String? cameraPassword;
  final String? cameraIpAddress;
  final String? raspberryPiIp;
  final String? routerIp;
  final String? simCardNumber;
  final bool hasCamera;
  
  // Owner & Assistant Contact Details
  final String? ownerName;
  final String? ownerPhoneNumber;
  // Dynamic list of assistants (each has name and phone)
  final List<Map<String, String>> assistants;
  
  // Metadata
  final DateTime? createdAt;
  final String? city;
  final String? area;
  
  // Blocked users list (user IDs who are blocked from booking this field)
  final List<String> blockedUsers;
  
  // Field enabled status (if false, field is hidden from user app)
  final bool isEnabled;

  FootballField({
    required this.id,
    required this.footballFieldName,
    required this.locationName,
    required this.streetName,
    required this.photos,
    required this.openingHours,
    required this.bookable,
    required this.bookings,
    required this.latitude,
    required this.longitude,
    required this.priceRange,
    required this.availableTimeSlots,
    required this.commissionPercentage,
    required this.username,
    required this.password,
    required this.amenities,
    required this.fieldSize,
    this.cameraUsername,
    this.cameraPassword,
    this.cameraIpAddress,
    this.raspberryPiIp,
    this.routerIp,
    this.simCardNumber,
    this.hasCamera = false,
    this.ownerName,
    this.ownerPhoneNumber,
    List<Map<String, String>>? assistants,
    this.createdAt,
    this.city,
    this.area,
    List<String>? blockedUsers,
    this.isEnabled = true,
  }) : assistants = assistants ?? [],
       blockedUsers = blockedUsers ?? [];

  // Deprecated: Use fromMap() instead (Supabase migration)
  // factory FootballField.fromFirestore(DocumentSnapshot doc) {
  //   Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
  //
  //   // Convert availableTimeSlots to Map<String, List<Map<String, dynamic>>>
  //   Map<String, List<Map<String, dynamic>>> timeSlots = {};
  //   if (data['availableTimeSlots'] != null) {
  //     data['availableTimeSlots'].forEach((key, value) {
  //       if (value is List) {
  //         timeSlots[key] = List<Map<String, dynamic>>.from(value.map((item) => item as Map<String, dynamic>));
  //       }
  //     });
  //   }
  //
  //   return FootballField(
  //     id: doc.id,
  //     footballFieldName: data['footballFieldName'] ?? '',
  //     locationName: data['locationName'] ?? '',
  //     streetName: data['streetName'] ?? '',
  //     photos: List<String>.from(data['photos'] ?? []),
  //     openingHours: data['openingHours'] ?? '',
  //     bookable: data['bookable'] ?? false,
  //     bookings: List<String>.from(data['bookings'] ?? []),
  //     latitude: data['latitude']?.toDouble() ?? 0.0,
  //     longitude: data['longitude']?.toDouble() ?? 0.0,
  //     priceRange: data['priceRange'] ?? '',
  //     availableTimeSlots: timeSlots,
  //     commissionPercentage: data['commissionPercentage'] ?? '',
  //     username: data['username'] ?? '',
  //     password: data['password'] ?? '',
  //     amenities: Map<String, bool>.from(data['amenities'] ?? {
  //       'parking': false,
  //       'toilets': false,
  //       'cafeteria': false,
  //       'floodlights': false,
  //       'qualityField': false,
  //       'ballIncluded': false,
  //       'cameraRecording': false,
  //     }),
  //     fieldSize: data['fieldSize'] ?? '5-a-side',
  //     cameraUsername: data['cameraUsername'],
  //     cameraPassword: data['cameraPassword'],
  //     cameraIpAddress: data['cameraIpAddress'],
  //     raspberryPiIp: data['raspberryPiIp'],
  //     routerIp: data['routerIp'],
  //     simCardNumber: data['simCardNumber'],
  //     hasCamera: (data['amenities'] as Map<String, dynamic>?)?['cameraRecording'] ?? false,
  //   );
  // }

  Map<String, dynamic> toMap() {
    return {
      'football_field_name': footballFieldName,
      'location_name': locationName,
      'street_name': streetName,
      'photos': photos,
      'opening_hours': openingHours,
      'bookable': bookable,
      'bookings': bookings,
      'latitude': latitude,
      'longitude': longitude,
      'price_range': priceRange,
      'available_time_slots': availableTimeSlots,
      'commission_percentage': commissionPercentage,
      'username': username,
      'password': password,
      'amenities': amenities,
      'field_size': fieldSize,
      'camera_username': cameraUsername,
      'camera_password': cameraPassword,
      'camera_ip_address': cameraIpAddress,
      'raspberry_pi_ip': raspberryPiIp,
      'router_ip': routerIp,
      'sim_card_number': simCardNumber,
      'has_camera': hasCamera,
      'owner_name': ownerName,
      'owner_phone_number': ownerPhoneNumber,
      'assistants': assistants,
      'created_at': createdAt?.toIso8601String(),
      'city': city,
      'area': area,
      'blocked_users': blockedUsers,
      'is_enabled': isEnabled,
    };
  }

  factory FootballField.fromMap(Map<String, dynamic> map) {
    // Helper to get value from either snake_case or camelCase key
    T? getValue<T>(String snakeCase, String camelCase, [T? defaultValue]) {
      return map[snakeCase] ?? map[camelCase] ?? defaultValue;
    }

    // Debug logging for timeslots
    final timeSlotsRaw = map['available_time_slots'] ?? map['availableTimeSlots'];
    print('DEBUG FootballField.fromMap: availableTimeSlots type: ${timeSlotsRaw?.runtimeType}');
    print('DEBUG FootballField.fromMap: availableTimeSlots is Map: ${timeSlotsRaw is Map}');
    if (timeSlotsRaw is Map) {
      print('DEBUG FootballField.fromMap: availableTimeSlots keys: ${timeSlotsRaw.keys}');
      if (timeSlotsRaw.isNotEmpty) {
        final firstKey = timeSlotsRaw.keys.first;
        print('DEBUG FootballField.fromMap: First day "$firstKey" slots: ${timeSlotsRaw[firstKey]?.runtimeType}, length: ${(timeSlotsRaw[firstKey] as List?)?.length}');
      }
    }

    // Parse availableTimeSlots with better error handling
    Map<String, List<Map<String, dynamic>>> parsedTimeSlots = {};
    try {
      final rawTimeSlots = map['available_time_slots'] ?? map['availableTimeSlots'] ?? {};
      if (rawTimeSlots is Map) {
        rawTimeSlots.forEach((key, value) {
          if (value is List) {
            parsedTimeSlots[key.toString()] = value.map((item) {
              if (item is Map) {
                return Map<String, dynamic>.from(item);
              }
              return item as Map<String, dynamic>;
            }).toList();
          } else {
            print('WARNING: Expected List for day $key, got ${value.runtimeType}');
            parsedTimeSlots[key.toString()] = [];
          }
        });
      }
    } catch (e) {
      print('ERROR parsing availableTimeSlots: $e');
      parsedTimeSlots = {};
    }

    // Parse created_at from either format
    DateTime? createdAtParsed;
    final createdAtRaw = map['created_at'] ?? map['createdAt'];
    if (createdAtRaw != null) {
      createdAtParsed = DateTime.tryParse(createdAtRaw.toString());
    }

    return FootballField(
      id: map['id'] ?? '',
      footballFieldName: getValue<String>('football_field_name', 'footballFieldName', '') ?? '',
      locationName: getValue<String>('location_name', 'locationName', '') ?? '',
      streetName: getValue<String>('street_name', 'streetName', '') ?? '',
      photos: List<String>.from(map['photos'] ?? []),
      openingHours: getValue<String>('opening_hours', 'openingHours', '') ?? '',
      bookable: map['bookable'] ?? false,
      bookings: List<String>.from(map['bookings']?.map((e) => e.toString()) ?? []),
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
      priceRange: getValue<String>('price_range', 'priceRange', '') ?? '',
      availableTimeSlots: parsedTimeSlots,
      commissionPercentage: getValue<String>('commission_percentage', 'commissionPercentage', '') ?? '',
      username: map['username'] ?? '',
      password: map['password'] ?? '',
      amenities: Map<String, bool>.from(map['amenities'] ?? {
        'parking': false,
        'toilets': false,
        'cafeteria': false,
        'floodlights': false,
        'qualityField': false,
        'ballIncluded': false,
        'cameraRecording': false,
      }),
      fieldSize: getValue<String>('field_size', 'fieldSize', '5-a-side') ?? '5-a-side',
      cameraUsername: getValue<String?>('camera_username', 'cameraUsername', null),
      cameraPassword: getValue<String?>('camera_password', 'cameraPassword', null),
      cameraIpAddress: getValue<String?>('camera_ip_address', 'cameraIpAddress', null),
      raspberryPiIp: getValue<String?>('raspberry_pi_ip', 'raspberryPiIp', null),
      routerIp: getValue<String?>('router_ip', 'routerIp', null),
      simCardNumber: getValue<String?>('sim_card_number', 'simCardNumber', null),
      hasCamera: getValue<bool>('has_camera', 'hasCamera', false) ?? false,
      ownerName: getValue<String?>('owner_name', 'ownerName', null),
      ownerPhoneNumber: getValue<String?>('owner_phone_number', 'ownerPhoneNumber', null),
      assistants: _parseAssistants(map['assistants']),
      createdAt: createdAtParsed,
      city: map['city'],
      area: map['area'],
      blockedUsers: List<String>.from(map['blocked_users'] ?? map['blockedUsers'] ?? []),
      isEnabled: getValue<bool>('is_enabled', 'isEnabled', true) ?? true,
    );
  }

  static List<Map<String, String>> _parseAssistants(dynamic assistantsData) {
    if (assistantsData == null) return [];
    if (assistantsData is List) {
      return assistantsData.map((item) {
        if (item is Map) {
          return Map<String, String>.from(
            item.map((key, value) => MapEntry(key.toString(), value?.toString() ?? '')),
          );
        }
        return <String, String>{};
      }).where((m) => m.isNotEmpty).toList();
    }
    return [];
  }
}
