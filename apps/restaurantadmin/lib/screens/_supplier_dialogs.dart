import 'package:flutter/material.dart';

class SupplierResult {
  final String name;
  final String? aiRules;
  const SupplierResult({required this.name, this.aiRules});
}

class SupplierCreateDialog extends StatefulWidget {
  final String? initialName;
  const SupplierCreateDialog({super.key, this.initialName});
  @override
  State<SupplierCreateDialog> createState() => _SupplierCreateDialogState();
}

class _SupplierCreateDialogState extends State<SupplierCreateDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _rules = TextEditingController();

  @override
  void initState() {
    super.initState();
    _name.text = widget.initialName ?? '';
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('New supplier detected', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Supplier name', border: OutlineInputBorder()),
                validator: (v) => (v==null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _rules,
                decoration: const InputDecoration(labelText: 'AI rules (optional)', border: OutlineInputBorder()),
                maxLines: 4,
              ),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    if (!_formKey.currentState!.validate()) return;
                    Navigator.of(context).pop(SupplierResult(name: _name.text.trim(), aiRules: _rules.text.trim().isEmpty ? null : _rules.text.trim()));
                  },
                  child: const Text('Create'),
                ),
              ])
            ],
          ),
        ),
      ),
    );
  }
}

