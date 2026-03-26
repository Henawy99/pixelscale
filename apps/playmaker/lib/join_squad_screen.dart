
import 'package:flutter/material.dart';
import 'package:playmakerappstart/create_sqauds_screen.dart';
import 'package:playmakerappstart/custom_container.dart';
import './models/squad.dart';
import 'package:playmakerappstart/models/user_model.dart';
import 'package:playmakerappstart/squad_details_screen.dart';
import 'package:playmakerappstart/services/supabase_service.dart';

class JoinSquadsScreen extends StatefulWidget {
  final PlayerProfile playerProfile;

  JoinSquadsScreen({Key? key, required this.playerProfile}) : super(key: key);

  @override
  _JoinSquadsScreenState createState() => _JoinSquadsScreenState();
}

class _JoinSquadsScreenState extends State<JoinSquadsScreen> {
  List<Squad> _allFetchedSquads = []; // Store all squads fetched from Supabase
  List<Squad> _displayedSquads = []; // Squads to display after all filters
  String? _filterLocation;
  RangeValues? _selectedAgeRange;
  final double _minPossibleAge = 10;
  final double _maxPossibleAge = 70;
  bool _isLoading = true;
  final SupabaseService _supabaseService = SupabaseService();

  @override
  void initState() {
    super.initState();
    _selectedAgeRange = RangeValues(_minPossibleAge, _maxPossibleAge);
    fetchAndFilterSquads();
  }

  Future<void> fetchAndFilterSquads() async {
    setState(() {
      _isLoading = true;
    });
    try {
      // Fetch all joinable squads from Supabase
      List<Squad> fetchedSquads = await _supabaseService.getAllJoinableSquads();

      // Apply Client-Side Filtering
      List<Squad> filteredSquads = fetchedSquads.where((squad) {
        // Filter 1: Not captained by current user
        if (squad.captain == widget.playerProfile.id) {
          return false;
        }

        // Filter 2: Current user is not already a member
        if (squad.squadMembers.contains(widget.playerProfile.id)) {
          return false;
        }

        // Filter 3: Must be joinable
        if (!squad.joinable) {
          return false;
        }

        // Filter 4: Location filter (if applied)
        if (_filterLocation != null && _filterLocation!.isNotEmpty && _filterLocation != 'All Locations') {
          if (squad.squadLocation != _filterLocation) {
            return false;
          }
        }

        // Filter 5: Age range filter (if applied)
        if (_selectedAgeRange != null) {
          if (squad.averageAge == null || // Exclude if averageAge is null
              squad.averageAge! < _selectedAgeRange!.start ||
              squad.averageAge! > _selectedAgeRange!.end) {
            return false;
          }
        }
        return true;
      }).toList();

      if (mounted) {
        setState(() {
          _allFetchedSquads = filteredSquads;
          _displayedSquads = List.from(_allFetchedSquads); 
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching or filtering squads: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading squads: ${e.toString()}')),
        );
        setState(() {
          _isLoading = false;
          _displayedSquads = [];
        });
      }
    }
  }

  void _applyFiltersAndFetch() {
    // This function will now call fetchAndFilterSquads which uses the current state of filters
    fetchAndFilterSquads();
  }

  void _showFilterBottomSheet() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        // Use StatefulBuilder to manage local state of the bottom sheet's filters
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return Container(
              padding: const EdgeInsets.only(top: 16, left: 24, right: 24, bottom: 16),
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.dividerColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Filter Squads',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Location',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 4.0,
                    children: ['New Cairo', 'Nasr City', 'Shorouk', 'Maadi', 'Sheikh Zayed', 'October', 'All Locations'].map((location) {
                      bool isSelected = (_filterLocation == location) || (location == 'All Locations' && _filterLocation == null);
                      return ChoiceChip(
                        label: Text(location),
                        selected: isSelected,
                        onSelected: (bool selected) {
                          setSheetState(() {
                            if (location == 'All Locations') {
                              _filterLocation = null;
                            } else {
                              _filterLocation = selected ? location : null;
                            }
                          });
                        },
                        selectedColor: theme.colorScheme.primary,
                        labelStyle: TextStyle(
                          color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
                        ),
                        backgroundColor: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                          side: BorderSide(color: isSelected ? theme.colorScheme.primary : theme.dividerColor)
                        ),
                        showCheckmark: false,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Average Squad Age',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  RangeSlider(
                    values: _selectedAgeRange ?? RangeValues(_minPossibleAge, _maxPossibleAge),
                    min: _minPossibleAge,
                    max: _maxPossibleAge,
                    divisions: (_maxPossibleAge - _minPossibleAge).toInt(),
                    labels: RangeLabels(
                      (_selectedAgeRange?.start ?? _minPossibleAge).round().toString(),
                      (_selectedAgeRange?.end ?? _maxPossibleAge).round().toString(),
                    ),
                    onChanged: (RangeValues values) {
                      setSheetState(() {
                        _selectedAgeRange = values;
                      });
                    },
                    activeColor: theme.colorScheme.primary,
                    inactiveColor: theme.colorScheme.primary.withOpacity(0.3),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Min: ${(_selectedAgeRange?.start ?? _minPossibleAge).round()} yrs', style: theme.textTheme.bodySmall),
                      Text('Max: ${(_selectedAgeRange?.end ?? _maxPossibleAge).round()} yrs', style: theme.textTheme.bodySmall),
                    ],
                  ),
                  const Spacer(), // Pushes button to the bottom
                  Padding(
                    padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 8),
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _applyFiltersAndFetch(); // Apply filters and re-fetch/re-filter
                      },
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        backgroundColor: theme.colorScheme.primary,
                      ),
                      child: Text('Apply Filters', style: TextStyle(color: theme.colorScheme.onPrimary)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Join Squads',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterBottomSheet,
          ),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _displayedSquads.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'No squads found',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => CreateSquadsScreen(
                                  playerProfile: widget.playerProfile,
                                )),
                      );
                    },
                    child: const Text(
                      'Create Squad',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green, // Button color
                      minimumSize: const Size(150, 50), // Button size
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _displayedSquads.length,
              itemBuilder: (context, index) {
                final squad = _displayedSquads[index];
                return InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SquadDetailsScreen(
                          userId: widget.playerProfile.id,
                          squad: squad,
                          // isCaptain: squad.captain == widget.playerProfile.id, // Removed
                          isVisitor: !squad.squadMembers.contains(widget.playerProfile.id),
                        ),
                      ),
                    );
                  },
                  child: CustomContainer(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: squad.squadLogo != null ? NetworkImage(squad.squadLogo!) : null,
                        child: squad.squadLogo == null ? Text(squad.squadName[0]) : null,
                      ),
                      title: Text(
                        squad.squadName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Number of players: ${squad.squadMembers.length}'),
                          Text('Location: ${squad.squadLocation}'),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
