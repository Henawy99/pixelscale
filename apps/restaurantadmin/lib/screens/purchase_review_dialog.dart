import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PurchaseItemModel {
  final String id;
  final String canonicalName; // purchase_catalog_items.name
  final String? receiptName;  // purchase_catalog_items.receipt_name (purchasename)
  final String? materialId;   // linked material
  final String? baseUnit;     // from material or explicit on purchase item
  final double? conversionRatio; // base units per 1 receipt unit
  final double? fixedQuantityBaseUnits; // optional fixed qty (e.g., 2.5 kg per unit)
  bool isFixedQuantity; // enforce fixedQuantityBaseUnits if true
  final double? defaultValue; // optional default value/price for the item (if desired)

  PurchaseItemModel({
    required this.id,
    required this.canonicalName,
    this.receiptName,
    this.materialId,
    this.baseUnit,
    this.conversionRatio,
    this.fixedQuantityBaseUnits,
    this.defaultValue,
    this.isFixedQuantity = false,
  });
}


class PurchaseLine {
  String rawName;
  String? brandName;
  String? itemNumber;
  double quantity;
  String unit;
  double? unitPrice;
  double? totalItemPrice;

  // Link to DB purchase_items row
  String? purchaseItemId; // purchase_items.id if this line came from DB

  // Selected/matched Purchase Catalog Item (the only thing we link to)
  String? purchaseCatalogItemId;
  String? purchaseCatalogItemName;

  // Fixed quantity behavior from purchase item
  bool isFixedQuantity = false; // when true, conversion is locked
  double? fixedQuantityBaseUnits; // base units per 1 receipt unit when fixed

  // Resolved material mapping (derived from purchase item; read-only in UI)
  String? materialId;
  String? materialName;
  String? baseUnit; // material.unit_of_measure or purchase item base_unit
  double conversionRatio; // how many baseUnit per 1 receipt unit

  // Current material stats (for UI)
  double? currentQuantity; // current stock in baseUnit
  double? averageUnitCost; // weighted avg cost per baseUnit
  String? itemImageUrl; // material.item_image_url

  PurchaseLine({
    required this.rawName,
    this.brandName,
    this.itemNumber,
    required this.quantity,
    required this.unit,
    this.unitPrice,
    this.totalItemPrice,
    this.purchaseItemId,
    this.purchaseCatalogItemId,
    this.purchaseCatalogItemName,
    this.materialId,
    this.materialName,
    this.baseUnit,
    this.conversionRatio = 1,
    this.currentQuantity,
    this.averageUnitCost,
    this.itemImageUrl,
  });

  double get quantityInBaseUnits => quantity * conversionRatio;
  double get effectiveUnitPrice => unitPrice ?? (totalItemPrice != null && quantityInBaseUnits > 0 ? totalItemPrice! / quantityInBaseUnits : 0);
  double get effectiveLineTotal => totalItemPrice ?? (effectiveUnitPrice * quantityInBaseUnits);
  double? get currentInventoryValue => (currentQuantity != null && averageUnitCost != null)
      ? (currentQuantity! * averageUnitCost!)
      : null;
}


class PurchaseReviewDialog extends StatefulWidget {
  final String? purchaseId; // If provided, we won't create a new purchase row
  final String? wholesalerName;
  final DateTime? receiptDate;
  final double? totalAmount;
  final List<PurchaseLine> lines;
  final Uint8List? receiptImageBytes;

  const PurchaseReviewDialog({super.key, this.purchaseId, required this.wholesalerName, required this.receiptDate, required this.totalAmount, required this.lines, this.receiptImageBytes});

  @override
  State<PurchaseReviewDialog> createState() => _PurchaseReviewDialogState();
}

class _PurchaseReviewDialogState extends State<PurchaseReviewDialog> {
  final _supabase = Supabase.instance.client;
  bool _isSaving = false;
  bool _autoSaveMappings = true;
  String? _supplierId;


  Future<void> _loadMaterialStatsForLine(PurchaseLine line) async {
    if (line.materialId == null) return;
    try {
      final mat = await _supabase
          .from('material')
          .select('unit_of_measure, current_quantity, average_unit_cost, item_image_url')
          .eq('id', line.materialId!)
          .maybeSingle();
      if (!mounted) return;
      if (mat != null) {
        setState(() {
          line.baseUnit = line.baseUnit ?? (mat['unit_of_measure'] as String?);
          line.currentQuantity = (mat['current_quantity'] as num?)?.toDouble();
          line.averageUnitCost = (mat['average_unit_cost'] as num?)?.toDouble();
          line.itemImageUrl = mat['item_image_url'] as String?;
        });
      }
    } catch (_) {}
  }

  Future<void> _resolveInitialMappings() async {
    // Resolve supplier first (by name), then try to load material mapping via purchase catalog if possible
    try {
      if (widget.wholesalerName != null && widget.wholesalerName!.trim().isNotEmpty) {
        final sup = await _supabase.from('suppliers').select('id').ilike('name', widget.wholesalerName!).maybeSingle();
        _supplierId = sup?['id'] as String?;
      }
    } catch (_) {}

    // Per requirements, do not auto-map lines. We only resolve supplier for header.
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _resolveInitialMappings();
  }

  Future<void> _applyToInventory() async {
    setState(() => _isSaving = true);
    try {

      // 1) Create purchase header row (so it shows under Recent Purchase Receipts)
      final headerTotal = widget.totalAmount ?? widget.lines.fold<double>(0.0, (s, l) => s + (l.totalItemPrice ?? 0));
      final purchaseInsert = await _supabase
          .from('purchases')
          .insert({
            'supplier_id': _supplierId,
            'supplier_name': widget.wholesalerName,
            'receipt_date': widget.receiptDate?.toIso8601String(),
            'total_amount': headerTotal,
            'status': 'pending_review',
            'notes': 'Created from Purchase Review Dialog',
          })
          .select('id')
          .single();
      final purchaseId = purchaseInsert['id'] as String;

      // 1b) Insert purchase_items
      final itemsPayload = widget.lines.map((line) => {
        'purchase_id': purchaseId,
        'raw_name': line.rawName,
        'brand_name': line.brandName,
        'item_number': line.itemNumber,
        'purchase_catalog_item_id': line.purchaseCatalogItemId,
        'quantity': line.quantity,
        'total_item_price': line.totalItemPrice,
      }).toList();
      if (itemsPayload.isNotEmpty) {
        await _supabase.from('purchase_items').insert(itemsPayload);
      }

      // 2) For each line: update material weighted average cost and inventory_log (via linked purchase item)
      for (final line in widget.lines) {
        if (line.materialId == null) continue; // skip if purchase item has no material linked yet
        final materialId = line.materialId!;

        // Fetch current state
        final materialRow = await _supabase
            .from('material')
            .select('current_quantity, average_unit_cost, name')
            .eq('id', materialId)
            .single();
        final oldQty = (materialRow['current_quantity'] as num?)?.toDouble() ?? 0.0;
        final oldWac = (materialRow['average_unit_cost'] as num?)?.toDouble() ?? 0.0;

        final qtyAdded = line.quantityInBaseUnits;
        final lineTotal = line.effectiveLineTotal;
        final oldValue = oldQty * oldWac;
        final newQty = oldQty + qtyAdded;
        final newTotalValue = oldValue + lineTotal;
        final newWac = newQty > 0 ? (newTotalValue / newQty) : 0.0;

        await _supabase
            .from('material')
            .update({ 'current_quantity': newQty, 'average_unit_cost': newWac })
            .eq('id', materialId);

        await _supabase.from('inventory_log').insert({
          'material_id': materialId,
          'material_name': (materialRow['name'] as String?) ?? line.materialName,
          'change_type': 'MANUAL_RECEIPT',
          'quantity_change': qtyAdded,
          'new_quantity_after_change': newQty,
          'unit_price_paid': line.effectiveUnitPrice,
          'total_price_paid': lineTotal,
          'source_details': 'Purchase Review Dialog',
          'user_id': _supabase.auth.currentUser?.id,
        });

        // 3) Optionally save mapping automatically for future scans
        if (_autoSaveMappings && line.materialId != null) {
          try {
            await _supabase.from('receiptmaterialitem').insert({
              'raw_name': line.rawName,
              'brand_name': line.brandName,
              'item_number': line.itemNumber,
              'material_id': line.materialId,
              'receipt_unit': line.unit,
              'base_unit': line.baseUnit,
              'conversion_ratio': line.conversionRatio,
              'notes': 'Auto-saved from purchase apply',
            });
          } catch (_) {}
        }
      }

      if (!mounted) return;
      Navigator.of(context).pop(true); // success
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to apply purchase: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _selectPurchaseItem(PurchaseLine line) async {
    if (line.purchaseItemId == null) return; // requires DB row id to persist
    final supplier = widget.wholesalerName;
    String? supplierId;
    try {
      if (supplier != null && supplier.trim().isNotEmpty) {
        final sup = await _supabase.from('suppliers').select('id').ilike('name', supplier).maybeSingle();
        supplierId = sup?['id'] as String?;
      }
    } catch (_) {}

    if (!mounted) return;
    final selected = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (ctx) => _PurchaseItemPickerDialog(supplierId: supplierId, initialQuery: line.rawName),
    );
    if (selected == null) return;
    // Update purchase_items.purchase_catalog_item_id
    try {
      await _supabase.from('purchase_items')
        .update({ 'purchase_catalog_item_id': selected['id'] as String })
        .eq('id', line.purchaseItemId!);

      // Pull material mapping for UI
      final pci = await _supabase
          .from('purchase_catalog_items')
          .select('material_id, material_id(id, name, unit_of_measure), base_unit, conversion_ratio')
          .eq('id', selected['id'] as String)
          .maybeSingle();
      final mat = pci?['material_id'] as Map<String, dynamic>?;
      setState(() {
        line.materialId = mat?['id'] as String?;
        line.materialName = mat?['name'] as String?;
        line.baseUnit = (pci?['base_unit'] as String?) ?? (mat?['unit_of_measure'] as String?);
        final conv = (pci?['conversion_ratio'] as num?)?.toDouble();
        if (conv != null && conv > 0) line.conversionRatio = conv;
      });
      // ignore: unawaited_futures
      _loadMaterialStatsForLine(line);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to set Purchase Item: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _createPurchaseItem(PurchaseLine line) async {
    final supplier = widget.wholesalerName;
    String? supplierId;
    try {
      if (supplier != null && supplier.trim().isNotEmpty) {
        final sup = await _supabase.from('suppliers').select('id').ilike('name', supplier).maybeSingle();
        supplierId = sup?['id'] as String?;
      }
    } catch (_) {}
    if (supplierId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Set supplier first.')));
      }
      return;
    }

    if (!mounted) return;
    final created = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (ctx) => _CreatePurchaseItemQuickDialog(supplierId: supplierId!, seedName: line.rawName),
    );
    if (created == null || line.purchaseItemId == null) return;

    try {
      await _supabase.from('purchase_items')
        .update({ 'purchase_catalog_item_id': created['id'] as String })
        .eq('id', line.purchaseItemId!);

      final mat = created['material_id'] as Map<String, dynamic>?;
      setState(() {
        line.materialId = mat?['id'] as String?;
        line.materialName = mat?['name'] as String?;
        line.baseUnit = created['base_unit'] as String?;
        final conv = (created['conversion_ratio'] as num?)?.toDouble();
        if (conv != null && conv > 0) line.conversionRatio = conv;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create Purchase Item: $e'), backgroundColor: Colors.red));
    }
  }


  @override
  Widget build(BuildContext context) {
    final total = widget.lines.fold<double>(0.0, (s, l) => s + l.effectiveLineTotal);
    return Scaffold(
      appBar: AppBar(
        title: Text('Review Purchase from ${widget.wholesalerName ?? 'Unknown'}'),
        actions: [
          if (widget.receiptDate != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(child: Text(widget.receiptDate!.toLocal().toString().substring(0, 16))),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: widget.lines.length,
              itemBuilder: (ctx, i) {
                final line = widget.lines[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(line.rawName, style: const TextStyle(fontWeight: FontWeight.w600)),
                            ),
                            Text(line.brandName ?? ''),
                            const SizedBox(width: 12),
                            Text(line.itemNumber ?? ''),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Item image (if any)
                            if (line.itemImageUrl != null)
                              Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(line.itemImageUrl!, width: 56, height: 56, fit: BoxFit.cover),
                                ),
                              ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    const Text('Purchase item:', style: TextStyle(fontWeight: FontWeight.w600)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        line.purchaseCatalogItemName ?? 'No purchase item detected. Create one.',
                                        style: TextStyle(color: line.purchaseCatalogItemId != null ? Colors.black87 : Colors.orange[800]),
                                      ),
                                    ),
                                  ]),
                                  const SizedBox(height: 6),
                                  Wrap(spacing: 10, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                                    OutlinedButton.icon(
                                      onPressed: () => _selectPurchaseItem(line),
                                      icon: const Icon(Icons.link_outlined, size: 16),
                                      label: const Text('Link Purchase Item'),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: () => _createPurchaseItem(line),
                                      icon: const Icon(Icons.add_circle_outline, size: 16),
                                      label: const Text('Create Purchase Item'),
                                    ),
                                    SizedBox(
                                      width: 90,
                                      child: TextField(
                                        decoration: InputDecoration(labelText: line.isFixedQuantity ? 'Units' : 'Qty', isDense: true, border: const OutlineInputBorder()),
                                        controller: TextEditingController(text: line.quantity.toStringAsFixed(2)),
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        onChanged: (v) => setState(() => line.quantity = double.tryParse(v.replaceAll(',', '.')) ?? line.quantity),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 120,
                                      child: TextField(
                                        decoration: const InputDecoration(labelText: 'Total €', isDense: true, border: OutlineInputBorder()),
                                        controller: TextEditingController(text: line.totalItemPrice?.toStringAsFixed(2) ?? ''),
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        onChanged: (v) => setState(() => line.totalItemPrice = double.tryParse(v.replaceAll(',', '.'))),
                                      ),
                                    ),
                                  ]),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(spacing: 12, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                          Chip(label: Text('Base unit: ${line.baseUnit ?? '-'}')),
                          Chip(label: Text('Qty in base: ${line.quantityInBaseUnits.toStringAsFixed(2)}')),
                          Chip(label: Text('Line Total: €${line.effectiveLineTotal.toStringAsFixed(2)}')),
                          if (line.currentQuantity != null) Chip(label: Text('Current stock: ${line.currentQuantity!.toStringAsFixed(2)} ${line.baseUnit ?? ''}')),
                          if (line.averageUnitCost != null) Chip(label: Text('Avg cost: €${line.averageUnitCost!.toStringAsFixed(2)}/${line.baseUnit ?? ''}')),
                          if (line.currentInventoryValue != null) Chip(label: Text('Inventory value: €${line.currentInventoryValue!.toStringAsFixed(2)}')),
                          if (line.currentQuantity != null) Chip(label: Text('After purchase: ${(line.currentQuantity! + line.quantityInBaseUnits).toStringAsFixed(2)} ${line.baseUnit ?? ''}')),
                        ]),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Expanded(child: Text('Total: €${total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold))),
              Row(children: [
                const Text('Save mappings'),
                Switch(value: _autoSaveMappings, onChanged: (v) => setState(() => _autoSaveMappings = v)),
              ]),
              const SizedBox(width: 8),
              TextButton(onPressed: _isSaving ? null : () => Navigator.of(context).pop(false), child: const Text('Cancel')),
              const SizedBox(width: 8),
              ElevatedButton.icon(onPressed: _isSaving ? null : _applyToInventory, icon: const Icon(Icons.check_circle_outline), label: const Text('Apply')),
            ],
          ),
        ),
      ),
    );
  }
}


class _CreateMaterialDialog extends StatefulWidget {
  final String seedName;
  const _CreateMaterialDialog({required this.seedName});
  @override
  State<_CreateMaterialDialog> createState() => _CreateMaterialDialogState();
}

class _CreateMaterialDialogState extends State<_CreateMaterialDialog> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _unit = TextEditingController(text: 'piece');
  final _category = TextEditingController();

  @override
  void initState() {
    super.initState();
    _name.text = widget.seedName;
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    final resp = await _supabase.from('material').insert({
      'name': _name.text.trim(),
      'unit_of_measure': _unit.text.trim(),
      'category': _category.text.trim().isNotEmpty ? _category.text.trim() : null,
      'current_quantity': 0,
      'average_unit_cost': 0,
    }).select('id, name, unit_of_measure').single();
    if (!mounted) return;
    Navigator.of(context).pop(resp);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Create Material', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _unit,
                decoration: const InputDecoration(labelText: 'Unit of measure', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _category,
                decoration: const InputDecoration(labelText: 'Category (optional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  ElevatedButton(onPressed: _create, child: const Text('Create')),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}



// Dialog to pick a Purchase Item (catalog) for a supplier
class _PurchaseItemPickerDialog extends StatefulWidget {
  final String? supplierId;
  final String initialQuery;
  const _PurchaseItemPickerDialog({required this.supplierId, required this.initialQuery});
  @override
  State<_PurchaseItemPickerDialog> createState() => _PurchaseItemPickerDialogState();
}

class _PurchaseItemPickerDialogState extends State<_PurchaseItemPickerDialog> {
  final _supabase = Supabase.instance.client;
  final _search = TextEditingController();
  List<Map<String, dynamic>> _results = [];

  @override
  void initState() {
    super.initState();
    _search.text = widget.initialQuery;
    _searchNow();
  }

  Future<void> _searchNow() async {
    final q = _search.text.trim();
    final base = _supabase
        .from('purchase_catalog_items')
        .select('id, name, receipt_name, material_id, material_id(name)');
    final resp = await (
      (widget.supplierId != null ? base.eq('supplier_id', widget.supplierId!) : base)
        .or(q.isEmpty ? 'id.not.is.null' : 'name.ilike.%$q%,receipt_name.ilike.%$q%')
        .limit(25)
    );
    if (!mounted) return;
    setState(() => _results = (resp as List).cast<Map<String, dynamic>>());
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 520,
        height: 520,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _search,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(icon: const Icon(Icons.refresh), onPressed: _searchNow),
                  labelText: 'Search Purchase Items',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: (_) => _searchNow(),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (ctx, i) {
                    final r = _results[i];
                    final mat = r['material_id'] as Map<String, dynamic>?;
                    return ListTile(
                      title: Text(r['name'] as String? ?? ''),
                      subtitle: Text('Receipt: ${r['receipt_name'] ?? '-'} • Material: ${mat!=null ? (mat['name'] ?? '-') : '-'}'),
                      onTap: () => Navigator.of(context).pop(r),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Quick create dialog for a Purchase Item
class _CreatePurchaseItemQuickDialog extends StatefulWidget {
  final String supplierId;
  final String seedName;
  const _CreatePurchaseItemQuickDialog({required this.supplierId, required this.seedName});
  @override
  State<_CreatePurchaseItemQuickDialog> createState() => _CreatePurchaseItemQuickDialogState();
}

class _CreatePurchaseItemQuickDialogState extends State<_CreatePurchaseItemQuickDialog> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _receiptName = TextEditingController();
  final _convCtrl = TextEditingController(text: '1.0');

  Map<String, dynamic>? _selectedMaterial; // deprecated (picker removed)
  String? _baseUnit; // optional; can be set later via Purchase Items screen

  @override
  void initState() {
    super.initState();
    _name.text = widget.seedName;
    _receiptName.text = widget.seedName;
  }

  Future<void> _pickMaterial() async {
    // Material picker removed per requirements; keep stub for UI button
    // In future, this could open a dedicated Materials screen.
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final conv = double.tryParse(_convCtrl.text.replaceAll(',', '.')) ?? 1.0;
    final payload = {
      'supplier_id': widget.supplierId,
      'name': _name.text.trim(),
      'receipt_name': _receiptName.text.trim().isNotEmpty ? _receiptName.text.trim() : null,
      if (_selectedMaterial != null) 'material_id': _selectedMaterial!['id'],
      if (_baseUnit != null) 'base_unit': _baseUnit,
      'conversion_ratio': conv,
    };
    final resp = await _supabase.from('purchase_catalog_items').insert(payload).select('*').single();
    if (!mounted) return;
    Navigator.of(context).pop(resp);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Create Purchase Item', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Canonical name', border: OutlineInputBorder()),
                validator: (v) => (v==null||v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _receiptName,
                decoration: const InputDecoration(labelText: 'Receipt name (purchasename)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _pickMaterial,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.category_outlined, size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_selectedMaterial!=null ? (_selectedMaterial!['name'] as String? ?? '') : 'Pick material...')),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(onPressed: _pickMaterial, icon: const Icon(Icons.search), label: const Text('Pick')),
                ],
              ),
              if (_baseUnit != null) ...[
                const SizedBox(height: 8),
                Text('Base unit: $_baseUnit'),
              ],
              const SizedBox(height: 8),
              TextFormField(
                controller: _convCtrl,
                decoration: const InputDecoration(
                  labelText: 'Conversion ratio (base units per 1 receipt unit)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _save, child: const Text('Create')),
              ])
            ],
          ),
        ),
      ),
    );
  }
}
