import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Simple Employee model for scheduling
class ScheduleEmployee {
  final String id;
  final String name;
  final String email;
  final double hourlyWage;
  final int colorIndex;
  final bool active;
  final bool isDriver;
  final String? authUserId;

  const ScheduleEmployee({
    required this.id,
    required this.name,
    required this.email,
    required this.hourlyWage,
    this.colorIndex = 0,
    this.active = true,
    this.isDriver = false,
    this.authUserId,
  });

  factory ScheduleEmployee.fromJson(Map<String, dynamic> json) =>
      ScheduleEmployee(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        hourlyWage: (json['hourly_wage'] as num?)?.toDouble() ?? 0.0,
        colorIndex: json['color_index'] as int? ?? 0,
        active: json['active'] as bool? ?? true,
        isDriver: json['is_driver'] as bool? ?? false,
        authUserId: json['auth_user_id'] as String?,
      );
}

/// Shift model
class Shift {
  final String id;
  final String employeeId;
  final DateTime date;
  final String startTime;
  final String endTime;

  const Shift({
    required this.id,
    required this.employeeId,
    required this.date,
    required this.startTime,
    required this.endTime,
  });

  factory Shift.fromJson(Map<String, dynamic> json) => Shift(
    id: json['id'] as String? ?? '',
    employeeId: json['employee_id'] as String? ?? '',
    date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
    startTime: json['start_time'] as String? ?? '00:00',
    endTime: json['end_time'] as String? ?? '00:00',
  );

  int get durationMinutes {
    final startParts = startTime.split(':');
    final endParts = endTime.split(':');
    if (startParts.length < 2 || endParts.length < 2) return 0;
    final startMin = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
    final endMin = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
    return endMin >= startMin ? endMin - startMin : (1440 - startMin) + endMin;
  }

  double getWage(double hourlyWage) => (durationMinutes / 60.0) * hourlyWage;
}

// Beautiful employee colors
const List<Color> employeeColors = [
  Color(0xFFE53935), // Red
  Color(0xFF8E24AA), // Purple
  Color(0xFF3949AB), // Indigo
  Color(0xFF1E88E5), // Blue
  Color(0xFF00ACC1), // Cyan
  Color(0xFF43A047), // Green
  Color(0xFFFB8C00), // Orange
  Color(0xFF6D4C41), // Brown
];

class ScheduleTab extends StatefulWidget {
  final List<dynamic> employees;
  final dynamic repo;

  const ScheduleTab({super.key, required this.employees, required this.repo});

  @override
  State<ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends State<ScheduleTab> {
  final _supabase = Supabase.instance.client;

  DateTime _selectedDate = DateTime.now();
  List<ScheduleEmployee> _employees = [];
  List<Shift> _shifts = [];
  bool _isLoading = true;
  bool _isWeeklyView = false;
  bool _showByDay = false; // false = by employee, true = by day

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.orange),
            SizedBox(width: 12),
            Text('Logout'),
          ],
        ),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _supabase.auth.signOut();
      if (mounted) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/login', (Route<dynamic> route) => false);
      }
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await Future.wait([_loadEmployees(), _loadShifts()]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadEmployees() async {
    try {
      final response = await _supabase
          .from('employees')
          .select(
            'id, name, email, hourly_wage, color_index, active, is_driver, auth_user_id',
          )
          .eq('active', true)
          .order('name');

      _employees = (response as List)
          .map((e) => ScheduleEmployee.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error loading employees: $e');
    }
  }

  Future<void> _loadShifts() async {
    try {
      if (_isWeeklyView) {
        // Load entire week (Tuesday to Monday)
        final tuesday = _getTuesday(_selectedDate);
        final monday = tuesday.add(const Duration(days: 6));
        final tuesdayStr = _formatDateForDb(tuesday);
        final mondayStr = _formatDateForDb(monday);

        final response = await _supabase
            .from('employee_shifts')
            .select('id, employee_id, date, start_time, end_time')
            .gte('date', tuesdayStr)
            .lte('date', mondayStr)
            .order('date')
            .order('start_time');

        _shifts = (response as List)
            .map((e) => Shift.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        final dateStr = _formatDateForDb(_selectedDate);
        final response = await _supabase
            .from('employee_shifts')
            .select('id, employee_id, date, start_time, end_time')
            .eq('date', dateStr);

        _shifts = (response as List)
            .map((e) => Shift.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('Error loading shifts: $e');
      _shifts = [];
    }
  }

  DateTime _getTuesday(DateTime date) {
    // Week starts on Tuesday, ends on Monday
    // weekday: Mon=1, Tue=2, Wed=3, Thu=4, Fri=5, Sat=6, Sun=7
    return date.subtract(Duration(days: (date.weekday - 2 + 7) % 7));
  }

  String _getWeekRangeText() {
    final tuesday = _getTuesday(_selectedDate);
    final monday = tuesday.add(const Duration(days: 6));
    return '${tuesday.day}/${tuesday.month} - ${monday.day}/${monday.month}';
  }

  double _calculateWeeklyCost() {
    double total = 0;
    for (final shift in _shifts) {
      final employee = _employees.firstWhere(
        (e) => e.id == shift.employeeId,
        orElse: () =>
            const ScheduleEmployee(id: '', name: '', email: '', hourlyWage: 0),
      );
      total += shift.getWage(employee.hourlyWage);
    }
    return total;
  }

  int _calculateWeeklyMinutes() {
    int total = 0;
    for (final shift in _shifts) {
      total += shift.durationMinutes;
    }
    return total;
  }

  Map<String, double> _getEmployeeWeeklyWages() {
    final Map<String, double> wages = {};
    for (final shift in _shifts) {
      final employee = _employees.firstWhere(
        (e) => e.id == shift.employeeId,
        orElse: () =>
            const ScheduleEmployee(id: '', name: '', email: '', hourlyWage: 0),
      );
      wages[shift.employeeId] =
          (wages[shift.employeeId] ?? 0) + shift.getWage(employee.hourlyWage);
    }
    return wages;
  }

  void _toggleView() {
    setState(() => _isWeeklyView = !_isWeeklyView);
    _loadShifts().then((_) => setState(() {}));
  }

  String _formatDateForDb(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _formatDateDisplay(DateTime date) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${days[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  }

  void _previousDay() {
    setState(
      () => _selectedDate = _selectedDate.subtract(
        Duration(days: _isWeeklyView ? 7 : 1),
      ),
    );
    _loadShifts().then((_) => setState(() {}));
  }

  void _nextDay() {
    setState(
      () => _selectedDate = _selectedDate.add(
        Duration(days: _isWeeklyView ? 7 : 1),
      ),
    );
    _loadShifts().then((_) => setState(() {}));
  }

  double _calculateDailyCost() {
    double total = 0;
    for (final shift in _shifts) {
      final employee = _employees.firstWhere(
        (e) => e.id == shift.employeeId,
        orElse: () =>
            const ScheduleEmployee(id: '', name: '', email: '', hourlyWage: 0),
      );
      total += shift.getWage(employee.hourlyWage);
    }
    return total;
  }

  int _calculateTotalHours() {
    int total = 0;
    for (final shift in _shifts) {
      total += shift.durationMinutes;
    }
    return total;
  }

  List<Shift> _getShiftsForEmployee(String employeeId) =>
      _shifts.where((s) => s.employeeId == employeeId).toList();

  // Get employees who have shifts today
  List<ScheduleEmployee> _getEmployeesWithShifts() {
    final employeeIdsWithShifts = _shifts.map((s) => s.employeeId).toSet();
    return _employees
        .where((e) => employeeIdsWithShifts.contains(e.id))
        .toList();
  }

  bool get _isToday =>
      _selectedDate.year == DateTime.now().year &&
      _selectedDate.month == DateTime.now().month &&
      _selectedDate.day == DateTime.now().day;

  @override
  Widget build(BuildContext context) {
    final totalCost = _isWeeklyView
        ? _calculateWeeklyCost()
        : _calculateDailyCost();
    final totalMinutes = _isWeeklyView
        ? _calculateWeeklyMinutes()
        : _calculateTotalHours();
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    final employeesWithShifts = _getEmployeesWithShifts();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2D3748),
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Row(
          children: [
            const Text(
              'Schedule',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '€${totalCost.toStringAsFixed(0)} · ${hours}h ${mins}m',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        actions: [
          // Day/Week toggle
          GestureDetector(
            onTap: _toggleView,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _isWeeklyView ? Colors.blue[50] : Colors.grey[100],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: _isWeeklyView
                      ? Colors.blue.shade200
                      : Colors.grey.shade300,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isWeeklyView ? Icons.view_week : Icons.today,
                    size: 14,
                    color: _isWeeklyView ? Colors.blue[700] : Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isWeeklyView ? 'Week' : 'Day',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _isWeeklyView
                          ? Colors.blue[700]
                          : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // By Employee / By Day toggle (only in weekly view)
          if (_isWeeklyView) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () => setState(() => _showByDay = !_showByDay),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _showByDay ? Colors.orange[50] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: _showByDay
                        ? Colors.orange.shade200
                        : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _showByDay ? Icons.calendar_view_day : Icons.person,
                      size: 14,
                      color: _showByDay ? Colors.orange[700] : Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _showByDay ? 'Days' : 'Staff',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _showByDay
                            ? Colors.orange[700]
                            : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.people_outline, size: 20),
            tooltip: 'Team',
            onPressed: _showEmployeesDialog,
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          IconButton(
            icon: const Icon(Icons.logout, size: 20),
            tooltip: 'Logout',
            onPressed: _logout,
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, size: 24),
                  onPressed: _previousDay,
                  color: Colors.grey[600],
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: _isWeeklyView ? null : _pickDate,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (!_isWeeklyView && _isToday)
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4CAF50),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: const Text(
                              'TODAY',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        Text(
                          _isWeeklyView
                              ? _getWeekRangeText()
                              : _formatDateDisplay(_selectedDate),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2D3748),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, size: 24),
                  onPressed: _nextDay,
                  color: Colors.grey[600],
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _isWeeklyView
          ? (_showByDay
                ? _buildWeeklyByDayView()
                : _buildWeeklyByEmployeeView())
          : employeesWithShifts.isEmpty
          ? _buildEmptyDayState()
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: employeesWithShifts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) =>
                  _buildShiftCard(employeesWithShifts[index]),
            ),
      floatingActionButton: _isWeeklyView
          ? null
          : FloatingActionButton.small(
              onPressed: _showAddShiftDialog,
              backgroundColor: const Color(0xFF4299E1),
              child: const Icon(Icons.add, color: Colors.white, size: 20),
            ),
    );
  }

  Widget _buildWeeklyByEmployeeView() {
    final employeeWages = _getEmployeeWeeklyWages();
    final totalWeekCost = _calculateWeeklyCost();
    final totalMinutes = _calculateWeeklyMinutes();
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;

    // Get employees who have shifts this week
    final employeeIdsWithShifts = _shifts.map((s) => s.employeeId).toSet();
    final employeesWithShifts = _employees
        .where((e) => employeeIdsWithShifts.contains(e.id))
        .toList();

    if (employeesWithShifts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_available_outlined,
              size: 40,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 12),
            Text(
              'No shifts this week',
              style: TextStyle(fontSize: 15, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // Week summary card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              Text(
                'Week Total',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
              const SizedBox(height: 4),
              Text(
                '€${totalWeekCost.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4CAF50),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${hours}h ${mins}m · ${_shifts.length} shifts',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Employee breakdown
        ...employeesWithShifts.map((emp) {
          final empShifts = _shifts.where((s) => s.employeeId == emp.id).toList()
            ..sort((a, b) {
              // Sort by date (Tuesday first order)
              // Convert weekday to Tuesday-first order: Tue=0, Wed=1, Thu=2, Fri=3, Sat=4, Sun=5, Mon=6
              int dayOrderA = (a.date.weekday - 2 + 7) % 7;
              int dayOrderB = (b.date.weekday - 2 + 7) % 7;
              if (dayOrderA != dayOrderB) return dayOrderA.compareTo(dayOrderB);
              // Then by start time
              return a.startTime.compareTo(b.startTime);
            });
          final empWage = employeeWages[emp.id] ?? 0;
          final empMinutes = empShifts.fold(
            0,
            (sum, s) => sum + s.durationMinutes,
          );
          final empHours = empMinutes ~/ 60;
          final empMins = empMinutes % 60;
          final color = employeeColors[emp.colorIndex % employeeColors.length];

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                // Employee header
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.04),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(7),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text(
                            emp.name.isNotEmpty
                                ? emp.name[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          emp.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Color(0xFF2D3748),
                          ),
                        ),
                      ),
                      Text(
                        '${empHours}h ${empMins}m',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '€${empWage.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF4CAF50),
                        ),
                      ),
                    ],
                  ),
                ),
                // Shifts by day
                ...empShifts.map((shift) {
                  final wage = shift.getWage(emp.hourlyWage);
                  final dayName = [
                    'Mon',
                    'Tue',
                    'Wed',
                    'Thu',
                    'Fri',
                    'Sat',
                    'Sun',
                  ][shift.date.weekday - 1];
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Colors.grey.shade100),
                      ),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 35,
                          child: Text(
                            dayName,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Text(
                          '${shift.startTime.substring(0, 5)} - ${shift.endTime.substring(0, 5)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '€${wage.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4CAF50),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          );
        }),
      ],
    );
  }

  // Get all dates in the week (Tuesday to Monday)
  List<DateTime> _getWeekDates() {
    final tuesday = _getTuesday(_selectedDate);
    return List.generate(7, (i) => tuesday.add(Duration(days: i)));
  }

  Widget _buildWeeklyByDayView() {
    final totalWeekCost = _calculateWeeklyCost();
    final totalMinutes = _calculateWeeklyMinutes();
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    final weekDates = _getWeekDates();

    // Day names starting from Tuesday
    const dayNames = ['Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun', 'Mon'];

    if (_shifts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_available_outlined,
              size: 40,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 12),
            Text(
              'No shifts this week',
              style: TextStyle(fontSize: 15, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // Week summary card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              Text(
                'Week Total',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
              const SizedBox(height: 4),
              Text(
                '€${totalWeekCost.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4CAF50),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${hours}h ${mins}m · ${_shifts.length} shifts',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Each day
        ...List.generate(7, (dayIndex) {
          final date = weekDates[dayIndex];
          final dayShifts =
              _shifts
                  .where(
                    (s) =>
                        s.date.year == date.year &&
                        s.date.month == date.month &&
                        s.date.day == date.day,
                  )
                  .toList()
                ..sort((a, b) => a.startTime.compareTo(b.startTime));

          final dayTotalMinutes = dayShifts.fold(
            0,
            (sum, s) => sum + s.durationMinutes,
          );
          final dayHours = dayTotalMinutes ~/ 60;
          final dayMins = dayTotalMinutes % 60;
          double dayTotalWage = 0;
          for (final shift in dayShifts) {
            final emp = _employees.firstWhere(
              (e) => e.id == shift.employeeId,
              orElse: () => const ScheduleEmployee(
                id: '',
                name: '',
                email: '',
                hourlyWage: 0,
              ),
            );
            dayTotalWage += shift.getWage(emp.hourlyWage);
          }

          final isToday =
              date.year == DateTime.now().year &&
              date.month == DateTime.now().month &&
              date.day == DateTime.now().day;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isToday ? Colors.blue.shade300 : Colors.grey.shade200,
                width: isToday ? 2 : 1,
              ),
            ),
            child: Column(
              children: [
                // Day header
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isToday ? Colors.blue.shade50 : Colors.grey.shade50,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(7),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isToday ? Colors.blue : Colors.grey.shade600,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          dayNames[dayIndex],
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${date.day}/${date.month}',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                      ),
                      if (isToday) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Text(
                            'TODAY',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (dayShifts.isNotEmpty) ...[
                        Text(
                          '${dayHours}h ${dayMins}m',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '€${dayTotalWage.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color(0xFF4CAF50),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Shifts for this day
                if (dayShifts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'No shifts',
                      style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                    ),
                  )
                else
                  ...dayShifts.map((shift) {
                    final emp = _employees.firstWhere(
                      (e) => e.id == shift.employeeId,
                      orElse: () => const ScheduleEmployee(
                        id: '',
                        name: '',
                        email: '',
                        hourlyWage: 0,
                      ),
                    );
                    final color =
                        employeeColors[emp.colorIndex % employeeColors.length];
                    final wage = shift.getWage(emp.hourlyWage);

                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Colors.grey.shade100),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Center(
                              child: Text(
                                emp.name.isNotEmpty
                                    ? emp.name[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              emp.name.isNotEmpty ? emp.name : 'Unknown',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${shift.startTime.substring(0, 5)} - ${shift.endTime.substring(0, 5)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '€${wage.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF4CAF50),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildEmptyDayState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.event_available_outlined,
            size: 40,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 12),
          Text(
            'No shifts',
            style: TextStyle(fontSize: 15, color: Colors.grey[600]),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap + to add',
            style: TextStyle(fontSize: 12, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftCard(ScheduleEmployee employee) {
    final shifts = _getShiftsForEmployee(employee.id);
    final color = employeeColors[employee.colorIndex % employeeColors.length];

    double totalWage = 0;
    int totalMinutes = 0;
    for (final shift in shifts) {
      totalWage += shift.getWage(employee.hourlyWage);
      totalMinutes += shift.durationMinutes;
    }
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          // Employee Header - compact
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.04),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(7),
              ),
            ),
            child: Row(
              children: [
                // Small avatar
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text(
                      employee.name.isNotEmpty
                          ? employee.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Name
                Expanded(
                  child: Text(
                    employee.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Color(0xFF2D3748),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Time + Wage
                Text(
                  '${hours}h ${mins}m',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
                const SizedBox(width: 8),
                Text(
                  '€${totalWage.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF4CAF50),
                  ),
                ),
              ],
            ),
          ),

          // Shifts - compact
          ...shifts.map((shift) => _buildShiftTile(shift, employee)),

          // Add shift button
          if (shifts.length < 2)
            InkWell(
              onTap: () => _showAddShiftDialog(preselectedEmployee: employee),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(7),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey.shade100)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, size: 14, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Text(
                      'Add',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildShiftTile(Shift shift, ScheduleEmployee employee) {
    final wage = shift.getWage(employee.hourlyWage);

    return InkWell(
      onTap: () => _editShift(shift, employee),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.grey.shade100)),
        ),
        child: Row(
          children: [
            Text(
              '${shift.startTime.substring(0, 5)} - ${shift.endTime.substring(0, 5)}',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
                fontSize: 13,
              ),
            ),
            const Spacer(),
            Text(
              '€${wage.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF4CAF50),
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => _deleteShift(shift),
              child: Icon(Icons.close, size: 16, color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
      await _loadShifts();
      setState(() {});
    }
  }

  void _showEmployeesDialog() {
    showDialog(
      context: context,
      builder: (ctx) =>
          _EmployeesDialog(employees: _employees, onChanged: () => _loadData()),
    );
  }

  void _showAddShiftDialog({ScheduleEmployee? preselectedEmployee}) {
    if (_employees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add employees first')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => _AddShiftDialog(
        employees: _employees,
        date: _selectedDate,
        preselectedEmployee: preselectedEmployee,
        existingShifts: _shifts,
        onSaved: () {
          _loadShifts().then((_) => setState(() {}));
        },
      ),
    );
  }

  void _editShift(Shift shift, ScheduleEmployee employee) {
    showDialog(
      context: context,
      builder: (ctx) => _EditShiftDialog(
        shift: shift,
        employee: employee,
        onSaved: () => _loadShifts().then((_) => setState(() {})),
        onDeleted: () => _loadShifts().then((_) => setState(() {})),
      ),
    );
  }

  Future<void> _deleteShift(Shift shift) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Shift?'),
        content: Text(
          'Remove shift ${shift.startTime.substring(0, 5)} - ${shift.endTime.substring(0, 5)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _supabase.from('employee_shifts').delete().eq('id', shift.id);
        await _loadShifts();
        setState(() {});
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
}

// ============ EMPLOYEES DIALOG ============

class _EmployeesDialog extends StatefulWidget {
  final List<ScheduleEmployee> employees;
  final VoidCallback onChanged;

  const _EmployeesDialog({required this.employees, required this.onChanged});

  @override
  State<_EmployeesDialog> createState() => _EmployeesDialogState();
}

class _EmployeesDialogState extends State<_EmployeesDialog> {
  final _supabase = Supabase.instance.client;
  late List<ScheduleEmployee> _employees;

  @override
  void initState() {
    super.initState();
    _employees = List.from(widget.employees);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340, maxHeight: 450),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
              child: Row(
                children: [
                  const Text(
                    'Team',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _addEmployee,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, size: 16),
                        SizedBox(width: 4),
                        Text('Add'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Divider(height: 1, color: Colors.grey.shade200),

            // List
            Flexible(
              child: _employees.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 32,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No employees',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _employees.length,
                      itemBuilder: (ctx, i) {
                        final emp = _employees[i];
                        final color =
                            employeeColors[emp.colorIndex %
                                employeeColors.length];
                        return InkWell(
                          onTap: () => _editEmployee(emp),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Center(
                                    child: Text(
                                      emp.name.isNotEmpty
                                          ? emp.name[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        emp.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        '€${emp.hourlyWage.toStringAsFixed(2)}/hr${emp.isDriver ? ' · Driver' : ''}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => _deleteEmployee(emp),
                                  child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: Icon(
                                      Icons.close,
                                      size: 16,
                                      color: Colors.grey[400],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addEmployee() {
    showDialog(
      context: context,
      builder: (ctx) => _EmployeeFormDialog(
        onSaved: (emp) async {
          setState(() => _employees.add(emp));
          widget.onChanged();
        },
      ),
    );
  }

  void _editEmployee(ScheduleEmployee emp) {
    showDialog(
      context: context,
      builder: (ctx) => _EmployeeFormDialog(
        employee: emp,
        onSaved: (updated) async {
          final index = _employees.indexWhere((e) => e.id == updated.id);
          if (index >= 0) {
            setState(() => _employees[index] = updated);
          }
          widget.onChanged();
        },
      ),
    );
  }

  Future<void> _deleteEmployee(ScheduleEmployee emp) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Employee?'),
        content: Text(
          'Are you sure you want to remove ${emp.name}?${emp.isDriver ? '\n\nThis will also remove their driver access.' : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // If they're a driver, also delete driver record
        if (emp.isDriver && emp.authUserId != null) {
          await _supabase
              .from('drivers')
              .delete()
              .eq('user_id', emp.authUserId!);
        }

        await _supabase
            .from('employees')
            .update({'active': false})
            .eq('id', emp.id);
        setState(() => _employees.removeWhere((e) => e.id == emp.id));
        widget.onChanged();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
}

// ============ EMPLOYEE FORM DIALOG ============

class _EmployeeFormDialog extends StatefulWidget {
  final ScheduleEmployee? employee;
  final Function(ScheduleEmployee) onSaved;

  const _EmployeeFormDialog({this.employee, required this.onSaved});

  @override
  State<_EmployeeFormDialog> createState() => _EmployeeFormDialogState();
}

class _EmployeeFormDialogState extends State<_EmployeeFormDialog> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _passwordCtrl;
  late TextEditingController _wageCtrl;
  int _colorIndex = 0;
  bool _isDriver = false;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.employee?.name ?? '');
    _emailCtrl = TextEditingController(text: widget.employee?.email ?? '');
    _passwordCtrl = TextEditingController();
    _wageCtrl = TextEditingController(
      text: widget.employee?.hourlyWage.toStringAsFixed(2) ?? '12.00',
    );
    _colorIndex = widget.employee?.colorIndex ?? 0;
    _isDriver = widget.employee?.isDriver ?? false;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _wageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.employee == null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isNew ? 'New Employee' : 'Edit Employee',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Name
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Name',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),

                  // Email
                  TextFormField(
                    controller: _emailCtrl,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v?.isEmpty ?? true) return 'Required';
                      if (!v!.contains('@')) return 'Invalid';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Password (only for new)
                  if (isNew) ...[
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            size: 20,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (v) {
                        if (v?.isEmpty ?? true) return 'Required';
                        if (v!.length < 4) return 'Min 4 chars';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Hourly Wage
                  TextFormField(
                    controller: _wageCtrl,
                    decoration: InputDecoration(
                      labelText: 'Hourly Wage (€)',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (v) {
                      final val = double.tryParse(
                        v?.replaceAll(',', '.') ?? '',
                      );
                      if (val == null || val < 0) return 'Invalid';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Driver Toggle - simple
                  InkWell(
                    onTap: () => setState(() => _isDriver = !_isDriver),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _isDriver ? Colors.blue[50] : Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _isDriver
                              ? Colors.blue.shade200
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.delivery_dining,
                            size: 20,
                            color: _isDriver
                                ? Colors.blue[600]
                                : Colors.grey[500],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Delivery Driver',
                            style: TextStyle(
                              fontSize: 13,
                              color: _isDriver
                                  ? Colors.blue[700]
                                  : Colors.grey[600],
                            ),
                          ),
                          const Spacer(),
                          Switch(
                            value: _isDriver,
                            onChanged: (v) => setState(() => _isDriver = v),
                            activeColor: Colors.blue[600],
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Color Picker - compact
                  const Text(
                    'Color',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(employeeColors.length, (i) {
                      final color = employeeColors[i];
                      return GestureDetector(
                        onTap: () => setState(() => _colorIndex = i),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _colorIndex == i
                                  ? Colors.black
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: _colorIndex == i
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 18,
                                )
                              : null,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),

                  // Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4299E1),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                isNew ? 'Create' : 'Save',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final name = _nameCtrl.text.trim();
      final email = _emailCtrl.text.trim();
      final wage = double.parse(_wageCtrl.text.replaceAll(',', '.'));

      if (widget.employee == null) {
        // === CREATE NEW EMPLOYEE ===
        final password = _passwordCtrl.text;
        String? userId;

        // Only create auth user if they're a driver (need login access)
        if (_isDriver) {
          try {
            final authRes = await _supabase.auth.signUp(
              email: email,
              password: password,
              data: {'name': name, 'role': 'driver'},
            );
            userId = authRes.user?.id;
          } catch (authError) {
            // Check if user already exists
            if (authError.toString().contains('already_exists') ||
                authError.toString().contains('already registered')) {
              throw Exception(
                'This email is already registered. Use a different email or edit the existing employee.',
              );
            }
            rethrow;
          }

          if (userId == null) throw Exception('Failed to create user account');
        }

        // Create employee record
        final empRes = await _supabase
            .from('employees')
            .insert({
              'name': name,
              'email': email,
              'hourly_wage': wage,
              'color_index': _colorIndex,
              'active': true,
              'is_driver': _isDriver,
              'auth_user_id': userId, // null for non-drivers
            })
            .select()
            .single();

        // If driver, also create driver record
        if (_isDriver && userId != null) {
          await _supabase.from('drivers').insert({
            'user_id': userId,
            'name': name,
            'is_online': false,
          });
        }

        final newEmp = ScheduleEmployee.fromJson(empRes);
        widget.onSaved(newEmp);
      } else {
        // === UPDATE EXISTING EMPLOYEE ===
        final wasDriver = widget.employee!.isDriver;
        final authUserId = widget.employee!.authUserId;

        await _supabase
            .from('employees')
            .update({
              'name': name,
              'email': email,
              'hourly_wage': wage,
              'color_index': _colorIndex,
              'is_driver': _isDriver,
            })
            .eq('id', widget.employee!.id);

        // Handle driver status changes
        if (_isDriver && !wasDriver && authUserId != null) {
          // Becoming a driver - create driver record
          final existingDriver = await _supabase
              .from('drivers')
              .select('id')
              .eq('user_id', authUserId)
              .maybeSingle();

          if (existingDriver == null) {
            await _supabase.from('drivers').insert({
              'user_id': authUserId,
              'name': name,
              'is_online': false,
            });
          }
        } else if (!_isDriver && wasDriver && authUserId != null) {
          // No longer a driver - remove driver record
          await _supabase.from('drivers').delete().eq('user_id', authUserId);
        } else if (_isDriver && authUserId != null) {
          // Still a driver, update name
          await _supabase
              .from('drivers')
              .update({'name': name})
              .eq('user_id', authUserId);
        }

        final updated = ScheduleEmployee(
          id: widget.employee!.id,
          name: name,
          email: email,
          hourlyWage: wage,
          colorIndex: _colorIndex,
          active: true,
          isDriver: _isDriver,
          authUserId: authUserId,
        );
        widget.onSaved(updated);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

// ============ ADD SHIFT DIALOG ============

class _AddShiftDialog extends StatefulWidget {
  final List<ScheduleEmployee> employees;
  final DateTime date;
  final ScheduleEmployee? preselectedEmployee;
  final List<Shift> existingShifts;
  final VoidCallback onSaved;

  const _AddShiftDialog({
    required this.employees,
    required this.date,
    this.preselectedEmployee,
    required this.existingShifts,
    required this.onSaved,
  });

  @override
  State<_AddShiftDialog> createState() => _AddShiftDialogState();
}

class _AddShiftDialogState extends State<_AddShiftDialog> {
  final _supabase = Supabase.instance.client;
  final _startCtrl = TextEditingController(text: '09:00');
  final _endCtrl = TextEditingController(text: '17:00');

  String? _selectedEmployeeId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Use ID instead of object to avoid reference mismatch issues
    if (widget.preselectedEmployee != null) {
      _selectedEmployeeId = widget.preselectedEmployee!.id;
    } else if (widget.employees.isNotEmpty) {
      _selectedEmployeeId = widget.employees.first.id;
    }
  }

  ScheduleEmployee? get _selectedEmployee {
    if (_selectedEmployeeId == null) return null;
    try {
      return widget.employees.firstWhere((e) => e.id == _selectedEmployeeId);
    } catch (_) {
      return widget.employees.isNotEmpty ? widget.employees.first : null;
    }
  }

  @override
  void dispose() {
    _startCtrl.dispose();
    _endCtrl.dispose();
    super.dispose();
  }

  int _getShiftCountForEmployee(String empId) =>
      widget.existingShifts.where((s) => s.employeeId == empId).length;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340, maxHeight: 450),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add Shift',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // Employee dropdown
              DropdownButtonFormField<String>(
                value: _selectedEmployeeId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Employee',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items: widget.employees.map((e) {
                  final shiftCount = _getShiftCountForEmployee(e.id);
                  final color =
                      employeeColors[e.colorIndex % employeeColors.length];
                  return DropdownMenuItem<String>(
                    value: e.id,
                    enabled: shiftCount < 2,
                    child: Row(
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            e.name,
                            style: TextStyle(
                              color: shiftCount >= 2 ? Colors.grey : null,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (shiftCount >= 2)
                          const Text(
                            ' (max)',
                            style: TextStyle(color: Colors.grey, fontSize: 11),
                          ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _selectedEmployeeId = v),
              ),
              const SizedBox(height: 16),

              // Time inputs
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _startCtrl,
                      decoration: InputDecoration(
                        labelText: 'Start',
                        hintText: '09:00',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      keyboardType: TextInputType.datetime,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '→',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  ),
                  Expanded(
                    child: TextFormField(
                      controller: _endCtrl,
                      decoration: InputDecoration(
                        labelText: 'End',
                        hintText: '17:00',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      keyboardType: TextInputType.datetime,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Wage preview
              if (_selectedEmployee != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.euro,
                        size: 18,
                        color: Color(0xFF2E7D32),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _calculateWage().toStringAsFixed(2),
                        style: const TextStyle(
                          color: Color(0xFF2E7D32),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              const Spacer(),

              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4299E1),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Add',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _calculateWage() {
    if (_selectedEmployee == null) return 0;

    final start = _parseTime(_startCtrl.text);
    final end = _parseTime(_endCtrl.text);
    if (start == null || end == null) return 0;

    int minutes = end >= start ? end - start : (1440 - start) + end;
    return (minutes / 60.0) * _selectedEmployee!.hourlyWage;
  }

  int? _parseTime(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59)
      return null;
    return h * 60 + m;
  }

  String _formatTime(String input) {
    final parts = input.split(':');
    if (parts.length != 2) return input;
    final h = int.tryParse(parts[0])?.toString().padLeft(2, '0') ?? parts[0];
    final m = int.tryParse(parts[1])?.toString().padLeft(2, '0') ?? parts[1];
    return '$h:$m';
  }

  Future<void> _save() async {
    if (_selectedEmployeeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an employee'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final start = _parseTime(_startCtrl.text);
    final end = _parseTime(_endCtrl.text);

    if (start == null || end == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid time format. Use HH:MM'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final dateStr =
          '${widget.date.year}-${widget.date.month.toString().padLeft(2, '0')}-${widget.date.day.toString().padLeft(2, '0')}';

      await _supabase.from('employee_shifts').insert({
        'employee_id': _selectedEmployeeId,
        'date': dateStr,
        'start_time': _formatTime(_startCtrl.text),
        'end_time': _formatTime(_endCtrl.text),
      });

      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

// ============ EDIT SHIFT DIALOG ============

class _EditShiftDialog extends StatefulWidget {
  final Shift shift;
  final ScheduleEmployee employee;
  final VoidCallback onSaved;
  final VoidCallback onDeleted;

  const _EditShiftDialog({
    required this.shift,
    required this.employee,
    required this.onSaved,
    required this.onDeleted,
  });

  @override
  State<_EditShiftDialog> createState() => _EditShiftDialogState();
}

class _EditShiftDialogState extends State<_EditShiftDialog> {
  final _supabase = Supabase.instance.client;
  late TextEditingController _startCtrl;
  late TextEditingController _endCtrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _startCtrl = TextEditingController(
      text: widget.shift.startTime.substring(0, 5),
    );
    _endCtrl = TextEditingController(
      text: widget.shift.endTime.substring(0, 5),
    );
  }

  @override
  void dispose() {
    _startCtrl.dispose();
    _endCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color =
        employeeColors[widget.employee.colorIndex % employeeColors.length];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        widget.employee.name[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.employee.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: () async {
                      Navigator.pop(context);
                      await _supabase
                          .from('employee_shifts')
                          .delete()
                          .eq('id', widget.shift.id);
                      widget.onDeleted();
                    },
                    child: Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: Colors.red[400],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Time inputs
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _startCtrl,
                      decoration: InputDecoration(
                        labelText: 'Start',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '→',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ),
                  Expanded(
                    child: TextFormField(
                      controller: _endCtrl,
                      decoration: InputDecoration(
                        labelText: 'End',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Wage
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.euro, size: 16, color: Color(0xFF2E7D32)),
                    const SizedBox(width: 4),
                    Text(
                      _calculateWage().toStringAsFixed(2),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E7D32),
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4299E1),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Save',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _calculateWage() {
    final start = _parseTime(_startCtrl.text);
    final end = _parseTime(_endCtrl.text);
    if (start == null || end == null) return 0;
    int minutes = end >= start ? end - start : (1440 - start) + end;
    return (minutes / 60.0) * widget.employee.hourlyWage;
  }

  int? _parseTime(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);

    try {
      await _supabase
          .from('employee_shifts')
          .update({'start_time': _startCtrl.text, 'end_time': _endCtrl.text})
          .eq('id', widget.shift.id);

      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
