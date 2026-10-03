import 'dart:math' as math;

import 'package:restaurantadmin/screens/map/tour_eta.dart';

/// Tour lines along the streets for the Map tab.
///
/// Each tour is drawn leg by leg (restaurant → stop → stop → restaurant) with the road
/// geometry from the route-lines edge function, which asks Google once per leg and caches it.
/// On a tour that is on the road the line starts at the driver: the current leg is cut where
/// the driver is on it, or (when the driver took another way) replaced by a road from the
/// driver to the next stop. Legs without a road yet are drawn straight.

/// Google encoded polyline (precision 5) → points.
List<GeoPoint> decodePolyline(String encoded) {
  final points = <GeoPoint>[];
  var index = 0, lat = 0, lng = 0;
  while (index < encoded.length) {
    for (var coord = 0; coord < 2; coord++) {
      var shift = 0, result = 0, b = 0;
      do {
        if (index >= encoded.length) return points;
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      // Not ~(result >> 1): on the web `~` gives an unsigned 32-bit number.
      final delta = (result & 1) != 0 ? -(result >> 1) - 1 : (result >> 1);
      if (coord == 0) {
        lat += delta;
      } else {
        lng += delta;
      }
    }
    points.add((lat: lat / 1e5, lng: lng / 1e5));
  }
  return points;
}

double _round(double v, int decimals) {
  final f = math.pow(10, decimals);
  return (v * f).round() / f;
}

/// Leg key with the same rounding as the route-lines cache (5 decimals, ~1 m).
String legKey(GeoPoint a, GeoPoint b) =>
    '${_round(a.lat, 5)},${_round(a.lng, 5)}>${_round(b.lat, 5)},${_round(b.lng, 5)}';

/// A driver position rounded to ~100 m, so a road from the driver is reused while they
/// stay in the same spot.
GeoPoint coarse(GeoPoint p) => (lat: _round(p.lat, 3), lng: _round(p.lng, 3));

/// Within this distance the driver counts as on a road line (GPS noise plus Google's snapping).
const double kOnRoadMeters = 80;

/// Farther than this from the line's start, a short connector joins the driver to the line.
const double kConnectorMeters = 30;

/// The rest of [line] from the point on it closest to [p] (starting exactly there), or null
/// when [p] is more than [maxOffMeters] away from the line.
List<GeoPoint>? trimFrom(List<GeoPoint> line, GeoPoint p, {double maxOffMeters = 250}) {
  if (line.length < 2) return null;
  // Local flat projection in metres around p.
  final kx = 111320 * math.cos(p.lat * math.pi / 180);
  const ky = 110540.0;
  ({double x, double y}) xy(GeoPoint q) => (x: (q.lng - p.lng) * kx, y: (q.lat - p.lat) * ky);

  var best = double.infinity;
  var bestIndex = -1;
  var bestT = 0.0;
  for (var i = 0; i < line.length - 1; i++) {
    final a = xy(line[i]), b = xy(line[i + 1]);
    final dx = b.x - a.x, dy = b.y - a.y;
    final len2 = dx * dx + dy * dy;
    final t = len2 == 0 ? 0.0 : (-(a.x * dx + a.y * dy) / len2).clamp(0.0, 1.0);
    final cx = a.x + t * dx, cy = a.y + t * dy;
    final d = math.sqrt(cx * cx + cy * cy);
    if (d < best) {
      best = d;
      bestIndex = i;
      bestT = t;
    }
  }
  if (bestIndex < 0 || best > maxOffMeters) return null;
  final a = line[bestIndex], b = line[bestIndex + 1];
  final start = (lat: a.lat + (b.lat - a.lat) * bestT, lng: a.lng + (b.lng - a.lng) * bestT);
  return [start, ...line.sublist(bestIndex + 1)];
}

/// Road geometry fetched so far, per leg.
class RoadCache {
  final Map<String, List<GeoPoint>?> _legs = {};
  final Map<String, DateTime> _failedAt = {};

  /// The road for a leg; null when not fetched yet or Google had no road for it.
  List<GeoPoint>? road(GeoPoint a, GeoPoint b) => _legs[legKey(a, b)];

  bool known(GeoPoint a, GeoPoint b) => _legs.containsKey(legKey(a, b));

  /// Legs worth asking for: not known, and not failed in the last [retryAfter].
  List<(GeoPoint, GeoPoint)> missing(Iterable<(GeoPoint, GeoPoint)> legs, DateTime now,
      {Duration retryAfter = const Duration(minutes: 2)}) {
    final seen = <String>{};
    final out = <(GeoPoint, GeoPoint)>[];
    for (final l in legs) {
      final k = legKey(l.$1, l.$2);
      if (_legs.containsKey(k) || !seen.add(k)) continue;
      final failed = _failedAt[k];
      if (failed != null && now.difference(failed) < retryAfter) continue;
      out.add(l);
    }
    return out;
  }

  /// Stores the answer for [legs] (encoded polylines in the same order, null = no road).
  void put(List<(GeoPoint, GeoPoint)> legs, List<String?> polylines) {
    for (var i = 0; i < legs.length && i < polylines.length; i++) {
      final p = polylines[i];
      _legs[legKey(legs[i].$1, legs[i].$2)] = p == null || p.isEmpty ? null : decodePolyline(p);
    }
  }

  /// Stores a route-lines answer: `{polyline}` per leg, or `{retry: true}` when Google failed
  /// for now (asked again after the back-off instead of being drawn straight for good).
  void putAnswers(List<(GeoPoint, GeoPoint)> legs, List<dynamic> answers, DateTime now) {
    for (var i = 0; i < legs.length && i < answers.length; i++) {
      final a = answers[i];
      if (a is Map && a['retry'] == true) {
        failed([legs[i]], now);
      } else {
        put([legs[i]], [a is Map ? a['polyline'] as String? : null]);
      }
    }
  }

  void failed(List<(GeoPoint, GeoPoint)> legs, DateTime now) {
    for (final l in legs) {
      _failedAt[legKey(l.$1, l.$2)] = now;
    }
  }
}

/// One tour to draw: its waypoints in driving order and, on the road, the driver.
class TourLine {
  final String id;
  final String driverId;
  final int colorIndex;
  final bool live;

  /// Restaurant or last delivered stop, the stops still to do, the restaurant.
  final List<GeoPoint> waypoints;

  /// Where the driver is (fresh GPS only); the line then starts there.
  final GeoPoint? driverAt;

  const TourLine({
    required this.id,
    required this.driverId,
    required this.colorIndex,
    required this.live,
    required this.waypoints,
    this.driverAt,
  });

  List<(GeoPoint, GeoPoint)> get legs => [
        for (var i = 0; i < waypoints.length - 1; i++) (waypoints[i], waypoints[i + 1]),
      ];
}

/// The lines for every board: the tour on the road (from the last delivery, or the
/// restaurant, through the open stops and back) and the tours after it.
List<TourLine> tourLines(List<DriverBoard> boards, GeoPoint store, DateTime now) {
  final lines = <TourLine>[];
  for (final b in boards) {
    final cur = b.current;
    if (cur != null) {
      final lastDone = cur.stops.where((s) => s.isDone && s.point != null).toList()
        ..sort((x, y) => (x.deliveredAt ?? DateTime(0)).compareTo(y.deliveredAt ?? DateTime(0)));
      lines.add(TourLine(
        id: 'live_${cur.routeId}',
        driverId: b.driverId,
        colorIndex: b.colorIndex,
        live: true,
        waypoints: [
          lastDone.isNotEmpty ? lastDone.last.point! : store,
          ...cur.remaining.where((s) => s.point != null).map((s) => s.point!),
          store,
        ],
        driverAt: b.position != null && b.gpsFresh(now) ? b.position : null,
      ));
    }
    for (final t in b.upcoming) {
      final stops = t.stops.where((s) => !s.isDone && s.point != null).map((s) => s.point!).toList();
      if (stops.isEmpty) continue;
      lines.add(TourLine(
        id: 'plan_${t.routeId}',
        driverId: b.driverId,
        colorIndex: b.colorIndex,
        live: false,
        waypoints: [store, ...stops, store],
      ));
    }
  }
  return lines;
}

/// A road from the driver to the next stop, fetched when the driver is off the planned leg.
typedef DriverRoad = ({GeoPoint to, List<GeoPoint> points});

/// The points to draw for [line]: roads where known, straight lines where not.
List<GeoPoint> composeLine(TourLine line, RoadCache roads, {DriverRoad? driverRoad}) {
  final out = <GeoPoint>[];
  void add(List<GeoPoint> seg) {
    for (final p in seg) {
      // Legs meet at the stop; decoded roads are rounded to ~1 m, so compare with a tolerance.
      if (out.isNotEmpty && (out.last.lat - p.lat).abs() < 2e-5 && (out.last.lng - p.lng).abs() < 2e-5) continue;
      out.add(p);
    }
  }

  final legs = line.legs;
  for (var i = 0; i < legs.length; i++) {
    final (a, b) = legs[i];
    var seg = roads.road(a, b) ?? [a, b];
    if (i == 0 && line.driverAt != null) {
      final at = line.driverAt!;
      final ownRoad = driverRoad != null && driverRoad.to == b ? driverRoad.points : null;
      // On the planned road; else on the road fetched from the driver; else near the planned
      // road (another street close by); else straight to the next stop.
      final from = trimFrom(seg, at, maxOffMeters: kOnRoadMeters) ??
          (ownRoad != null ? trimFrom(ownRoad, at) : null) ??
          trimFrom(seg, at);
      seg = from == null
          ? [at, b]
          : (haversineMeters(at, from.first) > kConnectorMeters ? [at, ...from] : from);
    }
    add(seg);
  }
  return out;
}

/// The road from the driver that [line] needs, as (coarse driver position, next stop): when the
/// driver is off the planned first leg and no fitting driver road is known.
(GeoPoint, GeoPoint)? driverLegNeeded(TourLine line, RoadCache roads, {DriverRoad? driverRoad}) {
  final at = line.driverAt;
  if (at == null || line.waypoints.length < 2) return null;
  final a = line.waypoints[0], b = line.waypoints[1];
  if (!roads.known(a, b)) return null; // Wait for the planned leg first.
  final planned = roads.road(a, b);
  if (planned == null || trimFrom(planned, at, maxOffMeters: kOnRoadMeters) != null) return null;
  if (driverRoad != null && driverRoad.to == b && trimFrom(driverRoad.points, at) != null) return null;
  return (coarse(at), b);
}
