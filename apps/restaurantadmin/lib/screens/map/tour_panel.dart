import 'package:flutter/material.dart';
import 'package:restaurantadmin/screens/map/tour_eta.dart';

/// Driver colours, shared by the panel and the map markers.
const List<Color> kDriverColors = [
  Color(0xFFE53935), // Red
  Color(0xFF8E24AA), // Purple
  Color(0xFF3949AB), // Indigo
  Color(0xFF1E88E5), // Blue
  Color(0xFF00ACC1), // Cyan
  Color(0xFF43A047), // Green
  Color(0xFFFB8C00), // Orange
  Color(0xFF6D4C41), // Brown
];

/// A negative index (a tour without a known driver) is grey.
Color driverColor(int colorIndex) => colorIndex < 0
    ? const Color(0xFF6B7280)
    : kDriverColors[colorIndex % kDriverColors.length];

// Palette (Tailwind greys, like the rest of the app).
const _ink = Color(0xFF111827);
const _muted = Color(0xFF6B7280);
const _faint = Color(0xFF9CA3AF);
const _line = Color(0xFFE5E7EB);
const _soft = Color(0xFFF3F4F6);
const _indigo = Color(0xFF4F46E5);
const _green = Color(0xFF059669);
const _amber = Color(0xFFD97706);
const _red = Color(0xFFDC2626);

/// The Map tab's side panel: every driver's tour with live times, then the orders
/// still waiting for a driver.
class TourPanel extends StatelessWidget {
  final List<DriverBoard> boards;
  final List<Map<String, dynamic>> waiting;
  final Map<String, Map<String, dynamic>> ordersById;
  final DateTime now;
  final String? selectedDriverId;
  final String? selectedStopId;
  final bool loading;
  final bool planning;
  final String? problem;
  final ScrollController? scrollController;

  /// Shown above the content (the drag handle on phones).
  final Widget? header;
  final void Function(DriverBoard board) onDriverTap;
  final void Function(DriverBoard board, TourStop stop) onStopTap;
  final void Function(String orderId) onOrderDetails;
  final void Function(String phone)? onCall;
  final void Function(Tour tour)? onStartTour;
  final void Function(TourStop stop, DriverBoard target)? onMoveStop;
  final VoidCallback onPlanNow;

  const TourPanel({
    super.key,
    required this.boards,
    required this.waiting,
    required this.ordersById,
    required this.now,
    required this.onDriverTap,
    required this.onStopTap,
    required this.onOrderDetails,
    required this.onPlanNow,
    this.selectedDriverId,
    this.selectedStopId,
    this.loading = false,
    this.planning = false,
    this.problem,
    this.scrollController,
    this.header,
    this.onCall,
    this.onStartTour,
    this.onMoveStop,
  });

  @override
  Widget build(BuildContext context) {
    final onTour = boards.where((b) => b.current != null).length;
    final online = boards.where((b) => b.isOnline).length;
    final onlineBoards = boards.where((b) => b.isOnline).toList();

    return ListView(
      controller: scrollController,
      padding: EdgeInsets.zero,
      children: [
        if (header != null) header!,
        if (problem != null) _ProblemBanner(text: problem!),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Stat(
                  value: '$onTour',
                  label: onTour == 1 ? 'tour on the road' : 'tours on the road',
                  color: _indigo,
                ),
                const SizedBox(width: 8),
                _Stat(
                  value: '${waiting.length}',
                  label: 'waiting for a driver',
                  color: waiting.isEmpty ? _green : _amber,
                ),
                const SizedBox(width: 8),
                _Stat(
                  value: '$online',
                  label: online == 1 ? 'driver online' : 'drivers online',
                  color: online == 0 ? _red : _green,
                ),
              ],
            ),
          ),
        ),
        if (loading && boards.isEmpty)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (boards.isEmpty)
          _EmptyState(planning: planning, onPlanNow: onPlanNow)
        else
          for (final b in boards)
            _DriverCard(
              board: b,
              now: now,
              ordersById: ordersById,
              selected: b.driverId == selectedDriverId,
              selectedStopId: selectedStopId,
              onTap: () => onDriverTap(b),
              onStopTap: (s) => onStopTap(b, s),
              onOrderDetails: onOrderDetails,
              onCall: onCall,
              onStartTour: onStartTour,
              moveTargets: onMoveStop == null
                  ? const []
                  : onlineBoards
                        .where((o) => o.driverId != b.driverId)
                        .toList(),
              onMoveStop: onMoveStop,
            ),
        _WaitingSection(
          orders: waiting,
          now: now,
          planning: planning,
          onPlanNow: onPlanNow,
          onOrderDetails: onOrderDetails,
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Summary, banners, empty state
// ─────────────────────────────────────────────────────────────────────────────

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _Stat({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: color,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 2,
              style: const TextStyle(fontSize: 11, color: _muted, height: 1.2),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProblemBanner extends StatelessWidget {
  final String text;
  const _ProblemBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, size: 18, color: _amber),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: Color(0xFF92400E)),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool planning;
  final VoidCallback onPlanNow;
  const _EmptyState({required this.planning, required this.onPlanNow});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              color: Color(0xFFEEF2FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.delivery_dining_rounded,
              size: 40,
              color: _indigo,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'No drivers on shift',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tours show up here as soon as a driver is online in the driver app.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: _muted),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: planning ? null : onPlanNow,
            icon: const Icon(Icons.autorenew_rounded, size: 18),
            label: Text(planning ? 'Planning…' : 'Plan tours now'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Driver card
// ─────────────────────────────────────────────────────────────────────────────

class _DriverCard extends StatelessWidget {
  final DriverBoard board;
  final DateTime now;
  final Map<String, Map<String, dynamic>> ordersById;
  final bool selected;
  final String? selectedStopId;
  final VoidCallback onTap;
  final void Function(TourStop stop) onStopTap;
  final void Function(String orderId) onOrderDetails;
  final void Function(String phone)? onCall;
  final void Function(Tour tour)? onStartTour;
  final List<DriverBoard> moveTargets;
  final void Function(TourStop stop, DriverBoard target)? onMoveStop;

  const _DriverCard({
    required this.board,
    required this.now,
    required this.ordersById,
    required this.selected,
    required this.selectedStopId,
    required this.onTap,
    required this.onStopTap,
    required this.onOrderDetails,
    required this.onCall,
    required this.onStartTour,
    required this.moveTargets,
    required this.onMoveStop,
  });

  @override
  Widget build(BuildContext context) {
    final color = driverColor(board.colorIndex);
    final current = board.current;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? color : _line,
          width: selected ? 2 : 1,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: _DriverHeader(board: board, now: now, color: color),
            ),
          ),
          if (current != null) ...[
            _BackBox(tour: current, now: now, color: color),
            _TourStops(
              tour: current,
              now: now,
              color: color,
              ordersById: ordersById,
              selectedStopId: selectedStopId,
              onStopTap: onStopTap,
              onOrderDetails: onOrderDetails,
              onCall: onCall,
              // The food is in the car: stops on the road can't go to another driver.
              moveTargets: const [],
              onMoveStop: null,
            ),
          ] else if (board.isOnline && board.upcoming.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: _Note(
                icon: Icons.storefront_outlined,
                text: 'At the restaurant, no tour planned yet.',
              ),
            ),
          for (var i = 0; i < board.upcoming.length; i++)
            _UpcomingTour(
              tour: board.upcoming[i],
              index: i,
              numberOffset:
                  (current?.stops.length ?? 0) +
                  board.upcoming
                      .take(i)
                      .fold<int>(0, (n, t) => n + t.stops.length),
              hasCurrent: current != null,
              driverName: board.name,
              now: now,
              color: color,
              ordersById: ordersById,
              selectedStopId: selectedStopId,
              onStopTap: onStopTap,
              onOrderDetails: onOrderDetails,
              onCall: onCall,
              onStartTour: current == null && board.driverId.isNotEmpty
                  ? onStartTour
                  : null,
              moveTargets: moveTargets,
              onMoveStop: onMoveStop,
            ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _DriverHeader extends StatelessWidget {
  final DriverBoard board;
  final DateTime now;
  final Color color;
  const _DriverHeader({
    required this.board,
    required this.now,
    required this.color,
  });

  static String _away(DriverBoard b) {
    final m = b.metersFromStore ?? 0;
    return 'Not at the restaurant · ${m < 1000 ? '${(m / 50).round() * 50} m' : '${(m / 1000).toStringAsFixed(1)} km'} away';
  }

  String get _activityText {
    final c = board.current;
    if (board.driverId.isEmpty)
      return 'Tour without a driver — give its orders to a driver';
    switch (board.activity) {
      case DriverActivity.delivering:
        final done = c!.deliveredCount;
        final total = c.stops.length;
        final next = c.nextStop;
        if (next != null && next.driverIsHere)
          return 'At ${next.name} now · $done of $total delivered';
        return 'Delivering · $done of $total delivered';
      case DriverActivity.returning:
        return c!.driverAtStore
            ? 'Back at the restaurant · tour not closed in the app'
            : 'All delivered · driving back';
      case DriverActivity.waitingToLeave:
        final t = board.upcoming.first;
        final leaves = t.departAt;
        if (board.awayFromStore)
          return '${_away(board)} · next tour is waiting';
        if (leaves == null) return 'At the restaurant · next tour ready';
        return leaves.isAfter(now.add(const Duration(seconds: 60)))
            ? 'At the restaurant · leaves ${clock(leaves)}'
            : 'At the restaurant · should leave now';
      case DriverActivity.atRestaurant:
        return board.awayFromStore ? _away(board) : 'At the restaurant';
      case DriverActivity.offline:
        return 'Offline';
    }
  }

  @override
  Widget build(BuildContext context) {
    final fresh = board.gpsFresh(now);
    final speedKmh = (board.speedMs ?? 0) * 3.6;
    final dim = !board.isOnline;

    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: dim ? _faint : color,
          child: Text(
            board.name.isNotEmpty ? board.name[0].toUpperCase() : '?',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                board.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _activityText,
                style: const TextStyle(fontSize: 12.5, color: _muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _GpsChip(board: board, now: now, fresh: fresh),
            if (fresh && speedKmh >= 5) ...[
              const SizedBox(height: 4),
              Text(
                '${speedKmh.round()} km/h',
                style: const TextStyle(fontSize: 11, color: _faint),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _GpsChip extends StatelessWidget {
  final DriverBoard board;
  final DateTime now;
  final bool fresh;
  const _GpsChip({required this.board, required this.now, required this.fresh});

  @override
  Widget build(BuildContext context) {
    final String text;
    final Color color;
    if (!board.isOnline) {
      text = 'Offline';
      color = _faint;
    } else if (fresh) {
      text = 'Live';
      color = _green;
    } else if (board.lastSeenAt == null || board.position == null) {
      text = 'No GPS';
      color = _amber;
    } else {
      text = 'GPS ${relative(board.lastSeenAt, now)}';
      color = _amber;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// The big "back at the restaurant" line with a progress bar.
class _BackBox extends StatelessWidget {
  final Tour tour;
  final DateTime now;
  final Color color;
  const _BackBox({required this.tour, required this.now, required this.color});

  @override
  Widget build(BuildContext context) {
    final total = tour.stops.length;
    final done = tour.deliveredCount;
    final back = tour.returnAt;
    final atStore = tour.driverAtStore;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      atStore ? 'AT THE RESTAURANT' : 'BACK AT THE RESTAURANT',
                      style: const TextStyle(
                        fontSize: 10.5,
                        letterSpacing: 0.6,
                        fontWeight: FontWeight.w700,
                        color: _muted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.end,
                      spacing: 8,
                      children: [
                        Text(
                          atStore ? 'Now' : '~${clock(back)}',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: _ink,
                            height: 1.1,
                          ),
                        ),
                        if (!atStore)
                          Text(
                            relative(back, now),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: color,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (tour.departAt != null)
                Text(
                  'left ${tour.departApprox ? '~' : ''}${clock(tour.departAt)}',
                  style: const TextStyle(fontSize: 12, color: _muted),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total == 0 ? 1 : done / total,
              minHeight: 6,
              backgroundColor: Colors.white,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$done of $total delivered${tour.lateCount > 0 ? ' · ${tour.lateCount} running late' : ''}'
            '${tour.fromGps ? '' : ' · no live GPS, times from the plan'}',
            style: TextStyle(
              fontSize: 11.5,
              color: tour.lateCount > 0 ? _red : _muted,
            ),
          ),
          if (tour.stale) ...[
            const SizedBox(height: 8),
            const _Note(
              icon: Icons.warning_amber_rounded,
              text:
                  'This tour has been open for hours — it was probably never closed in the driver app.',
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stops
// ─────────────────────────────────────────────────────────────────────────────

class _TourStops extends StatelessWidget {
  final Tour tour;
  final DateTime now;
  final Color color;
  final Map<String, Map<String, dynamic>> ordersById;
  final String? selectedStopId;
  final void Function(TourStop stop) onStopTap;
  final void Function(String orderId) onOrderDetails;
  final void Function(String phone)? onCall;
  final List<DriverBoard> moveTargets;
  final void Function(TourStop stop, DriverBoard target)? onMoveStop;
  final bool planned;

  /// Stops are numbered across the driver's tours (1–2 now, 3–6 on the next tour).
  final int numberOffset;

  const _TourStops({
    required this.tour,
    required this.now,
    required this.color,
    required this.ordersById,
    required this.selectedStopId,
    required this.onStopTap,
    required this.onOrderDetails,
    required this.onCall,
    required this.moveTargets,
    required this.onMoveStop,
    this.planned = false,
    this.numberOffset = 0,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      _EndpointRow(
        icon: Icons.storefront_rounded,
        color: color,
        title: 'Restaurant',
        trailing: tour.departAt == null
            ? ''
            : planned
            ? (tour.departAt!.isAfter(now.add(const Duration(seconds: 60)))
                  ? 'leaves ${clock(tour.departAt)}'
                  : 'should leave now')
            : 'left ${tour.departApprox ? '~' : ''}${clock(tour.departAt)}',
        isFirst: true,
      ),
    ];
    for (final s in tour.stops) {
      rows.add(
        _StopRow(
          stop: s,
          tour: tour,
          number: numberOffset + tour.stops.indexOf(s) + 1,
          now: now,
          color: color,
          order: s.orderId != null ? ordersById[s.orderId] : null,
          selected: s.key == selectedStopId,
          planned: planned,
          onTap: () => onStopTap(s),
          onOrderDetails: onOrderDetails,
          onCall: onCall,
          moveTargets: s.isDone ? const [] : moveTargets,
          onMoveStop: onMoveStop,
        ),
      );
    }
    rows.add(
      _EndpointRow(
        icon: Icons.home_rounded,
        color: color,
        title: 'Back at the restaurant',
        drive: tour.returnDrive,
        trailing: tour.returnAt == null ? '' : '~${clock(tour.returnAt)}',
        sub: planned || tour.returnAt == null
            ? null
            : relative(tour.returnAt, now),
        isLast: true,
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 10, 10, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: rows,
      ),
    );
  }
}

/// Left rail: the dot/number with the line to the previous and next row.
class _Rail extends StatelessWidget {
  final Widget dot;
  final Color lineColor;
  final bool top;
  final bool bottom;
  const _Rail({
    required this.dot,
    required this.lineColor,
    this.top = true,
    this.bottom = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      child: Column(
        children: [
          Container(
            width: 2,
            height: 10,
            color: top ? lineColor : Colors.transparent,
          ),
          dot,
          Expanded(
            child: Container(
              width: 2,
              color: bottom ? lineColor : Colors.transparent,
            ),
          ),
        ],
      ),
    );
  }
}

class _EndpointRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String trailing;
  final String? sub;
  final Duration? drive;
  final bool isFirst;
  final bool isLast;

  const _EndpointRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.trailing,
    this.sub,
    this.drive,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (drive != null) _DriveConnector(drive: drive!, color: color),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Rail(
                top: !isFirst,
                bottom: !isLast,
                lineColor: color.withValues(alpha: 0.35),
                dot: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: _soft,
                    shape: BoxShape.circle,
                    border: Border.all(color: _line),
                  ),
                  child: Icon(icon, size: 15, color: _muted),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 12, 0, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _muted,
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            trailing,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _ink,
                            ),
                          ),
                          if (sub != null && sub!.isNotEmpty)
                            Text(
                              sub!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: _muted,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DriveConnector extends StatelessWidget {
  final Duration drive;
  final Color color;
  const _DriveConnector({required this.drive, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 22,
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Center(
              child: Container(width: 2, color: color.withValues(alpha: 0.35)),
            ),
          ),
          const Icon(
            Icons.directions_car_filled_rounded,
            size: 13,
            color: _faint,
          ),
          const SizedBox(width: 4),
          Text(
            drive == Duration.zero ? 'here' : '${minutes(drive)} drive',
            style: const TextStyle(fontSize: 11, color: _faint),
          ),
        ],
      ),
    );
  }
}

class _StopRow extends StatelessWidget {
  final TourStop stop;
  final Tour tour;
  final int number;
  final DateTime now;
  final Color color;
  final Map<String, dynamic>? order;
  final bool selected;
  final bool planned;
  final VoidCallback onTap;
  final void Function(String orderId) onOrderDetails;
  final void Function(String phone)? onCall;
  final List<DriverBoard> moveTargets;
  final void Function(TourStop stop, DriverBoard target)? onMoveStop;

  const _StopRow({
    required this.stop,
    required this.tour,
    required this.number,
    required this.now,
    required this.color,
    required this.order,
    required this.selected,
    required this.planned,
    required this.onTap,
    required this.onOrderDetails,
    required this.onCall,
    required this.moveTargets,
    required this.onMoveStop,
  });

  @override
  Widget build(BuildContext context) {
    final isNext = stop.state == StopState.next;
    final done = stop.isDone;
    final p = stop.punctuality;
    final total = (order?['total_price'] as num?)?.toDouble();
    final paysWith = double.tryParse('${order?['pays_with'] ?? ''}');
    final phone = (order?['customer_phone'] as String?)?.trim();
    final etaColor = switch (p) {
      Punctuality.late => _red,
      Punctuality.tight => _amber,
      _ => _ink,
    };

    final Widget dot = Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: done ? _green : (isNext ? color : Colors.white),
        shape: BoxShape.circle,
        border: Border.all(color: done ? _green : color, width: 2),
      ),
      child: Center(
        child: done
            ? Icon(
                stop.state == StopState.skipped
                    ? Icons.close_rounded
                    : Icons.check_rounded,
                size: 15,
                color: Colors.white,
              )
            : Text(
                '$number',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isNext ? Colors.white : color,
                ),
              ),
      ),
    );

    // Second line: promise, payment, problems.
    final chips = <Widget>[];
    if (isNext) {
      chips.add(
        _Tag(
          text: stop.driverIsHere ? 'AT THE DOOR' : 'NEXT',
          color: color,
          solid: true,
        ),
      );
    }
    if (stop.cancelled)
      chips.add(const _Tag(text: 'ORDER CANCELLED', color: _red, solid: true));
    if (done) {
      chips.add(
        _Tag(
          text: stop.state == StopState.skipped
              ? 'not delivered'
              : 'delivered ${clock(stop.deliveredAt)}',
          color: stop.state == StopState.skipped ? _red : _green,
        ),
      );
    } else if (stop.dueAt != null) {
      chips.add(switch (p) {
        Punctuality.late => _Tag(
          text: '${minutes(stop.lateBy)} late · due ${clock(stop.dueAt)}',
          color: _red,
        ),
        Punctuality.tight => _Tag(
          text: 'tight · due ${clock(stop.dueAt)}',
          color: _amber,
        ),
        _ => _Tag(
          text: 'on time · due ${clock(stop.dueAt)}',
          color: _green,
          outline: true,
        ),
      });
    }
    final orderedAt = parseTs(order?['created_at']);
    if (orderedAt != null) {
      chips.add(_Tag(text: 'ordered ${clock(orderedAt)}', color: _muted, outline: true));
    }
    if (isCash(order)) {
      // Foodora's amount to collect at the door can differ from the order total.
      final due = double.tryParse('${order?['collect'] ?? ''}') ?? total;
      final amount = due != null ? ' €${due.toStringAsFixed(2)}' : '';
      final change = paysWith != null && due != null && paysWith > due
          ? ' · pays with €${paysWith.toStringAsFixed(0)}'
          : '';
      chips.add(_Tag(text: 'Cash$amount$change', color: _amber));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!done && stop.drive != null)
          _DriveConnector(drive: stop.drive!, color: color)
        else
          const SizedBox(height: 4),
        Material(
          color: selected ? color.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Rail(dot: dot, lineColor: color.withValues(alpha: 0.35)),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(4, 8, 0, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      stop.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: done ? _muted : _ink,
                                      ),
                                    ),
                                    if (stop.address != null &&
                                        stop.address!.isNotEmpty)
                                      Text(
                                        stop.address!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: _muted,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (!done)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      stop.eta == null
                                          ? '–'
                                          : '~${clock(stop.eta)}',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: etaColor,
                                      ),
                                    ),
                                    if (stop.eta != null)
                                      Text(
                                        stop.driverIsHere
                                            ? 'now'
                                            : relative(stop.eta, now),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: _muted,
                                        ),
                                      ),
                                  ],
                                ),
                            ],
                          ),
                          if (chips.isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Wrap(spacing: 5, runSpacing: 4, children: chips),
                          ],
                        ],
                      ),
                    ),
                  ),
                  _StopMenu(
                    stop: stop,
                    phone: phone,
                    onOrderDetails: onOrderDetails,
                    onCall: onCall,
                    moveTargets: moveTargets,
                    onMoveStop: onMoveStop,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StopMenu extends StatelessWidget {
  final TourStop stop;
  final String? phone;
  final void Function(String orderId) onOrderDetails;
  final void Function(String phone)? onCall;
  final List<DriverBoard> moveTargets;
  final void Function(TourStop stop, DriverBoard target)? onMoveStop;

  const _StopMenu({
    required this.stop,
    required this.phone,
    required this.onOrderDetails,
    required this.onCall,
    required this.moveTargets,
    required this.onMoveStop,
  });

  @override
  Widget build(BuildContext context) {
    final items = <PopupMenuEntry<String>>[
      if (stop.orderId != null)
        const PopupMenuItem(
          value: 'details',
          child: _MenuLine(
            icon: Icons.receipt_long_outlined,
            text: 'Order details',
          ),
        ),
      if (phone != null && phone!.isNotEmpty && onCall != null)
        PopupMenuItem(
          value: 'call',
          child: _MenuLine(icon: Icons.call_outlined, text: 'Call $phone'),
        ),
      if (onMoveStop != null)
        for (final t in moveTargets)
          PopupMenuItem(
            value: 'move:${t.driverId}',
            child: _MenuLine(
              icon: Icons.swap_horiz_rounded,
              text: 'Give to ${t.name}',
            ),
          ),
    ];
    if (items.isEmpty) return const SizedBox(width: 8);
    return PopupMenuButton<String>(
      tooltip: 'More',
      icon: const Icon(Icons.more_vert_rounded, size: 18, color: _faint),
      padding: EdgeInsets.zero,
      itemBuilder: (_) => items,
      onSelected: (v) {
        if (v == 'details' && stop.orderId != null) {
          onOrderDetails(stop.orderId!);
        } else if (v == 'call' && phone != null) {
          onCall?.call(phone!);
        } else if (v.startsWith('move:')) {
          final id = v.substring(5);
          final target = moveTargets.where((t) => t.driverId == id).firstOrNull;
          if (target != null) onMoveStop?.call(stop, target);
        }
      },
    );
  }
}

class _MenuLine extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MenuLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: _muted),
        const SizedBox(width: 10),
        Text(text),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;
  final bool outline;
  final bool solid;
  const _Tag({
    required this.text,
    required this.color,
    this.outline = false,
    this.solid = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: solid
            ? color
            : (outline ? Colors.transparent : color.withValues(alpha: 0.1)),
        borderRadius: BorderRadius.circular(5),
        border: outline
            ? Border.all(color: color.withValues(alpha: 0.4))
            : null,
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: solid ? Colors.white : color,
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Note({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _soft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: _muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12.5, color: _muted),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Next tours
// ─────────────────────────────────────────────────────────────────────────────

class _UpcomingTour extends StatefulWidget {
  final Tour tour;
  final int index;
  final int numberOffset;
  final bool hasCurrent;
  final String driverName;
  final DateTime now;
  final Color color;
  final Map<String, Map<String, dynamic>> ordersById;
  final String? selectedStopId;
  final void Function(TourStop stop) onStopTap;
  final void Function(String orderId) onOrderDetails;
  final void Function(String phone)? onCall;
  final void Function(Tour tour)? onStartTour;
  final List<DriverBoard> moveTargets;
  final void Function(TourStop stop, DriverBoard target)? onMoveStop;

  const _UpcomingTour({
    required this.tour,
    required this.index,
    required this.numberOffset,
    required this.hasCurrent,
    required this.driverName,
    required this.now,
    required this.color,
    required this.ordersById,
    required this.selectedStopId,
    required this.onStopTap,
    required this.onOrderDetails,
    required this.onCall,
    required this.onStartTour,
    required this.moveTargets,
    required this.onMoveStop,
  });

  @override
  State<_UpcomingTour> createState() => _UpcomingTourState();
}

class _UpcomingTourState extends State<_UpcomingTour> {
  late bool _open = widget.index == 0;

  @override
  Widget build(BuildContext context) {
    final t = widget.tour;
    final title = widget.hasCurrent || widget.index > 0
        ? 'NEXT TOUR'
        : 'PLANNED TOUR';
    final leaves = t.departAt;
    final leavesText = leaves == null
        ? ''
        : leaves.isAfter(widget.now.add(const Duration(seconds: 60)))
        ? 'leaves ${clock(leaves)}'
        : 'should leave now';
    final count = t.stops.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 1, indent: 14, endIndent: 14),
        InkWell(
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.index > 0 ? '${widget.index + 1}. ' : ''}$title · $count ${count == 1 ? 'stop' : 'stops'}',
                        style: const TextStyle(
                          fontSize: 10.5,
                          letterSpacing: 0.6,
                          fontWeight: FontWeight.w700,
                          color: _muted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          leavesText,
                          if (t.returnAt != null) 'back ~${clock(t.returnAt)}',
                        ].where((s) => s.isNotEmpty).join(' · '),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                      ),
                      if (t.delay.inMinutes >= 1)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            '${minutes(t.delay)} later than planned — ${widget.driverName} is not back yet',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: _amber,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (t.lateCount > 0) ...[
                  _Tag(text: '${t.lateCount} late', color: _red),
                  const SizedBox(width: 4),
                ],
                Icon(
                  _open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  color: _faint,
                ),
              ],
            ),
          ),
        ),
        if (_open) ...[
          _TourStops(
            tour: t,
            now: widget.now,
            color: widget.color,
            ordersById: widget.ordersById,
            selectedStopId: widget.selectedStopId,
            onStopTap: widget.onStopTap,
            onOrderDetails: widget.onOrderDetails,
            onCall: widget.onCall,
            moveTargets: widget.moveTargets,
            onMoveStop: widget.onMoveStop,
            planned: true,
            numberOffset: widget.numberOffset,
          ),
          if (widget.onStartTour != null && widget.index == 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: OutlinedButton.icon(
                onPressed: () => widget.onStartTour!(t),
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: Text('${widget.driverName} has left — start this tour'),
              ),
            ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Orders waiting for a driver
// ─────────────────────────────────────────────────────────────────────────────

class _WaitingSection extends StatelessWidget {
  final List<Map<String, dynamic>> orders;
  final DateTime now;
  final bool planning;
  final VoidCallback onPlanNow;
  final void Function(String orderId) onOrderDetails;

  const _WaitingSection({
    required this.orders,
    required this.now,
    required this.planning,
    required this.onPlanNow,
    required this.onOrderDetails,
  });

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 6),
            child: Row(
              children: [
                const Icon(
                  Icons.hourglass_top_rounded,
                  size: 18,
                  color: _amber,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Waiting for a driver (${orders.length})',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: planning ? null : onPlanNow,
                  icon: const Icon(Icons.autorenew_rounded, size: 16),
                  label: Text(planning ? 'Planning…' : 'Plan now'),
                ),
              ],
            ),
          ),
          for (final o in orders)
            _WaitingRow(
              order: o,
              now: now,
              onTap: () => onOrderDetails(o['id'] as String),
            ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _WaitingRow extends StatelessWidget {
  final Map<String, dynamic> order;
  final DateTime now;
  final VoidCallback onTap;
  const _WaitingRow({
    required this.order,
    required this.now,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final due = dueAt(order);
    final laterTour = parseTs(order['planned_arrival_at']);
    final address = [
      order['customer_street'],
      order['customer_city'],
    ].whereType<String>().where((s) => s.trim().isNotEmpty).join(', ');
    final reason = order['is_unassignable'] == true
        ? order['unassignable_reason'] as String?
        : null;
    final overdue = due != null && due.isBefore(now);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order['customer_name'] as String? ?? 'Customer',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                  if (address.isNotEmpty)
                    Text(
                      address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: _muted),
                    ),
                  if (parseTs(order['created_at']) != null)
                    Text(
                      'ordered ${clock(parseTs(order['created_at']))}',
                      style: const TextStyle(fontSize: 11.5, color: _muted),
                    ),
                  if (reason != null && reason.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        reason,
                        style: const TextStyle(fontSize: 11.5, color: _red),
                      ),
                    )
                  else if (laterTour != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        'Planned for a later tour · ~${clock(laterTour)}',
                        style: const TextStyle(fontSize: 11.5, color: _muted),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (due != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'due ${clock(due)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: overdue ? _red : _ink,
                    ),
                  ),
                  Text(
                    relative(due, now),
                    style: const TextStyle(fontSize: 11, color: _muted),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
