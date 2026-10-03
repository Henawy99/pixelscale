import 'dart:math' as math;

/// Live tour timings for the Map tab.
///
/// A tour on the road is timed exactly like the planner's `returnEta`
/// (supabase/functions/plan-routes/index.ts): every leg is the straight-line distance × 1.4
/// at the city speed, each customer gets the handover time, GPS counts as fresh for
/// 5 minutes, and without fresh GPS the driver is assumed to be at the next stop with the
/// return no earlier than planned (at most 20 minutes later). The return time therefore
/// matches when the planner lets the driver's next tour leave.
///
/// Tours still at the restaurant keep the planner's own times (Google road times), moved
/// back when the driver cannot leave on time.

typedef GeoPoint = ({double lat, double lng});

const Duration kGpsFreshFor = Duration(minutes: 5);

/// A driver whose app has not checked in for this long is off shift for the planner.
const Duration kDriverGoneAfter = Duration(minutes: 15);

/// A tour on the road for longer than this was most likely never closed in the driver app.
const Duration kTourStaleAfter = Duration(hours: 3);

/// Closer than this to a stop or the restaurant counts as being there.
const double kArrivedWithinMeters = 150;

const _doneStopStatuses = {'completed', 'skipped', 'failed'};

class EtaSettings {
  final double citySpeedKmh;
  final Duration handover;
  final Duration safetyBuffer;
  final GeoPoint store;
  final Duration staleOrderAge;

  const EtaSettings({
    this.citySpeedKmh = 25,
    this.handover = const Duration(minutes: 5),
    this.safetyBuffer = const Duration(minutes: 2),
    this.store = (lat: 47.81328, lng: 13.06882),
    this.staleOrderAge = const Duration(minutes: 60),
  });

  /// From the oldest delivery_settings row, which is the one the planner reads.
  factory EtaSettings.fromRow(Map<String, dynamic>? row) {
    const d = EtaSettings();
    if (row == null) return d;
    final lat = _num(row['store_latitude']);
    final lng = _num(row['store_longitude']);
    return EtaSettings(
      citySpeedKmh: _num(row['city_speed_kmh']) ?? d.citySpeedKmh,
      handover: Duration(seconds: (_num(row['handover_time_secs']) ?? 300).round()),
      safetyBuffer: Duration(seconds: (_num(row['safety_buffer_secs']) ?? 120).round()),
      store: lat != null && lng != null ? (lat: lat, lng: lng) : d.store,
      staleOrderAge: Duration(minutes: (_num(row['stale_order_mins']) ?? 60).round()),
    );
  }
}

/// What a driver is doing right now.
enum DriverActivity { delivering, returning, waitingToLeave, atRestaurant, offline }

enum StopState { delivered, next, upcoming, skipped }

/// How an expected arrival compares with the promise to the customer.
enum Punctuality { unknown, onTime, tight, late }

class TourStop {
  final String id;
  final String? orderId;
  final int sequence;
  final String name;
  final String? address;
  final GeoPoint? point;
  final StopState state;

  /// Expected arrival: live for a tour on the road, the plan (moved back if needed) otherwise.
  final DateTime? eta;

  /// Driving time from the previous point (restaurant, driver or stop) to this stop.
  final Duration? drive;

  /// Time promised to the customer.
  final DateTime? dueAt;

  /// When the driver marked it delivered (the tap, not necessarily the handover).
  final DateTime? deliveredAt;
  final bool driverIsHere;
  final bool cancelled;
  final Duration safetyBuffer;

  const TourStop({
    required this.id,
    required this.orderId,
    required this.sequence,
    required this.name,
    required this.address,
    required this.point,
    required this.state,
    this.eta,
    this.drive,
    this.dueAt,
    this.deliveredAt,
    this.driverIsHere = false,
    this.cancelled = false,
    this.safetyBuffer = const Duration(minutes: 2),
  });

  bool get isDone => state == StopState.delivered || state == StopState.skipped;

  /// Stable key across plan runs (the planner re-creates stop rows but keeps the order).
  String get key => orderId ?? id;

  Punctuality get punctuality {
    if (isDone || eta == null || dueAt == null) return Punctuality.unknown;
    if (eta!.difference(dueAt!).inSeconds >= 60) return Punctuality.late;
    if (eta!.isAfter(dueAt!.subtract(safetyBuffer))) return Punctuality.tight;
    return Punctuality.onTime;
  }

  /// How late the customer will get it (null unless at least a minute late).
  Duration? get lateBy => punctuality == Punctuality.late ? eta!.difference(dueAt!) : null;
}

class Tour {
  final String routeId;
  final String? driverId;

  /// On the road (delivery_routes.status = in_progress).
  final bool live;
  final DateTime? departAt;

  /// The departure is estimated: the driver never tapped "Start tour".
  final bool departApprox;
  final DateTime? returnAt;

  /// Driving time from the last stop (or the driver) back to the restaurant.
  final Duration? returnDrive;
  final List<TourStop> stops;

  /// Live times come from the driver's GPS; false means they lean on the plan.
  final bool fromGps;

  /// The driver is at the restaurant with everything delivered but the tour not closed.
  final bool driverAtStore;

  /// On the road for hours: probably never closed in the driver app.
  final bool stale;

  /// How far a planned tour moved because the driver is not back (or not gone) in time.
  final Duration delay;

  const Tour({
    required this.routeId,
    required this.driverId,
    required this.live,
    required this.departAt,
    required this.returnAt,
    required this.returnDrive,
    required this.stops,
    this.departApprox = false,
    this.fromGps = false,
    this.driverAtStore = false,
    this.stale = false,
    this.delay = Duration.zero,
  });

  int get deliveredCount => stops.where((s) => s.isDone).length;
  TourStop? get nextStop => stops.where((s) => s.state == StopState.next).firstOrNull;
  List<TourStop> get remaining => stops.where((s) => !s.isDone).toList();
  int get lateCount => stops.where((s) => s.punctuality == Punctuality.late).length;
}

class DriverBoard {
  final String driverId;
  final String name;
  final int colorIndex;
  final bool isOnline;
  final DateTime? lastSeenAt;
  final GeoPoint? position;
  final double? speedMs;
  final DriverActivity activity;

  /// Straight-line distance from the restaurant (null without fresh GPS).
  final double? metersFromStore;

  /// The tour on the road, if any.
  final Tour? current;

  /// Tours planned for later, in order.
  final List<Tour> upcoming;

  const DriverBoard({
    required this.driverId,
    required this.name,
    required this.colorIndex,
    required this.isOnline,
    required this.lastSeenAt,
    required this.position,
    required this.speedMs,
    required this.activity,
    required this.current,
    required this.upcoming,
    this.metersFromStore,
  });

  /// Online without a tour on the road, but clearly not at the restaurant.
  bool get awayFromStore => current == null && (metersFromStore ?? 0) > 300;

  /// When the driver is next at the restaurant (null when not on a tour).
  DateTime? get backAt => current?.returnAt;

  bool gpsFresh(DateTime now) =>
      position != null && lastSeenAt != null && now.difference(lastSeenAt!) < kGpsFreshFor;
}

/// Input for one driver. Plain values, so the logic is testable without Supabase.
class DriverInput {
  final String id;
  final String name;
  final int colorIndex;
  final bool isOnline;
  final DateTime? lastSeenAt;
  final GeoPoint? position;
  final double? speedMs;

  const DriverInput({
    required this.id,
    required this.name,
    this.colorIndex = 0,
    this.isOnline = false,
    this.lastSeenAt,
    this.position,
    this.speedMs,
  });

  bool gpsFresh(DateTime now) =>
      position != null && lastSeenAt != null && now.difference(lastSeenAt!) < kGpsFreshFor;

  /// Online in the app and checked in recently enough for the planner to count on them.
  bool onShift(DateTime now) => isOnline && lastSeenAt != null && now.difference(lastSeenAt!) < kDriverGoneAfter;
}

// ─────────────────────────────────────────────────────────────────────────────
// Geometry
// ─────────────────────────────────────────────────────────────────────────────

double haversineMeters(GeoPoint a, GeoPoint b) {
  const r = 6371000.0;
  final dLat = (b.lat - a.lat) * math.pi / 180;
  final dLng = (b.lng - a.lng) * math.pi / 180;
  final sLat = math.sin(dLat / 2);
  final sLng = math.sin(dLng / 2);
  final h = sLat * sLat + math.cos(a.lat * math.pi / 180) * math.cos(b.lat * math.pi / 180) * sLng * sLng;
  return 2 * r * math.asin(math.sqrt(h));
}

/// The planner's estimate: road ≈ 1.4 × straight line, driven at the city speed.
Duration estimateDrive(GeoPoint a, GeoPoint b, double citySpeedKmh) {
  if (citySpeedKmh <= 0) return Duration.zero;
  final roadMeters = haversineMeters(a, b) * 1.4;
  return Duration(seconds: (roadMeters / (citySpeedKmh * 1000 / 3600)).round());
}

// ─────────────────────────────────────────────────────────────────────────────
// Parsing helpers
// ─────────────────────────────────────────────────────────────────────────────

double? _num(dynamic v) => v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);

/// Supabase timestamps, read as UTC even when the offset is missing.
DateTime? parseTs(dynamic v) {
  if (v is DateTime) return v.toUtc();
  if (v is! String || v.isEmpty) return null;
  final hasZone = RegExp(r'(Z|[+-]\d{2}(:?\d{2})?)$').hasMatch(v);
  final dt = DateTime.tryParse(hasZone ? v : '${v}Z');
  return dt?.toUtc();
}

GeoPoint? _point(Map<String, dynamic> m, [String lat = 'latitude', String lng = 'longitude']) {
  final a = _num(m[lat]);
  final b = _num(m[lng]);
  return a != null && b != null ? (lat: a, lng: b) : null;
}

/// The promise to the customer, as the planner reads it: requested (pre-order) first, then
/// the platform's estimate, then the stop's copy, then 60 minutes after the order came in.
DateTime? dueAt(Map<String, dynamic>? order, [Map<String, dynamic>? stop]) {
  final created = parseTs(order?['created_at']);
  return parseTs(order?['requested_delivery_time']) ??
      parseTs(order?['estimated_delivery_time']) ??
      parseTs(stop?['target_delivery_time']) ??
      created?.add(const Duration(minutes: 60));
}

/// Cash orders: Foodora says so in payment_method; Lieferando always stores 'online' there,
/// so its raw payment method (selected as pay_method) decides.
bool isCash(Map<String, dynamic>? order) {
  if (order == null) return false;
  final method = (order['payment_method'] as String? ?? '').toLowerCase();
  final raw = (order['pay_method'] as String? ?? '').toLowerCase();
  return method.contains('cash') || raw == 'cash';
}

Duration? _googleLeg(Map<String, dynamic> stop) {
  final s = _num(stop['estimated_travel_time_to_next_stop_seconds']);
  return s != null && s > 0 ? Duration(seconds: s.round()) : null;
}

DateTime _max(DateTime a, DateTime b) => a.isAfter(b) ? a : b;

String _stopName(Map<String, dynamic> s, Map<String, dynamic>? order) =>
    (order?['customer_name'] as String?)?.trim().isNotEmpty == true
        ? (order!['customer_name'] as String).trim()
        : ((s['customer_name'] as String?) ?? 'Customer');

String? _stopAddress(Map<String, dynamic> s, Map<String, dynamic>? order) {
  final street = (order?['customer_street'] as String?)?.trim();
  if (street != null && street.isNotEmpty) {
    final city = [(order?['customer_postcode'] as String?)?.trim(), (order?['customer_city'] as String?)?.trim()]
        .whereType<String>()
        .where((p) => p.isNotEmpty)
        .join(' ');
    return city.isEmpty ? street : '$street, $city';
  }
  return s['customer_address'] as String?;
}

bool _isCancelled(Map<String, dynamic>? order) => (order?['status'] as String? ?? '').toLowerCase() == 'cancelled';

// ─────────────────────────────────────────────────────────────────────────────
// Tours
// ─────────────────────────────────────────────────────────────────────────────

List<Map<String, dynamic>> _sortedStops(List<Map<String, dynamic>> stops, String routeId) =>
    stops.where((s) => s['delivery_route_id'] == routeId).toList()
      ..sort((a, b) => ((a['sequence_number'] as num?) ?? 0).compareTo((b['sequence_number'] as num?) ?? 0));

/// A tour on the road: the planner's return estimate, with the time of every stop on the way.
Tour liveTour({
  required Map<String, dynamic> route,
  required List<Map<String, dynamic>> stops,
  required Map<String, Map<String, dynamic>> ordersById,
  required DriverInput? driver,
  required EtaSettings settings,
  required DateTime now,
}) {
  final routeId = route['id'] as String;
  final all = _sortedStops(stops, routeId);
  final customers = all.where((s) => s['type'] == 'customer_delivery').toList();
  final remaining = customers.where((s) => !_doneStopStatuses.contains((s['status'] as String? ?? '').toLowerCase())).toList();

  final gps = driver != null && driver.gpsFresh(now) ? driver.position : null;
  final firstPoint = remaining.isNotEmpty ? _point(remaining.first) : null;
  // Planner: from = gps ?? remaining[0] ?? store.
  GeoPoint from = gps ?? firstPoint ?? settings.store;

  // Walk the open stops.
  var t = now;
  final etas = <String, DateTime>{};
  final legs = <String, Duration>{};
  for (final s in remaining) {
    final p = _point(s) ?? from;
    final leg = estimateDrive(from, p, settings.citySpeedKmh);
    t = t.add(leg);
    etas[s['id'] as String] = t;
    legs[s['id'] as String] = leg;
    t = t.add(settings.handover);
    from = p;
  }
  final returnDrive = estimateDrive(from, settings.store, settings.citySpeedKmh);
  final unclamped = t.add(returnDrive);
  var back = unclamped;
  if (gps == null) {
    final plannedBack = parseTs(route['planned_return_at']);
    if (plannedBack != null) {
      final cap = unclamped.add(const Duration(minutes: 20));
      back = _max(unclamped, plannedBack.isBefore(cap) ? plannedBack : cap);
    }
  }
  // Without GPS the planner's floor moves the whole chain back, not just the return.
  final shift = back.difference(unclamped);

  final result = <TourStop>[];
  var nextGiven = false;
  for (final s in customers) {
    final order = ordersById[s['order_id']];
    final status = (s['status'] as String? ?? 'pending').toLowerCase();
    final id = s['id'] as String;
    final point = _point(s);
    final done = _doneStopStatuses.contains(status);
    final isNext = !done && !nextGiven;
    if (isNext) nextGiven = true;
    result.add(TourStop(
      id: id,
      orderId: s['order_id'] as String?,
      sequence: (s['sequence_number'] as num?)?.toInt() ?? 0,
      name: _stopName(s, order),
      address: _stopAddress(s, order),
      point: point,
      state: done
          ? (status == 'completed' ? StopState.delivered : StopState.skipped)
          : (isNext ? StopState.next : StopState.upcoming),
      eta: done ? null : etas[id]?.add(shift),
      // Without GPS the first leg is unknown (the planner assumes the driver is there).
      drive: done || (isNext && gps == null) ? null : legs[id],
      dueAt: dueAt(order, s),
      deliveredAt: done ? parseTs(s['actual_arrival_time']) ?? parseTs(s['departure_time']) : null,
      driverIsHere: isNext && gps != null && point != null && haversineMeters(gps, point) <= kArrivedWithinMeters,
      cancelled: _isCancelled(order),
      safetyBuffer: settings.safetyBuffer,
    ));
  }

  // Departure: the tap on "Start tour", or (when the driver skipped it and the tour was
  // started by the first "Delivered") that moment minus the drive to the first stop.
  DateTime? departAt = parseTs(route['actual_departure_at']);
  var approx = false;
  if (departAt == null) {
    final started = parseTs(route['started_at']) ?? parseTs(route['confirmed_at']);
    final firstDone = customers
        .map((s) => parseTs(s['actual_arrival_time']))
        .whereType<DateTime>()
        .fold<DateTime?>(null, (a, b) => a == null || b.isBefore(a) ? b : a);
    if (started != null && firstDone != null && started.difference(firstDone).inSeconds.abs() <= 5) {
      final firstStop = customers.isNotEmpty ? _point(customers.first) : null;
      departAt = firstStop == null ? started : started.subtract(estimateDrive(settings.store, firstStop, settings.citySpeedKmh));
      approx = true;
    } else {
      departAt = started;
    }
  }

  final atStore = remaining.isEmpty && gps != null && haversineMeters(gps, settings.store) <= kArrivedWithinMeters;
  final started = parseTs(route['started_at']) ?? departAt ?? parseTs(route['created_at']);

  return Tour(
    routeId: routeId,
    driverId: route['assigned_driver_id'] as String?,
    live: true,
    departAt: departAt,
    departApprox: approx,
    returnAt: back,
    returnDrive: returnDrive,
    stops: result,
    fromGps: gps != null,
    driverAtStore: atStore,
    stale: started != null && now.difference(started) > kTourStaleAfter,
  );
}

/// A tour waiting at the restaurant: the planner's times, moved back when the driver cannot
/// leave on time. Never moved earlier — the planner may be waiting for the food.
Tour plannedTour({
  required Map<String, dynamic> route,
  required List<Map<String, dynamic>> stops,
  required Map<String, Map<String, dynamic>> ordersById,
  required DateTime earliestDeparture,
  EtaSettings settings = const EtaSettings(),
}) {
  final routeId = route['id'] as String;
  final all = _sortedStops(stops, routeId);
  final storeStops = all.where((s) => s['type'] == 'store').toList();
  final plannedDepart = parseTs(route['planned_departure_at']) ??
      (storeStops.isNotEmpty ? parseTs(storeStops.first['planned_arrival_at']) : null);
  final delay = plannedDepart != null && earliestDeparture.isAfter(plannedDepart)
      ? earliestDeparture.difference(plannedDepart)
      : Duration.zero;
  DateTime? shift(DateTime? t) => t?.add(delay);

  final result = <TourStop>[];
  Map<String, dynamic>? prev = storeStops.isNotEmpty && storeStops.first == all.firstOrNull ? storeStops.first : null;
  for (final s in all) {
    if (s['type'] != 'customer_delivery') continue;
    final order = ordersById[s['order_id']];
    final status = (s['status'] as String? ?? 'pending').toLowerCase();
    result.add(TourStop(
      id: s['id'] as String,
      orderId: s['order_id'] as String?,
      sequence: (s['sequence_number'] as num?)?.toInt() ?? 0,
      name: _stopName(s, order),
      address: _stopAddress(s, order),
      point: _point(s),
      state: status == 'completed'
          ? StopState.delivered
          : (_doneStopStatuses.contains(status) ? StopState.skipped : StopState.upcoming),
      eta: shift(parseTs(s['planned_arrival_at']) ?? parseTs(s['estimated_arrival_time'])),
      drive: prev != null ? _googleLeg(prev) : null,
      dueAt: dueAt(order, s),
      cancelled: _isCancelled(order),
      safetyBuffer: settings.safetyBuffer,
    ));
    prev = s;
  }

  final plannedBack = parseTs(route['planned_return_at']) ??
      (storeStops.length > 1 ? parseTs(storeStops.last['planned_arrival_at']) : null);
  return Tour(
    routeId: routeId,
    driverId: route['assigned_driver_id'] as String?,
    live: false,
    departAt: shift(plannedDepart),
    returnAt: shift(plannedBack),
    returnDrive: prev != null && prev['type'] == 'customer_delivery' ? _googleLeg(prev) : null,
    stops: result,
    delay: delay,
  );
}

/// One board per driver: the tour on the road, the tours after it, and what they are doing.
/// Drivers on a tour or on shift come first; others are left out unless [includeIdleOffline].
List<DriverBoard> buildDriverBoards({
  required List<DriverInput> drivers,
  required List<Map<String, dynamic>> routes,
  required List<Map<String, dynamic>> stops,
  required Map<String, Map<String, dynamic>> ordersById,
  required EtaSettings settings,
  required DateTime now,
  bool includeIdleOffline = false,
}) {
  final boards = <DriverBoard>[];
  for (final d in drivers) {
    final mine = routes.where((r) => r['assigned_driver_id'] == d.id).toList();
    final liveRoutes = mine.where((r) => r['status'] == 'in_progress').toList()
      ..sort((a, b) => (parseTs(a['created_at']) ?? now).compareTo(parseTs(b['created_at']) ?? now));
    final planned = mine.where((r) => r['status'] == 'assigned').toList()
      ..sort((a, b) => (parseTs(a['planned_departure_at']) ?? now).compareTo(parseTs(b['planned_departure_at']) ?? now));

    final current = liveRoutes.isNotEmpty
        ? liveTour(route: liveRoutes.last, stops: stops, ordersById: ordersById, driver: d, settings: settings, now: now)
        : null;

    final upcoming = <Tour>[];
    var earliest = current?.returnAt ?? now;
    for (final r in planned) {
      final tour = plannedTour(route: r, stops: stops, ordersById: ordersById, earliestDeparture: earliest, settings: settings);
      upcoming.add(tour);
      earliest = tour.returnAt ?? earliest;
    }

    final onShift = d.onShift(now);
    if (!onShift && current == null && upcoming.isEmpty && !includeIdleOffline) continue;

    final DriverActivity activity;
    if (current != null) {
      activity = current.remaining.isEmpty ? DriverActivity.returning : DriverActivity.delivering;
    } else if (!onShift) {
      activity = DriverActivity.offline;
    } else if (upcoming.isNotEmpty) {
      activity = DriverActivity.waitingToLeave;
    } else {
      activity = DriverActivity.atRestaurant;
    }

    boards.add(DriverBoard(
      driverId: d.id,
      name: d.name,
      colorIndex: d.colorIndex,
      isOnline: onShift,
      lastSeenAt: d.lastSeenAt,
      position: d.position,
      speedMs: d.speedMs,
      activity: activity,
      current: current,
      upcoming: upcoming,
      metersFromStore: d.gpsFresh(now) ? haversineMeters(d.position!, settings.store) : null,
    ));
  }

  // Tours whose driver is gone (deleted, or never set) still need to be seen.
  final known = drivers.map((d) => d.id).toSet();
  final orphans = routes.where((r) => !known.contains(r['assigned_driver_id'])).toList();
  if (orphans.isNotEmpty) {
    final live = orphans.where((r) => r['status'] == 'in_progress').toList()
      ..sort((a, b) => (parseTs(a['created_at']) ?? now).compareTo(parseTs(b['created_at']) ?? now));
    final planned = orphans.where((r) => r['status'] == 'assigned').toList()
      ..sort((a, b) => (parseTs(a['planned_departure_at']) ?? now).compareTo(parseTs(b['planned_departure_at']) ?? now));
    final current = live.isNotEmpty
        ? liveTour(route: live.last, stops: stops, ordersById: ordersById, driver: null, settings: settings, now: now)
        : null;
    final upcoming = [
      for (final r in planned) plannedTour(route: r, stops: stops, ordersById: ordersById, earliestDeparture: now, settings: settings),
    ];
    boards.add(DriverBoard(
      driverId: '',
      name: 'No driver',
      colorIndex: -1,
      isOnline: false,
      lastSeenAt: null,
      position: null,
      speedMs: null,
      activity: current == null
          ? DriverActivity.waitingToLeave
          : (current.remaining.isEmpty ? DriverActivity.returning : DriverActivity.delivering),
      current: current,
      upcoming: upcoming,
    ));
  }

  int rank(DriverBoard b) => switch (b.activity) {
        DriverActivity.delivering => 0,
        DriverActivity.returning => 1,
        DriverActivity.waitingToLeave => 2,
        DriverActivity.atRestaurant => 3,
        DriverActivity.offline => 4,
      };
  boards.sort((a, b) {
    final r = rank(a).compareTo(rank(b));
    return r != 0 ? r : a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return boards;
}

// ─────────────────────────────────────────────────────────────────────────────
// Orders waiting for a driver
// ─────────────────────────────────────────────────────────────────────────────

/// Delivery orders on no tour that the planner still handles: the same window as
/// plan-routes (created in the last 6 h, promised no longer than the stale age ago, not
/// delivered by Foodora's own riders).
List<Map<String, dynamic>> waitingOrders(
  List<Map<String, dynamic>> orders, {
  required EtaSettings settings,
  required DateTime now,
}) {
  const closed = {'cancelled', 'delivered', 'completed', 'delivering', 'pending_payment'};
  final createdAfter = now.subtract(const Duration(hours: 6));
  final staleBefore = now.subtract(settings.staleOrderAge);
  final list = orders.where((o) {
    if (o['delivery_route_id'] != null) return false;
    if ((o['fulfillment_type'] as String?) != null && o['fulfillment_type'] != 'delivery') return false;
    if (closed.contains((o['status'] as String? ?? '').toLowerCase())) return false;
    final ds = (o['delivery_status'] as String? ?? '').toLowerCase();
    if (ds == 'out_for_delivery' || ds == 'delivered') return false;
    if (o['transport_type'] == 'PICKUP_LOGISTICS') return false;
    final created = parseTs(o['created_at']);
    if (created == null || created.isBefore(createdAfter)) return false;
    // Same target as the planner's stale check (no "created + 60 min" fallback here).
    final target = parseTs(o['requested_delivery_time']) ?? parseTs(o['estimated_delivery_time']) ?? created;
    return !target.isBefore(staleBefore);
  }).toList();
  DateTime key(Map<String, dynamic> o) => dueAt(o) ?? now;
  list.sort((a, b) => key(a).compareTo(key(b)));
  return list;
}

// ─────────────────────────────────────────────────────────────────────────────
// Formatting
// ─────────────────────────────────────────────────────────────────────────────

/// "19:42" in the device's local time.
String clock(DateTime? t) {
  if (t == null) return '–';
  final l = t.toLocal();
  return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
}

/// "in 12 min", "now", "5 min ago", "in 1 h 05".
String relative(DateTime? t, DateTime now) {
  if (t == null) return '';
  final mins = (t.difference(now).inSeconds / 60).round();
  if (mins.abs() < 1) return 'now';
  final a = mins.abs();
  final text = a < 60 ? '$a min' : '${a ~/ 60} h ${(a % 60).toString().padLeft(2, '0')}';
  return mins > 0 ? 'in $text' : '$text ago';
}

/// "13 min", "1 h 43 min" (at least 1 min for any non-zero leg).
String minutes(Duration? d) {
  if (d == null) return '';
  if (d == Duration.zero) return '0 min';
  final m = math.max(1, (d.inSeconds / 60).round());
  return m < 60 ? '$m min' : '${m ~/ 60} h ${(m % 60).toString().padLeft(2, '0')} min';
}
