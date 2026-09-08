import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:restaurantadmin/models/driver.dart' as app_driver_model;

/// Employee colors for driver markers and timeline lanes
const List<Color> kTimelineDriverColors = [
  Color(0xFFE53935), // Red
  Color(0xFF8E24AA), // Purple
  Color(0xFF3949AB), // Indigo
  Color(0xFF1E88E5), // Blue
  Color(0xFF00ACC1), // Cyan
  Color(0xFF43A047), // Green
  Color(0xFFFB8C00), // Orange
  Color(0xFF6D4C41), // Brown
];

/// Reusable Operator / Driver Timeline Widget
class DeliveryTimelineWidget extends StatefulWidget {
  final List<app_driver_model.Driver> drivers;
  final List<Map<String, dynamic>> routes;
  final List<Map<String, dynamic>> stops;
  final List<Map<String, dynamic>> unassignedOrders;
  final Set<String> highlightedStopIds;
  final String? singleDriverId; // When set, renders only this driver's lane (read-only)
  final int serviceDurationMinutes; // Fixed handover duration (default 5 min)
  final void Function(app_driver_model.Driver driver)? onDriverTap;
  final void Function(String stopId, String targetDriverId)? onReassignStop;
  final VoidCallback? onReplanRequested;

  const DeliveryTimelineWidget({
    super.key,
    required this.drivers,
    required this.routes,
    required this.stops,
    this.unassignedOrders = const [],
    this.highlightedStopIds = const {},
    this.singleDriverId,
    this.serviceDurationMinutes = 5,
    this.onDriverTap,
    this.onReassignStop,
    this.onReplanRequested,
  });

  @override
  State<DeliveryTimelineWidget> createState() => _DeliveryTimelineWidgetState();
}

class _DeliveryTimelineWidgetState extends State<DeliveryTimelineWidget> {
  late DateTime _timelineStart;
  final int _windowMinutes = 60;
  final double _pixelsPerMinute = 14.0;
  Timer? _tickerTimer;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _timelineStart = DateTime.now();
    // Refresh time axis every 30 seconds
    _tickerTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() {
          _timelineStart = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Color _getDriverColor(app_driver_model.Driver? driver) {
    if (driver == null) return Colors.grey;
    return kTimelineDriverColors[driver.colorIndex % kTimelineDriverColors.length];
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final displayDrivers = widget.singleDriverId != null
        ? widget.drivers.where((d) => d.id == widget.singleDriverId).toList()
        : widget.drivers;

    final timelineWidth = _windowMinutes * _pixelsPerMinute;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E222D),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          _buildHeaderBar(displayDrivers.length),

          // Main Timeline Content
          Container(
            constraints: const BoxConstraints(maxHeight: 280),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Unassigned Orders sidebar (if not single-driver mode and orders exist)
                if (widget.singleDriverId == null && widget.unassignedOrders.isNotEmpty)
                  _buildUnassignedDock(),

                // Scrollable Swimlanes
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: timelineWidth + 180, // 180px for driver headers
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Time axis row
                          _buildTimeAxisHeader(timelineWidth),

                          // Driver swimlane rows
                          if (displayDrivers.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                'No drivers currently available on shift',
                                style: TextStyle(color: Colors.grey[400], fontSize: 13),
                              ),
                            )
                          else
                            Expanded(
                              child: ListView.separated(
                                shrinkWrap: true,
                                itemCount: displayDrivers.length,
                                separatorBuilder: (_, __) => Divider(
                                  height: 1,
                                  color: Colors.white.withValues(alpha: 0.08),
                                ),
                                itemBuilder: (context, idx) {
                                  final driver = displayDrivers[idx];
                                  return _buildDriverLane(driver, timelineWidth);
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBar(int driverCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF282E3E),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(14),
          topRight: Radius.circular(14),
        ),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.timeline, color: Colors.amber, size: 18),
          const SizedBox(width: 8),
          Text(
            widget.singleDriverId != null ? 'My Route Timeline' : 'Live Driver Timeline (~60m)',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$driverCount on shift',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ),
          const Spacer(),
          // Legend
          _buildLegendDot(Colors.blue, 'Driving'),
          const SizedBox(width: 8),
          _buildLegendDot(Colors.grey[400]!, 'Handover'),
          const SizedBox(width: 8),
          _buildLegendDot(Colors.lightBlue[300]!, 'Return'),
          const SizedBox(width: 8),
          _buildLegendDot(Colors.amber, 'Wait food'),
          const SizedBox(width: 12),
          if (widget.onReplanRequested != null && widget.singleDriverId == null)
            InkWell(
              onTap: widget.onReplanRequested,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.indigo,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.autorenew, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text('Replan', style: TextStyle(color: Colors.white, fontSize: 11)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 10)),
      ],
    );
  }

  Widget _buildTimeAxisHeader(double timelineWidth) {
    return Container(
      height: 28,
      padding: const EdgeInsets.only(left: 170), // driver header offset
      decoration: BoxDecoration(
        color: const Color(0xFF181B24),
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: Stack(
        children: [
          // 10-minute intervals
          for (int m = 0; m <= _windowMinutes; m += 10) ...[
            Positioned(
              left: m * _pixelsPerMinute,
              top: 0,
              bottom: 0,
              child: Row(
                children: [
                  Container(
                    width: 1,
                    height: 12,
                    color: m == 0 ? Colors.redAccent : Colors.white24,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    m == 0
                        ? 'NOW ${_formatTime(_timelineStart)}'
                        : '+${m}m (${_formatTime(_timelineStart.add(Duration(minutes: m)))})',
                    style: TextStyle(
                      color: m == 0 ? Colors.redAccent : Colors.grey[400],
                      fontWeight: m == 0 ? FontWeight.bold : FontWeight.normal,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDriverLane(app_driver_model.Driver driver, double timelineWidth) {
    final driverColor = _getDriverColor(driver);

    // Find active route for this driver
    final route = widget.routes.cast<Map<String, dynamic>?>().firstWhere(
          (r) => r?['assigned_driver_id'] == driver.id,
          orElse: () => null,
        );

    final routeStops = route != null
        ? widget.stops.where((s) => s['delivery_route_id'] == route['id']).toList()
        : <Map<String, dynamic>>[];

    // Projected return time
    final projectedReturn = driver.projectedReturnAt ??
        (route != null && route['planned_return_at'] != null
            ? DateTime.tryParse(route['planned_return_at'] as String)
            : null);

    return InkWell(
      onTap: () {
        if (widget.onDriverTap != null) {
          widget.onDriverTap!(driver);
        } else {
          _showDriverDetailModal(driver, route, routeStops);
        }
      },
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            // Left driver identity card
            Container(
              width: 170,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: driverColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: driverColor.withValues(alpha: 0.4),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        driver.name.isNotEmpty ? driver.name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          driver.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          driver.isDemo ? 'Demo (Active)' : (driver.isOnline ? 'Active' : 'Standby'),
                          style: TextStyle(
                            color: (driver.isOnline || driver.isDemo) ? Colors.greenAccent : Colors.grey[400],
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Timeline lane track
            Expanded(
              child: SizedBox(
                width: timelineWidth,
                height: 44,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Background grid line for every 10 min
                    for (int m = 10; m <= _windowMinutes; m += 10)
                      Positioned(
                        left: m * _pixelsPerMinute,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 1,
                          color: Colors.white.withValues(alpha: 0.04),
                        ),
                      ),

                    // NOW marker (red vertical bar)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 2,
                        color: Colors.redAccent.withValues(alpha: 0.8),
                      ),
                    ),

                    // Route Segments
                    if (route != null && routeStops.isNotEmpty)
                      ..._buildRouteSegments(driver, route, routeStops, driverColor),

                    // Projected Return Badge (The most important number on screen!)
                    if (projectedReturn != null)
                      _buildReturnTimeBadge(projectedReturn, driverColor),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildRouteSegments(
    app_driver_model.Driver driver,
    Map<String, dynamic> route,
    List<Map<String, dynamic>> routeStops,
    Color driverColor,
  ) {
    final widgets = <Widget>[];
    final now = DateTime.now();

    // Sort customer delivery stops
    final customerStops = routeStops
        .where((s) => s['type'] == 'customer_delivery')
        .toList()
      ..sort((a, b) =>
          ((a['sequence_number'] as num?) ?? 0).compareTo((b['sequence_number'] as num?) ?? 0));

    DateTime? prevDeparture;
    final plannedDep = route['planned_departure_at'] != null
        ? DateTime.tryParse(route['planned_departure_at'] as String)
        : null;

    // Check if driver is currently waiting at depot for food
    if (plannedDep != null && plannedDep.isAfter(now)) {
      final waitSecs = plannedDep.difference(now).inSeconds;
      final waitWidth = (waitSecs / 60.0) * _pixelsPerMinute;
      if (waitWidth > 2) {
        widgets.add(
          Positioned(
            left: 0,
            top: 10,
            width: math.min(waitWidth, _windowMinutes * _pixelsPerMinute),
            height: 24,
            child: Tooltip(
              message: 'Waiting for food ready (departs ${_formatTime(plannedDep)})',
              child: CustomPaint(
                painter: const DashedBoxPainter(color: Colors.amberAccent),
                child: Container(
                  alignment: Alignment.center,
                  child: Text(
                    'Prep wait',
                    style: TextStyle(
                      color: Colors.amberAccent[100],
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
      prevDeparture = plannedDep;
    } else {
      prevDeparture = now;
    }

    // Check if driver is currently returning from a previous route
    if (driver.currentRouteId != null &&
        driver.projectedReturnAt != null &&
        driver.projectedReturnAt!.isAfter(now)) {
      final returnSecs = driver.projectedReturnAt!.difference(now).inSeconds;
      final returnWidth = (returnSecs / 60.0) * _pixelsPerMinute;
      widgets.add(
        Positioned(
          left: 0,
          top: 10,
          width: math.min(returnWidth, _windowMinutes * _pixelsPerMinute),
          height: 24,
          child: Tooltip(
            message: 'In flight / returning from previous route',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: CustomPaint(
                painter: HatchedPatternPainter(
                  color: driverColor.withValues(alpha: 0.7),
                  backgroundColor: driverColor.withValues(alpha: 0.2),
                ),
                child: Container(
                  alignment: Alignment.center,
                  child: const Text(
                    'Returning to Depot',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(color: Colors.black87, blurRadius: 2)],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      prevDeparture = driver.projectedReturnAt;
    }

    // Segments for customer stops
    for (int i = 0; i < customerStops.length; i++) {
      final stop = customerStops[i];
      final stopId = stop['id'] as String;
      final isHighlighted = widget.highlightedStopIds.contains(stopId);

      final arrivalStr = stop['planned_arrival_at'] as String? ??
          stop['estimated_arrival_time'] as String?;
      final arrivalTime = arrivalStr != null ? DateTime.tryParse(arrivalStr) : null;
      if (arrivalTime == null) continue;

      final startSecs = arrivalTime.isAfter(_timelineStart)
          ? arrivalTime.difference(_timelineStart).inSeconds
          : 0;
      final driveStartSecs = prevDeparture != null && prevDeparture.isAfter(_timelineStart)
          ? prevDeparture.difference(_timelineStart).inSeconds
          : 0;

      final driveLeft = (driveStartSecs / 60.0) * _pixelsPerMinute;
      final driveWidth = math.max(0.0, ((startSecs - driveStartSecs) / 60.0) * _pixelsPerMinute);

      // Driving Segment (Solid driver color)
      if (driveWidth > 1) {
        widgets.add(
          Positioned(
            left: driveLeft,
            top: 12,
            width: driveWidth,
            height: 20,
            child: Tooltip(
              message: 'Driving to ${stop['customer_name'] ?? 'Stop #${i + 1}'}',
              child: Container(
                decoration: BoxDecoration(
                  color: driverColor,
                  borderRadius: BorderRadius.horizontal(
                    left: i == 0 ? const Radius.circular(4) : Radius.zero,
                  ),
                ),
              ),
            ),
          ),
        );
      }

      // Handover Segment (Grey service time, e.g. 5 min)
      final handoverWidth = widget.serviceDurationMinutes * _pixelsPerMinute;
      final stopLeft = (startSecs / 60.0) * _pixelsPerMinute;

      // Target delivery time check
      final targetStr = stop['_target_time'] as String? ??
          stop['target_delivery_time'] as String?;
      final targetTime = targetStr != null ? DateTime.tryParse(targetStr) : null;

      final isLate = targetTime != null &&
          arrivalTime.isAfter(targetTime.add(const Duration(minutes: 2)));

      widgets.add(
        Positioned(
          left: stopLeft,
          top: 8,
          width: handoverWidth,
          height: 28,
          child: GestureDetector(
            onLongPress: widget.singleDriverId == null
                ? () => _showReassignDialog(stop, driver)
                : null,
            child: Tooltip(
              message: '${stop['customer_name'] ?? 'Customer'}\n'
                  'Arr: ${_formatTime(arrivalTime)}'
                  '${targetTime != null ? ' · Target: ${_formatTime(targetTime)}' : ''}'
                  '${isLate ? ' (LATE!)' : ''}',
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  color: isLate
                      ? Colors.red.withValues(alpha: 0.9)
                      : (stop['status'] == 'completed'
                          ? Colors.green.withValues(alpha: 0.85)
                          : Colors.grey[700]),
                  borderRadius: BorderRadius.circular(6),
                  border: isHighlighted
                      ? Border.all(color: Colors.amberAccent, width: 2.5)
                      : (isLate
                          ? Border.all(color: Colors.redAccent, width: 1.5)
                          : null),
                  boxShadow: isHighlighted
                      ? [
                          BoxShadow(
                            color: Colors.amberAccent.withValues(alpha: 0.6),
                            blurRadius: 8,
                            spreadRadius: 2,
                          )
                        ]
                      : null,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${i + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        _formatTime(arrivalTime),
                        style: TextStyle(
                          color: isLate ? Colors.white : Colors.grey[200],
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      // Red Target Tick
      if (targetTime != null) {
        final targetSecs = targetTime.difference(_timelineStart).inSeconds;
        final targetLeft = (targetSecs / 60.0) * _pixelsPerMinute;
        if (targetLeft >= 0 && targetLeft <= _windowMinutes * _pixelsPerMinute + 40) {
          widgets.add(
            Positioned(
              left: targetLeft,
              top: 0,
              child: Column(
                children: [
                  Container(
                    width: 2,
                    height: 10,
                    color: isLate ? Colors.redAccent : Colors.amber,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                    decoration: BoxDecoration(
                      color: isLate ? Colors.red : Colors.black87,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      'due ${_formatTime(targetTime)}',
                      style: TextStyle(
                        color: isLate ? Colors.white : Colors.amberAccent,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      }

      prevDeparture = arrivalTime.add(Duration(minutes: widget.serviceDurationMinutes));
    }

    // Return to depot segment
    final returnStr = route['planned_return_at'] as String?;
    final returnTime = returnStr != null ? DateTime.tryParse(returnStr) : null;
    if (prevDeparture != null && returnTime != null && returnTime.isAfter(prevDeparture)) {
      final startSecs = prevDeparture.difference(_timelineStart).inSeconds;
      final retSecs = returnTime.difference(_timelineStart).inSeconds;
      final retLeft = (startSecs / 60.0) * _pixelsPerMinute;
      final retWidth = math.max(0.0, ((retSecs - startSecs) / 60.0) * _pixelsPerMinute);

      widgets.add(
        Positioned(
          left: retLeft,
          top: 13,
          width: retWidth,
          height: 18,
          child: Tooltip(
            message: 'Returning to restaurant depot (arr ${_formatTime(returnTime)})',
            child: Container(
              decoration: BoxDecoration(
                color: driverColor.withValues(alpha: 0.45),
                borderRadius: const BorderRadius.horizontal(
                  right: Radius.circular(4),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                'Return',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  Widget _buildReturnTimeBadge(DateTime returnTime, Color driverColor) {
    final diffMinutes = returnTime.difference(_timelineStart).inMinutes;
    final leftPos = math.max(
      40.0,
      math.min(
        diffMinutes * _pixelsPerMinute + 4,
        _windowMinutes * _pixelsPerMinute + 20,
      ),
    );

    return Positioned(
      left: leftPos,
      top: 6,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF0D47A1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.lightBlueAccent, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withValues(alpha: 0.4),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.home, color: Colors.lightBlueAccent, size: 12),
            const SizedBox(width: 4),
            Text(
              'back ${_formatTime(returnTime)}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnassignedDock() {
    return Container(
      width: 190,
      decoration: BoxDecoration(
        color: const Color(0xFF161922),
        border: Border(right: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            color: Colors.black26,
            child: Row(
              children: [
                const Icon(Icons.pending_actions, color: Colors.orangeAccent, size: 14),
                const SizedBox(width: 6),
                Text(
                  'Pending (${widget.unassignedOrders.length})',
                  style: const TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(6),
              itemCount: widget.unassignedOrders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (context, i) {
                final order = widget.unassignedOrders[i];
                final readyStr = order['estimated_pickup_time'] as String?;
                final readyTime = readyStr != null ? DateTime.tryParse(readyStr) : null;
                final targetStr = order['requested_delivery_time'] as String? ??
                    order['estimated_delivery_time'] as String?;
                final targetTime = targetStr != null ? DateTime.tryParse(targetStr) : null;
                final isUnassignable = order['is_unassignable'] == true;
                final reason = order['unassignable_reason'] as String?;

                return Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isUnassignable
                        ? Colors.red.withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isUnassignable
                          ? Colors.redAccent.withValues(alpha: 0.5)
                          : Colors.white10,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              order['customer_name'] as String? ?? 'Order #${order['id'].toString().substring(0, 5)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            order['delivery_status'] == 'ready_to_deliver' ? 'READY' : 'PREP',
                            style: TextStyle(
                              color: order['delivery_status'] == 'ready_to_deliver'
                                  ? Colors.greenAccent
                                  : Colors.amberAccent,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (readyTime != null)
                            Text(
                              'Ready ${_formatTime(readyTime)}',
                              style: TextStyle(color: Colors.grey[400], fontSize: 9),
                            ),
                          if (readyTime != null && targetTime != null)
                            Text(' • ', style: TextStyle(color: Colors.grey[600], fontSize: 9)),
                          if (targetTime != null)
                            Text(
                              'Due ${_formatTime(targetTime)}',
                              style: const TextStyle(color: Colors.amberAccent, fontSize: 9),
                            ),
                        ],
                      ),
                      if (reason != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          reason,
                          style: const TextStyle(color: Colors.redAccent, fontSize: 8),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showDriverDetailModal(
    app_driver_model.Driver driver,
    Map<String, dynamic>? route,
    List<Map<String, dynamic>> routeStops,
  ) {
    final driverColor = _getDriverColor(driver);
    final customerStops = routeStops
        .where((s) => s['type'] == 'customer_delivery')
        .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E222D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: driverColor,
                  radius: 24,
                  child: Text(
                    driver.name.isNotEmpty ? driver.name[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driver.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Shift ends: ${driver.shiftEndAt != null ? _formatTime(driver.shiftEndAt!) : "Unlimited"}',
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (driver.phoneNumber.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.call, color: Colors.greenAccent),
                    tooltip: 'Call Driver',
                    onPressed: () {
                      final uri = Uri.parse('tel:${driver.phoneNumber}');
                      launchUrl(uri, mode: LaunchMode.externalApplication);
                    },
                  ),
              ],
            ),
            const Divider(color: Colors.white24, height: 24),
            Text(
              'Active Route: ${customerStops.length} stops',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            if (customerStops.isEmpty)
              Text('No current active stops', style: TextStyle(color: Colors.grey[400], fontSize: 12))
            else
              ...customerStops.take(4).map((s) {
                final arrStr = s['planned_arrival_at'] as String? ?? s['estimated_arrival_time'] as String?;
                final arrTime = arrStr != null ? DateTime.tryParse(arrStr) : null;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        s['status'] == 'completed' ? Icons.check_circle : Icons.location_on,
                        color: s['status'] == 'completed' ? Colors.green : driverColor,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          s['customer_name'] as String? ?? 'Stop',
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ),
                      if (arrTime != null)
                        Text(
                          'arr ${_formatTime(arrTime)}',
                          style: TextStyle(color: Colors.grey[400], fontSize: 12),
                        ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showReassignDialog(Map<String, dynamic> stop, app_driver_model.Driver currentDriver) {
    final otherDrivers = widget.drivers.where((d) => d.id != currentDriver.id).toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF282E3E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.swap_horiz, color: Colors.amberAccent),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Move Stop to Another Driver',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Stop: ${stop['customer_name'] ?? 'Customer'}',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              'Currently assigned to: ${currentDriver.name}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 16),
            const Text(
              'Select Driver to Pin:',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            if (otherDrivers.isEmpty)
              const Text('No other drivers available', style: TextStyle(color: Colors.grey))
            else
              ...otherDrivers.map((d) {
                final dColor = _getDriverColor(d);
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: dColor,
                    radius: 14,
                    child: Text(
                      d.name.isNotEmpty ? d.name[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                  title: Text(d.name, style: const TextStyle(color: Colors.white, fontSize: 13)),
                  subtitle: Text(
                    d.isOnline ? 'Active on shift' : 'Standby',
                    style: TextStyle(color: Colors.grey[400], fontSize: 11),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    if (widget.onReassignStop != null) {
                      widget.onReassignStop!(stop['id'] as String, d.id);
                    }
                  },
                );
              }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }
}

/// Custom Painter for dashed outline boxes (waiting for food at depot)
class DashedBoxPainter extends CustomPainter {
  final Color color;
  const DashedBoxPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const dashWidth = 4.0;
    const dashSpace = 3.0;

    // Top
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(math.min(x + dashWidth, size.width), 0), paint);
      x += dashWidth + dashSpace;
    }
    // Bottom
    x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, size.height), Offset(math.min(x + dashWidth, size.width), size.height), paint);
      x += dashWidth + dashSpace;
    }
    // Left
    double y = 0;
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(0, math.min(y + dashWidth, size.height)), paint);
      y += dashWidth + dashSpace;
    }
    // Right
    y = 0;
    while (y < size.height) {
      canvas.drawLine(Offset(size.width, y), Offset(size.width, math.min(y + dashWidth, size.height)), paint);
      y += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant DashedBoxPainter oldDelegate) => oldDelegate.color != color;
}

/// Custom Painter for diagonal hatched pattern (returning from previous route)
class HatchedPatternPainter extends CustomPainter {
  final Color color;
  final Color backgroundColor;

  const HatchedPatternPainter({
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Fill background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = backgroundColor,
    );

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.0;

    const step = 8.0;
    for (double x = -size.height; x < size.width + size.height; x += step) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant HatchedPatternPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.backgroundColor != backgroundColor;
}
