import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:playmakerappstart/models/footballfield_model.dart';
import 'package:playmakerappstart/services/supabase_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:playmakerappstart/screens/admin/create_football_field_screen.dart';
import 'package:playmakerappstart/screens/admin/admin_field_management_screen.dart';

class AdminFieldsScreen extends StatefulWidget {
  const AdminFieldsScreen({Key? key}) : super(key: key);

  @override
  State<AdminFieldsScreen> createState() => _AdminFieldsScreenState();
}

class _AdminFieldsScreenState extends State<AdminFieldsScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  List<FootballField> _fields = [];
  List<FootballField> _filteredFields = [];
  bool _isLoading = true;
  
  // Filter state
  String? _selectedCity;
  String? _selectedArea;
  String _sortBy = 'newest'; // 'newest', 'oldest', 'name'
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  // Available filter options (populated from data)
  List<String> _availableCities = [];
  List<String> _availableAreas = [];
  
  // Click stats for each field
  Map<String, Map<String, dynamic>> _fieldClickStats = {};

  @override
  void initState() {
    super.initState();
    _fetchFields();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchFields() async {
    setState(() => _isLoading = true);
    try {
      // Include disabled fields in admin view
      final result = await _supabaseService.getFootballFields(limit: 100, includeDisabled: true);
      
      // Fetch click stats for all fields
      await _fetchClickStats();
      
      if (mounted) {
        setState(() {
          _fields = result.fields;
          _extractFilterOptions();
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching fields: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Failed to load fields');
      }
    }
  }
  
  Future<void> _fetchClickStats() async {
    try {
      final allStats = await _supabaseService.getAllFieldsClickStats();
      final Map<String, Map<String, dynamic>> statsMap = {};
      
      for (final stat in allStats) {
        statsMap[stat['field_id']] = stat;
      }
      
      if (mounted) {
        setState(() {
          _fieldClickStats = statsMap;
        });
      }
    } catch (e) {
      print('Error fetching click stats: $e');
    }
  }
  
  void _extractFilterOptions() {
    // Extract unique cities and areas from fields
    final cities = <String>{};
    final areas = <String>{};
    
    for (final field in _fields) {
      // Use city field if available, otherwise extract from locationName
      if (field.city != null && field.city!.isNotEmpty) {
        cities.add(field.city!);
      } else {
        // Try to extract city from locationName (e.g., "Cairo, Maadi" -> "Cairo")
        final parts = field.locationName.split(',');
        if (parts.isNotEmpty) {
          cities.add(parts[0].trim());
        }
      }
      
      // Use area field if available, otherwise extract from locationName
      if (field.area != null && field.area!.isNotEmpty) {
        areas.add(field.area!);
      } else {
        // Try to extract area from locationName (e.g., "Cairo, Maadi" -> "Maadi")
        final parts = field.locationName.split(',');
        if (parts.length > 1) {
          areas.add(parts[1].trim());
        } else if (field.streetName.isNotEmpty) {
          areas.add(field.streetName);
        }
      }
    }
    
    _availableCities = cities.toList()..sort();
    _availableAreas = areas.toList()..sort();
  }
  
  void _applyFilters() {
    List<FootballField> filtered = List.from(_fields);
    
    // Filter by city
    if (_selectedCity != null && _selectedCity!.isNotEmpty) {
      filtered = filtered.where((field) {
        if (field.city != null && field.city!.isNotEmpty) {
          return field.city!.toLowerCase() == _selectedCity!.toLowerCase();
        }
        return field.locationName.toLowerCase().contains(_selectedCity!.toLowerCase());
      }).toList();
    }
    
    // Filter by name (search)
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((field) => 
        field.footballFieldName.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }
    
    // Filter by area
    if (_selectedArea != null && _selectedArea!.isNotEmpty) {
      filtered = filtered.where((field) {
        if (field.area != null && field.area!.isNotEmpty) {
          return field.area!.toLowerCase() == _selectedArea!.toLowerCase();
        }
        return field.locationName.toLowerCase().contains(_selectedArea!.toLowerCase()) ||
               field.streetName.toLowerCase().contains(_selectedArea!.toLowerCase());
      }).toList();
    }
    
    // Sort
    switch (_sortBy) {
      case 'newest':
        filtered.sort((a, b) {
          final aDate = a.createdAt ?? DateTime(2000);
          final bDate = b.createdAt ?? DateTime(2000);
          return bDate.compareTo(aDate); // Descending (newest first)
        });
        break;
      case 'oldest':
        filtered.sort((a, b) {
          final aDate = a.createdAt ?? DateTime(2000);
          final bDate = b.createdAt ?? DateTime(2000);
          return aDate.compareTo(bDate); // Ascending (oldest first)
        });
        break;
      case 'name':
        filtered.sort((a, b) => a.footballFieldName.compareTo(b.footballFieldName));
        break;
    }
    
    _filteredFields = filtered;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _navigateToCreateField() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateFootballFieldScreen(),
      ),
    );
    
    if (result == true) {
      _fetchFields(); // Refresh list
    }
  }

  Future<void> _navigateToFieldManagement(FootballField field) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminFieldManagementScreen(field: field),
      ),
    );
    
    if (result == true) {
      _fetchFields(); // Refresh list
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWideScreen = size.width > 900;
    final isMobile = size.width < 600;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), // Softer background
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            title: Text(
              'Football Fields',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold, 
                color: Colors.black87
              ),
            ),
            backgroundColor: Colors.white,
            elevation: 0,
            pinned: true,
            floating: true,
            iconTheme: const IconThemeData(color: Colors.black87),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF00BF63), // Brand green
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00BF63).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.add, color: Colors.white),
                  onPressed: _navigateToCreateField,
                  tooltip: 'Create New Field',
                ),
              ),
            ],
          ),
        ],
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Filter bar
                  _buildFilterBar(isMobile),
                  
                  // Fields list
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _fetchFields,
                      child: _filteredFields.isEmpty
                          ? _buildEmptyState()
                          : isMobile
                              ? ListView.separated(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: _filteredFields.length,
                                  separatorBuilder: (context, index) => const SizedBox(height: 16),
                                  itemBuilder: (context, index) {
                                    final field = _filteredFields[index];
                                    return _buildFieldCard(field, isMobile: true);
                                  },
                                )
                              : GridView.builder(
                                  padding: EdgeInsets.all(isWideScreen ? 24 : 16),
                                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: isWideScreen ? 4 : 3,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    childAspectRatio: isWideScreen ? 0.85 : 0.8,
                                  ),
                                  itemCount: _filteredFields.length,
                                  itemBuilder: (context, index) {
                                    final field = _filteredFields[index];
                                    return _buildFieldCard(field, isMobile: false);
                                  },
                                ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
  
  Widget _buildFilterBar(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats row
          Row(
            children: [
              Icon(Icons.sports_soccer, size: 18, color: Colors.green.shade600),
              const SizedBox(width: 8),
              Text(
                '${_filteredFields.length} of ${_fields.length} fields',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
              ),
              const Spacer(),
              if (_selectedCity != null || _selectedArea != null)
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedCity = null;
                      _selectedArea = null;
                      _applyFilters();
                    });
                  },
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('Clear Filters'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red.shade600,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Search Bar
          TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
                _applyFilters();
              });
            },
            decoration: InputDecoration(
              hintText: 'Search for field names...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchQuery.isNotEmpty 
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                          _applyFilters();
                        });
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
            ),
          ),
          const SizedBox(height: 12),
          
          // Filter dropdowns
          isMobile
              ? Column(
                  children: [
                    _buildCityDropdown(),
                    const SizedBox(height: 8),
                    _buildAreaDropdown(),
                    const SizedBox(height: 8),
                    _buildSortDropdown(),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: _buildCityDropdown()),
                    const SizedBox(width: 12),
                    Expanded(child: _buildAreaDropdown()),
                    const SizedBox(width: 12),
                    Expanded(child: _buildSortDropdown()),
                  ],
                ),
        ],
      ),
    );
  }
  
  Widget _buildCityDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCity,
          hint: Row(
            children: [
              Icon(Icons.location_city, size: 18, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              Text(
                'All Cities',
                style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade600),
              ),
            ],
          ),
          isExpanded: true,
          icon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Row(
                children: [
                  Icon(Icons.location_city, size: 18, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Text('All Cities', style: GoogleFonts.inter(fontSize: 14)),
                ],
              ),
            ),
            ..._availableCities.map((city) => DropdownMenuItem<String>(
              value: city,
              child: Text(city, style: GoogleFonts.inter(fontSize: 14)),
            )),
          ],
          onChanged: (value) {
            setState(() {
              _selectedCity = value;
              _applyFilters();
            });
          },
        ),
      ),
    );
  }
  
  Widget _buildAreaDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedArea,
          hint: Row(
            children: [
              Icon(Icons.place, size: 18, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              Text(
                'All Areas',
                style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade600),
              ),
            ],
          ),
          isExpanded: true,
          icon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Row(
                children: [
                  Icon(Icons.place, size: 18, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Text('All Areas', style: GoogleFonts.inter(fontSize: 14)),
                ],
              ),
            ),
            ..._availableAreas.map((area) => DropdownMenuItem<String>(
              value: area,
              child: Text(area, style: GoogleFonts.inter(fontSize: 14)),
            )),
          ],
          onChanged: (value) {
            setState(() {
              _selectedArea = value;
              _applyFilters();
            });
          },
        ),
      ),
    );
  }
  
  Widget _buildSortDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _sortBy,
          isExpanded: true,
          icon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
          items: [
            DropdownMenuItem<String>(
              value: 'newest',
              child: Row(
                children: [
                  Icon(Icons.arrow_downward, size: 18, color: Colors.green.shade600),
                  const SizedBox(width: 8),
                  Text('Newest First', style: GoogleFonts.inter(fontSize: 14)),
                ],
              ),
            ),
            DropdownMenuItem<String>(
              value: 'oldest',
              child: Row(
                children: [
                  Icon(Icons.arrow_upward, size: 18, color: Colors.orange.shade600),
                  const SizedBox(width: 8),
                  Text('Oldest First', style: GoogleFonts.inter(fontSize: 14)),
                ],
              ),
            ),
            DropdownMenuItem<String>(
              value: 'name',
              child: Row(
                children: [
                  Icon(Icons.sort_by_alpha, size: 18, color: Colors.blue.shade600),
                  const SizedBox(width: 8),
                  Text('By Name', style: GoogleFonts.inter(fontSize: 14)),
                ],
              ),
            ),
          ],
          onChanged: (value) {
            setState(() {
              _sortBy = value ?? 'newest';
              _applyFilters();
            });
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.sports_soccer,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 24),
          Text(
            'No Football Fields Yet',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first field to get started',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _navigateToCreateField,
            icon: const Icon(Icons.add),
            label: const Text('Create Field'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldCard(FootballField field, {required bool isMobile}) {
    return GestureDetector(
      onTap: () => _navigateToFieldManagement(field),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Image Header
            Stack(
              children: [
                field.photos.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: field.photos.first,
                height: isMobile ? 140 : 100,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                        height: isMobile ? 140 : 100,
                          color: Colors.grey.shade100,
                        ),
                        errorWidget: (context, url, error) => Container(
                        height: isMobile ? 140 : 100,
                          color: Colors.grey.shade100,
                          child: Icon(Icons.image_not_supported, color: Colors.grey.shade400),
                        ),
                      )
                    : Container(
                        height: isMobile ? 140 : 120,
                        width: double.infinity,
                        color: const Color(0xFF00BF63),
                        child: const Icon(Icons.sports_soccer, size: 48, color: Colors.white),
                      ),
                
                // Status Badge
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: field.bookable 
                          ? const Color(0xFF00BF63) 
                          : Colors.red.shade500,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          field.bookable ? Icons.check_circle : Icons.cancel,
                          size: 12,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          field.bookable ? 'Active' : 'Inactive',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Edit Button
                Positioned(
                  top: 8,
                  right: 8,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _navigateToFieldManagement(field),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.edit, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          field.footballFieldName,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        field.priceRange,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF00BF63),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 12, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          field.locationName,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Click Stats Row
                  if (_fieldClickStats.containsKey(field.id)) ...[
                    Row(
                      children: [
                        Icon(Icons.visibility, size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          '${_fieldClickStats[field.id]!['total_clicks'] ?? 0} views',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.today, size: 14, color: Colors.green.shade500),
                        const SizedBox(width: 4),
                        Text(
                          '${_fieldClickStats[field.id]!['clicks_today'] ?? 0} today',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.green.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                  
                  // Tags row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildTag(field.fieldSize, Colors.blue.shade50, Colors.blue.shade700),
                        const SizedBox(width: 8),
                        _buildTag('${_getTotalTimeSlots(field.availableTimeSlots)} slots', Colors.purple.shade50, Colors.purple.shade700),
                        if (!field.isEnabled) ...[
                          const SizedBox(width: 8),
                          _buildTag('DISABLED', Colors.red.shade100, Colors.red.shade700),
                        ],
                        if (field.blockedUsers.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          _buildTag('${field.blockedUsers.length} blocked', Colors.red.shade50, Colors.red.shade700),
                        ],
                        if (field.cameraIpAddress != null && field.cameraIpAddress!.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          _buildTag('📹 Camera', Colors.green.shade50, Colors.green.shade700),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Action Row (Footer)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _navigateToFieldManagement(field),
                          icon: const Icon(Icons.settings, size: 16),
                          label: const Text('Manage'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey.shade700,
                            side: BorderSide(color: Colors.grey.shade300),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showPriceManagementDialog(field),
                          icon: const Icon(Icons.payments, size: 16),
                          label: const Text('Prices'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00BF63),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String text, Color bg, Color textCol) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textCol,
        ),
      ),
    );
  }

  int _getTotalTimeSlots(Map<String, List<Map<String, dynamic>>> slots) {
    int total = 0;
    slots.forEach((key, value) {
      total += value.length;
    });
    return total;
  }

  void _showPriceManagementDialog(FootballField field) {
    final Map<String, List<Map<String, dynamic>>> editableSlots = {};
    field.availableTimeSlots.forEach((day, slots) {
      editableSlots[day] = slots.map((s) => Map<String, dynamic>.from(s)).toList();
    });

    final bulkPriceController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.payments, color: Color(0xFF00BF63)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Price Management',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Updating prices for ${field.footballFieldName}',
                        style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 20),
                      
                      // Bulk Update
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade100),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: bulkPriceController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  hintText: 'Bulk Price (EGP)',
                                  isDense: true,
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                final price = bulkPriceController.text.trim();
                                if (price.isNotEmpty) {
                                  setDialogState(() {
                                    editableSlots.forEach((day, slots) {
                                      for (var slot in slots) {
                                        slot['price'] = price;
                                      }
                                    });
                                  });
                                }
                              },
                              child: const Text('Apply to All'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // per day/slot list
                      ...editableSlots.keys.map((day) {
                        final slots = editableSlots[day]!;
                        if (slots.isEmpty) return const SizedBox.shrink();
                        
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                day,
                                style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.black87),
                              ),
                            ),
                            ...slots.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final slot = entry.value;
                              final priceController = TextEditingController(text: slot['price']?.toString() ?? '');
                              
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        '${slot['time']} - ${slot['duration']} min',
                                        style: GoogleFonts.inter(fontSize: 13),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextField(
                                        controller: priceController,
                                        keyboardType: TextInputType.number,
                                        onChanged: (val) {
                                          slot['price'] = val;
                                        },
                                        decoration: InputDecoration(
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                          suffixText: 'EGP',
                                        ),
                                        style: GoogleFonts.inter(fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            const Divider(),
                          ],
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      Navigator.pop(context);
                      setState(() => _isLoading = true);
                      
                      // Update Supabase
                      await _supabaseService.updateFootballField(field.id, {
                        'available_time_slots': editableSlots,
                      });
                      
                      _showError('Prices updated successfully');
                      _fetchFields(); // Refresh
                    } catch (e) {
                      _showError('Error updating prices: $e');
                      setState(() => _isLoading = false);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00BF63), foregroundColor: Colors.white),
                  child: const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
