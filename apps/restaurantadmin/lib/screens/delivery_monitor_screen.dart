import 'dart:async';
import 'dart:math' as math;
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Clipboard
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:flutter_map/flutter_map.dart' as fmap;
import 'package:latlong2/latlong.dart' as latlong;
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:restaurantadmin/models/driver.dart' as app_driver_model;
import 'package:restaurantadmin/models/order.dart' as app_order;
import 'package:restaurantadmin/screens/delivery_settings_screen.dart';
import 'package:restaurantadmin/screens/map/map_icons.dart';
import 'package:restaurantadmin/screens/map/route_lines.dart';
import 'package:restaurantadmin/screens/map/tour_eta.dart';
import 'package:restaurantadmin/screens/map/tour_panel.dart';

/// Check if running on desktop platform
bool get isDesktopPlatform {
  if (kIsWeb) return false;
  return Platform.isMacOS || Platform.isWindows || Platform.isLinux;
}

/// The Map tab: where every driver is, their tour with the time of each stop and when they
/// are back at the restaurant, and the orders still waiting for a driver.
class DeliveryMonitorScreen extends StatefulWidget {
  final SupabaseClient supabaseClient;

  const DeliveryMonitorScreen({super.key, required this.supabaseClient});

  @override
  State<DeliveryMonitorScreen> createState() => _DeliveryMonitorScreenState();
}

class _DeliveryMonitorScreenState extends State<DeliveryMonitorScreen> with TickerProviderStateMixin {
  SupabaseClient get _db => widget.supabaseClient;

  static const String _restaurantAddress = 'Minnesheimstraße 5, 5023 Salzburg';
  static const double _wideLayoutFrom = 720;
  static const double _sheetStart = 0.42;

  static const String _orderColumns =
      'id, daily_order_number, customer_name, customer_phone, customer_street, customer_postcode, customer_city, '
      'delivery_latitude, delivery_longitude, status, delivery_status, total_price, payment_method, created_at, '
      'estimated_delivery_time, requested_delivery_time, planned_arrival_at, delivery_route_id, fulfillment_type, '
      'is_unassignable, unassignable_reason, order_type_name, '
      'pay_method:platform_raw_data->payment->>method, pays_with:platform_raw_data->payment->>pays_with, '
      'collect:platform_raw_data->payment->>collectAtDropoff, '
      'transport_type:platform_raw_data->transport->>type';

  // ── Data ──────────────────────────────────────────────────────────────────
  List<app_driver_model.Driver> _drivers = [];
  final Map<String, int> _colorByDriver = {};
  List<Map<String, dynamic>> _routes = [];
  List<Map<String, dynamic>> _stops = [];
  List<Map<String, dynamic>> _recentOrders = [];
  Map<String, Map<String, dynamic>> _ordersById = {};
  EtaSettings _settings = const EtaSettings();
  bool _driversLoaded = false;
  bool _toursLoaded = false;
  String? _driversProblem;
  String? _toursProblem;
  bool _planning = false;
  bool _planAgain = false;
  DateTime _now = DateTime.now().toUtc();

  // ── Selection ─────────────────────────────────────────────────────────────
  String? _selectedDriverId;
  String? _selectedStopKey;

  // ── Online/offline notices ────────────────────────────────────────────────
  final Map<String, bool> _wasOnline = {};
  bool _seenDrivers = false;

  // ── Realtime and timers ───────────────────────────────────────────────────
  // Unique channel names: the screen can be open twice (tab + pushed from Orders).
  late final String _channelTag = '${identityHashCode(this)}';
  RealtimeChannel? _driversChannel;
  RealtimeChannel? _toursChannel;
  Timer? _clock;
  Timer? _driversPoll;
  Timer? _toursPoll;
  Timer? _toursDebounce;
  bool _toursLoading = false;
  bool _toursAgain = false;

  // ── Map ───────────────────────────────────────────────────────────────────
  gmaps.GoogleMapController? _gmap;
  final fmap.MapController _fmap = fmap.MapController();
  bool _fmapReady = false;
  bool _fittedOnce = false;
  final MapIcons _icons = MapIcons();
  final Map<String, gmaps.BitmapDescriptor> _driverIcons = {};
  final ValueNotifier<Set<gmaps.Marker>> _staticMarkers = ValueNotifier({});
  final ValueNotifier<Map<String, gmaps.LatLng>> _driverPos = ValueNotifier({});
  final Map<String, gmaps.LatLng> _fromPos = {};
  final Map<String, gmaps.LatLng> _toPos = {};
  late final AnimationController _move;
  int _markerBuild = 0;

  // ── Street geometry for the tour lines ────────────────────────────────────
  final RoadCache _roads = RoadCache();
  final Map<String, DriverRoad> _driverRoads = {};
  final Map<String, DateTime> _driverRoadAskedAt = {};
  bool _roadsBusy = false;

  @override
  void initState() {
    super.initState();
    _move = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..addListener(_onMoveTick);
    _loadDrivers();
    _loadTours();
    _subscribe();
    _clock = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now().toUtc());
      _refreshMarkers();
      _maybeFitOnce();
      _ensureRoads();
    });
    // Back-ups for realtime. Orders are not in the realtime publication, so new orders
    // waiting for a driver arrive with the tours poll (or the planner's plan_log insert).
    _driversPoll = Timer.periodic(const Duration(seconds: 15), (_) => _loadDrivers());
    _toursPoll = Timer.periodic(const Duration(seconds: 20), (_) => _loadTours());
  }

  @override
  void dispose() {
    _clock?.cancel();
    _driversPoll?.cancel();
    _toursPoll?.cancel();
    _toursDebounce?.cancel();
    _driversChannel?.unsubscribe();
    _toursChannel?.unsubscribe();
    _move.dispose();
    _staticMarkers.dispose();
    _driverPos.dispose();
    _gmap?.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Data
  // ═══════════════════════════════════════════════════════════════════════════

  /// Stable across phone and web builds (String.hashCode is not).
  static int _stableColor(String id) => id.codeUnits.fold<int>(7, (h, c) => (h * 31 + c) & 0x3fffffff) % kDriverColors.length;

  int _colorOf(String driverId) => _colorByDriver[driverId] ?? _stableColor(driverId);

  Future<void> _loadDrivers() async {
    if (!mounted) return;
    try {
      final rows = await _db.from('drivers').select('*, employee:employees(color_index)').order('name', ascending: true);
      if (!mounted) return;
      final list = <app_driver_model.Driver>[];
      for (final r in rows as List) {
        final m = Map<String, dynamic>.from(r as Map);
        final employee = m['employee'];
        final d = app_driver_model.Driver.fromJson(m);
        final color = employee is Map ? (employee['color_index'] as num?)?.toInt() : null;
        _colorByDriver[d.id] = color ?? _stableColor(d.id);
        list.add(d);
      }
      _noticeOnlineChanges(list);
      setState(() {
        _drivers = list;
        _driversLoaded = true;
        _driversProblem = null;
      });
      _onDriversMoved();
      if (_driverIconMissing()) _refreshMarkers();
      _maybeFitOnce();
    } catch (e) {
      _failed('drivers', e);
    }
  }

  /// A GPS ping from realtime: update that one driver without a round trip.
  void _applyDriverRow(Map<String, dynamic> row) {
    final id = row['id'] as String?;
    if (id == null) return;
    final i = _drivers.indexWhere((d) => d.id == id);
    if (i < 0) {
      _loadDrivers();
      return;
    }
    final updated = app_driver_model.Driver.fromJson(row);
    final list = [..._drivers]..[i] = updated;
    _noticeOnlineChanges(list);
    setState(() => _drivers = list);
    _onDriversMoved();
    if (_driverIconMissing()) _refreshMarkers();
  }

  /// A driver who should have a marker but whose icon (online/stale look) is not painted yet.
  bool _driverIconMissing() {
    if (isDesktopPlatform) return false;
    return _driversOnMap(_boards()).any((b) => !_driverIcons.containsKey('${b.driverId}:${b.gpsFresh(_now)}'));
  }

  Future<void> _loadTours() async {
    if (!mounted) return;
    if (_toursLoading) {
      _toursAgain = true;
      return;
    }
    _toursLoading = true;
    try {
      final since = DateTime.now().toUtc().subtract(const Duration(hours: 12)).toIso8601String();
      // No age limit: a tour left open in the driver app still counts for the planner.
      final routeRows = await _db
          .from('delivery_routes')
          .select('id, assigned_driver_id, status, planned_departure_at, planned_return_at, started_at, '
              'actual_departure_at, confirmed_at, created_at, total_estimated_duration_seconds')
          .inFilter('status', ['assigned', 'in_progress'])
          .order('created_at', ascending: true);
      final routes = (routeRows as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

      var stops = <Map<String, dynamic>>[];
      if (routes.isNotEmpty) {
        final stopRows = await _db
            .from('route_stops')
            .select('id, delivery_route_id, order_id, type, sequence_number, latitude, longitude, customer_name, '
                'customer_address, estimated_arrival_time, planned_arrival_at, target_delivery_time, status, '
                'actual_arrival_time, departure_time, estimated_travel_time_to_next_stop_seconds')
            .inFilter('delivery_route_id', routes.map((r) => r['id'] as String).toList())
            .order('sequence_number');
        stops = (stopRows as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }

      final orderRows = await _db.from('orders').select(_orderColumns).eq('fulfillment_type', 'delivery').gte('created_at', since);
      final orders = (orderRows as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final byId = {for (final o in orders) o['id'] as String: o};
      final missing = stops.map((s) => s['order_id'] as String?).whereType<String>().where((id) => !byId.containsKey(id)).toSet();
      if (missing.isNotEmpty) {
        final extra = await _db.from('orders').select(_orderColumns).inFilter('id', missing.toList());
        for (final o in extra as List) {
          final m = Map<String, dynamic>.from(o as Map);
          byId[m['id'] as String] = m;
        }
      }

      // The oldest row is the planner's.
      final settingsRow =
          await _db.from('delivery_settings').select().order('created_at', ascending: true).limit(1).maybeSingle();

      if (!mounted) return;
      setState(() {
        _routes = routes;
        _stops = stops;
        _recentOrders = orders;
        _ordersById = byId;
        _settings = EtaSettings.fromRow(settingsRow);
        _toursLoaded = true;
        _toursProblem = null;
        _now = DateTime.now().toUtc();
      });
      _refreshMarkers();
      _maybeFitOnce();
      _ensureRoads();
    } catch (e) {
      _failed('tours', e);
    } finally {
      _toursLoading = false;
      if (_toursAgain) {
        _toursAgain = false;
        _loadTours();
      }
    }
  }

  void _scheduleTours() {
    _toursDebounce?.cancel();
    _toursDebounce = Timer(const Duration(milliseconds: 700), _loadTours);
  }

  void _subscribe() {
    _driversChannel = _db
        .channel('map-drivers-$_channelTag')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'drivers',
          callback: (payload) {
            if (!mounted) return;
            if (payload.eventType == PostgresChangeEvent.update && payload.newRecord.isNotEmpty) {
              _applyDriverRow(payload.newRecord);
            } else {
              _loadDrivers();
            }
          },
        )
        .subscribe();

    void tours(PostgresChangePayload _) {
      if (mounted) _scheduleTours();
    }

    _toursChannel = _db
        .channel('map-tours-$_channelTag')
        .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'delivery_routes', callback: tours)
        .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'route_stops', callback: tours)
        .onPostgresChanges(event: PostgresChangeEvent.insert, schema: 'public', table: 'plan_log', callback: tours)
        .subscribe();
  }

  void _failed(String what, Object e) {
    debugPrint('[Map] Loading $what failed: $e');
    if (!mounted) return;
    const text = 'Can\'t reach the server right now — showing the last known positions. Retrying…';
    setState(() => what == 'drivers' ? _driversProblem = text : _toursProblem = text);
  }

  void _noticeOnlineChanges(List<app_driver_model.Driver> drivers) {
    if (!_seenDrivers) {
      for (final d in drivers) {
        _wasOnline[d.id] = d.isOnline;
      }
      _seenDrivers = true;
      return;
    }
    for (final d in drivers) {
      final before = _wasOnline[d.id];
      _wasOnline[d.id] = d.isOnline;
      if (before == null || before == d.isOnline || !mounted) continue;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(d.isOnline ? '${d.name} is online in the driver app' : '${d.name} went offline'),
          backgroundColor: d.isOnline ? const Color(0xFF059669) : const Color(0xFF4B5563),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Derived view
  // ═══════════════════════════════════════════════════════════════════════════

  List<DriverInput> get _driverInputs => [
        for (final d in _drivers)
          DriverInput(
            id: d.id,
            name: d.name,
            colorIndex: _colorOf(d.id),
            isOnline: d.isOnline,
            lastSeenAt: d.lastSeenAt,
            position: d.currentLocation == null ? null : (lat: d.currentLocation!.latitude, lng: d.currentLocation!.longitude),
            speedMs: d.speed,
          ),
      ];

  List<DriverBoard> _boards() => buildDriverBoards(
        drivers: _driverInputs,
        routes: _routes,
        stops: _stops,
        ordersById: _ordersById,
        settings: _settings,
        now: _now,
      );

  List<Map<String, dynamic>> _waiting() => waitingOrders(_recentOrders, settings: _settings, now: _now);

  /// Drivers worth a marker: on a tour or on shift, with a known position.
  Iterable<DriverBoard> _driversOnMap(List<DriverBoard> boards) =>
      boards.where((b) => b.position != null && (b.current != null || b.isOnline));

  // ═══════════════════════════════════════════════════════════════════════════
  // Actions
  // ═══════════════════════════════════════════════════════════════════════════

  void _toast(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: error ? const Color(0xFFDC2626) : const Color(0xFF111827),
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: error ? 6 : 3),
    ));
  }

  /// Runs the planner. A request while it is running queues one more run, so a change made
  /// meanwhile (e.g. a second "Give to …") is not lost.
  Future<void> _replan({bool quiet = false}) async {
    if (_planning) {
      _planAgain = true;
      return;
    }
    setState(() => _planning = true);
    try {
      do {
        _planAgain = false;
        await _db.functions.invoke('plan-routes', body: {'trigger_reason': 'manual'});
      } while (_planAgain && mounted);
      await _loadTours();
      if (!quiet) _toast('Tours planned again with the latest orders');
    } catch (e) {
      _toast('Could not plan the tours: $e', error: true);
    } finally {
      if (mounted) setState(() => _planning = false);
    }
  }

  Future<void> _moveStop(TourStop stop, DriverBoard target) async {
    try {
      // The planner re-creates stop rows, so pin by order when we can.
      final rows = stop.orderId != null
          ? await _db.from('route_stops').update({'pinned_driver_id': target.driverId}).eq('order_id', stop.orderId!).select('id')
          : await _db.from('route_stops').update({'pinned_driver_id': target.driverId}).eq('id', stop.id).select('id');
      if ((rows as List).isEmpty) {
        _toast('That tour was just re-planned — try again', error: true);
        await _loadTours();
        return;
      }
      _toast('${stop.name} goes to ${target.name} — re-planning…');
      await _replan(quiet: true);
    } catch (e) {
      _toast('Could not move the order: $e', error: true);
    }
  }

  Future<void> _startTour(Tour tour) async {
    final driver = _drivers.where((d) => d.id == tour.driverId).firstOrNull;
    final name = driver?.name ?? 'The driver';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Start this tour?'),
        content: Text(
          'Only do this if $name has already left with the food and did not tap "Start tour" in the driver app.\n\n'
          'The ${tour.stops.length} ${tour.stops.length == 1 ? 'order goes' : 'orders go'} out for delivery.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Start tour')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _db.rpc('driver_start_route', params: {'p_route_id': tour.routeId});
      await _loadTours();
      _toast('Tour started for $name');
    } catch (e) {
      _toast('Could not start the tour: $e', error: true);
    }
  }

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'[^\d+]'), ''));
    if (!await launchUrl(uri)) _toast('Could not start a call to $phone', error: true);
  }

  Future<void> _openOrder(String orderId) async {
    try {
      final row = await _db.from('orders').select().eq('id', orderId).single();
      if (!mounted) return;
      _showOrderDetailsBottomSheet(app_order.Order.fromJson(row));
    } catch (e) {
      _toast('Could not load the order: $e', error: true);
    }
  }

  void _selectDriver(DriverBoard b) {
    final same = _selectedDriverId == b.driverId && _selectedStopKey == null;
    setState(() {
      _selectedDriverId = same ? null : b.driverId;
      _selectedStopKey = null;
    });
    _refreshMarkers();
    if (same) {
      _fitAll();
    } else {
      _fitDriver(b);
    }
  }

  void _selectStop(DriverBoard b, TourStop s) {
    setState(() {
      _selectedDriverId = b.driverId;
      _selectedStopKey = s.key;
    });
    _refreshMarkers();
    if (s.point != null) _focus(s.point!, 15);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Camera
  // ═══════════════════════════════════════════════════════════════════════════

  bool get _mapReady => isDesktopPlatform ? _fmapReady : _gmap != null;

  /// Frame everyone once, as soon as the map is on screen with a real size. The tab is built
  /// at app start while hidden (IndexedStack), so a fit at that point would hit a 0×0 map;
  /// the 15 s clock retries until it works.
  void _maybeFitOnce() {
    if (_fittedOnce || !_mapReady || !_driversLoaded || !_toursLoaded) return;
    _fittedOnce = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (!isDesktopPlatform) {
        try {
          final r = await _gmap!.getVisibleRegion();
          if (r.northeast.latitude == r.southwest.latitude || r.northeast.longitude == r.southwest.longitude) {
            _fittedOnce = false; // Not laid out yet.
            return;
          }
        } catch (_) {
          _fittedOnce = false;
          return;
        }
      }
      _fitAll();
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  void _fitAll() {
    final boards = _boards();
    final pts = <GeoPoint>[_settings.store];
    for (final b in _driversOnMap(boards)) {
      pts.add(b.position!);
    }
    for (final b in boards) {
      for (final t in [if (b.current != null) b.current!, ...b.upcoming]) {
        pts.addAll(t.stops.where((s) => !s.isDone && s.point != null).map((s) => s.point!));
      }
    }
    for (final o in _waiting()) {
      final lat = (o['delivery_latitude'] as num?)?.toDouble();
      final lng = (o['delivery_longitude'] as num?)?.toDouble();
      if (lat != null && lng != null) pts.add((lat: lat, lng: lng));
    }
    _fit(pts);
  }

  void _fitDriver(DriverBoard b) {
    final pts = <GeoPoint>[_settings.store];
    if (b.position != null) pts.add(b.position!);
    final tour = b.current ?? b.upcoming.firstOrNull;
    if (tour != null) pts.addAll(tour.stops.where((s) => !s.isDone && s.point != null).map((s) => s.point!));
    _fit(pts);
  }

  void _fit(List<GeoPoint> pts) {
    if (pts.isEmpty || !_mapReady) return;
    final b = boundsOf(pts);
    try {
      if (isDesktopPlatform) {
        _fmap.fitCamera(fmap.CameraFit.bounds(
          bounds: fmap.LatLngBounds(latlong.LatLng(b.south, b.west), latlong.LatLng(b.north, b.east)),
          padding: const EdgeInsets.all(56),
          maxZoom: 16,
        ));
      } else {
        _gmap!.animateCamera(gmaps.CameraUpdate.newLatLngBounds(
          gmaps.LatLngBounds(southwest: gmaps.LatLng(b.south, b.west), northeast: gmaps.LatLng(b.north, b.east)),
          56,
        ));
      }
    } catch (e) {
      debugPrint('[Map] Camera fit failed: $e');
    }
  }

  void _focus(GeoPoint p, double zoom) {
    if (!_mapReady) return;
    try {
      if (isDesktopPlatform) {
        _fmap.move(latlong.LatLng(p.lat, p.lng), zoom);
      } else {
        _gmap!.animateCamera(gmaps.CameraUpdate.newLatLngZoom(gmaps.LatLng(p.lat, p.lng), zoom));
      }
    } catch (e) {
      debugPrint('[Map] Camera move failed: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Markers and lines
  // ═══════════════════════════════════════════════════════════════════════════

  /// Smoothly glide driver markers to their new position (phones only: on the web every
  /// marker update re-uploads the icon, so markers jump there instead).
  void _onDriversMoved() {
    final targets = <String, gmaps.LatLng>{};
    for (final d in _drivers) {
      if (d.currentLocation != null) targets[d.id] = d.currentLocation!;
    }
    final shown = _driverPos.value;
    final changed = targets.length != shown.length ||
        targets.entries.any((e) => _toPos[e.key] == null || _toPos[e.key] != e.value);
    if (!changed) return;
    _fromPos
      ..clear()
      ..addAll({for (final e in targets.entries) e.key: shown[e.key] ?? e.value});
    _toPos
      ..clear()
      ..addAll(targets);
    if (kIsWeb || isDesktopPlatform) {
      _driverPos.value = Map.of(targets);
    } else {
      _move.forward(from: 0);
    }
    _refreshMarkers();
    _ensureRoads();
  }

  void _onMoveTick() {
    final t = Curves.easeInOut.transform(_move.value);
    _driverPos.value = {
      for (final e in _toPos.entries)
        e.key: () {
          final a = _fromPos[e.key] ?? e.value;
          return gmaps.LatLng(a.latitude + (e.value.latitude - a.latitude) * t, a.longitude + (e.value.longitude - a.longitude) * t);
        }(),
    };
  }

  /// Rebuild the Google markers that do not move every frame (restaurant, stops, waiting
  /// orders) and make sure every driver icon is painted.
  Future<void> _refreshMarkers() async {
    if (isDesktopPlatform || !mounted) return;
    final build = ++_markerBuild;
    final boards = _boards();
    final waiting = _waiting();
    final store = await _icons.store();
    final waitingIcon = await _icons.waiting();
    final markers = <gmaps.Marker>{
      gmaps.Marker(
        markerId: const gmaps.MarkerId('store'),
        position: gmaps.LatLng(_settings.store.lat, _settings.store.lng),
        icon: store,
        anchor: const Offset(0.5, 0.5),
        zIndexInt: 5,
        infoWindow: const gmaps.InfoWindow(title: 'Restaurant', snippet: _restaurantAddress),
      ),
    };

    for (final b in boards) {
      final color = driverColor(b.colorIndex);
      final dim = _selectedDriverId != null && _selectedDriverId != b.driverId;
      final tours = [if (b.current != null) b.current!, ...b.upcoming];
      var number = 0;
      for (final tour in tours) {
        for (var i = 0; i < tour.stops.length; i++) {
          final s = tour.stops[i];
          number++;
          if (s.point == null) continue;
          final style = s.isDone
              ? 'done'
              : !tour.live
                  ? 'planned'
                  : (s.state == StopState.next ? 'next' : 'live');
          final selected = s.key == _selectedStopKey;
          // Stops still to do carry their arrival time and first name, e.g. "22:14 Anastasia".
          final ({gmaps.BitmapDescriptor icon, Offset anchor}) pin = s.isDone || s.eta == null
              ? (icon: await _icons.stop(number: number, color: color, style: style, selected: selected), anchor: const Offset(0.5, 1))
              : await _icons.stopWithLabel(
                  number: number,
                  color: color,
                  style: style,
                  selected: selected,
                  time: clock(s.eta),
                  name: s.name.trim().split(RegExp(r'\s+')).first,
                  late: s.punctuality == Punctuality.late,
                  dim: !tour.live,
                );
          final when = s.isDone
              ? 'delivered ${clock(s.deliveredAt)}'
              : '~${clock(s.eta)}${s.dueAt != null ? ' · due ${clock(s.dueAt)}' : ''}';
          markers.add(gmaps.Marker(
            markerId: gmaps.MarkerId('stop_${tour.routeId}_${s.key}'),
            position: gmaps.LatLng(s.point!.lat, s.point!.lng),
            icon: pin.icon,
            anchor: pin.anchor,
            alpha: dim ? 0.45 : 1,
            zIndexInt: selected ? 6 : (s.isDone ? 1 : (tour.live ? 3 : 2)),
            infoWindow: gmaps.InfoWindow(title: '$number. ${s.name} (${b.name})', snippet: when),
            onTap: () => _selectStop(b, s),
          ));
        }
      }
      if (b.position != null && !_driverIcons.containsKey('${b.driverId}:${b.gpsFresh(_now)}')) {
        _driverIcons['${b.driverId}:${b.gpsFresh(_now)}'] =
            await _icons.driver(name: b.name, color: color, stale: !b.gpsFresh(_now));
      }
    }

    for (final o in waiting) {
      final lat = (o['delivery_latitude'] as num?)?.toDouble();
      final lng = (o['delivery_longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;
      final due = dueAt(o);
      markers.add(gmaps.Marker(
        markerId: gmaps.MarkerId('wait_${o['id']}'),
        position: gmaps.LatLng(lat, lng),
        icon: waitingIcon,
        anchor: const Offset(0.5, 1),
        zIndexInt: 2,
        infoWindow: gmaps.InfoWindow(
          title: '${o['customer_name'] ?? 'Customer'} · waiting for a driver',
          snippet: due == null ? null : 'due ${clock(due)}',
        ),
        onTap: () => _openOrder(o['id'] as String),
      ));
    }

    if (!mounted || build != _markerBuild) return;
    _staticMarkers.value = markers;
  }

  Set<gmaps.Marker> _driverMarkers(List<DriverBoard> boards, Map<String, gmaps.LatLng> positions) {
    final out = <gmaps.Marker>{};
    for (final b in _driversOnMap(boards)) {
      final pos = positions[b.driverId] ?? gmaps.LatLng(b.position!.lat, b.position!.lng);
      final icon = _driverIcons['${b.driverId}:${b.gpsFresh(_now)}'];
      if (icon == null) continue;
      final back = b.backAt;
      out.add(gmaps.Marker(
        markerId: gmaps.MarkerId('driver_${b.driverId}'),
        position: pos,
        icon: icon,
        anchor: MapIcons.driverAnchor,
        zIndexInt: 10,
        infoWindow: gmaps.InfoWindow(
          title: b.name,
          snippet: back != null ? 'Back at the restaurant ~${clock(back)}' : null,
        ),
        onTap: () => _selectDriver(b),
      ));
    }
    return out;
  }

  /// Each tour line along the streets (straight where no road is known yet), starting at the
  /// driver on a tour that is on the road.
  List<({String id, Color color, List<GeoPoint> points, bool live, bool dim})> _tourLines(List<DriverBoard> boards) => [
        for (final l in tourLines(boards, _settings.store, _now))
          (
            id: l.id,
            color: driverColor(l.colorIndex),
            points: composeLine(l, _roads, driverRoad: _driverRoads[l.driverId]),
            live: l.live,
            dim: _selectedDriverId != null && _selectedDriverId != l.driverId,
          ),
      ];

  /// Fetches the street geometry the tour lines still need: once per leg (cached on the
  /// server too), plus a road from the driver to the next stop when the driver left the
  /// planned leg, at most once a minute per driver.
  Future<void> _ensureRoads() async {
    if (_roadsBusy || !mounted || !_toursLoaded) return;
    _roadsBusy = true;
    var again = false;
    try {
      final now = DateTime.now().toUtc();
      final lines = tourLines(_boards(), _settings.store, _now);
      final wanted = <(GeoPoint, GeoPoint)>[for (final l in lines) ...l.legs];
      final driverWanted = <String, (GeoPoint, GeoPoint)>{};
      for (final l in lines.where((l) => l.live)) {
        final need = driverLegNeeded(l, _roads, driverRoad: _driverRoads[l.driverId]);
        if (need == null) continue;
        final cached = _roads.road(need.$1, need.$2);
        if (cached != null) {
          _driverRoads[l.driverId] = (to: need.$2, points: cached);
          continue;
        }
        final asked = _driverRoadAskedAt[l.driverId];
        if (asked == null || now.difference(asked) > const Duration(seconds: 60)) driverWanted[l.driverId] = need;
      }
      final missing = _roads.missing([...wanted, ...driverWanted.values], now);
      if (missing.isEmpty) return;
      for (final id in driverWanted.keys) {
        _driverRoadAskedAt[id] = now;
      }

      for (var i = 0; i < missing.length; i += 40) {
        final batch = missing.sublist(i, math.min(i + 40, missing.length));
        try {
          final res = await _db.functions.invoke('route-lines', body: {
            'legs': [
              for (final (a, b) in batch)
                {
                  'from': {'lat': a.lat, 'lng': a.lng},
                  'to': {'lat': b.lat, 'lng': b.lng},
                },
            ],
          }).timeout(const Duration(seconds: 25));
          final data = res.data;
          final legs = data is Map && data['legs'] is List ? data['legs'] as List : const [];
          if (legs.length != batch.length) throw StateError('route-lines answered ${legs.length} of ${batch.length} legs');
          _roads.putAnswers(batch, legs, DateTime.now().toUtc());
          // Once the planned legs are in, a road from the driver may be needed: ask right away.
          if (driverWanted.isEmpty) again = true;
          if (mounted) setState(() {});
        } catch (e) {
          debugPrint('[Map] Street lines failed: $e');
          _roads.failed(batch, DateTime.now().toUtc());
        }
      }
      for (final e in driverWanted.entries) {
        final road = _roads.road(e.value.$1, e.value.$2);
        if (road != null) _driverRoads[e.key] = (to: e.value.$2, points: road);
      }
      if (mounted) setState(() {});
    } finally {
      _roadsBusy = false;
    }
    if (again && mounted) unawaited(_ensureRoads());
  }

  /// One instance, so unchanged dashed lines compare equal and aren't re-sent to the map.
  static final List<gmaps.PatternItem> _dashed = [gmaps.PatternItem.dash(14), gmaps.PatternItem.gap(8)];

  Set<gmaps.Polyline> _googleLines(List<DriverBoard> boards) => {
        for (final l in _tourLines(boards))
          gmaps.Polyline(
            polylineId: gmaps.PolylineId(l.id),
            points: [for (final p in l.points) gmaps.LatLng(p.lat, p.lng)],
            color: l.color.withValues(alpha: l.dim ? 0.2 : (l.live ? 0.85 : 0.45)),
            width: l.live ? 5 : 3,
            zIndex: l.live ? 2 : 1,
            patterns: l.live ? const [] : _dashed,
            jointType: gmaps.JointType.round,
            startCap: gmaps.Cap.roundCap,
            endCap: gmaps.Cap.roundCap,
          ),
      };

  // ═══════════════════════════════════════════════════════════════════════════
  // Build
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final boards = _boards();
    final waiting = _waiting();

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('Map'),
        actions: [
          IconButton(
            tooltip: 'Show everyone',
            icon: const Icon(Icons.zoom_out_map_rounded),
            onPressed: () {
              setState(() {
                _selectedDriverId = null;
                _selectedStopKey = null;
              });
              _refreshMarkers();
              _fitAll();
            },
          ),
          TextButton.icon(
            onPressed: _planning ? null : _replan,
            icon: _planning
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.autorenew_rounded, size: 20),
            label: Text(_planning ? 'Planning…' : 'Re-plan'),
          ),
          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (v) {
              switch (v) {
                case 'drivers':
                  _showManageDrivers();
                case 'settings':
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const DeliverySettingsScreen()));
                case 'gps':
                  _showAllDriversCoordinateLogsDialog();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'drivers', child: _MenuRow(icon: Icons.people_outline_rounded, text: 'Manage drivers')),
              PopupMenuItem(value: 'settings', child: _MenuRow(icon: Icons.tune_rounded, text: 'Planner settings')),
              PopupMenuItem(value: 'gps', child: _MenuRow(icon: Icons.gps_fixed_rounded, text: 'GPS log')),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, c) {
          Widget panel({ScrollController? controller, Widget? header}) => TourPanel(
                boards: boards,
                waiting: waiting,
                ordersById: _ordersById,
                now: _now,
                selectedDriverId: _selectedDriverId,
                selectedStopId: _selectedStopKey,
                loading: !_driversLoaded || !_toursLoaded,
                planning: _planning,
                problem: _toursProblem ?? _driversProblem,
                scrollController: controller,
                header: header,
                onDriverTap: _selectDriver,
                onStopTap: _selectStop,
                onOrderDetails: _openOrder,
                onCall: _call,
                onStartTour: _startTour,
                onMoveStop: _moveStop,
                onPlanNow: _replan,
              );

          if (c.maxWidth >= _wideLayoutFrom) {
            final panelWidth = (c.maxWidth * 0.38).clamp(340.0, 440.0);
            return Row(
              children: [
                SizedBox(width: panelWidth, child: ColoredBox(color: const Color(0xFFF9FAFB), child: panel())),
                const VerticalDivider(width: 1),
                Expanded(child: _buildMap(boards, bottomPadding: 0)),
              ],
            );
          }

          // Phones and narrow windows.
          if (kIsWeb) {
            // Flutter widgets drawn over the web map do not get taps, so stack them instead.
            return Column(
              children: [
                SizedBox(height: c.maxHeight * 0.42, child: _buildMap(boards, bottomPadding: 0)),
                const Divider(height: 1),
                Expanded(child: panel()),
              ],
            );
          }
          return Stack(
            children: [
              Positioned.fill(child: _buildMap(boards, bottomPadding: c.maxHeight * _sheetStart)),
              DraggableScrollableSheet(
                initialChildSize: _sheetStart,
                minChildSize: 0.16,
                maxChildSize: 0.94,
                snap: true,
                snapSizes: const [0.16, _sheetStart, 0.94],
                builder: (context, controller) => Material(
                  color: const Color(0xFFF9FAFB),
                  elevation: 8,
                  shadowColor: Colors.black26,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  clipBehavior: Clip.antiAlias,
                  child: panel(controller: controller, header: const _SheetHandle()),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMap(List<DriverBoard> boards, {required double bottomPadding}) {
    if (isDesktopPlatform) return _buildDesktopMap(boards);
    final map = _buildGoogleMap(boards, bottomPadding);
    if (!kIsWeb) return map;
    // On the web the map's HTML element swallows clicks meant for menus, dialogs and sheets
    // drawn over it. While one is open, cover the map with an interceptor.
    final covered = !(ModalRoute.of(context)?.isCurrent ?? true);
    return Stack(
      children: [
        Positioned.fill(child: map),
        if (covered) Positioned.fill(child: PointerInterceptor(child: const SizedBox.expand())),
      ],
    );
  }

  /// Google Maps on phones and the web.
  Widget _buildGoogleMap(List<DriverBoard> boards, double bottomPadding) {
    final lines = _googleLines(boards);
    return ValueListenableBuilder<Set<gmaps.Marker>>(
      valueListenable: _staticMarkers,
      builder: (context, statics, _) => ValueListenableBuilder<Map<String, gmaps.LatLng>>(
        valueListenable: _driverPos,
        builder: (context, positions, _) => gmaps.GoogleMap(
          onMapCreated: (controller) {
            _gmap = controller;
            _maybeFitOnce();
          },
          initialCameraPosition: gmaps.CameraPosition(target: gmaps.LatLng(_settings.store.lat, _settings.store.lng), zoom: 13),
          style: kCleanMapStyle,
          markers: {...statics, ..._driverMarkers(boards, positions)},
          polylines: lines,
          padding: EdgeInsets.only(bottom: bottomPadding),
          zoomControlsEnabled: kIsWeb,
          mapToolbarEnabled: false,
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
          compassEnabled: false,
          onTap: (_) {
            if (_selectedDriverId == null && _selectedStopKey == null) return;
            setState(() {
              _selectedDriverId = null;
              _selectedStopKey = null;
            });
            _refreshMarkers();
          },
        ),
      ),
    );
  }

  /// OpenStreetMap on macOS/Windows/Linux, with widget markers.
  Widget _buildDesktopMap(List<DriverBoard> boards) {
    final store = latlong.LatLng(_settings.store.lat, _settings.store.lng);
    final markers = <fmap.Marker>[];

    for (final b in boards) {
      final color = driverColor(b.colorIndex);
      final dim = _selectedDriverId != null && _selectedDriverId != b.driverId;
      var number = 0;
      for (final tour in [if (b.current != null) b.current!, ...b.upcoming]) {
        for (var i = 0; i < tour.stops.length; i++) {
          final s = tour.stops[i];
          final n = ++number;
          if (s.point == null) continue;
          final labelled = !s.isDone && s.eta != null;
          const labelledWidth = 190.0;
          final dot = _StopDot(
            number: n,
            color: color,
            done: s.isDone,
            filled: tour.live && !s.isDone,
            selected: s.key == _selectedStopKey,
          );
          markers.add(fmap.Marker(
            point: latlong.LatLng(s.point!.lat, s.point!.lng),
            width: labelled ? labelledWidth : 30,
            height: 30,
            // Keep the dot (not the label) on the address.
            alignment: labelled ? const Alignment(1 - 30 / labelledWidth, 0) : null,
            child: Opacity(
              opacity: dim ? 0.45 : 1,
              child: Tooltip(
                message: '$n. ${s.name} · ${s.isDone ? 'delivered ${clock(s.deliveredAt)}' : '~${clock(s.eta)}'}',
                child: GestureDetector(
                  onTap: () => _selectStop(b, s),
                  child: !labelled
                      ? dot
                      : Align(
                          alignment: Alignment.centerLeft,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(width: 30, height: 30, child: dot),
                              const SizedBox(width: 3),
                              _TimeLabel(
                                time: clock(s.eta),
                                name: s.name.trim().split(RegExp(r'\s+')).first,
                                late: s.punctuality == Punctuality.late,
                                color: color,
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ),
          ));
        }
      }
    }
    for (final o in _waiting()) {
      final lat = (o['delivery_latitude'] as num?)?.toDouble();
      final lng = (o['delivery_longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;
      markers.add(fmap.Marker(
        point: latlong.LatLng(lat, lng),
        width: 30,
        height: 30,
        child: GestureDetector(
          onTap: () => _openOrder(o['id'] as String),
          child: const _StopDot(icon: Icons.hourglass_top_rounded, color: Color(0xFFD97706), filled: true),
        ),
      ));
    }
    markers.add(fmap.Marker(
      point: store,
      width: 40,
      height: 40,
      child: const Tooltip(
        message: 'Restaurant · $_restaurantAddress',
        child: _StopDot(icon: Icons.storefront_rounded, color: Color(0xFF111827), filled: true, size: 36),
      ),
    ));
    return ValueListenableBuilder<Map<String, gmaps.LatLng>>(
      valueListenable: _driverPos,
      builder: (context, positions, _) {
        final drivers = [
          for (final b in _driversOnMap(boards))
            fmap.Marker(
              point: () {
                final p = positions[b.driverId];
                return p != null ? latlong.LatLng(p.latitude, p.longitude) : latlong.LatLng(b.position!.lat, b.position!.lng);
              }(),
              width: 96,
              height: 60,
              child: GestureDetector(
                onTap: () => _selectDriver(b),
                child: _DriverBadge(name: b.name, color: b.gpsFresh(_now) ? driverColor(b.colorIndex) : const Color(0xFF9CA3AF)),
              ),
            ),
        ];
        return fmap.FlutterMap(
          mapController: _fmap,
          options: fmap.MapOptions(
            initialCenter: store,
            initialZoom: 13,
            onMapReady: () {
              _fmapReady = true;
              _maybeFitOnce();
            },
          ),
          children: [
            fmap.TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.restaurantadmin.app',
            ),
            fmap.PolylineLayer(polylines: [
              for (final l in _tourLines(boards))
                fmap.Polyline(
                  points: [for (final p in l.points) latlong.LatLng(p.lat, p.lng)],
                  color: l.color.withValues(alpha: l.dim ? 0.2 : (l.live ? 0.85 : 0.45)),
                  strokeWidth: l.live ? 5 : 3,
                  isDotted: !l.live,
                ),
            ]),
            fmap.MarkerLayer(markers: [...markers, ...drivers]),
          ],
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Drivers: manage, info
  // ═══════════════════════════════════════════════════════════════════════════

  void _showManageDrivers() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text('Drivers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showAddDriverDialog();
                      },
                      icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                      label: const Text('Add driver'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: _drivers.isEmpty
                    ? const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No drivers yet')))
                    : ListView(
                        shrinkWrap: true,
                        children: [
                          for (final d in _drivers)
                            ListTile(
                              leading: CircleAvatar(
                                backgroundColor: d.isOnline ? driverColor(_colorOf(d.id)) : const Color(0xFF9CA3AF),
                                child: Text(
                                  d.name.isNotEmpty ? d.name[0].toUpperCase() : '?',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                                ),
                              ),
                              title: Text(d.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                !d.isOnline
                                    ? 'Offline'
                                    : _isLocationStale(d.lastSeenAt)
                                        ? 'Online · no GPS signal (${_formatLastSeen(d.lastSeenAt)})'
                                        : 'Online · GPS ${_formatLastSeen(d.lastSeenAt).toLowerCase()}',
                              ),
                              onTap: () {
                                Navigator.pop(ctx);
                                _showDriverInfoDialog(d);
                              },
                              trailing: IconButton(
                                tooltip: 'Delete driver',
                                icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626)),
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _deleteDriver(d);
                                },
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _driverColorFor(app_driver_model.Driver d) => driverColor(_colorOf(d.id));

  Future<void> _addDriver(String name, String email, String password) async {
    if (!mounted) return;

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 16),
                  Text('Creating driver account...'),
                ],
              ),
            ),
          ),
        ),
      );

      // 1. Create auth user using Supabase Auth Admin API (via Edge Function)
      // Since we can't use admin.createUser from client, we'll use signUp
      // Note: This will send a confirmation email. For production, you may want
      // to use an Edge Function with service role key.

      final authResponse = await widget.supabaseClient.auth.signUp(
        email: email,
        password: password,
        data: {'name': name, 'role': 'driver'},
      );

      if (authResponse.user == null) {
        throw Exception('Failed to create user account');
      }

      final userId = authResponse.user!.id;

      // 2. Create worker profile
      await widget.supabaseClient.from('worker_profiles').upsert({
        'id': userId,
        'email': email,
        'role': 'driver',
        'display_name': name,
      });

      // 3. Create driver record
      await widget.supabaseClient.from('drivers').insert({
        'user_id': userId,
        'name': name,
        'is_online': false,
      });

      if (mounted) {
        Navigator.pop(context); // Close loading dialog

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Driver "$name" created successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        _loadDrivers();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog

        String errorMessage = e.toString();
        if (errorMessage.contains('User already registered')) {
          errorMessage = 'A user with this email already exists';
        }

        _showCopyableError('Error creating driver: $errorMessage');
      }
      print('[DeliveryMonitorScreen] Error adding driver: $e');
    }
  }

  Future<void> _deleteDriver(app_driver_model.Driver driver) async {
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Driver'),
        content: Text(
          'Are you sure you want to delete driver "${driver.name}"?\n\nThis will remove the driver record but keep their user account.',
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

    if (confirmed != true) return;

    try {
      print(
        '[DeliveryMonitorScreen] Attempting to delete driver: ${driver.id} (${driver.name})',
      );

      // First verify the driver exists
      final existsCheck = await widget.supabaseClient
          .from('drivers')
          .select('id')
          .eq('id', driver.id)
          .maybeSingle();

      if (existsCheck == null) {
        print(
          '[DeliveryMonitorScreen] Driver not found in database: ${driver.id}',
        );
        if (mounted) {
          _showCopyableError(
            'Driver not found in database. It may have already been deleted.',
          );
          await _loadDrivers();
        }
        return;
      }

      // Delete driver record using select to get affected rows
      final deleteResponse = await widget.supabaseClient
          .from('drivers')
          .delete()
          .eq('id', driver.id)
          .select();

      print('[DeliveryMonitorScreen] Delete response: $deleteResponse');

      // Check if deletion was successful
      if (deleteResponse.isEmpty) {
        // Deletion might have failed due to RLS policies
        // Try to verify if driver still exists
        final stillExists = await widget.supabaseClient
            .from('drivers')
            .select('id')
            .eq('id', driver.id)
            .maybeSingle();

        if (stillExists != null) {
          throw Exception(
            'Failed to delete driver. Check database permissions (RLS policies).',
          );
        }
      }

      // Optionally update worker profile role
      if (driver.userId != null) {
        try {
          await widget.supabaseClient
              .from('worker_profiles')
              .update({'role': 'none'})
              .eq('id', driver.userId!);
        } catch (e) {
          print('[DeliveryMonitorScreen] Worker profile update skipped: $e');
          // Worker profile may not exist - not critical
        }
      }

      if (mounted) {
        // Immediately remove from local list for instant UI feedback
        setState(() {
          _drivers.removeWhere((d) => d.id == driver.id);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Driver "${driver.name}" deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Also refresh from database to ensure consistency
        await _loadDrivers();
      }
    } catch (e) {
      print('[DeliveryMonitorScreen] Error deleting driver: $e');
      if (mounted) {
        _showCopyableError('Error deleting driver: $e');
        // Refresh to restore the list if delete failed
        await _loadDrivers();
      }
    }
  }

  void _showAddDriverDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    bool obscurePassword = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.person_add, color: Colors.blue[600]),
              const SizedBox(width: 8),
              const Text('Add New Driver'),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Create a new driver account. The driver will use these credentials to log in to the Driver App.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 20),

                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Driver Name',
                    hintText: 'Enter driver\'s full name',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: emailController,
                  decoration: InputDecoration(
                    labelText: 'Email (Username)',
                    hintText: 'driver@example.com',
                    prefixIcon: const Icon(Icons.email),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: 'Minimum 6 characters',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () => setDialogState(
                        () => obscurePassword = !obscurePassword,
                      ),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue[700],
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'The driver will use this email and password to log in.',
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final name = nameController.text.trim();
                final email = emailController.text.trim();
                final password = passwordController.text;

                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a name'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                if (email.isEmpty || !email.contains('@')) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid email'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                if (password.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Password must be at least 6 characters'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                Navigator.pop(ctx);
                _addDriver(name, email, password);
              },
              icon: const Icon(Icons.add),
              label: const Text('Create Driver'),
            ),
          ],
        ),
      ),
    );
  }

  /// Check if driver location is stale (more than 2 minutes old).
  /// Uses a 2-minute window to account for network delays and timer intervals.
  bool _isLocationStale(DateTime? lastSeenAt) {
    if (lastSeenAt == null) return true;
    
    // Ensure consistent UTC comparison
    final now = DateTime.now().toUtc();
    final lastSeen = lastSeenAt.isUtc ? lastSeenAt : lastSeenAt.toUtc();
    final difference = now.difference(lastSeen);
    
    return difference.inSeconds > 120; // Stale if > 2 minutes
  }

  /// Format last seen time for display
  String _formatLastSeen(DateTime? lastSeenAt) {
    if (lastSeenAt == null) return 'Never updated';
    
    // Ensure consistent UTC comparison
    final now = DateTime.now().toUtc();
    final lastSeen = lastSeenAt.isUtc ? lastSeenAt : lastSeenAt.toUtc();
    final difference = now.difference(lastSeen);
    
    // Handle negative values (clock skew)
    final seconds = difference.inSeconds.abs();
    
    if (seconds < 15) {
      return 'Just now';
    } else if (seconds < 60) {
      return '${seconds}s ago';
    } else if (difference.inMinutes.abs() < 60) {
      return '${difference.inMinutes.abs()}m ago';
    } else if (difference.inHours.abs() < 24) {
      return '${difference.inHours.abs()}h ago';
    } else {
      return '${difference.inDays.abs()}d ago';
    }
  }

  /// Show clean driver info dialog
  void _showDriverInfoDialog(app_driver_model.Driver driver) {
    if (!mounted) return;
    
    final Color driverColor = _driverColorFor(driver);
    final bool isStale = _isLocationStale(driver.lastSeenAt);
    final String lastSeenText = _formatLastSeen(driver.lastSeenAt);
    
    // Format last seen timestamp
    String lastUpdateTime = 'Never';
    if (driver.lastSeenAt != null) {
      final local = driver.lastSeenAt!.toLocal();
      lastUpdateTime = '${local.hour.toString().padLeft(2, '0')}:'
                       '${local.minute.toString().padLeft(2, '0')}:'
                       '${local.second.toString().padLeft(2, '0')}';
    }
    
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Driver avatar with color
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: isStale ? Colors.grey : driverColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (isStale ? Colors.grey : driverColor).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.directions_car,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),
              
              // Driver name
              Text(
                driver.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              
              // Online/Offline Status indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: driver.isOnline ? Colors.green[50] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: driver.isOnline ? Colors.green[300]! : Colors.grey[300]!,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: driver.isOnline ? Colors.green : Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      driver.isOnline ? 'Online' : 'Offline',
                      style: TextStyle(
                        color: driver.isOnline ? Colors.green[700] : Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Info section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  children: [
                    // Last Updated
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 18,
                          color: isStale ? Colors.orange[700] : Colors.grey[600],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Last Updated:',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isStale ? Colors.orange[100] : Colors.green[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            lastSeenText,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isStale ? Colors.orange[800] : Colors.green[800],
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 10),
                    
                    // Update Time
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 18, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text(
                          'Update Time:',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                        const Spacer(),
                        Text(
                          lastUpdateTime,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'monospace',
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                    
                    if (driver.currentLocation != null) ...[
                      const SizedBox(height: 10),
                      const Divider(height: 1),
                      const SizedBox(height: 10),
                      
                      // Current Coordinates
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 18, color: Colors.blue[600]),
                          const SizedBox(width: 8),
                          Text(
                            'Coordinates:',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${driver.currentLocation!.latitude.toStringAsFixed(6)}, '
                          '${driver.currentLocation!.longitude.toStringAsFixed(6)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[800],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              if (isStale) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Location may be outdated',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 20),
              
              // View Coordinates button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: driverColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showCoordinateHistoryDialog(driver);
                  },
                  icon: const Icon(Icons.history, size: 18),
                  label: const Text('View Live Updates'),
                ),
              ),
              
              const SizedBox(height: 10),
              
              // Close button
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.grey[100],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show real-time coordinate history for a driver
  void _showCoordinateHistoryDialog(app_driver_model.Driver driver) {
    if (!mounted) return;
    
    final Color driverColor = _driverColorFor(driver);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _CoordinateHistoryDialog(
        driver: driver,
        driverColor: driverColor,
        supabaseClient: widget.supabaseClient,
      ),
    );
  }

  /// Show all drivers' coordinate logs dialog
  void _showAllDriversCoordinateLogsDialog() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _AllDriversCoordinateLogsDialog(
        colorFor: _driverColorFor,
        allDrivers: _drivers,
        onlineDrivers: _drivers.where((d) => d.isOnline).toList(),
        supabaseClient: widget.supabaseClient,
      ),
    );
  }

  void _showOrderDetailsBottomSheet(app_order.Order order) {
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
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
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.orange[600]!, Colors.orange[400]!],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.delivery_dining,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order #${order.dailyOrderNumber ?? order.id?.substring(0, 8) ?? "N/A"}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(order.status),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            order.status.replaceAll('_', ' ').toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '€${order.totalPrice.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                ],
              ),

              const Divider(height: 32),

              // Customer Info
              Row(
                children: [
                  Icon(Icons.person, color: Colors.blue[600], size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Customer',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        Text(
                          order.customerName ?? 'Unknown',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Address
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.location_on, color: Colors.red[600], size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Delivery Address',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        Text(
                          order.customerStreet ?? 'No street',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (order.customerPostcode != null ||
                            order.customerCity != null)
                          Text(
                            '${order.customerPostcode ?? ''} ${order.customerCity ?? ''}'
                                .trim(),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Payment Method
              Row(
                children: [
                  Icon(Icons.payment, color: Colors.purple[600], size: 20),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Payment Method',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        order.paymentMethod.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Close button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[200],
                    foregroundColor: Colors.grey[800],
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange[600]!;
      case 'confirmed':
        return Colors.blue[600]!;
      case 'preparing':
        return Colors.purple[600]!;
      case 'ready':
      case 'ready_to_deliver':
        return Colors.teal[600]!;
      case 'out_for_delivery':
        return Colors.indigo[600]!;
      case 'delivered':
        return Colors.green[700]!;
      default:
        return Colors.grey[600]!;
    }
  }

  void _showCopyableError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: '📋 COPY',
          textColor: Colors.white,
          onPressed: () {
            Clipboard.setData(ClipboardData(text: message));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✓ Error copied to clipboard'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small widgets
// ─────────────────────────────────────────────────────────────────────────────

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MenuRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(children: [Icon(icon, size: 20, color: const Color(0xFF6B7280)), const SizedBox(width: 12), Text(text)]);
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 10, bottom: 2),
        width: 40,
        height: 4,
        decoration: BoxDecoration(color: const Color(0xFFD1D5DB), borderRadius: BorderRadius.circular(2)),
      ),
    );
  }
}

/// Desktop map marker for a stop, the restaurant or a waiting order.
class _StopDot extends StatelessWidget {
  final int? number;
  final IconData? icon;
  final Color color;
  final bool done;
  final bool filled;
  final bool selected;
  final double size;

  const _StopDot({
    this.number,
    this.icon,
    required this.color,
    this.done = false,
    this.filled = false,
    this.selected = false,
    this.size = 26,
  });

  @override
  Widget build(BuildContext context) {
    final fill = done ? const Color(0xFF9CA3AF) : (filled ? color : Colors.white);
    final fg = done || filled ? Colors.white : color;
    return Center(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: fill,
          shape: BoxShape.circle,
          border: Border.all(color: selected ? const Color(0xFF111827) : (filled || done ? Colors.white : color), width: selected ? 3 : 2),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 1))],
        ),
        child: Center(
          child: done
              ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
              : icon != null
                  ? Icon(icon, size: size * 0.55, color: fg)
                  : Text('$number', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: fg)),
        ),
      ),
    );
  }
}

/// Desktop map label next to a stop: arrival time and first name.
class _TimeLabel extends StatelessWidget {
  final String time;
  final String name;
  final bool late;
  final Color color;
  const _TimeLabel({required this.time, required this.name, required this.late, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 1))],
      ),
      child: Text.rich(
        TextSpan(children: [
          TextSpan(
            text: time,
            style: TextStyle(fontWeight: FontWeight.w800, color: late ? const Color(0xFFDC2626) : const Color(0xFF111827)),
          ),
          TextSpan(text: '  $name', style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF4B5563))),
        ]),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }
}

/// Desktop map marker for a driver: badge with the initial and the name.
class _DriverBadge extends StatelessWidget {
  final String name;
  final Color color;
  const _DriverBadge({required this.name, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
          ),
          child: Center(
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
            ),
          ),
        ),
        const SizedBox(height: 3),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
          child: Text(name, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

/// Parse a timestamp string from Supabase, ensuring it's treated as UTC.
/// Supabase often returns UTC timestamps without the 'Z' suffix, causing
/// Dart's DateTime.tryParse to treat them as local time.
DateTime? _parseUtcTimestamp(String? s) {
  if (s == null || s.isEmpty) return null;
  final dt = DateTime.tryParse(s);
  if (dt == null) return null;
  return dt.isUtc
      ? dt
      : DateTime.utc(dt.year, dt.month, dt.day, dt.hour, dt.minute,
          dt.second, dt.millisecond, dt.microsecond);
}

/// Model for coordinate update entry
class _CoordinateUpdate {
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  
  _CoordinateUpdate({
    required this.timestamp,
    required this.latitude,
    required this.longitude,
  });
}

/// Dialog showing real-time coordinate updates for a driver
class _CoordinateHistoryDialog extends StatefulWidget {
  final app_driver_model.Driver driver;
  final Color driverColor;
  final SupabaseClient supabaseClient;
  
  const _CoordinateHistoryDialog({
    required this.driver,
    required this.driverColor,
    required this.supabaseClient,
  });
  
  @override
  State<_CoordinateHistoryDialog> createState() => _CoordinateHistoryDialogState();
}

class _CoordinateHistoryDialogState extends State<_CoordinateHistoryDialog> {
  final List<_CoordinateUpdate> _updates = [];
  final ScrollController _scrollController = ScrollController();
  RealtimeChannel? _subscription;
  Timer? _pollingTimer;
  bool _isListening = true;
  
  @override
  void initState() {
    super.initState();
    _addInitialUpdate();
    _setupRealtimeSubscription();
    _startPolling();
  }
  
  @override
  void dispose() {
    _subscription?.unsubscribe();
    _pollingTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }
  
  void _addInitialUpdate() {
    // Add current location as first entry
    if (widget.driver.currentLocation != null) {
      _updates.add(_CoordinateUpdate(
        timestamp: widget.driver.lastSeenAt ?? DateTime.now(),
        latitude: widget.driver.currentLocation!.latitude,
        longitude: widget.driver.currentLocation!.longitude,
      ));
    }
  }
  
  void _setupRealtimeSubscription() {
    _subscription = widget.supabaseClient
        .channel('driver_location_${widget.driver.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'drivers',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.driver.id,
          ),
          callback: (payload) {
            if (!mounted || !_isListening) return;
            
            final newData = payload.newRecord;
            final lat = newData['current_latitude'];
            final lng = newData['current_longitude'];
            final lastSeen = newData['last_seen_at'];
            
            if (lat != null && lng != null) {
              _addUpdate(
                _parseUtcTimestamp(lastSeen?.toString()) ?? DateTime.now().toUtc(),
                (lat as num).toDouble(),
                (lng as num).toDouble(),
              );
            }
          },
        )
        .subscribe();
  }
  
  void _startPolling() {
    // Poll every 5 seconds as backup
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted || !_isListening) return;
      
      try {
        final response = await widget.supabaseClient
            .from('drivers')
            .select('current_latitude, current_longitude, last_seen_at')
            .eq('id', widget.driver.id)
            .single();
        
        final lat = response['current_latitude'];
        final lng = response['current_longitude'];
        final lastSeen = response['last_seen_at'];
        
        if (lat != null && lng != null && mounted) {
          final timestamp = _parseUtcTimestamp(lastSeen?.toString()) ?? DateTime.now().toUtc();
          
          // Only add if coordinates changed
          if (_updates.isEmpty || 
              _updates.last.latitude != lat || 
              _updates.last.longitude != lng) {
            _addUpdate(timestamp, (lat as num).toDouble(), (lng as num).toDouble());
          }
        }
      } catch (e) {
        debugPrint('[CoordinateHistory] Polling error: $e');
      }
    });
  }
  
  void _addUpdate(DateTime timestamp, double lat, double lng) {
    // Check if this is a duplicate (same coordinates within 1 second)
    if (_updates.isNotEmpty) {
      final last = _updates.last;
      if (last.latitude == lat && 
          last.longitude == lng &&
          timestamp.difference(last.timestamp).inSeconds.abs() < 2) {
        return; // Skip duplicate
      }
    }
    
    setState(() {
      _updates.add(_CoordinateUpdate(
        timestamp: timestamp,
        latitude: lat,
        longitude: lng,
      ));
      
      // Keep only last 50 updates
      if (_updates.length > 50) {
        _updates.removeAt(0);
      }
    });
    
    // Auto-scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
  
  String _formatTime(DateTime time) {
    final local = time.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:'
           '${local.minute.toString().padLeft(2, '0')}:'
           '${local.second.toString().padLeft(2, '0')}';
  }
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 380,
        height: 500,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: widget.driverColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.directions_car, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.driver.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Live Coordinate Updates',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                // Live indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isListening ? Colors.green[50] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isListening ? Colors.green[300]! : Colors.grey[300]!,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _isListening ? Colors.green : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isListening ? 'LIVE' : 'PAUSED',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _isListening ? Colors.green[700] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Column headers
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 80,
                    child: Text(
                      'TIME',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'COORDINATES (LAT, LNG)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Updates list
            Expanded(
              child: _updates.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.hourglass_empty, size: 40, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Text(
                            'Waiting for location updates...',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount: _updates.length,
                      itemBuilder: (context, index) {
                        final update = _updates[index];
                        final isLatest = index == _updates.length - 1;
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isLatest ? widget.driverColor.withOpacity(0.1) : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isLatest ? widget.driverColor.withOpacity(0.3) : Colors.grey[200]!,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Time
                              SizedBox(
                                width: 70,
                                child: Text(
                                  _formatTime(update.timestamp),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isLatest ? FontWeight.bold : FontWeight.normal,
                                    fontFamily: 'monospace',
                                    color: isLatest ? widget.driverColor : Colors.grey[800],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Coordinates
                              Expanded(
                                child: Text(
                                  '${update.latitude.toStringAsFixed(6)}, ${update.longitude.toStringAsFixed(6)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                    color: isLatest ? Colors.black : Colors.grey[700],
                                  ),
                                ),
                              ),
                              // Latest badge
                              if (isLatest)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: widget.driverColor,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'NEW',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            
            const SizedBox(height: 12),
            
            // Footer with count and controls
            Row(
              children: [
                Text(
                  '${_updates.length} updates',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const Spacer(),
                // Pause/Resume button
                TextButton.icon(
                  onPressed: () {
                    setState(() => _isListening = !_isListening);
                  },
                  icon: Icon(
                    _isListening ? Icons.pause : Icons.play_arrow,
                    size: 18,
                  ),
                  label: Text(_isListening ? 'Pause' : 'Resume'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                  ),
                ),
                const SizedBox(width: 8),
                // Close button
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[200],
                    foregroundColor: Colors.grey[800],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog showing coordinate logs for ALL drivers
class _AllDriversCoordinateLogsDialog extends StatefulWidget {
  final List<app_driver_model.Driver> allDrivers;
  final List<app_driver_model.Driver> onlineDrivers;
  final SupabaseClient supabaseClient;
  
  final Color Function(app_driver_model.Driver driver) colorFor;

  const _AllDriversCoordinateLogsDialog({
    required this.colorFor,
    required this.allDrivers,
    required this.onlineDrivers,
    required this.supabaseClient,
  });
  
  @override
  State<_AllDriversCoordinateLogsDialog> createState() => _AllDriversCoordinateLogsDialogState();
}

class _AllDriversCoordinateLogsDialogState extends State<_AllDriversCoordinateLogsDialog> {
  // Map of driver ID to list of coordinate updates
  final Map<String, List<_CoordinateUpdate>> _driverUpdates = {};
  final Map<String, ScrollController> _scrollControllers = {};
  RealtimeChannel? _subscription;
  Timer? _pollingTimer;
  bool _isListening = true;
  String? _selectedDriverId;
  
  @override
  void initState() {
    super.initState();
    _initializeDrivers();
    _setupRealtimeSubscription();
    _startPolling();
  }
  
  @override
  void dispose() {
    _subscription?.unsubscribe();
    _pollingTimer?.cancel();
    for (var controller in _scrollControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
  
  void _initializeDrivers() {
    // Initialize with current positions for all drivers
    for (var driver in widget.allDrivers) {
      _driverUpdates[driver.id] = [];
      _scrollControllers[driver.id] = ScrollController();
      
      if (driver.currentLocation != null) {
        _driverUpdates[driver.id]!.add(_CoordinateUpdate(
          timestamp: driver.lastSeenAt ?? DateTime.now(),
          latitude: driver.currentLocation!.latitude,
          longitude: driver.currentLocation!.longitude,
        ));
      }
    }
    
    // Select first online driver by default, or first driver
    if (widget.onlineDrivers.isNotEmpty) {
      _selectedDriverId = widget.onlineDrivers.first.id;
    } else if (widget.allDrivers.isNotEmpty) {
      _selectedDriverId = widget.allDrivers.first.id;
    }
  }
  
  void _setupRealtimeSubscription() {
    _subscription = widget.supabaseClient
        .channel('all_drivers_location')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'drivers',
          callback: (payload) {
            if (!mounted || !_isListening) return;
            
            final newData = payload.newRecord;
            final driverId = newData['id']?.toString();
            final lat = newData['current_latitude'];
            final lng = newData['current_longitude'];
            final lastSeen = newData['last_seen_at'];
            
            if (driverId != null && lat != null && lng != null) {
              _addUpdateForDriver(
                driverId,
                _parseUtcTimestamp(lastSeen?.toString()) ?? DateTime.now().toUtc(),
                (lat as num).toDouble(),
                (lng as num).toDouble(),
              );
            }
          },
        )
        .subscribe();
  }
  
  void _startPolling() {
    // Poll every 5 seconds as backup
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted || !_isListening) return;
      
      try {
        final response = await widget.supabaseClient
            .from('drivers')
            .select('id, current_latitude, current_longitude, last_seen_at');
        
        for (var driverData in (response as List)) {
          final driverId = driverData['id']?.toString();
          final lat = driverData['current_latitude'];
          final lng = driverData['current_longitude'];
          final lastSeen = driverData['last_seen_at'];
          
          if (driverId != null && lat != null && lng != null && mounted) {
            final timestamp = _parseUtcTimestamp(lastSeen?.toString()) ?? DateTime.now().toUtc();
            final updates = _driverUpdates[driverId];
            
            // Only add if coordinates changed
            if (updates == null || 
                updates.isEmpty || 
                updates.last.latitude != lat || 
                updates.last.longitude != lng) {
              _addUpdateForDriver(driverId, timestamp, (lat as num).toDouble(), (lng as num).toDouble());
            }
          }
        }
      } catch (e) {
        debugPrint('[AllDriversCoordinateLogs] Polling error: $e');
      }
    });
  }
  
  void _addUpdateForDriver(String driverId, DateTime timestamp, double lat, double lng) {
    if (!_driverUpdates.containsKey(driverId)) {
      _driverUpdates[driverId] = [];
      _scrollControllers[driverId] = ScrollController();
    }
    
    final updates = _driverUpdates[driverId]!;
    
    // Check if this is a duplicate
    if (updates.isNotEmpty) {
      final last = updates.last;
      if (last.latitude == lat && 
          last.longitude == lng &&
          timestamp.difference(last.timestamp).inSeconds.abs() < 2) {
        return;
      }
    }
    
    setState(() {
      updates.add(_CoordinateUpdate(
        timestamp: timestamp,
        latitude: lat,
        longitude: lng,
      ));
      
      // Keep only last 100 updates per driver
      if (updates.length > 100) {
        updates.removeAt(0);
      }
    });
    
    // Auto-scroll if this driver is selected
    if (_selectedDriverId == driverId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final controller = _scrollControllers[driverId];
        if (controller != null && controller.hasClients) {
          controller.animateTo(
            controller.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }
  
  String _formatTime(DateTime time) {
    final local = time.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:'
           '${local.minute.toString().padLeft(2, '0')}:'
           '${local.second.toString().padLeft(2, '0')}';
  }
  
  app_driver_model.Driver? _getDriverById(String? id) {
    if (id == null) return null;
    try {
      return widget.allDrivers.firstWhere((d) => d.id == id);
    } catch (_) {
      return null;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final selectedDriver = _getDriverById(_selectedDriverId);
    final selectedUpdates = _selectedDriverId != null 
        ? (_driverUpdates[_selectedDriverId] ?? []) 
        : <_CoordinateUpdate>[];
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        height: 600,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.blue[600],
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.gps_fixed, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Coordinate Updates',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Live location logs for all drivers',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                // Live indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isListening ? Colors.green[50] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isListening ? Colors.green[300]! : Colors.grey[300]!,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _isListening ? Colors.green : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isListening ? 'LIVE' : 'PAUSED',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _isListening ? Colors.green[700] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Driver selector
            Container(
              height: 50,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                itemCount: widget.allDrivers.length,
                itemBuilder: (context, index) {
                  final driver = widget.allDrivers[index];
                  final isSelected = driver.id == _selectedDriverId;
                  final isOnline = driver.isOnline;
                  final updateCount = _driverUpdates[driver.id]?.length ?? 0;
                  final driverColor = widget.colorFor(driver);
                  
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: () => setState(() => _selectedDriverId = driver.id),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? driverColor : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? driverColor : Colors.grey[300]!,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: isOnline 
                                    ? (isSelected ? Colors.white : Colors.green)
                                    : (isSelected ? Colors.white54 : Colors.grey),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              driver.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? Colors.white : Colors.grey[800],
                              ),
                            ),
                            if (updateCount > 0) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.white24 : Colors.grey[200],
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$updateCount',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? Colors.white : Colors.grey[600],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Column headers
            if (selectedDriver != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: Text(
                        'TIME',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'COORDINATES (LAT, LNG)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            
            const SizedBox(height: 8),
            
            // Updates list
            Expanded(
              child: selectedDriver == null
                  ? Center(
                      child: Text(
                        'No drivers available',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    )
                  : selectedUpdates.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.hourglass_empty, size: 40, color: Colors.grey[400]),
                              const SizedBox(height: 8),
                              Text(
                                'Waiting for location updates from ${selectedDriver.name}...',
                                style: TextStyle(color: Colors.grey[600]),
                                textAlign: TextAlign.center,
                              ),
                              if (!selectedDriver.isOnline) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.orange[50],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Driver is currently offline',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.orange[700],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollControllers[_selectedDriverId],
                          itemCount: selectedUpdates.length,
                          itemBuilder: (context, index) {
                            final update = selectedUpdates[index];
                            final isLatest = index == selectedUpdates.length - 1;
                            final driverColor = widget.colorFor(selectedDriver);
                            
                            return Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: isLatest ? driverColor.withOpacity(0.1) : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isLatest ? driverColor.withOpacity(0.3) : Colors.grey[200]!,
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Time
                                  SizedBox(
                                    width: 70,
                                    child: Text(
                                      _formatTime(update.timestamp),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isLatest ? FontWeight.bold : FontWeight.normal,
                                        fontFamily: 'monospace',
                                        color: isLatest ? driverColor : Colors.grey[800],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Coordinates
                                  Expanded(
                                    child: Text(
                                      '${update.latitude.toStringAsFixed(6)}, ${update.longitude.toStringAsFixed(6)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontFamily: 'monospace',
                                        color: isLatest ? Colors.black : Colors.grey[700],
                                      ),
                                    ),
                                  ),
                                  // Latest badge
                                  if (isLatest)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: driverColor,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'NEW',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
            
            const SizedBox(height: 12),
            
            // Footer with controls
            Row(
              children: [
                if (selectedDriver != null)
                  Text(
                    '${selectedUpdates.length} updates for ${selectedDriver.name}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                const Spacer(),
                // Pause/Resume button
                TextButton.icon(
                  onPressed: () {
                    setState(() => _isListening = !_isListening);
                  },
                  icon: Icon(
                    _isListening ? Icons.pause : Icons.play_arrow,
                    size: 18,
                  ),
                  label: Text(_isListening ? 'Pause' : 'Resume'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                  ),
                ),
                const SizedBox(width: 8),
                // Close button
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[200],
                    foregroundColor: Colors.grey[800],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
