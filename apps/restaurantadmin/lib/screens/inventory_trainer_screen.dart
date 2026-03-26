import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:restaurantadmin/widgets/supplier_picker.dart';

class TrainerLine {
  String rawName;
  String? brandName;
  String? itemNumber;
  String receiptUnit;
  // Catalog selection (instead of direct material mapping)
  String? purchaseCatalogItemId;
  String? purchaseCatalogItemName;
  List<Map<String, dynamic>> catalogSuggestions;

  TrainerLine({
    required this.rawName,
    this.brandName,
    this.itemNumber,
    required this.receiptUnit,
    this.purchaseCatalogItemId,
    this.purchaseCatalogItemName,
    this.catalogSuggestions = const [],
  });
}

class InventoryTrainerScreen extends StatefulWidget {
  const InventoryTrainerScreen({super.key});
  @override
  State<InventoryTrainerScreen> createState() => _InventoryTrainerScreenState();
}

class _InventoryTrainerScreenState extends State<InventoryTrainerScreen> {
  final _supabase = Supabase.instance.client;
  String? _supplierId;
  String? _supplierName;
  final _supplierCtrl = TextEditingController();

  Uint8List? _imageBytes;
  String? _fileName;
  // Supplier chosen is required before scan
  String? _wholesalerHint; // deprecated, use _supplierName
  bool _isProcessing = false;
  List<TrainerLine> _lines = [];

  Future<void> _pickImage() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (res == null || res.files.single.bytes == null) return;
    setState(() {
      _imageBytes = res.files.single.bytes;
      _fileName = res.files.single.name;
    });
  }

  Future<void> _scan() async {
    if (_imageBytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Select an image first.')));
      }
      return;
    }
    if (_supplierId == null ||
        (_supplierName == null || _supplierName!.trim().isEmpty)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Choose a supplier first.')),
        );
      }
      return;
    }
    setState(() => _isProcessing = true);
    try {
      final resp = await _supabase.functions.invoke(
        'scan-purchase',
        body: {
          'receiptImageBase64': base64Encode(_imageBytes!),
          'wholesalerHint': _supplierName,
        },
      );
      final data = resp.data as Map<String, dynamic>?;
      if (data == null || data['ok'] != true) {
        throw Exception(data?['error'] ?? 'Scan failed');
      }
      final normalized = data['data'] as Map<String, dynamic>;
      final items = (normalized['items'] as List).cast<Map<String, dynamic>>();
      final lines = items
          .map(
            (m) => TrainerLine(
              rawName: m['raw_name'] as String,
              brandName: m['brand_name'] as String?,
              itemNumber: m['item_number'] as String?,
              receiptUnit: (m['unit'] as String?) ?? '',
              catalogSuggestions:
                  ((m['catalog_suggestions'] as List?)
                      ?.cast<Map<String, dynamic>>()) ??
                  const [],
            ),
          )
          .toList();
      if (mounted) setState(() => _lines = lines);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scan error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _saveMappings() async {
    // In Trainer, selections simply point to existing/created catalog items.
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Selections updated'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _pickCatalogItem(TrainerLine line) async {
    if (_supplierId == null) return;
    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (ctx) => _CatalogItemPickerDialog(
        supplierId: _supplierId!,
        query: line.rawName,
      ),
    );
    if (result != null && mounted) {
      setState(() {
        line.purchaseCatalogItemId = result['id'] as String?;
        line.purchaseCatalogItemName = result['name'] as String?;
      });
    }
  }

  Future<void> _createCatalogItem(TrainerLine line) async {
    if (_supplierId == null) return;
    final created = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (ctx) => _CreatePurchaseItemDialog(
        supplierId: _supplierId!,
        seedName: line.rawName,
        seedUnit: line.receiptUnit,
      ),
    );
    if (created != null && mounted) {
      setState(() {
        line.purchaseCatalogItemId = created['id'] as String?;
        line.purchaseCatalogItemName = created['name'] as String?;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inventory Trainer')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: SupplierPicker(
                    onSelected: (id, name) {
                      setState(() {
                        _supplierId = id;
                        _supplierName = name;
                      });
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
                    },
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.image_search_outlined),
                  label: const Text('Select Image'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _scan,
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Scan'),
                ),
              ],
            ),
            if (_fileName != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _fileName!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            const SizedBox(height: 10),
            Expanded(
              child: _lines.isEmpty
                  ? const Center(
                      child: Text('Scan a receipt to start training.'),
                    )
                  : ListView.builder(
                      itemCount: _lines.length,
                      itemBuilder: (ctx, i) {
                        final l = _lines[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l.rawName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: InkWell(
                                        onTap: () => _pickCatalogItem(l),
                                        child: Row(
                                          children: [
                                            Icon(
                                              l.purchaseCatalogItemId != null
                                                  ? Icons.check_circle
                                                  : Icons.search,
                                              color:
                                                  l.purchaseCatalogItemId !=
                                                      null
                                                  ? Colors.green
                                                  : Colors.grey,
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                l.purchaseCatalogItemName ??
                                                    'Select Purchase Item...',
                                                style: const TextStyle(
                                                  decoration:
                                                      TextDecoration.underline,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    OutlinedButton.icon(
                                      onPressed: () => _createCatalogItem(l),
                                      icon: const Icon(Icons.add),
                                      label: const Text('Create Purchase Item'),
                                    ),

                                    // Removed direct conversion/base unit/material mapping from Trainer.
                                    // Trainer focuses on linking to Purchase Items only.
                                  ],
                                ),
                                if (l.brandName != null || l.itemNumber != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      'Brand: ${l.brandName ?? '-'} • Item#: ${l.itemNumber ?? '-'}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: _saveMappings,
                  child: const Text('Save Mappings'),
                ),
              ],
            ),
          ],
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
        width: 500,
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
                      onTap: () => Navigator.of(context).pop({
                        'id': r['id'] as String,
                        'name': r['name'] as String,
                        'unit': r['unit_of_measure'] as String? ?? '',
                      }),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final created = await showDialog<Map<String, dynamic>?>(
                      context: context,
                      builder: (ctx) =>
                          _CreateMaterialDialog(seedName: _controller.text),
                    );
                    if (created != null) {
                      if (!mounted) return;
                      Navigator.of(context).pop({
                        'id': created['id'] as String,
                        'name': created['name'] as String,
                        'unit': created['unit_of_measure'] as String? ?? '',
                      });
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Create new material'),
                ),
              ),
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
    final resp = await _supabase
        .from('material')
        .insert({
          'name': _name.text.trim(),
          'unit_of_measure': _unit.text.trim(),
          'category': _category.text.trim().isNotEmpty
              ? _category.text.trim()
              : null,
          'current_quantity': 0,
          'average_unit_cost': 0,
        })
        .select('id, name, unit_of_measure')
        .single();
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
              const Text(
                'Create Material',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _unit,
                decoration: const InputDecoration(
                  labelText: 'Unit of measure',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _category,
                decoration: const InputDecoration(
                  labelText: 'Category (optional)',
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
                  ElevatedButton(
                    onPressed: _create,
                    child: const Text('Create'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CatalogItemPickerDialog extends StatefulWidget {
  final String supplierId;
  final String query;
  const _CatalogItemPickerDialog({
    required this.supplierId,
    required this.query,
  });
  @override
  State<_CatalogItemPickerDialog> createState() =>
      _CatalogItemPickerDialogState();
}

class _CatalogItemPickerDialogState extends State<_CatalogItemPickerDialog> {
  final _supabase = Supabase.instance.client;
  final _search = TextEditingController();
  List<Map<String, dynamic>> _results = [];

  @override
  void initState() {
    super.initState();
    _search.text = widget.query;
    _load();
  }

  Future<void> _load() async {
    final q = _search.text.trim();
    final resp = await _supabase
        .from('purchase_catalog_items')
        .select('id, name, receipt_name, unit, material_id, material_id(name)')
        .eq('supplier_id', widget.supplierId)
        .or(
          q.isEmpty
              ? 'id.not.is.null'
              : 'name.ilike.%$q%,receipt_name.ilike.%$q%',
        )
        .limit(25);
    setState(() => _results = (resp as List).cast<Map<String, dynamic>>());
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
                controller: _search,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _load,
                  ),
                  labelText: 'Search Purchase Items',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: (_) => _load(),
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
                      subtitle: Text(
                        'Receipt: ${r['receipt_name'] ?? '-'} • Material: ${mat != null ? (mat['name'] ?? '-') : '-'}',
                      ),
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

class _CreatePurchaseItemDialog extends StatefulWidget {
  final String supplierId;
  final String seedName;
  final String seedUnit;
  const _CreatePurchaseItemDialog({
    required this.supplierId,
    required this.seedName,
    required this.seedUnit,
  });
  @override
  State<_CreatePurchaseItemDialog> createState() =>
      _CreatePurchaseItemDialogState();
}

class _CreatePurchaseItemDialogState extends State<_CreatePurchaseItemDialog> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _receiptName = TextEditingController();
  final _unit = TextEditingController();
  final _notes = TextEditingController();

  @override
  void initState() {
    super.initState();
    _name.text = widget.seedName;
    _receiptName.text = widget.seedName;
    _unit.text = widget.seedUnit;
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
      'notes': _notes.text.trim().isNotEmpty ? _notes.text.trim() : null,
    };
    final resp = await _supabase
        .from('purchase_catalog_items')
        .insert(payload)
        .select('*')
        .single();
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
              const Text(
                'Create Purchase Item',
                style: TextStyle(fontWeight: FontWeight.w600),
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
              TextFormField(
                controller: _unit,
                decoration: const InputDecoration(
                  labelText: 'Unit',
                  border: OutlineInputBorder(),
                ),
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
                  ElevatedButton(onPressed: _save, child: const Text('Create')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
