import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/session_model.dart';
import '../models/session_registration_model.dart';
import '../providers/auth_provider.dart';
import '../services/session_service.dart';

/// Admin app: create/update/delete sessions, add/remove players, see count, max 4.
class AdminScheduleScreen extends StatefulWidget {
  const AdminScheduleScreen({super.key});

  @override
  State<AdminScheduleScreen> createState() => _AdminScheduleScreenState();
}

class _AdminScheduleScreenState extends State<AdminScheduleScreen> {
  DateTime _selectedDate = DateTime.now();
  List<SessionModel> _sessions = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final list = await SessionService.fetchSessions(dateStr);
      if (mounted) {
        setState(() {
          _sessions = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  Future<void> _deleteSession(SessionModel s) async {
    if (s.recurrenceId != null) {
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Recurring Session'),
          content: const Text('This session is part of a series. Delete just this one, or the whole series?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, 'cancel'), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, 'single'), child: const Text('This One')),
            FilledButton(onPressed: () => Navigator.pop(ctx, 'series'), child: const Text('Entire Series')),
          ],
        ),
      );
      if (choice == 'cancel' || choice == null) return;
      
      try {
        if (choice == 'series') {
          await SessionService.deleteSessionSeries(s.recurrenceId!);
        } else {
          await SessionService.deleteSession(s.id);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted')));
          _loadSessions();
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
      return;
    }

    // Standard delete
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete session?'),
      content: Text('${s.name} on Court ${s.courtId} at ${s.timeRange}'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
      ],
    ));
    if (ok != true) return;
    try {
      await SessionService.deleteSession(s.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Session deleted')));
        _loadSessions();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  void _openCreateSession() {
    Navigator.push(context, MaterialPageRoute(builder: (ctx) => _CreateEditSessionScreen(
      date: DateFormat('yyyy-MM-dd').format(_selectedDate),
      onSaved: () {
        Navigator.pop(ctx);
        _loadSessions();
      },
    )));
  }

  void _openEditSession(SessionModel s) {
    Navigator.push(context, MaterialPageRoute(builder: (ctx) => _CreateEditSessionScreen(
      date: s.date,
      session: s,
      onSaved: () {
        Navigator.pop(ctx);
        _loadSessions();
      },
    )));
  }

  void _openManagePlayers(SessionModel s) {
    Navigator.push(context, MaterialPageRoute(builder: (ctx) => _ManagePlayersScreen(session: s, onChanged: _loadSessions)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin – Schedule'),
        actions: [
          IconButton(icon: const Icon(Icons.calendar_today), onPressed: _pickDate),
          IconButton(icon: const Icon(Icons.logout), onPressed: () => context.read<AuthProvider>().signOut()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreateSession,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  TextButton(onPressed: _loadSessions, child: const Text('Retry')),
                ]))
              : RefreshIndicator(
                  onRefresh: _loadSessions,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        _selectedDate.day == DateTime.now().day ? 'Today' : DateFormat('EEEE, MMM d').format(_selectedDate),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      ..._sessionsByCourt.entries.map((e) => _AdminCourtSection(
                            courtNumber: e.key,
                            sessions: e.value,
                            onEdit: _openEditSession,
                            onDelete: _deleteSession,
                            onManagePlayers: _openManagePlayers,
                          )),
                    ],
                  ),
                ),
    );
  }

  Map<int, List<SessionModel>> get _sessionsByCourt {
    final map = <int, List<SessionModel>>{};
    for (final s in _sessions) {
      map.putIfAbsent(s.courtId, () => []).add(s);
    }
    for (final list in map.values) {
      list.sort((a, b) => a.startTime.compareTo(b.startTime));
    }
    return map;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _loadSessions();
    }
  }
}

class _AdminCourtSection extends StatelessWidget {
  final int courtNumber;
  final List<SessionModel> sessions;
  final void Function(SessionModel) onEdit;
  final void Function(SessionModel) onDelete;
  final void Function(SessionModel) onManagePlayers;

  const _AdminCourtSection({
    required this.courtNumber,
    required this.sessions,
    required this.onEdit,
    required this.onDelete,
    required this.onManagePlayers,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Court $courtNumber', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...sessions.map((s) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Row(
                    children: [
                      Expanded(child: Text(s.name + (s.recurrenceRule != null ? ' 🔁' : ''))),
                      Text(s.timeRange, style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(width: 8),
                      Text('${s.playerCount}/${s.maxCapacity}', style: Theme.of(context).textTheme.bodySmall),
                      if (s.isFull) const Chip(label: Text('FULL', style: TextStyle(fontSize: 10)), padding: EdgeInsets.zero, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.people), onPressed: () => onManagePlayers(s), tooltip: 'Players'),
                      IconButton(icon: const Icon(Icons.edit), onPressed: () => onEdit(s), tooltip: 'Edit'),
                      IconButton(icon: const Icon(Icons.delete), onPressed: () => onDelete(s), tooltip: 'Delete'),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _CreateEditSessionScreen extends StatefulWidget {
  final String date;
  final SessionModel? session;
  final VoidCallback onSaved;

  const _CreateEditSessionScreen({required this.date, this.session, required this.onSaved});

  @override
  State<_CreateEditSessionScreen> createState() => _CreateEditSessionScreenState();
}

class _CreateEditSessionScreenState extends State<_CreateEditSessionScreen> {
  final _nameController = TextEditingController();
  final _startController = TextEditingController();
  final _endController = TextEditingController();
  final _repeatController = TextEditingController(text: '4');
  int _courtId = 1;
  String _recurrence = 'none'; // none, daily, weekly
  bool _saving = false;
  bool get _isEdit => widget.session != null;

  @override
  void initState() {
    super.initState();
    if (widget.session != null) {
      final s = widget.session!;
      _nameController.text = s.name;
      _startController.text = s.startTime.length >= 5 ? s.startTime.substring(0, 5) : s.startTime;
      _endController.text = s.endTime.length >= 5 ? s.endTime.substring(0, 5) : s.endTime;
      _courtId = s.courtId;
      _recurrence = s.recurrenceRule ?? 'none';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _startController.dispose();
    _endController.dispose();
    _repeatController.dispose();
    super.dispose();
  }

  String get _startTime => _startController.text.trim().length >= 5 ? '${_startController.text.trim()}:00' : _startController.text.trim();
  String get _endTime => _endController.text.trim().length >= 5 ? '${_endController.text.trim()}:00' : _endController.text.trim();

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter session name')));
      return;
    }
    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await SessionService.updateSession(widget.session!.id, {
          'court_id': _courtId,
          'name': _nameController.text.trim(),
          'start_time': _startTime,
          'end_time': _endTime,
          // Recurrence usually not updated for single edit, or complicated. Skipping recurrence update logic for simplicity.
        });
      } else {
        await SessionService.createSession(
          date: widget.date,
          courtId: _courtId,
          name: _nameController.text.trim(),
          startTime: _startTime,
          endTime: _endTime,
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
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit session' : 'Create session')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Session name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _courtId,
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
            if (!_isEdit) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _recurrence,
                decoration: const InputDecoration(labelText: 'Recurrence', border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem(value: 'none', child: Text('None (One-time)')),
                  const DropdownMenuItem(value: 'daily', child: Text('Daily')),
                  const DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
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
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(_isEdit ? 'Save' : 'Create'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManagePlayersScreen extends StatefulWidget {
  final SessionModel session;
  final VoidCallback onChanged;

  const _ManagePlayersScreen({required this.session, required this.onChanged});

  @override
  State<_ManagePlayersScreen> createState() => _ManagePlayersScreenState();
}

class _ManagePlayersScreenState extends State<_ManagePlayersScreen> {
  List<SessionRegistrationModel> _regs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await SessionService.getSessionRegistrations(widget.session.id);
      if (mounted) {
        setState(() {
          _regs = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _removePlayer(SessionRegistrationModel reg) async {
    try {
      await SessionService.removePlayerFromSession(reg.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Player removed')));
        _load();
        widget.onChanged();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _approveOrReject(SessionRegistrationModel reg, String status) async {
    try {
      await SessionService.updateRegistrationStatus(reg.id, status);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(status == 'approved' ? 'Approved' : 'Rejected')));
        _load();
        widget.onChanged();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _addPlayerByEmail() async {
    final email = await showDialog<String>(context: context, builder: (ctx) {
      final c = TextEditingController();
      return AlertDialog(
        title: const Text('Add player by email'),
        content: TextField(
          controller: c,
          decoration: const InputDecoration(hintText: 'Player email'),
          keyboardType: TextInputType.emailAddress,
          onSubmitted: (_) => Navigator.pop(ctx, c.text.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Add')),
        ],
      );
    });
    if (email == null || email.isEmpty) return;
    try {
      final profiles = await SessionService.findProfileByEmail(email);
      if (profiles.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No user with that email')));
        return;
      }
      final userId = profiles.first['id'] as String;
      await SessionService.addPlayerToSession(widget.session.id, userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Player added')));
        _load();
        widget.onChanged();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.session.name} – Players'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('${_regs.length}/${widget.session.maxCapacity} players', style: Theme.of(context).textTheme.titleMedium),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _regs.length,
                    itemBuilder: (_, i) {
                      final r = _regs[i];
                      return ListTile(
                        title: Text(r.fullName ?? r.userId),
                        subtitle: Text('${r.status}${r.email != null ? ' · ${r.email}' : ''}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (r.status == 'pending') ...[
                              TextButton(onPressed: () => _approveOrReject(r, 'approved'), child: const Text('Approve')),
                              TextButton(onPressed: () => _approveOrReject(r, 'rejected'), child: const Text('Reject')),
                            ],
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () => _removePlayer(r),
                              tooltip: 'Remove',
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                if (_regs.length < widget.session.maxCapacity)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: FilledButton.icon(
                      icon: const Icon(Icons.person_add),
                      label: const Text('Add player by email'),
                      onPressed: _addPlayerByEmail,
                    ),
                  ),
              ],
            ),
    );
  }
}
