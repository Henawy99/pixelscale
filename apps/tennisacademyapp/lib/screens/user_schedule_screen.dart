import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/session_model.dart';
import '../constants/levels.dart';
import '../services/session_service.dart';

/// User schedule tab: read-only week/day view.
class UserScheduleScreen extends StatefulWidget {
  const UserScheduleScreen({super.key});

  @override
  State<UserScheduleScreen> createState() => _UserScheduleScreenState();
}

class _UserScheduleScreenState extends State<UserScheduleScreen> {
  bool _weekView = false;
  DateTime _selectedDate = DateTime.now();
  List<SessionModel> _sessions = [];

  /// Week view: cache of date -> sessions so switching days doesn't reload.
  final Map<String, List<SessionModel>> _weekCache = {};
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _dateStr(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_weekView) {
        final weekStart = _selectedDate.subtract(
          Duration(days: _selectedDate.weekday - 1),
        );
        final weekEnd = weekStart.add(const Duration(days: 6));
        final startStr = _dateStr(weekStart);
        final endStr = _dateStr(weekEnd);
        final all = await SessionService.fetchSessionsWithSlotAssignmentsRange(
          startStr,
          endStr,
        );
        if (!mounted) return;
        _weekCache.clear();
        for (final s in all) {
          _weekCache.putIfAbsent(s.date, () => []).add(s);
        }
        for (final list in _weekCache.values) {
          list.sort((a, b) => a.startTime.compareTo(b.startTime));
        }
        setState(() {
          _sessions = _weekCache[_dateStr(_selectedDate)] ?? [];
          _loading = false;
        });
      } else {
        final dateStr = _dateStr(_selectedDate);
        final sessions = await SessionService.fetchSessionsWithSlotAssignments(
          dateStr,
        );
        if (mounted) {
          setState(() {
            _sessions = sessions;
            _loading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  void _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final sessionsByCourt = <int, List<SessionModel>>{};
    for (final s in _sessions) {
      sessionsByCourt.putIfAbsent(s.courtId, () => []).add(s);
    }
    for (final list in sessionsByCourt.values) {
      list.sort((a, b) => a.startTime.compareTo(b.startTime));
    }

    if (_weekView) {
      return Column(
        children: [
          _buildToolbar(),
          Expanded(child: _buildWeekView()),
        ],
      );
    }

    return Column(
      children: [
        _buildToolbar(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: 800, // 4 columns * 200px
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [1, 2, 3, 4].map((courtId) {
                    return Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          border: Border(
                            right: BorderSide(color: Colors.grey.shade200),
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border(
                                  bottom: BorderSide(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.02),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.sports_tennis,
                                    size: 16,
                                    color: Colors.teal.shade800,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'COURT $courtId',
                                    style: TextStyle(
                                      color: Colors.teal.shade900,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.fromLTRB(
                                  8,
                                  16,
                                  8,
                                  88,
                                ),
                                child: Column(
                                  children: (sessionsByCourt[courtId] ?? [])
                                      .map((s) => _GridSessionCard(session: s))
                                      .toList(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWeekView() {
    final weekStart = _selectedDate.subtract(
      Duration(days: _selectedDate.weekday - 1),
    );
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        itemCount: 7,
        itemBuilder: (context, i) {
          final d = weekStart.add(Duration(days: i));
          final dateStr = _dateStr(d);
          final daySessions = _weekCache[dateStr] ?? [];
          final byCourt = <int, List<SessionModel>>{};
          for (final s in daySessions) {
            byCourt.putIfAbsent(s.courtId, () => []).add(s);
          }
          for (final list in byCourt.values) {
            list.sort((a, b) => a.startTime.compareTo(b.startTime));
          }

          final isToday =
              d.day == DateTime.now().day &&
              d.month == DateTime.now().month &&
              d.year == DateTime.now().year;

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
              border: isToday
                  ? Border.all(color: const Color(0xFFFFDE21), width: 2)
                  : Border.all(color: Colors.grey.shade100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Day Header
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: isToday
                        ? const Color(0xFFFFDE21).withOpacity(0.15)
                        : Colors.grey.shade50,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('EEEE, MMM d').format(d),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isToday
                              ? Colors.orange.shade900
                              : Colors.black87,
                        ),
                      ),
                      if (daySessions.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Text(
                            '${daySessions.length} sessions',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Day Content
                if (daySessions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Center(
                      child: Text(
                        'No sessions scheduled',
                        style: TextStyle(
                          color: Colors.black38,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        for (final courtId in [1, 2, 3, 4])
                          if ((byCourt[courtId] ?? []).isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 4,
                                bottom: 8,
                                top: 4,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.sports_tennis,
                                    size: 14,
                                    color: Colors.teal.shade700,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'COURT $courtId',
                                    style: TextStyle(
                                      color: Colors.teal.shade700,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ...(byCourt[courtId] ?? []).map(
                              (s) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _CompactSessionRow(session: s),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildToolbar() {
    return Material(
      color: const Color(0xFFFFDE21),
      elevation: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, color: Colors.black),
                  onPressed: () {
                    final days = _weekView ? 7 : 1;
                    setState(() {
                      _selectedDate = _selectedDate.subtract(
                        Duration(days: days),
                      );
                      _load();
                    });
                  },
                ),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 18,
                          color: Colors.black,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat(
                            _weekView ? 'MMM d' : 'EEE, MMM d',
                          ).format(_selectedDate),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, color: Colors.black),
                  onPressed: () {
                    final days = _weekView ? 7 : 1;
                    setState(() {
                      _selectedDate = _selectedDate.add(Duration(days: days));
                      _load();
                    });
                  },
                ),
                const Spacer(),
                // Using a customized container instead of SegmentedButton for color control
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.black54),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ToolbarButton(
                        label: 'Day',
                        isSelected: !_weekView,
                        onTap: () {
                          if (_weekView) {
                            setState(() => _weekView = false);
                            _load();
                          }
                        },
                      ),
                      _ToolbarButton(
                        label: 'Week',
                        isSelected: _weekView,
                        onTap: () {
                          if (!_weekView) {
                            setState(() => _weekView = true);
                            _load();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToolbarButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.orange.shade900 : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

class _CompactSessionRow extends StatelessWidget {
  final SessionModel session;

  const _CompactSessionRow({required this.session});

  @override
  Widget build(BuildContext context) {
    final info = levelInfoForClass(session.name);
    final count = session.playerCount;
    final max = session.maxCapacity;
    final color = info?.color ?? Colors.grey;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.15),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    session.timeRange,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[800],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: count >= max
                        ? Colors.red.withOpacity(0.1)
                        : Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$count/$max',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: count >= max ? Colors.red : Colors.green[700],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    session.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GridSessionCard extends StatelessWidget {
  final SessionModel session;

  const _GridSessionCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final slots = session.slotPlayerNames ?? {1: '', 2: '', 3: '', 4: ''};
    final info = levelInfoForClass(session.name);
    final headerColor = info?.color ?? Colors.grey;
    final isDarkHeader = headerColor.computeLuminance() < 0.5;
    final textColor = isDarkHeader ? Colors.white : Colors.black;
    final count = session.playerCount;
    final max = session.maxCapacity;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [headerColor.withOpacity(0.8), headerColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 10,
                ),
                child: Column(
                  children: [
                    Text(
                      session.name,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.access_time_filled,
                          size: 12,
                          color: textColor.withOpacity(0.8),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          session.timeRange,
                          style: TextStyle(
                            color: textColor.withOpacity(0.95),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.people, size: 10, color: textColor),
                              const SizedBox(width: 3),
                              Text(
                                '$count/$max',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Slots
          Column(
            children: [
              for (int i = 1; i <= 4; i++)
                Material(
                  color: i % 2 == 0 ? Colors.grey[50] : Colors.white,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 8,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Colors.grey.shade100),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (slots[i]?.isNotEmpty == true) ...[
                          CircleAvatar(
                            radius: 10,
                            backgroundColor: headerColor.withOpacity(0.2),
                            child: Text(
                              slots[i]!.substring(0, 1).toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: headerColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              slots[i]!,
                              style: TextStyle(
                                color: Colors.blueGrey.shade900,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ] else ...[
                          Icon(
                            Icons.person_outline,
                            size: 14,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Empty Slot',
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
