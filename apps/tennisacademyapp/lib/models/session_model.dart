/// Session: one time slot on one court.
/// Flat structure; players come from session_registrations.
class SessionModel {
  final String id;
  final String date; // YYYY-MM-DD
  final int courtId; // 1-4
  final String name; // Professional, Game, Bee, Flower, etc.
  final String startTime; // HH:mm or HH:mm:ss
  final String endTime;
  final String? fitnessStartTime; // HH:mm or HH:mm:ss
  final String? fitnessEndTime;
  final int maxCapacity;
  final String? createdAt;
  
  // Recurrence
  final String? recurrenceId;
  final String? recurrenceRule; // 'daily', 'weekly'

  // Computed / joined (set by service)
  int playerCount;
  bool get isFull => playerCount >= maxCapacity;
  String? userStatus; // current user: pending, approved, rejected
  List<String> playerNames;
  /// Admin: slot 1-4 -> player name (from session_assignments + players).
  Map<int, String>? slotPlayerNames;

  SessionModel({
    required this.id,
    required this.date,
    required this.courtId,
    required this.name,
    required this.startTime,
    required this.endTime,
    this.fitnessStartTime,
    this.fitnessEndTime,
    this.maxCapacity = 4,
    this.createdAt,
    this.recurrenceId,
    this.recurrenceRule,
    this.playerCount = 0,
    this.userStatus,
    this.playerNames = const [],
    this.slotPlayerNames,
  });

  /// Day label for weekly schedule (Sunday, Tuesday, Thursday)
  String get dayLabel {
    final d = DateTime.parse(date);
    const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    return days[d.weekday % 7];
  }

  String get timeRange => '${_formatTime(startTime)} – ${_formatTime(endTime)}';
  static String _formatTime(String t) {
    if (t.length >= 5) return t.substring(0, 5); // HH:mm
    return t;
  }

  factory SessionModel.fromJson(Map<String, dynamic> json, {int? playerCount, String? userStatus, List<String>? playerNames, Map<int, String>? slotPlayerNames}) {
    return SessionModel(
      id: json['id'] as String,
      date: json['date'] as String,
      courtId: (json['court_id'] as num).toInt(),
      name: json['name'] as String? ?? '',
      startTime: json['start_time'] as String? ?? '',
      endTime: json['end_time'] as String? ?? '',
      fitnessStartTime: json['fitness_start_time'] as String?,
      fitnessEndTime: json['fitness_end_time'] as String?,
      maxCapacity: (json['max_capacity'] as num?)?.toInt() ?? 4,
      createdAt: json['created_at'] as String?,
      recurrenceId: json['recurrence_id'] as String?,
      recurrenceRule: json['recurrence_rule'] as String?,
      playerCount: playerCount ?? 0,
      userStatus: userStatus,
      playerNames: playerNames ?? [],
      slotPlayerNames: slotPlayerNames,
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date,
        'court_id': courtId,
        'name': name,
        'start_time': startTime,
        'end_time': endTime,
        'fitness_start_time': fitnessStartTime,
        'fitness_end_time': fitnessEndTime,
        'max_capacity': maxCapacity,
        'recurrence_id': recurrenceId,
        'recurrence_rule': recurrenceRule,
      };

  SessionModel copyWith({int? playerCount, String? userStatus, List<String>? playerNames}) {
    return SessionModel(
      id: id,
      date: date,
      courtId: courtId,
      name: name,
      startTime: startTime,
      endTime: endTime,
      fitnessStartTime: fitnessStartTime,
      fitnessEndTime: fitnessEndTime,
      maxCapacity: maxCapacity,
      createdAt: createdAt,
      recurrenceId: recurrenceId,
      recurrenceRule: recurrenceRule,
      playerCount: playerCount ?? this.playerCount,
      userStatus: userStatus ?? this.userStatus,
      playerNames: playerNames ?? this.playerNames,
    );
  }
}
