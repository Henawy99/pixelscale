import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:restaurantadmin/main.dart' show appNavigatorKey; // for global navigation
import 'package:restaurantadmin/services/app_nav_service.dart';
import 'package:restaurantadmin/screens/purchase_review_dialog.dart';

class GlobalPurchaseListener extends StatefulWidget {
  final Widget child;
  const GlobalPurchaseListener({super.key, required this.child});
  @override
  State<GlobalPurchaseListener> createState() => _GlobalPurchaseListenerState();
}

class _GlobalPurchaseListenerState extends State<GlobalPurchaseListener> {
  final _supabase = Supabase.instance.client;
  StreamSubscription<List<Map<String, dynamic>>>? _purchasesStream;
  RealtimeChannel? _purchasesChannel;
  final Set<String> _seenIds = {};
  bool _initialized = false;
  bool _showingDialog = false;

  @override
  void initState() {
    super.initState();
    _subscribeToStream();
    _subscribeToInsertEvents();
  }

  void _subscribeToStream() {
    _purchasesStream?.cancel();
    _purchasesStream = _supabase
        .from('purchases')
        .stream(primaryKey: ['id'])
        .listen((rows) async {
      if (rows.isEmpty) return;
      if (!_initialized) {
        _seenIds.addAll(
          rows.map((r) => (r['id'] ?? '') as String).where((id) => id.isNotEmpty),
        );
        _initialized = true;
        return;
      }
      for (final r in rows) {
        final id = r['id'] as String?;
        if (id == null || id.isEmpty) continue;
        if (_seenIds.add(id)) {
          await _handleNewPurchase(r);
        }
      }
    });
  }

  void _subscribeToInsertEvents() {
    _purchasesChannel?.unsubscribe();
    _purchasesChannel = _supabase
        .channel('public:purchases:insert_listener')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'purchases',
          callback: (payload) async {
            final rec = payload.newRecord;
            final id = rec['id'] as String?;
            if (id == null || id.isEmpty) return;
            if (_seenIds.add(id)) {
              await _handleNewPurchase(rec);
            }
          },
        )
        .subscribe();
  }

  Future<void> _handleNewPurchase(Map<String, dynamic> rec) async {
    try {
      // Navigate to Inventory tab
      AppNavService().goToInventoryTab();

      // Fetch full purchase and items
      final id = rec['id'] as String;
      final headerResp = await _supabase
          .from('purchases')
          .select('supplier_name, receipt_date, total_amount')
          .eq('id', id)
          .maybeSingle();
      final itemsResp = await _supabase
          .from('purchase_items')
          .select('raw_name, brand_name, item_number, quantity, unit, unit_price, total_item_price, material_id, base_unit, conversion_ratio')
          .eq('purchase_id', id);

      if (headerResp == null) return;
      final wholesaler = headerResp['supplier_name'] as String?;
      final dateStr = headerResp['receipt_date'] as String?;
      final totalAmt = (headerResp['total_amount'] is num) ? (headerResp['total_amount'] as num).toDouble() : null;
      final dt = dateStr != null ? DateTime.tryParse(dateStr) : null;

      final List<PurchaseLine> lines = [];
      for (final row in itemsResp) {
        lines.add(PurchaseLine(
          rawName: (row['raw_name'] ?? '') as String,
          brandName: row['brand_name'] as String?,
          itemNumber: row['item_number'] as String?,
          quantity: (row['quantity'] is num) ? (row['quantity'] as num).toDouble() : 0.0,
          unit: (row['unit'] ?? '') as String,
          unitPrice: (row['unit_price'] is num) ? (row['unit_price'] as num).toDouble() : null,
          totalItemPrice: (row['total_item_price'] is num) ? (row['total_item_price'] as num).toDouble() : null,
          materialId: row['material_id'] as String?,
          materialName: null,
          baseUnit: row['base_unit'] as String?,
          conversionRatio: (row['conversion_ratio'] is num) ? (row['conversion_ratio'] as num).toDouble() : 1.0,
        ));
      }

      // Avoid overlapping dialogs
      if (_showingDialog) return;
      _showingDialog = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final nav = appNavigatorKey.currentState;
        if (nav == null) return;
        await nav.push<bool>(
          MaterialPageRoute(
            builder: (ctx) => PurchaseReviewDialog(
              wholesalerName: wholesaler,
              receiptDate: dt,
              totalAmount: totalAmt,
              lines: lines,
              receiptImageBytes: null,
            ),
          ),
        );
        _showingDialog = false;
      });
    } catch (e) {
      debugPrint('[GlobalPurchaseListener] Error handling purchase: $e');
      _showingDialog = false;
    }
  }

  @override
  void dispose() {
    _purchasesStream?.cancel();
    _purchasesChannel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

