import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupplierPicker extends StatefulWidget {
  final void Function(String id, String name) onSelected;
  final Future<void> Function(String name, String rules) onCreateSupplier;
  const SupplierPicker({super.key, required this.onSelected, required this.onCreateSupplier});
  @override
  State<SupplierPicker> createState() => _SupplierPickerState();
}

class _SupplierPickerState extends State<SupplierPicker> {
  final _supabase = Supabase.instance.client;
  final _search = TextEditingController();
  List<Map<String, dynamic>> _suppliers = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final q = _search.text.trim();
    final resp = await _supabase
        .from('suppliers')
        .select('id, name, ai_rules')
        .ilike('name', q.isEmpty ? '%' : '%$q%')
        .order('name');
    setState(() => _suppliers = (resp as List).cast<Map<String, dynamic>>());
  }

  Future<void> _create() async {
    final nameCtrl = TextEditingController();
    final rulesCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Supplier'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Supplier name')),
              const SizedBox(height: 8),
              TextField(controller: rulesCtrl, maxLines: 5, decoration: const InputDecoration(labelText: 'AI Rules (how to parse this supplier receipt)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Create')),
        ],
      ),
    );
    if (ok == true && nameCtrl.text.trim().isNotEmpty) {
      await widget.onCreateSupplier(nameCtrl.text.trim(), rulesCtrl.text);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.store_outlined),
          const SizedBox(width: 6),
          const Text('Supplier'),
          const Spacer(),
          SizedBox(
            width: 240,
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
                hintText: 'Search suppliers',
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _load(),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(onPressed: _create, icon: const Icon(Icons.add), label: const Text('New')),
        ]),
        const SizedBox(height: 6),
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _suppliers.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (ctx, i) {
              final s = _suppliers[i];
              return ActionChip(
                label: Text(s['name'] as String? ?? ''),
                onPressed: () => widget.onSelected(s['id'] as String, s['name'] as String? ?? ''),
              );
            },
          ),
        ),
      ],
    );
  }
}

