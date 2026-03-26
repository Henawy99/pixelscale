import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:playmakerappstart/models/booking_model.dart';
import 'package:playmakerappstart/models/footballfield_model.dart';
import 'package:playmakerappstart/models/user_model.dart';
import 'package:playmakerappstart/services/supabase_service.dart';
import 'package:playmakerappstart/services/demo_data_service.dart';
import 'package:playmakerappstart/field_booking_screen.dart';
import 'package:playmakerappstart/join_bookings_screen.dart';
import 'package:playmakerappstart/fields_list_view.dart';
import 'package:playmakerappstart/match_details_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:playmakerappstart/custom_dialoag.dart';
import 'package:playmakerappstart/login_screen/login_screen.dart';
import 'package:shimmer/shimmer.dart';
import 'package:playmakerappstart/localization/app_localizations.dart';

const Color _brandColor = Color(0xFF00BF63);

class BookingsScreen extends StatefulWidget {
  final Position? currentPosition;
  final PlayerProfile playerProfile;

  const BookingsScreen({
    super.key, 
    this.currentPosition, 
    required this.playerProfile,
  });

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final DemoDataService _demoService = DemoDataService();
  List<Booking> _bookings = [];
  List<FootballField?> _fields = [];
  bool _isLoading = true;

  // Demo data
  List<FootballField> _demoFields = [];
  Map<String, List<Booking>> _demoFieldMatches = {};

  @override
  void initState() {
    super.initState();
    _fetchBookings();
  }

  Future<void> _fetchBookings() async {
    try {
      final fetchedBookings = await _supabaseService.getUserBookings(widget.playerProfile.id);

      final uniqueFieldIds = fetchedBookings.map((b) => b.footballFieldId).toSet();
      final fetchedFields = await Future.wait(
        uniqueFieldIds.map((id) => _supabaseService.getFootballFieldById(id)),
      );

      // For demo account, load demo fields with open matches
      if (DemoDataService.isDemoAccount(widget.playerProfile.email)) {
        await _demoService.initialize();
        await _loadDemoFieldMatches();
      }

      setState(() {
        _bookings = fetchedBookings;
        _fields = fetchedFields.where((f) => f != null).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.loc.failedToLoadBookingsSnackbar)),
        );
      }
    }
  }

  Future<void> _loadDemoFieldMatches() async {
    try {
      // Get available fields
      final fields = await _supabaseService.getFootballFieldsPaginated(
        limit: 5,
        offset: 0,
        includeDisabled: true,
      );

      if (fields.isEmpty) return;

      _demoFields = fields.take(3).toList();
      _demoFieldMatches = {};

      // Generate 1 open match per field for demo showcase
      for (final field in _demoFields) {
        final matches = _demoService.getDemoOpenMatches(
          widget.playerProfile.id,
          {field.id: field},
        );
        // Take only the first match for each field 
        _demoFieldMatches[field.id] = matches.take(1).toList();
      }
    } catch (e) {
      print('⚠️ Failed to load demo field matches: $e');
    }
  }

  Future<void> _navigateToFieldBooking(String fieldId) async {
    try {
      final field = await _supabaseService.getFootballFieldById(fieldId);
      if (field != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FieldBookingScreen(
              field: field,
              playerProfile: widget.playerProfile,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.loc.errorFetchingFieldDetailsSnackbar)),
        );
      }
    }
  }

  void _showCreateProfileDialog() {
    CustomDialog.show(
      context: context,
      title: context.loc.createAccountDialogTitle,
      message: context.loc.createAccountDialogMessage,
      confirmText: context.loc.signUpButton,
      cancelText: context.loc.cancel,
      icon: Icons.account_circle_outlined,
      onConfirm: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const LoginWithPasswordScreen(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          context.loc.playTabTitle,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            color: Colors.black87,
            fontSize: 24,
          ),
        ),
        automaticallyImplyLeading: false,
      ),
      body: RefreshIndicator(
        color: _brandColor,
        onRefresh: _fetchBookings,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 32,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Quick Actions
                      _buildQuickActions(),

                      const SizedBox(height: 28),

                      // Demo: Recently Booked Fields with Open Matches
                      if (DemoDataService.isDemoAccount(widget.playerProfile.email) && _demoFields.isNotEmpty) ...[
                        _buildSectionHeader(
                          icon: Icons.star_rounded,
                          title: 'Popular Fields',
                          subtitle: 'Fields with open matches near you',
                        ),
                        const SizedBox(height: 16),
                        ..._demoFields.map((field) => _buildDemoFieldWithMatches(field)),
                        const SizedBox(height: 12),
                      ],

                      // Recently Played Fields
                      if (_isLoading)
                        _buildLoadingShimmer()
                      else if (_bookings.isNotEmpty) ...[
                        _buildSectionHeader(
                          icon: Icons.history_rounded,
                          title: context.loc.recentlyPlayedFieldsTitle,
                          subtitle: context.loc.yourFavoritePlacesToPlaySubtitle,
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 240,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _getUniqueFields().length,
                            itemBuilder: (context, index) {
                              final field = _getUniqueFields()[index];
                              return _RecentFieldCard(
                                field: field,
                                onTap: () => _navigateToFieldBooking(field!.id),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  List<FootballField?> _getUniqueFields() {
    final seenIds = <String>{};
    final uniqueFields = <FootballField?>[];
    for (final booking in _bookings) {
      final field = _fields.firstWhere(
        (f) => f?.id == booking.footballFieldId,
        orElse: () => null,
      );
      if (field != null && !seenIds.contains(field.id)) {
        seenIds.add(field.id);
        uniqueFields.add(field);
      }
    }
    return uniqueFields.take(5).toList();
  }

  Widget _buildQuickActions() {
    return Column(
      children: [
        _buildActionCard(
          title: context.loc.bookAFieldCardTitle,
          subtitle: context.loc.bookAFieldCardSubtitle,
          icon: Icons.stadium_rounded,
          gradient: const LinearGradient(
            colors: [Color(0xFF00BF63), Color(0xFF00D971)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          onTap: () {
            if (widget.playerProfile.isGuest) {
              _showCreateProfileDialog();
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FieldsListView(
                    playerProfile: widget.playerProfile,
                  ),
                ),
              );
            }
          },
        ),
        const SizedBox(height: 12),
        _buildActionCard(
          title: context.loc.joinMatchesCardTitle,
          subtitle: context.loc.joinMatchesCardSubtitle,
          icon: Icons.groups_rounded,
          gradient: const LinearGradient(
            colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          onTap: () {
            if (widget.playerProfile.isGuest) {
              _showCreateProfileDialog();
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => JoinBookingsScreen(
                    playerProfile: widget.playerProfile,
                  ),
                ),
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.75),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _brandColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: _brandColor, size: 20),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.grey[500],
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDemoFieldWithMatches(FootballField field) {
    final matches = _demoFieldMatches[field.id] ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Field Header with Image
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Stack(
              children: [
                SizedBox(
                  height: 140,
                  width: double.infinity,
                  child: field.photos.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: field.photos[0],
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Shimmer.fromColors(
                            baseColor: Colors.grey[200]!,
                            highlightColor: Colors.grey[50]!,
                            child: Container(color: Colors.white),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey[100],
                            child: Icon(Icons.sports_soccer_rounded, size: 48, color: Colors.grey[300]),
                          ),
                        )
                      : Container(
                          color: Colors.grey[100],
                          child: Icon(Icons.sports_soccer_rounded, size: 48, color: Colors.grey[300]),
                        ),
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
                      ),
                    ),
                  ),
                ),
                // Field info overlaid on image
                Positioned(
                  bottom: 12,
                  left: 16,
                  right: 16,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              field.footballFieldName,
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.location_on_rounded, size: 14, color: Colors.white70),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    field.locationName,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: Colors.white70,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Field size badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _brandColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          field.fieldSize,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Open Matches Section
          if (matches.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.flash_on_rounded, size: 16, color: Colors.orange[600]),
                      const SizedBox(width: 6),
                      Text(
                        '${matches.length} Open ${matches.length == 1 ? 'Match' : 'Matches'}',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...matches.map((match) => _buildOpenMatchTile(match, field)),
                  const SizedBox(height: 8),
                  // Book this field button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _navigateToFieldBooking(field.id),
                      icon: const Icon(Icons.calendar_today_rounded, size: 16),
                      label: Text('Book This Field', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _brandColor,
                        side: BorderSide(color: _brandColor.withOpacity(0.3)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _navigateToFieldBooking(field.id),
                  icon: const Icon(Icons.calendar_today_rounded, size: 16),
                  label: Text('Book This Field', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brandColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOpenMatchTile(Booking match, FootballField field) {
    final times = match.timeSlot.split('-');
    final spotsLeft = (match.maxPlayers ?? 10) - match.invitePlayers.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MatchDetailsScreen(
                  booking: match,
                  currentUserId: widget.playerProfile.id,
                  footballField: field,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Time
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _brandColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Text(
                        times.isNotEmpty ? times[0] : '',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _brandColor,
                        ),
                      ),
                      Text(
                        times.length > 1 ? times[1] : '',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                // Match info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Open Match',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.group_outlined, size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(
                            '${match.invitePlayers.length}/${match.maxPlayers ?? 10} players',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: spotsLeft > 3
                                  ? _brandColor.withOpacity(0.1)
                                  : Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$spotsLeft spots left',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: spotsLeft > 3 ? _brandColor : Colors.orange[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Arrow
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _brandColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_forward_ios, size: 12, color: _brandColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[200]!,
        highlightColor: Colors.grey[50]!,
        child: Column(
          children: List.generate(2, (index) => Container(
            margin: const EdgeInsets.only(bottom: 16),
            height: 200,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
          )),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────
// Enhanced Recent Field Card (used in horizontal scroll)
// ──────────────────────────────────────────────────────

class _RecentFieldCard extends StatelessWidget {
  final FootballField? field;
  final VoidCallback onTap;

  const _RecentFieldCard({
    required this.field,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (field == null) return const SizedBox();

    return Container(
      margin: const EdgeInsets.only(right: 16, bottom: 4),
      width: 220,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                    child: SizedBox(
                      height: 120,
                      width: double.infinity,
                      child: field!.photos.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: field!.photos[0],
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Shimmer.fromColors(
                                baseColor: Colors.grey[200]!,
                                highlightColor: Colors.grey[50]!,
                                child: Container(color: Colors.white),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: Colors.grey[100],
                                child: Icon(Icons.sports_soccer_rounded, size: 40, color: Colors.grey[300]),
                              ),
                            )
                          : Container(
                              color: Colors.grey[100],
                              child: Icon(Icons.sports_soccer_rounded, size: 40, color: Colors.grey[300]),
                            ),
                    ),
                  ),
                  // Price badge
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${field!.priceRange} EGP',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  // Field size badge
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _brandColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        field!.fieldSize,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        field!.footballFieldName,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.location_on_rounded, size: 13, color: Colors.grey[400]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              field!.locationName,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────
// BookingsTab (used elsewhere in the app)
// ──────────────────────────────────────────────────────

class BookingsTab extends StatelessWidget {
  final String userId;

  const BookingsTab({Key? key, required this.userId}) : super(key: key);

  Future<List<FootballField>> fetchRecentFields() async {
    try {
      final supabaseService = SupabaseService();
      final bookings = await supabaseService.getUserBookings(userId);
      final linkedFields = <String, FootballField>{};
      
      for (var booking in bookings) {
        final fieldId = booking.footballFieldId;
        if (!linkedFields.containsKey(fieldId)) {
          final field = await supabaseService.getFootballFieldById(fieldId);
          if (field != null) {
            linkedFields[field.id] = field;
          }
        }
      }

      return linkedFields.values.toList();
    } catch (e) {
      print('Error fetching recent fields: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<FootballField>>(
      future: fetchRecentFields(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: _brandColor),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline_rounded, size: 48, color: Colors.red[300]),
                const SizedBox(height: 12),
                Text(
                  context.loc.errorLoadingFields,
                  style: GoogleFonts.inter(color: Colors.red[400]),
                ),
              ],
            ),
          );
        }

        final fields = snapshot.data ?? [];
        if (fields.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: _brandColor.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.sports_soccer_rounded,
                    size: 56,
                    color: _brandColor.withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  context.loc.noRecentlyPlayedFields,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        final seenIds = <String>{};
        
        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: fields.length,
          itemBuilder: (context, index) {
            final field = fields[index];
            if (seenIds.contains(field.id)) {
              return const SizedBox.shrink();
            }
            seenIds.add(field.id);

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: CachedNetworkImage(
                        imageUrl: field.photos.isNotEmpty ? field.photos[0] : '',
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Shimmer.fromColors(
                          baseColor: Colors.grey[200]!,
                          highlightColor: Colors.grey[50]!,
                          child: Container(color: Colors.white),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[100],
                          child: Icon(Icons.sports_soccer_rounded, size: 48, color: Colors.grey[300]),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          field.footballFieldName,
                          style: GoogleFonts.inter(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(Icons.location_on_rounded, size: 15, color: _brandColor),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                field.locationName,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.payments_rounded, size: 15, color: _brandColor),
                            const SizedBox(width: 6),
                            Text(
                              '${field.priceRange} EGP',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
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
}
