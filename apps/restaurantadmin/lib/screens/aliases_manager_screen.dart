import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AliasesManagerScreen extends StatefulWidget {
  final String brandId;
  const AliasesManagerScreen({super.key, required this.brandId});

  @override
  State<AliasesManagerScreen> createState() => _AliasesManagerScreenState();
}

class _AliasesManagerScreenState extends State<AliasesManagerScreen> {
  final _supabase = Supabase.instance.client;
  final _aliasCtrl = TextEditingController();
  String? _selectedMenuItemId;
  bool _loading = false;
  List<Map<String, dynamic>> _aliases = [];
  List<Map<String, dynamic>> _menuItems = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final mi = await _supabase.from('menu_items').select('id, name').eq('brand_id', widget.brandId).order('name');
      final al = await _supabase.from('menu_item_aliases').select('id, alias, menu_item_id').eq('brand_id', widget.brandId).order('alias');
      setState(() {
        _menuItems = (mi as List).cast<Map<String, dynamic>>();
        _aliases = (al as List).cast<Map<String, dynamic>>();
      });
    } catch (e) {
      setState(() { _error = 'Failed to load: $e'; });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  Future<void> _addAlias() async {
    if (_selectedMenuItemId == null || _aliasCtrl.text.trim().isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      await _supabase.from('menu_item_aliases').insert({
        'brand_id': widget.brandId,
        'menu_item_id': _selectedMenuItemId,
        'alias': _aliasCtrl.text.trim(),
      });
      _aliasCtrl.clear();
      await _load();
    } catch (e) {
      setState(() { _error = 'Failed to add alias: $e'; });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  Future<void> _deleteAlias(String id) async {
    setState(() { _loading = true; _error = null; });
    try {
      await _supabase.from('menu_item_aliases').delete().eq('id', id);
      await _load();
    } catch (e) {
      setState(() { _error = 'Failed to delete alias: $e'; });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  void dispose() {
    _aliasCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Aliases Manager')),
      body: _loading && _menuItems.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(_error!, style: TextStyle(color: Colors.red[700])),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedMenuItemId,
                          decoration: const InputDecoration(labelText: 'Menu Item'),
                          items: _menuItems
                              .map((mi) => DropdownMenuItem<String>(
                                    value: mi['id'] as String,
                                    child: Text(mi['name'] as String),
                                  ))
                              .toList(),
                          onChanged: (v) => setState(() => _selectedMenuItemId = v),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _aliasCtrl,
                          decoration: const InputDecoration(labelText: 'Alias text (e.g., "Fries", "Liefergeb.")'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _loading ? null : _addAlias,
                        child: Text(_loading ? 'Saving…' : 'Add'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Existing Aliases', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      itemCount: _aliases.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final row = _aliases[i];
                        final alias = row['alias'] as String;
                        final id = row['id'] as String;
                        final miId = row['menu_item_id'] as String;
                        final mi = _menuItems.firstWhere((m) => m['id'] == miId, orElse: () => {'name': 'Unknown'});
                        return ListTile(
                          title: Text(alias),
                          subtitle: Text('→ ${mi['name']}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: _loading ? null : () => _deleteAlias(id),
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

