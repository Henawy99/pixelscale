import 'package:flutter/material.dart';
import '../models/session_model.dart';
import '../constants/levels.dart';
import '../services/session_service.dart';

class AddEditSessionSheet extends StatefulWidget {
  final String date;
  final SessionModel? session;
  final VoidCallback onSaved;
  final VoidCallback? onDelete;

  const AddEditSessionSheet({super.key, required this.date, this.session, required this.onSaved, this.onDelete});

  @override
  State<AddEditSessionSheet> createState() => _AddEditSessionSheetState();
}

class _AddEditSessionSheetState extends State<AddEditSessionSheet> {
  final _startController = TextEditingController();
  final _endController = TextEditingController();
  final _fitnessStartController = TextEditingController();
  final _fitnessEndController = TextEditingController();
  int _courtId = 1;
  String _selectedClass = allClasses.first;
  String _recurrence = 'none'; // none, daily, weekly
  final _repeatController = TextEditingController(text: '4');
  bool _saving = false;
  bool get _isEdit => widget.session != null;

  @override
  void initState() {
    super.initState();
    if (widget.session != null) {
      final s = widget.session!;
      _selectedClass = allClasses.contains(s.name) ? s.name : allClasses.first;
      _startController.text = s.startTime.length >= 5 ? s.startTime.substring(0, 5) : s.startTime;
      _endController.text = s.endTime.length >= 5 ? s.endTime.substring(0, 5) : s.endTime;
      _fitnessStartController.text = (s.fitnessStartTime != null && s.fitnessStartTime!.length >= 5) ? s.fitnessStartTime!.substring(0, 5) : (s.fitnessStartTime ?? '');
      _fitnessEndController.text = (s.fitnessEndTime != null && s.fitnessEndTime!.length >= 5) ? s.fitnessEndTime!.substring(0, 5) : (s.fitnessEndTime ?? '');
      _courtId = s.courtId;
    } else {
      _selectedClass = allClasses.first;
    }
    _endController.addListener(_onEndChanged);
  }

  void _onEndChanged() {
    if (_fitnessStartController.text.isEmpty && _endController.text.isNotEmpty) {
      _fitnessStartController.text = _endController.text;
    }
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    _fitnessStartController.dispose();
    _fitnessEndController.dispose();
    _repeatController.dispose();
    super.dispose();
  }

  String get _startTime => _startController.text.trim().length >= 5 ? '${_startController.text.trim()}:00' : _startController.text.trim();
  String get _endTime => _endController.text.trim().length >= 5 ? '${_endController.text.trim()}:00' : _endController.text.trim();
  String get _fitnessStartTime => _fitnessStartController.text.trim().length >= 5 ? '${_fitnessStartController.text.trim()}:00' : _fitnessStartController.text.trim();
  String get _fitnessEndTime => _fitnessEndController.text.trim().length >= 5 ? '${_fitnessEndController.text.trim()}:00' : _fitnessEndController.text.trim();

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await SessionService.updateSession(widget.session!.id, {
          'court_id': _courtId,
          'name': _selectedClass,
          'start_time': _startTime,
          'end_time': _endTime,
          'fitness_start_time': _fitnessStartTime.isEmpty ? null : _fitnessStartTime,
          'fitness_end_time': _fitnessEndTime.isEmpty ? null : _fitnessEndTime,
        });
      } else {
        await SessionService.createSession(
          date: widget.date,
          courtId: _courtId,
          name: _selectedClass,
          startTime: _startTime,
          endTime: _endTime,
          fitnessStartTime: _fitnessStartTime.isEmpty ? null : _fitnessStartTime,
          fitnessEndTime: _fitnessEndTime.isEmpty ? null : _fitnessEndTime,
          recurrenceRule: _recurrence == 'none' ? null : _recurrence,
          repeatCount: _recurrence == 'none' ? 1 : (int.tryParse(_repeatController.text) ?? 1),
        );
      }
      widget.onSaved();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_isEdit ? 'Edit Session' : 'Add session', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                if (_isEdit)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
                    child: Text('${widget.session!.playerCount}/${widget.session!.maxCapacity} Players', style: TextStyle(color: Colors.blue.shade900, fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            if (_isEdit) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Text(widget.session!.date, style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: allClasses.contains(_selectedClass) ? _selectedClass : allClasses.first,
              decoration: const InputDecoration(labelText: 'Class', border: OutlineInputBorder()),
              items: allClasses.map((c) {
                final info = levelInfoForClass(c);
                return DropdownMenuItem(
                  value: c,
                  child: Row(
                    children: [
                      if (info != null)
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: info.color,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey.shade400),
                          ),
                        ),
                      if (info != null) const SizedBox(width: 8),
                      Text(c),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (v) => setState(() => _selectedClass = v ?? allClasses.first),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              value: _courtId,
              decoration: const InputDecoration(labelText: 'Court', border: OutlineInputBorder()),
              items: [1, 2, 3, 4].map((c) => DropdownMenuItem(value: c, child: Text('Court $c'))).toList(),
              onChanged: (v) => setState(() => _courtId = v ?? 1),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _startController,
              decoration: const InputDecoration(labelText: 'Start (HH:mm)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _endController,
              decoration: const InputDecoration(labelText: 'End (HH:mm)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _fitnessStartController,
              decoration: const InputDecoration(labelText: 'Fitness Start (HH:mm) (Optional)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _fitnessEndController,
              decoration: const InputDecoration(labelText: 'Fitness End (HH:mm) (Optional)', border: OutlineInputBorder()),
            ),
            if (!_isEdit) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _recurrence,
                decoration: const InputDecoration(labelText: 'Recurrence', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'none', child: Text('None (One-time)')),
                  DropdownMenuItem(value: 'daily', child: Text('Daily')),
                  DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                ],
                onChanged: (v) => setState(() => _recurrence = v ?? 'none'),
              ),
              if (_recurrence != 'none')
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: TextField(
                    controller: _repeatController,
                    decoration: const InputDecoration(labelText: 'Number of occurrences', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                  ),
                ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                if (_isEdit && widget.onDelete != null) ...[
                  Expanded(
                    flex: 1,
                    child: OutlinedButton(
                      onPressed: widget.onDelete,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Delete'),
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(_isEdit ? 'Save Changes' : 'Create'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
