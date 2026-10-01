import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import 'package:restaurantadmin/models/expense.dart';
import 'package:restaurantadmin/screens/expenses/expense_format.dart';
import 'package:restaurantadmin/screens/expenses/expense_sheets.dart';
import 'package:restaurantadmin/services/expense_service.dart';

/// Check a scanned invoice and book it into inventory (or view one that is booked).
class ExpenseReviewScreen extends StatefulWidget {
  final String expenseId;
  final ExpenseService? service;
  const ExpenseReviewScreen({super.key, required this.expenseId, this.service});

  @override
  State<ExpenseReviewScreen> createState() => _ExpenseReviewScreenState();
}

class _ExpenseReviewScreenState extends State<ExpenseReviewScreen> {
  late final ExpenseService _service = widget.service ?? ExpenseService();

  Expense? _expense;
  List<ExpenseLine> _lines = [];
  List<StockMaterial> _materials = [];
  List<SupplierOption> _suppliers = [];
  List<String> _urls = [];
  final Map<String, LineDecision> _decisions = {};
  bool _loading = true;
  bool _busy = false;
  String? _error;
  Timer? _poll;

  Map<String, StockMaterial> get _materialById => {for (final m in _materials) m.id: m};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load({bool keepDecisions = false}) async {
    try {
      final results = await Future.wait([
        _service.fetchExpense(widget.expenseId),
        _service.fetchLines(widget.expenseId),
        _service.fetchMaterials(),
        _service.fetchSuppliers(),
      ]);
      final expense = results[0] as Expense;
      final lines = results[1] as List<ExpenseLine>;
      if (_urls.isEmpty && expense.documentPaths.isNotEmpty) {
        _urls = await _service.signedUrls(expense.documentPaths);
      }
      if (!mounted) return;
      setState(() {
        _expense = expense;
        _lines = lines;
        _materials = results[2] as List<StockMaterial>;
        _suppliers = results[3] as List<SupplierOption>;
        for (final l in lines) {
          final existing = _decisions[l.id];
          // A fresh catalog match (e.g. after choosing the supplier) replaces an undecided line.
          if (keepDecisions && existing != null && (existing.isReady || !existing.stock)) continue;
          _decisions[l.id] = LineDecision(
            materialId: l.materialId,
            conversionRatio: l.conversionRatio,
            // Products are meant for stock (they need attention until matched); deposits, fees etc. are not.
            stock: expense.isBooked ? l.booked : (l.isProduct || l.stock),
          );
        }
        _loading = false;
        _error = null;
      });
      // Still being read (e.g. opened from the list right after scanning): check again shortly.
      _poll?.cancel();
      if (expense.isAnalyzing) _poll = Timer(const Duration(seconds: 3), () => _load());
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load this expense: $e';
        });
      }
    }
  }

  // ------------------------------------------------------------ actions

  Future<void> _run(Future<void> Function() action, {String? success}) async {
    setState(() => _busy = true);
    try {
      await action();
      if (success != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success)));
      }
    } catch (e) {
      if (mounted) {
        final msg = e is ExpenseException ? e.message : (e is PostgrestException ? e.message : e.toString());
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: const Color(0xFFDC2626)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _assignSupplier(SupplierOption supplier) => _run(() async {
    await _service.assignSupplier(widget.expenseId, supplier.id);
    await _load(keepDecisions: true);
  }, success: 'Supplier set to ${supplier.name}');

  Future<void> _createSupplier() async {
    final created = await showCreateSupplier(context, _service, _expense?.detectedSupplier);
    if (created != null) await _assignSupplier(created);
  }

  Future<void> _pickSupplier() async {
    final picked = await showSupplierPicker(context, _suppliers);
    if (picked != null) await _assignSupplier(picked);
  }

  Future<void> _editLine(ExpenseLine line) async {
    final updated = await showLineEditor(
      context,
      service: _service,
      line: line,
      decision: _decisions[line.id]!,
      materials: _materials,
      onMaterialCreated: (m) =>
          setState(() => _materials = [..._materials, m]..sort((a, b) => a.name.compareTo(b.name))),
    );
    if (updated != null) setState(() => _decisions[line.id] = updated);
  }

  Future<void> _createMaterialFor(ExpenseLine line) async {
    final s = line.suggestion;
    final created = await showCreateMaterial(
      context,
      _service,
      name: s?.name ?? line.rawName,
      unit: s?.unit,
      category: s?.category,
    );
    if (created == null) return;
    setState(() {
      _materials = [..._materials, created]..sort((a, b) => a.name.compareTo(b.name));
      final d = _decisions[line.id]!;
      d.materialId = created.id;
      d.stock = true;
      d.conversionRatio = conversionFromContent(line.contentPerUnit, line.contentUnit, created.unit);
    });
    // No pack size on the invoice: ask for it right away.
    if (_decisions[line.id]!.conversionRatio == null && mounted) await _editLine(line);
  }

  Future<void> _book() async {
    final e = _expense!;
    final products = _lines.where((l) => _decisions[l.id]!.stock);
    final missing = products.where((l) => !_decisions[l.id]!.isReady).toList();
    if (missing.isNotEmpty) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('${missing.length} ${missing.length == 1 ? 'item is' : 'items are'} not ready'),
          content: Text(
            '${missing.map((l) => '• ${l.rawName}').take(6).join('\n')}\n\n'
            'These have no material or pack size yet and will not be added to stock.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Go back')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Book the rest')),
          ],
        ),
      );
      if (ok != true) return;
    }

    List<Map<String, dynamic>> changes = [];
    await _run(() async {
      changes = await _service.book(e.id, _decisions);
      await _load();
    });
    if (!mounted || _expense?.isBooked != true) return;
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 28),
                  SizedBox(width: 10),
                  Text('Added to inventory', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.5),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final c in changes)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          c['material'] as String? ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          'Now ${formatQuantity((c['new_quantity'] as num).toDouble(), c['unit'] as String? ?? '')}',
                        ),
                        trailing: Text(
                          formatQuantity((c['change'] as num).toDouble(), c['unit'] as String? ?? '', signed: true),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: (c['change'] as num) >= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _reopenForStock() async {
    final ok = await _confirm(
      'Add this invoice to stock?',
      'It is from ${formatDate(_expense!.date)}. Only do this if these goods are still in the kitchen — '
          'otherwise your stock count would be too high.',
      'Review for stock',
    );
    if (!ok) return;
    await _run(() async {
      await _service.reopenForStock(widget.expenseId);
      await _load();
    });
  }

  Future<void> _unbook() async {
    final ok = await _confirm(
      'Undo booking?',
      'The quantities from this invoice are taken out of the inventory again.',
      'Undo booking',
    );
    if (!ok) return;
    await _run(() async {
      await _service.unbook(widget.expenseId);
      await _load();
    }, success: 'Booking undone');
  }

  Future<void> _reread() async {
    final ok = await _confirm(
      'Read the invoice again?',
      'Changes you made on this screen will be replaced.',
      'Read again',
    );
    if (!ok) return;
    setState(() => _expense = _expense == null ? null : Expense.fromJson({..._rawForStatus('analyzing')}));
    await _run(() async {
      await _service.reanalyze(widget.expenseId);
      _decisions.clear();
      await _load();
    });
    await _load();
  }

  Future<void> _delete() async {
    final ok = await _confirm(
      'Delete this expense?',
      'The scan and its lines are removed. Stock is not affected.',
      'Delete',
    );
    if (!ok) return;
    await _run(() async {
      await _service.delete(_expense!);
      if (mounted) Navigator.of(context).pop();
    });
  }

  Map<String, dynamic> _rawForStatus(String status) => {
    'id': _expense!.id,
    'created_at': _expense!.createdAt.toIso8601String(),
    'updated_at': DateTime.now().toIso8601String(),
    'status': status,
    'document_paths': _expense!.documentPaths,
  };

  Future<bool> _confirm(String title, String body, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(action)),
          ],
        ),
      ) ??
      false;

  // ------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final e = _expense;
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text(e?.supplierName ?? (e?.isAnalyzing == true ? 'Reading invoice' : 'Invoice')),
        actions: [
          if (e != null && !e.isAnalyzing)
            PopupMenuButton<String>(
              onSelected: (v) => switch (v) {
                'reread' => _reread(),
                'unbook' => _unbook(),
                'delete' => _delete(),
                _ => null,
              },
              itemBuilder: (_) => [
                if (!e.isBooked && !e.isRecorded && e.documentPaths.isNotEmpty)
                  const PopupMenuItem(
                    value: 'reread',
                    child: ListTile(leading: Icon(Icons.refresh), title: Text('Read again')),
                  ),
                if (e.isBooked)
                  const PopupMenuItem(
                    value: 'unbook',
                    child: ListTile(leading: Icon(Icons.undo), title: Text('Undo booking')),
                  ),
                if (!e.isBooked)
                  const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
                      title: Text('Delete'),
                    ),
                  ),
              ],
            ),
        ],
        bottom: _busy ? const PreferredSize(preferredSize: Size.fromHeight(3), child: LinearProgressIndicator()) : null,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : e == null
          ? Center(child: Text(_error ?? 'Not found'))
          : e.isAnalyzing
          ? _ReadingView(urls: _urls, startedAt: e.updatedAt ?? e.createdAt)
          : LayoutBuilder(
              builder: (context, c) {
                final wide = c.maxWidth >= 1000 && _urls.isNotEmpty;
                final details = _details(e, showDocumentStrip: !wide);
                if (!wide) return details;
                return Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: Container(
                        color: const Color(0xFFE5E7EB),
                        child: ExpenseDocumentPages(urls: _urls, paths: e.documentPaths),
                      ),
                    ),
                    Expanded(flex: 6, child: details),
                  ],
                );
              },
            ),
      bottomNavigationBar: e == null || e.isAnalyzing || e.isFailed ? null : _bottomBar(e),
    );
  }

  Widget _details(Expense e, {required bool showDocumentStrip}) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
    children: [
      if (showDocumentStrip && _urls.isNotEmpty) _documentStrip(e),
      // Nothing was read: only the pages and what to do next.
      if (e.isFailed) _failedCard(e) else ..._readContent(e),
    ],
  );

  List<Widget> _readContent(Expense e) {
    final productLines = _lines.where((l) => _decisions[l.id]!.stock).toList();
    final ready = productLines.where((l) => _decisions[l.id]!.isReady).length;
    final attention = productLines.length - ready;
    final skipped = _lines.length - productLines.length;
    return [
      _supplierCard(e),
      for (final w in e.warnings) _warningCard(w),
      _summaryCard(e),
      if (_lines.isNotEmpty) ...[
        const SizedBox(height: 16),
        Row(
          children: [
            Text('Items (${_lines.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const Spacer(),
            if (!e.isBooked && !e.isRecorded) ...[
              _countChip('$ready ready', const Color(0xFF059669)),
              if (attention > 0) ...[
                const SizedBox(width: 6),
                _countChip('$attention to check', const Color(0xFFD97706)),
              ],
              if (skipped > 0) ...[
                const SizedBox(width: 6),
                _countChip('$skipped not stocked', const Color(0xFF6B7280)),
              ],
            ],
          ],
        ),
        const SizedBox(height: 8),
        for (final l in _lines) _lineCard(e, l),
      ],
    ];
  }

  Widget _countChip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
    child: Text(
      text,
      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color),
    ),
  );

  Widget _documentStrip(Expense e) => SizedBox(
    height: 132,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(bottom: 12),
      itemCount: _urls.length,
      separatorBuilder: (_, __) => const SizedBox(width: 10),
      itemBuilder: (_, i) {
        final isPdf = e.documentPaths[i].toLowerCase().endsWith('.pdf');
        return InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ExpenseDocumentViewer(urls: _urls, paths: e.documentPaths, initialPage: i),
            ),
          ),
          borderRadius: BorderRadius.circular(10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 90,
              color: Colors.white,
              child: isPdf
                  ? const Icon(Icons.picture_as_pdf_rounded, size: 40, color: Color(0xFFDC2626))
                  : Image.network(
                      _urls[i],
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.image_outlined),
                    ),
            ),
          ),
        );
      },
    ),
  );

  Widget _failedCard(Expense e) => Card(
    color: const Color(0xFFFEF2F2),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.error_outline, color: Color(0xFFDC2626)),
              SizedBox(width: 8),
              Text(
                'The invoice could not be read',
                style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF991B1B)),
              ),
            ],
          ),
          if (e.failureMessage != null) ...[
            const SizedBox(height: 6),
            Text(
              e.failureMessage!,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF991B1B)),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _busy ? null : _reread,
                icon: const Icon(Icons.refresh),
                label: const Text('Read again'),
              ),
              TextButton(
                onPressed: _busy ? null : _delete,
                style: TextButton.styleFrom(foregroundColor: const Color(0xFF991B1B)),
                child: const Text('Delete scan'),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _supplierCard(Expense e) {
    if (e.supplierId != null) {
      final name = e.supplierName ?? '';
      return Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: supplierColor(name).withValues(alpha: 0.12),
            child: Text(
              initials(name),
              style: TextStyle(color: supplierColor(name), fontWeight: FontWeight.w800),
            ),
          ),
          title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(e.supplierMatchStatus == 'matched' ? 'Supplier recognised' : 'Supplier'),
          trailing: e.isBooked
              ? null
              : TextButton(onPressed: _busy ? null : _pickSupplier, child: const Text('Change')),
        ),
      );
    }

    final seen = e.detectedSupplier ?? const {};
    final detectedName = seen['name'] as String?;
    final seenName = detectedName ?? 'Supplier not readable';
    final address = [
      seen['address'],
      [seen['postcode'], seen['city']].whereType<String>().join(' '),
    ].whereType<String>().where((s) => s.trim().isNotEmpty).join(', ');
    final suggested = e.suggestedSupplierId == null
        ? null
        : _suppliers.where((s) => s.id == e.suggestedSupplierId).firstOrNull;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFFCD34D), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.storefront_outlined, color: Color(0xFFD97706)),
                SizedBox(width: 8),
                Text(
                  'Which supplier is this?',
                  style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF92400E)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(seenName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            if (address.isNotEmpty) Text(address, style: const TextStyle(color: Color(0xFF6B7280))),
            if (seen['vat_id'] != null)
              Text('VAT ID ${seen['vat_id']}', style: const TextStyle(color: Color(0xFF6B7280))),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (suggested != null)
                  FilledButton(
                    onPressed: _busy ? null : () => _assignSupplier(suggested),
                    child: Text('It is ${suggested.name}'),
                  ),
                if (suggested == null)
                  FilledButton.icon(
                    onPressed: _busy ? null : _createSupplier,
                    icon: const Icon(Icons.add),
                    label: Text(detectedName == null ? 'Create new supplier' : 'Create “$detectedName”'),
                  )
                else
                  OutlinedButton(onPressed: _busy ? null : _createSupplier, child: const Text('Create new supplier')),
                OutlinedButton(onPressed: _busy ? null : _pickSupplier, child: const Text('Pick existing')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _warningCard(ExpenseWarning w) => Card(
    color: const Color(0xFFFFFBEB),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            w.code == 'duplicate' ? Icons.copy_all_rounded : Icons.warning_amber_rounded,
            color: const Color(0xFFD97706),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(w.message, style: const TextStyle(color: Color(0xFF92400E))),
          ),
        ],
      ),
    ),
  );

  Widget _summaryCard(Expense e) {
    Widget cell(String label, String value, {bool strong = false}) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(fontSize: strong ? 17 : 15, fontWeight: strong ? FontWeight.w800 : FontWeight.w600),
          ),
        ],
      ),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                cell('Invoice', e.invoiceNumber ?? '–'),
                cell('Date', formatDate(e.date)),
                cell('Status', expenseStatusStyle(e.displayStatus).label),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                cell('Net', formatMoney(e.netAmount)),
                cell('VAT', formatMoney(e.vatAmount)),
                cell('Total', formatMoney(e.totalAmount), strong: true),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _lineCard(Expense e, ExpenseLine l) {
    final d = _decisions[l.id]!;
    final m = d.materialId == null ? null : _materialById[d.materialId];
    final details = [
      if (l.articleNumber != null) 'Art. ${l.articleNumber}',
      '${quantityText(l.quantity)} × ${l.unit ?? 'unit'}${l.unitPrice != null ? ' à ${formatMoney(l.unitPrice)}' : ''}',
      if (l.vatRate != null) '${formatNumber(l.vatRate!, maxDecimals: 1)}% VAT',
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    l.rawName,
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  formatMoney(l.totalPrice),
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: (l.totalPrice ?? 0) < 0 ? const Color(0xFFDC2626) : const Color(0xFF111827),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(details, style: const TextStyle(fontSize: 12.5, color: Color(0xFF6B7280))),
            const SizedBox(height: 10),
            _stockRow(e, l, d, m),
          ],
        ),
      ),
    );
  }

  Widget _stockRow(Expense e, ExpenseLine l, LineDecision d, StockMaterial? m) {
    // History only: show the match, nothing to edit.
    if (e.isRecorded) {
      final conv = d.conversionRatio;
      if (!l.isProduct || m == null) {
        return _statusBox(
          const Color(0xFFF3F4F6),
          Icons.remove_circle_outline,
          const Color(0xFF6B7280),
          l.isProduct ? 'No material matched' : l.kindLabel,
          null,
        );
      }
      return _statusBox(
        const Color(0xFFF3F4F6),
        Icons.inventory_2_outlined,
        const Color(0xFF475569),
        m.name,
        conv == null ? null : '${quantityText(l.quantity)} × ${formatQuantity(conv, m.unit)} (not added to stock)',
      );
    }

    // Booked: show what was added.
    if (e.isBooked) {
      if (!l.booked || m == null || l.baseQuantity == null) {
        return _statusBox(
          const Color(0xFFF3F4F6),
          Icons.remove_circle_outline,
          const Color(0xFF6B7280),
          'Not added to stock',
          l.isProduct ? null : l.kindLabel,
        );
      }
      return _statusBox(
        const Color(0xFFECFDF5),
        Icons.check_circle_rounded,
        const Color(0xFF059669),
        '${formatQuantity(l.baseQuantity!, m.unit, signed: true)} · ${m.name}',
        null,
      );
    }

    if (!d.stock) {
      return _statusBox(
        const Color(0xFFF3F4F6),
        Icons.remove_circle_outline,
        const Color(0xFF6B7280),
        'Not added to stock',
        l.isProduct ? 'Tap to change' : '${l.kindLabel} · tap to change',
        onTap: () => _editLine(l),
      );
    }

    if (m == null) {
      final suggestion = l.suggestion?.name;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(10)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.help_outline_rounded, size: 18, color: Color(0xFFD97706)),
                SizedBox(width: 6),
                Text(
                  'Not in your inventory yet',
                  style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF92400E)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => _createMaterialFor(l),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(suggestion == null ? 'Create material' : 'Create “$suggestion”'),
                ),
                OutlinedButton(onPressed: () => _editLine(l), child: const Text('Pick existing')),
                TextButton(onPressed: () => setState(() => d.stock = false), child: const Text('Don\'t stock')),
              ],
            ),
          ],
        ),
      );
    }

    final conv = d.conversionRatio;
    if (conv == null || conv <= 0) {
      return _statusBox(
        const Color(0xFFFFFBEB),
        Icons.straighten_rounded,
        const Color(0xFFD97706),
        m.name,
        'How much is in 1 ${l.unit ?? 'unit'}? Tap to set the pack size',
        onTap: () => _editLine(l),
      );
    }

    final added = (l.quantity ?? 0) * conv;
    final source = switch (l.materialId == d.materialId && l.conversionRatio == d.conversionRatio
        ? l.matchSource
        : 'manual') {
      'catalog' => 'learned',
      'ai' => 'suggested',
      _ => 'your choice',
    };
    return _statusBox(
      const Color(0xFFEEF2FF),
      Icons.inventory_2_outlined,
      const Color(0xFF4F46E5),
      m.name,
      '1 ${l.unit ?? 'unit'} = ${formatQuantity(conv, m.unit)} · $source',
      trailing: formatQuantity(added, m.unit, signed: true),
      trailingColor: added < 0 ? const Color(0xFFDC2626) : const Color(0xFF059669),
      onTap: () => _editLine(l),
    );
  }

  Widget _statusBox(
    Color background,
    IconData icon,
    Color color,
    String title,
    String? subtitle, {
    String? trailing,
    Color? trailingColor,
    VoidCallback? onTap,
  }) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(fontWeight: FontWeight.w700, color: color),
                    ),
                    if (subtitle != null)
                      Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                  ],
                ),
              ),
              if (trailing != null)
                Text(
                  trailing,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: trailingColor ?? color),
                ),
              if (onTap != null) ...[
                const SizedBox(width: 4),
                const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF9CA3AF)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomBar(Expense e) {
    if (e.isBooked) {
      return SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          color: const Color(0xFFECFDF5),
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF059669)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'In the inventory${e.bookedAt != null ? ' since ${formatDate(e.bookedAt!)}' : ''}',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF065F46)),
                ),
              ),
              TextButton(onPressed: _busy ? null : _unbook, child: const Text('Undo')),
            ],
          ),
        ),
      );
    }
    if (e.isRecorded) {
      return SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          color: const Color(0xFFF1F5F9),
          child: Row(
            children: [
              const Icon(Icons.history_edu_rounded, color: Color(0xFF64748B)),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Recorded for your spending history. Not added to stock.',
                  style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                ),
              ),
              TextButton(onPressed: _busy ? null : _reopenForStock, child: const Text('Add to stock')),
            ],
          ),
        ),
      );
    }
    final ready = _lines.where((l) => _decisions[l.id]!.isReady).length;
    final supplierMissing = e.supplierId == null;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: _narrow(
          SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: _busy || supplierMissing || ready == 0 ? null : _book,
              icon: const Icon(Icons.inventory_rounded),
              label: Text(
                supplierMissing
                    ? 'Choose the supplier first'
                    : ready == 0
                    ? 'Nothing to add yet'
                    : 'Add $ready ${ready == 1 ? 'item' : 'items'} to inventory',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Keeps bottom buttons a comfortable width on a wide screen.
  Widget _narrow(Widget child) => Center(
    heightFactor: 1,
    child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 640), child: child),
  );
}

/// Shown while Gemini reads the invoice (usually well under a minute).
class _ReadingView extends StatefulWidget {
  final List<String> urls;
  final DateTime startedAt;
  const _ReadingView({required this.urls, required this.startedAt});

  @override
  State<_ReadingView> createState() => _ReadingViewState();
}

class _ReadingViewState extends State<_ReadingView> {
  static const _steps = [
    'Finding the supplier…',
    'Reading every line…',
    'Working out pack sizes…',
    'Matching your materials…',
  ];
  late final Timer _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(widget.startedAt).inSeconds.clamp(0, 9999);
    final step = _steps[(elapsed ~/ 4) % _steps.length];
    final slow = elapsed > 60;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.urls.isNotEmpty) ...[
                SizedBox(
                  height: 120,
                  child: ListView.separated(
                    shrinkWrap: true,
                    scrollDirection: Axis.horizontal,
                    itemCount: widget.urls.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, i) => ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 86,
                        color: Colors.white,
                        child: Image.network(
                          widget.urls[i],
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.description_outlined, size: 36, color: Color(0xFF9CA3AF)),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
              ],
              const SizedBox(width: 52, height: 52, child: CircularProgressIndicator(strokeWidth: 5)),
              const SizedBox(height: 22),
              const Text('Reading the invoice', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  step,
                  key: ValueKey(step),
                  style: const TextStyle(fontSize: 15, color: Color(0xFF6B7280)),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                '${elapsed ~/ 60}:${(elapsed % 60).toString().padLeft(2, '0')}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF9CA3AF),
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                slow
                    ? 'Gemini is busy right now, so this takes a bit longer. '
                          'You can go back — the invoice keeps reading and appears under Expenses.'
                    : 'Usually under a minute. You can go back — the invoice keeps reading and appears under Expenses.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF), height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
