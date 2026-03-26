import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ScannedReceiptDetailScreen extends StatefulWidget {
  final Map<String, dynamic> row; // row from scanned_receipts
  const ScannedReceiptDetailScreen({super.key, required this.row});

  @override
  State<ScannedReceiptDetailScreen> createState() =>
      _ScannedReceiptDetailScreenState();
}

class _ScannedReceiptDetailScreenState
    extends State<ScannedReceiptDetailScreen> {
  final _supabase = Supabase.instance.client;
  String? _imageUrl;
  Map<String, dynamic>? _order;
  Map<String, dynamic>? _purchase;
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Signed image URL
      final path = widget.row['storage_path'] as String?;
      if (path != null && path.isNotEmpty) {
        final res = await _supabase.storage
            .from('scanned-receipts')
            .createSignedUrl(path, 300);
        _imageUrl = res;
      }

      final scanType = (widget.row['scan_type'] as String?) ?? 'order';
      if (scanType == 'order' && widget.row['created_order_id'] != null) {
        final orderId = widget.row['created_order_id'] as String;
        final order = await _supabase
            .from('orders')
            .select('*')
            .eq('id', orderId)
            .maybeSingle();
        final items = await _supabase
            .from('order_items')
            .select('menu_item_name,quantity,price_at_purchase')
            .eq('order_id', orderId);
        _order = order != null ? Map<String, dynamic>.from(order) : null;
        _items = (items is List)
            ? List<Map<String, dynamic>>.from(
                items.map((e) => Map<String, dynamic>.from(e)),
              )
            : [];
      } else if (scanType == 'purchase' &&
          widget.row['created_purchase_id'] != null) {
        final purchaseId = widget.row['created_purchase_id'] as String;
        final purchase = await _supabase
            .from('purchases')
            .select('*')
            .eq('id', purchaseId)
            .maybeSingle();
        final items = await _supabase
            .from('purchase_items')
            .select('material_name,quantity,unit_price')
            .eq('purchase_id', purchaseId);
        _purchase = purchase != null
            ? Map<String, dynamic>.from(purchase)
            : null;
        _items = (items is List)
            ? List<Map<String, dynamic>>.from(
                items.map((e) => Map<String, dynamic>.from(e)),
              )
            : [];
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted)
        setState(() {
          _loading = false;
        });
    }
  }

  String _fmt(Object? n) {
    if (n == null) return '-';
    if (n is num) return NumberFormat.currency(symbol: '€').format(n);
    final v = num.tryParse('$n');
    return v == null ? '$n' : NumberFormat.currency(symbol: '€').format(v);
  }

  Widget _kv(String k, Object? v) {
    final text = v == null || ('$v').isEmpty ? '-' : '$v';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scanType = (widget.row['scan_type'] as String?) ?? 'order';
    return Scaffold(
      appBar: AppBar(
        title: Text(scanType == 'order' ? 'Order Receipt' : 'Purchase Receipt'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AspectRatio(
                    aspectRatio: 3 / 4,
                    child: _imageUrl == null
                        ? Container(
                            color: Colors.grey[200],
                            child: const Center(
                              child: Icon(Icons.image_not_supported),
                            ),
                          )
                        : Image.network(_imageUrl!, fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Details',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (scanType == 'order' && _order != null) ...[
                    _kv('Brand', widget.row['brand_name']),
                    _kv('Platform Order ID', _order!['platform_order_id']),
                    _kv('Total', _fmt(_order!['total_price'])),
                    _kv('Delivery Fee', _fmt(_order!['delivery_fee'])),
                    _kv('Service Fee', _fmt(_order!['fixed_service_fee'])),
                    _kv('Commission', _fmt(_order!['commission_amount'])),
                    _kv('Note', _order!['note']?.toString() ?? '-'),
                    _kv('Order Type', _order!['order_type_name']),
                    _kv('Payment', _order!['payment_method']),
                    _kv('Customer', _order!['customer_name']),
                    _kv('Street', _order!['customer_street']),
                    _kv('Postcode', _order!['customer_postcode']),
                    _kv('City', _order!['customer_city']),
                    _kv('Created At', _order!['created_at']),
                  ] else if (scanType == 'purchase' && _purchase != null) ...[
                    _kv('Supplier', widget.row['supplier_name']),
                    _kv('Total Amount', _fmt(_purchase!['total_amount'])),
                    _kv('Created At', _purchase!['created_at']),
                  ],
                  const SizedBox(height: 16),
                  if (_items.isNotEmpty) ...[
                    Text(
                      'Items',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    ..._items.map((it) {
                      if (scanType == 'order') {
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(it['menu_item_name'] ?? '-'),
                          subtitle: Text('Qty ${it['quantity'] ?? '-'}'),
                          trailing: Text(_fmt(it['price_at_purchase'])),
                        );
                      } else {
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(it['material_name'] ?? '-'),
                          subtitle: Text('Qty ${it['quantity'] ?? '-'}'),
                          trailing: Text(_fmt(it['unit_price'])),
                        );
                      }
                    }),
                  ],
                ],
              ),
            ),
    );
  }
}
