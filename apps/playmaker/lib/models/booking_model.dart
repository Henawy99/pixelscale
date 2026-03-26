// import 'package:cloud_firestore/cloud_firestore.dart'; // Removed - using Supabase

class Booking {
  final String id;
  final String userId;
  final String footballFieldId;
  final String date;
  final String timeSlot;
  final int price;
  final String paymentType;
  final List<String> invitePlayers;
  final List<String> inviteSquads;
  final bool isOpenMatch;
  final String bookingReference;
  final String footballFieldName;
  final String host;
  final String locationName;
  final String? cameraUsername;
  final String? cameraPassword;
  final String? cameraIpAddress;
  final String? description;
  final List<String> openJoiningRequests;
  final bool isRecordingEnabled;
  final String status;
  final String? recordingUrl;
  final String? recordingScheduleId; // Link to camera_recording_schedules
  final int? maxPlayers;
  final String? rejectionReason;
  final DateTime? rejectedAt;
  final DateTime createdAt; // Added createdAt

  // Fields from initial prompt / for recurrence
  final bool fieldManagerBooking; 
  final bool isRecurring;
  final String? recurringType; // "daily", "weekly"
  final String? recurringOriginalDate; // YYYY-MM-DD of the first occurrence
  final String? recurringEndDate; // Optional YYYY-MM-DD for when recurrence stops
  final List<String> recurringExceptions; // List of YYYY-MM-DD dates to exclude
  final String? userName; // Added from initial prompt
  final String? userEmail; // Added from initial prompt
  final String? userPhotoUrl; // Added from initial prompt
  final String? notes; // Added from initial prompt


  Booking({
    required this.id,
    required this.userId,
    required this.footballFieldId,
    required this.date,
    required this.timeSlot,
    required this.price,
    required this.paymentType,
    required this.invitePlayers,
    required this.inviteSquads,
    required this.isOpenMatch,
    required this.bookingReference,
    required this.footballFieldName,
    required this.host,
    required this.locationName,
    this.cameraUsername,
    this.cameraPassword,
    this.cameraIpAddress,
    this.description,
    List<String>? openJoiningRequests,
    this.isRecordingEnabled = false,
    required this.status,
    this.recordingUrl,
    this.recordingScheduleId,
    this.maxPlayers,
    this.rejectionReason,
    this.rejectedAt,
    DateTime? createdAt,
    // Added for recurrence and other fields
    this.fieldManagerBooking = false,
    this.isRecurring = false,
    this.recurringType,
    this.recurringOriginalDate,
    this.recurringEndDate,
    List<String>? recurringExceptions,
    this.userName,
    this.userEmail,
    this.userPhotoUrl,
    this.notes,
  }) : openJoiningRequests = openJoiningRequests ?? [],
       recurringExceptions = recurringExceptions ?? const [],
       createdAt = createdAt ?? DateTime.now();

  factory Booking.fromMap(Map<String, dynamic> data) {
    return Booking(
      id: data['id'] ?? '',
      userId: data['userId'] ?? '',
      footballFieldId: data['footballFieldId'] ?? '',
      date: data['date'] ?? '',
      timeSlot: data['timeSlot'] ?? '',
      price: (data['price'] ?? 0).toInt(),
      paymentType: data['paymentType'] ?? 'N/A',
      invitePlayers: List<String>.from(data['invitePlayers'] ?? []),
      inviteSquads: List<String>.from(data['inviteSquads'] ?? []),
      isOpenMatch: data['isOpenMatch'] ?? false,
      bookingReference: data['bookingReference'] ?? '',
      footballFieldName: data['footballFieldName'] ?? '',
      host: data['host'] ?? '',
      locationName: data['locationName'] ?? '',
      cameraUsername: data['cameraUsername'],
      cameraPassword: data['cameraPassword'],
      cameraIpAddress: data['cameraIpAddress'],
      description: data['description'],
      openJoiningRequests: List<String>.from(data['openJoiningRequests'] ?? []),
      isRecordingEnabled: data['isRecordingEnabled'] ?? false,
      status: data['status'] ?? 'pending',
      recordingUrl: data['recordingUrl'] ?? data['recording_url'],
      recordingScheduleId: data['recordingScheduleId'] ?? data['recording_schedule_id'],
      maxPlayers: data['maxPlayers'],
      rejectionReason: data['rejectionReason'] ?? data['rejection_reason'],
      rejectedAt: data['rejectedAt'] != null 
          ? DateTime.tryParse(data['rejectedAt'].toString()) 
          : data['rejected_at'] != null 
              ? DateTime.tryParse(data['rejected_at'].toString())
              : null,
      fieldManagerBooking: data['fieldManagerBooking'] ?? false,
      isRecurring: data['isRecurring'] ?? false,
      recurringType: data['recurringType'],
      recurringOriginalDate: data['recurringOriginalDate'],
      recurringEndDate: data['recurringEndDate'],
      recurringExceptions: List<String>.from(data['recurringExceptions'] ?? []),
      userName: data['userName'] ?? data['user']?['name'],
      userEmail: data['userEmail'] ?? data['user']?['email'],
      userPhotoUrl: data['userPhotoUrl'] ?? data['user']?['photoUrl'],
      notes: data['notes'],
      createdAt: data['created_at'] != null 
          ? DateTime.tryParse(data['created_at'].toString()) 
          : data['createdAt'] != null 
              ? DateTime.tryParse(data['createdAt'].toString()) 
              : null,
    );
  }

  // Deprecated: Use fromMap() instead (Supabase migration)
  // factory Booking.fromFirestore(DocumentSnapshot doc) {
  //   Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
  //
  //   return Booking(
  //     id: doc.id,
  //     userId: data['userId'] ?? '',
  //     footballFieldId: data['footballFieldId'] ?? '',
  //     date: data['date'] ?? '',
  //     timeSlot: data['timeSlot'] ?? '',
  //     price: (data['price'] ?? 0).toInt(), // Keep as int as per existing model
  //     paymentType: data['paymentType'] ?? 'N/A',
  //     invitePlayers: List<String>.from(data['invitePlayers'] ?? []),
  //     inviteSquads: List<String>.from(data['inviteSquads'] ?? []),
  //     isOpenMatch: data['isOpenMatch'] ?? false,
  //     bookingReference: data['bookingReference'] ?? '',
  //     footballFieldName: data['footballFieldName'] ?? '',
  //     host: data['host'] ?? '',
  //     locationName: data['locationName'] ?? '',
  //     cameraUsername: data['cameraUsername'], // Allow null
  //     cameraPassword: data['cameraPassword'], // Allow null
  //     cameraIpAddress: data['cameraIpAddress'], // Allow null
  //     description: data['description'], // Allow null
  //     openJoiningRequests: List<String>.from(data['openJoiningRequests'] ?? []),
  //     isRecordingEnabled: data['isRecordingEnabled'] ?? false,
  //     status: data['status'] ?? 'pending',
  //     recordingUrl: data['recording_url'], // Keep original key if that's what's in Firestore
  //     maxPlayers: data['maxPlayers'],
  //     // Added for recurrence and other fields
  //     fieldManagerBooking: data['fieldManagerBooking'] ?? false,
  //     isRecurring: data['isRecurring'] ?? false,
  //     recurringType: data['recurringType'],
  //     recurringOriginalDate: data['recurringOriginalDate'],
  //     recurringEndDate: data['recurringEndDate'],
  //     recurringExceptions: List<String>.from(data['recurringExceptions'] ?? []),
  //     userName: data['userName'] ?? data['user']?['name'], // From initial prompt
  //     userEmail: data['userEmail'] ?? data['user']?['email'], // From initial prompt
  //     userPhotoUrl: data['userPhotoUrl'] ?? data['user']?['photoUrl'], // From initial prompt
  //     notes: data['notes'], // From initial prompt
  //   );
  // }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'footballFieldId': footballFieldId,
      'date': date,
      'timeSlot': timeSlot,
      'price': price,
      'paymentType': paymentType,
      'invitePlayers': invitePlayers,
      'inviteSquads': inviteSquads,
      'isOpenMatch': isOpenMatch,
      'bookingReference': bookingReference,
      'footballFieldName': footballFieldName,
      'host': host,
      'locationName': locationName,
      'cameraUsername': cameraUsername,
      'cameraPassword': cameraPassword,
      'cameraIpAddress': cameraIpAddress,
      'description': description,
      'openJoiningRequests': openJoiningRequests,
      'isRecordingEnabled': isRecordingEnabled,
      'status': status,
      'recording_url': recordingUrl, // Keep original key
      'recording_schedule_id': recordingScheduleId,
      'maxPlayers': maxPlayers,
      'rejection_reason': rejectionReason,
      'rejected_at': rejectedAt?.toIso8601String(),
      // Added for recurrence and other fields
      'fieldManagerBooking': fieldManagerBooking,
      'isRecurring': isRecurring,
      'recurringType': recurringType,
      'recurringOriginalDate': recurringOriginalDate,
      'recurringEndDate': recurringEndDate,
      'recurringExceptions': recurringExceptions,
      'userName': userName,
      'userEmail': userEmail,
      'userPhotoUrl': userPhotoUrl,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Booking copyWith({
    String? id,
    String? userId,
    String? footballFieldId,
    String? date,
    String? timeSlot,
    int? price,
    String? paymentType,
    List<String>? invitePlayers,
    List<String>? inviteSquads,
    String? host,
    String? bookingReference,
    String? footballFieldName,
    String? locationName,
    String? cameraUsername,
    String? cameraPassword,
    String? cameraIpAddress,
    bool? isOpenMatch,
    String? description,
    List<String>? openJoiningRequests,
    int? maxPlayers,
    bool? isRecordingEnabled,
    String? status,
    String? recordingUrl,
    String? recordingScheduleId,
    // Added for recurrence and other fields
    bool? fieldManagerBooking,
    bool? isRecurring,
    String? recurringType,
    String? recurringOriginalDate,
    String? recurringEndDate,
    List<String>? recurringExceptions,
    String? userName,
    String? userEmail,
    String? userPhotoUrl,
    String? notes,
    DateTime? createdAt,
    // recordingUrl is intentionally not in copyWith in the original file, maintaining that
  }) {
    return Booking(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      footballFieldId: footballFieldId ?? this.footballFieldId,
      date: date ?? this.date,
      timeSlot: timeSlot ?? this.timeSlot,
      price: price ?? this.price,
      paymentType: paymentType ?? this.paymentType,
      invitePlayers: invitePlayers ?? this.invitePlayers,
      inviteSquads: inviteSquads ?? this.inviteSquads,
      isOpenMatch: isOpenMatch ?? this.isOpenMatch,
      bookingReference: bookingReference ?? this.bookingReference,
      footballFieldName: footballFieldName ?? this.footballFieldName,
      host: host ?? this.host,
      locationName: locationName ?? this.locationName,
      cameraUsername: cameraUsername ?? this.cameraUsername,
      cameraPassword: cameraPassword ?? this.cameraPassword,
      cameraIpAddress: cameraIpAddress ?? this.cameraIpAddress,
      description: description ?? this.description,
      openJoiningRequests: openJoiningRequests ?? this.openJoiningRequests,
      isRecordingEnabled: isRecordingEnabled ?? this.isRecordingEnabled,
      status: status ?? this.status,
      recordingUrl: recordingUrl ?? this.recordingUrl,
      recordingScheduleId: recordingScheduleId ?? this.recordingScheduleId,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      // Added for recurrence and other fields
      fieldManagerBooking: fieldManagerBooking ?? this.fieldManagerBooking,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringType: recurringType ?? this.recurringType,
      recurringOriginalDate: recurringOriginalDate ?? this.recurringOriginalDate,
      recurringEndDate: recurringEndDate ?? this.recurringEndDate,
      recurringExceptions: recurringExceptions ?? this.recurringExceptions,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      userPhotoUrl: userPhotoUrl ?? this.userPhotoUrl,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
