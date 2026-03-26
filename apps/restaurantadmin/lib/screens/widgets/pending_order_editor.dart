import 'package:flutter/material.dart';
import 'package:restaurantadmin/models/order.dart' as app_order;
import 'package:restaurantadmin/models/order_item.dart';
import 'package:restaurantadmin/models/menu_item_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PendingOrderEditor extends StatefulWidget {
  final app_order.Order order;
  final List<OrderItem> items;
  final void Function({
    required List<Map<String, dynamic>> itemUpdates,
    required Map<String, dynamic> orderFields,
    List<String> removedItemIds,
    List<Map<String, dynamic>> newItems,
  })
  onSave;
  final VoidCallback onConfirm;

  const PendingOrderEditor({
    super.key,
    required this.order,
    required this.items,
    required this.onSave,
    required this.onConfirm,
  });

  @override
  State<PendingOrderEditor> createState() => _PendingOrderEditorState();
}

class _PendingOrderEditorState extends State<PendingOrderEditor> {
  final SupabaseClient _supabase = Supabase.instance.client;
  late List<_EditableItem> _editableItems;
  late TextEditingController _serviceFeeCtrl;
  late TextEditingController _commissionCtrl;
  late TextEditingController _deliveryFeeCtrl;
  late TextEditingController _customerNameCtrl;
  late TextEditingController _streetCtrl;
  late TextEditingController _postcodeCtrl;
  late TextEditingController _cityCtrl;
  late TextEditingController _latCtrl;
  late TextEditingController _lngCtrl;
  String _fulfillmentType = 'delivery';
  final Set<String> _removedItemIds = {};
  List<MenuItem> _brandMenuItems = [];
  bool _loadingMenu = false;
  double? _estimatedMaterialsCost;
  bool _recalcLoading = false;

  @override
  void initState() {
    super.initState();
    _editableItems = widget.items.map((it) => _EditableItem.from(it)).toList();
    _serviceFeeCtrl = TextEditingController(
      text: _fmt(widget.order.fixedServiceFee),
    );
    _commissionCtrl = TextEditingController(
      text: _fmt(widget.order.commissionAmount),
    );
    _deliveryFeeCtrl = TextEditingController(
      text: _fmt(widget.order.deliveryFee),
    );
    // Materials cost estimate state is kept in the State object fields

    _customerNameCtrl = TextEditingController(
      text: widget.order.customerName ?? '',
    );
    _streetCtrl = TextEditingController(
      text: widget.order.customerStreet ?? '',
    );
    _postcodeCtrl = TextEditingController(
      text: widget.order.customerPostcode ?? '',
    );
    _cityCtrl = TextEditingController(text: widget.order.customerCity ?? '');
    _latCtrl = TextEditingController(
      text: widget.order.deliveryLatitude?.toString() ?? '',
    );
    _lngCtrl = TextEditingController(
      text: widget.order.deliveryLongitude?.toString() ?? '',
    );
    _fulfillmentType = widget.order.fulfillmentType ?? 'delivery';
    // Pre-calc materials cost once editor opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _recalcMaterialsCost();
    });
  }

  String _fmt(double? v) => v == null ? '' : v.toStringAsFixed(2);

  @override
  void dispose() {
    _serviceFeeCtrl.dispose();
    _commissionCtrl.dispose();
    _deliveryFeeCtrl.dispose();
    _customerNameCtrl.dispose();
    _streetCtrl.dispose();
    _postcodeCtrl.dispose();
    _cityCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = _editableItems.fold<double>(
      0.0,
      (sum, it) => sum + (it.priceAtPurchase * it.quantity),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Items',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              onPressed: _onAddItemPressed,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Add Item'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._editableItems.map((it) => _buildItemRow(it)),
        const Divider(height: 24),
        Text('Current Items Total: €${total.toStringAsFixed(2)}'),
        const SizedBox(height: 16),
        const Text(
          'Order Fields',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _buildNumberField('Service Fee (€)', _serviceFeeCtrl),
        _buildNumberField('Commission (€)', _commissionCtrl),
        _buildNumberField('Delivery Fee (€)', _deliveryFeeCtrl),
        const SizedBox(height: 8),
        _buildDropdown('Fulfillment', _fulfillmentType, (v) {
          setState(() => _fulfillmentType = v!);
        }),
        const SizedBox(height: 8),
        _buildTextField('Customer Name', _customerNameCtrl),
        _buildTextField('Street', _streetCtrl),
        Row(
          children: [
            Expanded(child: _buildTextField('Postcode', _postcodeCtrl)),
            const SizedBox(width: 8),
            Expanded(child: _buildTextField('City', _cityCtrl)),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                'Latitude',
                _latCtrl,
                keyboard: TextInputType.numberWithOptions(decimal: true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildTextField(
                'Longitude',
                _lngCtrl,
                keyboard: TextInputType.numberWithOptions(decimal: true),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildMaterialsCostRow(),
        const SizedBox(height: 16),
        if (_estimatedMaterialsCost != null) ...[
          const SizedBox(height: 8),
          _buildEstimatedProfitRow(),
        ],
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  final itemUpdates = _editableItems
                      .where((e) => e.id.isNotEmpty)
                      .map((e) => e.toUpdateMap())
                      .toList();
                  final newItems = _editableItems
                      .where((e) => e.id.isEmpty)
                      .map(
                        (e) => {
                          'order_id': widget.order.id,
                          'menu_item_id': e.menuItemId,
                          'menu_item_name': e.menuItemName,
                          'quantity': e.quantity,
                          'price_at_purchase': e.priceAtPurchase,
                          'brand_id': widget.order.brandId,
                        },
                      )
                      .toList();
                  final orderFields = <String, dynamic>{
                    'fixed_service_fee': _parseNum(_serviceFeeCtrl.text),
                    'commission_amount': _parseNum(_commissionCtrl.text),
                    'delivery_fee': _parseNum(_deliveryFeeCtrl.text),
                    'fulfillment_type': _fulfillmentType,
                    'customer_name': _customerNameCtrl.text.trim().isEmpty
                        ? null
                        : _customerNameCtrl.text.trim(),
                    'customer_street': _streetCtrl.text.trim().isEmpty
                        ? null
                        : _streetCtrl.text.trim(),
                    'customer_postcode': _postcodeCtrl.text.trim().isEmpty
                        ? null
                        : _postcodeCtrl.text.trim(),
                    'customer_city': _cityCtrl.text.trim().isEmpty
                        ? null
                        : _cityCtrl.text.trim(),
                    'delivery_latitude': double.tryParse(_latCtrl.text.trim()),
                    'delivery_longitude': double.tryParse(_lngCtrl.text.trim()),
                  }..removeWhere((k, v) => v == null);
                  widget.onSave(
                    itemUpdates: itemUpdates,
                    orderFields: orderFields,
                    removedItemIds: _removedItemIds.toList(),
                    newItems: newItems,
                  );
                },
                icon: const Icon(Icons.save_alt),
                label: const Text('Save Changes'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: widget.onConfirm,
                icon: const Icon(Icons.check_circle),
                label: const Text('Confirm Order'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _onAddItemPressed() async {
    // Fetch menu items for the order's brand
    setState(() => _loadingMenu = true);
    try {
      final resp = await _supabase
          .from('menu_items')
          .select('id, name, price')
          .eq('brand_id', widget.order.brandId);
      _brandMenuItems = (resp as List)
          .map(
            (m) => MenuItem.fromJson({
              'id': m['id'],
              'name': m['name'],
              'price': (m['price'] as num?)?.toDouble() ?? 0.0,
              'created_at': DateTime.now().toIso8601String(),
              'category_id': 'unknown',
              'display_order': 0,
              'is_available': true,
            }),
          )
          .toList();
    } catch (_) {
      _brandMenuItems = [];
    } finally {
      if (mounted) {
        setState(() => _loadingMenu = false);
      } else {
        _loadingMenu = false;
      }
    }

    if (_brandMenuItems.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No menu items found for this brand')),
      );
      return;
    }

    final selected = await showModalBottomSheet<MenuItem>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        List<MenuItem> filtered = List.of(_brandMenuItems);
        final searchCtrl = TextEditingController();
        return StatefulBuilder(
          builder: (context, setModalState) {
            void applyFilter(String q) {
              final t = q.trim().toLowerCase();
              setModalState(() {
                filtered = t.isEmpty
                    ? List.of(_brandMenuItems)
                    : _brandMenuItems
                          .where((mi) => mi.name.toLowerCase().contains(t))
                          .toList();
              });
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  height: 520,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Add Item',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: searchCtrl,
                        onChanged: applyFilter,
                        decoration: const InputDecoration(
                          hintText: 'Search items...',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final mi = filtered[index];
                            return ListTile(
                              title: Text(mi.name),
                              subtitle: Text('€${mi.price.toStringAsFixed(2)}'),
                              onTap: () => Navigator.of(context).pop(mi),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (selected == null) return;

    setState(() {
      _editableItems.add(
        _EditableItem(
          id: '', // new item (no DB id yet)
          menuItemName: selected.name,
          quantity: 1,
          priceAtPurchase: selected.price,
          menuItemId: selected.id,
        ),
      );
    });
  }

  Widget _buildItemRow(_EditableItem it) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                it.menuItemName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Expanded(
              child: TextFormField(
                initialValue: it.quantity.toString(),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: false,
                ),
                decoration: const InputDecoration(labelText: 'Qty'),
                onChanged: (v) {
                  setState(() => it.quantity = int.tryParse(v) ?? it.quantity);
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                initialValue: it.priceAtPurchase.toStringAsFixed(2),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Price'),
                onChanged: (v) {
                  setState(
                    () => it.priceAtPurchase =
                        double.tryParse(v) ?? it.priceAtPurchase,
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.list_alt_outlined),
              tooltip: 'Materials breakdown',
              onPressed: () => _showMaterialsBreakdown(it),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              tooltip: 'Remove',
              onPressed: () {
                setState(() {
                  _removedItemIds.add(it.id);
                  _editableItems.remove(it);
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialsCostRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            _estimatedMaterialsCost == null
                ? 'Materials Cost: tap recalc'
                : 'Materials Cost (est.): €${_estimatedMaterialsCost!.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
        TextButton.icon(
          onPressed: _recalcLoading ? null : _recalcMaterialsCost,
          icon: _recalcLoading
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.calculate_outlined, size: 18),
          label: const Text('Recalc COGS'),
        ),
      ],
    );
  }

  Future<void> _recalcMaterialsCost() async {
    setState(() => _recalcLoading = true);
    try {
      double total = 0.0;
      for (final it in _editableItems) {
        final c = await _calculateMaterialCostForMenuItem(it);
        total += c * it.quantity;
      }
      setState(() => _estimatedMaterialsCost = total);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to recalc: $e')));
    } finally {
      if (mounted) setState(() => _recalcLoading = false);
    }
  }

  Widget _buildEstimatedProfitRow() {
    final subtotal = _editableItems.fold<double>(
      0.0,
      (s, it) => s + (it.priceAtPurchase * it.quantity),
    );
    final cogs = _estimatedMaterialsCost ?? 0.0;
    final profit = subtotal - cogs;
    final profitPct = subtotal > 0 ? (profit / subtotal) * 100 : 0.0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Estimated Profit',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        Text(
          '€${profit.toStringAsFixed(2)} (${profitPct.toStringAsFixed(0)}%)',
        ),
      ],
    );
  }

  Future<double> _calculateMaterialCostForMenuItem(_EditableItem it) async {
    String? menuItemId = it.menuItemId;
    if ((menuItemId == null || menuItemId.isEmpty) &&
        it.menuItemName.isNotEmpty) {
      try {
        final resp = await _supabase
            .from('menu_items')
            .select('id')
            .eq('brand_id', widget.order.brandId)
            .ilike('name', it.menuItemName);
        if (resp.isNotEmpty && resp.first['id'] is String) {
          menuItemId = resp.first['id'] as String;
        }
      } catch (_) {}
    }
    if (menuItemId == null || menuItemId.isEmpty) return 0.0;

    double singleItemMaterialCost = 0.0;
    try {
      final mimResponse = await _supabase
          .from('menu_item_materials')
          .select('quantity_used, material_id(average_unit_cost)')
          .eq('menu_item_id', menuItemId);
      for (final mimData in (mimResponse as List)) {
        final double quantityUsed =
            (mimData['quantity_used'] as num?)?.toDouble() ?? 0.0;
        final materialData = mimData['material_id'] as Map<String, dynamic>?;
        final double? materialWac = (materialData?['average_unit_cost'] as num?)
            ?.toDouble();
        if (materialWac != null && materialWac > 0) {
          singleItemMaterialCost += quantityUsed * materialWac;
        }
      }
    } catch (_) {}
    return singleItemMaterialCost;
  }

  Widget _buildTextField(
    String label,
    TextEditingController c, {
    TextInputType keyboard = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: TextField(
        controller: c,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _buildNumberField(String label, TextEditingController c) {
    return _buildTextField(
      label,
      c,
      keyboard: const TextInputType.numberWithOptions(decimal: true),
    );
  }

  Future<void> _showMaterialsBreakdown(_EditableItem it) async {
    String? menuItemId = it.menuItemId;
    if ((menuItemId == null || menuItemId.isEmpty) &&
        it.menuItemName.isNotEmpty) {
      try {
        final resp = await _supabase
            .from('menu_items')
            .select('id')
            .eq('brand_id', widget.order.brandId)
            .ilike('name', it.menuItemName);
        if (resp.isNotEmpty && resp.first['id'] is String) {
          menuItemId = resp.first['id'] as String;
        }
      } catch (_) {}
    }
    if (menuItemId == null || menuItemId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No recipe found for this item')),
      );
      return;
    }

    List<Map<String, dynamic>> materials = [];
    try {
      final res = await _supabase
          .from('menu_item_materials')
          .select(
            'quantity_used, unit_used, material_id(name, average_unit_cost)',
          )
          .eq('menu_item_id', menuItemId);
      materials = List<Map<String, dynamic>>.from(res);
    } catch (_) {}

    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        final totalPerUnit = materials.fold<double>(0.0, (sum, m) {
          final q = (m['quantity_used'] as num?)?.toDouble() ?? 0.0;
          final wac =
              (m['material_id']?['average_unit_cost'] as num?)?.toDouble() ??
              0.0;
          return sum + (q * wac);
        });
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined),
                    const SizedBox(width: 8),
                    Text(
                      '${it.menuItemName} — materials (per unit)',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    Text(
                      'COGS/unit: €${totalPerUnit.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (materials.isEmpty)
                  const Text('No materials recipe found for this item')
                else
                  ...materials.map((m) {
                    final name =
                        (m['material_id']?['name'] as String?) ?? 'Unknown';
                    final q = (m['quantity_used'] as num?)?.toDouble() ?? 0.0;
                    final unit = (m['unit_used'] as String?) ?? '';
                    final wac =
                        (m['material_id']?['average_unit_cost'] as num?)
                            ?.toDouble() ??
                        0.0;
                    final cost = q * wac;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text('$name: ${q.toStringAsFixed(2)} $unit'),
                          ),
                          Text('€${cost.toStringAsFixed(2)}'),
                        ],
                      ),
                    );
                  }),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDropdown(
    String label,
    String value,
    ValueChanged<String?> onChanged,
  ) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          items: const [
            DropdownMenuItem(value: 'delivery', child: Text('Delivery')),
            DropdownMenuItem(value: 'pickup', child: Text('Pickup')),
            DropdownMenuItem(value: 'dine_in', child: Text('Dine-in')),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  double? _parseNum(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }
}

class _EditableItem {
  final String id;
  final String menuItemName;
  final String? menuItemId; // optional for new items
  int quantity;
  double priceAtPurchase;

  _EditableItem({
    required this.id,
    required this.menuItemName,
    required this.quantity,
    required this.priceAtPurchase,
    this.menuItemId,
  });

  factory _EditableItem.from(OrderItem it) => _EditableItem(
    id: it.id ?? '',
    menuItemName: it.menuItemName,
    quantity: it.quantity,
    priceAtPurchase: it.priceAtPurchase,
    menuItemId: it.menuItemId,
  );

  Map<String, dynamic> toUpdateMap() => {
    'id': id,
    'quantity': quantity,
    'price_at_purchase': priceAtPurchase,
  };
}
