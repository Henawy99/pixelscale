import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:playmakerappstart/l10n/app_localizations.dart';
import 'package:rxdart/rxdart.dart';
import 'package:playmakerappstart/fields_list_view.dart';
import 'package:playmakerappstart/join_bookings_screen.dart';
import 'package:playmakerappstart/login_screen/login_screen.dart';
import 'package:playmakerappstart/models/booking_model.dart';
import 'package:playmakerappstart/models/footballfield_model.dart';
import 'package:playmakerappstart/models/user_model.dart';
import 'package:playmakerappstart/services/supabase_service.dart';
import 'package:playmakerappstart/services/demo_data_service.dart';
import 'package:playmakerappstart/match_details_screen.dart';
import 'package:playmakerappstart/custom_dialoag.dart';
import 'package:cached_network_image/cached_network_image.dart';

class MatchesScreen extends StatefulWidget {
  final PlayerProfile userModel;
  final int initialTabIndex;

  const MatchesScreen({
    super.key, 
    required this.userModel, 
    this.initialTabIndex = 0,
  });

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> with SingleTickerProviderStateMixin {
  final SupabaseService _supabaseService = SupabaseService();
  final DemoDataService _demoService = DemoDataService();
  Map<String, FootballField?> fieldsMap = {};
  Map<String, Map<String, String>> hostInfoMap = {};
  bool _isLoading = true;
  late TabController _tabController;

  late Stream<List<Booking>> _hostedBookingsStream;
  late Stream<List<Booking>> _invitedBookingsStream;
  
  // Cached bookings for graceful error handling
  List<List<Booking>>? _cachedBookings;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTabIndex);
    
    _hostedBookingsStream = _supabaseService
        .streamUserBookings(widget.userModel.id)
        .handleError((error) {
          print('⚠️ Hosted bookings stream error: $error');
          return <Booking>[];
        });
    
    _invitedBookingsStream = _supabaseService
        .streamUserInvitedBookings(widget.userModel.id)
        .handleError((error) {
          print('⚠️ Invited bookings stream error: $error');
          return <Booking>[];
        });
    
    _loadFieldsData();
    
    // Initialize demo data if demo account
    if (DemoDataService.isDemoAccount(widget.userModel.email)) {
      _demoService.initialize();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadFieldsData() async {
    setState(() => _isLoading = true);
    List<FootballField> allFieldsList = [];
    int offset = 0;
    bool hasMore = true;
    const int batchSize = 50;

    try {
      while (hasMore) {
        final result = await _supabaseService.getFootballFieldsPaginated(
          limit: batchSize,
          offset: offset,
        );
        allFieldsList.addAll(result);
        offset += batchSize;
        hasMore = result.length == batchSize;
      }
      
      setState(() {
        fieldsMap = {for (var field in allFieldsList) field.id: field};
        _isLoading = false;
      });
    } catch (e) {
      print(AppLocalizations.of(context)!.matchesTab_errorLoadingFields(e.toString()));
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<Map<String, String>> _getHostInfo(String hostId) async {
    if (hostInfoMap.containsKey(hostId)) {
      return hostInfoMap[hostId]!;
    }

    try {
      final profile = await _supabaseService.getUserProfileById(hostId);

      if (profile != null) {
        hostInfoMap[hostId] = {
          'name': profile.name,
          'profilePicture': profile.profilePicture,
        };
        return hostInfoMap[hostId]!;
      }
      return {
        'name': AppLocalizations.of(context)!.matchesTab_unknownPlayer,
        'profilePicture': '',
      };
    } catch (e) {
      print(AppLocalizations.of(context)!.matchesTab_errorFetchingHostInfo(e.toString()));
      return {
        'name': AppLocalizations.of(context)!.matchesTab_unknownPlayer,
        'profilePicture': '',
      };
    }
  }

  String _formatDate(String date) {
    DateTime parsedDate = DateTime.parse(date);
    return DateFormat('EEE, MMM d', AppLocalizations.of(context)!.localeName).format(parsedDate);
  }

  String _formatTimeSlot(String timeSlot) {
    final times = timeSlot.split('-');
    if (times.length != 2) return timeSlot;
    
    final startTime = times[0];
    final endTime = times[1];
    
    final startHour = int.parse(startTime.split(':')[0]);
    final startMinute = int.parse(startTime.split(':')[1]);
    final endHour = int.parse(endTime.split(':')[0]);
    final endMinute = int.parse(endTime.split(':')[1]);
    
    final start = DateTime(1970, 1, 1, startHour, startMinute);
    final end = DateTime(1970, 1, 1, endHour, endMinute);
    
    final durationMinutes = (endHour * 60 + endMinute) - (startHour * 60 + startMinute);
    
    return '${DateFormat('h:mm a', AppLocalizations.of(context)!.localeName).format(start)} - ${DateFormat('h:mm a', AppLocalizations.of(context)!.localeName).format(end)} ($durationMinutes ${AppLocalizations.of(context)!.minsSuffix})';
  }

  String _getTimeLeft(DateTime bookingDate, String timeSlot) {
    final times = timeSlot.split('-');
    if (times.length != 2) return AppLocalizations.of(context)!.invalidGuestEntry;
    
    final startTime = times[0];
    final startHour = int.parse(startTime.split(':')[0]);
    final startMinute = int.parse(startTime.split(':')[1]);
    
    DateTime startDateTime = bookingDate.add(Duration(hours: startHour, minutes: startMinute));
    Duration difference = startDateTime.difference(DateTime.now());

    if (difference.isNegative) {
      return AppLocalizations.of(context)!.matchesTab_matchInProgress;
    }

    int days = difference.inDays;
    int hours = difference.inHours.remainder(24);
    int minutes = difference.inMinutes.remainder(60);

    if (days > 0) {
      return AppLocalizations.of(context)!.matchesTab_timeLeftDaysHours(days, hours);
    } else if (hours > 0) {
      return AppLocalizations.of(context)!.matchesTab_timeLeftHoursMinutes(hours, minutes);
    } else if (minutes > 0) {
      return AppLocalizations.of(context)!.matchesTab_timeLeftMinutes(minutes);
    } else {
      return AppLocalizations.of(context)!.matchesTab_startingSoon;
    }
  }

  void _showCreateProfileDialog() {
    CustomDialog.show(
      context: context,
      title: AppLocalizations.of(context)!.createAccountDialogTitle,
      message: AppLocalizations.of(context)!.createAccountDialogMessage,
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
        body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00BF63)))
          : StreamBuilder<List<List<Booking>>>(
              stream: Rx.combineLatest2<List<Booking>, List<Booking>, List<List<Booking>>>(
                _hostedBookingsStream,
                _invitedBookingsStream,
                (hosted, invited) => [hosted, invited],
              ),
              builder: (context, snapshot) {
                // Handle errors gracefully - use cached data if available
                if (snapshot.hasError) {
                  print('⚠️ Matches stream error: ${snapshot.error}');
                  if (_cachedBookings != null) {
                    // Show reconnecting indicator but keep using cached data
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Connection issue, reconnecting...'),
                            duration: Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    });
                  } else {
                    return Center(child: Text(AppLocalizations.of(context)!.matchesTab_errorGeneric(snapshot.error.toString())));
                  }
                }

                // Update cache when we get new data
                if (snapshot.hasData) {
                  _cachedBookings = snapshot.data;
                }
                
                final dataToUse = snapshot.data ?? _cachedBookings;
                if (dataToUse == null) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF00BF63)));
                }

                List<Booking> hostedBookings = dataToUse[0];
                List<Booking> invitedBookings = dataToUse[1];

                // DEMO ACCOUNT INJECTION
                if (DemoDataService.isDemoAccount(widget.userModel.email)) {
                  hostedBookings = List.from(hostedBookings);
                  invitedBookings = List.from(invitedBookings);
                  final demoMatches = _demoService.getDemoMatches(widget.userModel.id);
                  invitedBookings.addAll(demoMatches);
                }

                final Map<String, Booking> uniqueBookings = {};
                for (final booking in [...hostedBookings, ...invitedBookings]) {
                  uniqueBookings[booking.bookingReference] = booking;
                }
                
                final allBookings = uniqueBookings.values.toList();
                final now = DateTime.now();
                
                final upcomingMatches = <Booking>[];
                final pastMatches = <Booking>[];

                for (final booking in allBookings) {
                  final bookingDate = DateTime.parse(booking.date);
                  final times = booking.timeSlot.split('-');
                  if (times.length != 2) continue;
                  
                  final endTime = times[1];
                  final endHour = int.parse(endTime.split(':')[0]);
                  final endMinute = int.parse(endTime.split(':')[1]);

                  final endDateTime = bookingDate.add(Duration(hours: endHour, minutes: endMinute));

                  if (endDateTime.isBefore(now)) {
                    pastMatches.add(booking);
                  } else {
                    upcomingMatches.add(booking);
                  }
                }

                upcomingMatches.sort((a, b) {
                  final aDate = DateTime.parse(a.date);
                  final bDate = DateTime.parse(b.date);
                  final aTimes = a.timeSlot.split('-');
                  final bTimes = b.timeSlot.split('-');
                  if (aTimes.length != 2 || bTimes.length != 2) return 0;
                  final aStartHour = int.parse(aTimes[0].split(':')[0]);
                  final aStartMinute = int.parse(aTimes[0].split(':')[1]);
                  final bStartHour = int.parse(bTimes[0].split(':')[0]);
                  final bStartMinute = int.parse(bTimes[0].split(':')[1]);
                  final aDateTime = aDate.add(Duration(hours: aStartHour, minutes: aStartMinute));
                  final bDateTime = bDate.add(Duration(hours: bStartHour, minutes: bStartMinute));
                  return aDateTime.compareTo(bDateTime);
                });

                pastMatches.sort((a, b) {
                  final aDate = DateTime.parse(a.date);
                  final bDate = DateTime.parse(b.date);
                  final aTimes = a.timeSlot.split('-');
                  final bTimes = b.timeSlot.split('-');
                  if (aTimes.length != 2 || bTimes.length != 2) return 0;
                  final aEndHour = int.parse(aTimes[1].split(':')[0]);
                  final aEndMinute = int.parse(aTimes[1].split(':')[1]);
                  final bEndHour = int.parse(bTimes[1].split(':')[0]);
                  final bEndMinute = int.parse(bTimes[1].split(':')[1]);
                  final aDateTime = aDate.add(Duration(hours: aEndHour, minutes: aEndMinute));
                  final bDateTime = bDate.add(Duration(hours: bEndHour, minutes: bEndMinute));
                  return bDateTime.compareTo(aDateTime);
                });

                return NestedScrollView(
                  headerSliverBuilder: (context, innerBoxIsScrolled) {
                    return [
                      SliverAppBar(
                        title: Text(
                          AppLocalizations.of(context)!.matches,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                            fontSize: 24,
                          ),
                        ),
                        floating: true,
                        pinned: true,
                        forceElevated: innerBoxIsScrolled,
                        backgroundColor: Colors.white,
                        elevation: 0,
                        centerTitle: false,
                        automaticallyImplyLeading: false,
                        bottom: PreferredSize(
                          preferredSize: const Size.fromHeight(60),
                          child: Container(
                            color: Colors.white,
                            child: TabBar(
                              controller: _tabController,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              tabs: [
                                _buildTab(
                                  label: AppLocalizations.of(context)!.matchesTab_upcoming,
                                  count: upcomingMatches.length,
                                  isActive: _tabController.index == 0,
                                ),
                                _buildTab(
                                  label: AppLocalizations.of(context)!.matchesTab_past,
                                  count: pastMatches.length,
                                  isActive: _tabController.index == 1,
                                ),
                              ],
                              indicatorSize: TabBarIndicatorSize.tab,
                              indicator: BoxDecoration(
                                color: const Color(0xFF00BF63),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              labelColor: Colors.white,
                              unselectedLabelColor: Colors.grey[600],
                              dividerColor: Colors.transparent,
                              labelStyle: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                              unselectedLabelStyle: GoogleFonts.inter(
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                              onTap: (index) => setState(() {}),
                            ),
                          ),
                        ),
                      ),
                    ];
                  },
                  body: TabBarView(
                    controller: _tabController,
                  children: [
                    _buildMatchList(upcomingMatches, isUpcoming: true),
                    _buildMatchList(pastMatches, isUpcoming: false),
                  ],
                  ),
                );
              },
      ),
    );
  }

  Widget _buildTab({
    required String label,
    required int count,
    required bool isActive,
  }) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isActive ? Colors.white.withOpacity(0.2) : Colors.grey[200],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.inter(
                  color: isActive ? Colors.white : Colors.grey[600],
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMatchList(List<Booking> matches, {required bool isUpcoming}) {
    if (matches.isEmpty) {
      return _buildEmptyState(isUpcoming);
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: matches.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) => _buildMatchCard(matches[index], isUpcoming: isUpcoming),
    );
  }

  Widget _buildEmptyState(bool isUpcoming) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 60),
          Icon(
            isUpcoming ? Icons.event_note : Icons.history,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 24),
          Text(
            isUpcoming 
                ? AppLocalizations.of(context)!.matchesTab_noMatchesFound
                : 'No Past Matches',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isUpcoming
                ? AppLocalizations.of(context)!.matchesTab_startByJoiningOrBooking
                : 'Your completed matches will appear here',
            style: GoogleFonts.inter(
              color: Colors.grey[500],
              fontSize: 14,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          if (isUpcoming) ...[
            const SizedBox(height: 48),
            _buildActionButton(
              label: AppLocalizations.of(context)!.matchesTab_joinAMatch,
              icon: Icons.group_add,
              onPressed: () {
                if (widget.userModel.isGuest) {
                  _showCreateProfileDialog();
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => JoinBookingsScreen(
                        playerProfile: widget.userModel,
                      ),
                    ),
                  );
                }
              },
              isPrimary: true,
            ),
            const SizedBox(height: 16),
            _buildActionButton(
              label: AppLocalizations.of(context)!.bookAFieldCardTitle,
              icon: Icons.add_location_alt_outlined,
              onPressed: () {
                if (widget.userModel.isGuest) {
                  _showCreateProfileDialog();
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FieldsListView(
                        playerProfile: widget.userModel,
                      ),
                    ),
                  );
                }
              },
              isPrimary: false,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    required bool isPrimary,
  }) {
    return SizedBox(
      width: double.infinity,
      child: isPrimary 
        ? ElevatedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 18),
            label: Text(label),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
              backgroundColor: const Color(0xFF00BF63),
              foregroundColor: Colors.white,
              textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          )
        : OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, color: const Color(0xFF00BF63), size: 18),
            label: Text(label),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              foregroundColor: const Color(0xFF00BF63),
              side: const BorderSide(color: Color(0xFF00BF63)),
              textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
      ),
    );
  }

  Widget _buildMatchCard(Booking booking, {required bool isUpcoming}) {
    FootballField? field = fieldsMap[booking.footballFieldId];
    
    // DEMO ACCOUNT LOGIC: generate a fallback field to ensure the card is clickable
    if (field == null && (booking.footballFieldName.isNotEmpty || booking.id.startsWith('demo_'))) {
       field = FootballField.fromMap({
         'id': booking.footballFieldId, 
         'football_field_name': booking.footballFieldName.isNotEmpty ? booking.footballFieldName : 'Demo Arena', 
         'location_name': booking.locationName.isNotEmpty ? booking.locationName : 'Demo Center', 
         'latitude': 0.0,
         'longitude': 0.0,
       });
    }
    
    final brandColor = const Color(0xFF00BF63);

    return Container(
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
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () {
            if (field != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MatchDetailsScreen(
                    booking: booking,
                    currentUserId: widget.userModel.id,
                    footballField: field!,
                  ),
                ),
              );
            }
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (field != null)
                            Text(
                              field.footballFieldName,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                          if (field != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.location_on_outlined, size: 14, color: Colors.grey[500]),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    field.locationName,
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
                        ],
                      ),
                    ),
                    _buildStatusBadge(booking, isUpcoming),
                  ],
                ),
                
                const SizedBox(height: 16),
                Divider(color: Colors.grey[100], height: 1),
                const SizedBox(height: 16),
                
                // Date and Time Row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: brandColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.calendar_month, size: 18, color: brandColor),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatDate(booking.date),
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          _formatTimeSlot(booking.timeSlot),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Host and Players Info
                Row(
                  children: [
                    // Host
                    Expanded(
                      child: FutureBuilder<Map<String, String>>(
                        future: _getHostInfo(booking.host),
                        builder: (context, snapshot) {
                          final hostInfo = snapshot.data;
                          return Row(
                            children: [
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: Colors.grey[200],
                                backgroundImage: hostInfo?['profilePicture']?.isNotEmpty == true
                                    ? CachedNetworkImageProvider(hostInfo!['profilePicture']!)
                                    : null,
                                child: hostInfo?['profilePicture']?.isEmpty ?? true
                                    ? Icon(Icons.person, size: 14, color: Colors.grey[400])
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Host',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        color: Colors.grey[500],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      hostInfo?['name'] ?? 'Loading...',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    // Players Count
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.group_outlined, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 6),
                          RichText(
                            text: TextSpan(
                              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
                              children: [
                                TextSpan(
                                  text: '${booking.invitePlayers.length}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                if (booking.maxPlayers != null)
                                  TextSpan(text: '/${booking.maxPlayers}'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(Booking booking, bool isUpcoming) {
    if (isUpcoming) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF00BF63).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          _getTimeLeft(DateTime.parse(booking.date), booking.timeSlot),
          style: GoogleFonts.inter(
            color: const Color(0xFF00BF63),
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          AppLocalizations.of(context)!.matchesTab_completed,
          style: GoogleFonts.inter(
            color: Colors.grey[600],
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
      );
    }
  }
}
