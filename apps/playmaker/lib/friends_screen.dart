import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:playmakerappstart/friends_screen_manager.dart';
import 'package:playmakerappstart/models/user_model.dart';
import 'package:playmakerappstart/player_details_screen.dart';
import 'package:playmakerappstart/services/supabase_service.dart';
import 'package:playmakerappstart/services/notification_service.dart';
// import 'package:cached_network_image/cached_network_image.dart'; // PlayerTile handles this
import 'package:country_picker/country_picker.dart'; // PlayerTile handles this
import 'package:playmakerappstart/components/player_tile.dart'; // Added import

class FriendsScreen extends StatelessWidget {
  final PlayerProfile playerProfile;
  final bool isSelecting;
  final void Function(List<PlayerProfile>)? onPlayersSelected;

  const FriendsScreen({
    super.key, 
    required this.playerProfile,
    this.isSelecting = false,
    this.onPlayersSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => FriendManager(),
      child: FriendsScreenContent(
        playerProfile: playerProfile,
        isSelecting: isSelecting,
        onPlayersSelected: onPlayersSelected,
      ),
    );
  }
}

class FriendsScreenContent extends StatefulWidget {
  final PlayerProfile playerProfile;
  final bool isSelecting;
  final void Function(List<PlayerProfile>)? onPlayersSelected;

  const FriendsScreenContent({
    super.key, 
    required this.playerProfile,
    this.isSelecting = false,
    this.onPlayersSelected,
  });

  @override
  State<FriendsScreenContent> createState() => _FriendsScreenContentState();
}

class _FriendsScreenContentState extends State<FriendsScreenContent> with SingleTickerProviderStateMixin {
  late TextEditingController _searchController;
  late FriendManager _friendManager;
  final Set<PlayerProfile> _selectedPlayers = {};
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _friendManager = Provider.of<FriendManager>(context, listen: false);
      _friendManager.initialize(widget.playerProfile.id);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _showDeleteConfirmation(PlayerProfile profile) {
    final theme = Theme.of(context);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
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
            const SizedBox(height: 8),
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withOpacity(0.1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person_remove_outlined,
                      color: theme.colorScheme.error,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Remove Friend',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Are you sure you want to remove ${profile.name} from your friends list?',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: FilledButton(
                          onPressed: () async {
                            await _friendManager.deleteFriend(
                              widget.playerProfile.id,
                              profile.id,
                            );
                            if (mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(Icons.person_remove, color: Colors.white),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          '${profile.name} removed from your friends list',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: theme.colorScheme.error,
                                  behavior: SnackBarBehavior.floating,
                                  margin: const EdgeInsets.all(16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              );
                            }
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: theme.colorScheme.error,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Remove'),
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

  Future<void> _sendFriendRequest(PlayerProfile recipient) async {
    await SupabaseService().sendFriendRequest(
      widget.playerProfile.id,
      recipient.id,
    );
    
    // Send push notification to the recipient
    await NotificationService().sendFriendRequestNotification(
      toUserId: recipient.id,
      fromUserName: widget.playerProfile.name,
      fromUserId: widget.playerProfile.id,
    );
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.person_add, color: Colors.white),
              const SizedBox(width: 12),
              Text('Friend request sent to ${recipient.name}'),
            ],
          ),
          backgroundColor: const Color(0xFF00BF63),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
    _friendManager.searchResult = null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    _friendManager = Provider.of<FriendManager>(context);
    final brandColor = const Color(0xFF00BF63);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        title: Text(
          'Friends',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70.0),
          child: FadeTransition(
            opacity: _animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.5),
                end: Offset.zero,
              ).animate(_animation),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Container(
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
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by Player ID',
                      prefixIcon: Icon(
                        Icons.search,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _friendManager.searchResult = null;
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    onChanged: (value) {
                      setState(() {});
                      _friendManager.searchPlayer(value);
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: theme.colorScheme.background.withOpacity(0.95),
        actions: [
          if (widget.isSelecting && _selectedPlayers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: TextButton.icon(
                onPressed: () {
                  widget.onPlayersSelected?.call(_selectedPlayers.toList());
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.check_circle, color: Color(0xFF00BF63)),
                label: Text(
                  'Add ${_selectedPlayers.length} Player${_selectedPlayers.length != 1 ? 's' : ''}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: brandColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _buildBodyContent(theme, brandColor),
    );
  }

  Widget _buildBodyContent(ThemeData theme, Color brandColor) {
    if (_friendManager.isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF00BF63),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(top: 16),
      physics: const BouncingScrollPhysics(),
      children: [
        if (_friendManager.searchResult != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _buildSearchResultCard(_friendManager.searchResult!),
          ),

        if (_friendManager.openFriendRequestsProfiles.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(
                  icon: Icons.person_add_alt_1_outlined,
                  title: 'Friend Requests',
                  count: _friendManager.openFriendRequestsProfiles.length,
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        spreadRadius: 0,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListView.separated(
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      indent: 72,
                      endIndent: 16,
                      color: Colors.grey.withOpacity(0.1),
                    ),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _friendManager.openFriendRequestsProfiles.length,
                    itemBuilder: (context, index) {
                      final request = _friendManager.openFriendRequestsProfiles[index];
                      return PlayerTile( // Replacement for FriendRequestTile
                        playerProfile: request,
                        actionType: PlayerTileActionType.acceptDecline,
                        onAccept: () async {
                          await _friendManager.acceptFriendRequest(
                            widget.playerProfile.id,
                            request.id,
                          );
                          if (mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PlayerDetailsScreen(
                                  player: request,
                                  currentUserProfile: widget.playerProfile,
                                  forceShowAsFriend: true,
                                ),
                              ),
                            );
                          }
                        },
                        onDecline: () async {
                          await _friendManager.declineFriendRequest(
                            widget.playerProfile.id,
                            request.id,
                          );
                          // Send notification to the sender that their request was declined
                          await NotificationService().sendFriendRequestDeclinedNotification(
                            toUserId: request.id,
                            declinedByName: widget.playerProfile.name,
                          );
                        },
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PlayerDetailsScreen(
                              player: request, // Use 'request' here as it's the profile for this tile
                              currentUserProfile: widget.playerProfile,
                            ),
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Reduced vertical padding
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

        Padding(
           padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
           child: _buildSectionHeader(
             icon: Icons.group_outlined,
             title: 'My Friends',
             count: _friendManager.friendsProfiles.length,
           ),
        ),

        if (_friendManager.friendsProfiles.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: brandColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.people_outline,
                      size: 50,
                      color: brandColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No friends yet',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'Search for players by their Player ID to add them as friends',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: _friendManager.friendsProfiles.length,
            itemBuilder: (context, index) {
              final friend = _friendManager.friendsProfiles[index];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2), // Reduced vertical padding
                child: PlayerTile( // Replacement for ModernPlayerTile
                  playerProfile: friend,
                  onTap: () {
                    if (widget.isSelecting) {
                      setState(() {
                        if (_selectedPlayers.contains(friend)) {
                          _selectedPlayers.remove(friend);
                        } else {
                          _selectedPlayers.add(friend);
                        }
                      });
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PlayerDetailsScreen(
                            player: friend, // Use 'friend' here
                            currentUserProfile: widget.playerProfile,
                          ),
                        ),
                      );
                    }
                  },
                  actionType: widget.isSelecting 
                      ? PlayerTileActionType.checkbox 
                      : PlayerTileActionType.moreOptions,
                  isCheckboxChecked: widget.isSelecting && _selectedPlayers.contains(friend),
                  onToggleSelection: widget.isSelecting 
                      ? (value) {
                          setState(() {
                            if (value == true) {
                              _selectedPlayers.add(friend);
                            } else {
                              _selectedPlayers.remove(friend);
                            }
                          });
                        }
                      : null,
                  onMoreOptions: widget.isSelecting 
                      ? null 
                      : () => _showDeleteConfirmation(friend),
                  isSelected: widget.isSelecting && _selectedPlayers.contains(friend),
                  // ModernPlayerTile specific styling can be applied here if needed
                  // e.g. tileColor, selectedTileColor, customShape
                  // For now, using default PlayerTile styling.
                  // The ModernPlayerTile had a Card with specific shape and side.
                  // This can be replicated by passing customShape to PlayerTile.
                  customShape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: (widget.isSelecting && _selectedPlayers.contains(friend))
                          ? brandColor.withOpacity(0.5)
                          : Colors.grey.withOpacity(0.1),
                      width: (widget.isSelecting && _selectedPlayers.contains(friend)) ? 2 : 1,
                    ),
                  ),
                  tileColor: Colors.white, // ModernPlayerTile used white
                  selectedTileColor: brandColor.withOpacity(0.1), // Mimic selection color
                  contentPadding: const EdgeInsets.all(12), // From ModernPlayerTile
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildSectionHeader({required IconData icon, required String title, required int count}) {
    final theme = Theme.of(context);
    final brandColor = const Color(0xFF00BF63);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: brandColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: brandColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: brandColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count.toString(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: brandColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResultCard(PlayerProfile profile) {
    final theme = Theme.of(context);
    // final isFriend = _friendManager.friendsProfiles.any((friend) => friend.id == profile.id); // Not used in this widget
    // final brandColor = const Color(0xFF00BF63); // Not used in this widget

    // Using PlayerTile for search result for consistency
    return PlayerTile(
      playerProfile: profile,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PlayerDetailsScreen(
            player: profile,
            currentUserProfile: widget.playerProfile,
          ),
        ),
      ),
      // Add any specific styling for search result tile if needed
      // For example, a slightly different background or border
      tileColor: Colors.white,
      customShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      // No specific action type for search result card, defaults to none
    );
  }
}

// Removed ModernPlayerTile and FriendRequestTile classes as they are replaced by the unified PlayerTile
// The extra curly brace was here, now removed.
