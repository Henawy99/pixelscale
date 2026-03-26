class WorkDaySchedule {
  final String start; // 'HH:mm'
  final String end; // 'HH:mm'

  const WorkDaySchedule({required this.start, required this.end});

  Map<String, dynamic> toJson() => {
        'start': start,
        'end': end,
      };

  factory WorkDaySchedule.fromJson(Map<String, dynamic> json) => WorkDaySchedule(
        start: (json['start'] ?? '') as String,
        end: (json['end'] ?? '') as String,
      );

  Duration get duration {
    final sParts = start.split(':').map(int.parse).toList();
    final eParts = end.split(':').map(int.parse).toList();
    final startMinutes = sParts[0] * 60 + sParts[1];
    final endMinutes = eParts[0] * 60 + eParts[1];
    int minutes = endMinutes - startMinutes;
    if (minutes < 0) minutes += 24 * 60; // spans midnight
    return Duration(minutes: minutes);
  }
}

/// Employee model for time management
/// Backed by Supabase table `public.employees` (suggested columns):
/// id (uuid, pk), created_at (timestamptz), updated_at (timestamptz),
/// name (text), active (bool), hourly_wage (numeric), weekly_schedule (jsonb)
class Employee {
  final String id;
  final DateTime createdAt;
  final DateTime? updatedAt;

  final String name;
  final bool active;

  final double hourlyWage;

  // Chosen color index (0..7) for employee-specific color coding
  final int colorIndex;

  // Keys: mon, tue, wed, thu, fri, sat, sun => WorkDaySchedule or null
  final Map<String, WorkDaySchedule?> weeklySchedule;

  const Employee({
    required this.id,
    required this.createdAt,
    this.updatedAt,
    required this.name,
    this.active = true,
    required this.hourlyWage,
    this.colorIndex = 0,
    this.weeklySchedule = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'active': active,
      'hourly_wage': hourlyWage,
      'color_index': colorIndex,
      'weekly_schedule': weeklySchedule.map((k, v) => MapEntry(k, v?.toJson())),
    };
  }

  factory Employee.fromJson(Map<String, dynamic> json) {
    final ws = (json['weekly_schedule'] as Map<String, dynamic>?) ?? {};
    WorkDaySchedule? parseDay(dynamic v) {
      if (v == null) return null;
      if (v is Map<String, dynamic>) return WorkDaySchedule.fromJson(v);
      return null;
    }
    return Employee(
      id: (json['id'] ?? '') as String,
      createdAt: DateTime.tryParse((json['created_at'] ?? json['createdAt'] ?? '') as String) ?? DateTime.now(),
      updatedAt: DateTime.tryParse((json['updated_at'] ?? json['updatedAt']) as String? ?? ''),
      name: (json['name'] ?? '') as String,
      active: (json['active'] as bool?) ?? true,
      hourlyWage: (json['hourly_wage'] as num?)?.toDouble() ?? 0.0,
      colorIndex: (json['color_index'] as int?) ?? 0,
      weeklySchedule: {
        'mon': parseDay(ws['mon']),
        'tue': parseDay(ws['tue']),
        'wed': parseDay(ws['wed']),
        'thu': parseDay(ws['thu']),
        'fri': parseDay(ws['fri']),
        'sat': parseDay(ws['sat']),
        'sun': parseDay(ws['sun']),
      }..removeWhere((k, v) => v == null),
    );
  }

  /// Sum of scheduled hours across the week (does not include ad-hoc time logs)
  double get scheduledHoursPerWeek {
    double total = 0.0;
    for (final v in weeklySchedule.values) {
      if (v == null) continue;
      total += v.duration.inMinutes / 60.0;
    }
    return double.parse(total.toStringAsFixed(2));
  }

  double get estimatedWeeklyCost => double.parse((scheduledHoursPerWeek * hourlyWage).toStringAsFixed(2));

  Employee copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? name,
    bool? active,
    double? hourlyWage,
    int? colorIndex,
    Map<String, WorkDaySchedule?>? weeklySchedule,
  }) {
    return Employee(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      name: name ?? this.name,
      active: active ?? this.active,
      hourlyWage: hourlyWage ?? this.hourlyWage,
      colorIndex: colorIndex ?? this.colorIndex,
      weeklySchedule: weeklySchedule ?? this.weeklySchedule,
    );
  }

  @override
  String toString() =>
      'Employee(id: $id, name: $name, wage: $hourlyWage, active: $active, hours/week: $scheduledHoursPerWeek)';
}

