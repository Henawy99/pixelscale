import 'package:flutter/material.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:restaurantadmin/services/active_screen_service.dart';
import 'package:restaurantadmin/services/app_nav_service.dart';

// Global stream controller for notifying OrdersScreen about new orders
class OrderNotificationService {
  static final OrderNotificationService _instance = OrderNotificationService._internal();
  factory OrderNotificationService() => _instance;
  OrderNotificationService._internal();

  final StreamController<String> _newOrderController = StreamController<String>.broadcast();
  Stream<String> get newOrderStream => _newOrderController.stream;

  void notifyNewOrder(String orderId) {
    print('[OrderNotificationService] Notifying new order: $orderId');
    _newOrderController.add(orderId);
  }

  void dispose() {
    _newOrderController.close();
  }
}

class GlobalOrderListener extends StatefulWidget {
  final Widget child;
  const GlobalOrderListener({super.key, required this.child});

  @override
  State<GlobalOrderListener> createState() => _GlobalOrderListenerState();
}

class _GlobalOrderListenerState extends State<GlobalOrderListener> {
  final SupabaseClient _supabase = Supabase.instance.client;
  StreamSubscription<List<Map<String, dynamic>>>? _ordersStream;
  RealtimeChannel? _ordersChannel;
  bool _initialized = false;
  final Set<String> _seenIds = {};
  final OrderNotificationService _notificationService = OrderNotificationService();
  Timer? _pollTimer; // Fallback for platforms where realtime is unreliable

  @override
  void initState() {
    super.initState();
    print('[GlobalOrderListener] Initializing...');
    _subscribeToOrdersStream();
    _subscribeToInsertEvents();
    _startPollingFallback();
  }

  void _subscribeToOrdersStream() {
    _ordersStream?.cancel();
    _ordersStream = _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .listen(
          (rows) async {
            if (rows.isEmpty) return;

            if (!_initialized) {
              _seenIds.addAll(
                rows
                    .map((r) => (r['id'] ?? '') as String)
                    .where((id) => id.isNotEmpty),
              );
              _initialized = true;
              return;
            }

            for (final r in rows) {
              final id = r['id'] as String?;
              if (id == null || id.isEmpty) continue;
              if (_seenIds.add(id)) {
                final tsStr = (r['scanned_date'] as String?) ?? (r['created_at'] as String?);
                DateTime? ts = tsStr != null ? DateTime.tryParse(tsStr) : null;
                final isRecent = ts == null || DateTime.now().difference(ts).inMinutes <= 10;
                if (isRecent) await _openOrderDialog(r);
              }
            }
          },
          onError: (err) {
            debugPrint('GlobalOrderListener stream error: $err');
          },
        );
  }

  void _subscribeToInsertEvents() {
    _ordersChannel?.unsubscribe();
    print('[GlobalOrderListener] Setting up channel subscription...');
    _ordersChannel = _supabase
        .channel('public:orders:insert_listener')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'orders',
          callback: (payload) async {
            print(
              '[GlobalOrderListener] INSERT event received: ${payload.newRecord}',
            );
            final rec = payload.newRecord;
            final id = rec['id'] as String?;
            final status = rec['status'] as String?;
            print('[GlobalOrderListener] Order ID: $id, Status: $status');

            if (id == null || id.isEmpty) {
              print('[GlobalOrderListener] Skipping - no ID');
              return;
            }
            if (!_seenIds.add(id)) {
              print('[GlobalOrderListener] Skipping - already seen ID: $id');
              return;
            }

            // Notify OrdersScreen immediately about the new order
            _notificationService.notifyNewOrder(id);

            final createdAtStr = rec['created_at'] as String?;
            DateTime? createdAt = createdAtStr != null
                ? DateTime.tryParse(createdAtStr)
                : null;
            final isRecent =
                createdAt == null ||
                DateTime.now().difference(createdAt).inMinutes <= 10;

            print(
              '[GlobalOrderListener] Created at: $createdAt, Is recent: $isRecent',
            );

            if (!isRecent) {
              print('[GlobalOrderListener] Skipping - not recent');
              return;
            }

            print('[GlobalOrderListener] Opening dialog for order: $id');
            await _openOrderDialog(Map<String, dynamic>.from(rec));
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'orders',
          callback: (payload) async {
            final newRec = payload.newRecord;
            final id = newRec['id'] as String?;

            // Always notify about order updates for OrdersScreen refresh
            if (id != null && id.isNotEmpty) {
              _notificationService.notifyNewOrder(id);
            }
          },
        )
        .subscribe((status, [error]) {
          print('[GlobalOrderListener] Subscription status: $status');
          if (error != null) {
            print('[GlobalOrderListener] Subscribe error: $error');
          } else {
            print(
              '[GlobalOrderListener] Successfully subscribed to orders channel',
            );
          }
        });
  }

  void _startPollingFallback() {
    // Poll every 6 seconds for the newest order and trigger if unseen
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 6), (t) async {
      try {
        final resp = await _supabase
            .from('orders')
            .select('id, created_at, status')
            .order('created_at', ascending: false)
            .limit(1);
        if (resp.isNotEmpty) {
          final Map<String, dynamic> rec = resp.first;
          final id = rec['id'] as String?;
          if (id != null && id.isNotEmpty && _seenIds.add(id)) {
            // Notify screens about new order
            _notificationService.notifyNewOrder(id);
          }
        }
      } catch (e) {
        debugPrint('[GlobalOrderListener] Polling error: $e');
      }
    });
  }

  Future<void> _openOrderDialog(Map<String, dynamic> record) async {
    // Auto-navigate to Orders tab except when DeliveryMonitor is active
    try {
      final active = ActiveScreenService();
      final blocked = active.currentTopScreen.value == 'delivery_monitor';
      if (!blocked) {
        // Set MainScreen tab to Orders via NavService notifier
        AppNavService().goToOrdersTab();
      }
    } catch (_) {}

    // Orders no longer require confirmation - just log and notify
    print('[GlobalOrderListener] _openOrderDialog called with: $record');
    final id = record['id'] as String?;
    if (id != null && id.isNotEmpty) {
      print('[GlobalOrderListener] New order detected: $id');
    }
  }

  @override
  void dispose() {
    _ordersStream?.cancel();
    _ordersChannel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
