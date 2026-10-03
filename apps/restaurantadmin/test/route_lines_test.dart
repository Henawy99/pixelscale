import 'package:flutter_test/flutter_test.dart';
import 'package:restaurantadmin/screens/map/route_lines.dart';
import 'package:restaurantadmin/screens/map/tour_eta.dart';

void main() {
  const store = (lat: 47.81328, lng: 13.06882);
  GeoPoint east(double km, [double northKm = 0]) =>
      (lat: store.lat + northKm / 111.195, lng: store.lng + km / (111.32 * 0.6721)); // cos(47.8°) ≈ 0.672

  String encode(List<GeoPoint> pts) {
    // Reference encoder for the tests.
    final sb = StringBuffer();
    var pl = 0, pg = 0;
    void enc(int v) {
      var s = v < 0 ? ~(v << 1) : (v << 1);
      while (s >= 0x20) {
        sb.writeCharCode((0x20 | (s & 0x1f)) + 63);
        s >>= 5;
      }
      sb.writeCharCode(s + 63);
    }

    for (final p in pts) {
      final la = (p.lat * 1e5).round(), lo = (p.lng * 1e5).round();
      enc(la - pl);
      enc(lo - pg);
      pl = la;
      pg = lo;
    }
    return sb.toString();
  }

  group('decodePolyline', () {
    test('decodes Google\'s documented example', () {
      final pts = decodePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@');
      expect(pts.length, 3);
      expect(pts[0].lat, closeTo(38.5, 1e-9));
      expect(pts[0].lng, closeTo(-120.2, 1e-9));
      expect(pts[2].lat, closeTo(43.252, 1e-9));
      expect(pts[2].lng, closeTo(-126.453, 1e-9));
    });
    test('round-trips', () {
      final pts = [store, east(1), east(1, 1), east(2, 1)];
      final back = decodePolyline(encode(pts));
      for (var i = 0; i < pts.length; i++) {
        expect(back[i].lat, closeTo(pts[i].lat, 1e-5));
        expect(back[i].lng, closeTo(pts[i].lng, 1e-5));
      }
    });
    test('a truncated string does not throw', () {
      expect(() => decodePolyline('_p~iF~ps|U_ul'), returnsNormally);
    });
  });

  group('trimFrom', () {
    final line = [store, east(1), east(1, 1)]; // east 1 km, then north 1 km

    test('starts at the driver\'s projection on the line', () {
      final t = trimFrom(line, east(0.5, 0.05))!; // 50 m north of the first segment's middle
      expect(t.length, 3);
      expect(t.first.lat, closeTo(store.lat, 1e-6));
      expect(t.first.lng, closeTo(east(0.5).lng, 1e-4));
      expect(t[1], east(1));
    });
    test('on the second segment drops the first', () {
      final t = trimFrom(line, east(1.02, 0.5))!;
      expect(t.length, 2);
      expect(t.last, east(1, 1));
    });
    test('null when the driver is far off', () {
      expect(trimFrom(line, east(0.5, 0.6)), isNull);
      expect(trimFrom([store], store), isNull);
    });
  });

  group('composeLine', () {
    final a = store, s1 = east(2), s2 = east(2, 2);
    final roads = RoadCache();
    roads.put([(a, s1), (s1, s2), (s2, a)], [
      encode([a, east(1, -0.2), s1]),
      encode([s1, east(2.1, 1), s2]),
      null, // Google had no road: straight
    ]);

    test('planned tour: roads where known, straight where not', () {
      final line = TourLine(id: 'p', driverId: 'd', colorIndex: 0, live: false, waypoints: [a, s1, s2, a]);
      final pts = composeLine(line, roads);
      expect(pts.length, 6); // a, bend, s1, bend, s2, a
      expect(pts.last, a);
    });

    test('live tour starts at the driver on the planned leg', () {
      final line = TourLine(id: 'l', driverId: 'd', colorIndex: 0, live: true, waypoints: [a, s1, s2, a], driverAt: east(1.5, -0.1));
      final pts = composeLine(line, roads);
      expect(pts.first.lng, greaterThan(east(1).lng)); // the driven part is gone
      expect(pts.contains(east(1, -0.2)), isFalse);
      expect(driverLegNeeded(line, roads), isNull);
    });

    test('driver off the planned leg: straight to the next stop until a driver road arrives', () {
      final off = east(0.5, 1.5);
      final line = TourLine(id: 'l', driverId: 'd', colorIndex: 0, live: true, waypoints: [a, s1, s2, a], driverAt: off);
      expect(composeLine(line, roads).take(2).toList(), [off, s1]);
      final need = driverLegNeeded(line, roads)!;
      expect(need.$1, coarse(off));
      expect(need.$2, s1);

      final driverRoad = (to: s1, points: [coarse(off), east(1.2, 1.0), s1]);
      final pts = composeLine(line, roads, driverRoad: driverRoad);
      expect(pts.first, off); // joined to the marker
      expect(pts.contains(east(1.2, 1.0)), isTrue);
      expect(driverLegNeeded(line, roads, driverRoad: driverRoad), isNull);
    });

    test('driver on a street next to the planned road: connector, and a road from the driver is asked for', () {
      final near = east(1.5, 0.05); // ~150 m from the planned leg
      final line = TourLine(id: 'l', driverId: 'd', colorIndex: 0, live: true, waypoints: [a, s1, s2, a], driverAt: near);
      final pts = composeLine(line, roads);
      expect(pts.first, near);
      expect(pts[1].lng, closeTo(east(1.5).lng, 0.002)); // then onto the planned road
      expect(driverLegNeeded(line, roads), isNotNull);
    });

    test('no driver leg is requested before the planned leg is known', () {
      final line = TourLine(id: 'l', driverId: 'd', colorIndex: 0, live: true, waypoints: [east(5), s1, a], driverAt: east(9, 9));
      expect(driverLegNeeded(line, roads), isNull);
    });
  });

  group('RoadCache.putAnswers', () {
    test('retry answers are asked again after the back-off, no-road answers are final', () {
      final c = RoadCache();
      final now = DateTime.utc(2026, 10, 3, 19);
      final l1 = (store, east(1)), l2 = (east(1), east(2)), l3 = (east(2), store);
      c.putAnswers([l1, l2, l3], [
        {'polyline': '_p~iF~ps|U'},
        {'polyline': null, 'retry': true},
        {'polyline': null},
      ], now);
      expect(c.road(l1.$1, l1.$2), isNotNull);
      expect(c.known(l2.$1, l2.$2), isFalse);
      expect(c.known(l3.$1, l3.$2), isTrue);
      expect(c.missing([l1, l2, l3], now.add(const Duration(minutes: 1))), isEmpty);
      expect(c.missing([l1, l2, l3], now.add(const Duration(minutes: 3))), [l2]);
    });
  });

  group('RoadCache.missing', () {
    test('skips known, duplicate and recently failed legs', () {
      final c = RoadCache();
      final now = DateTime.utc(2026, 10, 3, 19);
      final l1 = (store, east(1)), l2 = (east(1), east(2)), l3 = (east(2), store);
      c.put([l1], ['_p~iF~ps|U']);
      c.failed([l2], now);
      expect(c.missing([l1, l2, l3, l3], now), [l3]);
      expect(c.missing([l2], now.add(const Duration(minutes: 3))), [l2]);
    });
  });

  group('tourLines', () {
    test('live line starts at the latest delivery and ends at the restaurant', () {
      final now = DateTime.utc(2026, 10, 3, 19);
      final boards = buildDriverBoards(
        drivers: [DriverInput(id: 'd1', name: 'B', isOnline: true, lastSeenAt: now, position: east(3))],
        routes: [
          {'id': 'r', 'assigned_driver_id': 'd1', 'status': 'in_progress', 'created_at': '2026-10-03T18:00:00Z'},
        ],
        stops: [
          for (final (i, p, st, at) in [
            (1, east(1), 'completed', '2026-10-03T18:40:00Z'),
            (2, east(2), 'pending', null),
            (3, east(4), 'completed', '2026-10-03T18:50:00Z'),
            (4, east(5), 'pending', null),
          ])
            {
              'id': 's$i', 'delivery_route_id': 'r', 'order_id': 'o$i', 'type': 'customer_delivery', 'sequence_number': i,
              'latitude': p.lat, 'longitude': p.lng, 'status': st, 'actual_arrival_time': at,
            },
        ],
        ordersById: const {},
        settings: const EtaSettings(),
        now: now,
      );
      final line = tourLines(boards, store, now).single;
      expect(line.waypoints, [east(4), east(2), east(5), store]);
      expect(line.driverAt, east(3));
    });
  });
}
