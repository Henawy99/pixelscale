import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:restaurantadmin/screens/map/tour_eta.dart';
import 'package:restaurantadmin/screens/map/tour_panel.dart';

void main() {
  const settings = EtaSettings();
  final now = DateTime.now().toUtc();
  GeoPoint north(double km) => (lat: settings.store.lat + km / 111.195, lng: settings.store.lng);
  String iso(Duration d) => now.add(d).toIso8601String();

  Map<String, dynamic> stop(String id, String route, int seq, {String status = 'pending', Duration? planned}) => {
        'id': id,
        'delivery_route_id': route,
        'order_id': 'o$id',
        'type': 'customer_delivery',
        'sequence_number': seq,
        'latitude': north(seq.toDouble()).lat,
        'longitude': north(seq.toDouble()).lng,
        'customer_name': 'Customer with a rather long name $id',
        'customer_address': 'Elsa-Brändström-Straße 2, 5020 Salzburg',
        'status': status,
        'planned_arrival_at': planned == null ? null : iso(planned),
        'actual_arrival_time': status == 'completed' ? iso(const Duration(minutes: -10)) : null,
        'estimated_travel_time_to_next_stop_seconds': 300,
      };

  List<DriverBoard> boards() => buildDriverBoards(
        drivers: [
          DriverInput(id: 'd1', name: 'Barakat', colorIndex: 4, isOnline: true, lastSeenAt: now, position: north(2), speedMs: 12),
          DriverInput(id: 'd2', name: 'Abou Nur', isOnline: true, lastSeenAt: now, position: north(0.01)),
        ],
        routes: [
          {'id': 'live', 'assigned_driver_id': 'd1', 'status': 'in_progress', 'created_at': iso(const Duration(minutes: -30)), 'started_at': iso(const Duration(minutes: -30))},
          {'id': 'next', 'assigned_driver_id': 'd1', 'status': 'assigned', 'planned_departure_at': iso(const Duration(minutes: 20)), 'planned_return_at': iso(const Duration(minutes: 70))},
          {'id': 'abou', 'assigned_driver_id': 'd2', 'status': 'assigned', 'planned_departure_at': iso(const Duration(minutes: -2)), 'planned_return_at': iso(const Duration(minutes: 40))},
          {'id': 'orphan', 'assigned_driver_id': null, 'status': 'assigned', 'planned_departure_at': iso(const Duration(minutes: 5))},
        ],
        stops: [
          stop('a', 'live', 1, status: 'completed'),
          stop('b', 'live', 2),
          stop('c', 'live', 3),
          stop('d', 'next', 1, planned: const Duration(minutes: 30)),
          stop('e', 'next', 2, planned: const Duration(minutes: 40)),
          stop('f', 'abou', 1, planned: const Duration(minutes: 10)),
          stop('g', 'orphan', 1, planned: const Duration(minutes: 15)),
        ],
        ordersById: {
          'ob': {'id': 'ob', 'payment_method': 'online', 'pay_method': 'cash', 'pays_with': '50', 'total_price': 32.5, 'customer_phone': '+43 660 1234567', 'estimated_delivery_time': iso(const Duration(minutes: 2))},
          'oc': {'id': 'oc', 'payment_method': 'cash on delivery', 'total_price': 20.0, 'collect': '20.99', 'status': 'cancelled'},
        },
        settings: settings,
        now: now,
      );

  final waiting = [
    {'id': 'w1', 'customer_name': 'Felix', 'customer_street': 'Linzer Gasse 1', 'customer_city': 'Salzburg', 'estimated_delivery_time': iso(const Duration(minutes: 25)), 'is_unassignable': true, 'unassignable_reason': 'No driver is online in the driver app'},
    {'id': 'w2', 'customer_name': 'Aya', 'planned_arrival_at': iso(const Duration(minutes: 50)), 'estimated_delivery_time': iso(const Duration(minutes: 45))},
  ];

  Widget panel({ScrollController? controller, Widget? header}) => TourPanel(
        boards: boards(),
        waiting: waiting,
        ordersById: const {},
        now: now,
        selectedDriverId: 'd1',
        selectedStopId: 'ob',
        problem: 'Can\'t reach the server right now',
        scrollController: controller,
        header: header,
        onDriverTap: (_) {},
        onStopTap: (_, __) {},
        onOrderDetails: (_) {},
        onCall: (_) {},
        onStartTour: (_) {},
        onMoveStop: (_, __) {},
        onPlanNow: () {},
      );

  Future<void> pumpAt(WidgetTester tester, Size size, Widget child) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
    await tester.pump();
  }

  testWidgets('side panel lays out at 340 px wide without errors', (tester) async {
    await pumpAt(tester, const Size(1024, 900), Row(children: [SizedBox(width: 340, child: panel()), const Expanded(child: SizedBox())]));
    expect(tester.takeException(), isNull);
    expect(find.text('BACK AT THE RESTAURANT'), findsOneWidget);
    expect(find.text('Barakat'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('No driver'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('No driver'), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('Waiting for a driver (2)'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('Waiting for a driver (2)'), findsOneWidget);
    expect(find.text('Planned for a later tour · ~${clock(now.add(const Duration(minutes: 50)))}'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone: panel inside the pull-up sheet, scroll to the end, open the tour toggles', (tester) async {
    await pumpAt(
      tester,
      const Size(375, 812),
      Stack(children: [
        const Positioned.fill(child: ColoredBox(color: Colors.grey)),
        DraggableScrollableSheet(
          initialChildSize: 0.42,
          minChildSize: 0.16,
          maxChildSize: 0.94,
          snap: true,
          snapSizes: const [0.16, 0.42, 0.94],
          builder: (context, controller) => Material(child: panel(controller: controller, header: const SizedBox(height: 14))),
        ),
      ]),
    );
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(TourPanel), const Offset(0, -2000));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(TourPanel), const Offset(0, -4000));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // Collapse/expand a planned tour.
    final toggle = find.byIcon(Icons.expand_less_rounded);
    if (toggle.evaluate().isNotEmpty) {
      await tester.tap(toggle.first);
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('cash chip shows what to collect, cancelled orders are flagged', (tester) async {
    final b = boards();
    final live = b.firstWhere((x) => x.driverId == 'd1').current!;
    final orders = {
      'ob': {'id': 'ob', 'payment_method': 'online', 'pay_method': 'cash', 'pays_with': '50', 'total_price': 32.5},
      'oc': {'id': 'oc', 'payment_method': 'cash on delivery', 'total_price': 20.0, 'collect': '20.99', 'status': 'cancelled'},
    };
    expect(live.stops.map((s) => s.cancelled), [false, false, true]);
    await pumpAt(
      tester,
      const Size(1024, 2400),
      SizedBox(
        width: 420,
        child: TourPanel(
          boards: b,
          waiting: const [],
          ordersById: orders,
          now: now,
          onDriverTap: (_) {},
          onStopTap: (_, __) {},
          onOrderDetails: (_) {},
          onPlanNow: () {},
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Cash €32.50 · pays with €50'), findsOneWidget);
    expect(find.text('Cash €20.99'), findsOneWidget);
    expect(find.text('ORDER CANCELLED'), findsOneWidget);
  });
}
