import 'package:flutter_test/flutter_test.dart';
import 'package:restaurantadmin/screens/map/tour_eta.dart';

void main() {
  const settings = EtaSettings(); // 25 km/h, 5 min handover, store at Minnesheimstraße 5
  final now = DateTime.utc(2026, 10, 3, 17, 42); // 19:42 Vienna

  // Points ~1 km apart along the same meridian (1 km straight line → 1.4 km road → 202 s at 25 km/h).
  GeoPoint north(double km) => (lat: settings.store.lat + km / 111.195, lng: settings.store.lng);
  const oneKm = 202;

  Map<String, dynamic> stop(String id, int seq, String type,
          {GeoPoint? at, String status = 'pending', String? planned, int? next, String? due, String? deliveredAt, String route = 'r1'}) =>
      {
        'id': id,
        'delivery_route_id': route,
        'order_id': type == 'customer_delivery' ? 'o$id' : null,
        'type': type,
        'sequence_number': seq,
        'latitude': (at ?? settings.store).lat,
        'longitude': (at ?? settings.store).lng,
        'customer_name': type == 'customer_delivery' ? 'Customer $id' : null,
        'status': status,
        'planned_arrival_at': planned,
        'estimated_travel_time_to_next_stop_seconds': next,
        'target_delivery_time': due,
        'actual_arrival_time': deliveredAt,
      };

  DriverInput gpsAt(GeoPoint p, {Duration age = Duration.zero}) =>
      DriverInput(id: 'd1', name: 'Barakat', isOnline: true, lastSeenAt: now.subtract(age), position: p);

  group('estimateDrive', () {
    test('matches the planner (1.4 × straight line at city speed)', () {
      expect(estimateDrive(settings.store, north(1), 25).inSeconds, closeTo(oneKm, 1));
      expect(estimateDrive(settings.store, settings.store, 25), Duration.zero);
    });
  });

  group('liveTour', () {
    final route = {'id': 'r1', 'assigned_driver_id': 'd1', 'status': 'in_progress', 'planned_return_at': '2026-10-03T18:31:00+00:00'};

    test('fresh GPS: the planner chain from the driver through the open stops and back', () {
      final stops = [
        stop('s0', 0, 'store'),
        stop('a', 1, 'customer_delivery', at: north(1), status: 'completed', deliveredAt: '2026-10-03T17:17:00+00:00'),
        stop('b', 2, 'customer_delivery', at: north(3), next: 30),
        stop('c', 3, 'customer_delivery', at: north(4), next: 30),
        stop('s9', 4, 'store'),
      ];
      final tour = liveTour(route: route, stops: stops, ordersById: const {}, driver: gpsAt(north(2)), settings: settings, now: now);

      expect(tour.fromGps, isTrue);
      expect(tour.stops.map((s) => s.state), [StopState.delivered, StopState.next, StopState.upcoming]);
      expect(tour.deliveredCount, 1);
      expect(tour.stops.first.deliveredAt, DateTime.utc(2026, 10, 3, 17, 17));
      final b = tour.stops[1], c = tour.stops[2];
      // Google legs (next: 30) are ignored, like in the planner's returnEta.
      expect(b.drive!.inSeconds, closeTo(oneKm, 2));
      expect(b.eta!.difference(now).inSeconds, closeTo(oneKm, 2));
      expect(c.eta!.difference(b.eta!).inSeconds, closeTo(300 + oneKm, 2));
      expect(tour.returnDrive!.inSeconds, closeTo(4 * oneKm, 4));
      // The planned return is ignored with fresh GPS.
      expect(tour.returnAt!.difference(c.eta!).inSeconds, closeTo(300 + 4 * oneKm, 4));
    });

    test('driver standing at the next stop is flagged as there', () {
      final stops = [stop('b', 1, 'customer_delivery', at: north(3))];
      final tour = liveTour(route: route, stops: stops, ordersById: const {}, driver: gpsAt(north(3.05)), settings: settings, now: now);
      expect(tour.stops.single.driverIsHere, isTrue);
      expect(tour.stops.single.eta!.difference(now).inSeconds, lessThan(15));
    });

    test('stale GPS: driver assumed at the next stop, chain moved back to the planner floor', () {
      final stops = [stop('b', 1, 'customer_delivery', at: north(3))];
      final tour = liveTour(
          route: route, stops: stops, ordersById: const {}, driver: gpsAt(north(2), age: const Duration(minutes: 10)), settings: settings, now: now);
      expect(tour.fromGps, isFalse);
      // Unclamped: now + 0 drive + 5 min + 3 km back = 17:57:06. The plan says 18:31, capped at +20 min.
      final unclamped = now.add(Duration(seconds: 300 + 3 * oneKm));
      expect(tour.returnAt!.difference(unclamped.add(const Duration(minutes: 20))).inSeconds.abs(), lessThan(4));
      expect(tour.stops.single.eta, now.add(const Duration(minutes: 20)));
      expect(tour.stops.single.drive, isNull);
    });

    test('all delivered: returning, back = drive from GPS to the restaurant', () {
      final stops = [stop('a', 1, 'customer_delivery', at: north(3), status: 'completed')];
      final tour = liveTour(route: route, stops: stops, ordersById: const {}, driver: gpsAt(north(2)), settings: settings, now: now);
      expect(tour.remaining, isEmpty);
      expect(tour.driverAtStore, isFalse);
      expect(tour.returnAt!.difference(now).inSeconds, closeTo(2 * oneKm, 3));

      final home = liveTour(route: route, stops: stops, ordersById: const {}, driver: gpsAt(north(0.05)), settings: settings, now: now);
      expect(home.driverAtStore, isTrue);
    });

    test('the promise comes from the order (requested first) and late/tight are flagged', () {
      final stops = [stop('b', 1, 'customer_delivery', at: north(3), due: '2026-10-03T19:00:00+00:00')];
      final orders = {
        'ob': {'id': 'ob', 'estimated_delivery_time': '2026-10-03T17:40:00+00:00', 'created_at': '2026-10-03T17:00:00+00:00'},
      };
      final tour = liveTour(route: route, stops: stops, ordersById: orders, driver: gpsAt(north(2)), settings: settings, now: now);
      expect(tour.stops.single.dueAt, DateTime.utc(2026, 10, 3, 17, 40));
      expect(tour.stops.single.punctuality, Punctuality.late);
      expect(tour.stops.single.lateBy!.inMinutes, greaterThanOrEqualTo(5));
      expect(tour.lateCount, 1);

      final tight = {
        'ob': {'id': 'ob', 'requested_delivery_time': '2026-10-03T17:46:00+00:00', 'estimated_delivery_time': '2026-10-03T17:30:00+00:00'},
      };
      final t2 = liveTour(route: route, stops: stops, ordersById: tight, driver: gpsAt(north(2)), settings: settings, now: now);
      expect(t2.stops.single.dueAt, DateTime.utc(2026, 10, 3, 17, 46));
      expect(t2.stops.single.punctuality, Punctuality.tight); // eta 17:45:22, due 17:46
    });

    test('names and addresses prefer the live order over the stop snapshot', () {
      final stops = [stop('b', 1, 'customer_delivery', at: north(3))];
      final orders = {
        'ob': {'id': 'ob', 'customer_name': 'Julia Kurcz', 'customer_street': 'Am Sonnenhang 15', 'customer_postcode': '5161', 'customer_city': 'Elixhausen', 'status': 'cancelled'},
      };
      final s = liveTour(route: route, stops: stops, ordersById: orders, driver: gpsAt(north(2)), settings: settings, now: now).stops.single;
      expect(s.name, 'Julia Kurcz');
      expect(s.address, 'Am Sonnenhang 15, 5161 Elixhausen');
      expect(s.cancelled, isTrue);
    });

    test('departure: the Start tour tap, else first delivery minus the drive there', () {
      final stops = [
        stop('a', 1, 'customer_delivery', at: north(2), status: 'completed', deliveredAt: '2026-10-03T17:17:35.631+00:00'),
        stop('b', 2, 'customer_delivery', at: north(3)),
      ];
      final tapped = liveTour(
          route: {...route, 'actual_departure_at': '2026-10-03T17:01:00+00:00', 'started_at': '2026-10-03T17:01:00+00:00'},
          stops: stops, ordersById: const {}, driver: gpsAt(north(2)), settings: settings, now: now);
      expect(tapped.departAt, DateTime.utc(2026, 10, 3, 17, 1));
      expect(tapped.departApprox, isFalse);

      final skipped = liveTour(
          route: {...route, 'started_at': '2026-10-03T17:17:35.631+00:00'},
          stops: stops, ordersById: const {}, driver: gpsAt(north(2)), settings: settings, now: now);
      expect(skipped.departApprox, isTrue);
      expect(DateTime.utc(2026, 10, 3, 17, 17, 35, 631).difference(skipped.departAt!).inSeconds, closeTo(2 * oneKm, 2));
    });

    test('a tour open for hours is flagged stale', () {
      final t = liveTour(
          route: {...route, 'started_at': '2026-10-01T18:00:00+00:00'},
          stops: [stop('a', 1, 'customer_delivery', at: north(1))], ordersById: const {}, driver: gpsAt(north(2)), settings: settings, now: now);
      expect(t.stale, isTrue);
    });
  });

  group('plannedTour', () {
    final route = {
      'id': 'r1',
      'assigned_driver_id': 'd1',
      'status': 'assigned',
      'planned_departure_at': '2026-10-03T18:10:00+00:00',
      'planned_return_at': '2026-10-03T19:09:00+00:00',
    };
    final stops = [
      stop('s0', 0, 'store', next: 809),
      stop('e', 1, 'customer_delivery', at: north(3), planned: '2026-10-03T18:23:30+00:00', next: 186),
      stop('l', 2, 'customer_delivery', at: north(4), planned: '2026-10-03T18:32:00+00:00', next: 615),
      stop('s9', 3, 'store', planned: '2026-10-03T19:09:00+00:00'),
    ];

    test('keeps the plan (and its Google legs) when the driver is back in time', () {
      final t = plannedTour(route: route, stops: stops, ordersById: const {}, earliestDeparture: DateTime.utc(2026, 10, 3, 18, 0));
      expect(t.delay, Duration.zero);
      expect(t.departAt, DateTime.utc(2026, 10, 3, 18, 10));
      expect(t.stops.first.drive, const Duration(seconds: 809));
      expect(t.stops[1].drive, const Duration(seconds: 186));
      expect(t.returnDrive, const Duration(seconds: 615));
      expect(t.stops.first.key, 'oe');
    });

    test('moves everything back when the driver returns late, never earlier', () {
      final t = plannedTour(route: route, stops: stops, ordersById: const {}, earliestDeparture: DateTime.utc(2026, 10, 3, 18, 25));
      expect(t.delay, const Duration(minutes: 15));
      expect(t.departAt, DateTime.utc(2026, 10, 3, 18, 25));
      expect(t.stops.first.eta, DateTime.utc(2026, 10, 3, 18, 38, 30));
      expect(t.returnAt, DateTime.utc(2026, 10, 3, 19, 24));
    });
  });

  group('buildDriverBoards', () {
    test('chains the next tour after the live one; offline drivers without tours are hidden', () {
      final routes = [
        {'id': 'live', 'assigned_driver_id': 'd1', 'status': 'in_progress', 'created_at': '2026-10-03T17:00:00+00:00'},
        {'id': 'next', 'assigned_driver_id': 'd1', 'status': 'assigned', 'planned_departure_at': '2026-10-03T17:45:00+00:00', 'planned_return_at': '2026-10-03T18:30:00+00:00'},
      ];
      final stops = [
        stop('b', 1, 'customer_delivery', at: north(3), route: 'live'),
        stop('x', 1, 'customer_delivery', at: north(1), planned: '2026-10-03T17:55:00+00:00', route: 'next'),
      ];
      final drivers = [
        const DriverInput(id: 'd2', name: 'Abou Nur'),
        gpsAt(north(2)),
      ];
      final boards = buildDriverBoards(drivers: drivers, routes: routes, stops: stops, ordersById: const {}, settings: settings, now: now);
      expect(boards.length, 1);
      final b = boards.single;
      expect(b.activity, DriverActivity.delivering);
      expect(b.upcoming.single.departAt, b.backAt);
      expect(b.upcoming.single.delay, greaterThan(Duration.zero));

      final all = buildDriverBoards(
          drivers: drivers, routes: routes, stops: stops, ordersById: const {}, settings: settings, now: now, includeIdleOffline: true);
      expect(all.map((b) => b.activity), [DriverActivity.delivering, DriverActivity.offline]);
    });

    test('online flag but silent for 15+ min counts as off shift', () {
      final quiet = DriverInput(id: 'd1', name: 'B', isOnline: true, lastSeenAt: now.subtract(const Duration(minutes: 20)), position: north(1));
      expect(buildDriverBoards(drivers: [quiet], routes: const [], stops: const [], ordersById: const {}, settings: settings, now: now), isEmpty);
    });

    test('waiting at the restaurant with a planned tour', () {
      final routes = [
        {'id': 'next', 'assigned_driver_id': 'd1', 'status': 'assigned', 'planned_departure_at': '2026-10-03T17:50:00+00:00'},
      ];
      final b = buildDriverBoards(drivers: [gpsAt(settings.store)], routes: routes, stops: const [], ordersById: const {}, settings: settings, now: now).single;
      expect(b.activity, DriverActivity.waitingToLeave);
      expect(b.upcoming.single.departAt, DateTime.utc(2026, 10, 3, 17, 50));
    });
  });

  group('tours without a driver', () {
    test('a tour whose driver was deleted still gets a board', () {
      final routes = [
        {'id': 'orphan', 'assigned_driver_id': null, 'status': 'in_progress', 'created_at': '2026-10-03T17:00:00+00:00'},
      ];
      final stops = [stop('b', 1, 'customer_delivery', at: north(3), route: 'orphan')];
      final boards = buildDriverBoards(drivers: const [], routes: routes, stops: stops, ordersById: const {}, settings: settings, now: now);
      expect(boards.single.name, 'No driver');
      expect(boards.single.current!.stops.single.name, 'Customer b');
    });
  });

  group('waitingOrders', () {
    test('the stale cutoff uses created_at like the planner when there is no promise', () {
      final orders = [
        {'id': 'old', 'status': 'confirmed', 'created_at': now.subtract(const Duration(minutes: 90)).toIso8601String()},
        {'id': 'new', 'status': 'confirmed', 'created_at': now.subtract(const Duration(minutes: 30)).toIso8601String()},
      ];
      expect(waitingOrders(orders, settings: settings, now: now).map((o) => o['id']), ['new']);
    });

    test('drops old, closed, routed and Foodora-rider orders like the planner', () {
      String ago(int mins) => now.subtract(Duration(minutes: mins)).toIso8601String();
      String inMins(int mins) => now.add(Duration(minutes: mins)).toIso8601String();
      final orders = [
        {'id': 'fresh', 'status': 'confirmed', 'delivery_status': 'preparing', 'created_at': ago(10), 'estimated_delivery_time': inMins(30)},
        {'id': 'yesterday', 'status': 'confirmed', 'delivery_status': 'preparing', 'created_at': ago(60 * 22)},
        {'id': 'stale', 'status': 'confirmed', 'delivery_status': 'preparing', 'created_at': ago(150), 'estimated_delivery_time': ago(90)},
        {'id': 'cancelled', 'status': 'cancelled', 'delivery_status': 'preparing', 'created_at': ago(5)},
        {'id': 'routed', 'status': 'confirmed', 'delivery_status': 'assigned_to_route', 'created_at': ago(5), 'delivery_route_id': 'r'},
        {'id': 'rider', 'status': 'confirmed', 'created_at': ago(5), 'transport_type': 'PICKUP_LOGISTICS'},
        {'id': 'early', 'status': 'confirmed', 'delivery_status': 'preparing', 'created_at': ago(5), 'requested_delivery_time': inMins(10)},
      ];
      expect(waitingOrders(orders, settings: settings, now: now).map((o) => o['id']), ['early', 'fresh']);
    });
  });

  group('helpers', () {
    test('cash detection covers Foodora and Lieferando', () {
      expect(isCash({'payment_method': 'cash on delivery'}), isTrue);
      expect(isCash({'payment_method': 'online', 'pay_method': 'cash'}), isTrue);
      expect(isCash({'payment_method': 'online', 'pay_method': 'online'}), isFalse);
      expect(isCash(null), isFalse);
    });
    test('relative and minutes', () {
      expect(relative(now.add(const Duration(minutes: 12)), now), 'in 12 min');
      expect(relative(now.subtract(const Duration(minutes: 5)), now), '5 min ago');
      expect(relative(now.add(const Duration(seconds: 20)), now), 'now');
      expect(relative(now.add(const Duration(minutes: 65)), now), 'in 1 h 05');
      expect(minutes(const Duration(seconds: 20)), '1 min');
      expect(minutes(const Duration(minutes: 13)), '13 min');
    });
    test('parseTs treats a missing offset as UTC', () {
      expect(parseTs('2026-10-03T17:42:00'), DateTime.utc(2026, 10, 3, 17, 42));
      expect(parseTs('2026-10-03T19:42:00+02:00'), DateTime.utc(2026, 10, 3, 17, 42));
      expect(parseTs('2026-10-03 17:42:00.123+00'), DateTime.utc(2026, 10, 3, 17, 42, 0, 123));
    });
  });
}
