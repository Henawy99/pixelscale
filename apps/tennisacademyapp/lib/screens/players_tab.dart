import 'package:flutter/material.dart';
import '../models/player_model.dart';
import '../services/player_service.dart';
import 'add_player_dialog.dart';
import 'classes_settings_sheet.dart';
import '../constants/levels.dart';

class PlayersTab extends StatefulWidget {
  const PlayersTab({super.key});

  @override
  State<PlayersTab> createState() => _PlayersTabState();
}

class _PlayersTabState extends State<PlayersTab> {
  List<PlayerModel> _players = [];
  List<PlayerModel> _filteredPlayers = [];
  bool _loading = false;
  String? _error;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredPlayers = _players;
      } else {
        _filteredPlayers = _players.where((p) {
          return p.name.toLowerCase().contains(query) ||
              p.className.toLowerCase().contains(query) ||
              p.levelInfo.label.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await PlayerService.fetchPlayers();
      if (mounted) {
        setState(() {
          _players = list;
          _filteredPlayers = list;
          _loading = false;
        });
        _onSearchChanged(); 
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

  Future<void> _addPlayer() async {
    final added = await showDialog<bool>(
      context: context,
      builder: (ctx) => const AddPlayerDialog(),
    );
    if (added == true && mounted) _load();
  }

  Future<void> _editPlayer(PlayerModel p) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => _EditPlayerDialog(player: p),
    );
    if (updated == true && mounted) _load();
  }

  Future<void> _deletePlayer(PlayerModel p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove player?'),
        content: Text('Are you sure you want to delete ${p.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok == true) {
      await PlayerService.deletePlayer(p.id, isRegistered: p.isRegistered);
      if (mounted) _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        labelText: 'Search players',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.settings),
                    onPressed: () async {
                      await showModalBottomSheet(
                        context: context,
                        builder: (context) => const ClassesSettingsSheet(),
                      );
                      setState(() {}); // refresh if levels changed
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                itemCount: _filteredPlayers.length,
                itemBuilder: (_, i) {
                  final p = _filteredPlayers[i];
                  final info = p.levelInfo;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: p.isRegistered ? BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.green, width: 2),
                    ) : null,
                    child: Card(
                      margin: EdgeInsets.zero,
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: info.color, width: 2),
                        ),
                        child: CircleAvatar(
                          backgroundColor: info.color.withOpacity(0.2),
                          child: Text(
                            p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                            style: TextStyle(color: info.color, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: info.color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                info.label,
                                style: TextStyle(color: info.color, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(p.className, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                          ],
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _editPlayer(p),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete_outline, color: Colors.grey[400]),
                            onPressed: () => _deletePlayer(p),
                          ),
                        ],
                      ),
                    ),
                  ), // Closing Card
                ); // Closing Container
              },
            ),
            ),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            onPressed: _addPlayer,
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}

class _EditPlayerDialog extends StatefulWidget {
  final PlayerModel player;
  const _EditPlayerDialog({required this.player});

  @override
  State<_EditPlayerDialog> createState() => _EditPlayerDialogState();
}

class _EditPlayerDialogState extends State<_EditPlayerDialog> {
  final _nameController = TextEditingController();
  final _classController = TextEditingController();
  final _yearController = TextEditingController();
  String _level = 'green';
  DateTime? _dob;
  String? _preferredHand;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.player.name;
    _classController.text = widget.player.className;
    _yearController.text = widget.player.startedPlayingYear?.toString() ?? '';
    _level = widget.player.level;
    _dob = widget.player.dateOfBirth;
    _preferredHand = widget.player.dominantHand;
  }
  
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime.now().subtract(const Duration(days: 365 * 10)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() => _dob = picked);
    }
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await PlayerService.updatePlayer(
        widget.player.id,
        isRegistered: widget.player.isRegistered,
        name: _nameController.text.trim(),
        level: _level,
        className: _classController.text.trim(),
        dateOfBirth: _dob,
        startedPlayingYear: int.tryParse(_yearController.text.trim()),
        dominantHand: _preferredHand,
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
      title: const Text('Edit Player'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _classController,
              decoration: const InputDecoration(labelText: 'Class Name'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _level,
              items: allLevelValues.map((info) {
                return DropdownMenuItem(value: info.id, child: Text(info.label));
              }).toList(),
              onChanged: (v) => setState(() => _level = v ?? 'green'),
              decoration: const InputDecoration(labelText: 'Level'),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Date of Birth'),
                child: Text(_dob == null ? 'Select Date' : _dob!.toIso8601String().split('T')[0]),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _yearController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Started Playing Year'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _preferredHand,
              items: const [
                DropdownMenuItem(value: 'Right', child: Text('Right')),
                DropdownMenuItem(value: 'Left', child: Text('Left')),
                DropdownMenuItem(value: 'Both', child: Text('Both')),
              ],
              onChanged: (v) => setState(() => _preferredHand = v),
              decoration: const InputDecoration(labelText: 'Preferred Hand'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
        ),
      ],
    );
  }
}
