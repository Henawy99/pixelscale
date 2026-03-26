import 'package:supabase_flutter/supabase_flutter.dart';

class EmployeeAssignmentsRepository {
  final SupabaseClient client;
  EmployeeAssignmentsRepository({SupabaseClient? client})
      : client = client ?? Supabase.instance.client;

  // Recurring rule model
  static const List<String> validDays = ['mon','tue','wed','thu','fri','sat','sun'];

  // dayKey is one of: mon, tue, wed, thu, fri, sat, sun
  // slots are minutes from 0..1439, 60-minute steps in our v1
  Future<Map<String, Map<int, Set<String>>>> loadAssignments(DateTime weekStart) async {
    final week = _dateOnlyISO(_dateOnly(weekStart));

    final rows = await client
        .from('employee_assignments')
        .select('day_key, slot_minutes, employee_id')
        .eq('week_start', week);

    final result = <String, Map<int, Set<String>>>{
      'mon': {}, 'tue': {}, 'wed': {}, 'thu': {}, 'fri': {}, 'sat': {}, 'sun': {},
    };

    for (final r in (rows as List)) {
      final day = (r['day_key'] ?? '') as String;
      final slot = (r['slot_minutes'] as num).toInt();
      final emp = (r['employee_id'] ?? '') as String;
      final map = result.putIfAbsent(day, () => {});
      final set = map.putIfAbsent(slot, () => <String>{});
      set.add(emp);
    }
    return result;
  }

  // Persisted schedule history API (schedule_history table)
  Future<void> logHistory({
    required String actionType, // 'add' | 'edit' | 'delete'
    required String employeeId,
    required String dayKey,
    required int startMin,
    required int endMin,
    DateTime? weekStart,
    String? message,
  }) async {
    try {
      final row = {
        'action_type': actionType,
        'employee_id': employeeId,
        'day_key': dayKey,
        'start_minutes': startMin,
        'end_minutes': endMin,
        if (weekStart != null) 'week_start': _dateOnlyISO(_dateOnly(weekStart)),
        if (message != null) 'message': message,
      };
      await client.from('schedule_history').insert(row);
    } catch (_) {/* table may not exist yet; ignore to avoid UI break */}
  }

  Future<List<Map<String, dynamic>>> fetchHistory({
    DateTime? weekStart,
    int limit = 200,
  }) async {
    try {
      dynamic query = client.from('schedule_history')
        .select('created_at, action_type, employee_id, day_key, start_minutes, end_minutes, week_start, message')
        .order('created_at', ascending: false)
        .limit(limit);
      if (weekStart != null) {
        query = client.from('schedule_history')
          .select('created_at, action_type, employee_id, day_key, start_minutes, end_minutes, week_start, message')
          .eq('week_start', _dateOnlyISO(_dateOnly(weekStart)))
          .order('created_at', ascending: false)
          .limit(limit);
      }
      final rows = await query;
      return (rows as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> addEmployeeAssignments({
    required String dayKey,
    required List<int> slots,
    required String employeeId,
    required DateTime weekStart,
  }) async {
    if (slots.isEmpty) return;
    final week = _dateOnlyISO(_dateOnly(weekStart));

    // Remove existing rows for these slots for this employee to avoid duplicates
    await client
        .from('employee_assignments')
        .delete()
        .eq('day_key', dayKey)
        .eq('employee_id', employeeId)
        .eq('week_start', week)
        .inFilter('slot_minutes', slots);

    final rows = [
      for (final s in slots)
        {
          'day_key': dayKey,
          'slot_minutes': s,
          'employee_id': employeeId,
          'week_start': week,
        }
    ];
    await client.from('employee_assignments').insert(rows);
  }

  // Recurring rules
  Future<void> clearAllRecurringRules() async {
    try {
      await client.from('employee_recurring_rules').delete();
    } catch (_) {/* ignore */}
  }

  // Recurring exceptions (suppress a single instance in a specific week)
  Future<bool> upsertRecurringException({
    required String employeeId,
    required String dayKey,
    required int startMin,
    required int endMin,
    required DateTime weekStart,
  }) async {
    final week = _dateOnlyISO(_dateOnly(weekStart));
    try {
      await client.from('employee_recurring_exceptions').upsert({
        'employee_id': employeeId,
        'day_key': dayKey,
        'start_min': startMin,
        'end_min': endMin,
        'week_start': week,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> loadRecurringExceptions(DateTime weekStart) async {
    try {
      final week = _dateOnlyISO(_dateOnly(weekStart));
      final rows = await client
          .from('employee_recurring_exceptions')
          .select('employee_id, day_key, start_min, end_min, week_start')
          .eq('week_start', week);
      return (rows as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> clearRecurringExceptionsForWeek(DateTime weekStart) async {
    try {
      final week = _dateOnlyISO(_dateOnly(weekStart));
      await client.from('employee_recurring_exceptions').delete().eq('week_start', week);
    } catch (_) {/* ignore */}
  }

  Future<List<Map<String, dynamic>>> loadRecurringRules() async {
    try {
      final rows = await client
          .from('employee_recurring_rules')
          .select('id, employee_id, day_key, start_min, end_min, active');
      return (rows as List).cast<Map<String, dynamic>>();
    } catch (_) {
      // Table may not exist yet
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> upsertRecurringRule({
    required String employeeId,
    required String dayKey,
    required int startMin,
    required int endMin,
    bool active = true,
  }) async {
    assert(validDays.contains(dayKey));
    await client.from('employee_recurring_rules').upsert({
      'employee_id': employeeId,
      'day_key': dayKey,
      'start_min': startMin,
      'end_min': endMin,
      'active': active,
    });
  }

  Future<void> deleteRecurringRule({
    required String employeeId,
    required String dayKey,
  }) async {
    await client
        .from('employee_recurring_rules')
        .delete()
        .eq('employee_id', employeeId)
        .eq('day_key', dayKey);
  }

  Future<List<Map<String, dynamic>>> loadMinuteRanges(DateTime weekStart) async {
    try {
      final week = _dateOnlyISO(_dateOnly(weekStart));
      final rows = await client
          .from('employee_time_ranges')
          .select('employee_id, day_key, start_min, end_min')
          .eq('week_start', week);
      return (rows as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> upsertMinuteRange({
    required String employeeId,
    required String dayKey,
    required int startMin,
    required int endMin,
    required DateTime weekStart,
  }) async {
    final week = _dateOnlyISO(_dateOnly(weekStart));
    // Replace any existing ranges for same employee/day/week with the new one
    await client
        .from('employee_time_ranges')
        .delete()
        .eq('employee_id', employeeId)
        .eq('day_key', dayKey)
        .eq('week_start', week);
    await client.from('employee_time_ranges').insert({
      'employee_id': employeeId,
      'day_key': dayKey,
      'start_min': startMin,
      'end_min': endMin,
      'week_start': week,
    });
  }

  Future<void> deleteMinuteRange({
    required String employeeId,
    required String dayKey,
    required DateTime weekStart,
  }) async {
    final week = _dateOnlyISO(_dateOnly(weekStart));
    await client
        .from('employee_time_ranges')
        .delete()
        .eq('employee_id', employeeId)
        .eq('day_key', dayKey)
        .eq('week_start', week);
  }

  // Clear all assigned time ranges for a specific week (for all employees)
  Future<void> clearWeekAssignmentsAndRanges(DateTime weekStart) async {
    final week = _dateOnlyISO(_dateOnly(weekStart));
    await client.from('employee_assignments').delete().eq('week_start', week);
    await client.from('employee_time_ranges').delete().eq('week_start', week);
  }

  Future<void> removeEmployeeAssignments({
    required String dayKey,
    required List<int> slots,
    required String employeeId,
    required DateTime weekStart,
  }) async {
    if (slots.isEmpty) return;
    final week = _dateOnlyISO(_dateOnly(weekStart));
    await client
        .from('employee_assignments')
        .delete()
        .eq('day_key', dayKey)
        .eq('employee_id', employeeId)
        .eq('week_start', week)
        .inFilter('slot_minutes', slots);
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  String _two(int v) => v.toString().padLeft(2, '0');
  String _dateOnlyISO(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';
}

