import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:playmakerappstart/field_booking_screen.dart';
import 'package:playmakerappstart/l10n/app_localizations.dart';
import 'package:playmakerappstart/models/footballfield_model.dart';
import 'package:playmakerappstart/models/user_model.dart';
import 'package:playmakerappstart/services/supabase_service.dart';
import 'package:playmakerappstart/custom_dialoag.dart';
import 'package:playmakerappstart/login_screen/login_screen.dart';
import 'fields_map_screen.dart';

class FieldsListView extends StatefulWidget {
  final Position? currentPosition;
  final PlayerProfile playerProfile;

  const FieldsListView({
    super.key,
    this.currentPosition,
    required this.playerProfile,
  });

  @override
  State<FieldsListView> createState() => _FieldsListViewState();
}

class _FieldsListViewState extends State<FieldsListView> with TickerProviderStateMixin {
  final SupabaseService _supabaseService = SupabaseService();
  List<String> _locations(BuildContext context) => [ // Made _locations a method to access context
    AppLocalizations.of(context)!.fieldsListView_locationNewCairo,
    AppLocalizations.of(context)!.fieldsListView_locationNasrCity,
    AppLocalizations.of(context)!.fieldsListView_locationShorouk,
    AppLocalizations.of(context)!.fieldsListView_locationMaadi,
    AppLocalizations.of(context)!.fieldsListView_locationSheikhZayed,
    AppLocalizations.of(context)!.fieldsListView_locationOctober
  ];

  List<FootballField> _allFields = []; // Stores all fields fetched from Firestore based on _selectedLocation
  List<FootballField> _displayedFields = []; // Stores fields to be displayed after client-side sorting/filtering
  DateTime _selectedDate = DateTime.now();
  double _radius = 10.0; // Default to 10 km
  bool _anyDistance = true; // New flag for "any" distance
  String _selectedLocation = '';
  bool _isLoading = true; // For initial load
  Position? _currentPosition;
  bool _isLocationEnabled = false;

  // Pagination state
  static const int _fieldsPerPage = 10;
  int _currentOffset = 0;
  bool _isFetchingMore = false;
  bool _hasMoreFieldsToLoad = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _checkLocationPermission().then((_) {
      _fetchFootballFields(isInitialLoad: true);
    });

    _scrollController.addListener(() {
      // If scrolled to the bottom and not already fetching and there are more fields
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
          !_isFetchingMore &&
          _hasMoreFieldsToLoad) {
        _fetchFootballFields(isInitialLoad: false); // Fetch more fields
      }
    });
  }
  
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _checkLocationPermission() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _isLocationEnabled = false);
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _isLocationEnabled = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _isLocationEnabled = false);
        return;
      }

      // Get current position if permissions are granted
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = position;
        _isLocationEnabled = true;
      });
    } catch (e) {
      print(AppLocalizations.of(context)!.fieldsListView_errorCheckingLocationPermission(e.toString()));
      setState(() => _isLocationEnabled = false);
    }
  }

  Future<void> _fetchFootballFields({bool isInitialLoad = true}) async {
    if (_isFetchingMore && !isInitialLoad) return;

    if (isInitialLoad) {
      setState(() {
        _isLoading = true;
        _allFields.clear();
        _displayedFields.clear();
        _currentOffset = 0;
        _hasMoreFieldsToLoad = true;
      });
    } else {
      if (!_hasMoreFieldsToLoad) return;
      setState(() => _isFetchingMore = true);
    }
    
    try {
      String? activeLocationFilter = _selectedLocation.isNotEmpty ? _selectedLocation : null;

      // On initial load, always fetch the featured field first to ensure it's available
      FootballField? featuredField;
      if (isInitialLoad) {
        try {
          featuredField = await _supabaseService.getFootballFieldById(_featuredFieldId);
        } catch (e) {
          print('Could not fetch featured field: $e');
        }
      }

      final fetchedFields = await _supabaseService.getFootballFieldsPaginated(
        limit: _fieldsPerPage,
        offset: isInitialLoad ? 0 : _currentOffset,
        locationName: activeLocationFilter,
      );

      if (isInitialLoad) {
        _allFields = fetchedFields;
        
        // Add the featured field if it was fetched and is not already in the list
        if (featuredField != null && !_allFields.any((f) => f.id == _featuredFieldId)) {
          _allFields.insert(0, featuredField);
        }
        
        _currentOffset = _fieldsPerPage;
      } else {
        // Don't add duplicates when paginating
        for (final field in fetchedFields) {
          if (!_allFields.any((f) => f.id == field.id)) {
            _allFields.add(field);
          }
        }
        _currentOffset += _fieldsPerPage;
      }
      
      _hasMoreFieldsToLoad = fetchedFields.length == _fieldsPerPage;

      _processAndDisplayFields();

    } catch (e) {
      print(AppLocalizations.of(context)!.fieldsListView_errorFetchingFields(e.toString()));
    } finally {
      if (mounted) {
        setState(() {
          if (isInitialLoad) _isLoading = false;
          _isFetchingMore = false;
        });
      }
    }
  }

  // Featured field ID that should always appear at the top
  static const String _featuredFieldId = 'ff897aeb-a1b2-4c2a-b944-38d554878a0f'; // Be Pro Fun Hub

  void _processAndDisplayFields() {
    List<FootballField> tempDisplayedFields = List.from(_allFields);

    if (_isLocationEnabled && _currentPosition != null) {
      // Sort all fetched fields by distance
      tempDisplayedFields.sort((a, b) {
        final distanceA = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          a.latitude,
          a.longitude,
        );
        final distanceB = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          b.latitude,
          b.longitude,
        );
        return distanceA.compareTo(distanceB);
      });

      // If radius filter is active, apply it
      if (!_anyDistance) {
        tempDisplayedFields = tempDisplayedFields.where((field) {
          final distance = Geolocator.distanceBetween(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            field.latitude,
            field.longitude,
          );
          return distance <= _radius * 1000; // _radius is in km
        }).toList();
      }
    }
    // If location is not enabled, tempDisplayedFields remains as _allFields (filtered by _selectedLocation by Firestore)

    // Always pin the featured field "Be Pro Fun Hub" at the top of the list
    final featuredFieldIndex = tempDisplayedFields.indexWhere((f) => f.id == _featuredFieldId);
    if (featuredFieldIndex > 0) {
      final featuredField = tempDisplayedFields.removeAt(featuredFieldIndex);
      tempDisplayedFields.insert(0, featuredField);
    }

    setState(() {
      _displayedFields = tempDisplayedFields;
    });
  }

  Future<void> _refreshData() async {
    await _checkLocationPermission(); // Re-check permission and potentially update _currentPosition
    await _fetchFootballFields(isInitialLoad: true);
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FilterBottomSheet(
        locations: _locations(context), // Pass context to _locations
        selectedLocation: _selectedLocation,
        radius: _radius,
        anyDistance: _anyDistance,
        onLocationChanged: (location) => setState(() => _selectedLocation = location),
        onRadiusChanged: (value) => setState(() {
          _radius = value;
          _anyDistance = false;
        }),
        onAnyDistanceChanged: (value) => setState(() => _anyDistance = value),
        onApply: () {
          Navigator.pop(context);
          _fetchFootballFields(isInitialLoad: true); // Apply filters means initial load
        },
      ),
    );
  }

  void _changeDate(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      body: Container(
        color: colorScheme.surface,
        child: CustomScrollView(
          controller: _scrollController, // Attach scroll controller
          physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            floating: true,
            pinned: true,
              backgroundColor: colorScheme.surface,
              elevation: 0,
              expandedHeight: 120,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.map_outlined),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FieldsMapScreen(
                      currentPosition: widget.currentPosition,
                      playerProfile: widget.playerProfile,
                    ),
                  ),
                ),
                  tooltip: AppLocalizations.of(context)!.fieldsListView_viewMap,
              ),
              IconButton(
                icon: const Icon(Icons.tune),
                onPressed: _showFilterSheet,
                  tooltip: AppLocalizations.of(context)!.fieldsListView_filter,
              ),
                const SizedBox(width: 8),
            ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  padding: const EdgeInsets.only(top: 80, left: 16, right: 16),
                ),
              ),
            bottom: PreferredSize(
                preferredSize: const Size.fromHeight(70),
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                      IconButton.filledTonal(
                        icon: const Icon(Icons.chevron_left),
                      onPressed: _selectedDate.isAfter(DateTime.now())
                          ? () => _changeDate(-1)
                          : null,
                        style: IconButton.styleFrom(
                          backgroundColor: colorScheme.primary.withOpacity(0.1),
                          foregroundColor: colorScheme.primary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                      children: [
                        Text(
                          DateFormat('MMMM d', AppLocalizations.of(context)!.localeName).format(_selectedDate),
                          style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: colorScheme.primary,
                          ),
                        ),
                        Text(
                          DateFormat('EEEE', AppLocalizations.of(context)!.localeName).format(_selectedDate),
                          style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.primary.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                      ),
                      IconButton.filledTonal(
                        icon: const Icon(Icons.chevron_right),
                      onPressed: _selectedDate.isBefore(
                        DateTime.now().add(const Duration(days: 14)),
                      )
                          ? () => _changeDate(1)
                          : null,
                        style: IconButton.styleFrom(
                          backgroundColor: colorScheme.primary.withOpacity(0.1),
                          foregroundColor: colorScheme.primary,
                        ),
                    ),
                  ],
                ),
              ),
            ),
          ),
            if (_selectedLocation.isNotEmpty || (!_anyDistance && _isLocationEnabled))
            SliverToBoxAdapter(
              child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                    runSpacing: 8,
                  children: [
                      if (_selectedLocation.isNotEmpty)
                        Chip(
                          avatar: const Icon(Icons.location_on, size: 18),
                      label: Text(_selectedLocation),
                          onDeleted: () => setState(() {
                            _selectedLocation = '';
                            _fetchFootballFields(isInitialLoad: true); // Removing filter means initial load
                          }),
                      deleteIcon: const Icon(Icons.close, size: 18),
                          backgroundColor: colorScheme.primary.withOpacity(0.1),
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      if (!_anyDistance && _isLocationEnabled && widget.currentPosition != null)
                        Chip(
                          avatar: const Icon(Icons.route, size: 18),
                        label: Text(AppLocalizations.of(context)!.fieldsListView_withinRadiusKm(_radius.toInt())),
                          onDeleted: () => setState(() {
                            _anyDistance = true;
                            _fetchFootballFields(isInitialLoad: true); // Removing filter means initial load
                          }),
                          deleteIcon: const Icon(Icons.close, size: 18),
                          backgroundColor: colorScheme.primary.withOpacity(0.1),
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                      ),
                  ],
                ),
              ),
            ),
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_displayedFields.isEmpty && !_isLoading) // Check _displayedFields
            SliverFillRemaining(
              child: _EmptyState(
                onRefresh: () => _fetchFootballFields(isInitialLoad: true),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList.builder(
                itemCount: _displayedFields.length + (_isFetchingMore && _hasMoreFieldsToLoad ? 1 : 0), // Show loader only if fetching and more might exist
                itemBuilder: (context, index) {
                  if (index == _displayedFields.length && _isFetchingMore && _hasMoreFieldsToLoad) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (index >= _displayedFields.length) return const SizedBox.shrink();

                  return _FieldCard(
                    field: _displayedFields[index], // Use _displayedFields
                    currentPosition: _currentPosition,
                    isLocationEnabled: _isLocationEnabled,
                    onTap: () {
                      if (widget.playerProfile.isGuest) {
                        CustomDialog.show(
                          context: context,
                          title: AppLocalizations.of(context)!.createAccountDialogTitle,
                          message: AppLocalizations.of(context)!.fieldsListView_createAccountToBook,
                          confirmText: AppLocalizations.of(context)!.signUpButton,
                          cancelText: AppLocalizations.of(context)!.cancel,
                          icon: Icons.account_circle_outlined,
                          onConfirm: () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (context) => const LoginWithPasswordScreen(),
                              ),
                            );
                          },
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FieldBookingScreen(
                              field: _displayedFields[index], // Use _displayedFields
                              playerProfile: widget.playerProfile,
                              selectedDate: _selectedDate,
                            ),
                        ),
                      );
                    }
                  },
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

class _FilterBottomSheet extends StatefulWidget {
  final List<String> locations;
  final String selectedLocation;
  final double radius;
  final bool anyDistance;
  final ValueChanged<String> onLocationChanged;
  final ValueChanged<double> onRadiusChanged;
  final ValueChanged<bool> onAnyDistanceChanged;
  final VoidCallback onApply;

  const _FilterBottomSheet({
    required this.locations,
    required this.selectedLocation,
    required this.radius,
    required this.anyDistance,
    required this.onLocationChanged,
    required this.onRadiusChanged,
    required this.onAnyDistanceChanged,
    required this.onApply,
  });

  @override
  State<_FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<_FilterBottomSheet> {
  late String _location;
  late double _radius;
  late bool _anyDistance;

  @override
  void initState() {
    super.initState();
    _location = widget.selectedLocation;
    _radius = widget.radius;
    _anyDistance = widget.anyDistance;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.filter_list,
                      color: colorScheme.primary,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                Text(
                  AppLocalizations.of(context)!.fieldsListView_filterFields,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                  ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Location section
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 20,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context)!.fieldsListView_location,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                  ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceVariant.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.locations.map((location) {
                    return ChoiceChip(
                      label: Text(location),
                      selected: _location == location,
                      onSelected: (selected) {
                        setState(() => _location = selected ? location : '');
                        widget.onLocationChanged(_location);
                      },
                        selectedColor: colorScheme.primary.withOpacity(0.2),
                        backgroundColor: Colors.transparent,
                        checkmarkColor: colorScheme.primary,
                        labelStyle: TextStyle(
                          color: _location == location
                              ? colorScheme.primary
                              : colorScheme.onSurface,
                          fontWeight: _location == location
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: _location == location
                                ? colorScheme.primary
                                : Colors.transparent,
                          ),
                        ),
                    );
                  }).toList(),
                  ),
                ),
                const SizedBox(height: 24),
                // Distance section
                Row(
                  children: [
                    Icon(
                      Icons.route,
                      size: 20,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context)!.fieldsListView_distance,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Any distance switch
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: _anyDistance
                        ? colorScheme.primary.withOpacity(0.1)
                        : colorScheme.surfaceVariant.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _anyDistance
                          ? colorScheme.primary
                          : Colors.transparent,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.fieldsListView_anyDistance,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: _anyDistance ? FontWeight.bold : FontWeight.normal,
                          color: _anyDistance ? colorScheme.primary : colorScheme.onSurface,
                        ),
                      ),
                      Switch(
                        value: _anyDistance,
                        onChanged: (value) {
                          setState(() => _anyDistance = value);
                          widget.onAnyDistanceChanged(value);
                        },
                        activeColor: colorScheme.primary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Distance slider (disabled when Any Distance is selected)
                AnimatedOpacity(
                  opacity: _anyDistance ? 0.5 : 1.0,
                  duration: const Duration(milliseconds: 300),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: _radius,
                        min: 1,
                              max: 20,
                              divisions: 19,
                        label: AppLocalizations.of(context)!.fieldsListView_radiusKm(_radius.toInt()),
                              onChanged: _anyDistance
                                  ? null
                                  : (value) {
                          setState(() => _radius = value);
                          widget.onRadiusChanged(value);
                        },
                              activeColor: colorScheme.primary,
                              inactiveColor: colorScheme.primary.withOpacity(0.2),
                            ),
                          ),
                          Container(
                            width: 60,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                      child: Text(
                        AppLocalizations.of(context)!.fieldsListView_radiusKm(_radius.toInt()),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              AppLocalizations.of(context)!.fieldsListView_minRadius,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                            Text(
                              AppLocalizations.of(context)!.fieldsListView_maxRadius,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                // Apply filters button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                  onPressed: widget.onApply,
                    icon: const Icon(Icons.check),
                    label: Text(
                      AppLocalizations.of(context)!.fieldsListView_applyFilters,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldCard extends StatefulWidget {
  final FootballField field;
  final Position? currentPosition;
  final bool isLocationEnabled;
  final VoidCallback onTap;

  const _FieldCard({
    required this.field,
    required this.currentPosition,
    required this.isLocationEnabled,
    required this.onTap,
  });

  @override
  State<_FieldCard> createState() => _FieldCardState();
}

class _FieldCardState extends State<_FieldCard> with SingleTickerProviderStateMixin {
  int _currentPage = 0;
  final PageController _pageController = PageController();
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  String _getDistanceText() {
    if (!widget.isLocationEnabled || widget.currentPosition == null) return '';
    
    final distance = Geolocator.distanceBetween(
      widget.currentPosition!.latitude,
      widget.currentPosition!.longitude,
      widget.field.latitude,
      widget.field.longitude,
    );
    
    return distance < 1000
        ? AppLocalizations.of(context)!.fieldsListView_distanceMetersAway(distance.round().toString())
        : AppLocalizations.of(context)!.fieldsListView_distanceKmAway((distance / 1000).toStringAsFixed(1));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasDistance = widget.isLocationEnabled && widget.currentPosition != null;
    
    return FadeTransition(
      opacity: _animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.05),
          end: Offset.zero,
        ).animate(_animation),
        child: Container(
      margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
      child: InkWell(
              onTap: widget.onTap,
              splashColor: colorScheme.primary.withOpacity(0.1),
              highlightColor: colorScheme.primary.withOpacity(0.05),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                  if (widget.field.photos.isNotEmpty)
                    Stack(
                      children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                          child: PageView.builder(
                            controller: _pageController,
                            onPageChanged: (index) => setState(() => _currentPage = index),
                            itemCount: widget.field.photos.length,
                            itemBuilder: (context, index) {
                              return Hero(
                                tag: 'field-${widget.field.id}-$index',
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.network(
                                      widget.field.photos[index],
                    fit: BoxFit.cover,
                                      loadingBuilder: (context, child, loadingProgress) {
                                        if (loadingProgress == null) return child;
                                        return Container(
                                          color: colorScheme.surfaceVariant,
                                          child: Center(
                                            child: CircularProgressIndicator(
                                              value: loadingProgress.expectedTotalBytes != null
                                                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                                  : null,
                                              color: colorScheme.primary,
                                            ),
                                          ),
                                        );
                                      },
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          color: colorScheme.surfaceVariant,
                                          child: const Center(
                                            child: Icon(Icons.broken_image_outlined, size: 48),
                                          ),
                                        );
                                      },
                                    ),
                                    // Gradient overlay
                                    Positioned.fill(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Colors.transparent,
                                              Colors.black.withOpacity(0.5),
                                            ],
                                            stops: const [0.7, 1.0],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        // Field size chip on the top left
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                                  Icons.sports_soccer,
                        size: 16,
                                  color: Colors.white.withOpacity(0.9),
                      ),
                                const SizedBox(width: 6),
                      Text(
                                  widget.field.fieldSize,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Price chip on the top right
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              AppLocalizations.of(context)!.fieldsListView_priceRangeEgpHour(widget.field.priceRange),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        // Field name on the bottom
                        Positioned(
                          bottom: 12,
                          left: 12,
                          right: 12,
                          child: Text(
                            widget.field.footballFieldName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  blurRadius: 4,
                                  color: Colors.black.withOpacity(0.5),
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Page indicator
                        if (widget.field.photos.length > 1)
                          Positioned(
                            bottom: 12,
                            right: 0,
                            left: 0,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: List.generate(
                                    widget.field.photos.length,
                                    (index) => Container(
                                      width: 6,
                                      height: 6,
                                      margin: const EdgeInsets.symmetric(horizontal: 3),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: _currentPage == index
                                            ? Colors.white
                                            : Colors.white.withOpacity(0.5),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  // Details section
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Location info with distance
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 16,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                widget.field.locationName,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurface.withOpacity(0.8),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Distance chip - prominently display distance
                            if (hasDistance && _getDistanceText().isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.near_me,
                                      size: 14,
                                      color: colorScheme.primary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _getDistanceText(),
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: colorScheme.primary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Amenities
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                      children: [
                            if (widget.field.amenities['parking'] == true)
                      _FieldFeatureChip(
                                icon: Icons.local_parking,
                        label: AppLocalizations.of(context)!.fieldsListView_amenityParking,
                                colorScheme: colorScheme,
                      ),
                            if (widget.field.amenities['toilets'] == true)
                      _FieldFeatureChip(
                                icon: Icons.wc,
                                label: AppLocalizations.of(context)!.fieldsListView_amenityRestrooms,
                                colorScheme: colorScheme,
                      ),
                            if (widget.field.amenities['cafeteria'] == true)
                      _FieldFeatureChip(
                                icon: Icons.restaurant,
                                label: AppLocalizations.of(context)!.fieldsListView_amenityCafeteria,
                                colorScheme: colorScheme,
                              ),
                            if (widget.field.amenities['floodlights'] == true)
                              _FieldFeatureChip(
                                icon: Icons.lightbulb,
                                label: AppLocalizations.of(context)!.fieldsListView_amenityFloodlights,
                                colorScheme: colorScheme,
                              ),
                            if (widget.field.amenities['cameraRecording'] == true)
                              _FieldFeatureChip(
                                icon: Icons.videocam,
                                label: AppLocalizations.of(context)!.fieldsListView_amenityRecording,
                                colorScheme: colorScheme,
                                isHighlighted: true, // Camera recording stands out
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldFeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final ColorScheme colorScheme;
  final bool isHighlighted;

  const _FieldFeatureChip({
    required this.icon,
    required this.label,
    required this.colorScheme,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    // Camera recording gets a special red/orange highlight color to stand out
    final highlightColor = const Color(0xFFE53935); // Vibrant red for camera
    final chipColor = isHighlighted ? highlightColor : colorScheme.primary;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isHighlighted 
            ? highlightColor.withOpacity(0.15)
            : colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: isHighlighted 
            ? Border.all(color: highlightColor.withOpacity(0.5), width: 1)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: chipColor,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: chipColor,
              fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onRefresh;

  const _EmptyState({
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.sports_soccer,
                size: 60,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              AppLocalizations.of(context)!.fieldsListView_noFieldsFound,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context)!.fieldsListView_noFieldsFoundSubtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.tonalIcon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              label: Text(AppLocalizations.of(context)!.fieldsListView_refresh),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Add this extension for better handling of date comparisons
extension DateTimeExtension on DateTime {
  bool isSameDay(DateTime other) {
    return year == other.year && month == other.month && day == other.day;
  }

  DateTime get dateOnly {
    return DateTime(year, month, day);
  }
}

// Add this mixin to handle refresh functionality if needed
mixin RefreshableState<T extends StatefulWidget> on State<T> {
  bool _isRefreshing = false;

  Future<void> refresh() async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);
    try {
      await onRefresh();
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  Future<void> onRefresh();
}
