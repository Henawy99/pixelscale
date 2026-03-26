import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import './models/squad.dart';
import './services/supabase_service.dart';
import 'package:playmakerappstart/models/user_model.dart';
import 'package:playmakerappstart/player_details_screen.dart';
import 'package:playmakerappstart/invite_friends_bottom_sheet.dart';
import 'package:playmakerappstart/components/player_tile.dart';
import 'package:playmakerappstart/custom_dialoag.dart'; // Import CustomDialog

class SquadDetailsScreen extends StatefulWidget {
  final Squad squad;
  final String userId;
  // final bool isCaptain; // This will be derived from _squad.captain == userId
  final bool isVisitor;

  const SquadDetailsScreen({
    Key? key,
    required this.squad,
    required this.userId,
    // required this.isCaptain, // Removed as it's derived in the state
    required this.isVisitor,
  }) : super(key: key);

  @override
  State<SquadDetailsScreen> createState() => _SquadDetailsScreenState();
}

class _SquadDetailsScreenState extends State<SquadDetailsScreen> {
  late Squad _squad;
  String get userId => widget.userId;
  bool get isCaptain => _squad.captain == userId;
  bool get isVisitor => widget.isVisitor;
  bool get isMember => _squad.squadMembers.contains(userId);
  // Correctly determine if the current user has a pending request for THIS squad
  bool get hasPendingRequest => _squad.pendingRequests.contains(userId);

  String _averageAgeDisplay = 'N/A';
  late Future<List<PlayerProfile>> _membersFuture;
  late Future<List<PlayerProfile>> _pendingRequestsFuture;
  PlayerProfile? _currentUserProfile;

  @override
  void initState() {
    super.initState();
    _squad = widget.squad;
    _fetchCurrentUserProfile();
    _membersFuture = fetchPlayerProfiles(_squad.squadMembers);
    _pendingRequestsFuture = fetchPlayerProfiles(_squad.pendingRequests);
    // Calculate initial average age
    _calculateAndSetAverageAge(_squad.squadMembers);
  }

  Future<void> _fetchCurrentUserProfile() async {
    if (widget.userId.isNotEmpty) {
      try {
        final profile = await SupabaseService().getUserModel(widget.userId);
        if (profile != null && mounted) {
          setState(() {
            _currentUserProfile = profile;
          });
        }
      } catch (e) {
        debugPrint('Error fetching current user profile: $e');
        // Optionally handle error, e.g., show a snackbar or set a default profile
      }
    }
  }

  Future<void> _refreshMembersData() async {
    final profiles = await fetchPlayerProfiles(_squad.squadMembers);
    if (mounted) {
      _calculateAndSetAverageAgeFromProfiles(profiles);
      setState(() {
        _membersFuture = Future.value(profiles);
      });
    }
  }

  Future<void> _refreshPendingRequestsData() async {
    final profiles = await fetchPlayerProfiles(_squad.pendingRequests);
    if (mounted) {
      setState(() {
        _pendingRequestsFuture = Future.value(profiles);
      });
    }
  }

  Future<List<PlayerProfile>> fetchPlayerProfiles(List<String> userIds) async {
    if (userIds.isEmpty) return [];
    try {
      final profiles = await Future.wait(
        userIds.map((id) => SupabaseService().getUserModel(id)),
      );
      return profiles
          .where((profile) => profile != null)
          .map((profile) => profile!)
          .toList();
    } catch (e) {
      debugPrint('Error fetching player profiles: $e');
      return [];
    }
  }

  void _calculateAndSetAverageAgeFromProfiles(List<PlayerProfile> profiles) {
    if (profiles.isEmpty) {
      if (mounted) setState(() => _averageAgeDisplay = 'N/A');
      return;
    }
    double totalAge = 0;
    int validAgeCount = 0;
    for (var profile in profiles) {
      if (profile.age.isNotEmpty) {
        final age = int.tryParse(profile.age);
        if (age != null && age > 0) {
          totalAge += age;
          validAgeCount++;
        }
      }
    }
    if (validAgeCount > 0) {
      final avg = totalAge / validAgeCount;
      if (mounted) setState(() => _averageAgeDisplay = avg.toStringAsFixed(1));
    } else {
      if (mounted) setState(() => _averageAgeDisplay = 'N/A');
    }
  }

  Future<void> _calculateAndSetAverageAge(List<String> userIds) async {
    if (userIds.isEmpty) {
      if (mounted) setState(() => _averageAgeDisplay = 'N/A');
      return;
    }
    try {
      final profiles = await fetchPlayerProfiles(userIds);
      _calculateAndSetAverageAgeFromProfiles(profiles);
    } catch (e) {
      debugPrint("Error calculating average age: $e");
      if (mounted) setState(() => _averageAgeDisplay = 'Error');
    }
  }

  void _showActionDialog(
    BuildContext context, {
    required String title,
    required String content,
    required String actionLabel,
    required Color actionColor,
    required VoidCallback onAction,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: Theme.of(context).colorScheme.secondary),
            ),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              onAction();
            },
            style: FilledButton.styleFrom(backgroundColor: actionColor),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }

  void _handleAsyncAction(
    BuildContext context, {
    required Future<void> Function() action,
    required String successMessage,
    VoidCallback? onSuccessLocalUpdate,
    bool popOnSuccess = false,
  }) async {
    try {
      await action();
      onSuccessLocalUpdate?.call();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
      if (popOnSuccess) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${error.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Widget _buildStatCard(BuildContext context, String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF00BF63).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon, 
                color: const Color(0xFF00BF63), 
                size: 20,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child, EdgeInsets? padding}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(20),
        child: child,
      ),
    );
  }

  Widget _buildSectionTitle(String title, {IconData? icon, Widget? trailing}) {
    return Row(
      children: [
        if (icon != null) ...[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF00BF63).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF00BF63), size: 20),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Future<void> _handlePendingRequest(BuildContext context, String playerId, bool accept) async {
    final supabaseService = SupabaseService();
    try {
      final player = await supabaseService.getUserModel(playerId);
      if (player == null) {
        throw Exception('Player not found');
      }
      
      if (accept) {
        await supabaseService.acceptSquadJoinRequest(_squad.id, playerId);
        _squad.pendingRequests.remove(playerId);
        if (!_squad.squadMembers.contains(playerId)) {
          _squad.squadMembers.add(playerId);
        }
        _refreshPendingRequestsData();
        _refreshMembersData(); // Recalculates age
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${player.name} is now part of your squad'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      } else {
        await supabaseService.declineSquadJoinRequest(_squad.id, playerId);
        _squad.pendingRequests.remove(playerId);
        _refreshPendingRequestsData();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Declined ${player.name} to join'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error handling request: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  void _handleMakeCaptain(PlayerProfile playerToPromote) {
    CustomDialog.show(
      context: context,
      title: 'Make Captain?',
      message: 'Are you sure you want to make ${playerToPromote.name} the new squad captain? This will transfer all captain responsibilities to them.',
      confirmText: 'Confirm',
      confirmColor: const Color(0xFF00BF63), // Playmaker Green
      icon: Icons.admin_panel_settings_outlined,
      onConfirm: () {
        _handleAsyncAction(
          context,
          action: () => SupabaseService().updateSquadCaptain(_squad.id, playerToPromote.id),
          successMessage: '${playerToPromote.name} is now the captain!',
          onSuccessLocalUpdate: () {
            setState(() {
              _squad = _squad.copyWith(captain: playerToPromote.id);
            });
          },
        );
      },
    );
  }

  void _handleRemovePlayer(PlayerProfile playerToRemove) {
    CustomDialog.show(
      context: context,
      title: 'Remove Player?',
      message: 'Are you sure you want to remove ${playerToRemove.name} from the squad? They will no longer be a member and will need to rejoin or be invited again.',
      confirmText: 'Remove',
      confirmColor: Colors.red,
      icon: Icons.person_remove_outlined,
      isDestructive: true,
      onConfirm: () {
        _handleAsyncAction(
          context,
          action: () => SupabaseService().removePlayerFromSquad(_squad.id, playerToRemove.id),
          successMessage: '${playerToRemove.name} removed from squad.',
          onSuccessLocalUpdate: () {
            _squad.squadMembers.remove(playerToRemove.id);
            _refreshMembersData(); // Recalculates age
          },
        );
      },
    );
  }

  void _showInviteFriendsSheet() async {
    if (_currentUserProfile == null) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User profile not loaded yet. Please try again.')),
      );
      return;
    }

    final List<String>? selectedFriendIds = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // Bottom sheet handles its own background
      shape: const RoundedRectangleBorder( // Optional: if you want specific shape for the modal itself
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => InviteFriendsBottomSheet(
        playerProfile: _currentUserProfile!,
        // Pass current squad members to allow InviteFriendsBottomSheet to potentially
        // disable or indicate friends who are already in the squad.
        initiallySelectedFriends: List<String>.from(_squad.squadMembers),
      ),
    );

    if (selectedFriendIds != null && selectedFriendIds.isNotEmpty) {
      _invitePlayersToSquad(selectedFriendIds);
    }
  }

  void _invitePlayersToSquad(List<String> friendIds) {
    // Filter out existing members or those with pending requests
    final List<String> newInvitees = friendIds
        .where((id) => !_squad.squadMembers.contains(id) && !_squad.pendingRequests.contains(id))
        .toList();

    if (newInvitees.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selected players are already members or have pending requests.')),
        );
      }
      return;
    }

    _handleAsyncAction(
      context,
      action: () async {
        // This is where you'd call your SupabaseService method
        // e.g., await SupabaseService().sendInvitesToSquad(_squad.id, newInvitees);
        // For this exercise, we'll simulate success.
        // In a real app, this would trigger notifications to the invited players
        // and potentially update a list of invited players in Firestore.
        debugPrint("Simulating sending invites to: ${newInvitees.join(', ')} for squad ${_squad.id}");
        // Example: You might add them to pending requests if that's your flow
        // await SupabaseService().addPlayersToPendingRequests(_squad.id, newInvitees);
        // _squad.pendingRequests.addAll(newInvitees.where((id) => !_squad.pendingRequests.contains(id)));
        // _refreshPendingRequestsData();
        await Future.delayed(const Duration(seconds: 1)); // Simulate network call
      },
      successMessage: 'Invitations sent to ${newInvitees.length} players.',
      onSuccessLocalUpdate: () {
        // Optionally, refresh data if your backend updates a list the captain can see
        // For example, if invites move players to the pending list:
        // _refreshPendingRequestsData();
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: 'squad-${_squad.id}',
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: _squad.squadLogo ?? _squad.profilePicture,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF00BF63).withOpacity(0.8),
                              const Color(0xFF00BF63).withOpacity(0.6),
                            ],
                          ),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF00BF63).withOpacity(0.8),
                              const Color(0xFF00BF63).withOpacity(0.6),
                            ],
                          ),
                        ),
                        child: const Icon(
                          Icons.shield_outlined, 
                          size: 60, 
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.3, 1.0],
                          colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              title: Text(
                _squad.squadName,
                style: textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      blurRadius: 2.0,
                      color: Colors.black.withOpacity(0.5),
                      offset: const Offset(1.0, 1.0),
                    ),
                  ],
                ),
              ),
              centerTitle: true,
              titlePadding: const EdgeInsets.only(bottom: 16),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Member Status Card
                  if (isMember)
                    _buildCard(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: (isCaptain ? Colors.amber : const Color(0xFF00BF63)).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isCaptain ? Icons.star_rounded : Icons.group_rounded,
                              color: isCaptain ? Colors.amber : const Color(0xFF00BF63),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isCaptain ? 'Squad Captain' : 'Squad Member',
                                  style: textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  isCaptain ? 'You have full control over this squad' : 'You are part of this squad',
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Stats Row
                  Row(
                    children: [
                      _buildStatCard(context, 'Location', _squad.squadLocation.isNotEmpty ? _squad.squadLocation : 'N/A', Icons.location_on_outlined),
                      const SizedBox(width: 12),
                      _buildStatCard(context, 'Matches', _squad.matchesPlayed, Icons.sports_soccer_outlined),
                      const SizedBox(width: 12),
                      _buildStatCard(context, 'Avg Age', _averageAgeDisplay, Icons.cake_outlined),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Captain Settings Section
                  if (isCaptain)
                    _buildCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle('Squad Settings', icon: Icons.settings),
                          const SizedBox(height: 16),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.grey[50],
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: SwitchListTile(
                              title: Text(
                                'Allow Join Requests',
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                _squad.joinable ? 'Players can request to join' : 'Squad is invite-only',
                                style: textTheme.bodySmall?.copyWith(
                                  color: Colors.grey[600],
                                ),
                              ),
                              value: _squad.joinable,
                              onChanged: (bool value) {
                                _handleAsyncAction(
                                  context,
                                  action: () => SupabaseService().updateSquadJoinableStatus(_squad.id, value),
                                  successMessage: value ? 'Squad is now open to join requests.' : 'Squad is now invite-only.',
                                  onSuccessLocalUpdate: () => setState(() => _squad = _squad.copyWith(joinable: value)),
                                );
                              },
                              secondary: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00BF63).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  _squad.joinable ? Icons.lock_open_rounded : Icons.lock_rounded, 
                                  color: const Color(0xFF00BF63),
                                  size: 20,
                                ),
                              ),
                              activeColor: const Color(0xFF00BF63),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Join/Request Buttons for Visitors
                  if (isVisitor && !isMember && !hasPendingRequest && _squad.joinable)
                    _buildCard(
                      child: Column(
                        children: [
                          _buildSectionTitle('Join Squad', icon: Icons.person_add_alt_1),
                          const SizedBox(height: 16),
                          Text(
                            'Send a request to join ${_squad.squadName} and become part of their team!',
                            textAlign: TextAlign.center,
                            style: textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () {
                                _handleAsyncAction(
                                  context,
                                  action: () => SupabaseService().requestToJoinSquad(_squad.id, userId),
                                  successMessage: 'Request to join ${_squad.squadName} sent!',
                                  onSuccessLocalUpdate: () => setState(() {
                                    _squad.pendingRequests.add(userId);
                                    _refreshPendingRequestsData();
                                  }),
                                );
                              },
                              icon: const Icon(Icons.send),
                              label: const Text('Send Join Request'),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF00BF63),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Pending Request Status
                  if (isVisitor && !isMember && hasPendingRequest)
                    _buildCard(
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.hourglass_top_rounded,
                                  color: Colors.orange,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Request Pending',
                                        style: textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orange[700],
                                        ),
                                      ),
                                      Text(
                                        'Your request to join this squad is awaiting approval',
                                        style: textTheme.bodyMedium?.copyWith(
                                          color: Colors.orange[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Pending Requests (Captain only)
                  if (isCaptain && _squad.pendingRequests.isNotEmpty)
                    _buildCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle(
                            'Pending Join Requests', 
                            icon: Icons.notifications_outlined,
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_squad.pendingRequests.length}',
                                style: textTheme.labelMedium?.copyWith(
                                  color: Colors.red[700],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          FutureBuilder<List<PlayerProfile>>(
                            future: _pendingRequestsFuture,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: CircularProgressIndicator(
                                      color: Color(0xFF00BF63),
                                    ),
                                  ),
                                );
                              }
                              if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              final pendingPlayers = snapshot.data!;
                              return ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: pendingPlayers.length,
                                separatorBuilder: (context, index) => const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final player = pendingPlayers[index];
                                  return Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[50],
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.grey[200]!),
                                    ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 24,
                                          backgroundImage: player.profilePicture.isNotEmpty 
                                              ? CachedNetworkImageProvider(player.profilePicture) 
                                              : null,
                                          backgroundColor: const Color(0xFF00BF63).withOpacity(0.1),
                                          child: player.profilePicture.isEmpty 
                                              ? const Icon(
                                                  Icons.person, 
                                                  color: Color(0xFF00BF63),
                                                ) 
                                              : null,
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                player.name,
                                                style: textTheme.titleMedium?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              if (player.preferredPosition.isNotEmpty)
                                                Text(
                                                  player.preferredPosition,
                                                  style: textTheme.bodyMedium?.copyWith(
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF00BF63).withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: IconButton(
                                                tooltip: 'Accept',
                                                icon: const Icon(Icons.check),
                                                color: const Color(0xFF00BF63),
                                                onPressed: () => _handlePendingRequest(context, player.id, true),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              decoration: BoxDecoration(
                                                color: Colors.red.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: IconButton(
                                                tooltip: 'Decline',
                                                icon: const Icon(Icons.close),
                                                color: Colors.red,
                                                onPressed: () => _handlePendingRequest(context, player.id, false),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                  // Invite Players Button (Captain only)
                  if (isCaptain && _currentUserProfile != null)
                    _buildCard(
                      child: Column(
                        children: [
                          _buildSectionTitle('Grow Your Squad', icon: Icons.person_add_alt_1),
                          const SizedBox(height: 16),
                          Text(
                            'Invite your friends to join the squad and build a stronger team together.',
                            textAlign: TextAlign.center,
                            style: textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              icon: const Icon(Icons.person_add_alt_1_rounded),
                              label: const Text('Invite Players'),
                              onPressed: _showInviteFriendsSheet,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF00BF63),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Squad Members Section Title
                  _buildSectionTitle(
                    'Squad Members', 
                    icon: Icons.group,
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00BF63).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '${_squad.squadMembers.length}',
                        style: textTheme.labelLarge?.copyWith(
                          color: const Color(0xFF00BF63),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // Squad Members List Section
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            sliver: FutureBuilder<List<PlayerProfile>>(
              future: _membersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return SliverFillRemaining(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const CircularProgressIndicator(
                          color: Color(0xFF00BF63),
                        ),
                      ),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return SliverFillRemaining(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 48,
                              color: Colors.red[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Error loading members',
                              style: TextStyle(
                                color: Colors.red[600],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${snapshot.error}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                final members = snapshot.data ?? [];
                if (members.isEmpty) {
                  return SliverFillRemaining(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.group_off,
                                size: 48,
                                color: Colors.grey[500],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No members found',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'This squad has no members yet.',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final playerProfile = members[index];
                      final bool isCurrentPlayerTheSquadCaptain = playerProfile.id == _squad.captain;
                      final bool isViewingOwnProfile = playerProfile.id == userId;
                      final bool canCaptainManageThisPlayer = isCaptain && !isViewingOwnProfile;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: PlayerTile(
                          playerProfile: playerProfile,
                          isCaptainContext: isCurrentPlayerTheSquadCaptain,
                          onTap: () {
                            if (_currentUserProfile == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Loading user data... Please try again shortly.')),
                              );
                              return;
                            }
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PlayerDetailsScreen(
                                  player: playerProfile,
                                  currentUserProfile: _currentUserProfile!,
                                ),
                              ),
                            );
                          },
                          actionType: canCaptainManageThisPlayer 
                              ? PlayerTileActionType.moreOptions 
                              : (isCurrentPlayerTheSquadCaptain ? PlayerTileActionType.customWidget : PlayerTileActionType.none),
                          customTrailingWidget: isCurrentPlayerTheSquadCaptain 
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.amber.withOpacity(0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Captain',
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: Colors.amber[700],
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : null,
                          onMoreOptions: canCaptainManageThisPlayer 
                            ? () {
                                final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
                                showMenu<String>(
                                  context: context,
                                  position: RelativeRect.fromRect(
                                    Rect.fromPoints(
                                      (context.findRenderObject() as RenderBox).localToGlobal(Offset.zero, ancestor: overlay),
                                      (context.findRenderObject() as RenderBox).localToGlobal((context.findRenderObject() as RenderBox).size.bottomRight(Offset.zero), ancestor: overlay),
                                    ),
                                    Offset.zero & overlay.size,
                                  ),
                                  items: <PopupMenuEntry<String>>[
                                    PopupMenuItem<String>(
                                      value: 'make_captain',
                                      child: ListTile(
                                        leading: Icon(Icons.admin_panel_settings_outlined, color: Color(0xFF00BF63)),
                                        title: Text('Make Captain', style: TextStyle(color: Color(0xFF00BF63))),
                                      ),
                                    ),
                                    const PopupMenuDivider(),
                                    PopupMenuItem<String>(
                                      value: 'remove_player',
                                      child: ListTile(
                                        leading: Icon(Icons.person_remove_outlined, color: Colors.red),
                                        title: Text('Remove Player', style: TextStyle(color: Colors.red)),
                                      ),
                                    ),
                                  ],
                                  color: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ).then((String? value) {
                                  if (value == 'make_captain') {
                                    _handleMakeCaptain(playerProfile);
                                  } else if (value == 'remove_player') {
                                    _handleRemovePlayer(playerProfile);
                                  }
                                });
                              }
                            : null,
                          tileColor: Colors.transparent,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      );
                    },
                    childCount: members.length,
                  ),
                );
              },
            ),
          ),

          // Leave/Delete Buttons Section
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.warning_outlined,
                            color: Colors.red,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Danger Zone',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.red[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (isCaptain) ...[
                      Text(
                        'Delete Squad',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Permanently delete this squad and remove all members. This action cannot be undone.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => _showActionDialog(
                            context,
                            title: 'Delete Squad?',
                            content: 'Are you sure you want to permanently delete this squad? This action cannot be undone.',
                            actionLabel: 'Delete',
                            actionColor: Colors.red,
                            onAction: () => _handleAsyncAction(
                              context,
                              action: () => SupabaseService().deleteSquad(_squad.id),
                              successMessage: 'Squad deleted successfully.',
                              popOnSuccess: true,
                            ),
                          ),
                          icon: const Icon(Icons.delete_forever_outlined),
                          label: const Text('Delete Squad'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ] else if (isMember) ...[
                      Text(
                        'Leave Squad',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Leave this squad and lose access to all squad activities and matches.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _showActionDialog(
                            context,
                            title: 'Leave Squad?',
                            content: 'Are you sure you want to leave this squad?',
                            actionLabel: 'Leave',
                            actionColor: Colors.red,
                            onAction: () => _handleAsyncAction(
                              context,
                              action: () => SupabaseService().leaveSquad(_squad.id, userId),
                              successMessage: 'You have left the squad.',
                              popOnSuccess: true,
                            ),
                          ),
                          icon: const Icon(Icons.exit_to_app_rounded),
                          label: const Text('Leave Squad'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
