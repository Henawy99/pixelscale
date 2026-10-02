import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:restaurantadmin/models/expense.dart';
import 'package:restaurantadmin/screens/expenses/expense_capture_screen.dart';
import 'package:restaurantadmin/screens/expenses/expense_format.dart';
import 'package:restaurantadmin/screens/expenses/expense_review_screen.dart';
import 'package:restaurantadmin/screens/suppliers_screen.dart';
import 'package:restaurantadmin/services/expense_service.dart';

/// Expenses tab: every scanned supplier invoice, and the camera button to scan the next one.
class ExpensesScreen extends StatefulWidget {
  /// Injectable for previews and tests; defaults to the live Supabase service.
  final ExpenseService? service;
  const ExpensesScreen({super.key, this.service});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

enum _Filter { all, toReview, inStock }

class _ExpensesScreenState extends State<ExpensesScreen> {
  late final ExpenseService _service = widget.service ?? ExpenseService();
  List<Expense> _expenses = [];
  bool _loading = true;
  String? _error;
  _Filter _filter = _Filter.all;
  RealtimeChannel? _channel;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
    _channel = _service.watchExpenses(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 600), _load);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    if (_channel != null) _service.stopWatching(_channel!);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      // Newest invoice date first, so the month groups are in order.
      final list = (await _service.fetchExpenses())
        ..sort((a, b) {
          final byDate = b.date.compareTo(a.date);
          return byDate != 0 ? byDate : b.createdAt.compareTo(a.createdAt);
        });
      if (!mounted) return;
      setState(() {
        _expenses = list;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load expenses: $e';
      });
    }
  }

  bool get _isPhone =>
      !kIsWeb &&
      (Theme.of(context).platform == TargetPlatform.android || Theme.of(context).platform == TargetPlatform.iOS);

  Future<void> _scan() async {
    // On a phone, ask where the invoice comes from: camera, photo library or a file (PDF).
    CaptureSource? start;
    if (_isPhone) {
      start = await _chooseSource();
      if (start == null || !mounted) return;
    }
    final expenseId = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => ExpenseCaptureScreen(service: _service, start: start),
        fullscreenDialog: true,
      ),
    );
    await _load();
    if (expenseId != null && mounted) _open(expenseId);
  }

  Future<CaptureSource?> _chooseSource() => showModalBottomSheet<CaptureSource>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      Widget option(CaptureSource source, IconData icon, String title, String subtitle) => ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFEEF2FF),
          child: Icon(icon, color: const Color(0xFF4F46E5)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        onTap: () => Navigator.pop(ctx, source),
      );
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Add an invoice', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ),
              ),
              option(CaptureSource.camera, Icons.photo_camera_rounded, 'Take photo', 'Photograph the invoice now'),
              option(CaptureSource.photos, Icons.photo_library_rounded, 'Choose from Photos', 'Pick one or more pages'),
              option(CaptureSource.files, Icons.upload_file_rounded, 'PDF or other file', 'From Files, e-mail downloads…'),
            ],
          ),
        ),
      );
    },
  );

  Future<void> _open(String expenseId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExpenseReviewScreen(expenseId: expenseId, service: _service),
      ),
    );
    _load();
  }

  List<Expense> get _visible => switch (_filter) {
    _Filter.all => _expenses,
    _Filter.toReview => _expenses.where((e) => e.needsReview || e.isFailed || e.isAnalyzing).toList(),
    _Filter.inStock => _expenses.where((e) => e.isBooked).toList(),
  };

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final thisMonth = _expenses.where((e) => e.date.year == now.year && e.date.month == now.month && !e.isFailed);
    final monthTotal = thisMonth.fold<double>(0, (s, e) => s + (e.totalAmount ?? e.netAmount ?? 0));
    final toReview = _expenses.where((e) => e.needsReview || e.isFailed).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SuppliersScreen())),
            icon: const Icon(Icons.storefront_outlined, size: 20),
            label: const Text('Suppliers'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.large(
        onPressed: _scan,
        tooltip: 'Scan an invoice',
        backgroundColor: const Color(0xFF4F46E5),
        foregroundColor: Colors.white,
        child: const Icon(Icons.photo_camera_rounded, size: 34),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: _StatCard(
                                  label: 'Spent in ${DateFormat('MMMM').format(now)}',
                                  value: formatMoney(monthTotal),
                                  detail: '${thisMonth.length} ${thisMonth.length == 1 ? 'invoice' : 'invoices'}',
                                  color: const Color(0xFF4F46E5),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _StatCard(
                                  label: 'To review',
                                  value: '$toReview',
                                  detail: toReview == 0 ? 'All booked' : 'Tap to check and book',
                                  color: toReview == 0 ? const Color(0xFF059669) : const Color(0xFFD97706),
                                  onTap: toReview == 0 ? null : () => setState(() => _filter = _Filter.toReview),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                          child: Wrap(
                            spacing: 8,
                            children: [
                              for (final f in _Filter.values)
                                ChoiceChip(
                                  label: Text(switch (f) {
                                    _Filter.all => 'All',
                                    _Filter.toReview => 'To review',
                                    _Filter.inStock => 'In stock',
                                  }),
                                  selected: _filter == f,
                                  onSelected: (_) => setState(() => _filter = f),
                                ),
                            ],
                          ),
                        ),
                      ),
                      if (_error != null)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(_error!, style: const TextStyle(color: Color(0xFFDC2626))),
                          ),
                        ),
                      if (_visible.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _EmptyState(onScan: _scan, filtered: _filter != _Filter.all),
                        )
                      else
                        ..._groupedSlivers(),
                      const SliverToBoxAdapter(child: SizedBox(height: 120)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  /// Month headers with their expenses.
  List<Widget> _groupedSlivers() {
    final groups = <String, List<Expense>>{};
    for (final e in _visible) {
      groups.putIfAbsent(DateFormat('MMMM yyyy').format(e.date), () => []).add(e);
    }
    return [
      for (final entry in groups.entries) ...[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
            child: Row(
              children: [
                Text(
                  entry.key,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)),
                ),
                const Spacer(),
                Text(
                  formatMoney(
                    entry.value
                        .where((e) => !e.isFailed)
                        .fold<double>(0, (s, e) => s + (e.totalAmount ?? e.netAmount ?? 0)),
                  ),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
        ),
        SliverList.builder(
          itemCount: entry.value.length,
          itemBuilder: (_, i) => _ExpenseTile(expense: entry.value[i], onTap: () => _open(entry.value[i].id)),
        ),
      ],
    ];
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String detail;
  final Color color;
  final VoidCallback? onTap;

  const _StatCard({required this.label, required this.value, required this.detail, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color),
              ),
              const SizedBox(height: 2),
              Text(detail, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  final Expense expense;
  final VoidCallback onTap;

  const _ExpenseTile({required this.expense, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final style = expenseStatusStyle(expense.displayStatus);
    final name =
        expense.supplierName ??
        (expense.isAnalyzing
            ? 'Reading invoice…'
            : expense.isFailed
            ? 'Scanned invoice'
            : (expense.detectedSupplier?['name'] as String? ?? 'Unknown supplier'));
    final details = [
      if (expense.invoiceNumber != null) 'No. ${expense.invoiceNumber}',
      formatDate(expense.date),
      if (expense.lineCount > 0) '${expense.lineCount} ${expense.lineCount == 1 ? 'item' : 'items'}',
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: (expense.isFailed && expense.supplierName == null ? style.color : supplierColor(name))
                    .withValues(alpha: 0.12),
                child: expense.isAnalyzing
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : expense.isFailed && expense.supplierName == null
                    ? Icon(Icons.description_outlined, color: style.color)
                    : Text(
                        initials(name),
                        style: TextStyle(color: supplierColor(name), fontWeight: FontWeight.w800, fontSize: 15),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      details,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatMoney(expense.totalAmount ?? expense.netAmount),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: style.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(style.icon, size: 12, color: style.color),
                        const SizedBox(width: 4),
                        Text(
                          style.label,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: style.color),
                        ),
                      ],
                    ),
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

class _EmptyState extends StatelessWidget {
  final VoidCallback onScan;
  final bool filtered;
  const _EmptyState({required this.onScan, required this.filtered});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(color: Color(0xFFEEF2FF), shape: BoxShape.circle),
            child: const Icon(Icons.document_scanner_outlined, size: 44, color: Color(0xFF4F46E5)),
          ),
          const SizedBox(height: 16),
          Text(
            filtered ? 'Nothing here' : 'Scan your first invoice',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'Take a photo of a supplier invoice. The items are read automatically, matched to your materials and added to the inventory.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF6B7280)),
          ),
          if (!filtered) ...[
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onScan,
              icon: const Icon(Icons.photo_camera_rounded),
              label: const Text('Scan invoice'),
            ),
          ],
        ],
      ),
    );
  }
}
