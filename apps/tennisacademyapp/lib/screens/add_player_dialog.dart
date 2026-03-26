import 'package:flutter/material.dart';
import '../constants/levels.dart';
import '../services/player_service.dart';

class AddPlayerDialog extends StatefulWidget {
  const AddPlayerDialog({super.key});

  @override
  State<AddPlayerDialog> createState() => _AddPlayerDialogState();
}

class _AddPlayerDialogState extends State<AddPlayerDialog> {
  final _nameController = TextEditingController();
  late String _levelId;
  late String _className;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final first = allLevelValues.first;
    _levelId = first.id;
    _className = first.classes.isNotEmpty ? first.classes.first : '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  List<String> get _classesForCurrentLevel => kLevels[_levelId]?.classes ?? [];

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter name')));
      return;
    }
    setState(() => _saving = true);
    try {
      await PlayerService.createPlayer(
        name: name,
        level: _levelId,
        className: _className,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add player'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _levelId,
              decoration: const InputDecoration(labelText: 'Level (color)', border: OutlineInputBorder()),
              items: allLevelValues.map((info) {
                return DropdownMenuItem(
                  value: info.id,
                  child: Row(
                    children: [
                      Container(width: 16, height: 16, decoration: BoxDecoration(color: info.color, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Text(info.label),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    _levelId = v;
                    final list = kLevels[v]?.classes ?? [];
                    _className = list.isNotEmpty ? list.first : '';
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            if (_classesForCurrentLevel.isNotEmpty)
              DropdownButtonFormField<String>(
                value: _classesForCurrentLevel.contains(_className) ? _className : _classesForCurrentLevel.first,
                decoration: const InputDecoration(labelText: 'Class (from selected level)', border: OutlineInputBorder()),
                items: _classesForCurrentLevel.map((c) {
                  final info = kLevels[_levelId]!;
                  return DropdownMenuItem(
                    value: c,
                    child: Row(
                      children: [
                        Container(width: 16, height: 16, decoration: BoxDecoration(color: info.color, shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Text(c),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _className = v ?? _classesForCurrentLevel.first),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Add'),
        ),
      ],
    );
  }
}
