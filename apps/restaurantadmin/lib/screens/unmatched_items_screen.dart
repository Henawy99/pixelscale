import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'aliases_manager_screen.dart';

class UnmatchedItemsScreen extends StatefulWidget {
  final String brandId;
  const UnmatchedItemsScreen({super.key, required this.brandId});

  @override
  State<UnmatchedItemsScreen> createState() => _UnmatchedItemsScreenState();
}

class _UnmatchedItemsScreenState extends State<UnmatchedItemsScreen> {
  final _supabase = Supabase.instance.client;
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await _supabase
          .from('unmatched_menu_items')
          .select('id, raw_name, created_at')
          .eq('brand_id', widget.brandId)
          .order('created_at', ascending: false)
          .limit(200);
      setState(() { _rows = (res as List).cast<Map<String, dynamic>>(); });
    } catch (e) {
      setState(() { _error = 'Failed to load: $e'; });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  void _openAliases() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AliasesManagerScreen(brandId: widget.brandId),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Unmatched Items'),
        actions: [
          IconButton(icon: const Icon(Icons.sync), onPressed: _loading ? null : _load),
          IconButton(icon: const Icon(Icons.edit_note), onPressed: _openAliases),
        ],
      ),
      body: _loading && _rows.isEmpty
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
                  const Text('Most recent unmatched item names. Add aliases to improve matching.'),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      itemCount: _rows.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final r = _rows[i];
                        return ListTile(
                          title: Text(r['raw_name'] as String),
                          subtitle: Text(r['created_at'] as String),
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

