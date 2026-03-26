import 'package:flutter/material.dart';
import '../models/player_model.dart';

/// Bottom sheet to pick a player to assign to a slot, or clear the slot.
/// Pops with null to clear slot, or PlayerModel to assign.
class AssignPlayerSheet extends StatefulWidget {
  final List<PlayerModel> players;
  final String currentName;

  const AssignPlayerSheet({
    super.key,
    required this.players,
    required this.currentName,
  });

  @override
  State<AssignPlayerSheet> createState() => _AssignPlayerSheetState();
}

class _AssignPlayerSheetState extends State<AssignPlayerSheet> {
  final _searchController = TextEditingController();
  List<PlayerModel> _filteredPlayers = [];

  @override
  void initState() {
    super.initState();
    _filteredPlayers = widget.players;
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
        _filteredPlayers = widget.players;
      } else {
        _filteredPlayers = widget.players.where((p) {
          return p.name.toLowerCase().contains(query) ||
              p.className.toLowerCase().contains(query) ||
              p.levelInfo.label.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'Search players',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ),
            if (widget.currentName.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.person_off, color: Colors.red),
                title: const Text('Remove player (Clear slot)', style: TextStyle(color: Colors.red)),
                onTap: () => Navigator.pop(context, 'REMOVE'),
              ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: _filteredPlayers.length,
                itemBuilder: (_, i) {
                  final p = _filteredPlayers[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: p.levelInfo.color,
                      radius: 18,
                    ),
                    title: Text(p.name),
                    subtitle: Text('${p.levelInfo.label} · ${p.className}'),
                    onTap: () => Navigator.pop(context, p),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
