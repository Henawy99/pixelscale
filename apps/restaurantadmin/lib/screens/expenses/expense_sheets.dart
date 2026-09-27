import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:restaurantadmin/models/expense.dart';
import 'package:restaurantadmin/screens/expenses/expense_format.dart';
import 'package:restaurantadmin/services/expense_service.dart';

double? _parseNumber(String s) => double.tryParse(s.trim().replaceAll(' ', '').replaceAll(',', '.'));

String _trimNumber(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString().replaceAll('.', ',');

Future<T?> _sheet<T>(BuildContext context, Widget child) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  constraints: const BoxConstraints(maxWidth: 640),
  builder: (_) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
    child: child,
  ),
);

// ------------------------------------------------------------------ materials

/// Result of the material picker: an existing material, or "create a new one".
class MaterialChoice {
  final StockMaterial? material;
  final bool createNew;
  final String query;
  const MaterialChoice.existing(this.material) : createNew = false, query = '';
  const MaterialChoice.create(this.query) : material = null, createNew = true;
}

Future<MaterialChoice?> showMaterialPicker(BuildContext context, List<StockMaterial> materials, {String? hint}) =>
    _sheet(context, _MaterialPicker(materials: materials, hint: hint));

class _MaterialPicker extends StatefulWidget {
  final List<StockMaterial> materials;
  final String? hint;
  const _MaterialPicker({required this.materials, this.hint});

  @override
  State<_MaterialPicker> createState() => _MaterialPickerState();
}

class _MaterialPickerState extends State<_MaterialPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final list = q.isEmpty
        ? widget.materials
        : widget.materials
              .where((m) => m.name.toLowerCase().contains(q) || (m.category ?? '').toLowerCase().contains(q))
              .toList();
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: widget.hint == null ? 'Search materials' : 'Search materials (e.g. ${widget.hint})',
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFEEF2FF),
              child: Icon(Icons.add, color: Color(0xFF4F46E5)),
            ),
            title: Text(
              _query.trim().isEmpty ? 'Create a new material' : 'Create “${_query.trim()}”',
              style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF4F46E5)),
            ),
            onTap: () => Navigator.of(context).pop(MaterialChoice.create(_query.trim())),
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: list.length,
              itemBuilder: (_, i) {
                final m = list[i];
                return ListTile(
                  title: Text(m.name),
                  subtitle: Text(
                    '${m.category ?? 'No category'} · in stock ${formatQuantity(m.currentQuantity, m.unit)}',
                  ),
                  trailing: Text(unitLabel(m.unit), style: const TextStyle(color: Color(0xFF6B7280))),
                  onTap: () => Navigator.of(context).pop(MaterialChoice.existing(m)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

Future<StockMaterial?> showCreateMaterial(
  BuildContext context,
  ExpenseService service, {
  String? name,
  String? unit,
  String? category,
}) => _sheet(context, _CreateMaterial(service: service, name: name, unit: unit, category: category));

class _CreateMaterial extends StatefulWidget {
  final ExpenseService service;
  final String? name;
  final String? unit;
  final String? category;
  const _CreateMaterial({required this.service, this.name, this.unit, this.category});

  @override
  State<_CreateMaterial> createState() => _CreateMaterialState();
}

class _CreateMaterialState extends State<_CreateMaterial> {
  late final TextEditingController _name = TextEditingController(text: widget.name ?? '');
  final TextEditingController _alert = TextEditingController();
  late String _unit = ExpenseService.materialUnits.contains(widget.unit) ? widget.unit! : 'gram';
  late String? _category = ExpenseService.materialCategories.contains(widget.category) ? widget.category : null;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _alert.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _category == null) {
      setState(() => _error = 'Enter a name and choose a category.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final m = await widget.service.createMaterial(
        name: _name.text,
        unit: _unit,
        category: _category!,
        alertBelow: _parseNumber(_alert.text),
      );
      if (mounted) Navigator.of(context).pop(m);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = 'Could not create the material: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('New material', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text(
            'It will show up in your inventory and future invoices are matched to it.',
            style: TextStyle(color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Name'),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 16),
          const Text('Counted in', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'gram', label: Text('Grams')),
              ButtonSegment(value: 'ml', label: Text('Millilitres')),
              ButtonSegment(value: 'piece', label: Text('Pieces')),
            ],
            selected: {_unit},
            onSelectionChanged: (s) => setState(() => _unit = s.first),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Category'),
            items: [
              for (final c in ExpenseService.materialCategories)
                DropdownMenuItem(value: c, child: Text(c[0] + c.substring(1).toLowerCase())),
            ],
            onChanged: (v) => setState(() => _category = v),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _alert,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Warn me when stock is below (optional)',
              suffixText: unitLabel(_unit),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Color(0xFFDC2626))),
          ],
          const SizedBox(height: 20),
          SizedBox(
            height: 50,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Text('Create material', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ one line

/// Edit how one invoice line goes into stock. Returns the new decision, or null when cancelled.
Future<LineDecision?> showLineEditor(
  BuildContext context, {
  required ExpenseService service,
  required ExpenseLine line,
  required LineDecision decision,
  required List<StockMaterial> materials,
  required void Function(StockMaterial created) onMaterialCreated,
}) => _sheet(
  context,
  _LineEditor(
    service: service,
    line: line,
    decision: decision,
    materials: materials,
    onMaterialCreated: onMaterialCreated,
  ),
);

class _LineEditor extends StatefulWidget {
  final ExpenseService service;
  final ExpenseLine line;
  final LineDecision decision;
  final List<StockMaterial> materials;
  final void Function(StockMaterial created) onMaterialCreated;

  const _LineEditor({
    required this.service,
    required this.line,
    required this.decision,
    required this.materials,
    required this.onMaterialCreated,
  });

  @override
  State<_LineEditor> createState() => _LineEditorState();
}

class _LineEditorState extends State<_LineEditor> {
  late String? _materialId = widget.decision.materialId;
  late bool _stock = widget.decision.stock;
  late final TextEditingController _conv = TextEditingController(
    text: widget.decision.conversionRatio == null ? '' : _trimNumber(widget.decision.conversionRatio!),
  );
  late final List<StockMaterial> _materials = List.of(widget.materials);

  StockMaterial? get _material => _materialId == null ? null : _materials.where((m) => m.id == _materialId).firstOrNull;

  @override
  void dispose() {
    _conv.dispose();
    super.dispose();
  }

  Future<void> _chooseMaterial() async {
    final choice = await showMaterialPicker(context, _materials, hint: widget.line.suggestion?.name);
    if (choice == null || !mounted) return;
    StockMaterial? picked = choice.material;
    if (choice.createNew) {
      final s = widget.line.suggestion;
      picked = await showCreateMaterial(
        context,
        widget.service,
        name: choice.query.isNotEmpty ? choice.query : (s?.name ?? widget.line.rawName),
        unit: s?.unit,
        category: s?.category,
      );
      if (picked == null) return;
      _materials.add(picked);
      widget.onMaterialCreated(picked);
    }
    setState(() {
      _materialId = picked!.id;
      _stock = true;
      final c = conversionFromContent(widget.line.contentPerUnit, widget.line.contentUnit, picked.unit);
      if (c != null) _conv.text = _trimNumber(c);
    });
  }

  @override
  Widget build(BuildContext context) {
    final line = widget.line;
    final m = _material;
    final conv = _parseNumber(_conv.text);
    final added = (m != null && conv != null && line.quantity != null) ? line.quantity! * conv : null;
    final purchased = line.unit ?? 'unit';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(line.rawName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            '${quantityText(line.quantity)} × $purchased · ${formatMoney(line.totalPrice)}',
            style: const TextStyle(color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Add to stock', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
              _stock ? 'The quantity goes into the inventory' : 'Only kept on the expense (e.g. deposit, fees)',
            ),
            value: _stock,
            onChanged: (v) => setState(() => _stock = v),
          ),
          if (_stock) ...[
            const SizedBox(height: 8),
            const Text('Material', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            OutlinedButton(
              onPressed: _chooseMaterial,
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(14), alignment: Alignment.centerLeft),
              child: Row(
                children: [
                  Icon(m == null ? Icons.add_circle_outline : Icons.inventory_2_outlined, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(m?.name ?? 'Choose or create a material', style: const TextStyle(fontSize: 15))),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
            if (m != null) ...[
              const SizedBox(height: 16),
              const Text('Pack size', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text('1 $purchased =', style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 130,
                    child: TextField(
                      controller: _conv,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(isDense: true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(unitLabel(m.unit), style: const TextStyle(fontSize: 16)),
                ],
              ),
              if (line.contentPerUnit != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Read on the invoice: ${_trimNumber(line.contentPerUnit!)} ${line.contentUnit ?? ''} per $purchased',
                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF6B7280)),
                ),
              ],
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: added == null ? const Color(0xFFFFFBEB) : const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  added == null
                      ? 'Enter how many ${unitLabel(m.unit)} are in one $purchased.'
                      : '${formatQuantity(added, m.unit, signed: true)} → ${m.name} (now ${formatQuantity(m.currentQuantity, m.unit)})',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: added == null ? const Color(0xFF92400E) : const Color(0xFF065F46),
                  ),
                ),
              ),
            ],
          ],
          const SizedBox(height: 20),
          SizedBox(
            height: 50,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(
                LineDecision(
                  materialId: _stock ? _materialId : widget.decision.materialId,
                  conversionRatio: _stock ? conv : widget.decision.conversionRatio,
                  stock: _stock,
                ),
              ),
              child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ suppliers

Future<SupplierOption?> showSupplierPicker(BuildContext context, List<SupplierOption> suppliers) =>
    _sheet(context, _SupplierPicker(suppliers: suppliers));

class _SupplierPicker extends StatefulWidget {
  final List<SupplierOption> suppliers;
  const _SupplierPicker({required this.suppliers});

  @override
  State<_SupplierPicker> createState() => _SupplierPickerState();
}

class _SupplierPickerState extends State<_SupplierPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.toLowerCase();
    final list = widget.suppliers.where((s) => s.name.toLowerCase().contains(q)).toList();
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Search suppliers', prefixIcon: Icon(Icons.search)),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                for (final s in list)
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: supplierColor(s.name).withValues(alpha: 0.12),
                      child: Text(
                        initials(s.name),
                        style: TextStyle(color: supplierColor(s.name), fontWeight: FontWeight.w700),
                      ),
                    ),
                    title: Text(s.name),
                    subtitle: s.city == null ? null : Text(s.city!),
                    onTap: () => Navigator.of(context).pop(s),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<SupplierOption?> showCreateSupplier(
  BuildContext context,
  ExpenseService service,
  Map<String, dynamic>? detected,
) => _sheet(context, _CreateSupplier(service: service, detected: detected ?? const {}));

class _CreateSupplier extends StatefulWidget {
  final ExpenseService service;
  final Map<String, dynamic> detected;
  const _CreateSupplier({required this.service, required this.detected});

  @override
  State<_CreateSupplier> createState() => _CreateSupplierState();
}

class _CreateSupplierState extends State<_CreateSupplier> {
  late final Map<String, TextEditingController> _c = {
    for (final k in ['name', 'address', 'postcode', 'city', 'phone', 'email', 'vat_id', 'website'])
      k: TextEditingController(text: widget.detected[k] as String? ?? ''),
  };
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_c['name']!.text.trim().isEmpty) {
      setState(() => _error = 'Enter the supplier name.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final s = await widget.service.createSupplier(
        name: _c['name']!.text,
        street: _c['address']!.text,
        postcode: _c['postcode']!.text,
        city: _c['city']!.text,
        phone: _c['phone']!.text,
        email: _c['email']!.text,
        vatId: _c['vat_id']!.text,
        website: _c['website']!.text,
      );
      if (mounted) Navigator.of(context).pop(s);
    } catch (e) {
      final text = e.toString();
      setState(() {
        _saving = false;
        _error = text.contains('suppliers_name_key')
            ? 'A supplier with this name already exists. Pick it from the list instead.'
            : 'Could not create the supplier: $text';
      });
    }
  }

  Widget _field(String key, String label, {TextInputType? type}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: _c[key],
      keyboardType: type,
      decoration: InputDecoration(labelText: label),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('New supplier', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text(
            'Filled in from the invoice. Next time this supplier is recognised automatically.',
            style: TextStyle(color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 16),
          _field('name', 'Name'),
          _field('address', 'Street'),
          Row(
            children: [
              SizedBox(width: 110, child: _field('postcode', 'Postcode', type: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(child: _field('city', 'City')),
            ],
          ),
          _field('phone', 'Phone', type: TextInputType.phone),
          _field('email', 'Email', type: TextInputType.emailAddress),
          _field('vat_id', 'VAT ID (UID)'),
          _field('website', 'Website', type: TextInputType.url),
          if (_error != null) ...[
            Text(_error!, style: const TextStyle(color: Color(0xFFDC2626))),
            const SizedBox(height: 12),
          ],
          SizedBox(
            height: 50,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Text('Create supplier', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ document

/// Full-screen, zoomable view of the scanned pages.
class ExpenseDocumentViewer extends StatelessWidget {
  final List<String> urls;
  final List<String> paths;
  final int initialPage;
  const ExpenseDocumentViewer({super.key, required this.urls, required this.paths, this.initialPage = 0});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: const Text('Invoice')),
      body: ExpenseDocumentPages(urls: urls, paths: paths, initialPage: initialPage, dark: true),
    );
  }
}

/// Swipeable, zoomable pages (images) or an "open PDF" card.
class ExpenseDocumentPages extends StatelessWidget {
  final List<String> urls;
  final List<String> paths;
  final int initialPage;
  final bool dark;
  const ExpenseDocumentPages({
    super.key,
    required this.urls,
    required this.paths,
    this.initialPage = 0,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) return const Center(child: Text('No document'));
    return PageView.builder(
      controller: PageController(initialPage: initialPage),
      itemCount: urls.length,
      itemBuilder: (_, i) {
        final isPdf = paths.length > i && paths[i].toLowerCase().endsWith('.pdf');
        if (isPdf) {
          return Center(
            child: FilledButton.icon(
              onPressed: () => launchUrl(Uri.parse(urls[i]), mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.picture_as_pdf_rounded),
              label: const Text('Open PDF'),
            ),
          );
        }
        return InteractiveViewer(
          maxScale: 5,
          child: Center(
            child: Image.network(
              urls[i],
              fit: BoxFit.contain,
              loadingBuilder: (_, child, p) => p == null ? child : const Center(child: CircularProgressIndicator()),
              errorBuilder: (_, __, ___) =>
                  Icon(Icons.broken_image_outlined, size: 48, color: dark ? Colors.white54 : Colors.grey),
            ),
          ),
        );
      },
    );
  }
}
