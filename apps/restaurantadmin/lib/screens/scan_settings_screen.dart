import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ScanSettingsScreen extends StatefulWidget {
  const ScanSettingsScreen({super.key});

  @override
  State<ScanSettingsScreen> createState() => _ScanSettingsScreenState();
}

class _ScanSettingsScreenState extends State<ScanSettingsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _promptController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final row = await _supabase
          .from('app_settings')
          .select('receipt_prompt_hint')
          .maybeSingle();
      _promptController.text = (row?['receipt_prompt_hint'] as String?) ?? '';
    } catch (e) {
      _error = 'Failed to load settings: $e';
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      // Upsert single-row settings. You can add RLS to limit to a single row by policy.
      await _supabase.from('app_settings').upsert({
        'id': 1,
        'receipt_prompt_hint': _promptController.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() { _error = 'Failed to save: $e'; });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Settings'),
      ),
      body: _loading && _promptController.text.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_error != null) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          border: Border.all(color: Colors.red.shade200),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(_error!, style: TextStyle(color: Colors.red.shade800)),
                      ),
                    ],
                    const Text(
                      'Gemini Prompt Hint',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _promptController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Optional operator guidance appended to the AI prompt',
                      ),
                      validator: (v) => null,
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _loading ? null : _save,
                        icon: const Icon(Icons.save),
                        label: Text(_loading ? 'Saving…' : 'Save Settings'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

