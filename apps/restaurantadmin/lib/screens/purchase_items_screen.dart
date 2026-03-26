import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:restaurantadmin/widgets/supplier_picker.dart';

class PurchaseItemsScreen extends StatefulWidget {
  const PurchaseItemsScreen({super.key});
  @override
  State<PurchaseItemsScreen> createState() => _PurchaseItemsScreenState();
}

class _PurchaseItemsScreenState extends State<PurchaseItemsScreen> {
  final _supabase = Supabase.instance.client;
  String? _supplierId;
  String? _supplierName;
  bool _loading = false;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
  }

  Future<void> _load() async {
    if (_supplierId == null) return;
    setState(() => _loading = true);
    try {
      final resp = await _supabase
          .from('purchase_catalog_items')
          .select(
            'id, name, receipt_name, unit, default_quantity, is_fixed_quantity, fixed_quantity_base_units, material_id, material_id(name, unit_of_measure), base_unit, conversion_ratio, notes',
          )
          .eq('supplier_id', _supplierId!)
          .order('name');
      setState(() => _items = (resp as List).cast<Map<String, dynamic>>());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Load error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createOrEdit({Map<String, dynamic>? row}) async {
    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) =>
          _PurchaseItemEditorDialog(supplierId: _supplierId!, initial: row),
    );
    if (result != null) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Purchase Items')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SupplierPicker(
              onSelected: (id, name) async {
                setState(() {
                  _supplierId = id;
                  _supplierName = name;
                });
                await _load();
              },
              onCreateSupplier: (name, rules) async {
                final resp = await _supabase
                    .from('suppliers')
                    .insert({'name': name, 'ai_rules': rules})
                    .select('id, name')
                    .single();
                setState(() {
                  _supplierId = resp['id'] as String;
                  _supplierName = resp['name'] as String;
                });
                await _load();
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: (_supplierId == null)
                      ? null
                      : () => _createOrEdit(),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Purchase Item'),
                ),
                const SizedBox(width: 12),
                if (_supplierName != null)
                  Text(
                    'Supplier: $_supplierName',
                    style: const TextStyle(color: Colors.grey),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : (_supplierId == null)
                  ? const Center(child: Text('Select a supplier to view items'))
                  : _items.isEmpty
                  ? const Center(child: Text('No purchase items yet'))
                  : ListView.separated(
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) {
                        final r = _items[i];
                        final mat = r['material_id'] as Map<String, dynamic>?;
                        return Card(
                          child: ListTile(
                            title: Text(r['name'] as String? ?? ''),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Receipt name: ${r['receipt_name'] ?? '-'}',
                                ),
                                Text(
                                  'Unit: ${r['unit'] ?? '-'} • Default qty: ${r['default_quantity'] ?? '-'}',
                                ),
                                Text(
                                  'Fixed qty: ${r['is_fixed_quantity'] == true ? (r['fixed_quantity_base_units']?.toString() ?? 'yes') : 'no'}',
                                ),
                                Text(
                                  'Material: ${mat != null ? (mat['name'] ?? '-') : '-'}',
                                ),
                                if (r['conversion_ratio'] != null)
                                  Text(
                                    'Conversion: ${r['conversion_ratio']} x base ${r['base_unit'] ?? ''}',
                                  ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _createOrEdit(row: r),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PurchaseItemEditorDialog extends StatefulWidget {
  final String supplierId;
  final Map<String, dynamic>? initial;
  const _PurchaseItemEditorDialog({required this.supplierId, this.initial});
  @override
  State<_PurchaseItemEditorDialog> createState() =>
      _PurchaseItemEditorDialogState();
}

class _PurchaseItemEditorDialogState extends State<_PurchaseItemEditorDialog> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _receiptName = TextEditingController();
  final _unit = TextEditingController();
  final _defaultQty = TextEditingController();
  String? _materialId;
  String? _materialName;
  String? _baseUnit;
  final _conv = TextEditingController();
  bool _isFixed = false;
  final _fixedQty = TextEditingController();

  final _notes = TextEditingController();

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    if (init != null) {
      _name.text = (init['name'] ?? '').toString();
      _receiptName.text = (init['receipt_name'] ?? '').toString();
      _unit.text = (init['unit'] ?? '').toString();
      _defaultQty.text = (init['default_quantity']?.toString() ?? '');
      _isFixed = (init['is_fixed_quantity'] == true);
      _fixedQty.text = (init['fixed_quantity_base_units']?.toString() ?? '');
      final mat = init['material_id'] as Map<String, dynamic>?;
      if (mat != null) {
        _materialId =
            mat['id'] as String?; // note: only id if selected('id, name,...')
        _materialName = mat['name'] as String?;
        _baseUnit = mat['unit_of_measure'] as String?;
      }
      _baseUnit ??= (init['base_unit'] ?? '') as String?;
      _conv.text = (init['conversion_ratio']?.toString() ?? '');
      _notes.text = (init['notes'] ?? '').toString();
    }
  }

  Future<void> _pickMaterial() async {
    final res = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (ctx) => _MaterialPickerDialog(
        initialQuery: _name.text.isNotEmpty ? _name.text : _receiptName.text,
      ),
    );
    if (res != null) {
      setState(() {
        _materialId = res['id'] as String?;
        _materialName = res['name'] as String?;
        _baseUnit = res['unit_of_measure'] as String? ?? res['unit'] as String?;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final payload = {
      'supplier_id': widget.supplierId,
      'name': _name.text.trim(),
      'receipt_name': _receiptName.text.trim().isNotEmpty
          ? _receiptName.text.trim()
          : null,
      'unit': _unit.text.trim().isNotEmpty ? _unit.text.trim() : null,
      'default_quantity': double.tryParse(
        _defaultQty.text.replaceAll(',', '.'),
      ),
      'material_id': _materialId,
      'is_fixed_quantity': _isFixed,
      'fixed_quantity_base_units': double.tryParse(
        _fixedQty.text.replaceAll(',', '.'),
      ),

      'base_unit': _baseUnit,
      'conversion_ratio': double.tryParse(_conv.text.replaceAll(',', '.')),
      'notes': _notes.text.trim().isNotEmpty ? _notes.text.trim() : null,
    };
    try {
      if (widget.initial == null) {
        await _supabase.from('purchase_catalog_items').insert(payload);
      } else {
        await _supabase
            .from('purchase_catalog_items')
            .update(payload)
            .eq('id', widget.initial!['id'] as String);
      }
      if (!mounted) return;
      Navigator.of(context).pop(payload);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.initial == null
                      ? 'Create Purchase Item'
                      : 'Edit Purchase Item',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'Canonical name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _receiptName,
                  decoration: const InputDecoration(
                    labelText: 'Receipt name (purchasename)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _unit,
                        decoration: const InputDecoration(
                          labelText: 'Unit',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _defaultQty,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Default quantity',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: TextEditingController(
                          text: _materialName ?? '',
                        ),
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Material',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _pickMaterial,
                      icon: const Icon(Icons.search),
                      label: const Text('Pick'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Text('Fixed quantity'),
                          const SizedBox(width: 8),
                          Switch(
                            value: _isFixed,
                            onChanged: (v) => setState(() => _isFixed = v),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _fixedQty,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Fixed qty (base units)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: TextEditingController(
                          text: _baseUnit ?? '',
                        ),
                        onChanged: (v) => _baseUnit = v,
                        decoration: const InputDecoration(
                          labelText: 'Base unit',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _conv,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Conversion ratio',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _notes,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(onPressed: _save, child: const Text('Save')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MaterialPickerDialog extends StatefulWidget {
  final String initialQuery;
  const _MaterialPickerDialog({required this.initialQuery});
  @override
  State<_MaterialPickerDialog> createState() => _MaterialPickerDialogState();
}

class _MaterialPickerDialogState extends State<_MaterialPickerDialog> {
  final _supabase = Supabase.instance.client;
  final _controller = TextEditingController();
  List<Map<String, dynamic>> _results = [];

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialQuery;
    _search();
  }

  Future<void> _search() async {
    final q = _controller.text.trim();
    if (q.isEmpty) return;
    final resp = await _supabase
        .from('material')
        .select('id, name, unit_of_measure')
        .ilike('name', '%$q%')
        .limit(25);
    setState(
      () => _results = (resp as List)
          .map((e) => e as Map<String, dynamic>)
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 520,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _controller,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: _search,
                  ),
                  labelText: 'Search materials',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: (_) => _search(),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (ctx, i) {
                    final r = _results[i];
                    return ListTile(
                      title: Text(r['name'] as String? ?? ''),
                      subtitle: Text(r['unit_of_measure'] as String? ?? ''),
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
