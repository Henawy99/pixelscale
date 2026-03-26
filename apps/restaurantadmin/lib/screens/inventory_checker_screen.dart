import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InventoryCheckerScreen extends StatefulWidget {
  const InventoryCheckerScreen({super.key});

  @override
  State<InventoryCheckerScreen> createState() => _InventoryCheckerScreenState();
}

class _MaterialRow {
  final String id;
  final String name;
  final String category;
  final String unitOfMeasure;
  final double currentQuantity;
  final double averageUnitCost;
  final String? imageUrl;
  final TextEditingController controller;

  _MaterialRow({
    required this.id,
    required this.name,
    required this.category,
    required this.unitOfMeasure,
    required this.currentQuantity,
    required this.averageUnitCost,
    required this.imageUrl,
    required this.controller,
  });
}

class _InventoryCheckerScreenState extends State<InventoryCheckerScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final currency = NumberFormat.currency(symbol: '€');

  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  List<_MaterialRow> _materials = [];
  double _currentTotalValue = 0.0;
  double _actualTotalValue = 0.0;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  List<_MaterialRow> _filtered() {
    if (_searchQuery.trim().isEmpty) return _materials;
    final q = _searchQuery.toLowerCase();
    return _materials.where((m) =>
      m.name.toLowerCase().contains(q) ||
      m.category.toLowerCase().contains(q)
    ).toList();
  }

  void _fillAllWithCurrent() {
    for (final m in _materials) {
      m.controller.text = m.currentQuantity.toStringAsFixed(2);
    }
    setState(() {
      _actualTotalValue = _calculateActualTotalValue();
    });
  }

  void _setAllToZero() {
    for (final m in _materials) {
      m.controller.text = '0';
    }
    setState(() {
      _actualTotalValue = _calculateActualTotalValue();
    });
  }

  Widget _buildToolsBar() {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      border: const OutlineInputBorder(),
                      hintText: 'Search name or category',
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                              },
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _fillAllWithCurrent,
                  icon: const Icon(Icons.assignment_turned_in_outlined),
                  label: const Text('Use current'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _setAllToZero,
                  icon: const Icon(Icons.cleaning_services_outlined),
                  label: const Text('Set all 0'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
    _loadMaterials();
  }

  @override
  void dispose() {
    for (final m in _materials) {
      m.controller.dispose();
    }
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMaterials() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await _supabase
          .from('material')
          .select('id, name, category, unit_of_measure, current_quantity, average_unit_cost, item_image_url')
          .order('category', ascending: true);

      final List<_MaterialRow> rows = [];
      double currentTotal = 0.0;
      for (var item in (response as List)) {
        final map = item as Map<String, dynamic>;
        final currentQty = (map['current_quantity'] as num?)?.toDouble() ?? 0.0;
        final avgCost = (map['average_unit_cost'] as num?)?.toDouble() ?? 0.0;
        currentTotal += (currentQty > 0 && avgCost > 0) ? currentQty * avgCost : 0.0;
        rows.add(
          _MaterialRow(
            id: map['id'] as String,
            name: map['name'] as String? ?? 'Unnamed',
            category: (map['category'] as String?)?.trim().isNotEmpty == true ? (map['category'] as String) : 'Uncategorized',
            unitOfMeasure: map['unit_of_measure'] as String? ?? '',
            currentQuantity: currentQty,
            averageUnitCost: avgCost,
            imageUrl: map['item_image_url'] as String?,
            controller: TextEditingController(),
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _materials = rows;
        _currentTotalValue = currentTotal;
        _actualTotalValue = _calculateActualTotalValue();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load materials: $e';
        _isLoading = false;
      });
    }
  }

  double _calculateActualTotalValue() {
    double total = 0.0;
    for (final m in _materials) {
      final text = m.controller.text.trim();
      final actualQty = double.tryParse(text.replaceAll(',', '.')) ?? m.currentQuantity;
      if (actualQty > 0 && m.averageUnitCost > 0) {
        total += actualQty * m.averageUnitCost;
      }
    }
    return total;
  }

  bool get _hasAnyChange {
    for (final m in _materials) {
      final text = m.controller.text.trim();
      if (text.isEmpty) continue;
      final actualQty = double.tryParse(text.replaceAll(',', '.'));
      if (actualQty != null && (actualQty - m.currentQuantity).abs() > 1e-6) {
        return true;
      }
    }
    return false;
  }

  Map<String, List<_MaterialRow>> _groupByCategory(List<_MaterialRow> items) {
    final Map<String, List<_MaterialRow>> groups = {};
    for (final m in items) {
      groups.putIfAbsent(m.category, () => []);
      groups[m.category]!.add(m);
    }
    // Sort categories and items for stable display
    for (final list in groups.values) {
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    final sortedKeys = groups.keys.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return {for (final k in sortedKeys) k: groups[k]!};
  }

  Future<void> _saveAdjustments() async {
    if (!_hasAnyChange) return;

    setState(() => _isSaving = true);

    try {
      for (final m in _materials) {
        final text = m.controller.text.trim();
        if (text.isEmpty) continue; // No change
        final actualQty = double.tryParse(text.replaceAll(',', '.'));
        if (actualQty == null) continue;
        final delta = actualQty - m.currentQuantity;
        if (delta.abs() < 1e-6) continue;

        // Update material current quantity
        await _supabase
            .from('material')
            .update({'current_quantity': actualQty})
            .eq('id', m.id);

        // Log correction with value for history
        final valueChange = (delta.abs()) * (m.averageUnitCost);
        await _supabase.from('inventory_log').insert({
          'material_id': m.id,
          'material_name': m.name,
          'change_type': 'CORRECTION',
          'quantity_change': delta,
          'new_quantity_after_change': actualQty,
          'unit_price_paid': m.averageUnitCost, // reuse column to store valuation basis
          'total_price_paid': valueChange, // magnitude of the value change
          'source_details': 'Inventory Checker',
          'user_id': _supabase.auth.currentUser?.id,
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Inventory adjustments saved'), backgroundColor: Colors.green),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save adjustments: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildSummary() {
    final variance = _actualTotalValue - _currentTotalValue;
    final varianceColor = variance < 0 ? Colors.red : (variance > 0 ? Colors.green : Colors.grey[700]);
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.inventory_2_outlined, color: Colors.black87),
                const SizedBox(width: 8),
                const Text('Inventory Summary', style: TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                if (_isSaving) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Current value'),
                Text(currency.format(_currentTotalValue), style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Actual value (entered)'),
                Text(currency.format(_actualTotalValue), style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Variance'),
                Text(
                  (variance >= 0 ? '+' : '') + currency.format(variance),
                  style: TextStyle(fontWeight: FontWeight.bold, color: varianceColor),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    final groups = _groupByCategory(_filtered());
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        _buildToolsBar(),
        _buildSummary(),
        ...groups.entries.map((entry) {
          final category = entry.key;
          final items = entry.value;
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ExpansionTile(
              initiallyExpanded: true,
              title: Text('$category (${items.length})', style: const TextStyle(fontWeight: FontWeight.w600)),
              children: items.map((m) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.grey[200],
                        child: Text(m.name.isNotEmpty ? m.name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.black87)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text('Current: ${m.currentQuantity.toStringAsFixed(2)} ${m.unitOfMeasure}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 110,
                        child: TextField(
                          controller: m.controller,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Actual',
                            hintText: m.currentQuantity.toStringAsFixed(2),
                            isDense: true,
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          ),
                          onChanged: (_) {
                            setState(() {
                              _actualTotalValue = _calculateActualTotalValue();
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          );
        }),
        const SizedBox(height: 80), // space for bottom button
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Checker'),
        actions: [
          TextButton.icon(
            onPressed: _isSaving || !_hasAnyChange ? null : _saveAdjustments,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Error: $_error', style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 8),
                        ElevatedButton(onPressed: _loadMaterials, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : _buildList(),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSaving || !_hasAnyChange ? null : _saveAdjustments,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Save Adjustments'),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ),
        ),
      ),
    );
  }
}

