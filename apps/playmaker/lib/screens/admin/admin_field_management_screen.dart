import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:playmakerappstart/models/footballfield_model.dart';
import 'package:playmakerappstart/services/supabase_service.dart';
import 'package:playmakerappstart/services/camera_script_generator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Clean, single-page Field Management Screen
/// All field editing in one scrollable page with expandable sections
class AdminFieldManagementScreen extends StatefulWidget {
  final FootballField field;

  const AdminFieldManagementScreen({Key? key, required this.field}) : super(key: key);

  @override
  State<AdminFieldManagementScreen> createState() => _AdminFieldManagementScreenState();
}

class _AdminFieldManagementScreenState extends State<AdminFieldManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _hasChanges = false;
  late FootballField _field;

  // Controllers
  late TextEditingController _nameController;
  late TextEditingController _streetController;
  late TextEditingController _cityController;
  late TextEditingController _areaController;
  late TextEditingController _priceController;
  late TextEditingController _openingHoursController;
  late TextEditingController _ownerNameController;
  late TextEditingController _ownerPhoneController;
  late TextEditingController _cameraIpController;
  late TextEditingController _cameraUsernameController;
  late TextEditingController _cameraPasswordController;
  late TextEditingController _piIpController;
  late TextEditingController _partnerUsernameController;
  late TextEditingController _partnerPasswordController;

  // State
  late String _selectedLocation;
  late String _fieldSize;
  late bool _bookable;
  late Map<String, bool> _amenities;
  late Map<String, List<Map<String, dynamic>>> _availableTimeSlots;

  // Expanded sections
  final Map<String, bool> _expandedSections = {
    'basic': true,
    'analytics': false,
    'timeslots': false,
    'amenities': false,
    'owner': false,
    'camera': false,
    'blocked': false,
    'danger': false,
  };
  
  // Click analytics
  Map<String, dynamic> _clickStats = {};
  List<Map<String, dynamic>> _recentClicks = [];
  bool _loadingAnalytics = false;

  // Blocked users
  List<Map<String, dynamic>> _blockedUsers = [];
  bool _loadingBlockedUsers = false;

  @override
  void initState() {
    super.initState();
    _field = widget.field;
    _initializeControllers();
    _loadBlockedUsers();
    _loadClickAnalytics();
  }

  void _initializeControllers() {
    _nameController = TextEditingController(text: _field.footballFieldName);
    _streetController = TextEditingController(text: _field.streetName);
    _cityController = TextEditingController(text: _field.city ?? '');
    _areaController = TextEditingController(text: _field.area ?? '');
    _priceController = TextEditingController(text: _field.priceRange);
    _openingHoursController = TextEditingController(text: _field.openingHours);
    _ownerNameController = TextEditingController(text: _field.ownerName ?? '');
    _ownerPhoneController = TextEditingController(text: _field.ownerPhoneNumber ?? '');
    _cameraIpController = TextEditingController(text: _field.cameraIpAddress ?? '');
    _cameraUsernameController = TextEditingController(text: _field.cameraUsername ?? '');
    _cameraPasswordController = TextEditingController(text: _field.cameraPassword ?? '');
    _piIpController = TextEditingController(text: _field.raspberryPiIp ?? '');
    _partnerUsernameController = TextEditingController(text: _field.username);
    _partnerPasswordController = TextEditingController(text: _field.password);
    _selectedLocation = _field.locationName;
    _fieldSize = _field.fieldSize;
    _bookable = _field.bookable;

    // Initialize amenities
    _amenities = Map<String, bool>.from(_field.amenities);
    final defaultAmenities = [
      'parking', 'toilets', 'cafeteria', 'floodlights',
      'qualityField', 'ballIncluded', 'cameraRecording'
    ];
    for (var key in defaultAmenities) {
      if (!_amenities.containsKey(key)) {
        _amenities[key] = false;
      }
    }

    // Initialize timeslots - normalize day names to capitalized format
    _availableTimeSlots = {};
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    
    // Initialize all days with empty lists first
    for (var day in days) {
      _availableTimeSlots[day] = [];
    }
    
    // Copy existing timeslots, normalizing day names
    _field.availableTimeSlots.forEach((day, slots) {
      // Normalize day name to capitalized format
      String normalizedDay = _normalizeDayName(day);
      if (_availableTimeSlots.containsKey(normalizedDay)) {
        _availableTimeSlots[normalizedDay] = List<Map<String, dynamic>>.from(
          slots.map((s) => Map<String, dynamic>.from(s)),
        );
      }
    });
  }
  
  /// Normalize day name to capitalized format for display (e.g., "monday" -> "Monday")
  String _normalizeDayName(String day) {
    final dayLower = day.toLowerCase().trim();
    final dayMap = {
      'monday': 'Monday',
      'tuesday': 'Tuesday',
      'wednesday': 'Wednesday',
      'thursday': 'Thursday',
      'friday': 'Friday',
      'saturday': 'Saturday',
      'sunday': 'Sunday',
    };
    return dayMap[dayLower] ?? day;
  }


  @override
  void dispose() {
    _nameController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _areaController.dispose();
    _priceController.dispose();
    _openingHoursController.dispose();
    _ownerNameController.dispose();
    _ownerPhoneController.dispose();
    _cameraIpController.dispose();
    _cameraUsernameController.dispose();
    _cameraPasswordController.dispose();
    _piIpController.dispose();
    _partnerUsernameController.dispose();
    _partnerPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadBlockedUsers() async {
    if (_field.blockedUsers.isEmpty) return;

    setState(() => _loadingBlockedUsers = true);
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('player_profiles')
          .select('id, name, email, phone_number')
          .inFilter('id', _field.blockedUsers);

      setState(() {
        _blockedUsers = List<Map<String, dynamic>>.from(response);
        _loadingBlockedUsers = false;
      });
    } catch (e) {
      print('Error loading blocked users: $e');
      setState(() => _loadingBlockedUsers = false);
    }
  }
  
  Future<void> _loadClickAnalytics() async {
    setState(() => _loadingAnalytics = true);
    try {
      final supabaseService = SupabaseService();
      final stats = await supabaseService.getFieldClickStats(_field.id);
      final clicks = await supabaseService.getRecentFieldClicks(_field.id, limit: 20);
      
      if (mounted) {
        setState(() {
          _clickStats = stats;
          _recentClicks = clicks;
          _loadingAnalytics = false;
        });
      }
    } catch (e) {
      print('Error loading click analytics: $e');
      if (mounted) {
        setState(() => _loadingAnalytics = false);
      }
    }
  }

  int _getTotalTimeSlots() {
    int total = 0;
    _availableTimeSlots.forEach((_, slots) => total += slots.length);
    return total;
  }

  Future<bool> _onWillPop() async {
    Navigator.pop(context, _hasChanges);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: CustomScrollView(
          slivers: [
            _buildSliverAppBar(),
            SliverToBoxAdapter(
              child: Form(
                key: _formKey,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Quick Stats
                      _buildQuickStats(),
                      const SizedBox(height: 20),

                      // Status Toggle
                      _buildStatusCard(),
                      const SizedBox(height: 12),

                      // Basic Information
                      _buildExpandableSection(
                        key: 'basic',
                        title: 'Basic Information',
                        icon: Icons.info_outline,
                        child: _buildBasicInfoContent(),
                      ),
                      const SizedBox(height: 12),

                      // Analytics Section
                      _buildExpandableSection(
                        key: 'analytics',
                        title: 'View Analytics',
                        icon: Icons.analytics,
                        badge: '${_clickStats['total_clicks'] ?? 0} views',
                        badgeColor: Colors.purple,
                        child: _buildAnalyticsContent(),
                      ),
                      const SizedBox(height: 12),

                      // Timeslots - THE KEY FEATURE!
                      _buildExpandableSection(
                        key: 'timeslots',
                        title: 'Timeslots',
                        icon: Icons.schedule,
                        badge: '${_getTotalTimeSlots()} slots',
                        badgeColor: Colors.blue,
                        child: _buildTimeslotsContent(),
                      ),
                      const SizedBox(height: 12),

                      // Amenities
                      _buildExpandableSection(
                        key: 'amenities',
                        title: 'Amenities',
                        icon: Icons.star,
                        child: _buildAmenitiesContent(),
                      ),
                      const SizedBox(height: 12),

                      // Owner Contact
                      _buildExpandableSection(
                        key: 'owner',
                        title: 'Owner & Partner',
                        icon: Icons.person,
                        child: _buildOwnerContent(),
                      ),
                      const SizedBox(height: 12),

                      // Camera Settings
                      _buildExpandableSection(
                        key: 'camera',
                        title: 'Camera Settings',
                        icon: Icons.videocam,
                        badge: _cameraIpController.text.isNotEmpty ? 'Configured' : null,
                        badgeColor: Colors.green,
                        child: _buildCameraContent(),
                      ),
                      const SizedBox(height: 12),

                      // Blocked Users
                      _buildExpandableSection(
                        key: 'blocked',
                        title: 'Blocked Users',
                        icon: Icons.block,
                        badge: _field.blockedUsers.isNotEmpty ? '${_field.blockedUsers.length}' : null,
                        badgeColor: Colors.red,
                        child: _buildBlockedUsersContent(),
                      ),
                      const SizedBox(height: 12),

                      // Danger Zone
                      _buildExpandableSection(
                        key: 'danger',
                        title: 'Danger Zone',
                        icon: Icons.warning,
                        iconColor: Colors.red,
                        child: _buildDangerZoneContent(),
                      ),
                      const SizedBox(height: 24),

                      // Save Button
                      _buildSaveButton(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
        ),
        onPressed: () => Navigator.pop(context, _hasChanges),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            _field.photos.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: _field.photos.first,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(color: const Color(0xFF00BF63)),
                    errorWidget: (context, url, error) => Container(
                      color: const Color(0xFF00BF63),
                      child: const Icon(Icons.sports_soccer, color: Colors.white, size: 64),
                    ),
                  )
                : Container(
                    color: const Color(0xFF00BF63),
                    child: const Icon(Icons.sports_soccer, color: Colors.white, size: 64),
                  ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                ),
              ),
            ),
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _field.footballFieldName,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.white70, size: 16),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _field.locationName,
                          style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
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

  Widget _buildQuickStats() {
    return Row(
      children: [
        Expanded(child: _buildStatCard('Timeslots', '${_getTotalTimeSlots()}', Icons.schedule, Colors.blue)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('Photos', '${_field.photos.length}', Icons.photo_library, Colors.purple)),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Blocked',
            '${_field.blockedUsers.length}',
            Icons.block,
            _field.blockedUsers.isEmpty ? Colors.green : Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(value, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: color.shade700)),
          Text(label, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _bookable ? Colors.green.shade50 : Colors.red.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _bookable ? Icons.check_circle : Icons.cancel,
              color: _bookable ? Colors.green : Colors.red,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Field Status', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15)),
                Text(
                  _bookable ? 'Active - Accepting Bookings' : 'Inactive - Not Accepting Bookings',
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Switch(
            value: _bookable,
            onChanged: (v) => setState(() {
              _bookable = v;
              _hasChanges = true;
            }),
            activeColor: const Color(0xFF00BF63),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandableSection({
    required String key,
    required String title,
    required IconData icon,
    required Widget child,
    String? badge,
    Color? badgeColor,
    Color? iconColor,
  }) {
    final isExpanded = _expandedSections[key] ?? false;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expandedSections[key] = !isExpanded),
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(12),
              bottom: isExpanded ? Radius.zero : const Radius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (iconColor ?? const Color(0xFF00BF63)).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: iconColor ?? const Color(0xFF00BF63), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15)),
                  ),
                  if (badge != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (badgeColor ?? Colors.grey).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        badge,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: badgeColor ?? Colors.grey,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: child,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAnalyticsContent() {
    if (_loadingAnalytics) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stats Cards
        Row(
          children: [
            Expanded(
              child: _buildAnalyticsStatCard(
                'Total Views',
                '${_clickStats['total_clicks'] ?? 0}',
                Icons.visibility,
                Colors.purple,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildAnalyticsStatCard(
                'Today',
                '${_clickStats['clicks_today'] ?? 0}',
                Icons.today,
                Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildAnalyticsStatCard(
                'This Week',
                '${_clickStats['clicks_this_week'] ?? 0}',
                Icons.calendar_view_week,
                Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildAnalyticsStatCard(
                'This Month',
                '${_clickStats['clicks_this_month'] ?? 0}',
                Icons.calendar_month,
                Colors.blue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildAnalyticsStatCard(
          'Unique Users',
          '${_clickStats['unique_users'] ?? 0}',
          Icons.people,
          Colors.teal,
        ),
        
        const SizedBox(height: 24),
        
        // Recent Clicks
        Text(
          'Recent Views',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        
        if (_recentClicks.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                'No views yet',
                style: GoogleFonts.inter(
                  color: Colors.grey.shade500,
                  fontSize: 14,
                ),
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recentClicks.length > 10 ? 10 : _recentClicks.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
              itemBuilder: (context, index) {
                final click = _recentClicks[index];
                final clickedAt = DateTime.tryParse(click['clicked_at'] ?? '') ?? DateTime.now();
                final timeAgo = _formatTimeAgo(clickedAt);
                
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.purple.shade50,
                    child: Icon(Icons.person, color: Colors.purple.shade400, size: 20),
                  ),
                  title: Text(
                    click['user_name'] ?? 'Anonymous',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    click['user_email'] ?? 'N/A',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  trailing: Text(
                    timeAgo,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                );
              },
            ),
          ),
        
        const SizedBox(height: 16),
        
        // Refresh Button
        Center(
          child: TextButton.icon(
            onPressed: _loadClickAnalytics,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh Analytics'),
          ),
        ),
      ],
    );
  }
  
  Widget _buildAnalyticsStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  Widget _buildBasicInfoContent() {
    return Column(
      children: [
        _buildTextField(_nameController, 'Field Name', Icons.sports_soccer),
        _buildTextField(_streetController, 'Street Name', Icons.map),
        _buildTextField(_cityController, 'City', Icons.location_city),
        _buildTextField(_areaController, 'Area', Icons.place),
        _buildTextField(_priceController, 'Price (EGP)', Icons.attach_money),
        _buildTextField(_openingHoursController, 'Opening Hours', Icons.schedule),
        const SizedBox(height: 8),
        _buildDropdown('Field Size', _fieldSize, ['5-a-side', '7-a-side', '11-a-side'], (v) {
          setState(() {
            _fieldSize = v!;
            _hasChanges = true;
          });
        }),
      ],
    );
  }

  // =====================================================
  // TIMESLOTS MANAGEMENT - Key Feature!
  // =====================================================
  Widget _buildTimeslotsContent() {
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Auto-generate button
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _showAutoGenerateDialog,
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const Text('Auto-Generate Timeslots'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF00BF63),
                  side: const BorderSide(color: Color(0xFF00BF63)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Days list
        ...days.map((day) {
          final slots = _availableTimeSlots[day] ?? [];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                // Day header
                InkWell(
                  onTap: () => _addTimeSlot(day),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Text(
                          day,
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: slots.isEmpty ? Colors.orange.shade100 : Colors.green.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${slots.length} slots',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: slots.isEmpty ? Colors.orange.shade800 : Colors.green.shade800,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00BF63).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.add, size: 18, color: Color(0xFF00BF63)),
                        ),
                      ],
                    ),
                  ),
                ),
                // Slots list
                if (slots.isNotEmpty) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: slots.asMap().entries.map((entry) {
                        final index = entry.key;
                        final slot = entry.value;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                slot['time'] ?? '',
                                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(width: 6),
                              InkWell(
                                onTap: () => _removeTimeSlot(day, index),
                                child: Icon(Icons.close, size: 16, color: Colors.red.shade400),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  void _addTimeSlot(String day) {
    TimeOfDay? fromTime;
    TimeOfDay? toTime;
    bool applyToAll = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.schedule, color: Color(0xFF00BF63)),
              const SizedBox(width: 8),
              Expanded(child: Text('Add Timeslot - $day', style: GoogleFonts.inter(fontSize: 18))),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // From time
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('From', style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                trailing: TextButton(
                  onPressed: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: fromTime ?? const TimeOfDay(hour: 16, minute: 0),
                    );
                    if (time != null) setDialogState(() => fromTime = time);
                  },
                  child: Text(
                    fromTime != null ? fromTime!.format(context) : 'Select',
                    style: GoogleFonts.inter(
                      color: fromTime != null ? Colors.black87 : Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              // To time
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('To', style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                trailing: TextButton(
                  onPressed: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: toTime ?? const TimeOfDay(hour: 17, minute: 0),
                    );
                    if (time != null) setDialogState(() => toTime = time);
                  },
                  child: Text(
                    toTime != null ? toTime!.format(context) : 'Select',
                    style: GoogleFonts.inter(
                      color: toTime != null ? Colors.black87 : Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Apply to all days
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: applyToAll,
                onChanged: (v) => setDialogState(() => applyToAll = v ?? false),
                title: Text('Apply to all days', style: GoogleFonts.inter(fontSize: 14)),
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: const Color(0xFF00BF63),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: fromTime != null && toTime != null
                  ? () {
                      final from = '${fromTime!.hour.toString().padLeft(2, '0')}:${fromTime!.minute.toString().padLeft(2, '0')}';
                      final to = '${toTime!.hour.toString().padLeft(2, '0')}:${toTime!.minute.toString().padLeft(2, '0')}';
                      final timeSlotString = '$from - $to';

                      // Parse price as number (int for user app compatibility)
                      final priceNum = int.tryParse(_priceController.text) ?? 300;
                      
                      setState(() {
                        if (applyToAll) {
                          for (var dayKey in _availableTimeSlots.keys) {
                            _availableTimeSlots[dayKey]!.add({'time': timeSlotString, 'price': priceNum});
                            _availableTimeSlots[dayKey]!.sort((a, b) => (a['time'] ?? '').compareTo(b['time'] ?? ''));
                          }
                        } else {
                          _availableTimeSlots[day]!.add({'time': timeSlotString, 'price': priceNum});
                          _availableTimeSlots[day]!.sort((a, b) => (a['time'] ?? '').compareTo(b['time'] ?? ''));
                        }
                        _hasChanges = true;
                      });
                      Navigator.pop(context);
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00BF63),
                foregroundColor: Colors.white,
              ),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _removeTimeSlot(String day, int index) {
    setState(() {
      _availableTimeSlots[day]!.removeAt(index);
      _hasChanges = true;
    });
  }

  void _showAutoGenerateDialog() {
    int startHour = 16;
    int endHour = 23;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.auto_awesome, color: Color(0xFF00BF63)),
              const SizedBox(width: 8),
              Text('Auto-Generate Timeslots', style: GoogleFonts.inter(fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'This will create hourly timeslots for all days.',
                style: GoogleFonts.inter(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 20),
              // Start hour
              Row(
                children: [
                  Expanded(child: Text('Start Hour', style: GoogleFonts.inter(fontWeight: FontWeight.w500))),
                  DropdownButton<int>(
                    value: startHour,
                    items: List.generate(24, (i) => i)
                        .map((h) => DropdownMenuItem(value: h, child: Text('${h.toString().padLeft(2, '0')}:00')))
                        .toList(),
                    onChanged: (v) => setDialogState(() => startHour = v!),
                  ),
                ],
              ),
              // End hour
              Row(
                children: [
                  Expanded(child: Text('End Hour', style: GoogleFonts.inter(fontWeight: FontWeight.w500))),
                  DropdownButton<int>(
                    value: endHour,
                    items: List.generate(24, (i) => i)
                        .map((h) => DropdownMenuItem(value: h, child: Text('${h.toString().padLeft(2, '0')}:00')))
                        .toList(),
                    onChanged: (v) => setDialogState(() => endHour = v!),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This will replace all existing timeslots!',
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.orange.shade800),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                _autoGenerateTimeslots(startHour, endHour);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00BF63),
                foregroundColor: Colors.white,
              ),
              child: const Text('Generate'),
            ),
          ],
        ),
      ),
    );
  }

  void _autoGenerateTimeslots(int startHour, int endHour) {
    setState(() {
      for (var day in _availableTimeSlots.keys) {
        _availableTimeSlots[day]!.clear();

        for (int hour = startHour; hour < endHour; hour++) {
          final fromTime = '${hour.toString().padLeft(2, '0')}:00';
          final toTime = '${(hour + 1).toString().padLeft(2, '0')}:00';
          final timeSlotString = '$fromTime - $toTime';

          _availableTimeSlots[day]!.add({
            'time': timeSlotString,
            'price': int.tryParse(_priceController.text) ?? 300,
          });
        }
      }
      _hasChanges = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Generated ${endHour - startHour} timeslots for each day!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Widget _buildAmenitiesContent() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _amenities.keys.map((key) {
        final isSelected = _amenities[key] ?? false;
        return FilterChip(
          label: Text(_formatAmenityName(key)),
          selected: isSelected,
          onSelected: (value) {
            setState(() {
              _amenities[key] = value;
              _hasChanges = true;
            });
          },
          selectedColor: const Color(0xFF00BF63).withOpacity(0.2),
          checkmarkColor: const Color(0xFF00BF63),
          labelStyle: GoogleFonts.inter(
            color: isSelected ? const Color(0xFF00BF63) : Colors.black87,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildOwnerContent() {
    return Column(
      children: [
        _buildTextField(_ownerNameController, 'Owner Name', Icons.person),
        _buildTextField(_ownerPhoneController, 'Owner Phone', Icons.phone),
        const Divider(height: 24),
        // Partner credentials
        _buildTextField(_partnerUsernameController, 'Partner Username', Icons.alternate_email),
        _buildTextField(_partnerPasswordController, 'Partner Password', Icons.lock_outline, obscure: true),
      ],
    );
  }

  Widget _buildCameraContent() {
    return Column(
      children: [
        _buildTextField(_cameraIpController, 'Camera IP Address', Icons.videocam),
        _buildTextField(_cameraUsernameController, 'Camera Username', Icons.person),
        _buildTextField(_cameraPasswordController, 'Camera Password', Icons.lock, obscure: true),
        _buildTextField(_piIpController, 'Raspberry Pi IP', Icons.memory),
        const SizedBox(height: 16),
        if (_cameraIpController.text.isNotEmpty) ...[
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _copyCameraScript,
                  icon: const Icon(Icons.code, size: 18),
                  label: const Text('Copy Script'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.purple,
                    side: const BorderSide(color: Colors.purple),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _copyEnvFile,
                  icon: const Icon(Icons.settings, size: 18),
                  label: const Text('Copy .env'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue,
                    side: const BorderSide(color: Colors.blue),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  void _copyCameraScript() {
    final script = CameraScriptGenerator.generateScript(_field);
    Clipboard.setData(ClipboardData(text: script));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Python script copied!'), backgroundColor: Colors.green),
    );
  }

  void _copyEnvFile() {
    final envFile = CameraScriptGenerator.generateEnvFile(_field);
    Clipboard.setData(ClipboardData(text: envFile));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('.env file copied!'), backgroundColor: Colors.green),
    );
  }

  Widget _buildBlockedUsersContent() {
    if (_loadingBlockedUsers) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_field.blockedUsers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.check_circle, size: 48, color: Colors.green.shade400),
            const SizedBox(height: 12),
            Text('No Blocked Users', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            Text(
              'All users can book at this field',
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _blockedUsers.map((user) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.red.shade100,
                radius: 18,
                child: Icon(Icons.person_off, color: Colors.red.shade700, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user['name'] ?? 'Unknown', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
                    if (user['email'] != null)
                      Text(user['email'], style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => _unblockUser(user['id']),
                child: Text('Unblock', style: GoogleFonts.inter(color: Colors.green, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Future<void> _unblockUser(String userId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unblock User?'),
        content: const Text('This user will be able to book at this field again.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Unblock'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final supabase = Supabase.instance.client;
      final updatedList = List<String>.from(_field.blockedUsers)..remove(userId);

      await supabase.from('football_fields').update({'blocked_users': updatedList}).eq('id', _field.id);

      setState(() {
        _blockedUsers.removeWhere((u) => u['id'] == userId);
        _field = FootballField(
          id: _field.id,
          footballFieldName: _field.footballFieldName,
          streetName: _field.streetName,
          latitude: _field.latitude,
          longitude: _field.longitude,
          locationName: _field.locationName,
          openingHours: _field.openingHours,
          priceRange: _field.priceRange,
          photos: _field.photos,
          availableTimeSlots: _field.availableTimeSlots,
          amenities: _field.amenities,
          fieldSize: _field.fieldSize,
          bookable: _field.bookable,
          bookings: _field.bookings,
          createdAt: _field.createdAt,
          username: _field.username,
          password: _field.password,
          commissionPercentage: _field.commissionPercentage,
          blockedUsers: updatedList,
          assistants: _field.assistants,
          hasCamera: _field.hasCamera,
          cameraIpAddress: _field.cameraIpAddress,
          cameraUsername: _field.cameraUsername,
          cameraPassword: _field.cameraPassword,
          raspberryPiIp: _field.raspberryPiIp,
          ownerName: _field.ownerName,
          ownerPhoneNumber: _field.ownerPhoneNumber,
          city: _field.city,
          area: _field.area,
        );
        _hasChanges = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User unblocked successfully'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to unblock: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildDangerZoneContent() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Delete this field',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.red.shade700),
              ),
              const SizedBox(height: 4),
              Text(
                'Once you delete a field, there is no going back. All associated bookings will also be deleted.',
                style: GoogleFonts.inter(fontSize: 13, color: Colors.red.shade600),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _confirmDelete,
                  icon: const Icon(Icons.delete_forever),
                  label: const Text('Delete Field'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.warning, color: Colors.red.shade700),
            ),
            const SizedBox(width: 12),
            const Text('Delete Field'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete this field?', style: GoogleFonts.inter(fontSize: 15)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_field.footballFieldName, style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.red.shade900)),
                  const SizedBox(height: 4),
                  Text(_field.locationName, style: GoogleFonts.inter(fontSize: 13, color: Colors.red.shade700)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey.shade700))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteField();
    }
  }

  Future<void> _deleteField() async {
    try {
      await SupabaseService().deleteFootballField(_field.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_field.footballFieldName} deleted successfully'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _saveChanges,
        icon: _isLoading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.save),
        label: Text(_isLoading ? 'Saving...' : 'Save All Changes', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00BF63),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;

      // Convert timeslots to lowercase keys for user app compatibility
      final timeSlotsForSave = <String, List<Map<String, dynamic>>>{};
      _availableTimeSlots.forEach((day, slots) {
        timeSlotsForSave[day.toLowerCase()] = slots;
      });

      await supabase.from('football_fields').update({
        'football_field_name': _nameController.text.trim(),
        'street_name': _streetController.text.trim(),
        'city': _cityController.text.trim(),
        'area': _areaController.text.trim(),
        'price_range': _priceController.text.trim(),
        'opening_hours': _openingHoursController.text.trim(),
        'owner_name': _ownerNameController.text.trim(),
        'owner_phone_number': _ownerPhoneController.text.trim(),
        'username': _partnerUsernameController.text.trim(),
        'password': _partnerPasswordController.text.trim(),
        'camera_ip_address': _cameraIpController.text.trim(),
        'camera_username': _cameraUsernameController.text.trim(),
        'camera_password': _cameraPasswordController.text.trim(),
        'raspberry_pi_ip': _piIpController.text.trim(),
        'location_name': _selectedLocation,
        'field_size': _fieldSize,
        'bookable': _bookable,
        'has_camera': _cameraIpController.text.trim().isNotEmpty,
        'amenities': _amenities,
        'available_time_slots': timeSlotsForSave,
      }).eq('id', _field.id);

      // Fetch updated field
      final response = await supabase.from('football_fields').select().eq('id', _field.id).single();
      _field = FootballField.fromMap(response);

      setState(() => _hasChanges = true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Field updated successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool obscure = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        onChanged: (_) => _hasChanges = true,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value, {bool isPassword = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600)),
          ),
          Expanded(
            child: Text(
              isPassword ? '••••••••' : value,
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$label copied'), duration: const Duration(seconds: 1)),
              );
            },
            child: Icon(Icons.copy, size: 16, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      items: items.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
      onChanged: onChanged,
    );
  }

  String _formatAmenityName(String key) {
    return key
        .replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m.group(1)}')
        .trim()
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
  }
}