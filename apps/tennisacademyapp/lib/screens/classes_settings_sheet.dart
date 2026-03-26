import 'package:flutter/material.dart';
import '../constants/levels.dart';

class ClassesSettingsSheet extends StatefulWidget {
  const ClassesSettingsSheet({super.key});

  @override
  State<ClassesSettingsSheet> createState() => _ClassesSettingsSheetState();
}

class _ClassesSettingsSheetState extends State<ClassesSettingsSheet> {
  bool _loading = false;

  Future<void> _refresh() async {
    setState(() => _loading = true);
    await loadAcademyClasses();
    if (mounted) setState(() => _loading = false);
  }

  void _addLevel() async {
    final res = await showDialog<LevelInfo>(
      context: context,
      builder: (ctx) => const _LevelDialog(),
    );
    if (res != null) {
      setState(() => _loading = true);
      await saveAcademyClass(res);
      if (mounted) setState(() => _loading = false);
    }
  }

  void _editLevel(LevelInfo level) async {
    final res = await showDialog<LevelInfo>(
      context: context,
      builder: (ctx) => _LevelDialog(level: level),
    );
    if (res != null) {
      setState(() => _loading = true);
      await saveAcademyClass(res);
      if (mounted) setState(() => _loading = false);
    }
  }

  void _deleteLevel(LevelInfo level) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Level'),
        content: Text('Are you sure you want to delete ${level.label}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      setState(() => _loading = true);
      await deleteAcademyClass(level.id);
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 300,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    
    final levels = allLevelValues;

    return Container(
      padding: const EdgeInsets.only(top: 24, left: 16, right: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Manage Classes & Levels', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
            ],
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: levels.length,
              itemBuilder: (context, index) {
                final level = levels[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: level.color.withValues(alpha: 0.2),
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(color: level.color, shape: BoxShape.circle),
                      ),
                    ),
                    title: Text(level.label, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(level.classes.isEmpty ? 'No classes' : level.classes.join(', ')),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _editLevel(level)),
                        IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteLevel(level)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _addLevel,
                  icon: const Icon(Icons.add),
                  label: const Text('Add New Level'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelDialog extends StatefulWidget {
  final LevelInfo? level;
  const _LevelDialog({this.level});

  @override
  State<_LevelDialog> createState() => _LevelDialogState();
}

class _LevelDialogState extends State<_LevelDialog> {
  final _labelController = TextEditingController();
  final _classesController = TextEditingController();
  int _colorValue = 0xFF9E9E9E; // Default grey

  @override
  void initState() {
    super.initState();
    if (widget.level != null) {
      _labelController.text = widget.level!.label;
      _classesController.text = widget.level!.classes.join(', ');
      _colorValue = widget.level!.colorValue;
    }
  }

  void _save() {
    if (_labelController.text.trim().isEmpty) return;
    
    final label = _labelController.text.trim();
    // basic sanity ID generation if new
    final id = widget.level?.id ?? label.toLowerCase().replaceAll(' ', '_');
    
    final classesStr = _classesController.text;
    final classesList = classesStr.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    final newLevel = LevelInfo(
      id: id,
      label: label,
      colorValue: _colorValue,
      classes: classesList,
    );
    Navigator.pop(context, newLevel);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.level == null ? 'Add Level' : 'Edit Level'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _labelController,
              decoration: const InputDecoration(labelText: 'Level Name', hintText: 'e.g. Purple'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _classesController,
              decoration: const InputDecoration(labelText: 'Classes (Comma separated)', hintText: 'e.g. Avocado, Lemons'),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            const Text('Color:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                0xFF2E7D32, // Green
                0xFFC62828, // Red
                0xFFF9A825, // Yellow
                0xFFE65100, // Orange
                0xFF1565C0, // Blue
                0xFF6A1B9A, // Purple
                0xFF000000, // Black
                0xFF9E9E9E, // Grey
              ].map((value) => GestureDetector(
                    onTap: () => setState(() => _colorValue = value),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Color(value),
                        shape: BoxShape.circle,
                        border: _colorValue == value ? Border.all(color: Colors.blue, width: 3) : null,
                      ),
                    ),
                  )).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
