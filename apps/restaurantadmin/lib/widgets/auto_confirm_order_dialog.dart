import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:restaurantadmin/models/order.dart' as app_order;
import 'package:restaurantadmin/services/settings_service.dart';
import 'package:restaurantadmin/screens/order_detail_screen.dart';

class AutoConfirmOrderDialog extends StatefulWidget {
  final app_order.Order order;
  final VoidCallback? onConfirmed;
  final VoidCallback? onCancelled;

  const AutoConfirmOrderDialog({
    super.key,
    required this.order,
    this.onConfirmed,
    this.onCancelled,
  });

  @override
  State<AutoConfirmOrderDialog> createState() => _AutoConfirmOrderDialogState();
}

class _AutoConfirmOrderDialogState extends State<AutoConfirmOrderDialog>
    with TickerProviderStateMixin {
  final SettingsService _settings = SettingsService();

  Timer? _autoConfirmTimer;
  late AnimationController _progressController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  int _secondsLeft = 0;
  bool _isConfirming = false;
  bool _autoConfirmCancelled = false;

  @override
  void initState() {
    super.initState();

    _progressController = AnimationController(
      duration: Duration(seconds: _settings.autoConfirmSeconds.value),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    _fadeController.forward();

    // Start auto-confirm if enabled
    if (_settings.autoConfirmEnabled.value) {
      _startAutoConfirmCountdown();
    }
  }

  @override
  void dispose() {
    _autoConfirmTimer?.cancel();
    _progressController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _startAutoConfirmCountdown() {
    if (_autoConfirmCancelled) return;

    _secondsLeft = _settings.autoConfirmSeconds.value;
    _progressController.forward();

    _autoConfirmTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _autoConfirmCancelled) {
        timer.cancel();
        return;
      }

      setState(() => _secondsLeft--);

      if (_secondsLeft <= 0) {
        timer.cancel();
        _confirmOrder();
      }
    });
  }

  void _cancelAutoConfirm() {
    setState(() {
      _autoConfirmCancelled = true;
      _secondsLeft = 0;
    });
    _autoConfirmTimer?.cancel();
    _progressController.stop();
  }

  Future<void> _confirmOrder() async {
    if (_isConfirming) return;

    setState(() => _isConfirming = true);

    try {
      // Update order status to confirmed directly
      await Supabase.instance.client
          .from('orders')
          .update({'status': 'confirmed'})
          .eq('id', widget.order.id!);

      if (mounted) {
        widget.onConfirmed?.call();
        Navigator.of(context).pop(true);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text('Order ${widget.order.id?.substring(0, 8)} confirmed!'),
              ],
            ),
            backgroundColor: Colors.green[600],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to confirm order: $e'),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isConfirming = false);
    }
  }

  void _editOrder() {
    _cancelAutoConfirm();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => OrderDetailScreen(order: widget.order),
        fullscreenDialog: true,
      ),
    );
  }

  void _closeDialog() {
    _cancelAutoConfirm();
    widget.onCancelled?.call();
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 720),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with progress bar
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange[600]!, Colors.orange[400]!],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.receipt_long, color: Colors.white),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'New Order Received',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _closeDialog,
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                      ],
                    ),
                    if (_settings.autoConfirmEnabled.value && !_autoConfirmCancelled) ...[
                      const SizedBox(height: 8),
                      AnimatedBuilder(
                        animation: _progressController,
                        builder: (context, child) {
                          return Column(
                            children: [
                              LinearProgressIndicator(
                                value: _progressController.value,
                                backgroundColor: Colors.white.withAlpha(77),
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _secondsLeft > 0
                                    ? 'Auto-confirming in $_secondsLeft seconds...'
                                    : 'Confirming order...',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),

              // Order details + costs
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top row: brand, platform logo, totals
                      Row(
                        children: [
                          // Brand pill
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.blue[200]!),
                            ),
                            child: Text(
                              widget.order.brandName ?? 'Unknown Brand',
                              style: TextStyle(
                                color: Colors.blue[700],
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Delivery platform logo
                          _OrderTypeLogoSmall(orderTypeName: widget.order.orderTypeName),
                          const Spacer(),
                          // Total price
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.green[200]!),
                            ),
                            child: Text(
                              '€${widget.order.totalPrice.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: Colors.green[700],
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Order ID: ${widget.order.id?.substring(0, 8) ?? 'N/A'}...',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),
                      if (widget.order.fulfillmentType != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Type: ${widget.order.fulfillmentType}',
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                      ],
                      const SizedBox(height: 12),

                      // Costs row: material cost, commission, service fee, delivery fee, profit
                      _CostRow(order: widget.order),
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 12),

                      // AI parse debug (toggle-controlled)
                      ValueListenableBuilder<bool>(
                        valueListenable: _settings.showAiDebugInDialog,
                        builder: (context, show, _) => show
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('AI parse (raw and normalized)', style: TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 6),
                                  SizedBox(height: 120, child: _AiParsePanel(orderId: widget.order.id!)),
                                  const SizedBox(height: 12),
                                  const Divider(height: 1),
                                  const SizedBox(height: 12),
                                ],
                              )
                            : const SizedBox.shrink(),
                      ),

                      // Items with images (compact list)
                      Expanded(
                        child: _OrderItemsPreview(orderId: widget.order.id!),
                      ),
                      const SizedBox(height: 12),

                      // Actions
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isConfirming ? null : _editOrder,
                              icon: const Icon(Icons.edit),
                              label: const Text('Edit Order'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isConfirming ? null : _confirmOrder,
                              icon: _isConfirming
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.check),
                              label: Text(_isConfirming ? 'Confirming...' : 'Confirm Now'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green[600],
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderTypeLogoSmall extends StatelessWidget {
  final String? orderTypeName;
  const _OrderTypeLogoSmall({required this.orderTypeName});

  @override
  Widget build(BuildContext context) {
    String? logoPath;
    final name = orderTypeName?.toLowerCase() ?? '';
    if (name.contains('lieferando')) {
      logoPath = 'assets/ordertypes/lieferando.png';
    } else if (name.contains('foodora')) {
      logoPath = 'assets/ordertypes/Foodora.png';
    } else if (name.contains('ninja')) {
      logoPath = 'assets/ordertypes/ninjas.jpeg';
    } else if (name.contains('wolt')) {
      logoPath = 'assets/ordertypes/wolt-logo.png';
    }

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: logoPath != null
            ? Image.asset(logoPath, fit: BoxFit.contain)
            : Icon(Icons.delivery_dining_outlined, size: 16, color: Colors.blueGrey.shade400),
      ),
    );
  }
}

class _CostRow extends StatelessWidget {
  final app_order.Order order;
  const _CostRow({required this.order});

  String _fmt(double? v) => v == null ? '-' : '€${v.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    // Commission is stored as commission_amount on order
    final commission = order.commissionAmount;
    final serviceFee = order.fixedServiceFee;
    final deliveryFee = order.deliveryFee;
    final materialCost = order.totalMaterialCost;
    final profit = order.profit;

    Widget chip(String label, String value, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(51)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          Text(value, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip('Materials', _fmt(materialCost), Colors.deepPurple),
          const SizedBox(width: 8),
          chip('Commission', _fmt(commission), Colors.orange),
          const SizedBox(width: 8),
          chip('Service fee', _fmt(serviceFee), Colors.teal),
          const SizedBox(width: 8),
          chip('Delivery fee', _fmt(deliveryFee), Colors.blue),
          const SizedBox(width: 8),
          chip('Profit', _fmt(profit), profit == null || profit >= 0 ? Colors.green : Colors.red),
        ],
      ),
    );
  }
}

class _OrderItemsPreview extends StatefulWidget {
  final String orderId;
  const _OrderItemsPreview({required this.orderId});

  @override
  State<_OrderItemsPreview> createState() => _OrderItemsPreviewState();
}

class _OrderItemsPreviewState extends State<_OrderItemsPreview> {
  final _supabase = Supabase.instance.client;
  Future<List<Map<String, dynamic>>>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    // fetch order_items joined with menu_items to get names and image_url
    final rows = await _supabase
        .from('order_items')
        .select('menu_item_id, menu_item_name, quantity, price_at_purchase, menu_items(image_url)')
        .eq('order_id', widget.orderId);
    final list = (rows as List).cast<Map<String, dynamic>>();
    // Normalize nested menu_items.image_url to top-level 'image_url'
    for (final map in list) {
      final mi = map['menu_items'];
      if (mi is Map<String, dynamic>) {
        map['image_url'] = mi['image_url'];
      }
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        if (snap.hasError) {
          return Center(child: Text('Failed to load items', style: TextStyle(color: Colors.red.shade700)));
        }
        final items = snap.data ?? const [];
        if (items.isEmpty) {
          return const Center(child: Text('No items'));
        }
        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final it = items[i];
            final name = it['menu_item_name'] as String? ?? 'Item';
            final qty = (it['quantity'] as num?)?.toInt() ?? 1;
            final price = (it['price_at_purchase'] as num?)?.toDouble() ?? 0.0;
            final imageUrl = it['image_url'] as String?;
            return ListTile(
              leading: imageUrl != null && imageUrl.isNotEmpty



                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        imageUrl,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.fastfood),
                      ),
                    )
                  : const Icon(Icons.fastfood),
              title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('x$qty'),
              trailing: Text('€${(price * qty).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              dense: true,
            );
          },
        );
      },
    );
  }
}


class _AiParsePanel extends StatefulWidget {
  final String orderId;
  const _AiParsePanel({required this.orderId});

  @override
  State<_AiParsePanel> createState() => _AiParsePanelState();
}

class _AiParsePanelState extends State<_AiParsePanel> {
  final _supabase = Supabase.instance.client;
  Future<Map<String, dynamic>>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    // Heuristic: fetch latest scan_logs row near this order by created_at and same brand if possible
    final order = await _supabase
        .from('orders')
        .select('id, brand_id, created_at, platform_order_id')
        .eq('id', widget.orderId)
        .maybeSingle();
    if (order == null) return {};
    final brandId = order['brand_id'] as String?;

    var builder = _supabase
        .from('scan_logs')
        .select('id, created_at, raw_response, normalized');
    if (brandId != null) {
      builder = builder.eq('brand_id', brandId);
    }
    final logs = await builder.order('created_at', ascending: false).limit(10);
    final list = (logs as List?) ?? const [];
    if (list.isEmpty) return {};

    final latest = list.first as Map<String, dynamic>;
    return {
      'raw': latest['raw_response'],
      'normalized': latest['normalized'],
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        final data = snap.data ?? const {};
        if (data.isEmpty) return const Text('No AI logs');
        final raw = data['raw'];
        final normalized = data['normalized'];
        return Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100], borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                padding: const EdgeInsets.all(8),
                child: SingleChildScrollView(
                  child: Text(
                    _prettyJson(raw),
                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100], borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                padding: const EdgeInsets.all(8),
                child: SingleChildScrollView(
                  child: Text(
                    _prettyJson(normalized),
                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _prettyJson(dynamic obj) {
    try {
      return const JsonEncoder.withIndent('  ').convert(obj);
    } catch (_) {
      return obj?.toString() ?? '';
    }
  }
}
